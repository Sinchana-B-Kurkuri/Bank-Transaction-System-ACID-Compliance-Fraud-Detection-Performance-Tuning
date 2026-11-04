param([string]$Database='bank_txn_scratch',[switch]$SkipThroughput,[switch]$ResumeThroughput,[switch]$Quick)
if ($args.Count) { throw 'Unknown experiment arguments; refusing to select a workload.' }
if ($Quick) {
 if ($SkipThroughput -or $ResumeThroughput) { throw 'Quick is an exclusive bounded profile; no throughput/resume options allowed.' }
 & powershell -NoProfile -File "$PSScriptRoot/run_quick.ps1" -Database $Database
 exit $LASTEXITCODE
}
if ($env:BANK_TEST_ISOLATED_PREFIX) { throw 'Isolated aggregate runs require -Quick; full drivers are not isolated-target certified.' }
. "$PSScriptRoot/lib/Common.ps1"
$summary=[Collections.Generic.List[string]]::new()
$summary.Add("# Measured experiment summary`n`nStarted $(Get-Date -Format o), database $Database. Raw files contain version/time/connection IDs.`n`n| Experiment | Status | Detail |`n|---|---|---|")
$jobs=@(
 @('01','experiments/EXP-01_atomicity/run_auto.ps1',@()),
 @('02','experiments/EXP-02_consistency/run_auto.ps1',@()),
 @('04','experiments/EXP-04_lost_update/run_auto.ps1',@()),
 @('05','experiments/EXP-05_dirty_read/run_auto.ps1',@()),
 @('06','experiments/EXP-06_nonrepeatable_read/run_auto.ps1',@()),
 @('07','experiments/EXP-07_phantom_read/run_auto.ps1',@()),
 @('09-20','experiments/EXP-09_stress/run_stress.ps1',@('-Parallel','20')),
 @('09-50','experiments/EXP-09_stress/run_stress.ps1',@('-Parallel','50')),
 @('10','experiments/EXP-10_deadlocks/run_auto.ps1',@())
)
if ($ResumeThroughput) {
 if ($SkipThroughput) { throw 'ResumeThroughput cannot be combined with SkipThroughput.' }
 $prior=@(Get-Content evidence/EV-EXP-SUMMARY.md | Where-Object { $_ -match '^\| EXP-(01|02|04|05|06|07|09-20|09-50|10) \| LOCALLY TESTED' })
 if ($prior.Count -ne 9) { throw 'Resume requires evidence of all nine completed SQL/stress experiment runs.' }
 $summary.AddRange([string[]]$prior)
 $summary.Add('| Resume | IMPLEMENTED | Reusing recorded completed SQL runs; rerunning matrix and Quick throughput, then cleanup. Original failed driver log is retained. |')
 $jobs=@()
}
$failed=$false
try {
 foreach ($job in $jobs) {
  Write-Output "RUNNING|EXP-$($job[0])"
  $extra=$job[2]; $output=@(& powershell -NoProfile -File $job[1] -Database $Database @extra 2>&1 | ForEach-Object { "$_" })
  Save-Text "evidence/EV-EXP$($job[0])-driver.txt" ($output -join "`n")
  if ($LASTEXITCODE) {
   $summary.Add("| EXP-$($job[0]) | FAIL | See driver log; later experiments not run. |")
   throw "EXP-$($job[0]) failed: $($output -join ' ')"
  }
  $status='LOCALLY TESTED'
  if (($output -join ' ') -match 'TARGET NOT MET') { $status+=' / TARGET NOT MET' }
  if (($output -join ' ') -match 'NEEDS MANUAL VERIFICATION|BLOCKED:') { $status+=' / NEEDS MANUAL VERIFICATION' }
  $summary.Add("| EXP-$($job[0]) | $status | Native MySQL run completed; see RESULTS.md/raw output and any explicit capture limitation. |")
  Write-Output ($output -join "`n")
  Save-Text evidence/EV-EXP-SUMMARY.md ($summary -join "`n")
 }
 & powershell -NoProfile -File experiments/EXP-08_isolation_matrix/build_matrix.ps1
 if ($LASTEXITCODE) { throw 'Matrix generation failed.' }
 $summary.Add('| EXP-08 matrix | LOCALLY TESTED | Parsed completed raw runs. |')
 if (!$SkipThroughput) {
  & powershell -NoProfile -File experiments/EXP-08_isolation_matrix/run_throughput.ps1 -Database $Database -Quick
  if ($LASTEXITCODE) { throw 'Quick throughput failed.' }
  $summary.Add('| EXP-08 Quick | LOCALLY TESTED | Measured mysqlslap RC/RR, concurrency 5/25. |')
 }
} catch { $failed=$true; $summary.Add("| Runner | FAIL | $($_.Exception.Message.Replace('|','/')) |"); Write-Output $_.Exception.Message }
finally {
 Invoke-MySql $Database -File experiments/lab_objects/uninstall.sql | Out-Null
 $remaining=Invoke-MySql $Database -Sql "SELECT ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND (ROUTINE_NAME LIKE 'sp_lab_%' OR ROUTINE_NAME LIKE 'lab_%' OR ROUTINE_NAME IN ('sp_transfer_naive','sp_transfer_atomic_update'));"
 Save-Text evidence/EV-LAB-UNINSTALL.txt ("database=$Database; remaining="+(@($remaining).Count))
 if (@($remaining).Count) { $failed=$true; $summary.Add('| Cleanup | FAIL | Lab routines remain. |') }
 Save-Text evidence/EV-EXP-SUMMARY.md ($summary -join "`n")
}
if ($failed) { exit 1 }
