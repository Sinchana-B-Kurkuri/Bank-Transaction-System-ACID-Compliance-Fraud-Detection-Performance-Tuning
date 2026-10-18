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
