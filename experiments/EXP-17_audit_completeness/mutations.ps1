# LAB ONLY -- never ship. Operation plan independently derives expected trigger events.
function Run-AuditMutations {
 $expected=@();$raw=@()
 $start=@(Invoke-MySql -Database $Database -Sql 'SELECT COALESCE(MAX(audit_id),0) FROM Audit_Log;')[0]
 foreach($login in $script:AuditCreated) {
  $employee=if($login -like '*teller'){$script:AuditTeller}else{'NULL'}
  $channel=if($login -like '*teller'){'Branch'}else{'Online'}
  $number=if($login -like '*teller'){'EXP17-TELLER'}else{'EXP17-CUSTOMER'}
  $plan=@(
   @{Name='open';Sql="CALL sp_open_account($script:AuditCustomer,$script:AuditBranch,$script:AuditType,10000,$employee,'$number',@a,@n); SELECT @a;";AccountInserts=1;SingleLegs=1;Transfers=0;LoanInserts=0},
   @{Name='deposit';Sql="CALL sp_deposit({account},100,'$channel',$employee,NULL,NULL,@t,@b);";AccountInserts=0;SingleLegs=1;Transfers=0;LoanInserts=0},
   @{Name='withdraw';Sql="CALL sp_withdraw({account},10,'$channel',$employee,NULL,NULL,@t,@b);";AccountInserts=0;SingleLegs=1;Transfers=0;LoanInserts=0},
   @{Name='transfer';Sql="CALL sp_transfer_funds({account},$script:AuditTarget,5,'$channel',$employee,NULL,NULL,0,@g,@d,@c);";AccountInserts=0;SingleLegs=0;Transfers=1;LoanInserts=0},
   @{Name='loan';Sql="CALL sp_disburse_loan($script:AuditCustomer,{account},50,1,12,$employee,@l);";AccountInserts=0;SingleLegs=1;Transfers=0;LoanInserts=1}
  )
  foreach($op in $plan) {
   $before=@(Invoke-MySql -Database $Database -Sql 'SELECT COALESCE(MAX(audit_id),0) FROM Audit_Log;')[0]
   $out=@(Invoke-AuditLogin $login ($op.Sql.Replace('{account}',"$account")))
   if($op.Name -eq 'open') {$account=[int]$out[-1]}
   $after=@(Invoke-MySql -Database $Database -Sql 'SELECT COALESCE(MAX(audit_id),0) FROM Audit_Log;')[0]
   $legs=$op.SingleLegs+2*$op.Transfers
   $total=$op.AccountInserts+2*$legs+$op.LoanInserts
   $delta=@(Invoke-MySql -Database $Database -Sql "SELECT COUNT(*) FROM Audit_Log WHERE audit_id>$before AND audit_id<=$after;")[0]
   Write-Output "TEST|$(if([int]$delta -eq $total){'PASS'}else{'FAIL'})|EXP17 total $login $($op.Name)|expected=$total;actual=$delta"
   if([int]$delta -ne $total){throw 'Unexpected audit events outside the expected action groups.'}
   $counts=@{'Accounts|INSERT'=$op.AccountInserts;'Accounts|UPDATE'=$legs;'Transactions|INSERT'=$legs;'Loans|INSERT'=$op.LoanInserts}
   foreach($key in $counts.Keys) {
    $parts=$key -split '\|'
    $actual=@(Invoke-MySql -Database $Database -Sql "SELECT COUNT(*) FROM Audit_Log WHERE audit_id>$before AND audit_id<=$after AND table_name='$($parts[0])' AND action_type='$($parts[1])';")[0]
    $ok=[int]$actual -eq [int]$counts[$key]
    $expected+="| $login / $($op.Name) | $($key.Replace('|',' / ')) | $($counts[$key]) | $actual | $ok |"
    Write-Output "TEST|$(if($ok){'PASS'}else{'FAIL'})|EXP17 $login $($op.Name) $key|expected=$($counts[$key]);actual=$actual"
    if(!$ok){throw 'Audit event count mismatch.'}
   }
   $mapped=$script:AuditMaps[$script:AuditCreated.IndexOf($login)].Replace("'","''")
   $actor=if($login -like '*teller'){"actor_type='Employee' AND actor_employee_id=$script:AuditTeller AND actor_customer_id IS NULL"}else{"actor_type='Customer' AND actor_customer_id=$script:AuditCustomer AND actor_employee_id IS NULL"}
   $n=@(Invoke-MySql -Database $Database -Sql "SELECT COUNT(*) FROM Audit_Log WHERE audit_id>$before AND audit_id<=$after AND NOT(db_session_user='$mapped' AND $actor);")[0]
   Write-Output "TEST|$(if($n -eq '0'){'PASS'}else{'FAIL'})|EXP17 actor $login $($op.Name)|mismatches=$n"
   if($n -ne '0'){throw 'Audit actor mismatch.'}
  }
 }
 Save-Text evidence/EV-EXP17-counts.md (((@('# EXP-17 expected versus actual','', 'Derivation per operation: ledger legs = single-leg calls + 2 * transfer calls; Accounts UPDATE and Transactions INSERT each equal ledger legs. Opening additionally inserts one Accounts row. Routed loan additionally inserts one Loans row. Zero-count groups are also checked. The plan contains each executed statement once; counts are not inferred from Audit_Log.', '', '| Statement | Table/action | Expected | Actual | Match |','|---|---|---:|---:|---|')+$expected) -join "`n")+"`n")
 # Independently verify snapshots for every generated row, not just counts.
 $sql=@"
SET @w=$start;
SET @bad=(SELECT COUNT(*) FROM Audit_Log l JOIN Transactions t ON l.table_name='Transactions' AND l.record_pk=CAST(t.transaction_id AS CHAR) WHERE l.audit_id>@w AND (l.old_value IS NOT NULL OR JSON_LENGTH(l.new_value)<>14 OR NOT(JSON_EXTRACT(l.new_value,'$.balance_after') <=> CAST(t.balance_after AS JSON)) OR JSON_UNQUOTE(JSON_EXTRACT(l.new_value,'$.status'))<>t.status));
CALL bank_lab.sp_assert_equal(DATABASE(),'EXP17 transaction JSON snapshots','0',@bad);
SET @bad=(WITH q AS (SELECT old_value,new_value,LAG(new_value) OVER(PARTITION BY record_pk ORDER BY audit_id) prior FROM Audit_Log WHERE audit_id>@w AND table_name='Accounts') SELECT COUNT(*) FROM q WHERE JSON_LENGTH(new_value)<>8 OR (prior IS NOT NULL AND (NOT(JSON_EXTRACT(old_value,'$.balance') <=> JSON_EXTRACT(prior,'$.balance')) OR NOT(JSON_EXTRACT(old_value,'$.status') <=> JSON_EXTRACT(prior,'$.status')))));
CALL bank_lab.sp_assert_equal(DATABASE(),'EXP17 account JSON chain','0',@bad);
SELECT audit_id,table_name,record_pk,action_type,db_session_user,actor_type,actor_employee_id,actor_customer_id,old_value,new_value FROM Audit_Log WHERE audit_id>@w ORDER BY audit_id;
"@
 $out=Invoke-MySql -Database $Database -Sql $sql -OutputFile evidence/EV-EXP17-json.txt
 $out | Where-Object {$_ -like 'TEST|*'}
 if($out -match '^TEST\|FAIL'){throw 'Audit JSON verification failed.'}
 $dbout=@(Invoke-MySql -Database $Database -File tests/integration/05_exp17.sql -OutputFile "$Directory/db-assertions.txt")
 $dbout | Where-Object {$_ -like 'TEST|*'}
 if($dbout -match '^TEST\|FAIL'){throw 'DB assertions failed.'}
 # Each of these five single-row direct statements executes once in the SQL plan.
 $groups=@($dbout | Where-Object {$_ -like 'AUDIT_COUNT|*'})
 if($groups.Count -ne 5){throw 'Unexpected DBA table/action groups.'}
 foreach($key in @('Loans|INSERT','Loans|UPDATE','Loans|DELETE','Accounts|UPDATE','Transactions|INSERT')) {
  $line=@($groups | Where-Object {$_ -ceq "AUDIT_COUNT|$key|1"})
  if($line.Count -ne 1){throw "DBA expected one $key audit row."}
  Add-Content evidence/EV-EXP17-counts.md "| DBA / one single-row statement | $($key.Replace('|',' / ')) | 1 | 1 | True |" -Encoding UTF8
 }
 Add-Content evidence/EV-EXP17-json.txt ("`n"+(($dbout | Where-Object {$_ -like 'AUDIT_JSON|*'}) -join "`n")) -Encoding UTF8
}
