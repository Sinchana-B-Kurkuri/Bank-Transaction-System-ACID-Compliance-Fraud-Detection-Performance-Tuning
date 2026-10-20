param([string]$Database='bank_txn',[switch]$NoRebuild,[string]$Filter='*',
 [ValidateSet('Auto','Standalone','Integrated')][string]$Mode='Auto')
. "$PSScriptRoot/../build/mysql_common.ps1"
Assert-BankDatabase $Database
$root=Split-Path $PSScriptRoot -Parent
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$runId=$stamp
$log=[Collections.Generic.List[string]]::new()
$pass=0; $fail=0
try {
 Push-Location $root
 if ($Mode -eq 'Auto' -and $env:BANK_TEST_BUILD_MODE) { $Mode=$env:BANK_TEST_BUILD_MODE }
 [void][IO.Directory]::CreateDirectory((Join-Path $root 'evidence/test-runs'))
 if (!$NoRebuild) {
  $ErrorActionPreference='Continue'
  $buildArgs=@('-Database',$Database)
  if ($Mode -ne 'Auto') { $buildArgs+=@('-Mode',$Mode) }
  $output=@(& powershell -NoProfile -File build/rebuild.ps1 @buildArgs 2>&1 | ForEach-Object { "$_" })
  $ErrorActionPreference='Stop'
  $log.AddRange([string[]]$output)
  if ($LASTEXITCODE -ne 0) { throw 'Rebuild failed; tests not executed.' }
 }
 # Detect installed real B schema, not merely files or the stand-in interfaces.
 $real=@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='Account_Risk_Profile';")[0] -eq '1'
 if ($Mode -eq 'Auto') { $Mode=if($real){'Integrated'}else{'Standalone'} }
 if (($Mode -eq 'Integrated') -ne $real) { throw 'Requested test mode disagrees with installed schema.' }
 $manifest=Import-Csv tests/component_tests.csv
 foreach ($folder in @('schema','functions','triggers','procedures','invariants','integration')) {
  $files=Get-ChildItem "tests/$folder" -File | Where-Object { $_.Name -match '^\d\d_.*\.(sql|ps1)$' -and $_.BaseName -like $Filter } | Sort-Object Name
  foreach ($file in $files) {
   $relative=$file.FullName.Substring($root.Length+1).Replace('\','/')
   if ($Mode -eq 'Standalone' -and @($manifest | Where-Object { $_.Path -eq $relative -and $_.Mode -eq 'Integrated' }).Count) {
    $line="SKIP|$relative|Integrated component test; Standalone has interface stubs only"
    $log.Add($line); Write-Output $line; continue
   }
   try {
    if ($file.Extension -eq '.sql') {
     $restoreLedgerGuard=$false
     try {
      # Prompt 1's unchanged constraint fixture deliberately UPDATEs ledger NULLs.
      # Test native column errors independently of Prompt 2's unconditional guard,
      # then restore the guard before any function/trigger/procedure tests run.
      if ($relative -eq 'tests/schema/01_negative_constraints.sql') {
       $installed=@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema=DATABASE() AND trigger_name='trg_transactions_bu_immutable';")
       if ([int]$installed[0] -eq 1) {
        Invoke-BankMysql -Database $Database -Sql 'DROP TRIGGER trg_transactions_bu_immutable;' | Out-Null
        $restoreLedgerGuard=$true
        $log.Add('INFO|Native constraint isolation: temporarily suspend ledger UPDATE guard for unchanged Prompt 1 fixture; restore in finally.')
       }
      }
      $output=@(Invoke-BankMysql -Database $Database -Sql "SET @test_run_id='$runId';`nsource $relative")
     } finally {
      if ($restoreLedgerGuard) { Invoke-BankMysql -Database $Database -Sql 'source triggers/guards/trg_transactions_bu_immutable.sql' | Out-Null }
     }
    }
    else {
     $ErrorActionPreference='Continue'
     $output=@(& powershell -NoProfile -File $file.FullName -Database $Database 2>&1 | ForEach-Object { "$_" })
     $ErrorActionPreference='Stop'
     if ($LASTEXITCODE -ne 0) { throw "$relative exited $LASTEXITCODE`n$($output -join "`n")" }
    }
    $log.AddRange([string[]]$output)
    $results=@($output | Where-Object { $_ -match '^TEST\|' })
    if (!$results.Count) { throw "$relative emitted no TEST results" }
    foreach ($line in $results) {
     Write-Output $line
     if ($line -match '^TEST\|PASS\|') { $pass++ } else { $fail++ }
    }
   } catch {
    if ($_.Exception.Data['RawOutput']) { $log.Add([string]$_.Exception.Data['RawOutput']) }
    $fail++; $line="TEST|FAIL|$relative|$($_.Exception.Message)"; $log.Add($line); Write-Output $line
   }
  }
 }
 if ($pass+$fail -eq 0) { throw 'No matching tests executed.' }
} catch { $fail++; $line="TEST|FAIL|runner|$($_.Exception.Message)"; $log.Add($line); Write-Output $line }
finally {
 $summary="TOTAL|PASS=$pass|FAIL=$fail"
 $log.Add($summary); Write-Output $summary
 $log | Set-Content (Get-BankEvidencePath (Join-Path $root "evidence/test-runs/$stamp.txt")) -Encoding UTF8
 Pop-Location
}
if ($fail) { exit 1 }
exit 0
