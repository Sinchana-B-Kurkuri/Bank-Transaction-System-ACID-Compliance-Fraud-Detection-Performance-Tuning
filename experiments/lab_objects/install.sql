-- LAB ONLY — never ship
SOURCE experiments/lab_objects/uninstall.sql;
DELIMITER $$
CREATE PROCEDURE sp_transfer_naive(IN p_from INT,IN p_to INT,IN p_amount DECIMAL(14,2))
BEGIN
 DECLARE b DECIMAL(14,2); DECLARE t DECIMAL(14,2); DECLARE g CHAR(36); DECLARE x BIGINT; DECLARE s INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 SELECT balance INTO b FROM Accounts WHERE account_id=p_from;
 SELECT SLEEP(IFNULL(@lab_sleep_seconds,5)) INTO s;
 UPDATE Accounts SET balance=b-p_amount WHERE account_id=p_from;
 UPDATE Accounts SET balance=balance+p_amount WHERE account_id=p_to;
 SELECT balance INTO t FROM Accounts WHERE account_id=p_to;
 SET g=UUID();
 CALL sp_internal_insert_ledger(p_from,p_to,NULL,g,NULL,NULL,'TransferOut',p_amount,b-p_amount,'Online','Completed',NULL,x);
 CALL sp_internal_insert_ledger(p_to,p_from,NULL,g,NULL,NULL,'TransferIn',p_amount,t,'Online','Completed',NULL,x);
 COMMIT;
END$$
CREATE PROCEDURE sp_transfer_atomic_update(IN p_from INT,IN p_to INT,IN p_amount DECIMAL(14,2))
BEGIN
 DECLARE b DECIMAL(14,2); DECLARE t DECIMAL(14,2); DECLARE g CHAR(36); DECLARE x BIGINT; DECLARE s INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 UPDATE Accounts SET balance=balance-p_amount WHERE account_id=p_from AND balance-p_amount>=1000 AND status='Active';
 IF ROW_COUNT()<>1 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5004,MESSAGE_TEXT='LAB: insufficient funds'; END IF;
 SELECT SLEEP(IFNULL(@lab_sleep_seconds,0)) INTO s;
 UPDATE Accounts SET balance=balance+p_amount WHERE account_id=p_to;
 SELECT balance INTO b FROM Accounts WHERE account_id=p_from;
 SELECT balance INTO t FROM Accounts WHERE account_id=p_to;
 SET g=UUID();
 CALL sp_internal_insert_ledger(p_from,p_to,NULL,g,NULL,NULL,'TransferOut',p_amount,b,'Online','Completed',NULL,x);
 CALL sp_internal_insert_ledger(p_to,p_from,NULL,g,NULL,NULL,'TransferIn',p_amount,t,'Online','Completed',NULL,x);
 COMMIT;
END$$
CREATE PROCEDURE sp_lab_random_transfer()
BEGIN
 DECLARE a INT; DECLARE b INT; DECLARE n INT; DECLARE g CHAR(36); DECLARE d BIGINT; DECLARE c BIGINT;
 DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET @lab_errors=IFNULL(@lab_errors,0)+1;
 SELECT account_id INTO a FROM Accounts WHERE account_number LIKE 'LAB-%' ORDER BY RAND() LIMIT 1;
 SELECT account_id INTO b FROM Accounts WHERE account_number LIKE 'LAB-%' AND account_id<>a ORDER BY RAND() LIMIT 1;
 CALL sp_transfer_funds_retry(a,b,1+FLOOR(RAND()*50),'Online',NULL,NULL,NULL,0,5,g,d,c,n);
 IF g IS NOT NULL THEN SET @lab_success=IFNULL(@lab_success,0)+1; END IF;
END$$
CREATE PROCEDURE sp_lab_random_transfer_at_level(IN p_level TINYINT)
BEGIN
 IF p_level=1 THEN SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
 ELSEIF p_level=2 THEN SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
 ELSEIF p_level=3 THEN SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
 ELSEIF p_level=4 THEN SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 END IF;
 CALL sp_lab_random_transfer();
END$$
CREATE PROCEDURE sp_lab_stress_loop(IN p_iterations INT,IN p_seed INT)
BEGIN
 DECLARE i INT DEFAULT 0; DECLARE r DOUBLE;
 SET r=RAND(p_seed),@lab_errors=0,@lab_success=0;
 WHILE i<p_iterations DO CALL sp_lab_random_transfer(); SET i=i+1; END WHILE;
 SELECT CONCAT('RESULT|EXP-09|ALL|successful|',@lab_success);
 SELECT CONCAT('RESULT|EXP-09|ALL|errors|',@lab_errors);
END$$
CREATE PROCEDURE sp_lab_retry_loop(IN p_from INT,IN p_to INT,IN p_n INT,IN p_mode TINYINT)
BEGIN
 DECLARE i INT DEFAULT 0; DECLARE failed INT; DECLARE g CHAR(36); DECLARE d BIGINT; DECLARE c BIGINT; DECLARE attempts INT;
 WHILE i<p_n DO
  SET failed=0;
  BEGIN
   DECLARE CONTINUE HANDLER FOR 1213 SET failed=1;
   CALL sp_transfer_funds_retry(p_from,p_to,1,'Online',NULL,NULL,NULL,p_mode,5,g,d,c,attempts);
  END;
  IF failed=0 THEN SELECT 'SUCCESS'; ELSE SELECT 'RETRY_EXHAUSTED'; END IF;
  SET i=i+1;
 END WHILE;
END$$
CREATE PROCEDURE sp_lab_atomicity_loop(IN p_n INT)
BEGIN
 DECLARE i INT DEFAULT 0; DECLARE a INT; DECLARE b INT; DECLARE ba DECIMAL(14,2); DECLARE bb DECIMAL(14,2);
 DECLARE cnt BIGINT; DECLARE g CHAR(36); DECLARE d BIGINT; DECLARE c BIGINT; DECLARE caught INT; DECLARE partials INT DEFAULT 0;
 WHILE i<p_n DO
  SELECT account_id,balance INTO a,ba FROM Accounts WHERE account_number LIKE 'LAB-%' ORDER BY RAND() LIMIT 1;
  SELECT account_id,balance INTO b,bb FROM Accounts WHERE account_number LIKE 'LAB-%' AND account_id<>a ORDER BY RAND() LIMIT 1;
  SELECT COUNT(*) INTO cnt FROM Transactions;
  SET caught=0;
  BEGIN DECLARE CONTINUE HANDLER FOR 5016 SET caught=1;
   CALL sp_transfer_funds(a,b,10,'Online',NULL,NULL,NULL,1,g,d,c);
  END;
  IF caught<>1 OR ba<>(SELECT balance FROM Accounts WHERE account_id=a) OR bb<>(SELECT balance FROM Accounts WHERE account_id=b) OR cnt<>(SELECT COUNT(*) FROM Transactions) THEN SET partials=partials+1; END IF;
  SET i=i+1;
 END WHILE;
 SELECT CONCAT('RESULT|EXP-01|ALL|iterations|',i);
 SELECT CONCAT('RESULT|EXP-01|ALL|partial_transfers|',partials);
END$$
DELIMITER ;
