param([string]$Database='bank_txn',[switch]$NoRebuild,[string]$Filter='*')
. "$PSScriptRoot/../build/mysql_common.ps1"
Assert-BankDatabase $Database
$root=Split-Path $PSScriptRoot -Parent
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$runId=$stamp
$log=[Collections.Generic.List[string]]::new()
$pass=0; $fail=0
try {
 Push-Location $root
 [void][IO.Directory]::CreateDirectory((Join-Path $root 'evidence/test-runs'))
 if (!$NoRebuild) {
  $ErrorActionPreference='Continue'
  $output=@(& powershell -NoProfile -File build/rebuild.ps1 -Database $Database 2>&1 | ForEach-Object { "$_" })
  $ErrorActionPreference='Stop'
  $log.AddRange([string[]]$output)
  if ($LASTEXITCODE -ne 0) { throw 'Rebuild failed; tests not executed.' }
 }
 foreach ($folder in @('schema','functions','triggers','procedures','invariants','integration')) {
  $files=Get-ChildItem "tests/$folder" -File | Where-Object { $_.Name -match '^\d\d_.*\.(sql|ps1)$' -and $_.BaseName -like $Filter } | Sort-Object Name
  foreach ($file in $files) {
   $relative=$file.FullName.Substring($root.Length+1).Replace('\','/')
   try {
    if ($file.Extension -eq '.sql') { $output=@(Invoke-BankMysql -Database $Database -Sql "SET @test_run_id='$runId';`nsource $relative") }
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
 $log | Set-Content (Join-Path $root "evidence/test-runs/$stamp.txt") -Encoding UTF8
 Pop-Location
}
if ($fail) { exit 1 }
exit 0
