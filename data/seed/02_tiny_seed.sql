-- All identities and numbers are synthetic. Calls public APIs; no bulk ledger writes.
DELIMITER $$
DROP PROCEDURE IF EXISTS p3_load_tiny_seed$$
CREATE PROCEDURE p3_load_tiny_seed()
SQL SECURITY DEFINER
BEGIN
 DECLARE v_i INT DEFAULT 1;
 DECLARE v_customer INT; DECLARE v_branch INT; DECLARE v_type INT; DECLARE v_employee INT;
 DECLARE v_account INT; DECLARE v_number VARCHAR(20); DECLARE v_email VARCHAR(100); DECLARE v_proof VARCHAR(20);
 DECLARE v_initial DECIMAL(14,2); DECLARE v_tx BIGINT; DECLARE v_balance DECIMAL(14,2);
 DECLARE v_from INT; DECLARE v_to INT; DECLARE v_group CHAR(36); DECLARE v_debit BIGINT; DECLARE v_credit BIGINT; DECLARE v_loan INT;
 WHILE v_i<=6 DO
  SET v_email=CONCAT('seed.customer.',v_i,'@example.invalid');
  IF NOT EXISTS(SELECT 1 FROM Customers WHERE email=v_email) THEN
   SET v_proof=ELT(v_i,'Aadhaar','PAN','Passport','DrivingLicense','VoterID','PAN');
   CALL sp_register_customer(CONCAT('Synthetic Seed Customer ',v_i),'1990-01-01',NULL,v_email,CONCAT('900000000',v_i),'Synthetic seed address',CONCAT('SYN-',v_proof,'-',LPAD(v_i,6,'0')),v_proof,v_customer);
  END IF;
  SET v_i=v_i+1;
 END WHILE;
 SET v_i=1;
 WHILE v_i<=8 DO
  SET v_number=CONCAT('SEED-',LPAD(v_i,4,'0'));
  IF NOT EXISTS(SELECT 1 FROM Accounts WHERE account_number=v_number) THEN
   SET v_customer=(SELECT customer_id FROM Customers WHERE email=CONCAT('seed.customer.',IF(v_i<=6,v_i,v_i-6),'@example.invalid'));
   SET v_branch=(SELECT branch_id FROM Branches WHERE ifsc_code=IF(MOD(v_i,2)=1,'SYNB0000001','SYNB0000002'));
   SET v_type=(SELECT account_type_id FROM Account_Types WHERE type_name=IF(v_i=7,'Fixed Deposit',IF(v_i=8,'Current','Savings')));
   SET v_employee=(SELECT employee_id FROM Employees WHERE branch_id=v_branch AND role='Teller' AND is_active ORDER BY employee_id LIMIT 1);
   SET v_initial=CASE v_i WHEN 1 THEN 300000 WHEN 2 THEN 200000 WHEN 7 THEN 15000 WHEN 8 THEN 10000 ELSE 5000 END;
   CALL sp_open_account(v_customer,v_branch,v_type,v_initial,v_employee,v_number,v_account,v_number);
  END IF;
  SET v_i=v_i+1;
 END WHILE;
 SET v_from=(SELECT account_id FROM Accounts WHERE account_number='SEED-0003');
 SET v_customer=(SELECT customer_id FROM Accounts WHERE account_id=v_from);
 IF NOT EXISTS(SELECT 1 FROM Loans WHERE customer_id=v_customer AND disbursement_account_id=v_from AND principal_amount=10000) THEN
  CALL sp_disburse_loan(v_customer,v_from,10000,8.00,12,NULL,v_loan);
 END IF;
 SET v_i=1;
 WHILE v_i<=6 DO
  SET v_from=(SELECT account_id FROM Accounts WHERE account_number=CONCAT('SEED-',LPAD(IF(v_i<=5,v_i,1),4,'0')));
  IF NOT EXISTS(SELECT 1 FROM Transactions WHERE account_id=v_from AND transaction_type='Deposit' AND status='Completed' AND amount=110+v_i) THEN
   CALL sp_deposit(v_from,110+v_i,'Online',NULL,NULL,NULL,v_tx,v_balance);
  END IF;
  SET v_i=v_i+1;
 END WHILE;
 SET v_i=1;
 WHILE v_i<=2 DO
  SET v_from=(SELECT account_id FROM Accounts WHERE account_number=CONCAT('SEED-',LPAD(v_i,4,'0')));
  IF NOT EXISTS(SELECT 1 FROM Transactions WHERE account_id=v_from AND transaction_type='Withdrawal' AND status='Completed' AND amount=20+v_i) THEN
   CALL sp_withdraw(v_from,20+v_i,'Online',NULL,NULL,NULL,v_tx,v_balance);
  END IF;
  SET v_to=(SELECT account_id FROM Accounts WHERE account_number=CONCAT('SEED-',LPAD(3-v_i,4,'0')));
  IF NOT EXISTS(SELECT 1 FROM Transactions WHERE account_id=v_from AND related_account_id=v_to AND transaction_type='TransferOut' AND status='Completed' AND amount=200+v_i) THEN
   CALL sp_transfer_funds(v_from,v_to,200+v_i,'Online',NULL,NULL,NULL,0,v_group,v_debit,v_credit);
  END IF;
  SET v_i=v_i+1;
 END WHILE;
 SET v_account=(SELECT account_id FROM Accounts WHERE account_number='SEED-0006');
 IF (SELECT status FROM Accounts WHERE account_id=v_account)='Active' THEN
  SET v_employee=(SELECT e.employee_id FROM Employees e JOIN Accounts a ON a.branch_id=e.branch_id WHERE a.account_id=v_account AND e.role='Teller' AND e.is_active ORDER BY e.employee_id LIMIT 1);
  CALL sp_set_account_status(v_account,'Frozen',v_employee);
 END IF;
END$$
DELIMITER ;
CALL p3_load_tiny_seed();
DROP PROCEDURE p3_load_tiny_seed;
