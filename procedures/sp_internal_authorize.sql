DELIMITER $$
CREATE PROCEDURE sp_internal_authorize(IN p_account_id INT, IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_is_debit TINYINT, IN p_allow_manager TINYINT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_actor VARCHAR(10); DECLARE v_e INT; DECLARE v_c INT; DECLARE v_owner INT; DECLARE v_branch INT;
 IF p_channel IS NULL OR p_channel NOT IN ('ATM','Branch','Online','Mobile') THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid channel'; END IF;
 SELECT customer_id,branch_id INTO v_owner,v_branch FROM Accounts WHERE account_id=p_account_id;
 CALL sp_resolve_actor(USER(),v_actor,v_e,v_c);
 IF (v_actor='Customer' AND p_is_debit=1 AND NOT (v_c <=> v_owner)) OR (v_actor='Employee' AND p_employee_id IS NOT NULL AND NOT (p_employee_id <=> v_e)) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: actor does not match operation'; END IF;
 IF p_channel='Branch' THEN
  IF p_employee_id IS NULL OR NOT EXISTS(SELECT 1 FROM Employees WHERE employee_id=p_employee_id AND is_active AND branch_id=v_branch AND (role='Teller' OR (p_allow_manager=1 AND role='Manager'))) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: branch staff mismatch'; END IF;
 ELSEIF p_employee_id IS NOT NULL THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: non-branch channel requires no employee'; END IF;
END$$
DELIMITER ;
