DELIMITER $$
CREATE PROCEDURE sp_review_fraud_flag(IN p_flag_id INT, IN p_new_status VARCHAR(12), IN p_manager_employee_id INT) SQL SECURITY DEFINER
BEGIN
 DECLARE v_status VARCHAR(12);
 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK; 
  
  RESIGNAL;
 END;
 IF p_new_status IS NULL OR p_new_status NOT IN ('UnderReview','Confirmed','Dismissed') THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5011,MESSAGE_TEXT='E_INVALID_TRANSITION: invalid flag transition'; END IF;
 START TRANSACTION;
 CALL sp_internal_assert_staff(p_manager_employee_id,NULL,'Manager');
 IF p_flag_id IS NULL OR NOT EXISTS(SELECT 1 FROM Fraud_Flags WHERE flag_id=p_flag_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5007,MESSAGE_TEXT='E_INVALID_REFERENCE: flag does not exist'; END IF;
 SELECT flag_status INTO v_status FROM Fraud_Flags WHERE flag_id=p_flag_id FOR UPDATE;
 IF NOT ((v_status='Open' AND p_new_status='UnderReview') OR (v_status='UnderReview' AND p_new_status IN ('Confirmed','Dismissed'))) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5011,MESSAGE_TEXT='E_INVALID_TRANSITION: illegal flag transition'; END IF;
 UPDATE Fraud_Flags SET flag_status=p_new_status,reviewed_by=p_manager_employee_id WHERE flag_id=p_flag_id;
 COMMIT;
END$$
DELIMITER ;
