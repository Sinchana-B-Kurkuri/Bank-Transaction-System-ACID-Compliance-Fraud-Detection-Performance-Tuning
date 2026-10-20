param([string]$Database='bank_txn')
. "$PSScriptRoot/../../build/mysql_common.ps1"
Assert-BankDatabase $Database
$scratchDatabase=Get-BankScratchDatabase
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$failed=$false
try {
 Push-Location $root
 & powershell -NoProfile -File build/rebuild.ps1 -Database $scratchDatabase -Mode Standalone -WithSeed | Out-Null
 if ($LASTEXITCODE -ne 0) {throw 'Scratch rebuild failed'}
 $before=@(Invoke-BankMysql -Database $scratchDatabase -Sql "CALL sp_reconcile_balances(NULL); SELECT CONCAT('CHECK|',SUM(j.status='FAIL')) FROM JSON_TABLE(@reconcile_results,'`$[*]' COLUMNS(status VARCHAR(4) PATH '`$.status')) j;")
 if ($before -notcontains 'CHECK|0') {throw 'Scratch baseline did not reconcile'}
 Write-Output 'TEST|PASS|reconcile scratch baseline|All six invariants PASS before injection'
 $after=@(Invoke-BankMysql -Database $scratchDatabase -Sql "UPDATE Accounts SET balance=balance+1 WHERE account_number='SEED-0001'; CALL sp_reconcile_balances(NULL); SELECT CONCAT('CHECK|',SUM(j.status='FAIL' AND j.invariant IN ('I1','I5'))) FROM JSON_TABLE(@reconcile_results,'`$[*]' COLUMNS(invariant VARCHAR(4) PATH '`$.invariant',status VARCHAR(4) PATH '`$.status')) j;")
 $after | Set-Content (Get-BankEvidencePath 'evidence/EV-P3-INJECT-1.txt') -Encoding UTF8
 if ($after -notcontains 'CHECK|2') {throw 'Expected I1 and I5 failures were not detected'}
 Write-Output 'TEST|PASS|reconcile injected discrepancy|Actual I1 and I5 FAIL diagnostics saved; corruption limited to scratch'
 $gaps=@(Invoke-BankMysql -Database $scratchDatabase -Sql "source triggers/lab/drop_audit_triggers.sql`nSET @c=(SELECT customer_id FROM Customers WHERE email='seed.customer.1@example.invalid'); SET @b=(SELECT branch_id FROM Branches WHERE ifsc_code='SYNB0000001'); SET @t=(SELECT account_type_id FROM Account_Types WHERE type_name='Savings'); CALL sp_open_account(@c,@b,@t,2000,NULL,'P3-LAB-GAP',@a,@n); CALL sp_disburse_loan(@c,@a,1000,6,12,NULL,@l); CALL sp_reconcile_balances(NULL);")
 $gaps | Set-Content (Get-BankEvidencePath 'evidence/EV-P3-AUDIT-GAP-1.txt') -Encoding UTF8
 foreach ($kind in @('Accounts','Transactions','Loans')) {
  if (!($gaps -match "missing $kind INSERT audit")) {throw "I4 missed the $kind audit gap"}
 }
 Write-Output 'TEST|PASS|reconcile audit gaps|I4 identifies missing INSERT audits for Accounts, Transactions and Loans'
 $all=@(Invoke-BankMysql -Database $scratchDatabase -Sql "SET @a=(SELECT account_id FROM Accounts WHERE account_number='P3-LAB-GAP'); INSERT INTO Transactions(account_id,transaction_type,amount,balance_after,channel,status,reference_no) VALUES(@a,'Deposit',1,200000,'Online','Completed',fn_generate_reference()); INSERT INTO Transactions(account_id,transfer_group_id,transaction_type,amount,balance_after,channel,status,reference_no) VALUES(@a,UUID(),'TransferOut',1,2999,'Online','Completed',fn_generate_reference()); INSERT INTO Accounts(customer_id,branch_id,account_type_id,account_number,balance,opened_date) SELECT customer_id,branch_id,account_type_id,'P3-LAB-LOW',1,CURDATE() FROM Accounts WHERE account_id=@a; CALL sp_reconcile_balances(NULL); SELECT CONCAT('CHECK|',SUM(j.status='FAIL')) FROM JSON_TABLE(@reconcile_results,'`$[*]' COLUMNS(status VARCHAR(4) PATH '`$.status')) j;")
 $all | Set-Content (Get-BankEvidencePath 'evidence/EV-P3-ALL-INVARIANTS-1.txt') -Encoding UTF8
 if ($all -notcontains 'CHECK|6') {throw 'One or more invariant detectors missed the scratch injections'}
 Write-Output 'TEST|PASS|reconcile all detectors|All six detect deliberate scratch corruption: balance, chain, orphan group, minimum and audit gaps'
} catch {
 $failed=$true
 Write-Output "TEST|FAIL|reconcile scratch|$($_.Exception.Message)"
} finally {
 & powershell -NoProfile -File build/rebuild.ps1 -Database $scratchDatabase -Mode Standalone -WithSeed | Out-Null
 if ($LASTEXITCODE -ne 0) {$failed=$true; Write-Output 'TEST|FAIL|scratch restoration|Rebuild failed'}
 else {
  $check=@(Invoke-BankMysql -Database $scratchDatabase -Sql "CALL sp_reconcile_balances(NULL); SELECT CONCAT('CHECK|',SUM(j.status='FAIL')) FROM JSON_TABLE(@reconcile_results,'`$[*]' COLUMNS(status VARCHAR(4) PATH '`$.status')) j;")
  if ($check -contains 'CHECK|0') {Write-Output 'TEST|PASS|scratch restoration|Rebuild removed all injections; six invariants PASS'}
  else {$failed=$true; Write-Output 'TEST|FAIL|scratch restoration|Rebuilt scratch did not reconcile'}
 }
 Pop-Location
}
if ($failed) {exit 1}
