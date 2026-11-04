DELIMITER $$
CREATE PROCEDURE sp_transfer_funds(IN p_from_account_id INT, IN p_to_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, IN p_lab_mode TINYINT, OUT p_transfer_group_id CHAR(36), OUT p_debit_txn_id BIGINT, OUT p_credit_txn_id BIGINT)
SQL SECURITY DEFINER
BEGIN

 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK;
  SET p_transfer_group_id=NULL,p_debit_txn_id=NULL,p_credit_txn_id=NULL;
  IF v_errno IN (5003,5004,5005,5006,5010) THEN
   BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
    START TRANSACTION;
    CALL sp_internal_record_failed(p_from_account_id,p_amount,'TransferOut',p_channel);
    COMMIT;
   END;
  END IF;
  RESIGNAL;
 END;
 SET p_transfer_group_id=NULL,p_debit_txn_id=NULL,p_credit_txn_id=NULL;
 IF p_amount IS NULL OR p_amount<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: amount must be positive'; END IF;
 IF p_lab_mode IS NULL OR p_lab_mode NOT IN (0,1,2,3) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid lab mode'; END IF;
 IF p_from_account_id=p_to_account_id THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5005,MESSAGE_TEXT='E_SAME_ACCOUNT: accounts must differ'; END IF;
 IF p_amount>=fn_approval_threshold() THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5006,MESSAGE_TEXT='E_APPROVAL_REQUIRED: approval threshold reached'; END IF;
 -- RELEASE_GUARD_PLACEHOLDER
 START TRANSACTION;
 -- LAB_HOOK_BEGIN
 -- The hook executes in the private helper within this public transaction.
 -- LAB_HOOK_END
 -- LAB_NAIVE_BEGIN
 -- Lab lock-order selection is delegated to the same private helper.
 -- LAB_NAIVE_END
 CALL sp_internal_post_transfer(p_from_account_id,p_to_account_id,p_amount,p_channel,p_employee_id,p_device_id,p_location_id,p_lab_mode,0,p_transfer_group_id,p_debit_txn_id,p_credit_txn_id);
 COMMIT;
END$$
DELIMITER ;
