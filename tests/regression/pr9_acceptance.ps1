# Safe PR9 acceptance. Default has no global roles/users/grants.
# -WithRestrictedRoles requires explicit approval of security/README.md's cleanup plan.
param([switch]$WithRestrictedRoles)
$ErrorActionPreference='Stop'
$workspace=(Get-Location).ProviderPath
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Push-Location $root
. "$root/build/mysql_common.ps1"
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile("$root/tests/regression/error1222_seed.ps1",[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Focused harness parse failed.'}
foreach($f in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$false)){Invoke-Expression $f.Extent.Text}
# Same owned-name/native execution/cleanup functions as the tracked focused harness.
# The administrative-keyword scan ignores quoted SQL data so we can COMPILE the
# RBAC preview containing 'GRANT ...' strings. Preview always forces apply=0, and
# actual CREATE ROLE/USER, GRANT, global changes etc. remain forbidden.
function Convert-IsolatedSql([string]$Sql) {
 Assert-OwnedName
 $Sql=Expand-BankSqlSource -Sql $Sql
 $Sql=[regex]::Replace($Sql,'(?i)\bbank_lab\b',$script:database)
 if($Sql -match '(?i)\bbank_txn(?:_scratch)?\b|\bbank_lab\b'){throw 'Protected database reference.'}
 $body=[regex]::Replace($Sql,'(?s)/\*.*?\*/|(?m)^\s*--[^\r\n]*','')
 $body=[regex]::Replace($body,"'(?:''|[^'])*'","''")
 # The audited RBAC preview compiles static CREATE ROLE under IF v_apply=1.
 # It is the ONLY permitted global-DDL definition, with apply pinned to0 by this caller.
 # CREATE ROLE is not supported by MySQL PREPARE; no role DDL is executed here.
 if($Sql -match '(?s)^SET @rbac_apply=0,@rbac_role_suffix=' -and $Sql -match 'CREATE PROCEDURE sp_install_rbac\(\)') {
  if([regex]::Matches($body,"(?i)CREATE ROLE IF NOT EXISTS ''@'';").Count -ne 4){throw 'RBAC static role definition inventory changed.'}
  $body=[regex]::Replace($body,"(?i)CREATE ROLE IF NOT EXISTS ''@'';",'')
 }
 if($body -match '(?i)\b(?:CREATE|ALTER|DROP)\s+(?:USER|ROLE)\b|\b(?:GRANT|REVOKE|SHUTDOWN|KILL)\b|\bSET\s+(?:GLOBAL|PERSIST)\b|\bFLUSH\b'){throw 'Global privilege/server operation forbidden.'}
 foreach($m in [regex]::Matches($body,'(?i)\b(?:CREATE|DROP)\s+(?:DATABASE|SCHEMA)\s+(?:IF\s+(?:NOT\s+)?EXISTS\s+)?`?(\w+)')){if($m.Groups[1].Value -cne $script:database){throw 'DDL outside owned schema.'}}
 foreach($m in [regex]::Matches($body,'(?i)\bUSE\s+`?(\w+)')){if($m.Groups[1].Value -cne $script:database){throw 'USE outside owned schema.'}}
 return $Sql
}
$utf8=[Text.UTF8Encoding]::new($false)
$directory=Join-Path (Join-Path $root 'evidence/reviews/PR9-final-fixes') ((Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($directory)
$database='bank_b_1222_'+[guid]::NewGuid().ToString('N')+'_after'
$owner=[guid]::NewGuid().ToString('N');$owned=$false;$marker=$false
$pass=0;$fail=0;$results=[Collections.Generic.List[string]]::new()
$sqlPass=0;$sqlFail=0;$sqlErrors=0;$formatErrors=0
$fileResults=[Collections.Generic.List[object]]::new()
if (!$env:BANK_MYSQL_CNF) { throw 'Set BANK_MYSQL_CNF to an external option file.' }
$optionFile=(Resolve-Path -LiteralPath $env:BANK_MYSQL_CNF).ProviderPath
$client=if($env:BANK_MYSQL_BIN){(Resolve-Path -LiteralPath $env:BANK_MYSQL_BIN).ProviderPath}else{(Get-Command mysql -CommandType Application -ErrorAction Stop).Source}
function Read-Assertions($Result) {
 foreach($line in ($Result.Out -split '\r?\n' | Where-Object {$_ -like 'TEST|*'})){
  $script:results.Add($line);Write-Output $line
  if($line -like 'TEST|PASS|*'){$script:pass++}else{$script:fail++}
 }
}
try {
 $install=Convert-IsolatedSql 'SOURCE build/run_all.sql;'
 $r=Invoke-Required 'SELECT VERSION(),@@version_comment,NOW(6),DATABASE();' 'environment' -Admin
 if($r.Out -notmatch '^8\.4\.11\s'){throw 'Expected real MySQL 8.4.11.'}
 $r=Invoke-Required "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$database';" 'preflight' -Admin
 if($r.Out.Trim() -ne '0'){throw 'Refusing existing schema.'}
 Invoke-Required "CREATE DATABASE $database CHARACTER SET utf8mb4;" 'create' -Admin | Out-Null;$owned=$true
 Invoke-Required "CREATE TABLE _error1222_owner(owner_token CHAR(32) NOT NULL);INSERT INTO _error1222_owner VALUES('$owner');" 'owner' | Out-Null;$marker=$true
 Invoke-Required $install 'integrated-install' | Out-Null
 Test-Result 'real Integrated baseline installation' $true 'Actual build/run_all.sql expanded; helper schema relocated only'
 foreach($folder in @('schema','functions','triggers','procedures','invariants','integration')){
  foreach($file in Get-ChildItem "tests/$folder" -Filter '*.sql' -File | Where-Object Name -Match '^\d\d_' | Sort-Object Name){
   $relative=$file.FullName.Substring($root.Length+1).Replace('\','/')
   $name='suite-'+$folder+'-'+$file.BaseName
   $restore=$false
   try {
    if($relative -eq 'tests/schema/01_negative_constraints.sql'){
     Invoke-Required 'DROP TRIGGER trg_transactions_bu_immutable;' 'native-constraint-guard-suspend' | Out-Null;$restore=$true
    }
    $r=Invoke-IsolatedSql "SET @test_run_id='pr9-final-fixes';`nSOURCE $relative;" $name
   }finally{if($restore){Invoke-Required 'SOURCE triggers/guards/trg_transactions_bu_immutable.sql;' 'native-constraint-guard-restore' | Out-Null}}
   $p=@($r.Out -split '\r?\n' | Where-Object {$_ -like 'TEST|PASS|*'}).Count
   $f=@($r.Out -split '\r?\n' | Where-Object {$_ -like 'TEST|FAIL|*'}).Count
   $sqlPass+=$p;$sqlFail+=$f
   if($r.Code -ne 0){$sqlErrors++}
   $format=($p+$f -eq 0);if($format){$formatErrors++}
   $fileResults.Add([pscustomobject]@{File=$relative;Pass=$p;Fail=$f;SqlExit=$r.Code;NoTestLines=$format;BarePass=@($r.Out -split '\r?\n' | Where-Object {$_ -eq 'PASS'}).Count})
   Write-Output "SQLFILE|$relative|PASS=$p|FAIL=$f|EXIT=$($r.Code)|NO_TEST_LINES=$format"
  }
 }
 Test-Result 'existing Integrated SQL assertions' ($sqlFail -eq 0 -and $sqlErrors -eq 0) "emitted PASS=$sqlPass; FAIL=$sqlFail; SQL-error files=$sqlErrors"
 Test-Result 'SQL runner result-line compatibility' ($formatErrors -eq 0) "files without TEST lines=$formatErrors"
 $required=@('fn_distance_km','fn_amount_zscore','fn_txn_count_window','fn_is_odd_hour','fn_account_age_days','fn_txn_risk_score','fn_risk_level')
 $list=($required | ForEach-Object {"'$_'"}) -join ','
 $r=Invoke-Required "SELECT SPECIFIC_NAME,ORDINAL_POSITION,CONCAT(COALESCE(PARAMETER_NAME,'RETURN'),'=',LOWER(REPLACE(DTD_IDENTIFIER,' ',''))),COALESCE(PARAMETER_MODE,'RETURN') FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME IN ($list) ORDER BY SPECIFIC_NAME,ORDINAL_POSITION;SELECT ROUTINE_NAME,IS_DETERMINISTIC,SQL_DATA_ACCESS,SECURITY_TYPE FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME IN ($list);" 'function-signatures'
 $expected=@{
  fn_distance_km='RETURN=decimal(10,3);p_lat1=decimal(9,6);p_lon1=decimal(9,6);p_lat2=decimal(9,6);p_lon2=decimal(9,6)'
  fn_amount_zscore='RETURN=decimal(10,4);p_amount=decimal(14,2);p_mean=decimal(14,4);p_stddev=decimal(14,4)'
  fn_txn_count_window='RETURN=int;p_account_id=int;p_as_of=datetime;p_window_minutes=int'
  fn_is_odd_hour='RETURN=tinyint;p_timestamp=datetime'
  fn_account_age_days='RETURN=int;p_account_id=int;p_as_of=datetime'
  fn_txn_risk_score='RETURN=decimal(5,2);p_amount=decimal(14,2);p_channel=varchar(10);p_device_trusted=tinyint(1);p_account_risk=decimal(5,2)'
  fn_risk_level='RETURN=varchar(10);p_score=decimal(5,2)'
 }
 foreach($name in $required){
  $rows=@($r.Out -split '\r?\n' | Where-Object {$_ -match "^$name`t\d+`t"} | ForEach-Object {($_ -split "`t")[2]})
  Test-Result "signature $name" (($rows -join ';') -eq $expected[$name]) ($rows -join ';')
 }
 $functionChecks=@'
CALL bank_lab.sp_assert_true(DATABASE(),'distance normal and NULL',fn_distance_km(0,0,0,1) BETWEEN 111 AND 112 AND fn_distance_km(NULL,0,0,0) IS NULL,'Haversine and NULL');
CALL bank_lab.sp_assert_true(DATABASE(),'zscore normal and zero deviation',fn_amount_zscore(150,100,25)=2 AND fn_amount_zscore(50,100,25)=-2 AND fn_amount_zscore(1,0,0)=0,'Signed score and zero guard');
CALL bank_lab.sp_assert_true(DATABASE(),'odd hour boundaries',fn_is_odd_hour('2026-01-01 05:59:59')=1 AND fn_is_odd_hour('2026-01-01 06:00:00')=0 AND fn_is_odd_hour('2026-01-01 22:00:00')=1 AND fn_is_odd_hour(NULL)=0,'Boundary hours');
CALL bank_lab.sp_assert_true(DATABASE(),'risk level boundaries',fn_risk_level(29.99)='Low' AND fn_risk_level(30)='Medium' AND fn_risk_level(60)='High' AND fn_risk_level(85)='Critical','Four ranges');
CALL bank_lab.sp_assert_true(DATABASE(),'transaction risk score normal and capped',fn_txn_risk_score(100,'Online',FALSE,0)=30 AND fn_txn_risk_score(50000,'Mobile',FALSE,100)=100,'Current implemented scoring formula');
SET @seed=(SELECT account_id FROM Accounts WHERE account_number='SEED-0001');
CALL bank_lab.sp_assert_true(DATABASE(),'age normal missing and NULL',fn_account_age_days(@seed,DATE_ADD(CURDATE(),INTERVAL 10 DAY))=10 AND fn_account_age_days(-1,NOW()) IS NULL AND fn_account_age_days(NULL,NOW()) IS NULL,'As-of date and missing account');
CALL bank_lab.sp_assert_true(DATABASE(),'count window invalid inputs',fn_txn_count_window(@seed,NOW(),0)=0 AND fn_txn_count_window(NULL,NOW(),10)=0 AND fn_txn_count_window(-1,NOW(),10)=0,'Invalid windows/accounts');
SET @customer=(SELECT customer_id FROM Customers WHERE email='seed.customer.1@example.invalid');
SET @branch=(SELECT branch_id FROM Branches WHERE ifsc_code='SYNB0000001');
SET @type=(SELECT account_type_id FROM Account_Types WHERE type_name='Savings');
CALL sp_open_account(@customer,@branch,@type,2000,NULL,'CORRECT-CLEAN',@clean,@n);
SET @tx=(SELECT transaction_id FROM Transactions WHERE account_id=@clean);
CALL bank_lab.sp_assert_equal(DATABASE(),'count window one opening','1',fn_txn_count_window(@clean,NOW(),10));
SET @risk1=(SELECT risk_score FROM Account_Risk_Profile WHERE account_id=@clean);
CALL sp_evaluate_fraud(@tx);
SET @risk2=(SELECT risk_score FROM Account_Risk_Profile WHERE account_id=@clean);
CALL sp_evaluate_fraud(@tx);
SET @risk3=(SELECT risk_score FROM Account_Risk_Profile WHERE account_id=@clean);
SELECT CONCAT('OBSERVATION|reevaluation|',@risk1,'|',@risk2,'|',@risk3);
CALL bank_lab.sp_assert_true(DATABASE(),'reevaluation stable without new activity',@risk1=@risk2 AND @risk2=@risk3,'Same account and transaction, two actual calls');
SET @rule=(SELECT rule_id FROM Fraud_Rules WHERE rule_code='HIGH_AMOUNT');
SET @params=(SELECT param_json FROM Fraud_Rules WHERE rule_id=@rule);
UPDATE Fraud_Rules SET param_json=JSON_OBJECT('minimum_amount',1000000) WHERE rule_id=@rule;
CALL sp_deposit(@clean,6000,'Online',NULL,NULL,NULL,@tx,@bal);
CALL bank_lab.sp_assert_equal(DATABASE(),'configured HIGH_AMOUNT threshold','0',(SELECT COUNT(*) FROM Fraud_Flags WHERE transaction_id=@tx AND rule_id=@rule));
UPDATE Fraud_Rules SET param_json=@params WHERE rule_id=@rule;
'@
 Read-Assertions (Invoke-Required $functionChecks 'function-behavior-and-reevaluation')
 $identity=@'
START TRANSACTION;
SET @c1=(SELECT customer_id FROM Customers WHERE email='seed.customer.1@example.invalid');
SET @c2=(SELECT customer_id FROM Customers WHERE email='seed.customer.2@example.invalid');
SET @employee=(SELECT employee_id FROM Employees WHERE email='teller.one@example.invalid');
SET @login=USER(),@bare=SUBSTRING_INDEX(USER(),'@',1);
DELETE FROM DB_User_Map WHERE BINARY SUBSTRING_INDEX(db_login,'@',1)=BINARY @bare;
CALL bank_lab.sp_assert_equal(DATABASE(),'unmapped customer view empty','0',(SELECT COUNT(*) FROM v_customer_account_summary));
INSERT INTO DB_User_Map(db_login,actor_type,customer_id) VALUES(@login,'Customer',@c1),(@bare,'Customer',@c2);
CALL sp_resolve_actor(USER(),@actor,@e,@c);
CALL bank_lab.sp_assert_true(DATABASE(),'exact identity agrees with A resolver',@actor='Customer' AND @c=@c1 AND fn_resolved_customer_id(USER())=@c1 AND fn_resolved_employee_id(USER()) IS NULL,'Exact beats bare');
CALL bank_lab.sp_assert_true(DATABASE(),'customer summary scoped',(SELECT COUNT(*)>0 AND SUM(customer_id<>@c1)=0 FROM v_customer_account_summary),'Mapped customer only');
CALL bank_lab.sp_assert_true(DATABASE(),'customer activity scoped',(SELECT COUNT(*)>0 AND SUM(a.customer_id<>@c1)=0 FROM v_transaction_activity v JOIN Accounts a ON a.account_id=v.account_id),'Exact customer only; bare conflict excluded');
DELETE FROM DB_User_Map WHERE db_login=@login;
CALL bank_lab.sp_assert_equal(DATABASE(),'bare identity fallback',CAST(@c2 AS CHAR),fn_resolved_customer_id(USER()));
DELETE FROM DB_User_Map WHERE db_login=@bare;
INSERT INTO DB_User_Map(db_login,actor_type,customer_id) VALUES(CONCAT(@bare,'@synthetic-a'),'Customer',@c1),(CONCAT(@bare,'@synthetic-b'),'Customer',@c2);
CALL bank_lab.sp_assert_true(DATABASE(),'ambiguous identity denied',fn_resolved_customer_id(USER()) IS NULL AND (SELECT COUNT(*) FROM v_transaction_activity)=0,'Conflicting host variants yield no actor');
DELETE FROM DB_User_Map WHERE BINARY SUBSTRING_INDEX(db_login,'@',1)=BINARY @bare;
INSERT INTO DB_User_Map(db_login,actor_type,customer_id) VALUES(UPPER(@login),'Customer',@c1);
CALL sp_resolve_actor(USER(),@actor,@e,@c);
CALL bank_lab.sp_assert_true(DATABASE(),'case-sensitive identity agrees',@actor='System' AND fn_resolved_customer_id(USER()) IS NULL AND (SELECT COUNT(*) FROM v_customer_account_summary)=0,'Different username case does not match');
DELETE FROM DB_User_Map WHERE db_login=UPPER(@login);
INSERT INTO DB_User_Map(db_login,actor_type,employee_id) VALUES(@login,'Employee',@employee);
CALL bank_lab.sp_assert_true(DATABASE(),'employee activity branch scoped',(SELECT COUNT(*)>0 AND SUM(a.branch_id<>e.branch_id)=0 FROM v_transaction_activity v JOIN Accounts a ON a.account_id=v.account_id JOIN Employees e ON e.employee_id=@employee),'Active mapped employee own branch');
UPDATE Employees SET is_active=FALSE WHERE employee_id=@employee;
CALL bank_lab.sp_assert_equal(DATABASE(),'inactive employee activity empty','0',(SELECT COUNT(*) FROM v_transaction_activity));
ROLLBACK;
'@
 Read-Assertions (Invoke-Required $identity 'view-identity-diagnostics')
 function Probe-Statement([string]$Name,[string]$Mapping,[string]$Target,[int]$ExpectedError,[switch]$Inactive,[switch]$CheckCustomerDenial) {
  $mappingSql=switch($Mapping){
   'Customer' { "INSERT INTO DB_User_Map(db_login,actor_type,customer_id) SELECT USER(),'Customer',customer_id FROM Customers WHERE email='seed.customer.1@example.invalid';" }
   'Teller' { "INSERT INTO DB_User_Map(db_login,actor_type,employee_id) SELECT USER(),'Employee',employee_id FROM Employees WHERE email='teller.one@example.invalid';" }
   'Manager' { "INSERT INTO DB_User_Map(db_login,actor_type,employee_id) SELECT USER(),'Employee',employee_id FROM Employees WHERE email='manager.one@example.invalid';" }
   'System' { '' }
  }
  $inactiveSql=if($Inactive){"UPDATE Employees SET is_active=FALSE WHERE employee_id=(SELECT employee_id FROM DB_User_Map WHERE db_login=USER());"}else{''}
  $sql="START TRANSACTION; DELETE FROM DB_User_Map WHERE BINARY SUBSTRING_INDEX(db_login,'@',1)=BINARY SUBSTRING_INDEX(USER(),'@',1); $mappingSql $inactiveSql CALL sp_resolve_actor(USER(),@actor,@employee,@customer);SELECT CONCAT('ACTOR|',@actor,'|',COALESCE(@employee,0),'|',COALESCE(@customer,0)); SET @target=(SELECT account_id FROM Accounts WHERE account_number='$Target'); CALL sp_generate_statement(@target,CURDATE(),CURDATE());ROLLBACK;"
  $r=Invoke-IsolatedSql $sql $Name
  $rows=@($r.Out -split '\r?\n' | Where-Object {($_ -split "`t").Count -eq 8}).Count
  $actual=if($r.Err -match 'ERROR (\d+)'){[int]$Matches[1]}else{0}
  if($CheckCustomerDenial){Test-Result 'customer foreign statement denied' ($r.Code -ne 0 -and $rows -eq 0) "Native errno=$actual; data rows=$rows"}
  $ok=if($ExpectedError -eq 0){$r.Code -eq 0 -and $rows -gt 0}else{$r.Code -ne 0 -and $actual -eq $ExpectedError -and $rows -eq 0}
  Test-Result $Name $ok "Native errno=$actual; expected=$ExpectedError; data rows=$rows; privileged actor-map diagnostic, not restricted authentication"
 }
 Probe-Statement 'statement-customer-own' 'Customer' 'SEED-0001' 0
 Probe-Statement 'statement-customer-foreign-error-contract' 'Customer' 'SEED-0002' 5010 -CheckCustomerDenial
 Probe-Statement 'statement-teller-own-branch' 'Teller' 'SEED-0001' 0
 Probe-Statement 'statement-teller-other-branch' 'Teller' 'SEED-0002' 5010
 Probe-Statement 'statement-inactive-teller' 'Teller' 'SEED-0001' 5010 -Inactive
 Probe-Statement 'statement-manager-own-branch' 'Manager' 'SEED-0001' 0
 Probe-Statement 'statement-manager-other-branch' 'Manager' 'SEED-0002' 5010
 Probe-Statement 'statement-inactive-manager' 'Manager' 'SEED-0001' 5010 -Inactive
 Probe-Statement 'statement-System-backward-compatibility' 'System' 'SEED-0001' 0
 $r=Invoke-Required "SET @rbac_apply=0,@rbac_role_suffix='_pr9_01234567';`nSOURCE security/01_roles_and_grants.sql;" 'native-rbac-preview'
 $plan=@($r.Out -split '\r?\n' | Where-Object {$_ -like 'RBAC|PLAN|*'} | ForEach-Object {$_.Substring('RBAC|PLAN|'.Length)})
 Test-Result 'RBAC native preview compiles' ($plan.Count -eq 45) "Native exit=$($r.Code); planned statements=$($plan.Count); apply=0"
 Test-Result 'RBAC four intended roles' (@($plan | Where-Object {$_ -like 'CREATE ROLE*'}).Count -eq 4) 'Customer/teller/manager/auditor; uniquely suffixed plan only'
 Test-Result 'RBAC public-only EXECUTE plan' (@($plan | Where-Object {$_ -like 'GRANT EXECUTE*'}).Count -eq 32 -and !($plan -match 'sp_internal_|sp_evaluate_fraud|\*')) 'Explicit reviewed public procedures only; no wildcard'
 Test-Result 'RBAC nine intended SELECT grants' (@($plan | Where-Object {$_ -like 'GRANT SELECT*'}).Count -eq 9) 'Eight view grants and existing read-only auditor Audit_Log'
 $r=Invoke-Required "SET @rbac_apply=0,@rbac_role_suffix='_pr9_01234567';`nSOURCE security/01_roles_and_grants.sql;" 'native-rbac-preview-second'
 $secondPlan=@($r.Out -split '\r?\n' | Where-Object {$_ -like 'RBAC|PLAN|*'} | ForEach-Object {$_.Substring('RBAC|PLAN|'.Length)})
 Test-Result 'RBAC preview repeatable without residual helper' (($plan -join "`n") -ceq ($secondPlan -join "`n")) 'Same complete plan on second source; no global DDL executed'
 $parseSql=($plan | Where-Object {$_ -like 'GRANT *'} | ForEach-Object {"SET @pr9_parse_sql='"+$_.Replace("'","''")+"'; PREPARE pr9_parse_probe FROM @pr9_parse_sql; DEALLOCATE PREPARE pr9_parse_probe;"}) -join "`n"
 $r=Invoke-IsolatedSql $parseSql 'native-rbac-plan-prepare-only'
 Test-Result 'RBAC planned grants native syntax' ($r.Code -eq 0) "GRANT PREPARE/DEALLOCATE only, never EXECUTE; CREATE ROLE compiled statically; native exit=$($r.Code); $($r.Err.Trim())"
 $procs=@($plan | Where-Object {$_ -like 'GRANT EXECUTE*'} | ForEach-Object {if($_ -match '\.\x60([^\x60]+)\x60 TO'){ $Matches[1] }} | Sort-Object -Unique)
 $inList=($procs | ForEach-Object {"'$_'"}) -join ','
 $r=Invoke-Required "SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_TYPE='PROCEDURE' AND SECURITY_TYPE='DEFINER' AND ROUTINE_NAME IN ($inList);" 'rbac-public-contract'
 Test-Result 'RBAC grants name installed DEFINER public APIs' ([int]$r.Out.Trim() -eq $procs.Count -and $procs.Count -eq 16) 'No fabricated/missing/private procedure in EXECUTE plan'
 $r=Invoke-Required "SELECT (SELECT COUNT(*) FROM mysql.tables_priv WHERE Db=DATABASE() AND User LIKE 'bank_%_role_pr9_01234567'),(SELECT COUNT(*) FROM mysql.procs_priv WHERE Db=DATABASE() AND User LIKE 'bank_%_role_pr9_01234567');SELECT ROUTINE_NAME,SECURITY_TYPE FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME IN ('sp_generate_statement','sp_resolve_actor','sp_install_rbac');SELECT TABLE_NAME,SECURITY_TYPE FROM information_schema.VIEWS WHERE TABLE_SCHEMA=DATABASE();" 'rbac-installed-metadata'
 $grantLine=@($r.Out -split '\r?\n')[0]
 Test-Result 'RBAC preview leaves privileges unchanged' ($grantLine -eq "0`t0") "View/procedure grant counts=$grantLine; apply intentionally not executed"
 $r=Invoke-Required "SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='sp_install_rbac';" 'rbac-no-residual-helper'
 Test-Result 'RBAC transient helper removed' ($r.Out.Trim() -eq '0') 'Preview leaves no administrative helper callable by roles'
 $r=Invoke-Required "SELECT CONCAT('SCORING|',fn_fraud_score(100,'Online',FALSE,0),'|',fn_txn_risk_score(100,'Online',FALSE,0));" 'public-versus-evaluator-scoring'
 Write-Output $r.Out.Trim()
 Test-Result 'legacy helper agrees with evaluator scoring' ($r.Out.Trim() -eq 'SCORING|30.00|30.00') 'User-approved +20 untrusted and +10 digital'
 if($WithRestrictedRoles){
  . "$root/tests/regression/support/pr9_rbac.ps1"
  Test-Pr9RestrictedRbac
 }else{
  Write-Output 'PENDING|restricted customer/teller/manager logins|Use -WithRestrictedRoles only after explicit approval of the isolated cleanup plan; actor-map checks do not certify restricted-role access'
 }
 $core="'Branches','Employees','Customers','Account_Types','Accounts','Transactions','Loans','Fraud_Flags','Audit_Log'"
 $r=Invoke-Required "SELECT TABLE_NAME,INDEX_NAME,NON_UNIQUE,SEQ_IN_INDEX,COLUMN_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ($core) ORDER BY TABLE_NAME,INDEX_NAME,SEQ_IN_INDEX;SELECT CONCAT('OPTIONAL|',COUNT(DISTINCT INDEX_NAME)) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND INDEX_NAME LIKE 'idx\\_%';" 'baseline-index-inventory'
 $rows=@($r.Out -split '\r?\n' | Where-Object {($_ -split "`t").Count -eq 5})
 $fk=Invoke-Required "SELECT CONCAT(TABLE_NAME,'.',COLUMN_NAME) FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ($core) AND REFERENCED_TABLE_NAME IS NOT NULL;" 'baseline-fk-columns'
 $fkCols=@($fk.Out -split '\r?\n')
 $nonunique=@($rows | Where-Object {($_ -split "`t")[2] -eq '1'})
 $bad=@($nonunique | Where-Object {$v=$_ -split "`t";$v[3] -ne '1' -or $fkCols -notcontains ($v[0]+'.'+$v[4])})
 Test-Result 'default B0 only' (!$bad.Count -and $r.Out -match 'OPTIONAL\|0' -and $rows.Count -eq 36) "Core index-column rows=$($rows.Count); optional indexes=0; independent FK-only check"
 Invoke-Required 'SOURCE indexes/01_performance_indexes.sql;' 'optimized-install' | Out-Null
 $r=Invoke-Required "SELECT DISTINCT INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND INDEX_NAME LIKE 'idx\\_%' ORDER BY INDEX_NAME;" 'optimized-index-inventory'
 Test-Result 'explicit optimized seven indexes' (@($r.Out.Trim() -split '\r?\n').Count -eq 7) 'No benchmark or plan timing was run'
 Read-Assertions (Invoke-Required 'SOURCE tests/integration/04_after_experiments.sql;' 'final-six-invariants')
}catch{Test-Result 'PR9 acceptance execution' $false $_.Exception.Message}
finally{
 try{Remove-OwnedDatabase 'review'}catch{Test-Result 'review cleanup' $false $_.Exception.Message}
 $fileResults | Export-Csv "$directory/sql-files.csv" -NoTypeInformation -Encoding UTF8
 $results.Add("SQL_TOTAL|PASS=$sqlPass|FAIL=$sqlFail|SQL_ERROR_FILES=$sqlErrors|NO_TEST_LINE_FILES=$formatErrors")
 $results.Add("FOCUSED_TOTAL|PASS=$pass|FAIL=$fail")
 Save-Proof 'summary.txt' ($results -join "`n")
 Write-Output "SQL_TOTAL|PASS=$sqlPass|FAIL=$sqlFail|SQL_ERROR_FILES=$sqlErrors|NO_TEST_LINE_FILES=$formatErrors"
 Write-Output "FOCUSED_TOTAL|PASS=$pass|FAIL=$fail";Write-Output "EVIDENCE|$directory"
}
Pop-Location
if($fail -or $sqlFail -or $sqlErrors -or $formatErrors){exit 1}
