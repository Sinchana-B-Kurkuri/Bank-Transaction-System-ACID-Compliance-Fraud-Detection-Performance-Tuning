DELIMITER $$
CREATE PROCEDURE sp_request_approval(IN p_from_account_id INT, IN p_to_account_id INT, IN p_amount DECIMAL(14,2), IN p_requested_by_employee_id INT, IN p_requested_by_customer_id INT, OUT p_approval_id INT) SQL SECURITY DEFINER
BEGIN
 DECLARE v_actor VARCHAR(10); DECLARE v_e INT; DECLARE v_c INT;
 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK; SET p_approval_id=NULL;
  IF v_errno IN (5003,5004,5005,5006,5010) THEN BEGIN
   DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
   START TRANSACTION; CALL sp_internal_record_failed(p_from_account_id,p_amount,'TransferOut','Online'); COMMIT;
  END; END IF;
  RESIGNAL;
 END;
 SET p_approval_id=NULL;
 IF p_amount IS NULL OR p_amount<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: amount must be positive'; END IF;
 START TRANSACTION;
 IF p_from_account_id IS NULL OR p_to_account_id IS NULL OR NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_from_account_id) OR NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_to_account_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: transfer account does not exist'; END IF;
 IF p_from_account_id=p_to_account_id THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5005,MESSAGE_TEXT='E_SAME_ACCOUNT: accounts must differ'; END IF;
 IF EXISTS(SELECT 1 FROM Accounts WHERE account_id IN (p_from_account_id,p_to_account_id) AND status<>'Active') THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5003,MESSAGE_TEXT='E_ACCOUNT_NOT_ACTIVE: both accounts must be active'; END IF;
 CALL sp_resolve_actor(USER(),v_actor,v_e,v_c);
 IF (v_actor='Employee' AND p_requested_by_employee_id=v_e AND p_requested_by_customer_id IS NULL AND EXISTS(SELECT 1 FROM Employees WHERE employee_id=v_e AND is_active)) THEN
  CALL sp_internal_authorize(p_from_account_id,'Branch',p_requested_by_employee_id,1,1);
 ELSEIF (v_actor='Customer' AND p_requested_by_customer_id=v_c AND p_requested_by_employee_id IS NULL AND EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_from_account_id AND customer_id=v_c)) THEN
  CALL sp_internal_authorize(p_from_account_id,'Online',NULL,1,0);
 ELSE SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: requester must match resolved actor'; END IF;
 INSERT INTO Transaction_Approvals(requested_by_actor_type,requested_by_employee_id,requested_by_customer_id,from_account_id,to_account_id,amount,status) VALUES(v_actor,p_requested_by_employee_id,p_requested_by_customer_id,p_from_account_id,p_to_account_id,p_amount,'Requested');
 SET p_approval_id=LAST_INSERT_ID();
 COMMIT;
END$$
DELIMITER ;
