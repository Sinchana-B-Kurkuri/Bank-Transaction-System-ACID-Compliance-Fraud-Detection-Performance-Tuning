DELIMITER $$
CREATE PROCEDURE sp_internal_assert_staff(IN p_employee_id INT, IN p_account_id INT, IN p_roles VARCHAR(40))
SQL SECURITY DEFINER
BEGIN
 DECLARE v_actor VARCHAR(10); DECLARE v_e INT; DECLARE v_c INT;
 CALL sp_resolve_actor(USER(),v_actor,v_e,v_c);
 IF v_actor='Customer' OR (v_actor='Employee' AND NOT (p_employee_id <=> v_e)) OR p_employee_id IS NULL OR NOT EXISTS(SELECT 1 FROM Employees e WHERE e.employee_id=p_employee_id AND e.is_active AND FIND_IN_SET(e.role,p_roles)>0 AND (p_account_id IS NULL OR e.branch_id=(SELECT branch_id FROM Accounts WHERE account_id=p_account_id))) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: active authorized staff required'; END IF;
END$$
DELIMITER ;
