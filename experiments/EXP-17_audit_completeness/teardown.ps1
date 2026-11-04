# LAB ONLY -- never ship. Called in finally even when a mutation fails.
function Remove-AuditIdentities {
 foreach($map in $script:AuditMaps) {
  Invoke-MySql -Database $Database -Sql "DELETE FROM DB_User_Map WHERE BINARY db_login=BINARY '$($map.Replace("'","''"))';" | Out-Null
 }
 foreach($login in $script:AuditCreated) {Invoke-BankMysql -Sql "DROP USER '$login'@'localhost';" | Out-Null}
 $script:AuditPassword=$null
 $n=@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM mysql.user WHERE User IN ('zz_a_audit_teller','zz_a_audit_customer');")[0]
 $m=@(Invoke-MySql -Database $Database -Sql "SELECT COUNT(*) FROM DB_User_Map WHERE SUBSTRING_INDEX(db_login,'@',1) IN ('zz_a_audit_teller','zz_a_audit_customer');")[0]
 if($n -ne '0' -or $m -ne '0'){throw 'Temporary audit identity cleanup failed.'}
 Write-Output 'TEST|PASS|EXP17 identity cleanup|users=0;maps=0'
}
