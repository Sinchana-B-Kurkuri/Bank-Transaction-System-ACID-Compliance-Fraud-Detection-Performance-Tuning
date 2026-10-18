-- LAB ONLY -- never ship. Run on scratch after seed + lab accounts.
SELECT CONCAT('META|',VERSION(),'|',NOW(6));
SELECT @@innodb_flush_log_at_trx_commit,@@sync_binlog,@@innodb_doublewrite,@@log_bin;
DROP PROCEDURE IF EXISTS lab_durability_commit;
DELIMITER $$
CREATE PROCEDURE lab_durability_commit()
BEGIN
 DECLARE i INT DEFAULT 0; DECLARE a INT;
 SELECT account_id INTO a FROM Accounts WHERE account_number='LAB-0001';
 WHILE i<100 DO
  CALL sp_deposit(a,3.00,'Online',NULL,NULL,NULL,@t,@b);
  SET i=i+1;
 END WHILE;
END$$
DELIMITER ;
CALL lab_durability_commit();
DROP PROCEDURE lab_durability_commit;
CHECKSUM TABLE Accounts, Transactions;
SELECT COUNT(*),SUM(balance) FROM Accounts;
SELECT COUNT(*) FROM Transactions;
