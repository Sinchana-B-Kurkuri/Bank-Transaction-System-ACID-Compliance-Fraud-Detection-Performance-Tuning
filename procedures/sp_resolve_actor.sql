DELIMITER $$
CREATE PROCEDURE sp_resolve_actor(IN p_db_login VARCHAR(100), OUT p_actor_type VARCHAR(10), OUT p_employee_id INT, OUT p_customer_id INT)
READS SQL DATA SQL SECURITY DEFINER
BEGIN
 DECLARE v_matches INT DEFAULT 0;
 DECLARE v_user VARCHAR(100);
 SET p_actor_type='System',p_employee_id=NULL,p_customer_id=NULL;
 IF p_db_login IS NOT NULL THEN
  SET v_user=SUBSTRING_INDEX(p_db_login,'@',1);
  SELECT COUNT(*) INTO v_matches FROM DB_User_Map WHERE BINARY db_login=BINARY p_db_login;
  IF v_matches=1 THEN
   SELECT actor_type,employee_id,customer_id INTO p_actor_type,p_employee_id,p_customer_id
   FROM DB_User_Map WHERE BINARY db_login=BINARY p_db_login;
  ELSE
   -- Prefer an explicit host-independent user key. Conflicting host mappings remain unattributed.
   SELECT COUNT(*) INTO v_matches FROM DB_User_Map WHERE BINARY db_login=BINARY v_user;
   IF v_matches=1 THEN
    SELECT actor_type,employee_id,customer_id INTO p_actor_type,p_employee_id,p_customer_id
    FROM DB_User_Map WHERE BINARY db_login=BINARY v_user;
   ELSE
    SELECT COUNT(DISTINCT CONCAT(actor_type,':',COALESCE(employee_id,0),':',COALESCE(customer_id,0)))
    INTO v_matches FROM DB_User_Map WHERE BINARY SUBSTRING_INDEX(db_login,'@',1)=BINARY v_user;
    IF v_matches=1 THEN
     SELECT actor_type,employee_id,customer_id INTO p_actor_type,p_employee_id,p_customer_id
     FROM DB_User_Map WHERE BINARY SUBSTRING_INDEX(db_login,'@',1)=BINARY v_user
     ORDER BY BINARY db_login LIMIT 1;
    END IF;
   END IF;
  END IF;
 END IF;
END$$
DELIMITER ;
