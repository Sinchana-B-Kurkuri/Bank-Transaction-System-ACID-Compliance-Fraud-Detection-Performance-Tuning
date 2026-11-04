param([string]$Database='bank_txn')
. "$PSScriptRoot/../../build/mysql_common.ps1"
Assert-BankDatabase $Database
$account=[int](@(Invoke-BankMysql -Database $Database -Sql "SELECT account_id FROM Accounts WHERE account_number='SEED-0001';")[0])
$lines=@(Invoke-BankMysql -Database $Database -Sql "CALL sp_generate_statement($account,DATE_SUB(CURDATE(),INTERVAL 180 DAY),CURDATE());")
$opening=@($lines | Where-Object {($_ -split "`t").Count -eq 3})
$rows=@($lines | Where-Object {($_ -split "`t").Count -eq 8})
$correct=$opening.Count -eq 1 -and $rows.Count -gt 0
foreach ($row in $rows) {
 $values=$row -split "`t"
 if ([decimal]$values[4] -ne [decimal]$values[7]) {$correct=$false}
}
$status=if ($correct) {'PASS'} else {'FAIL'}
Write-Output "TEST|$status|statement actual running balances|Parsed both actual result sets; compared every returned running_balance to balance_after"
if (!$correct) {exit 1}
