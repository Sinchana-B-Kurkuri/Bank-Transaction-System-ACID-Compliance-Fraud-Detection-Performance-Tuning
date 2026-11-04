SELECT VERSION(),@@version_comment,USER(),NOW(6);SHOW VARIABLES WHERE Variable_name IN ('transaction_isolation','innodb_flush_log_at_trx_commit','sync_binlog','log_bin','performance_schema');
SELECT customer_id FROM Customers WHERE email='demo.customer@example.invalid';
SELECT branch_id FROM Branches WHERE ifsc_code='SYNB0000001';
SELECT account_type_id FROM Account_Types WHERE type_name='Savings';
SELECT employee_id FROM Employees WHERE branch_id=1 AND role='Teller' LIMIT 1;
SELECT employee_id FROM Employees WHERE branch_id=1 AND role='Manager' LIMIT 1;
SELECT account_id FROM Accounts WHERE account_number='DEMO-0001';
SELECT account_id FROM Accounts WHERE account_number='SEED-0002';
SELECT balance FROM Accounts WHERE account_id=9;
SELECT MIN(f.flag_id) FROM Fraud_Flags f JOIN Transactions t ON t.transaction_id=f.transaction_id WHERE t.account_id=9;
SELECT CONCAT(flag_status,'|',reviewed_by) FROM Fraud_Flags WHERE flag_id=73;
INSERT INTO DB_User_Map(db_login,actor_type,customer_id) VALUES(USER(),'Customer',7);
DELETE FROM DB_User_Map WHERE db_login=USER();
SELECT MAX(approval_id) FROM Transaction_Approvals WHERE from_account_id=9;
SELECT balance FROM Accounts WHERE account_id=9;
SELECT COUNT(*) FROM Audit_Log WHERE table_name='Accounts' AND record_pk='9' AND action_type='INSERT' AND db_session_user=USER();
SELECT account_id FROM Accounts WHERE account_number='DEMO-NORMAL';
INSERT INTO Devices(customer_id,device_fingerprint,device_type,first_seen_at,last_seen_at,is_trusted) VALUES(7,REPEAT('a',64),'Synthetic',NOW(),NOW(),TRUE);
SELECT device_id FROM Devices WHERE device_fingerprint=REPEAT('a',64);
SELECT MAX(transaction_id) FROM Transactions WHERE account_id=10;
SELECT COUNT(*) FROM Fraud_Flags WHERE transaction_id=32;
SELECT fn_txn_risk_score(100,'Online',FALSE,0);
SELECT MAX(transaction_id) FROM Transactions WHERE account_id=10;
SELECT MAX(risk_score) FROM Fraud_Flags WHERE transaction_id=33;
SELECT CONCAT(COUNT(*),'|',SUM(risk_score)) FROM Fraud_Flags WHERE transaction_id=33;
CALL sp_evaluate_fraud(33);CALL sp_evaluate_fraud(33);
SELECT CONCAT(COUNT(*),'|',SUM(risk_score)) FROM Fraud_Flags WHERE transaction_id=33;
SELECT rule_code,weight,param_json FROM Fraud_Rules ORDER BY rule_id;SELECT f.flag_id,r.rule_code,f.risk_score,fn_risk_level(f.risk_score),f.evidence FROM Fraud_Flags f JOIN Fraud_Rules r ON r.rule_id=f.rule_id WHERE transaction_id=33 ORDER BY f.flag_id;SELECT fn_distance_km(12.9,77.6,19.0,72.8),fn_is_odd_hour('2026-10-20 02:00:00');
SELECT balance FROM Accounts WHERE account_id=9;
DROP PROCEDURE sp_internal_post_transfer;
DELIMITER $$
CREATE PROCEDURE sp_internal_post_transfer(IN p_from_account_id INT, IN p_to_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, IN p_lab_mode TINYINT, IN p_allow_approval TINYINT, OUT p_transfer_group_id CHAR(36), OUT p_debit_txn_id BIGINT, OUT p_credit_txn_id BIGINT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_first INT; DECLARE v_second INT; DECLARE v_lock INT; DECLARE v_fb DECIMAL(14,2); DECLARE v_tb DECIMAL(14,2); DECLARE v_min DECIMAL(12,2); DECLARE v_fs VARCHAR(10); DECLARE v_ts VARCHAR(10); DECLARE v_sleep INT;
 IF p_amount IS NULL OR p_amount<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: amount must be positive'; END IF;
 IF p_lab_mode IS NULL OR p_lab_mode NOT IN (0,1,2,3) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid lab mode'; END IF;
 -- RELEASE_GUARD_PLACEHOLDER
 IF p_from_account_id IS NULL OR p_to_account_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: transfer account does not exist'; END IF;
 -- LAB_NAIVE_BEGIN
 IF p_lab_mode=3 THEN
  SET v_first=p_from_account_id,v_second=p_to_account_id;
 ELSE
 -- LAB_NAIVE_END
  SET v_first=LEAST(p_from_account_id,p_to_account_id),v_second=GREATEST(p_from_account_id,p_to_account_id);
 -- LAB_NAIVE_BEGIN
 END IF;
 -- LAB_NAIVE_END
 -- The locking reads also validate existence: no shared lookup locks may precede
 -- the canonical exclusive-lock order. The local handler cannot mask later reads.
 BEGIN
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_lock=NULL;
  SET v_lock=NULL;
  SELECT account_id INTO v_lock FROM Accounts WHERE account_id=v_first FOR UPDATE;
 IF p_lab_mode=3 THEN SELECT SLEEP(IFNULL(@lab_first_lock_sleep,1)) INTO v_sleep; END IF;
  IF v_lock IS NULL THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: transfer account does not exist'; END IF;
  SET v_lock=NULL;
  SELECT account_id INTO v_lock FROM Accounts WHERE account_id=v_second FOR UPDATE;
  IF v_lock IS NULL THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: transfer account does not exist'; END IF;
 END;
 IF p_from_account_id=p_to_account_id THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5005,MESSAGE_TEXT='E_SAME_ACCOUNT: accounts must differ'; END IF;
 IF p_allow_approval=0 AND p_amount>=fn_approval_threshold() THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5006,MESSAGE_TEXT='E_APPROVAL_REQUIRED: approval threshold reached'; END IF;
 SELECT a.balance,a.status,t.min_balance INTO v_fb,v_fs,v_min FROM Accounts a JOIN Account_Types t USING(account_type_id) WHERE a.account_id=p_from_account_id;
 SELECT balance,status INTO v_tb,v_ts FROM Accounts WHERE account_id=p_to_account_id;
 IF v_fs<>'Active' OR v_ts<>'Active' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5003,MESSAGE_TEXT='E_ACCOUNT_NOT_ACTIVE: both accounts must be active'; END IF;
 CALL sp_internal_authorize(p_from_account_id,p_channel,p_employee_id,1,p_allow_approval);
 IF v_fb-p_amount<v_min THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5004,MESSAGE_TEXT='E_INSUFFICIENT_FUNDS: transfer would breach minimum balance'; END IF;
 SET p_transfer_group_id=UUID();
 UPDATE Accounts SET balance=balance-p_amount WHERE account_id=p_from_account_id;
 CALL sp_internal_insert_ledger(p_from_account_id,p_to_account_id,p_employee_id,p_transfer_group_id,p_device_id,p_location_id,'TransferOut',p_amount,v_fb-p_amount,p_channel,'Completed',NULL,p_debit_txn_id);
 -- LAB_HOOK_BEGIN
 IF p_lab_mode=1 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5016,MESSAGE_TEXT='E_LAB_INJECTED_FAILURE: failure after debit'; END IF;
 IF p_lab_mode IN (2,3) THEN SELECT SLEEP(IFNULL(@lab_sleep_seconds,5)) INTO v_sleep; END IF;
 -- LAB_HOOK_END
 UPDATE Accounts SET balance=balance+p_amount WHERE account_id=p_to_account_id;
 CALL sp_internal_insert_ledger(p_to_account_id,p_from_account_id,p_employee_id,p_transfer_group_id,NULL,NULL,'TransferIn',p_amount,v_tb+p_amount,p_channel,'Completed',NULL,p_credit_txn_id);
END$$
DELIMITER ;

SELECT account_id FROM Accounts WHERE account_number='SEED-0001';
SELECT COUNT(*) FROM bank_a_ci_demo_a99a890cc80b_lab.Experiment_Log WHERE exp_id='RETRY';
SELECT COUNT(*) FROM bank_a_ci_demo_a99a890cc80b_lab.Experiment_Log WHERE exp_id='RETRY';
SELECT event_type,detail FROM bank_a_ci_demo_a99a890cc80b_lab.Experiment_Log WHERE exp_id='RETRY';
DROP PROCEDURE sp_internal_post_transfer;
DELIMITER $$
CREATE PROCEDURE sp_internal_post_transfer(IN p_from_account_id INT, IN p_to_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, IN p_lab_mode TINYINT, IN p_allow_approval TINYINT, OUT p_transfer_group_id CHAR(36), OUT p_debit_txn_id BIGINT, OUT p_credit_txn_id BIGINT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_first INT; DECLARE v_second INT; DECLARE v_lock INT; DECLARE v_fb DECIMAL(14,2); DECLARE v_tb DECIMAL(14,2); DECLARE v_min DECIMAL(12,2); DECLARE v_fs VARCHAR(10); DECLARE v_ts VARCHAR(10); DECLARE v_sleep INT;
 IF p_amount IS NULL OR p_amount<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: amount must be positive'; END IF;
 IF p_lab_mode IS NULL OR p_lab_mode NOT IN (0,1,2,3) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid lab mode'; END IF;
 -- RELEASE_GUARD_PLACEHOLDER
 IF p_from_account_id IS NULL OR p_to_account_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: transfer account does not exist'; END IF;
 -- LAB_NAIVE_BEGIN
 IF p_lab_mode=3 THEN
  SET v_first=p_from_account_id,v_second=p_to_account_id;
 ELSE
 -- LAB_NAIVE_END
  SET v_first=LEAST(p_from_account_id,p_to_account_id),v_second=GREATEST(p_from_account_id,p_to_account_id);
 -- LAB_NAIVE_BEGIN
 END IF;
 -- LAB_NAIVE_END
 -- The locking reads also validate existence: no shared lookup locks may precede
 -- the canonical exclusive-lock order. The local handler cannot mask later reads.
 BEGIN
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_lock=NULL;
  SET v_lock=NULL;
  SELECT account_id INTO v_lock FROM Accounts WHERE account_id=v_first FOR UPDATE;
  IF v_lock IS NULL THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: transfer account does not exist'; END IF;
  SET v_lock=NULL;
  SELECT account_id INTO v_lock FROM Accounts WHERE account_id=v_second FOR UPDATE;
  IF v_lock IS NULL THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: transfer account does not exist'; END IF;
 END;
 IF p_from_account_id=p_to_account_id THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5005,MESSAGE_TEXT='E_SAME_ACCOUNT: accounts must differ'; END IF;
 IF p_allow_approval=0 AND p_amount>=fn_approval_threshold() THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5006,MESSAGE_TEXT='E_APPROVAL_REQUIRED: approval threshold reached'; END IF;
 SELECT a.balance,a.status,t.min_balance INTO v_fb,v_fs,v_min FROM Accounts a JOIN Account_Types t USING(account_type_id) WHERE a.account_id=p_from_account_id;
 SELECT balance,status INTO v_tb,v_ts FROM Accounts WHERE account_id=p_to_account_id;
 IF v_fs<>'Active' OR v_ts<>'Active' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5003,MESSAGE_TEXT='E_ACCOUNT_NOT_ACTIVE: both accounts must be active'; END IF;
 CALL sp_internal_authorize(p_from_account_id,p_channel,p_employee_id,1,p_allow_approval);
 IF v_fb-p_amount<v_min THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5004,MESSAGE_TEXT='E_INSUFFICIENT_FUNDS: transfer would breach minimum balance'; END IF;
 SET p_transfer_group_id=UUID();
 UPDATE Accounts SET balance=balance-p_amount WHERE account_id=p_from_account_id;
 CALL sp_internal_insert_ledger(p_from_account_id,p_to_account_id,p_employee_id,p_transfer_group_id,p_device_id,p_location_id,'TransferOut',p_amount,v_fb-p_amount,p_channel,'Completed',NULL,p_debit_txn_id);
 -- LAB_HOOK_BEGIN
 IF p_lab_mode=1 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5016,MESSAGE_TEXT='E_LAB_INJECTED_FAILURE: failure after debit'; END IF;
 IF p_lab_mode IN (2,3) THEN SELECT SLEEP(IFNULL(@lab_sleep_seconds,5)) INTO v_sleep; END IF;
 -- LAB_HOOK_END
 UPDATE Accounts SET balance=balance+p_amount WHERE account_id=p_to_account_id;
 CALL sp_internal_insert_ledger(p_to_account_id,p_from_account_id,p_employee_id,p_transfer_group_id,NULL,NULL,'TransferIn',p_amount,v_tb+p_amount,p_channel,'Completed',NULL,p_credit_txn_id);
END$$
DELIMITER ;

SELECT COUNT(*) FROM Accounts;SELECT COUNT(*) FROM Transactions;SELECT COUNT(*) FROM Fraud_Flags;SELECT COUNT(*) FROM Transaction_Approvals;
SELECT TABLE_NAME,INDEX_NAME,COLUMN_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() ORDER BY 1,2,SEQ_IN_INDEX;
EXPLAIN SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
EXPLAIN SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
EXPLAIN SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SOURCE indexes/01_performance_indexes.sql;
SELECT TABLE_NAME,INDEX_NAME,COLUMN_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() ORDER BY 1,2,SEQ_IN_INDEX;
EXPLAIN SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=9 AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
EXPLAIN SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
EXPLAIN SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SET @demo_start=NOW(6);SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at;SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));
SOURCE tests/integration/04_after_experiments.sql;
