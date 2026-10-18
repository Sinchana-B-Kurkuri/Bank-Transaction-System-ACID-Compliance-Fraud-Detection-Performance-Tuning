param([string]$Database='bank_txn_scratch',[string]$StateFile='backup/out/durability_state.json')
. "$PSScriptRoot/../../backup/ps/Common.ps1"
Assert-Scratch $Database
& powershell -NoProfile -File build/rebuild.ps1 -Database $Database -WithSeed | Out-Null
if($LASTEXITCODE){throw 'Scratch rebuild failed.'}
Invoke-MySql -Database $Database -File experiments/lab_objects/setup_lab_accounts.sql | Out-Null
$dir=New-EvidenceDir EXP-03
Invoke-MySql -Database $Database -File experiments/EXP-03_durability/setup_commit.sql -OutputFile "$dir/committed.txt" | Out-Null
$before=Get-RecoverySnapshot $Database
$reference='DUR-UNCOMMITTED-'+(Get-Date -Format HHmmssfff)
$sql="SET @a=(SELECT account_id FROM Accounts WHERE account_number='LAB-0001'); START TRANSACTION; UPDATE Accounts SET balance=balance+7 WHERE account_id=@a; INSERT INTO Transactions(account_id,transaction_type,amount,balance_after,channel,status,reference_no) SELECT @a,'Deposit',7,balance,'Online','Completed','$reference' FROM Accounts WHERE account_id=@a; SELECT 'UNCOMMITTED_READY'; SELECT SLEEP(600); ROLLBACK;"
$p=Start-MySqlSession -Database $Database -Sql $sql -Name uncommitted -Directory $dir
$cid=Get-ConnectionId $p
$ready=$false
for($i=0;$i -lt 100;$i++) {
 if((Get-Content -LiteralPath $p.LabStdout -Raw) -match 'UNCOMMITTED_READY') {$ready=$true;break}
 Start-Sleep -Milliseconds 50
}
if(!$ready){Invoke-MySql -Database $Database -Sql "KILL $cid;" | Out-Null;throw 'Uncommitted fixture did not become ready.'}
$state=@{Database=$Database;Evidence=$dir;Before=$before;Reference=$reference;ClientPid=$p.Id;ConnectionId=$cid;PreparedAt=(Get-Date -Format o);RecoveryExecuted=$false}
Save-RecoveryState $state $StateFile
Save-Text "$dir/before.txt" ($state | ConvertTo-Json -Depth 10)
Write-Output "RESULT|EXP-03|prepared|committed=100|uncommitted_connection=$cid|client_pid=$($p.Id)|expires_after_seconds=600"
