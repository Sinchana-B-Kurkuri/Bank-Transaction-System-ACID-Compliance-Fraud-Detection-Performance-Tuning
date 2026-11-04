DELIMITER $$
CREATE PROCEDURE sp_internal_insert_ledger(IN p_account_id INT, IN p_related INT, IN p_employee INT, IN p_group CHAR(36), IN p_device INT, IN p_location INT, IN p_type VARCHAR(20), IN p_amount DECIMAL(14,2), IN p_balance DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_status VARCHAR(12), IN p_timestamp DATETIME, OUT p_transaction_id BIGINT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_attempt INT DEFAULT 0; DECLARE v_duplicate BOOLEAN;
 SET p_transaction_id=NULL;
 reference_retry: LOOP
  SET v_attempt=v_attempt+1,v_duplicate=FALSE;
  BEGIN
   DECLARE CONTINUE HANDLER FOR 1062 SET v_duplicate=TRUE;
   INSERT INTO Transactions(account_id,related_account_id,employee_id,transfer_group_id,device_id,location_id,transaction_type,amount,balance_after,channel,status,transaction_timestamp,reference_no)
   VALUES(p_account_id,p_related,p_employee,p_group,p_device,p_location,p_type,p_amount,p_balance,p_channel,p_status,COALESCE(p_timestamp,NOW()),fn_generate_reference());
  END;
  IF NOT v_duplicate THEN SET p_transaction_id=LAST_INSERT_ID(); LEAVE reference_retry; END IF;
  IF v_attempt>=5 THEN SIGNAL SQLSTATE '23000' SET MYSQL_ERRNO=1062,MESSAGE_TEXT='E_INVALID_REFERENCE: reference collision retry exhausted'; END IF;
 END LOOP;
END$$
DELIMITER ;
