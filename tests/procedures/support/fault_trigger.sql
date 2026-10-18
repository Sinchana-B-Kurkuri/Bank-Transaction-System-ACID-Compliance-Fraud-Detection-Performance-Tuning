-- Synthetic error-path probe, not a real deadlock/lock-wait experiment.
DROP TRIGGER IF EXISTS p3_test_retry_fault;
DELIMITER $$
CREATE TRIGGER p3_test_retry_fault BEFORE INSERT ON Transactions FOR EACH ROW FOLLOWS trg_transactions_bi_device_owner
BEGIN
 IF NEW.transaction_type='TransferOut' AND COALESCE(@p3_fault_remaining,0)>0 THEN
  SET @p3_fault_remaining=@p3_fault_remaining-1;
  IF @p3_fault_errno=1213 THEN SIGNAL SQLSTATE '40001' SET MYSQL_ERRNO=1213,MESSAGE_TEXT='synthetic deadlock code probe';
  ELSE SIGNAL SQLSTATE 'HY000' SET MYSQL_ERRNO=1205,MESSAGE_TEXT='synthetic lock wait code probe'; END IF;
 END IF;
END$$
DELIMITER ;
