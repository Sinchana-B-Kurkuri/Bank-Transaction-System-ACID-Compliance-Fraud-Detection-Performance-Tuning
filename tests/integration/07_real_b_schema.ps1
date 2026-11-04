param([string]$Database='bank_txn')
. "$PSScriptRoot/../../build/mysql_common.ps1"
Assert-BankDatabase $Database
$real=@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='Account_Risk_Profile';")[0]
if($real -eq '0') {
 Write-Output 'TEST|PASS|Standalone boundary identified|Account_Risk_Profile absent; no real-B constraint claim made'
 exit 0
}
$sql=@'
SOURCE tests/procedures/support/fixture.sql;
START TRANSACTION;
CALL bank_lab.sp_expect_error(DATABASE(),'real B latitude check','INSERT INTO {db}.Locations(city,country,latitude,longitude) VALUES(''Synthetic'',''Synthetic'',91,0)',3819);
CALL bank_lab.sp_expect_error(DATABASE(),'real B longitude check','INSERT INTO {db}.Locations(city,country,latitude,longitude) VALUES(''Synthetic'',''Synthetic'',0,181)',3819);
CALL bank_lab.sp_expect_error(DATABASE(),'real B rule weight check','INSERT INTO {db}.Fraud_Rules(rule_code,weight) VALUES(UUID(),101)',3819);
CALL bank_lab.sp_expect_error(DATABASE(),'real B account risk check','INSERT INTO {db}.Account_Risk_Profile(account_id,risk_score) VALUES(@p3_a,101)',3819);
CALL bank_lab.sp_expect_error(DATABASE(),'real B map exactly one actor','INSERT INTO {db}.DB_User_Map(db_login,actor_type,employee_id,customer_id) VALUES(CONCAT(''p6-'',UUID()),''Employee'',@p3_t1,@p3_c1)',3819);
CALL bank_lab.sp_expect_error(DATABASE(),'real B approval distinct accounts','INSERT INTO {db}.Transaction_Approvals(requested_by_actor_type,requested_by_customer_id,from_account_id,to_account_id,amount) VALUES(''Customer'',@p3_c1,@p3_a,@p3_a,100000)',3819);
CALL bank_lab.sp_expect_error(DATABASE(),'real B approval requester check','INSERT INTO {db}.Transaction_Approvals(requested_by_actor_type,from_account_id,to_account_id,amount) VALUES(''Customer'',@p3_a,@p3_b,100000)',3819);
CALL bank_lab.sp_expect_error(DATABASE(),'real B approval requester FK','INSERT INTO {db}.Transaction_Approvals(requested_by_actor_type,requested_by_customer_id,from_account_id,to_account_id,amount) VALUES(''Customer'',-1,@p3_a,@p3_b,100000)',1452);
CALL bank_lab.sp_expect_error(DATABASE(),'real B risk profile FK','INSERT INTO {db}.Account_Risk_Profile(account_id) VALUES(-1)',1452);
CALL bank_lab.sp_expect_error(DATABASE(),'real B ground truth FK','INSERT INTO {db}.Fraud_Ground_Truth(transaction_id,is_fraud) VALUES(-1,0)',1452);
ROLLBACK;
'@
$out=@(Invoke-BankMysql -Database $Database -Sql $sql)
$out | Where-Object {$_ -like 'TEST|*'}
if($out -match '^TEST\|FAIL'){exit 1}
