DELIMITER $$
CREATE PROCEDURE sp_withdraw(IN p_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, OUT p_transaction_id BIGINT, OUT p_balance_after DECIMAL(14,2))
SQL SECURITY DEFINER
BEGIN

 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK;
  SET p_transaction_id=NULL,p_balance_after=NULL;
  IF v_errno IN (5003,5004,5005,5006,5010) THEN
   BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
    START TRANSACTION;
    CALL sp_internal_record_failed(p_account_id,p_amount,'Withdrawal',p_channel);
    COMMIT;
   END;
  END IF;
  RESIGNAL;
 END;
 SET p_transaction_id=NULL,p_balance_after=NULL;
 IF p_amount IS NULL OR p_amount<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: amount must be positive'; END IF;
 START TRANSACTION;
 CALL sp_internal_post_single(p_account_id,p_amount,'Withdrawal',p_channel,p_employee_id,p_device_id,p_location_id,p_transaction_id,p_balance_after);
 COMMIT;
END$$
DELIMITER ;
