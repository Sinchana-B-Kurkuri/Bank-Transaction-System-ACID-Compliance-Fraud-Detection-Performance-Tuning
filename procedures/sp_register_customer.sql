DELIMITER $$
CREATE PROCEDURE sp_register_customer(IN p_full_name VARCHAR(100), IN p_dob DATE, IN p_gender VARCHAR(15), IN p_email VARCHAR(100), IN p_phone VARCHAR(20), IN p_address VARCHAR(200), IN p_id_proof_number VARCHAR(30), IN p_id_proof_type VARCHAR(20), OUT p_customer_id INT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR 1062 BEGIN ROLLBACK; SET p_customer_id=NULL; SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: duplicate identity attribute'; END;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK;
  SET p_customer_id=NULL;
  
  RESIGNAL;
 END;
 SET p_customer_id=NULL;
 IF NULLIF(TRIM(p_full_name),'') IS NULL OR p_dob IS NULL OR p_dob>CURDATE() OR p_email IS NULL OR p_email NOT LIKE '%_@_%._%' OR p_phone IS NULL OR NOT REGEXP_LIKE(p_phone,'^[+]?[0-9]{7,19}$','c') OR NULLIF(TRIM(p_address),'') IS NULL OR NULLIF(TRIM(p_id_proof_number),'') IS NULL OR p_id_proof_type IS NULL OR p_id_proof_type NOT IN ('Aadhaar','PAN','Passport','DrivingLicense','VoterID') THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid customer attributes'; END IF;
 START TRANSACTION;
 INSERT INTO Customers(full_name,dob,gender,email,phone,address,id_proof_number,id_proof_type,kyc_status,is_active) VALUES(TRIM(p_full_name),p_dob,p_gender,p_email,p_phone,p_address,p_id_proof_number,p_id_proof_type,'Pending',TRUE);
 SET p_customer_id=LAST_INSERT_ID();
 COMMIT;
END$$
DELIMITER ;
