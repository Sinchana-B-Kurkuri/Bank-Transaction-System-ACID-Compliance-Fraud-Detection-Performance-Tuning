param([string]$Database='bank_txn_scratch',[string]$StateFile='backup/out/recovery_state.json')
. "$PSScriptRoot/Common.ps1"
Assert-Scratch $Database
$s=Read-RecoveryState $StateFile
if (!$s.S1 -or $s.Database -ne $Database) {throw 'Run workload first.'}
$s.BeforeOops=Get-RecoveryPosition
Invoke-MySql -Database $Database -Sql "SELECT CONCAT('T2|',NOW(6)); DELETE FROM Loans; SELECT CONCAT('DELETED|',ROW_COUNT());" -OutputFile "$($s.Evidence)/oops.txt"
$a=@(Invoke-MySql -Database $Database -Sql "SELECT account_id FROM Accounts WHERE account_number='LAB-0001';")[0]
Invoke-MySql -Database $Database -Sql "CALL sp_deposit($a,2,'Online',NULL,NULL,NULL,@t,@b);" | Out-Null
$s.S2=Get-RecoverySnapshot $Database
$s.S2.AuditBaseline=Join-Path $script:RepoRoot 'backup/out/audit-S2.jsonl'
Save-AuditBaseline $Database $s.S2.AuditBaseline
$log=$s.BeforeOops.File.Replace("'","''")
Invoke-BankMysql -Sql "SHOW BINLOG EVENTS IN '$log' FROM $($s.BeforeOops.Position) LIMIT 30;" | ForEach-Object {$_} | Set-Content "$($s.Evidence)/oops-binlog-events.txt" -Encoding UTF8
Save-RecoveryState $s $StateFile
Save-Text "$($s.Evidence)/S2.json" ($s.S2 | ConvertTo-Json -Depth 10)
Write-Output "RESULT|EXP-16|oops|stop-before-transaction=$($s.BeforeOops.File):$($s.BeforeOops.Position)"
