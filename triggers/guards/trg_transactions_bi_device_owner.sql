DELIMITER $$
CREATE TRIGGER trg_transactions_bi_device_owner BEFORE INSERT ON Transactions FOR EACH ROW
BEGIN
 DECLARE v_account_owner INT;
 DECLARE v_device_owner INT;
 IF NEW.related_account_id=NEW.account_id THEN
  SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5005,MESSAGE_TEXT='E_SAME_ACCOUNT: counterparty must be a different account';
 END IF;
 IF NEW.device_id IS NOT NULL THEN
  SET v_account_owner=(SELECT customer_id FROM Accounts WHERE account_id=NEW.account_id);
  SET v_device_owner=(SELECT customer_id FROM Devices WHERE device_id=NEW.device_id);
  -- A missing reference is left to the FK (1452); an existing mismatched device is 5014.
  IF v_account_owner IS NOT NULL AND v_device_owner IS NOT NULL AND v_account_owner<>v_device_owner THEN
   SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5014,MESSAGE_TEXT='E_DEVICE_OWNER_MISMATCH: device belongs to another customer';
  END IF;
 END IF;
END$$
DELIMITER ;
