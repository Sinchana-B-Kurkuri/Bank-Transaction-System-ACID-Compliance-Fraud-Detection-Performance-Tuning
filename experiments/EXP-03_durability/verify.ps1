param([string]$StateFile='backup/out/durability_state.json')
. "$PSScriptRoot/../../backup/ps/Common.ps1"
$s=Read-RecoveryState $StateFile
Assert-Scratch $s.Database
if(!$s.RecoveryExecuted){throw 'NEEDS MANUAL VERIFICATION: no confirmed crash/restart recorded; ordinary reconnect is not durability proof.'}
$out=Invoke-MySql -Database $s.Database -Sql "SET @durability_reference='$($s.Reference)';`nsource experiments/EXP-03_durability/verify_after_restart.sql" -OutputFile "$($s.Evidence)/after.txt"
$after=Get-RecoverySnapshot $s.Database
$checks=@();foreach($table in @('Accounts','Transactions')) {
 $expected=$s.Before.Tables | Where-Object Table -eq $table
 $actual=$after.Tables | Where-Object Table -eq $table
 $ok=$actual.Rows -eq $expected.Rows -and $actual.Checksum -eq $expected.Checksum
 $checks+="TEST|$(if($ok){'PASS'}else{'FAIL'})|durability $table|rows=$($actual.Rows);checksum=$($actual.Checksum);expected=$($expected.Checksum)"
}
$n=@(Invoke-MySql -Database $s.Database -Sql "SELECT COUNT(*) FROM Transactions WHERE reference_no='$($s.Reference)';")[0]
$checks+="TEST|$(if($n -eq '0'){'PASS'}else{'FAIL'})|uncommitted row absent|rows=$n"
try {
 Invoke-BankMysql -Sql "SELECT LOGGED,PRIO,SUBSYSTEM,DATA FROM performance_schema.error_log WHERE SUBSYSTEM='InnoDB' AND (DATA LIKE '%crash recovery%' OR DATA LIKE '%recovered transaction%' OR DATA LIKE '%Apply batch%') ORDER BY LOGGED DESC LIMIT 100;" | Set-Content "$($s.Evidence)/crash-recovery-log.txt" -Encoding UTF8
} catch {
 try {
  $errorPath=@(Invoke-BankMysql -Sql 'SELECT @@log_error;')[0]
  Get-Content -LiteralPath $errorPath -Tail 1000 -ErrorAction Stop | Select-String 'crash recovery|recovered transaction|Apply batch' | Set-Content "$($s.Evidence)/crash-recovery-log.txt" -Encoding UTF8
 } catch {Save-Text "$($s.Evidence)/crash-recovery-log.txt" 'NEEDS MANUAL VERIFICATION: error_log and .err read failed; use elevated shell.'}
}
Assert-LabInvariants $s.Database $s.Evidence
Save-Text "$($s.Evidence)/verification.txt" ($checks -join "`n")
$checks
if($checks -match '^TEST\|FAIL'){throw 'Durability comparison failed.'}
