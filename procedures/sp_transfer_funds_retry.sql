DELIMITER $$
CREATE PROCEDURE sp_transfer_funds_retry(IN p_from_account_id INT, IN p_to_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, IN p_lab_mode TINYINT, IN p_max_retries INT, OUT p_transfer_group_id CHAR(36), OUT p_debit_txn_id BIGINT, OUT p_credit_txn_id BIGINT, OUT p_attempts INT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_limit INT; DECLARE v_error INT DEFAULT 0; DECLARE v_backoff DOUBLE;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 SET p_attempts=0,p_transfer_group_id=NULL,p_debit_txn_id=NULL,p_credit_txn_id=NULL;
 SET v_limit=COALESCE(p_max_retries,5);
 IF v_limit<1 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: retry limit must be positive'; END IF;
 retry_loop: LOOP
  SET p_attempts=p_attempts+1,v_error=0;
  BEGIN
   DECLARE CONTINUE HANDLER FOR 1213 SET v_error=1213;
   DECLARE CONTINUE HANDLER FOR 1205 SET v_error=1205;
   CALL sp_transfer_funds(p_from_account_id,p_to_account_id,p_amount,p_channel,p_employee_id,p_device_id,p_location_id,p_lab_mode,p_transfer_group_id,p_debit_txn_id,p_credit_txn_id);
  END;
  IF v_error=0 THEN LEAVE retry_loop; END IF;
  BEGIN
   DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
   START TRANSACTION;
   INSERT INTO bank_lab.Experiment_Log(db_name,exp_id,event_type,detail) VALUES(DATABASE(),'RETRY',IF(v_error=1213,'DEADLOCK_RETRY','LOCKWAIT_RETRY'),JSON_OBJECT('from_account',p_from_account_id,'to_account',p_to_account_id,'attempt',p_attempts));
   COMMIT;
  END;
  IF p_attempts>=v_limit THEN
   BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
    START TRANSACTION;
    INSERT INTO bank_lab.Experiment_Log(db_name,exp_id,event_type,detail) VALUES(DATABASE(),'RETRY','RETRY_EXHAUSTED',JSON_OBJECT('from_account',p_from_account_id,'to_account',p_to_account_id,'attempt',p_attempts));
    COMMIT;
   END;
   SIGNAL SQLSTATE '40001' SET MYSQL_ERRNO=1213,MESSAGE_TEXT='E_RETRY_EXHAUSTED: whole-transaction retry limit reached';
  END IF;
  SELECT SLEEP(RAND()*0.2) INTO v_backoff;
 END LOOP;
END$$
DELIMITER ;
