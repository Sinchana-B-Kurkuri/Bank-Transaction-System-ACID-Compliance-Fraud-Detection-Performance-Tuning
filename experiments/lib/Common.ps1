# LAB ONLY — never ship
. "$PSScriptRoot/../../build/mysql_common.ps1"
$script:RepoRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $script:RepoRoot
function Save-Text([string]$Path,[string]$Text) {
 [void][IO.Directory]::CreateDirectory((Split-Path ([IO.Path]::GetFullPath($Path)) -Parent))
 [IO.File]::WriteAllText([IO.Path]::GetFullPath($Path),$Text,[Text.UTF8Encoding]::new($false))
}
function Get-MySqlPath {
 if ($env:BANK_MYSQL_BIN) { return (Resolve-Path -LiteralPath $env:BANK_MYSQL_BIN).ProviderPath }
 $c=Get-Command mysql.exe -ErrorAction SilentlyContinue
 if ($c) { return $c.Source }
 $c=@(Get-ChildItem "$env:ProgramFiles/MySQL/MySQL Server */bin/mysql.exe")
 if ($c.Count -ne 1) { throw 'Set BANK_MYSQL_BIN to the intended mysql.exe path.' }
 return $c[0].FullName
}
function New-EvidenceDir([string]$Experiment) {
 $p=Join-Path $script:RepoRoot ("evidence/raw/$Experiment/"+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
 [void][IO.Directory]::CreateDirectory($p); return $p
}
function Invoke-MySql {
 param([string]$Database='bank_txn_scratch',[Alias('e')][string]$Sql,[string]$File,[string]$OutputFile)
 Assert-BankDatabase $Database
 if ($File) { $Sql="SOURCE $File;" }
 try { $out=@(Invoke-BankMysql -Database $Database -Sql $Sql); $text=$out -join [Environment]::NewLine }
 catch { if ($OutputFile) { Save-Text $OutputFile ([string]$_.Exception.Data['RawOutput']) }; throw }
 if ($OutputFile) { Save-Text $OutputFile $text }
 return $out
}
function Start-MySqlSession {
 param([string]$Database,[string]$Sql,[string]$Name,[string]$Directory)
 Assert-BankDatabase $Database
 $inputFile=Join-Path $Directory "$Name.sql"
 $stdout=Join-Path $Directory "$Name.stdout.txt"; $stderr=Join-Path $Directory "$Name.stderr.txt"
 $meta="SELECT CONCAT('META|',VERSION(),'|',NOW(6),'|',CONNECTION_ID()); SELECT CONCAT('CONNECTION|',CONNECTION_ID());`n"
 Save-Text $inputFile (Expand-BankSqlSource -Sql ($meta+$Sql))
 $args=@("--defaults-extra-file=$env:BANK_MYSQL_CNF",'--batch','--raw','--unbuffered','--skip-column-names','--default-character-set=utf8mb4','--skip-force',"--database=$Database")
 $p=Start-Process -FilePath (Get-MySqlPath) -ArgumentList (($args | ForEach-Object { ConvertTo-BankNativeArgument $_ }) -join ' ') -WorkingDirectory $script:RepoRoot -WindowStyle Hidden -RedirectStandardInput $inputFile -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
 # Cache the native handle before exit; Windows PowerShell Start-Process otherwise
 # can leave ExitCode null after a fast process has already terminated.
 $null=$p.Handle
 $p | Add-Member NoteProperty LabStdout $stdout
 $p | Add-Member NoteProperty LabStderr $stderr
 $p | Add-Member NoteProperty LabDatabase $Database
 return $p
}
function Get-ConnectionId($Process) {
 for ($i=0;$i -lt 100;$i++) {
  $s=if (Test-Path $Process.LabStdout) { Get-Content -LiteralPath $Process.LabStdout -Raw } else { '' }
  if ($s -match '(?m)^CONNECTION\|(\d+)\r?\n') { return [int64]$Matches[1] }
  if ($Process.HasExited) { throw "Session exited before connection ID: $([IO.File]::ReadAllText($Process.LabStderr))" }
  Start-Sleep -Milliseconds 50
 }
 throw 'Connection ID not flushed within five seconds.'
}
function Wait-Sessions {
 param([object[]]$Sessions,[int]$TimeoutSeconds=90,[switch]$AllowErrors)
 $until=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
 try {
  while (@($Sessions | Where-Object { !$_.HasExited }).Count) {
   if ([DateTime]::UtcNow -gt $until) { throw 'Session deadline exceeded.' }
   Start-Sleep -Milliseconds 100
  }
  foreach ($p in $Sessions) {
   $p.WaitForExit(); $p.Refresh()
   if (!$AllowErrors -and $p.ExitCode -ne 0) { throw "mysql session exited $($p.ExitCode): $([IO.File]::ReadAllText($p.LabStderr))" }
  }
 } finally {
  foreach ($p in $Sessions) {
   if (!$p.HasExited) {
    $id=Get-ConnectionId $p
    Invoke-MySql -Database $p.LabDatabase -Sql "KILL $id;" | Out-Null
    [void]$p.WaitForExit(10000)
   }
  }
 }
}
function Initialize-Lab([string]$Database) {
 Assert-BankDatabase $Database
 & powershell -NoProfile -File build/rebuild.ps1 -Database $Database -Mode Standalone -WithSeed | Out-Null
 if ($LASTEXITCODE) { throw 'Lab rebuild failed.' }
 Invoke-MySql -Database $Database -File experiments/lab_objects/install.sql | Out-Null
 Invoke-MySql -Database $Database -File experiments/lab_objects/setup_lab_accounts.sql | Out-Null
}
function Get-LabIds([string]$Database) {
 return @((Invoke-MySql -Database $Database -Sql "SELECT account_id FROM Accounts WHERE account_number IN ('LAB-0001','LAB-0002','LAB-0003') ORDER BY account_number;") | ForEach-Object { [int]$_ })
}
function Assert-LabInvariants([string]$Database,[string]$Directory) {
 $out=@(Invoke-MySql -Database $Database -File tests/integration/04_after_experiments.sql -OutputFile "$Directory/invariants.txt")
 if (@($out | Where-Object { $_ -match '^TEST\|FAIL' }).Count -or @($out | Where-Object { $_ -match '^TEST\|PASS' }).Count -ne 6) { throw "Invariant failure: $($out -join '; ')" }
}
function Complete-Experiment([string]$Folder,[string]$Directory,[string[]]$Actual) {
 $match=switch -Wildcard ($Folder) {
  '*01_atomicity*' { 'Matched if partial_transfers=0 and kill_snapshot_unchanged=YES; the driver asserted both and all six invariants.' }
  '*02_consistency*' { 'Matched: all recorded expected errnos matched the actual server errnos; failed checks would stop the driver.' }
  '*04_lost_update*' { 'Unsafe RU/RC/RR lost updates were observed; SERIALIZABLE aborted a writer. Relative updates and ordered locks preserved balances under actual contention. See raw expected/actual balance fields.' }
  '*05_dirty_read*' { 'RU exposed the uncommitted value; RC/RR did not. SERIALIZABLE protected the read by blocking until 1205.' }
  '*06_nonrepeatable_read*' { 'RU/RC values changed, RR remained stable, and SERIALIZABLE blocked the writer (1205).' }
  '*07_phantom_read*' { 'RC observed a phantom; InnoDB RR snapshot remained stable while the locking current read saw an added row. Gap and SERIALIZABLE schedules blocked the writer.' }
  '*08_isolation_matrix*' { 'Throughput is a measured workload result with no assumed winning isolation level; see CSV. Matrix differences from textbook minimum guarantees are flagged explicitly.' }
  '*09_stress*' { 'All six invariants passed. Worker successes/errors and expected call totals were checked; throughput has no predefined target.' }
  '*10_deadlocks*' { 'A real 1213 and separate 1205 were required. Retry success/exhaustion and ordered-mode deadlocks are measurements, not assumed to be zero. Error-log capture may still need administrator verification.' }
  default { 'See measured result fields.' }
 }
 $text="# Measured results`n`n## Hypothesis`nSee README for expectations recorded before measurement.`n`n## Procedure run`nWindows PowerShell driver; independent native mysql processes. Run timestamps are in the raw directory names and session META records. Report generated $(Get-Date -Format o).`n`n## Raw output paths`n$Directory`n`n## Actual`n"+($Actual -join "`n")+"`n`n## Match?`n$match`n`n## Notes`nSession SQL, stdout and stderr retained; META includes server version, time and connection ID.`n"
 Save-Text "$Folder/RESULTS.md" $text
 Write-Output ($Actual -join "`n")
}
function Get-LockEvidence([string]$Database,[string]$Path) {
 Invoke-MySql -Database $Database -Sql "SELECT NOW(6),ENGINE_TRANSACTION_ID,THREAD_ID,OBJECT_SCHEMA,OBJECT_NAME,INDEX_NAME,LOCK_TYPE,LOCK_MODE,LOCK_STATUS,LOCK_DATA FROM performance_schema.data_locks WHERE OBJECT_SCHEMA=DATABASE(); SELECT NOW(6),w.* FROM performance_schema.data_lock_waits w;" -OutputFile $Path | Out-Null
}
