param([string]$Database='bank_txn')
. "$PSScriptRoot/../../build/mysql_common.ps1"
Assert-BankDatabase $Database
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$created=[Collections.Generic.List[string]]::new()
$logins=[Collections.Generic.List[string]]::new()
$nonce=[guid]::NewGuid().ToString('N').Substring(0,16)
$routine='p2_attribution_'+$nonce
$password=$null
$routineCreated=$false
$failures=0
function Report-Actor($name,[bool]$condition,$detail) {
 $status=if ($condition) {'PASS'} else {'FAIL'}
 if (!$condition) {$script:failures++}
 Write-Output "TEST|$status|actor $name|$detail"
}
function Invoke-ActorLogin([string]$Login,[string]$Sql) {
 $client=Get-Command mysql.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
 $exe=if ($client) {$client.Source} else {
  $candidates=@(Get-ChildItem (Join-Path $env:ProgramFiles 'MySQL/MySQL Server */bin/mysql.exe') -File)
  if ($candidates.Count -ne 1) {throw 'Set PATH to the intended mysql.exe'}
  $candidates[0].FullName
 }
 $arguments=@('--no-defaults','--no-login-paths','--protocol=TCP','--host=127.0.0.1',"--port=$script:port","--user=$Login","--database=$Database",'--batch','--raw','--skip-column-names','--default-character-set=utf8mb4')
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=$exe
 $start.Arguments=($arguments | ForEach-Object {ConvertTo-BankNativeArgument $_}) -join ' '
 $start.UseShellExecute=$false; $start.CreateNoWindow=$true
 $start.RedirectStandardInput=$true; $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
 $encoding=[Text.UTF8Encoding]::new($false)
 $start.StandardOutputEncoding=$encoding; $start.StandardErrorEncoding=$encoding
 # MYSQL_PWD is set only in the child environment; never in arguments or a file.
 $start.EnvironmentVariables['MYSQL_PWD']=$script:password
 $process=[Diagnostics.Process]::new(); $process.StartInfo=$start
 try {
  [void]$process.Start()
  $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
  $bytes=$encoding.GetBytes($Sql+"`n")
  $process.StandardInput.BaseStream.Write($bytes,0,$bytes.Length)
  $process.StandardInput.BaseStream.Close()
  $process.WaitForExit()
  $out=$stdout.GetAwaiter().GetResult(); $err=$stderr.GetAwaiter().GetResult()
  if ($process.ExitCode -ne 0) {throw "Restricted login failed: $err"}
  return @($out.TrimEnd() -split '\r?\n')
 } finally {
  $start.EnvironmentVariables.Remove('MYSQL_PWD')
  $process.Dispose()
 }
}
try {
 Push-Location $root
 $port=[int](@(Invoke-BankMysql -Sql 'SELECT @@port;')[0])
 $existing=[int](@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM mysql.user WHERE User IN ('zz_a_teller_test','zz_a_customer_test');")[0])
 if ($existing) {throw 'BLOCKED: reserved test users already exist; refusing to alter them'}
 $bytes=New-Object byte[] 32
 $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
 try {$rng.GetBytes($bytes)} finally {$rng.Dispose()}
 $password=[Convert]::ToBase64String($bytes)
 $setup=@"
INSERT INTO Customers(full_name,dob,email,phone,address,id_proof_number,id_proof_type)
VALUES('Synthetic actor fixture','1990-01-01','p2.$nonce@example.invalid','P2-$nonce','Synthetic','SYNTH-$nonce','Passport');
SET @c=LAST_INSERT_ID();
INSERT INTO Employees(branch_id,full_name,role,email,hire_date)
SELECT branch_id,'Synthetic actor teller','Teller','p2.teller.$nonce@example.invalid','2020-01-01' FROM Branches WHERE ifsc_code='SYNB0000001';
SET @e=LAST_INSERT_ID();
INSERT INTO Accounts(customer_id,branch_id,account_type_id,account_number,balance,opened_date)
SELECT @c,b.branch_id,t.account_type_id,'P2U$nonce',2000,'2026-01-01' FROM Branches b CROSS JOIN Account_Types t WHERE b.ifsc_code='SYNB0000001' AND t.type_name='Savings';
SET @a=LAST_INSERT_ID();
INSERT INTO Transactions(account_id,transaction_type,amount,balance_after,channel,status,reference_no)
VALUES(@a,'Deposit',2000,2000,'Online','Completed','P2OPEN$nonce');
SELECT CONCAT(@c,'|',@e,'|',@a);
"@
 $ids=(@(Invoke-BankMysql -Database $Database -Sql $setup)[0]) -split '\|'
 if ($ids.Count -ne 3 -or [int]$ids[2] -le 0) {throw 'Actor fixture setup failed'}
 $customer=[int]$ids[0]; $employee=[int]$ids[1]; $account=[int]$ids[2]
 # This probe executes in the same DEFINER context as A's triggers, so it is a
 # negative control for replacing USER() with CURRENT_USER() inside a trigger.
 $probe='DELIMITER $$' + "`nCREATE PROCEDURE $routine() SQL SECURITY DEFINER BEGIN SELECT CONCAT('IDENTITY|',USER(),'|',CURRENT_USER()); END" + '$$' + "`nDELIMITER ;"
 Invoke-BankMysql -Database $Database -Sql $probe | Out-Null
 $routineCreated=$true
 $creditSequence=0
 foreach ($case in @(@('zz_a_teller_test','Employee',$employee),@('zz_a_customer_test','Customer',$customer))) {
  $login=$case[0]; $actor=$case[1]; $actorId=[int]$case[2]
  Invoke-BankMysql -Sql "CREATE USER '$login'@'localhost' IDENTIFIED BY '$password';" | Out-Null
  $created.Add($login)
  Invoke-BankMysql -Sql "GRANT SELECT(account_id,balance), UPDATE(balance) ON $Database.Accounts TO '$login'@'localhost'; GRANT EXECUTE ON PROCEDURE $Database.$routine TO '$login'@'localhost';" | Out-Null
  $first=@(Invoke-ActorLogin $login "CALL $routine(); UPDATE Accounts SET balance=balance+1 WHERE account_id=$account;")
  # These cross-session fixtures persist because immutable audits reference the
  # actors. Mirror each test credit in the ledger so later invariants stay valid.
  $creditSequence++
  Invoke-BankMysql -Database $Database -Sql "INSERT INTO Transactions(account_id,transaction_type,amount,balance_after,channel,status,reference_no) SELECT account_id,'Deposit',1,balance,'Online','Completed','P2C$nonce-$creditSequence' FROM Accounts WHERE account_id=$account;" | Out-Null
  $identity=($first | Where-Object {$_ -like 'IDENTITY|*'} | Select-Object -First 1) -split '\|'
  if ($identity.Count -ne 3) {throw 'Restricted session did not report identity'}
  $session=$identity[1]; $definer=$identity[2]
  $escaped=$session.Replace("'","''")
  Report-Actor "$actor negative control" ($session -ne $definer) "USER()=$session; DEFINER CURRENT_USER()=$definer"
  $sameDefiner=[int](@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema=DATABASE() AND trigger_name='trg_accounts_au_audit' AND definer='$($definer.Replace("'","''"))';")[0])
  Report-Actor "$actor probe context" ($sameDefiner -eq 1) 'Probe and Accounts audit trigger have the same definer'
  $unmapped=[int](@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM Audit_Log WHERE audit_id=(SELECT MAX(audit_id) FROM Audit_Log WHERE table_name='Accounts' AND record_pk='$account' AND action_type='UPDATE') AND db_session_user='$escaped' AND actor_type='System';")[0])
  Report-Actor "$actor unmapped" ($unmapped -eq 1) 'First restricted UPDATE attributed to session user and System'
  $employeeValue=if ($actor -eq 'Employee') {"$actorId"} else {'NULL'}
  $customerValue=if ($actor -eq 'Customer') {"$actorId"} else {'NULL'}
  Invoke-BankMysql -Database $Database -Sql "INSERT INTO DB_User_Map(db_login,actor_type,employee_id,customer_id) VALUES('$escaped','$actor',$employeeValue,$customerValue);" | Out-Null
  $logins.Add($session)
  Invoke-ActorLogin $login "UPDATE Accounts SET balance=balance+1 WHERE account_id=$account;" | Out-Null
  $creditSequence++
  Invoke-BankMysql -Database $Database -Sql "INSERT INTO Transactions(account_id,transaction_type,amount,balance_after,channel,status,reference_no) SELECT account_id,'Deposit',1,balance,'Online','Completed','P2C$nonce-$creditSequence' FROM Accounts WHERE account_id=$account;" | Out-Null
  $mapped=[int](@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM Audit_Log WHERE audit_id=(SELECT MAX(audit_id) FROM Audit_Log WHERE table_name='Accounts' AND record_pk='$account' AND action_type='UPDATE') AND db_session_user='$escaped' AND actor_type='$actor' AND actor_employee_id <=> $employeeValue AND actor_customer_id <=> $customerValue;")[0])
  Report-Actor "$actor mapped" ($mapped -eq 1) 'Second restricted UPDATE records the exact calibrated login and actor ids'
 }
 $reconciled=[int](@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM Accounts a WHERE a.account_id=$account AND a.balance=(SELECT SUM(amount) FROM Transactions WHERE account_id=a.account_id AND status='Completed' AND transaction_type='Deposit') AND a.balance=(SELECT balance_after FROM Transactions WHERE account_id=a.account_id AND status='Completed' ORDER BY transaction_id DESC LIMIT 1);")[0])
 Report-Actor 'persistent fixture ledger' ($reconciled -eq 1) 'Opening deposit and four test credits reconcile to final account balance'
} catch {
 $message=$_.Exception.Message
 if ($password) {$message=$message.Replace($password,'[REDACTED]')}
 Report-Actor 'execution' $false $message
} finally {
 foreach ($login in $logins) {
  try {Invoke-BankMysql -Database $Database -Sql "DELETE FROM DB_User_Map WHERE BINARY db_login=BINARY '$($login.Replace("'","''"))';" | Out-Null}
  catch {Report-Actor 'map cleanup' $false 'Could not remove the test mapping'}
 }
 foreach ($login in $created) {
  try {Invoke-BankMysql -Sql "DROP USER '$login'@'localhost';" | Out-Null}
  catch {Report-Actor 'user cleanup' $false "Could not drop reserved test user $login"}
 }
 if ($routineCreated) {
  try {Invoke-BankMysql -Database $Database -Sql "DROP PROCEDURE $routine;" | Out-Null}
  catch {Report-Actor 'probe cleanup' $false 'Could not drop definer-context probe'}
 }
 if ($created.Count) {
  try {
   $remaining=[int](@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM mysql.user WHERE User IN ('zz_a_teller_test','zz_a_customer_test');")[0])
   Report-Actor 'temporary user cleanup' ($remaining -eq 0) 'Both reserved test users removed'
   $remaining=[int](@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM DB_User_Map WHERE SUBSTRING_INDEX(db_login,'@',1) IN ('zz_a_teller_test','zz_a_customer_test');")[0])
   Report-Actor 'temporary mapping cleanup' ($remaining -eq 0) 'Both calibrated test mappings removed'
  } catch {Report-Actor 'cleanup verification' $false 'Could not verify disposable user/map cleanup'}
 }
 $password=$null
 Pop-Location
}
if ($failures) {exit 1}
exit 0
