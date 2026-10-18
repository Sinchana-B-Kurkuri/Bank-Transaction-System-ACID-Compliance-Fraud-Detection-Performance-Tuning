DELIMITER $$
CREATE PROCEDURE sp_update_customer(IN p_customer_id INT, IN p_full_name VARCHAR(100), IN p_address VARCHAR(200), IN p_email VARCHAR(100), IN p_phone VARCHAR(20), IN p_kyc_status VARCHAR(10), IN p_is_active TINYINT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_active BOOLEAN; DECLARE v_actor VARCHAR(10); DECLARE v_e INT; DECLARE v_c INT;
 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR 1062 BEGIN ROLLBACK; SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: duplicate identity attribute'; END;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK;
  
  
  RESIGNAL;
 END;
 IF (p_full_name IS NOT NULL AND TRIM(p_full_name)='') OR (p_address IS NOT NULL AND TRIM(p_address)='') OR (p_email IS NOT NULL AND p_email NOT LIKE '%_@_%._%') OR (p_phone IS NOT NULL AND NOT REGEXP_LIKE(p_phone,'^[+]?[0-9]{7,19}$','c')) OR (p_kyc_status IS NOT NULL AND p_kyc_status NOT IN ('Pending','Verified','Rejected')) OR (p_is_active IS NOT NULL AND p_is_active NOT IN (0,1)) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid customer update'; END IF;
 START TRANSACTION;
 IF p_customer_id IS NULL OR NOT EXISTS(SELECT 1 FROM Customers WHERE customer_id=p_customer_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5007,MESSAGE_TEXT='E_INVALID_REFERENCE: customer does not exist'; END IF;
 SELECT is_active INTO v_active FROM Customers WHERE customer_id=p_customer_id FOR UPDATE;
 CALL sp_resolve_actor(USER(),v_actor,v_e,v_c);
 IF v_actor='Customer' AND v_c<>p_customer_id THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: customer identity mismatch'; END IF;
 IF p_is_active=0 AND EXISTS(SELECT 1 FROM Accounts WHERE customer_id=p_customer_id AND status<>'Closed') THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5011,MESSAGE_TEXT='E_INVALID_TRANSITION: customer has a non-closed account'; END IF;
 UPDATE Customers SET full_name=COALESCE(p_full_name,full_name),address=COALESCE(p_address,address),email=COALESCE(p_email,email),phone=COALESCE(p_phone,phone),kyc_status=COALESCE(p_kyc_status,kyc_status),is_active=COALESCE(p_is_active,is_active) WHERE customer_id=p_customer_id;
 COMMIT;
END$$
DELIMITER ;
