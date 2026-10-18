param([string]$Database='bank_txn_scratch',[ValidateRange(1,100000)][int]$N=500,[string]$StateFile='backup/out/recovery_state.json')
. "$PSScriptRoot/Common.ps1"
Assert-Scratch $Database
$s=Read-RecoveryState $StateFile
if ($s.Database -ne $Database) {throw 'State database mismatch.'}
$a=@(Invoke-MySql -Database $Database -Sql "SELECT account_id FROM Accounts WHERE account_number='LAB-0001';")[0]
$sql=(1..$N | ForEach-Object {"CALL sp_deposit($a,1.00,'Online',NULL,NULL,NULL,@t,@b);"}) -join "`n"
Invoke-MySql -Database $Database -Sql $sql | Out-Null
$s.S1=Get-RecoverySnapshot $Database
$s.S1.AuditBaseline=Join-Path $script:RepoRoot 'backup/out/audit-S1.jsonl'
Save-AuditBaseline $Database $s.S1.AuditBaseline
Save-RecoveryState $s $StateFile
Save-Text "$($s.Evidence)/S1.json" ($s.S1 | ConvertTo-Json -Depth 10)
Write-Output "RESULT|EXP-16|workload|commits=$N|T1=$($s.S1.Time)"
