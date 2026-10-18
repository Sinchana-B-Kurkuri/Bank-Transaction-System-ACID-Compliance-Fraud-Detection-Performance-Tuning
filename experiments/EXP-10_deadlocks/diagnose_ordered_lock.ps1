# LAB ONLY — never ship
param([string]$Database='bank_txn_scratch')
. "$PSScriptRoot/../lib/Common.ps1"
Initialize-Lab $Database
$dir=New-EvidenceDir 'EXP-10-lock-diagnosis'
$shipping=[IO.File]::ReadAllText((Join-Path $script:RepoRoot 'procedures/sp_internal_post_transfer.sql'))
$old=[IO.File]::ReadAllText((Join-Path $script:RepoRoot 'evidence/EXP10-lock-fix/original/sp_internal_post_transfer.sql'))
$needle='SELECT account_id INTO v_lock FROM Accounts WHERE account_id=v_first FOR UPDATE;'
$ids=Get-LabIds $Database; $a=$ids[0]; $b=$ids[1]; $results=@()
try {
 foreach ($variant in @('original','corrected')) {
  $source=if ($variant -eq 'original') { $old } else { $shipping }
  if (!$source.Contains($needle)) { throw 'Probe anchor missing.' }
  # Pause before the FIRST exclusive read, without changing any existence expression.
  $probe=$source.Replace($needle,'SELECT SLEEP(5) INTO v_sleep;'+[Environment]::NewLine+$needle)
  Invoke-MySql $Database -Sql ("DROP PROCEDURE sp_internal_post_transfer;"+[Environment]::NewLine+$probe) | Out-Null
  Save-Text "$dir/$variant-probe.sql" $probe
  $p=Start-MySqlSession $Database -Sql "SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ; SET @lab_sleep_seconds=0; CALL sp_transfer_funds($a,$b,1,'Online',NULL,NULL,NULL,2,@g,@d,@c);" -Name $variant -Directory $dir
  $id=Get-ConnectionId $p
  try {
   Start-Sleep -Seconds 1
   $state=Invoke-MySql $Database -Sql "SELECT PROCESSLIST_ID,PROCESSLIST_STATE,PROCESSLIST_INFO FROM performance_schema.threads WHERE PROCESSLIST_ID=$id;" -OutputFile "$dir/$variant-state.txt"
   if (($state -join '') -notmatch 'User sleep') { throw 'Diagnostic session not inside pre-exclusive-read pause.' }
   $where="FROM performance_schema.data_locks d JOIN performance_schema.threads t ON t.THREAD_ID=d.THREAD_ID WHERE t.PROCESSLIST_ID=$id AND d.OBJECT_SCHEMA=DATABASE() AND LOWER(d.OBJECT_NAME)='accounts' AND d.LOCK_TYPE='RECORD'"
   Invoke-MySql $Database -Sql "SELECT d.INDEX_NAME,d.LOCK_TYPE,d.LOCK_MODE,d.LOCK_STATUS,d.LOCK_DATA $where;" -OutputFile "$dir/$variant-record-locks.txt" | Out-Null
   $shared=[int]@(Invoke-MySql $Database -Sql "SELECT COUNT(*) $where AND d.LOCK_MODE LIKE 'S%';")[0]
   $results+="RESULT|EXP-10|$variant|shared_records_before_first_exclusive_read|$shared"
   if (($variant -eq 'original' -and $shared -ne 2) -or ($variant -eq 'corrected' -and $shared -ne 0)) { throw "Unexpected diagnostic lock count $variant : $shared" }
  } finally { Wait-Sessions @($p) -TimeoutSeconds 30 }
 }
 Assert-LabInvariants $Database $dir
} finally {
 Invoke-MySql $Database -Sql ("DROP PROCEDURE IF EXISTS sp_internal_post_transfer;"+[Environment]::NewLine+$shipping) | Out-Null
 Invoke-MySql $Database -File experiments/lab_objects/uninstall.sql | Out-Null
}
Save-Text "$dir/results.txt" ($results -join [Environment]::NewLine)
Save-Text evidence/EXP10-lock-fix/diagnosis.txt ("Raw: $dir"+[Environment]::NewLine+($results -join [Environment]::NewLine))
$results
