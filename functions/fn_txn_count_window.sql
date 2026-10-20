DELIMITER $$
CREATE FUNCTION fn_txn_count_window(p_account_id INT, p_as_of DATETIME, p_window_minutes INT)
RETURNS INT
READS SQL DATA SQL SECURITY DEFINER
BEGIN
  DECLARE v_count INT DEFAULT 0;
  IF p_account_id IS NULL OR p_as_of IS NULL OR p_window_minutes IS NULL OR p_window_minutes < 1 THEN
    RETURN 0;
  END IF;
  SELECT COUNT(*) INTO v_count
    FROM Transactions t
   WHERE t.account_id=p_account_id
     AND t.status='Completed'
     AND t.transaction_timestamp > DATE_SUB(p_as_of, INTERVAL p_window_minutes MINUTE)
     AND t.transaction_timestamp <= p_as_of;
  RETURN v_count;
END$$
DELIMITER ;
