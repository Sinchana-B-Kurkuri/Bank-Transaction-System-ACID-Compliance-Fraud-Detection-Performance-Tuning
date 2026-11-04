DELIMITER $$
CREATE PROCEDURE sp_disburse_loan(IN p_customer_id INT, IN p_disbursement_account_id INT, IN p_principal DECIMAL(14,2), IN p_interest_rate DECIMAL(5,2), IN p_tenure_months INT, IN p_employee_id INT, OUT p_loan_id INT) SQL SECURITY DEFINER
BEGIN
 DECLARE v_active BOOLEAN; DECLARE v_owner INT; DECLARE v_state VARCHAR(10); DECLARE v_tx BIGINT; DECLARE v_bal DECIMAL(14,2); DECLARE v_actor VARCHAR(10); DECLARE v_e INT; DECLARE v_c INT;
 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK; SET p_loan_id=NULL;
  IF v_errno IN (5003,5004,5005,5006,5010) THEN BEGIN
   DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
   START TRANSACTION; CALL sp_internal_record_failed(p_disbursement_account_id,p_principal,'Deposit',IF(p_employee_id IS NULL,'Online','Branch')); COMMIT;
  END; END IF;
  RESIGNAL;
 END;
 SET p_loan_id=NULL;
 IF p_principal IS NULL OR p_principal<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: principal must be positive'; END IF;
 IF p_interest_rate IS NULL OR p_interest_rate<0 OR p_tenure_months IS NULL OR p_tenure_months<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid loan rate or tenure'; END IF;
 START TRANSACTION;
 IF p_customer_id IS NULL OR NOT EXISTS(SELECT 1 FROM Customers WHERE customer_id=p_customer_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5007,MESSAGE_TEXT='E_INVALID_REFERENCE: customer does not exist'; END IF;
 SELECT is_active INTO v_active FROM Customers WHERE customer_id=p_customer_id FOR UPDATE;
 IF NOT v_active THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5011,MESSAGE_TEXT='E_INVALID_TRANSITION: customer must be active'; END IF;
 CALL sp_resolve_actor(USER(),v_actor,v_e,v_c);
 IF v_actor='Customer' AND v_c<>p_customer_id THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: loan customer mismatch'; END IF;
 IF p_disbursement_account_id IS NOT NULL THEN
  IF NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_disbursement_account_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5007,MESSAGE_TEXT='E_INVALID_REFERENCE: disbursement account does not exist'; END IF;
  SELECT customer_id,status INTO v_owner,v_state FROM Accounts WHERE account_id=p_disbursement_account_id FOR UPDATE;
  IF v_owner<>p_customer_id THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: disbursement account owner mismatch'; END IF;
  IF v_state<>'Active' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5003,MESSAGE_TEXT='E_ACCOUNT_NOT_ACTIVE: disbursement account must be active'; END IF;
 ELSEIF p_employee_id IS NOT NULL THEN CALL sp_internal_assert_staff(p_employee_id,NULL,'Teller,Manager,DBA');
 END IF;
 INSERT INTO Loans(customer_id,disbursement_account_id,principal_amount,interest_rate,tenure_months,status,disbursed_date) VALUES(p_customer_id,p_disbursement_account_id,p_principal,p_interest_rate,p_tenure_months,'Active',CURDATE());
 SET p_loan_id=LAST_INSERT_ID();
 IF p_disbursement_account_id IS NOT NULL THEN CALL sp_internal_post_single(p_disbursement_account_id,p_principal,'Deposit',IF(p_employee_id IS NULL,'Online','Branch'),p_employee_id,NULL,NULL,v_tx,v_bal); END IF;
 COMMIT;
END$$
DELIMITER ;
