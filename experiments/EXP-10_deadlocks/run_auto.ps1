param([string]$Database='bank_txn_scratch',[int]$Iterations=50,[string]$EvidencePrefix='EV-EXP10',[switch]$RequireOrderedZero)
. "$PSScriptRoot/../lib/Common.ps1"
if ($EvidencePrefix -notmatch '^EV-EXP10(?:-[A-Za-z0-9-]+)?$') { throw 'EvidencePrefix must be an EV-EXP10 filename prefix, not a path.' }
Initialize-Lab $Database
$dir=New-EvidenceDir 'EXP-10'; $ids=Get-LabIds $Database; $a=$ids[0]; $b=$ids[1]; $results=@()
$original=[IO.File]::ReadAllText((Join-Path $script:RepoRoot 'procedures/sp_internal_post_transfer.sql'))
$needle='SELECT account_id INTO v_lock FROM Accounts WHERE account_id=v_first FOR UPDATE;'
if (!$original.Contains($needle)) { throw 'First-lock instrumentation anchor changed; refusing to alter routine.' }
# Temporary DB-only scheduling probe, original source restored in finally. No shipping file edits.
$probe=$original.Replace($needle,$needle+"`n IF p_lab_mode=3 THEN SELECT SLEEP(IFNULL(@lab_first_lock_sleep,0.05)) INTO v_sleep; END IF;")
$old=@(Invoke-MySql $Database -Sql 'SELECT @@GLOBAL.innodb_print_all_deadlocks;')[0]
$orderedDeadlocks=$null; $orderedSuccess=0
try {
 Invoke-MySql $Database -Sql "SET GLOBAL innodb_print_all_deadlocks=ON; DROP PROCEDURE sp_internal_post_transfer;`n$probe" | Out-Null
 Save-Text "$dir/instrumentation.sql" $probe
 $prefix="SET @lab_first_lock_sleep=3,@lab_sleep_seconds=3; SET SESSION innodb_lock_wait_timeout=15;"
 $p=Start-MySqlSession $Database -Sql "$prefix CALL sp_transfer_funds($a,$b,10,'Online',NULL,NULL,NULL,3,@g,@d,@c);" -Name create-A -Directory $dir
 $q=Start-MySqlSession $Database -Sql "$prefix CALL sp_transfer_funds($b,$a,10,'Online',NULL,NULL,NULL,3,@g,@d,@c);" -Name create-B -Directory $dir
 Start-Sleep -Milliseconds 1500
 Get-LockEvidence $Database "$dir/create-locks.txt"
 for ($poll=0;$poll -lt 10;$poll++) {
  Start-Sleep -Milliseconds 100
  Get-LockEvidence $Database "$dir/create-poll-$poll.txt"
 }
 Wait-Sessions @($p,$q) -AllowErrors
 $err=[IO.File]::ReadAllText($p.LabStderr)+[IO.File]::ReadAllText($q.LabStderr)
 if ($err -notmatch '1213') { throw "Real deadlock not observed: $err" }
 $results+='RESULT|EXP-10|CREATE|victim_errno|1213'
 $status=Invoke-MySql $Database -Sql 'SHOW ENGINE INNODB STATUS;' -OutputFile "$dir/innodb-status.txt"
 $graph=[regex]::Match(($status -join "`n"),'LATEST DETECTED DEADLOCK[\s\S]*?(?=\r?\n-+\r?\nTRANSACTIONS)')
 if (!$graph.Success) { throw 'InnoDB did not retain the detected deadlock graph.' }
 Save-Text "$dir/latest-detected-deadlock.txt" $graph.Value
 try {
  $logRows=@(Invoke-MySql $Database -Sql "SELECT LOGGED,PRIO,ERROR_CODE,SUBSYSTEM,DATA FROM performance_schema.error_log WHERE LOGGED>NOW()-INTERVAL 5 MINUTE AND (DATA LIKE '%deadlock%' OR DATA LIKE '%TRANSACTION%');" -OutputFile "$dir/error-log.txt")
  if (!$logRows.Count) {
   $paths=@(Invoke-MySql $Database -Sql 'SELECT @@GLOBAL.datadir; SELECT @@GLOBAL.log_error;')
   $errorPath=if ([IO.Path]::IsPathRooted($paths[1])) { $paths[1] } else { Join-Path $paths[0] $paths[1] }
   try { Save-Text "$dir/datadir-error-log.txt" ((Get-Content -LiteralPath $errorPath -Tail 200) -join "`n") }
   catch { Save-Text "$dir/error-log-unavailable.txt" $_.Exception.Message; $results+='RESULT|EXP-10|DETECT|error_log|NEEDS MANUAL VERIFICATION: performance_schema returned no deadlock rows; datadir error log access denied' }
  }
 }
 catch { Save-Text "$dir/error-log-unavailable.txt" $_.Exception.Message; $results+='RESULT|EXP-10|DETECT|error_log|BLOCKED: see raw reason' }
 $p=Start-MySqlSession $Database -Sql "START TRANSACTION; SELECT account_id FROM Accounts WHERE account_id=$a FOR UPDATE; SELECT SLEEP(5); ROLLBACK;" -Name wait-A -Directory $dir
 Start-Sleep -Seconds 1
 $q=Start-MySqlSession $Database -Sql "SET SESSION innodb_lock_wait_timeout=2; CALL sp_deposit($a,10,'Online',NULL,NULL,NULL,@t,@b);" -Name wait-B -Directory $dir
 Start-Sleep -Milliseconds 500; Get-LockEvidence $Database "$dir/contrast-locks.txt"
 Wait-Sessions @($p,$q) -AllowErrors
 if ([IO.File]::ReadAllText($q.LabStderr) -notmatch '1205') { throw 'Contrast 1205 not observed.' }
 $results+='RESULT|EXP-10|CONTRAST|errno|1205'
 $comparison=@()
 foreach ($mode in @(3,2)) {
  $before=[int64]@(Invoke-MySql $Database -Sql "SELECT COUNT FROM information_schema.INNODB_METRICS WHERE NAME='lock_deadlocks';")[0]
  $logBefore=[int64]@(Invoke-MySql $Database -Sql "SELECT COALESCE(MAX(log_id),0) FROM bank_lab.Experiment_Log;")[0]
  $sqlA="SET @lab_first_lock_sleep=0.05,@lab_sleep_seconds=0.01;"; $sqlB=$sqlA
  $sqlA+=" CALL sp_lab_retry_loop($a,$b,$Iterations,$mode);"
  $sqlB+=" CALL sp_lab_retry_loop($b,$a,$Iterations,$mode);"
  $p=Start-MySqlSession $Database -Sql $sqlA -Name "retry-mode$mode-A" -Directory $dir
  $q=Start-MySqlSession $Database -Sql $sqlB -Name "retry-mode$mode-B" -Directory $dir
  Wait-Sessions @($p,$q) -TimeoutSeconds 180
  $after=[int64]@(Invoke-MySql $Database -Sql "SELECT COUNT FROM information_schema.INNODB_METRICS WHERE NAME='lock_deadlocks';")[0]
  if ($after -gt $before) { Invoke-MySql $Database -Sql 'SHOW ENGINE INNODB STATUS;' -OutputFile "$dir/mode-$mode-innodb-status.txt" | Out-Null }
  $logs=Invoke-MySql $Database -Sql "SELECT log_id,event_type,detail FROM bank_lab.Experiment_Log WHERE log_id>$logBefore AND db_name=DATABASE() AND event_type IN ('DEADLOCK_RETRY','LOCKWAIT_RETRY');" -OutputFile "$dir/retries-mode$mode.txt"
  Invoke-MySql $Database -Sql "SELECT log_id,event_type,detail FROM bank_lab.Experiment_Log WHERE log_id>$logBefore AND db_name=DATABASE() AND event_type='RETRY_EXHAUSTED';" -OutputFile "$dir/exhausted-mode$mode.txt" | Out-Null
  $success=([regex]::Matches(([IO.File]::ReadAllText($p.LabStdout)+[IO.File]::ReadAllText($q.LabStdout)),'(?m)^SUCCESS')).Count
  $exhausted=([regex]::Matches(([IO.File]::ReadAllText($p.LabStdout)+[IO.File]::ReadAllText($q.LabStdout)),'(?m)^RETRY_EXHAUSTED')).Count
  if ($success+$exhausted -ne $Iterations*2) { throw 'Retry attempt accounting mismatch.' }
  $comparison+="| $mode | $($after-$before) | $(@($logs).Count) | $success / $($Iterations*2) |"
  if ($mode -eq 3 -and @($logs).Count -eq 0) { throw 'No committed retry logs observed.' }
  $results+="RESULT|EXP-10|MODE-$mode|deadlocks|$($after-$before)"
  $results+="RESULT|EXP-10|MODE-$mode|success|$success/$($Iterations*2)"
  $results+="RESULT|EXP-10|MODE-$mode|retry_exhausted|$exhausted"
  if ($mode -eq 2) { $orderedDeadlocks=$after-$before; $orderedSuccess=$success }
  if ($mode -eq 2 -and $after -gt $before) { $results+="RESULT|EXP-10|PREVENT|target|TARGET NOT MET: ordered mode still had $($after-$before) deadlocks; inspect retained graph" }
 }
 Save-Text "evidence/$EvidencePrefix-compare.md" ("# Measured deadlock comparison`n`nDB-only first-lock pause in mode 3; source snapshot retained in instrumentation.sql. Raw: $dir`n`n| Mode | Deadlocks delta | Committed retry rows | Successful calls |`n|---|---:|---:|---:|`n"+($comparison -join "`n"))
 Assert-LabInvariants $Database $dir
} finally {
 try { Invoke-MySql $Database -Sql "DROP PROCEDURE IF EXISTS sp_internal_post_transfer;`n$original" | Out-Null }
 finally {
  Invoke-MySql $Database -Sql "SET GLOBAL innodb_print_all_deadlocks=$old;" | Out-Null
  Invoke-MySql $Database -Sql "SELECT @@GLOBAL.innodb_print_all_deadlocks;" -OutputFile "$dir/global-restored.txt" | Out-Null
 }
}
Save-Text "$dir/results.txt" ($results -join "`n")
Complete-Experiment $PSScriptRoot $dir $results
if ($RequireOrderedZero) {
 if ($orderedDeadlocks -ne 0 -or $orderedSuccess -ne $Iterations*2) { throw 'Ordered workload did not meet zero-deadlock/full-completion requirement; actual measurements retained.' }
 Write-Output "TEST|PASS|EXP-10 corrected ordered locking|0 deadlocks; $orderedSuccess/$($Iterations*2) successful calls"
}
