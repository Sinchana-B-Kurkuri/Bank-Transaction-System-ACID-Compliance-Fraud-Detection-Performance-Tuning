-- LAB ONLY — never ship
DROP PROCEDURE IF EXISTS sp_lab_setup;
DELIMITER $$
CREATE PROCEDURE sp_lab_setup()
BEGIN
 DECLARE c INT; DECLARE b INT; DECLARE t INT; DECLARE i INT DEFAULT 1; DECLARE a INT; DECLARE n VARCHAR(20);
 SELECT customer_id INTO c FROM Customers WHERE email='lab.customer@example.invalid';
 IF c IS NULL THEN CALL sp_register_customer('Synthetic lab customer','1990-01-01',NULL,'lab.customer@example.invalid','+990000000001','Synthetic lab address','SYN-LAB-000001','Passport',c); END IF;
 SELECT branch_id INTO b FROM Branches WHERE ifsc_code='SYNB0000001';
 SELECT account_type_id INTO t FROM Account_Types WHERE type_name='Savings';
 WHILE i<=100 DO
  SET n=CONCAT('LAB-',LPAD(i,4,'0'));
  IF NOT EXISTS(SELECT 1 FROM Accounts WHERE account_number=n) THEN CALL sp_open_account(c,b,t,1000000,NULL,n,a,n); END IF;
  SET i=i+1;
 END WHILE;
END$$
DELIMITER ;
CALL sp_lab_setup();
DROP PROCEDURE sp_lab_setup;
SELECT CONCAT('RESULT|LAB|ALL|accounts|',COUNT(*)) FROM Accounts WHERE account_number LIKE 'LAB-%';
