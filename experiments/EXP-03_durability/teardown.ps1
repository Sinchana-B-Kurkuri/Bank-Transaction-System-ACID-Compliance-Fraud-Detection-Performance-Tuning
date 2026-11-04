param([string]$StateFile='backup/out/durability_state.json')
. "$PSScriptRoot/../../backup/ps/Common.ps1"
$s=Read-RecoveryState $StateFile; Assert-Scratch $s.Database
# Only the connection opened by setup.ps1, additionally calibrated by processlist.
$n=@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE ID=$($s.ConnectionId) AND DB='bank_txn_scratch' AND INFO LIKE '%SLEEP(600)%';")[0]
if($n -eq '1'){Invoke-MySql -Database $s.Database -Sql "KILL $($s.ConnectionId);" | Out-Null}
Assert-LabInvariants $s.Database $s.Evidence
Write-Output 'RESULT|EXP-03|teardown|own sleeping connection removed; no server crash executed'
