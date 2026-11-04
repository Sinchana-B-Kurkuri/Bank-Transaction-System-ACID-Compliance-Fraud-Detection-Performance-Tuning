# LAB ONLY -- never ship. Dot-sourced by run_auto.ps1; passwords remain in memory.
. "$PSScriptRoot/../../backup/ps/Common.ps1"
function Invoke-AuditLogin([string]$Login,[string]$Sql) {
 $si=[Diagnostics.ProcessStartInfo]::new();$si.FileName=Get-MySqlPath
 $args=@('--no-defaults','--no-login-paths','--protocol=TCP','--host=127.0.0.1',"--port=$script:AuditPort","--user=$Login",'--database=bank_txn_scratch','--batch','--raw','--skip-column-names','--default-character-set=utf8mb4')
 $si.Arguments=($args | ForEach-Object {ConvertTo-BankNativeArgument $_}) -join ' '
 $si.UseShellExecute=$false;$si.CreateNoWindow=$true
 $si.RedirectStandardInput=$true;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
 $si.EnvironmentVariables['MYSQL_PWD']=$script:AuditPassword
 $p=[Diagnostics.Process]::new();$p.StartInfo=$si
 try {
  [void]$p.Start();$out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync()
  $bytes=[Text.Encoding]::UTF8.GetBytes($Sql+"`n")
  $p.StandardInput.BaseStream.Write($bytes,0,$bytes.Length);$p.StandardInput.Close();$p.WaitForExit()
  $o=$out.GetAwaiter().GetResult();$e=$err.GetAwaiter().GetResult()
  if($p.ExitCode){throw "Restricted audit mutation failed: $e"}
  return @($o.TrimEnd() -split '\r?\n')
 } finally {$si.EnvironmentVariables.Remove('MYSQL_PWD');$p.Dispose()}
}
function Initialize-AuditExperiment {
 Assert-Scratch $Database
 & powershell -NoProfile -File build/rebuild.ps1 -Database $Database -WithSeed | Out-Null
 if($LASTEXITCODE){throw 'Scratch rebuild failed.'}
 Invoke-MySql -Database $Database -File experiments/lab_objects/setup_lab_accounts.sql | Out-Null
 $script:AuditPort=@(Invoke-BankMysql -Sql 'SELECT @@port;')[0]
 $script:AuditCreated=[Collections.Generic.List[string]]::new()
 $script:AuditMaps=[Collections.Generic.List[string]]::new()
 $n=@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM mysql.user WHERE User IN ('zz_a_audit_teller','zz_a_audit_customer');")[0]
 if($n -ne '0'){throw 'Reserved audit users already exist; refusing to alter them.'}
 $rng=[Security.Cryptography.RandomNumberGenerator]::Create();$bytes=New-Object byte[] 32
 try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
 $script:AuditPassword=[Convert]::ToBase64String($bytes)
 $ids=(@(Invoke-MySql -Database $Database -Sql "SELECT c.customer_id,b.branch_id,t.account_type_id,e.employee_id,a.account_id FROM Customers c JOIN Accounts a USING(customer_id) JOIN Branches b USING(branch_id) JOIN Account_Types t USING(account_type_id) JOIN Employees e ON e.branch_id=b.branch_id AND e.email='teller.one@example.invalid' WHERE a.account_number='LAB-0001';")[0] -split "`t")
 $script:AuditCustomer=$ids[0];$script:AuditBranch=$ids[1];$script:AuditType=$ids[2];$script:AuditTeller=$ids[3];$script:AuditTarget=$ids[4]
 foreach($login in @('zz_a_audit_teller','zz_a_audit_customer')) {
  Invoke-BankMysql -Sql "CREATE USER '$login'@'localhost' IDENTIFIED BY '$script:AuditPassword';" | Out-Null
  $script:AuditCreated.Add($login)
  foreach($proc in @('sp_open_account','sp_deposit','sp_withdraw','sp_transfer_funds','sp_disburse_loan')) {
   Invoke-BankMysql -Sql "GRANT EXECUTE ON PROCEDURE bank_txn_scratch.$proc TO '$login'@'localhost';" | Out-Null
  }
  $user=@(Invoke-AuditLogin $login 'SELECT USER();')[0]
  $script:AuditMaps.Add($user)
  $values=if($login -like '*teller'){"'Employee',$script:AuditTeller,NULL"}else{"'Customer',NULL,$script:AuditCustomer"}
  Invoke-MySql -Database $Database -Sql "INSERT INTO DB_User_Map(db_login,actor_type,employee_id,customer_id) VALUES('$($user.Replace("'","''"))',$values);" | Out-Null
 }
}
