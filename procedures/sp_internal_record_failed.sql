DELIMITER $$
CREATE PROCEDURE sp_internal_record_failed(IN p_account_id INT, IN p_amount DECIMAL(14,2), IN p_type VARCHAR(20), IN p_channel VARCHAR(10))
SQL SECURITY DEFINER
BEGIN
 DECLARE v_balance DECIMAL(14,2); DECLARE v_tx BIGINT;
 -- No transaction control: the public handler owns this separate small transaction.
 IF p_amount IS NOT NULL AND p_amount>0 AND EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_account_id) THEN
  SELECT balance INTO v_balance FROM Accounts WHERE account_id=p_account_id FOR UPDATE;
  CALL sp_internal_insert_ledger(p_account_id,NULL,NULL,NULL,NULL,NULL,p_type,p_amount,v_balance,IF(p_channel IN ('ATM','Branch','Online','Mobile'),p_channel,'Online'),'Failed',NULL,v_tx);
 END IF;
END$$
DELIMITER ;
