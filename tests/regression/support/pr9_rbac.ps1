# Invoked only by pr9_acceptance.ps1 -WithRestrictedRoles after explicit operator approval.
# No execution body: all global operations are exact members of an in-memory allowlist.
function Invoke-Pr9RbacNative {
 param([string]$Sql,[string]$Name,[string]$Login,[string]$Password,[switch]$Secret)
 Assert-OwnedName
 if(!$script:WithRestrictedRoles){throw 'Restricted-role operations were not enabled.'}
 if($Sql -match '(?i)\bbank_(?:txn(?:_scratch)?|lab)\b'){throw 'Protected schema in RBAC batch.'}
 if(!$Login -and !$script:rbacAllowed.Contains($Sql)){throw 'Administrative SQL is outside the approved exact RBAC plan.'}
 # Array-wrap the conditional: PowerShell otherwise unwraps the admin's one item
 # to a scalar string and += would concatenate all later flags into the CNF path.
 $arguments=@(if($Login){'--no-defaults';'--protocol=TCP';'--host=127.0.0.1';"--port=$script:rbacPort";"--user=$Login"}else{"--defaults-extra-file=$script:optionFile"})
 $arguments+=@('--batch','--raw','--skip-column-names','--default-character-set=utf8mb4','--skip-force',"--database=$script:database")
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=$script:client;$start.Arguments=($arguments | ForEach-Object {ConvertTo-BankNativeArgument $_}) -join ' '
 $start.WorkingDirectory=$script:root;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
 $start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
 $start.StandardOutputEncoding=$script:utf8;$start.StandardErrorEncoding=$script:utf8
 if($Login){$start.EnvironmentVariables['MYSQL_PWD']=$Password}
 $process=[Diagnostics.Process]::new();$process.StartInfo=$start
 try {
  [void]$process.Start()
  $out=$process.StandardOutput.ReadToEndAsync();$err=$process.StandardError.ReadToEndAsync()
  $bytes=$script:utf8.GetBytes($Sql+"`n")
  try{$process.StandardInput.BaseStream.Write($bytes,0,$bytes.Length)}finally{$process.StandardInput.BaseStream.Close()}
  if(!$process.WaitForExit(60000)){$process.Kill();$process.WaitForExit();throw 'Own RBAC mysql CLIENT exceeded deadline.'}
  $stdout=$out.GetAwaiter().GetResult();$stderr=$err.GetAwaiter().GetResult()
  foreach($secretValue in $script:rbacPasswords){
   $stdout=$stdout.Replace($secretValue,'[REDACTED]');$stderr=$stderr.Replace($secretValue,'[REDACTED]')
  }
  Save-Proof "$Name.sql" $(if($Secret){'-- Runtime-secret CREATE USER batch intentionally not recorded.'}else{$Sql})
  Save-Proof "$Name.stdout.txt" $stdout;Save-Proof "$Name.stderr.txt" $stderr
  return [pscustomobject]@{Code=$process.ExitCode;Out=$stdout;Err=$stderr}
 } finally {
  if($Login){$start.EnvironmentVariables.Remove('MYSQL_PWD')}
  $process.Dispose()
 }
}
function Invoke-Pr9RbacAdmin([string]$Sql,[string]$Name,[switch]$Secret) {
 $r=Invoke-Pr9RbacNative -Sql $Sql -Name $Name -Secret:$Secret
 if($r.Code -ne 0){throw "$Name failed: $($r.Err)"}
 return $r
}
function Test-Pr9RestrictedRbac {
 $suffix='_pr9_'+[guid]::NewGuid().ToString('N').Substring(0,8)
 $short=$suffix.Substring(5)
 $roles=@('customer','teller','manager','auditor') | ForEach-Object {"bank_${_}_role$suffix"}
 $users=@("zz_a_pr9_c_$short","zz_a_pr9_t_$short","zz_a_pr9_m_$short")
 $createdRoles=[Collections.Generic.List[string]]::new();$createdUsers=[Collections.Generic.List[string]]::new()
 $script:rbacAllowed=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
 $script:rbacPasswords=[Collections.Generic.List[string]]::new()
 $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
 $secrets=@{}
 try {
  $r=Invoke-Required 'SELECT owner_token FROM _error1222_owner;' 'rbac-owner-preflight'
  if($r.Out.Trim() -cne $script:owner){throw 'RBAC target ownership mismatch.'}
  $names=(($roles+$users) | ForEach-Object {"'$_'"}) -join ','
  $r=Invoke-Required "SELECT COUNT(*) FROM mysql.user WHERE User IN ($names);SELECT @@port;" 'rbac-account-preflight'
  $values=$r.Out.Trim() -split '\r?\n'
  if($values[0] -ne '0'){throw 'RBAC account/role collision: refusing any existing account at any host.'}
  $script:rbacPort=[int]$values[1]
  $r=Invoke-Required "SET @rbac_apply=0,@rbac_role_suffix='$suffix';`nSOURCE security/01_roles_and_grants.sql;" 'rbac-approved-suffixed-plan'
  $commands=@($r.Out -split '\r?\n' | Where-Object {$_ -like 'RBAC|PLAN|*'} | ForEach-Object {$_.Substring(10)})
  if($commands.Count -ne 45 -or @($commands | Sort-Object -Unique).Count -ne 45){throw 'RBAC plan must have45 distinct statements.'}
  foreach($command in $commands){
   if($command -match "^CREATE ROLE IF NOT EXISTS '([^']+)'@'%'$"){
    if($roles -cnotcontains $Matches[1]){throw 'Unexpected role in plan.'}
   }else{
    $dbPattern=[regex]::Escape($script:database)
    if($command -notmatch "^GRANT (?:SELECT ON|EXECUTE ON PROCEDURE) ``$dbPattern``\.``([A-Za-z0-9_]+)`` TO '([^']+)'@'%'$"){throw "Unexpected grant syntax in plan: $command"}
    $object=$Matches[1];$role=$Matches[2]
    if($roles -cnotcontains $role -or $object -match '^sp_internal_' -or $object -eq 'sp_evaluate_fraud'){throw 'Unexpected privileged target in grant.'}
    if($command -like 'GRANT SELECT*' -and $object -notin @('v_customer_account_summary','v_transaction_activity','v_fraud_case_queue','Audit_Log')){throw 'Unexpected base-table grant.'}
   }
   [void]$script:rbacAllowed.Add($command+';')
  }
  Save-Proof 'rbac-approved-inventory.txt' ((@("database=$script:database","suffix=$suffix")+$roles+$users) -join "`n")
  foreach($role in $roles){
   # Strict CREATE closes the race after preflight: never adopt an existing role.
   $create="CREATE ROLE '$role'@'%';";[void]$script:rbacAllowed.Add($create)
   Invoke-Pr9RbacAdmin $create "rbac-create-$role" | Out-Null
   $createdRoles.Add($role)
   [void]$script:rbacAllowed.Add("DROP ROLE '$role'@'%';")
  }
  foreach($command in $commands | Where-Object {$_ -like 'GRANT *'}){Invoke-Pr9RbacAdmin ($command+';') ('rbac-grant-'+[guid]::NewGuid().ToString('N')) | Out-Null}
  # Reapply the same GRANTs via the installer's session-variable PREPARE protocol.
  # This proves actual EXECUTE, not merely syntax or a repeated preview.
  foreach($command in $commands | Where-Object {$_ -like 'GRANT *'}){
   $sql="SET @pr9_role_grant='"+$command.Replace("'","''")+"'; PREPARE pr9_role_stmt FROM @pr9_role_grant; EXECUTE pr9_role_stmt; DEALLOCATE PREPARE pr9_role_stmt;"
   [void]$script:rbacAllowed.Add($sql)
   Invoke-Pr9RbacAdmin $sql ('rbac-regrant-'+[guid]::NewGuid().ToString('N')) | Out-Null
  }
  Test-Result 'restricted RBAC actual suffixed plan applied twice' $true 'Four fresh roles,41 object grants; regrant via actual PREPARE/EXECUTE; no standard role changed'
  $roleNames=($roles | ForEach-Object {"'$_'"}) -join ','
  $r=Invoke-Required "SELECT (SELECT COUNT(*) FROM mysql.tables_priv WHERE Db=DATABASE() AND User IN ($roleNames)),(SELECT COUNT(*) FROM mysql.procs_priv WHERE Db=DATABASE() AND User IN ($roleNames)),(SELECT COUNT(*) FROM mysql.procs_priv WHERE User IN ($roleNames) AND Routine_name LIKE 'sp!_internal!_%' ESCAPE '!'),(SELECT COUNT(*) FROM mysql.db WHERE User IN ($roleNames));" 'rbac-actual-grant-inventory'
  Test-Result 'restricted RBAC installed privilege inventory' ($r.Out.Trim() -eq "9`t32`t0`t0") 'Nine object SELECT,32 routine EXECUTE,zero private EXECUTE,zero database wildcard grants'
  for($i=0;$i -lt $users.Count;$i++){
   $bytes=New-Object byte[] 24;$rng.GetBytes($bytes)
   $password=[Convert]::ToBase64String($bytes)+'!aA9'
   $script:rbacPasswords.Add($password);$secrets[$users[$i]]=$password
   $create="CREATE USER '$($users[$i])'@'127.0.0.1' IDENTIFIED BY '$password';"
   [void]$script:rbacAllowed.Add($create)
   Invoke-Pr9RbacAdmin $create "rbac-create-user-$i" -Secret | Out-Null
   [void]$script:rbacAllowed.Remove($create);$create=$null;$password=$null
   $createdUsers.Add($users[$i]);[void]$script:rbacAllowed.Add("DROP USER '$($users[$i])'@'127.0.0.1';")
   foreach($sql in @("GRANT '$($roles[$i])'@'%' TO '$($users[$i])'@'127.0.0.1';","SET DEFAULT ROLE '$($roles[$i])'@'%' TO '$($users[$i])'@'127.0.0.1';")){
    [void]$script:rbacAllowed.Add($sql);Invoke-Pr9RbacAdmin $sql "rbac-user-role-$i-$([guid]::NewGuid().ToString('N'))" | Out-Null
   }
  }
  $r=Invoke-Required "SELECT (SELECT customer_id FROM Customers WHERE email='seed.customer.1@example.invalid'),(SELECT account_id FROM Accounts WHERE account_number='SEED-0001'),(SELECT account_id FROM Accounts WHERE account_number='SEED-0002'),(SELECT employee_id FROM Employees WHERE email='teller.one@example.invalid'),(SELECT employee_id FROM Employees WHERE email='manager.one@example.invalid'),(SELECT COALESCE(MAX(audit_id),0) FROM Audit_Log);" 'rbac-fixture-ids'
  $v=$r.Out.Trim() -split "`t";$customer=[int]$v[0];$own=[int]$v[1];$foreign=[int]$v[2];$teller=[int]$v[3];$manager=[int]$v[4];$audit=[long]$v[5]
  $logins=@{}
  for($i=0;$i -lt $users.Count;$i++){
   $r=Invoke-Pr9RbacNative 'SELECT USER(),CURRENT_USER(),CURRENT_ROLE();SHOW GRANTS;' "rbac-login-$i" $users[$i] $secrets[$users[$i]]
   if($r.Code -ne 0){throw "Restricted native login failed: $($r.Err)"}
   $row=($r.Out -split '\r?\n')[0] -split "`t";$login=$row[0]
   if($login -notmatch ('^'+[regex]::Escape($users[$i])+'@') -or $row[1] -ne ($users[$i]+'@127.0.0.1')){throw 'Native identity calibration mismatch.'}
   $logins[$users[$i]]=$login
   Test-Result "restricted native role activation $i" ($row[2].Contains($roles[$i]) -and $r.Out -notmatch 'GRANT OPTION') 'Exact new login and intended default role; no GRANT OPTION'
   $mapping=if($i -eq 0){"'Customer',NULL,$customer"}else{"'Employee',$(if($i -eq 1){$teller}else{$manager}),NULL"}
   Invoke-Required "INSERT INTO DB_User_Map(db_login,actor_type,employee_id,customer_id) VALUES('$login',$mapping);" "rbac-map-$i" | Out-Null
  }
  function Probe-Restricted([int]$Index,[string]$Name,[string]$Sql,[int[]]$Errors=@(0),[switch]$Statement) {
   $r=Invoke-Pr9RbacNative $Sql $Name $users[$Index] $secrets[$users[$Index]]
   $errno=if($r.Err -match 'ERROR (\d+)'){[int]$Matches[1]}else{0}
   $ok=if($Errors -contains 0){$r.Code -eq 0}else{$r.Code -ne 0 -and $Errors -contains $errno}
   if($Statement){
    $rows=@($r.Out -split '\r?\n' | Where-Object {($_ -split "`t").Count -eq 8})
    if($Errors -contains 0){$ok=$ok -and $rows.Count -gt 0;foreach($row in $rows){$cols=$row -split "`t";if([decimal]$cols[4] -ne [decimal]$cols[7]){$ok=$false}}}
    else{$ok=$ok -and $rows.Count -eq 0}
   }
   if($r.Out -match 'ASSERT\|FAIL'){$ok=$false}
   Test-Result $Name $ok "Native restricted session; errno=$errno; expected=$($Errors -join ',')"
  }
  Probe-Restricted 0 'restricted customer own view' "SELECT CONCAT('ASSERT|',IF(COUNT(*)>0 AND SUM(customer_id<>$customer)=0,'PASS','FAIL')) FROM v_customer_account_summary;"
  Probe-Restricted 0 'restricted customer foreign activity absent' "SELECT CONCAT('ASSERT|',IF(SUM(account_id=$foreign)=0 AND COUNT(*)>0,'PASS','FAIL')) FROM v_transaction_activity;"
  for($i=0;$i -lt $users.Count;$i++){
   Probe-Restricted $i "restricted own statement $i" "CALL sp_generate_statement($own,CURDATE(),CURDATE());" -Statement
   Probe-Restricted $i "restricted foreign statement $i" "CALL sp_generate_statement($foreign,CURDATE(),CURDATE());" @(5010) -Statement
   Probe-Restricted $i "restricted base SELECT denied $i" 'SELECT balance FROM Accounts LIMIT 1;' @(1142,1143)
   Probe-Restricted $i "restricted base UPDATE denied $i" "UPDATE Accounts SET balance=balance+1 WHERE account_id=$own;" @(1142,1143)
   Probe-Restricted $i "restricted identity table denied $i" 'SELECT * FROM DB_User_Map;' @(1142,1143)
   Probe-Restricted $i "restricted private EXECUTE denied $i" "CALL sp_internal_authorize($own,'Online',NULL,1,0);" @(1370)
   Probe-Restricted $i "restricted evaluator EXECUTE denied $i" 'CALL sp_evaluate_fraud(1);' @(1370)
   Probe-Restricted $i "restricted raw identity function denied $i" 'SELECT fn_resolved_employee_id(USER());' @(1370)
  }
  foreach($i in @(1,2)){
   Probe-Restricted $i "restricted staff activity foreign branch absent $i" "SELECT CONCAT('ASSERT|',IF(COUNT(*)>0 AND SUM(account_id=$foreign)=0,'PASS','FAIL')) FROM v_transaction_activity;"
  }
  $r=Invoke-Required 'SHOW CREATE VIEW v_transaction_activity;' 'rbac-activity-view-definition'
  Test-Result 'restricted activity retains DEFINER security' ($r.Out -match 'SQL SECURITY DEFINER') 'Identity predicates remain encapsulated; no raw-function EXECUTE grants'
  foreach($staff in @(@(1,$teller),@(2,$manager))){
   try{
    Invoke-Required "UPDATE Employees SET is_active=FALSE WHERE employee_id=$($staff[1]);" "rbac-deactivate-$($staff[0])" | Out-Null
    Probe-Restricted $staff[0] "restricted inactive staff denied $($staff[0])" "CALL sp_generate_statement($own,CURDATE(),CURDATE());" @(5010) -Statement
    Probe-Restricted $staff[0] "restricted inactive staff empty view $($staff[0])" "SELECT CONCAT('ASSERT|',IF(COUNT(*)=0,'PASS','FAIL')) FROM v_transaction_activity;"
   }finally{Invoke-Required "UPDATE Employees SET is_active=TRUE WHERE employee_id=$($staff[1]);" "rbac-reactivate-$($staff[0])" | Out-Null}
  }
  Probe-Restricted 0 'restricted customer deposit' "CALL sp_deposit($own,1,'Online',NULL,NULL,NULL,@tx,@b);"
  Probe-Restricted 0 'restricted customer withdrawal' "CALL sp_withdraw($own,1,'Online',NULL,NULL,NULL,@tx,@b);"
  Probe-Restricted 0 'restricted customer foreign debit denied' "CALL sp_transfer_funds($foreign,$own,1,'Online',NULL,NULL,NULL,0,@g,@d,@c);" @(5010)
  Probe-Restricted 0 'restricted customer own transfer' "CALL sp_transfer_funds($own,$foreign,1,'Online',NULL,NULL,NULL,0,@g,@d,@c);"
  Probe-Restricted 0 'restricted customer atomic rollback' "CALL sp_transfer_funds($own,$foreign,1,'Online',NULL,NULL,NULL,1,@g,@d,@c);" @(5016)
  Probe-Restricted 1 'restricted teller branch posting' "CALL sp_deposit($own,1,'Branch',$teller,NULL,NULL,@tx,@b);"
  Probe-Restricted 1 'restricted teller wrong branch posting denied' "CALL sp_deposit($foreign,1,'Branch',$teller,NULL,NULL,@tx,@b);" @(5010)
  Probe-Restricted 0 'restricted customer cannot review fraud' "CALL sp_review_fraud_flag(1,'UnderReview',1);" @(1370)
  $r=Invoke-Required "SELECT flag_id FROM Fraud_Flags WHERE flag_status='Open' ORDER BY flag_id LIMIT 1;" 'rbac-open-flag'
  $flag=[int]$r.Out.Trim()
  Probe-Restricted 2 'restricted manager fraud review' "CALL sp_review_fraud_flag($flag,'UnderReview',$manager);"
  $r=Invoke-Required "SELECT flag_status,reviewed_by FROM Fraud_Flags WHERE flag_id=$flag;" 'rbac-manager-review-state'
  Test-Result 'restricted manager review persisted' ($r.Out.Trim() -eq "UnderReview`t$manager") 'Actual manager-granted routine committed expected status/reviewer'
  $actorSql=@"
CALL bank_lab.sp_assert_true(DATABASE(),'restricted audit customer actor',
 (SELECT COUNT(*)>0 AND SUM(actor_type<>'Customer' OR NOT(actor_customer_id <=> $customer) OR actor_employee_id IS NOT NULL)=0 FROM Audit_Log WHERE audit_id>$audit AND db_session_user='$($logins[$users[0]])'),'Exact native USER and mapped customer');
CALL bank_lab.sp_assert_true(DATABASE(),'restricted audit teller actor',
 (SELECT COUNT(*)>0 AND SUM(actor_type<>'Employee' OR NOT(actor_employee_id <=> $teller) OR actor_customer_id IS NOT NULL)=0 FROM Audit_Log WHERE audit_id>$audit AND db_session_user='$($logins[$users[1]])'),'Exact native USER and mapped teller');
"@
  Read-Assertions (Invoke-Required $actorSql 'rbac-native-audit-attribution')
  Read-Assertions (Invoke-Required 'SOURCE tests/integration/04_after_experiments.sql;' 'rbac-native-six-invariants')
 } finally {
  foreach($user in $createdUsers){try{Invoke-Pr9RbacAdmin "DROP USER '$user'@'127.0.0.1';" "rbac-drop-$user" | Out-Null}catch{Test-Result "RBAC user cleanup $user" $false $_.Exception.Message}}
  foreach($role in $createdRoles){try{Invoke-Pr9RbacAdmin "DROP ROLE '$role'@'%';" "rbac-drop-$role" | Out-Null}catch{Test-Result "RBAC role cleanup $role" $false $_.Exception.Message}}
  try{
   if($createdUsers.Count){$l=($createdUsers | ForEach-Object {"'$_'"}) -join ',';Invoke-Required "DELETE FROM DB_User_Map WHERE SUBSTRING_INDEX(db_login,'@',1) IN ($l);" 'rbac-remove-disposable-maps' | Out-Null}
   if($names){
    $r=Invoke-Required "SELECT (SELECT COUNT(*) FROM mysql.user WHERE User IN ($names)),(SELECT COUNT(*) FROM mysql.tables_priv WHERE User IN ($names)),(SELECT COUNT(*) FROM mysql.procs_priv WHERE User IN ($names)),(SELECT COUNT(*) FROM mysql.role_edges WHERE FROM_USER IN ($names) OR TO_USER IN ($names)),(SELECT COUNT(*) FROM mysql.default_roles WHERE User IN ($names) OR DEFAULT_ROLE_USER IN ($names));" 'rbac-cleanup-verify'
    Test-Result 'RBAC owned users roles grants cleanup' ($r.Out.Trim() -eq "0`t0`t0`t0`t0") 'Exact created accounts, object grants, role edges and defaults absent'
   }
  }catch{Test-Result 'RBAC cleanup verification' $false $_.Exception.Message}
  $secrets.Clear();$script:rbacPasswords.Clear();$script:rbacAllowed.Clear();$rng.Dispose()
 }
}
