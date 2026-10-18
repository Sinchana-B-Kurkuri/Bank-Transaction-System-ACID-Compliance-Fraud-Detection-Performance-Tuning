DELIMITER $$
CREATE PROCEDURE sp_set_account_status(IN p_account_id INT, IN p_new_status VARCHAR(10), IN p_employee_id INT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_status VARCHAR(10);
 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK;
  
  
  RESIGNAL;
 END;
 IF p_new_status IS NULL OR p_new_status NOT IN ('Active','Frozen') THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5011,MESSAGE_TEXT='E_INVALID_TRANSITION: only Active and Frozen transitions allowed'; END IF;
 START TRANSACTION;
 IF p_account_id IS NULL OR NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_account_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: account does not exist'; END IF;
 SELECT status INTO v_status FROM Accounts WHERE account_id=p_account_id FOR UPDATE;
 IF v_status='Closed' OR v_status=p_new_status THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5011,MESSAGE_TEXT='E_INVALID_TRANSITION: invalid status transition'; END IF;
 CALL sp_internal_assert_staff(p_employee_id,p_account_id,'Teller,Manager');
 UPDATE Accounts SET status=p_new_status WHERE account_id=p_account_id;
 COMMIT;
END$$
DELIMITER ;
