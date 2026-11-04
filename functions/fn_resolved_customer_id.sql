-- Mirrors sp_resolve_actor: exact login, explicit bare-user key, then unanimous host variants.
DELIMITER $$
CREATE FUNCTION fn_resolved_customer_id(p_login VARCHAR(100))
RETURNS INT
READS SQL DATA SQL SECURITY DEFINER
BEGIN
  DECLARE v_user VARCHAR(100);
  DECLARE v_n INT DEFAULT 0;
  DECLARE v_customer INT DEFAULT NULL;
  DECLARE v_actor VARCHAR(10);
  IF p_login IS NULL THEN RETURN NULL; END IF;
  SET v_user=SUBSTRING_INDEX(p_login,'@',1);
  SELECT COUNT(*) INTO v_n FROM DB_User_Map WHERE BINARY db_login=BINARY p_login;
  IF v_n=1 THEN
    SELECT customer_id INTO v_customer FROM DB_User_Map WHERE BINARY db_login=BINARY p_login AND actor_type='Customer';
    RETURN v_customer;
  END IF;
  SELECT COUNT(*) INTO v_n FROM DB_User_Map WHERE BINARY db_login=BINARY v_user;
  IF v_n=1 THEN
    SELECT customer_id INTO v_customer FROM DB_User_Map WHERE BINARY db_login=BINARY v_user AND actor_type='Customer';
    RETURN v_customer;
  END IF;
  SELECT COUNT(DISTINCT CONCAT(actor_type,':',COALESCE(employee_id,0),':',COALESCE(customer_id,0)))
    INTO v_n FROM DB_User_Map WHERE BINARY SUBSTRING_INDEX(db_login,'@',1)=BINARY v_user;
  IF v_n<>1 THEN RETURN NULL; END IF;
  SELECT MAX(customer_id),MAX(actor_type) INTO v_customer,v_actor
    FROM DB_User_Map WHERE BINARY SUBSTRING_INDEX(db_login,'@',1)=BINARY v_user;
  IF v_actor='Customer' THEN RETURN v_customer; END IF;
  RETURN NULL;
END$$
DELIMITER ;
