# LAB ONLY — never ship
param([ValidateSet('01','04','05','06','07','09')][string]$Experiment,[string]$Database='bank_txn_scratch',[int]$Iterations=200,[int]$Parallel=20)
. "$PSScriptRoot/Common.ps1"
Initialize-Lab $Database
$dir=New-EvidenceDir "EXP-$Experiment"; $results=@()
$ids=Get-LabIds $Database; $a=$ids[0]; $b=$ids[1]; $c=$ids[2]
$folders=@{'01'='atomicity';'04'='lost_update';'05'='dirty_read';'06'='nonrepeatable_read';'07'='phantom_read';'09'='stress'}
$folder="experiments/EXP-$($Experiment)_$($folders[$Experiment])"
if ($Experiment -eq '01') {
 $snapshot="SELECT account_number,balance FROM Accounts WHERE account_number LIKE 'LAB-%' ORDER BY account_number; SELECT SUM(balance),COUNT(*) FROM Accounts; SELECT COUNT(*) FROM Transactions;"
 $before=Invoke-MySql $Database -Sql $snapshot -OutputFile "$dir/before.txt"
 $results+=Invoke-MySql $Database -Sql "CALL sp_lab_atomicity_loop($Iterations);" -OutputFile "$dir/injected.txt"
 if ($results -notcontains 'RESULT|EXP-01|ALL|partial_transfers|0') { throw 'Partial transfer observed.' }
 Invoke-MySql $Database -Sql "INSERT INTO bank_lab.Experiment_Log(db_name,exp_id,event_type,detail) SELECT DATABASE(),'EXP-01','BEFORE_KILL',JSON_OBJECT('sum',SUM(balance),'rows',(SELECT COUNT(*) FROM Transactions)) FROM Accounts;" | Out-Null
 $p=Start-MySqlSession $Database -Sql "SET @lab_sleep_seconds=30; CALL sp_transfer_funds($a,$b,10,'Online',NULL,NULL,NULL,2,@g,@d,@c);" -Name killed -Directory $dir
 $id=Get-ConnectionId $p
 try {
  Start-Sleep -Seconds 2
  Get-LockEvidence $Database "$dir/mid-transfer-locks.txt"
  $sleepState=@(Invoke-MySql $Database -Sql "SELECT CONCAT('CONNECTION_STATE|',PROCESSLIST_ID,'|',PROCESSLIST_STATE) FROM performance_schema.threads WHERE PROCESSLIST_ID=$id;" -OutputFile "$dir/killed-connection-state.txt")
  if (($sleepState -join '') -notmatch '\|User sleep$') { throw 'Owned connection was not confirmed inside SLEEP; KILL experiment is not valid.' }
  Invoke-MySql $Database -Sql "KILL $id;" -OutputFile "$dir/kill.txt" | Out-Null
  Wait-Sessions @($p) -AllowErrors
 } finally {
  if (!$p.HasExited) { Invoke-MySql $Database -Sql "KILL $id;" | Out-Null; Wait-Sessions @($p) -AllowErrors }
 }
 Start-Sleep -Milliseconds 300
 $after=Invoke-MySql $Database -Sql $snapshot -OutputFile "$dir/after.txt"
 if (($before -join '|') -ne ($after -join '|')) { throw 'KILL changed committed snapshot.' }
 Invoke-MySql $Database -Sql "INSERT INTO bank_lab.Experiment_Log(db_name,exp_id,event_type,detail) SELECT DATABASE(),'EXP-01','AFTER_KILL',JSON_OBJECT('connection_id',$id,'sum',SUM(balance),'rows',(SELECT COUNT(*) FROM Transactions)) FROM Accounts;" | Out-Null
 $results+="RESULT|EXP-01|ALL|kill_snapshot_unchanged|YES"
}
if ($Experiment -eq '04') {
 foreach ($level in @('READ UNCOMMITTED','READ COMMITTED','REPEATABLE READ','SERIALIZABLE')) {
  foreach ($fix in @('naive','atomic','ordered')) {
   Initialize-Lab $Database; $ids=Get-LabIds $Database; $a=$ids[0]; $b=$ids[1]; $c=$ids[2]
   $prefix="SET SESSION TRANSACTION ISOLATION LEVEL $level; SET SESSION innodb_lock_wait_timeout=10; SET @lab_sleep_seconds=5;"
   $ca="CALL sp_transfer_naive($a,$b,100);"; $cb="CALL sp_transfer_naive($a,$c,200);"
   if ($fix -eq 'atomic') { $ca="CALL sp_transfer_atomic_update($a,$b,100);"; $cb="CALL sp_transfer_atomic_update($a,$c,200);" }
   if ($fix -eq 'ordered') { $ca="CALL sp_transfer_funds($a,$b,100,'Online',NULL,NULL,NULL,2,@g,@d,@c);"; $cb="CALL sp_transfer_funds($a,$c,200,'Online',NULL,NULL,NULL,2,@g,@d,@c);" }
   $p=Start-MySqlSession $Database -Sql "$prefix $ca SELECT 'COMMITTED';" -Name "$level-$fix-A" -Directory $dir
   Start-Sleep -Seconds 1
   $q=Start-MySqlSession $Database -Sql "$prefix $cb SELECT 'COMMITTED';" -Name "$level-$fix-B" -Directory $dir
   Start-Sleep -Milliseconds 500
   Get-LockEvidence $Database "$dir/$level-$fix-locks.txt"
   Wait-Sessions @($p,$q) -AllowErrors
   $errors=[IO.File]::ReadAllText($p.LabStderr)+[IO.File]::ReadAllText($q.LabStderr)
   if ($errors -and $errors -notmatch 'ERROR (1213|1205)') { throw "Unexpected native error: $errors" }
   $actual=@(Invoke-MySql $Database -Sql "SELECT balance FROM Accounts WHERE account_id=$a;")[0]
   $commits=0; if ([IO.File]::ReadAllText($p.LabStdout) -match 'COMMITTED') { $commits+=100 }; if ([IO.File]::ReadAllText($q.LabStdout) -match 'COMMITTED') { $commits+=200 }
   $expected=1000000-$commits
   $v=if ([decimal]$actual -ne $expected) { 'OBSERVED' } elseif ($errors -match '1213|1205') { 'BLOCKED' } else { 'NOT OBSERVED' }
   $results+="RESULT|EXP-04|$level|$fix|$v"
   $results+="RESULT|EXP-04|$level|$fix-balances|expected=$expected;actual=$actual;committed_amount=$commits"
   if ($fix -ne 'naive' -and $v -eq 'OBSERVED') { throw "Lost update in $fix fix." }
   if ($fix -ne 'naive') { Assert-LabInvariants $Database $dir }
  }
 }
 Initialize-Lab $Database
}
if ($Experiment -in @('05','06','07')) {
 foreach ($level in @('READ UNCOMMITTED','READ COMMITTED','REPEATABLE READ','SERIALIZABLE')) {
  $prefix="SET SESSION TRANSACTION ISOLATION LEVEL $level; SET SESSION innodb_lock_wait_timeout=3;"
  if ($Experiment -eq '05') {
   $sqlA="START TRANSACTION; UPDATE Accounts SET balance=balance+1000 WHERE account_id=$a; SELECT SLEEP(10); ROLLBACK;"
   $sqlB="$prefix START TRANSACTION; SELECT CONCAT('READ|',balance) FROM Accounts WHERE account_id=$a; COMMIT;"
   $delay=3
  } elseif ($Experiment -eq '06') {
   $sqlA="$prefix START TRANSACTION; SELECT balance INTO @first FROM Accounts WHERE account_id=$a; SELECT CONCAT('FIRST|',@first); SELECT SLEEP(6); SELECT CONCAT('CHANGED|',IF(balance<>@first,'OBSERVED','NOT OBSERVED')) FROM Accounts WHERE account_id=$a; COMMIT;"
   $sqlB="SET SESSION innodb_lock_wait_timeout=2; CALL sp_deposit($a,1000,'Online',NULL,NULL,NULL,@t,@b);"; $delay=2
  } else {
   $sqlA="$prefix START TRANSACTION; SELECT COUNT(*) INTO @first FROM Transactions WHERE account_id=$a AND status='Completed'; SELECT CONCAT('FIRST|',@first); SELECT SLEEP(6); SELECT CONCAT('CHANGED|',IF(COUNT(*)<>@first,'OBSERVED','NOT OBSERVED')) FROM Transactions WHERE account_id=$a AND status='Completed';"
   if ($level -eq 'REPEATABLE READ') { $sqlA+=" SELECT transaction_id FROM Transactions WHERE account_id=$a AND status='Completed' FOR UPDATE; SELECT CONCAT('CURRENT|',COUNT(*)) FROM Transactions WHERE account_id=$a AND status='Completed' FOR UPDATE;" }
   $sqlA+=' COMMIT;'
   $sqlB="SET SESSION innodb_lock_wait_timeout=2; CALL sp_deposit($a,10,'Online',NULL,NULL,NULL,@t,@b);"; $delay=2
  }
  $p=Start-MySqlSession $Database -Sql $sqlA -Name "$level-A" -Directory $dir
  Start-Sleep -Seconds $delay
  $q=Start-MySqlSession $Database -Sql $sqlB -Name "$level-B" -Directory $dir
  if ($Experiment -eq '07') { Start-Sleep -Milliseconds 500; Get-LockEvidence $Database "$dir/$level-locks.txt" }
  Wait-Sessions @($p,$q) -AllowErrors
  $out=[IO.File]::ReadAllText($p.LabStdout)+[IO.File]::ReadAllText($q.LabStdout)
  $err=[IO.File]::ReadAllText($p.LabStderr)+[IO.File]::ReadAllText($q.LabStderr)
  if ($err -and $err -notmatch 'ERROR 1205') { throw "Unexpected native error: $err" }
  if ($err -match '1205') { $v='BLOCKED' }
  elseif ($Experiment -eq '05') {
   if ($out -match 'READ\|1001000.00') { $v='OBSERVED' } elseif ($out -match 'READ\|1000000.00') { $v='NOT OBSERVED' } else { throw "Unrecognized dirty read: $out $err" }
  } elseif ($out -match 'CHANGED\|([^\r\n]+)') { $v=$Matches[1] } else { throw "Unrecognized observation: $out $err" }
  if ($Experiment -eq '07' -and $level -eq 'REPEATABLE READ') { $v+=' (nuance)' }
  $results+="RESULT|EXP-$Experiment|$level|anomaly|$v"
 }
 if ($Experiment -eq '07') {
  $p=Start-MySqlSession $Database -Sql "SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ; START TRANSACTION; SELECT transaction_id FROM Transactions WHERE account_id=$a FOR UPDATE; SELECT SLEEP(6); COMMIT;" -Name gap-B -Directory $dir
  Start-Sleep -Seconds 1
  $q=Start-MySqlSession $Database -Sql "SET SESSION innodb_lock_wait_timeout=2; CALL sp_deposit($a,10,'Online',NULL,NULL,NULL,@t,@b);" -Name gap-A -Directory $dir
  Start-Sleep -Milliseconds 500
  Get-LockEvidence $Database "$dir/gap-locks.txt"
  Wait-Sessions @($p,$q) -AllowErrors
  if ([IO.File]::ReadAllText($q.LabStderr) -notmatch '1205') { throw 'Gap timeout was not observed.' }
  $results+='RESULT|EXP-07|REPEATABLE READ|gap_writer|BLOCKED'
 }
}
if ($Experiment -eq '09') {
 $metrics="SELECT COUNT(*) FROM Transactions WHERE status='Completed'; SELECT COUNT(*) FROM Transactions WHERE status='Failed'; SELECT COUNT FROM information_schema.INNODB_METRICS WHERE NAME='lock_deadlocks'; SELECT COUNT(*) FROM bank_lab.Experiment_Log WHERE db_name=DATABASE() AND event_type IN ('DEADLOCK_RETRY','LOCKWAIT_RETRY');"
 Invoke-MySql $Database -Sql $metrics -OutputFile "$dir/before.txt" | Out-Null
 $sessions=@(); $watch=[Diagnostics.Stopwatch]::StartNew()
 for ($i=0;$i -lt $Parallel;$i++) { $sessions+=Start-MySqlSession $Database -Sql "CALL sp_lab_stress_loop($Iterations,$i);" -Name "worker-$i" -Directory $dir }
 Wait-Sessions $sessions -TimeoutSeconds 300
 $watch.Stop()
 Invoke-MySql $Database -Sql $metrics -OutputFile "$dir/after.txt" | Out-Null
 $ok=0; $errors=0
 foreach ($p in $sessions) {
  $s=[IO.File]::ReadAllText($p.LabStdout)
  if ($s -match '\|successful\|(\d+)') { $ok += [int]$Matches[1] }
  if ($s -match '\|errors\|(\d+)') { $errors += [int]$Matches[1] }
 }
 if ($ok+$errors -ne $Parallel*$Iterations) { throw 'Worker accounting mismatch.' }
 $results+=@("RESULT|EXP-09|ALL|parallel|$Parallel","RESULT|EXP-09|ALL|iterations_each|$Iterations","RESULT|EXP-09|ALL|successful|$ok","RESULT|EXP-09|ALL|errors|$errors","RESULT|EXP-09|ALL|seconds|$($watch.Elapsed.TotalSeconds)")
}
Assert-LabInvariants $Database $dir
Save-Text "$dir/results.txt" ($results -join "`n")
Complete-Experiment $folder $dir $results
