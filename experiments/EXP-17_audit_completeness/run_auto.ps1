param([string]$Database='bank_txn_scratch')
. "$PSScriptRoot/setup.ps1"
. "$PSScriptRoot/mutations.ps1"
. "$PSScriptRoot/teardown.ps1"
Assert-Scratch $Database
$Directory=New-EvidenceDir EXP-17
$script:AuditCreated=@();$script:AuditMaps=@();$toggled=$false
try {
 Initialize-AuditExperiment
 Invoke-MySql -Database $Database -Sql 'SELECT VERSION(),NOW(6),USER();' -OutputFile "$Directory/metadata.txt" | Out-Null
 Run-AuditMutations
 Invoke-MySql -Database $Database -File triggers/lab/drop_audit_triggers.sql | Out-Null
 $toggled=$true
 $before=@(Invoke-MySql -Database $Database -Sql 'SELECT COALESCE(MAX(audit_id),0) FROM Audit_Log;')[0]
 # All three tables have rows loaded before the new watermark with no audit trail.
 Invoke-MySql -Database $Database -Sql "CALL sp_open_account($script:AuditCustomer,$script:AuditBranch,$script:AuditType,2000,NULL,'EXP17-PRE-WM',@a,@n); CALL sp_disburse_loan($script:AuditCustomer,NULL,100,1,12,NULL,@l);" | Out-Null
 $after=@(Invoke-MySql -Database $Database -Sql 'SELECT COALESCE(MAX(audit_id),0) FROM Audit_Log;')[0]
 if($before -ne $after){throw 'Disabled-trigger mutation unexpectedly audited.'}
 Save-Text "$Directory/limit.txt" "audits_before=$before`naudits_after=$after`nMISSING: opening account, opening deposit, unrouted loan while DBA disabled audit triggers. DBA can also TRUNCATE/DROP Audit_Log; trigger guards cannot stop DDL."
 Invoke-MySql -Database $Database -File triggers/lab/create_audit_triggers.sql | Out-Null
 $toggled=$false
 $out=Invoke-MySql -Database $Database -Sql "SET @n=(SELECT COUNT(*) FROM Audit_Log WHERE table_name='Accounts' AND record_pk=(SELECT CAST(account_id AS CHAR) FROM Accounts WHERE account_number='EXP17-PRE-WM')); CALL bank_lab.sp_assert_equal(DATABASE(),'EXP17 pre-watermark row has no audit','0',@n); SELECT detail FROM bank_lab.Experiment_Log WHERE db_name=DATABASE() AND event_type='AUDIT_TRIGGERS_INSTALLED' ORDER BY log_id DESC LIMIT 1;" -OutputFile "$Directory/watermark.txt"
 $out | Where-Object {$_ -like 'TEST|*'}
 if($out -match '^TEST\|FAIL'){throw 'Watermark assertion failed.'}
 Assert-LabInvariants $Database $Directory
 Write-Output 'TEST|PASS|EXP17 honest limit and D5|Missing audit proved; recreated triggers; all six invariants PASS with new watermark'
} finally {
 try {if($toggled){Invoke-MySql -Database $Database -File triggers/lab/create_audit_triggers.sql | Out-Null}}
 finally {Remove-AuditIdentities}
}
Complete-Experiment experiments/EXP-17_audit_completeness $Directory @('LOCALLY TESTED: procedure audit counts, JSON, identities, rejected DML and immutability assertions passed.','LOCALLY TESTED: DBA-disabled trigger gap demonstrated; D5 watermark respected; six invariants PASS.','Temporary users and mappings removed in finally. See EV-EXP17-counts.md and EV-EXP17-json.txt.')
