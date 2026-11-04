param([string]$Database='bank_txn_scratch',[string]$StateFile='backup/out/recovery_state.json')
. "$PSScriptRoot/Common.ps1"
Assert-Scratch $Database
$s=Read-RecoveryState $StateFile
if (!$s.S2 -or $s.Database -ne $Database) {throw 'Run oops_delete before simulating loss.'}
$s.LossTime=@(Invoke-BankMysql -Sql "SELECT DATE_FORMAT(NOW(6),'%Y-%m-%dT%H:%i:%s.%f');")[0]
Save-RecoveryState $s $StateFile
Invoke-BankMysql -Sql 'DROP DATABASE IF EXISTS bank_txn_scratch;'
Write-Output "RESULT|EXP-16|loss|time=$($s.LossTime)|database=bank_txn_scratch"
