DELIMITER $$
CREATE PROCEDURE sp_internal_post_single(IN p_account_id INT, IN p_amount DECIMAL(14,2), IN p_type VARCHAR(20), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, OUT p_transaction_id BIGINT, OUT p_balance_after DECIMAL(14,2))
SQL SECURITY DEFINER
BEGIN
 DECLARE v_balance DECIMAL(14,2); DECLARE v_min DECIMAL(12,2); DECLARE v_status VARCHAR(10);
 IF p_amount IS NULL OR p_amount<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: amount must be positive'; END IF;
 IF p_account_id IS NULL OR NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_account_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: account does not exist'; END IF;
 SELECT a.balance,a.status,t.min_balance INTO v_balance,v_status,v_min FROM Accounts a JOIN Account_Types t USING(account_type_id) WHERE a.account_id=p_account_id FOR UPDATE OF a;
 IF v_status<>'Active' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5003,MESSAGE_TEXT='E_ACCOUNT_NOT_ACTIVE: active account required'; END IF;
 CALL sp_internal_authorize(p_account_id,p_channel,p_employee_id,p_type='Withdrawal',0);
 IF p_type='Withdrawal' AND v_balance-p_amount<v_min THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5004,MESSAGE_TEXT='E_INSUFFICIENT_FUNDS: minimum balance would be breached'; END IF;
 IF p_type='Deposit' THEN UPDATE Accounts SET balance=balance+p_amount WHERE account_id=p_account_id; SET p_balance_after=v_balance+p_amount;
 ELSEIF p_type='Withdrawal' THEN UPDATE Accounts SET balance=balance-p_amount WHERE account_id=p_account_id; SET p_balance_after=v_balance-p_amount;
 ELSE SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: unsupported single-leg posting'; END IF;
 CALL sp_internal_insert_ledger(p_account_id,NULL,p_employee_id,NULL,p_device_id,p_location_id,p_type,p_amount,p_balance_after,p_channel,'Completed',NULL,p_transaction_id);
END$$
DELIMITER ;
