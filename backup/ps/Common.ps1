# Member A recovery infrastructure. No credentials or binary content are persisted here.
. "$PSScriptRoot/../../experiments/lib/Common.ps1"
function Assert-Scratch([string]$Database) {
 if ($Database -cne 'bank_txn_scratch') { throw 'Recovery requires exactly bank_txn_scratch.' }
}
function Invoke-RecoveryTool([string]$Tool,[string[]]$Arguments) {
 $exe=Join-Path (Split-Path (Get-MySqlPath) -Parent) "$Tool.exe"
 if (!(Test-Path -LiteralPath $exe)) { throw "$Tool.exe not found beside mysql.exe." }
 $password=$null
 if($Tool -eq 'mysqldump' -and @($Arguments | Where-Object {$_ -like '--defaults-extra-file=*'}).Count) {
  # mysql-only [client] options (e.g. local-infile) break mysqldump. Read only
  # connection options in memory; never copy the option file or expose passwords.
  $options=@{}; $section=''
  foreach($line in [IO.File]::ReadAllLines($env:BANK_MYSQL_CNF)) {
   $line=$line.Trim()
   if(!$line -or $line.StartsWith('#') -or $line.StartsWith(';')) {continue}
   if($line.StartsWith('!')) {throw 'Recovery option reader does not support !include; provide a self-contained local connection option file.'}
   if($line -match '^\[([^]]+)\]$') {$section=$Matches[1];continue}
   if($section -in @('client','mysqldump') -and $line -match '^([^=\s]+)\s*=\s*(.*)$') {
    $key=$Matches[1].ToLowerInvariant().Replace('_','-');$value=$Matches[2].Trim()
    if($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {$value=$value.Substring(1,$value.Length-2)}
    $value=[regex]::Replace($value,'\\([bstnr\\"''])',{param($m) switch($m.Groups[1].Value){'b'{"`b"};'s'{' '};'t'{"`t"};'n'{"`n"};'r'{"`r"};default{$m.Groups[1].Value}}})
    $options[$key]=$value
   }
  }
  $connection=@('--no-defaults','--no-login-paths')
  foreach($key in @('user','host','port','socket','protocol','ssl-mode','ssl-ca','ssl-capath','ssl-cert','ssl-key','ssl-cipher','tls-version','default-auth','get-server-public-key','server-public-key-path')) {
   if($options.ContainsKey($key)) {$connection+="--$key=$($options[$key])"}
  }
  if($options.ContainsKey('password')) {$password=$options['password']}
  $Arguments=$connection+@($Arguments | Where-Object {$_ -notlike '--defaults-extra-file=*'})
 }
 $si=[Diagnostics.ProcessStartInfo]::new(); $si.FileName=$exe
 if($null -ne $password){$si.EnvironmentVariables['MYSQL_PWD']=$password}
 $si.Arguments=($Arguments | ForEach-Object {ConvertTo-BankNativeArgument $_}) -join ' '
 $si.UseShellExecute=$false; $si.CreateNoWindow=$true
 $si.RedirectStandardOutput=$true; $si.RedirectStandardError=$true
 $p=[Diagnostics.Process]::new(); $p.StartInfo=$si
 try {
  [void]$p.Start(); $o=$p.StandardOutput.ReadToEndAsync(); $e=$p.StandardError.ReadToEndAsync()
  $p.WaitForExit(); $out=$o.GetAwaiter().GetResult(); $err=$e.GetAwaiter().GetResult()
  if ($p.ExitCode) {throw "$Tool exited $($p.ExitCode): $err"}
  if ($err) {[Console]::Error.Write($err)}
  return $out
 } finally {$si.EnvironmentVariables.Remove('MYSQL_PWD');$password=$null;$p.Dispose()}
}
function Get-RecoveryPosition {
 $version=@(Invoke-BankMysql -Sql 'SELECT VERSION();')[0]
 $sql=if ([version](($version -split '-')[0]) -ge [version]'8.4') {'SHOW BINARY LOG STATUS;'} else {'SHOW MASTER STATUS;'}
 $v=(@(Invoke-BankMysql -Sql $sql)[0] -split "`t")
 if ($v.Count -lt 2) {throw 'Binary logging is unavailable.'}
 return @{File=$v[0]; Position=[long]$v[1]}
}
function Get-RecoverySnapshot([string]$Database) {
 Assert-Scratch $Database
 $tables=@('Branches','Employees','Customers','Account_Types','Accounts','Transactions','Loans','Fraud_Flags','Audit_Log')
 $rows=@(); foreach($table in $tables) {
  $sum=(@(Invoke-BankMysql -Database $Database -Sql "CHECKSUM TABLE $table;")[0] -split "`t")[-1]
  $n=@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM $table;")[0]
  $rows+=@{Table=$table; Rows=[long]$n; Checksum="$sum"}
 }
 return @{Time=@(Invoke-BankMysql -Sql "SELECT DATE_FORMAT(NOW(6),'%Y-%m-%dT%H:%i:%s.%f');")[0]; Tables=$rows; Position=(Get-RecoveryPosition)}
}
function Get-AuditJsonExpression {
 return "JSON_OBJECT('audit_id',audit_id,'table_name',table_name,'record_pk',record_pk,'action_type',action_type,'old_value',old_value,'new_value',new_value,'db_session_user',db_session_user,'actor_type',actor_type,'actor_employee_id',actor_employee_id,'actor_customer_id',actor_customer_id,'performed_at',performed_at)"
}
function Save-AuditBaseline([string]$Database,[string]$Path) {
 $json=Get-AuditJsonExpression
 Save-Text $Path ((Invoke-MySql -Database $Database -Sql "SELECT $json FROM Audit_Log ORDER BY audit_id;") -join "`n")
}
function Compare-AuditBaseline([string]$Database,[string]$Path) {
 $sql="SET SESSION sql_mode=CONCAT(@@sql_mode,',NO_BACKSLASH_ESCAPES'); CREATE TEMPORARY TABLE expected_audit(j JSON);`n"
 foreach($row in [IO.File]::ReadAllLines($Path)) {$sql+="INSERT INTO expected_audit VALUES('$($row.Replace("'","''"))');`n"}
 $json=Get-AuditJsonExpression
 # Round-trip the actual document through JSON text too: JSON_OBJECT can contain
 # opaque MySQL DATE/DATETIME/DECIMAL values, whereas a SQL dump restores JSON text.
 $sql+="SELECT COUNT(*) FROM expected_audit e LEFT JOIN Audit_Log a ON a.audit_id=CAST(JSON_UNQUOTE(JSON_EXTRACT(e.j,'$.audit_id')) AS UNSIGNED) WHERE a.audit_id IS NULL OR NOT(e.j=CAST(CAST($json AS CHAR) AS JSON));"
 return [long]@(Invoke-MySql -Database $Database -Sql $sql)[0]
}
function Save-RecoveryState($State,[string]$StateFile) {
 Save-Text $StateFile ($State | ConvertTo-Json -Depth 10)
}
function Read-RecoveryState([string]$StateFile) {
 if (!(Test-Path -LiteralPath $StateFile)) {throw 'Run take_full_backup.ps1 first (or pass -StateFile).'}
 return Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
}
function Restore-RecoveryDump($State) {
 Assert-Scratch $State.Database
 Invoke-BankMysql -Sql 'DROP DATABASE IF EXISTS bank_txn_scratch;'
 # Native mysql SOURCE streams the dump; no PowerShell text/binary pipeline.
 $path=$State.Dump.Replace('\','/')
 Invoke-RecoveryTool mysql @("--defaults-extra-file=$env:BANK_MYSQL_CNF",'--batch','--skip-force',"--execute=source $path") | Out-Null
}
