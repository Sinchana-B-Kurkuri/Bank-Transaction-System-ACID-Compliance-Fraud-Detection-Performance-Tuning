param([string]$Database='bank_txn',[ValidateSet('Standalone','Integrated')][string]$Mode='Integrated')
. "$PSScriptRoot/../build/mysql_common.ps1"
Assert-BankDatabase $Database
$root=Split-Path $PSScriptRoot -Parent;Push-Location $root
$fail=0;$missing=0
function Acceptance($Name,$Status,$Detail) {
 Write-Output "ACCEPTANCE|$Status|$Name|$Detail"
 if($Status -eq 'FAIL'){$script:fail++}
 if($Status -in @('MISSING','BLOCKED')){$script:missing++}
}
try {
 $routines=@(Invoke-BankMysql -Database $Database -Sql 'SELECT ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE();')
 foreach($name in @('fn_fraud_score','sp_evaluate_fraud','fn_distance_km','fn_amount_zscore','fn_txn_count_window','fn_is_odd_hour','fn_account_age_days','fn_txn_risk_score','fn_risk_level')) {
  Acceptance "Installed B routine $name" $(if($routines -contains $name){'PASS'}else{'MISSING'}) 'Installation inventory only; behavior reported separately'
 }
 $triggers=@(Invoke-BankMysql -Database $Database -Sql "SELECT TRIGGER_NAME,ACTION_ORDER FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() AND EVENT_OBJECT_TABLE='Transactions' AND ACTION_TIMING='AFTER' AND EVENT_MANIPULATION='INSERT';")
 $audit=@($triggers | Where-Object {($_ -split "`t")[0] -eq 'trg_transactions_ai_audit'})
 $fraud=@($triggers | Where-Object {($_ -split "`t")[0] -eq 'trg_transactions_ai_fraud_evaluate'})
 if(!$fraud.Count) { Acceptance 'Fraud trigger ordering' 'MISSING' 'Expected B trigger absent' }
 else {
  $ordered=$audit.Count -eq 1 -and [int](($fraud[0] -split "`t")[1]) -gt [int](($audit[0] -split "`t")[1])
  $follows=[IO.File]::ReadAllText('triggers/fraud/trg_transactions_ai_fraud_evaluate.sql') -match '(?i)FOLLOWS\s+trg_transactions_ai_audit'
  Acceptance 'Fraud trigger ordering' $(if($ordered -and $follows){'PASS'}else{'FAIL'}) 'Installed ACTION_ORDER plus source FOLLOWS'
 }
 if($Mode -eq 'Integrated' -and $routines -contains 'fn_fraud_score') {
  $out=@(Invoke-BankMysql -Database $Database -Sql 'SOURCE tests/functions/03_fraud_score.sql;')
  $out | Write-Output
  Acceptance 'B scoring behavior' $(if(@($out -like 'TEST|FAIL|*').Count){'FAIL'}else{'PASS'}) 'Unmodified B assertions; unconditional summary does not override FAIL'
 }
 if($Mode -eq 'Integrated' -and $fraud.Count -and $routines -contains 'sp_evaluate_fraud') {
  $sql=@'
SOURCE tests/procedures/support/fixture.sql;
SET @n=(SELECT COUNT(*) FROM Fraud_Flags);
CALL sp_deposit(@p3_a,1,'Online',NULL,NULL,NULL,@tx,@bal);
SELECT CONCAT('PROBE|flags|',(SELECT COUNT(*) FROM Fraud_Flags WHERE transaction_id=@tx));
SELECT CONCAT('PROBE|audit|',(SELECT COUNT(*) FROM Audit_Log WHERE table_name='Transactions' AND record_pk=CAST(@tx AS CHAR) AND action_type='INSERT'));
SET @snapshot=CONCAT((SELECT SUM(balance) FROM Accounts),'|',(SELECT COUNT(*) FROM Transactions),'|',(SELECT COUNT(*) FROM Audit_Log),'|',(SELECT COUNT(*) FROM Fraud_Flags),'|',(SELECT COALESCE(SUM(risk_score),0) FROM Account_Risk_Profile));
CALL bank_lab.sp_expect_error(DATABASE(),'integrated fraud transfer rollback','CALL {db}.sp_transfer_funds(@p3_a,@p3_b,1,''Online'',NULL,NULL,NULL,1,@g,@d,@c)',5016);
SELECT CONCAT('PROBE|rollback|',@snapshot=CONCAT((SELECT SUM(balance) FROM Accounts),'|',(SELECT COUNT(*) FROM Transactions),'|',(SELECT COUNT(*) FROM Audit_Log),'|',(SELECT COUNT(*) FROM Fraud_Flags),'|',(SELECT COALESCE(SUM(risk_score),0) FROM Account_Risk_Profile)));
CALL sp_open_account(@p3_c1,@p3_b1,@p3_type,1000,NULL,CONCAT('REVIEW-',LEFT(UUID(),12)),@clean,@number);
SET @clean_tx=(SELECT MAX(transaction_id) FROM Transactions WHERE account_id=@clean);
SET @score_before=(SELECT risk_score FROM Account_Risk_Profile WHERE account_id=@clean);
CALL sp_evaluate_fraud(@clean_tx);
SELECT CONCAT('PROBE|reevaluation|',@score_before,'|',(SELECT risk_score FROM Account_Risk_Profile WHERE account_id=@clean),'|',@score_before=(SELECT risk_score FROM Account_Risk_Profile WHERE account_id=@clean));
'@
  $out=@(Invoke-BankMysql -Database $Database -Sql $sql);$out | Write-Output
  $flags=@($out | Where-Object {$_ -match '^PROBE\|flags\|[1-9]\d*$'}).Count -eq 1
  Acceptance 'Automatic fraud evaluation' $(if($flags -and $out -contains 'PROBE|audit|1'){'PASS'}else{'FAIL'}) 'Real deposit produced flags and exactly one INSERT audit'
  Acceptance 'Fraud rollback participation' $(if($out -contains 'PROBE|rollback|1' -and !@($out -like 'TEST|FAIL|*').Count){'PASS'}else{'FAIL'}) 'Real 5016 rollback: balances, ledger, audit, flags and risk total unchanged'
  $reevaluation=@($out | Where-Object {$_ -like 'PROBE|reevaluation|*'})
  Acceptance 'Fraud reevaluation stability' $(if($reevaluation.Count -eq 1 -and $reevaluation[0] -match '\|1$'){'PASS'}else{'FAIL'}) ($reevaluation -join ';')
 }
 $views=@(Invoke-BankMysql -Database $Database -Sql 'SELECT TABLE_NAME,SECURITY_TYPE FROM information_schema.VIEWS WHERE TABLE_SCHEMA=DATABASE();')
 foreach($name in @('v_customer_account_summary','v_transaction_activity','v_fraud_case_queue')) {
  Acceptance "Installed B view $name" $(if(@($views | Where-Object {($_ -split "`t")[0] -eq $name}).Count){'PASS'}else{'MISSING'}) 'Presence only; no permission certification'
 }
 $grants=@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM mysql.tables_priv WHERE Db=DATABASE() AND User IN ('bank_customer_role','bank_teller_role','bank_manager_role','bank_auditor_role');")[0]
 Acceptance 'Target B role grants' $(if([int]$grants -gt 0){'BLOCKED'}else{'MISSING'}) "Target grant records=$grants; restricted-role behavior requires B repaired target-aware acceptance suite; no global roles installed by this runner"
 if(Test-Path security/01_roles_and_grants.sql) {
  $source=[IO.File]::ReadAllText('security/01_roles_and_grants.sql')
  Acceptance 'B public EXECUTE source contract' $(if($source -match '(?i)GRANT\s+EXECUTE'){'BLOCKED'}else{'FAIL'}) 'Static check only: role source must grant agreed public APIs; never private helpers'
 } else {Acceptance 'B RBAC source' 'MISSING' 'Security script absent'}
} catch {Acceptance 'Runtime acceptance execution' 'FAIL' $_.Exception.Message}
finally {Pop-Location}
Write-Output "TOTAL|ACCEPTANCE_FAIL=$fail|MISSING_OR_BLOCKED=$missing"
if($fail){exit 2};if($missing){exit 2};exit 0
