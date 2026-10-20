param([string]$Database='bank_txn_scratch')
# Bounded smoke profile, NOT a substitute for full EXP-01..10 measurements.
. "$PSScriptRoot/lib/Common.ps1"
Assert-BankDatabase $Database
$directory=Join-Path $RepoRoot ('evidence/quick/'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
[void][IO.Directory]::CreateDirectory($directory)
$sessions=@();$failed=$false
try {
 $ids=@(Invoke-MySql -Database $Database -Sql "SELECT account_id FROM Accounts WHERE account_number IN ('SEED-0001','SEED-0002') AND status='Active' ORDER BY account_number;")
 if ($ids.Count -ne 2) { throw 'Quick requires two Active seeded accounts; it never rebuilds or installs lab objects.' }
 $a=[int]$ids[0];$b=[int]$ids[1]
 $before=@(Invoke-MySql -Database $Database -Sql "SELECT CONCAT(SUM(balance),'|',(SELECT COUNT(*) FROM Transactions),'|',(SELECT COUNT(*) FROM Audit_Log),'|',(SELECT COUNT(*) FROM Fraud_Flags)) FROM Accounts;")
 $failureSql="SET SESSION innodb_lock_wait_timeout=3;`n"
 for($i=0;$i -lt 3;$i++) { $failureSql+="CALL bank_lab.sp_expect_error(DATABASE(),'Quick atomicity $i','CALL {db}.sp_transfer_funds($a,$b,1,''Online'',NULL,NULL,NULL,1,@g,@d,@c)',5016);`n" }
 $out=@(Invoke-MySql -Database $Database -Sql $failureSql -OutputFile "$directory/atomicity.txt")
 $after=@(Invoke-MySql -Database $Database -Sql "SELECT CONCAT(SUM(balance),'|',(SELECT COUNT(*) FROM Transactions),'|',(SELECT COUNT(*) FROM Audit_Log),'|',(SELECT COUNT(*) FROM Fraud_Flags)) FROM Accounts;")
 if (@($out -match '^TEST\|PASS').Count -ne 3 -or ($before -join '') -cne ($after -join '')) { throw 'Quick atomicity checks failed.' }
 $out | Write-Output
 $ledger=[int64]@(Invoke-MySql -Database $Database -Sql 'SELECT COUNT(*) FROM Transactions;')[0]
 foreach($pair in @(@($a,$b),@($b,$a))) {
  $sql="SET SESSION innodb_lock_wait_timeout=3; SET @lab_sleep_seconds=0.05;`n"
  for($i=0;$i -lt 5;$i++) { $sql+="CALL sp_transfer_funds($($pair[0]),$($pair[1]),1,'Online',NULL,NULL,NULL,2,@g,@d,@c); SELECT 'RESULT|QUICK|ordered|completed|1';`n" }
  $sessions+=Start-MySqlSession -Database $Database -Sql $sql -Name "ordered-$($sessions.Count)" -Directory $directory
 }
 Wait-Sessions -Sessions $sessions -TimeoutSeconds 45
 $completed=0
 foreach($session in $sessions) { $completed+=@(Get-Content $session.LabStdout | Where-Object {$_ -eq 'RESULT|QUICK|ordered|completed|1'}).Count }
 $delta=[int64]@(Invoke-MySql -Database $Database -Sql 'SELECT COUNT(*) FROM Transactions;')[0]-$ledger
 if ($completed -ne 10 -or $delta -ne 20) { throw "Quick ordered workload incomplete: completed=$completed; ledger_delta=$delta" }
 Write-Output 'TEST|PASS|Quick ordered concurrency|2 real sessions, 5 transfers each, 20 ledger rows'
 Assert-LabInvariants -Database $Database -Directory $directory
 Get-Content "$directory/invariants.txt" | Where-Object {$_ -like 'TEST|*'} | Write-Output
 Save-Text "$directory/summary.md" "# Quick measured smoke profile`nDatabase: $Database`n3 injected rollback checks; 2 concurrent sessions x 5 ordered transfers; 6 invariants PASS. No rebuild, installation, global changes, full drivers, throughput, crash or PITR. This does not certify full experiments."
} catch {
 $failed=$true
 Save-Text "$directory/failure.txt" $_.Exception.ToString()
 Write-Output "TEST|FAIL|Quick|$($_.Exception.Message)"
} finally {
 if (@($sessions | Where-Object {!$_.HasExited}).Count) { Wait-Sessions -Sessions $sessions -TimeoutSeconds 1 -AllowErrors }
 Write-Output "QUICK|evidence=$directory"
}
if($failed){exit 1}
