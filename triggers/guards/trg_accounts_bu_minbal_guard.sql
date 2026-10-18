DELIMITER $$
CREATE TRIGGER trg_accounts_bu_minbal_guard BEFORE UPDATE ON Accounts FOR EACH ROW
BEGIN
 DECLARE v_min DECIMAL(12,2);
 IF OLD.status='Closed' AND (NOT (NEW.balance <=> OLD.balance) OR NEW.status<>'Closed') THEN
  SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5011,MESSAGE_TEXT='E_INVALID_TRANSITION: closed account cannot change balance or status';
 END IF;
 SELECT min_balance INTO v_min FROM Account_Types WHERE account_type_id=NEW.account_type_id;
 IF NOT (NEW.balance <=> OLD.balance) AND NEW.balance=0 AND NEW.status<>'Closed' THEN
  SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5015,MESSAGE_TEXT='E_MINBAL_GUARD: zero balance requires closure';
 END IF;
 IF NEW.balance<OLD.balance AND NEW.balance<v_min AND NOT (NEW.balance=0 AND NEW.status='Closed') THEN
  SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5015,MESSAGE_TEXT='E_MINBAL_GUARD: decrease would breach minimum balance';
 END IF;
END$$
DELIMITER ;
