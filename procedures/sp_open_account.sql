DELIMITER $$
CREATE PROCEDURE sp_open_account(IN p_customer_id INT, IN p_branch_id INT, IN p_account_type_id INT, IN p_initial_deposit DECIMAL(14,2), IN p_employee_id INT, IN p_account_number VARCHAR(20), OUT p_account_id INT, OUT p_account_number_out VARCHAR(20))
SQL SECURITY DEFINER
BEGIN
 DECLARE v_active BOOLEAN; DECLARE v_min DECIMAL(12,2); DECLARE v_attempt INT DEFAULT 0; DECLARE v_dup BOOLEAN; DECLARE v_tx BIGINT; DECLARE v_bal DECIMAL(14,2); DECLARE v_actor VARCHAR(10); DECLARE v_e INT; DECLARE v_c INT;
 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK;
  SET p_account_id=NULL,p_account_number_out=NULL;
  
  RESIGNAL;
 END;
 SET p_account_id=NULL,p_account_number_out=NULL;
 IF p_initial_deposit IS NULL OR p_initial_deposit<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: opening deposit must be positive'; END IF;
 IF p_account_number IS NOT NULL AND TRIM(p_account_number)='' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: account number cannot be empty'; END IF;
 START TRANSACTION;
 IF p_customer_id IS NULL OR NOT EXISTS(SELECT 1 FROM Customers WHERE customer_id=p_customer_id) OR p_branch_id IS NULL OR NOT EXISTS(SELECT 1 FROM Branches WHERE branch_id=p_branch_id) OR p_account_type_id IS NULL OR NOT EXISTS(SELECT 1 FROM Account_Types WHERE account_type_id=p_account_type_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5007,MESSAGE_TEXT='E_INVALID_REFERENCE: opening reference does not exist'; END IF;
 SELECT is_active INTO v_active FROM Customers WHERE customer_id=p_customer_id FOR UPDATE;
 IF NOT v_active THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5011,MESSAGE_TEXT='E_INVALID_TRANSITION: inactive customer cannot open account'; END IF;
 CALL sp_resolve_actor(USER(),v_actor,v_e,v_c);
 IF v_actor='Customer' AND v_c<>p_customer_id THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: customer identity mismatch'; END IF;
 SELECT min_balance INTO v_min FROM Account_Types WHERE account_type_id=p_account_type_id;
 IF p_initial_deposit<v_min THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5004,MESSAGE_TEXT='E_INSUFFICIENT_FUNDS: opening deposit below minimum'; END IF;
 account_number_retry: LOOP
  SET v_attempt=v_attempt+1,v_dup=FALSE;
  SET p_account_number_out=COALESCE(p_account_number,CONCAT('AC',LPAD(FLOOR(RAND()*10000000000),10,'0')));
  BEGIN
   DECLARE CONTINUE HANDLER FOR 1062 SET v_dup=TRUE;
   INSERT INTO Accounts(customer_id,branch_id,account_type_id,account_number,balance,status,opened_date) VALUES(p_customer_id,p_branch_id,p_account_type_id,p_account_number_out,0,'Active',CURDATE());
  END;
  IF NOT v_dup THEN SET p_account_id=LAST_INSERT_ID(); LEAVE account_number_retry; END IF;
  IF p_account_number IS NOT NULL OR v_attempt>=5 THEN SIGNAL SQLSTATE '23000' SET MYSQL_ERRNO=1062,MESSAGE_TEXT='E_INVALID_REFERENCE: duplicate account number'; END IF;
 END LOOP;
 CALL sp_internal_post_single(p_account_id,p_initial_deposit,'Deposit',IF(p_employee_id IS NULL,'Online','Branch'),p_employee_id,NULL,NULL,v_tx,v_bal);
 COMMIT;
END$$
DELIMITER ;
