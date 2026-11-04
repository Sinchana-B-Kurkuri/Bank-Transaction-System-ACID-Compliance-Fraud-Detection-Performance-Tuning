DELIMITER $$
CREATE PROCEDURE sp_close_account(IN p_account_id INT, IN p_employee_id INT, IN p_settle_balance TINYINT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_bal DECIMAL(14,2); DECLARE v_status VARCHAR(10); DECLARE v_tx BIGINT;
 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK;
  
  IF v_errno IN (5003,5004,5005,5006,5010) THEN
   BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
    START TRANSACTION;
    CALL sp_internal_record_failed(p_account_id,v_bal,'Withdrawal',IF(p_employee_id IS NULL,'Online','Branch'));
    COMMIT;
   END;
  END IF;
  RESIGNAL;
 END;
 IF p_settle_balance IS NULL OR p_settle_balance NOT IN (0,1) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid settlement flag'; END IF;
 START TRANSACTION;
 IF p_account_id IS NULL OR NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_account_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: account does not exist'; END IF;
 SELECT balance,status INTO v_bal,v_status FROM Accounts WHERE account_id=p_account_id FOR UPDATE;
 IF v_status='Closed' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5011,MESSAGE_TEXT='E_INVALID_TRANSITION: account already closed'; END IF;
 CALL sp_internal_authorize(p_account_id,IF(p_employee_id IS NULL,'Online','Branch'),p_employee_id,1,0);
 IF EXISTS(SELECT 1 FROM Loans WHERE disbursement_account_id=p_account_id AND status='Active') OR (p_settle_balance=0 AND v_bal<>0) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5008,MESSAGE_TEXT='E_CLOSE_BLOCKED: balance or active loan blocks closure'; END IF;
 IF v_bal>0 THEN CALL sp_internal_insert_ledger(p_account_id,NULL,p_employee_id,NULL,NULL,NULL,'Withdrawal',v_bal,0,IF(p_employee_id IS NULL,'Online','Branch'),'Completed',NULL,v_tx); END IF;
 UPDATE Accounts SET balance=0,status='Closed' WHERE account_id=p_account_id;
 COMMIT;
END$$
DELIMITER ;
