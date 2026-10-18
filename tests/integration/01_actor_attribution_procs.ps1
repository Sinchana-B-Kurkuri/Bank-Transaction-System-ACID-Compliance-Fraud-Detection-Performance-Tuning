param([string]$Database='bank_txn')
. "$PSScriptRoot/../../build/mysql_common.ps1"
Assert-BankDatabase $Database
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$created=[Collections.Generic.List[string]]::new()
$maps=[Collections.Generic.List[string]]::new()
$password=$null
$failures=0
function Report-ProcedureActor($Name,[bool]$Condition,$Detail) {
 $status=if ($Condition) {'PASS'} else {'FAIL'}
 if (!$Condition) {$script:failures++}
 Write-Output "TEST|$status|procedure actor $Name|$Detail"
}
function Invoke-ProcedureLogin([string]$Login,[string]$Sql) {
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
 $start.EnvironmentVariables['MYSQL_PWD']=$script:password
 $process=[Diagnostics.Process]::new(); $process.StartInfo=$start
 try {
  [void]$process.Start()
  $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
  $bytes=$encoding.GetBytes($Sql+"`n")
  $process.StandardInput.BaseStream.Write($bytes,0,$bytes.Length); $process.StandardInput.BaseStream.Close()
  $process.WaitForExit()
  $out=$stdout.GetAwaiter().GetResult(); $err=$stderr.GetAwaiter().GetResult()
  if ($process.ExitCode -ne 0) {throw "Restricted procedure call failed: $err"}
  return @($out.TrimEnd() -split '\r?\n')
 } finally {$start.EnvironmentVariables.Remove('MYSQL_PWD'); $process.Dispose()}
}
function Expect-ProcedureLoginError($Name,$Login,$Sql,[int]$Errno) {
 try {
  Invoke-ProcedureLogin $Login $Sql | Out-Null
  Report-ProcedureActor $Name $false 'Expected rejection did not occur'
 } catch {
  Report-ProcedureActor $Name ($_.Exception.Message -match "ERROR $Errno\b") "Expected MySQL errno $Errno"
 }
}
try {
 Push-Location $root
 $port=[int](@(Invoke-BankMysql -Sql 'SELECT @@port;')[0])
 $existing=[int](@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM mysql.user WHERE User IN ('zz_a_proc_customer','zz_a_proc_teller');")[0])
 $existingMaps=[int](@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM DB_User_Map WHERE SUBSTRING_INDEX(db_login,'@',1) IN ('zz_a_proc_customer','zz_a_proc_teller');")[0])
 if ($existing -or $existingMaps) {throw 'BLOCKED: reserved procedure test identity exists; refusing to alter it'}
 $bytes=New-Object byte[] 32; $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
 try {$rng.GetBytes($bytes)} finally {$rng.Dispose()}
 $password=[Convert]::ToBase64String($bytes)
 $setup=@(Invoke-BankMysql -Database $Database -Sql "source tests/procedures/support/fixture.sql`nSELECT CONCAT(@p3_c2,'|',@p3_a,'|',@p3_b,'|',@p3_t1,'|',@p3_t2);")
 $values=$setup[-1] -split '\|'
 $customer=[int]$values[0]; $from=[int]$values[1]; $own=[int]$values[2]; $teller=[int]$values[3]; $otherTeller=[int]$values[4]
 foreach ($login in @('zz_a_proc_customer','zz_a_proc_teller')) {
  Invoke-BankMysql -Sql "CREATE USER '$login'@'localhost' IDENTIFIED BY '$password';" | Out-Null
  $created.Add($login)
  Invoke-BankMysql -Sql "GRANT EXECUTE ON PROCEDURE $Database.sp_transfer_funds TO '$login'@'localhost';" | Out-Null
  $session=@(Invoke-ProcedureLogin $login "SELECT CONCAT('LOGIN|',USER());")[0].Substring(6)
  $escaped=$session.Replace("'","''")
  if ($login -eq 'zz_a_proc_customer') {
   Invoke-BankMysql -Database $Database -Sql "INSERT INTO DB_User_Map(db_login,actor_type,customer_id) VALUES('$escaped','Customer',$customer);" | Out-Null
  } else {
   Invoke-BankMysql -Database $Database -Sql "INSERT INTO DB_User_Map(db_login,actor_type,employee_id) VALUES('$escaped','Employee',$teller);" | Out-Null
  }
  $maps.Add($session)
 }
 Expect-ProcedureLoginError 'Customer cannot debit another owner' 'zz_a_proc_customer' "CALL sp_transfer_funds($from,$own,1,'Online',NULL,NULL,NULL,0,@g,@d,@c);" 5010
 $result=@(Invoke-ProcedureLogin 'zz_a_proc_customer' "CALL sp_transfer_funds($own,$from,1,'Online',NULL,NULL,NULL,0,@g,@d,@c); SELECT CONCAT('GROUP|',@g);")
 $group=($result | Where-Object {$_ -like 'GROUP|*'} | Select-Object -First 1).Substring(6)
 $session=$maps[0].Replace("'","''")
 $audits=[int](@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM Audit_Log l JOIN Transactions t ON l.table_name='Transactions' AND l.record_pk=CAST(t.transaction_id AS CHAR) WHERE t.transfer_group_id='$group' AND l.action_type='INSERT' AND l.db_session_user='$session' AND l.actor_type='Customer' AND l.actor_customer_id=$customer AND l.actor_employee_id IS NULL;")[0])
 Report-ProcedureActor 'Customer own transfer and audit' ($audits -eq 2) 'Both committed ledger legs carry exact Customer session attribution'
 Expect-ProcedureLoginError 'Customer cannot call private helper' 'zz_a_proc_customer' "CALL sp_internal_record_failed($own,1,'TransferOut','Online');" 1370
 Expect-ProcedureLoginError 'Teller wrong branch' 'zz_a_proc_teller' "CALL sp_transfer_funds($own,$from,1,'Branch',$teller,NULL,NULL,0,@g,@d,@c);" 5010
 Expect-ProcedureLoginError 'Teller cannot impersonate another employee' 'zz_a_proc_teller' "CALL sp_transfer_funds($own,$from,1,'Branch',$otherTeller,NULL,NULL,0,@g,@d,@c);" 5010
 $result=@(Invoke-ProcedureLogin 'zz_a_proc_teller' "CALL sp_transfer_funds($from,$own,1,'Branch',$teller,NULL,NULL,0,@g,@d,@c); SELECT CONCAT('GROUP|',@g);")
 $group=($result | Where-Object {$_ -like 'GROUP|*'} | Select-Object -First 1).Substring(6)
 $session=$maps[1].Replace("'","''")
 $audits=[int](@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM Audit_Log l JOIN Transactions t ON l.table_name='Transactions' AND l.record_pk=CAST(t.transaction_id AS CHAR) WHERE t.transfer_group_id='$group' AND l.action_type='INSERT' AND l.db_session_user='$session' AND l.actor_type='Employee' AND l.actor_employee_id=$teller;")[0])
 Report-ProcedureActor 'Teller correct branch' ($audits -eq 2) 'Public EXECUTE grant suffices; internal helpers execute in definer context'
} catch {
 $message=$_.Exception.Message
 if ($password) {$message=$message.Replace($password,'[REDACTED]')}
 Report-ProcedureActor 'execution' $false $message
} finally {
 foreach ($session in $maps) {
  try {Invoke-BankMysql -Database $Database -Sql "DELETE FROM DB_User_Map WHERE BINARY db_login=BINARY '$($session.Replace("'","''"))';" | Out-Null}
  catch {Report-ProcedureActor 'map cleanup' $false 'Could not remove the test mapping'}
 }
 foreach ($login in $created) {
  try {Invoke-BankMysql -Sql "DROP USER '$login'@'localhost';" | Out-Null}
  catch {Report-ProcedureActor 'user cleanup' $false 'Could not drop the reserved test user'}
 }
 if ($created.Count) {
  try {
   $remaining=[int](@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM mysql.user WHERE User IN ('zz_a_proc_customer','zz_a_proc_teller');")[0])
   Report-ProcedureActor 'user cleanup verified' ($remaining -eq 0) 'Reserved users removed'
   $remaining=[int](@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM DB_User_Map WHERE SUBSTRING_INDEX(db_login,'@',1) IN ('zz_a_proc_customer','zz_a_proc_teller');")[0])
   Report-ProcedureActor 'map cleanup verified' ($remaining -eq 0) 'Reserved mappings removed'
  } catch {Report-ProcedureActor 'cleanup verification' $false 'Could not verify cleanup'}
 }
 $password=$null
 Pop-Location
}
if ($failures) {exit 1}
