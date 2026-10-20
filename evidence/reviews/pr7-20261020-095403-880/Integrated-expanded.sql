-- Run from repository root through build/rebuild.ps1 (fail-fast UTF-8 batch).
SET SESSION sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
CREATE DATABASE IF NOT EXISTS bank_review_lab_1020095404 CHARACTER SET utf8mb4;
CREATE TABLE IF NOT EXISTS bank_review_lab_1020095404.Experiment_Log (
 log_id BIGINT AUTO_INCREMENT PRIMARY KEY, db_name VARCHAR(64), exp_id VARCHAR(16), event_type VARCHAR(40),
 detail JSON NULL, created_at DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS bank_review_lab_1020095404.Test_Results (
 result_id BIGINT AUTO_INCREMENT PRIMARY KEY, run_id VARCHAR(40), db_name VARCHAR(64), test_name VARCHAR(200),
 status ENUM('PASS','FAIL'), detail VARCHAR(500), created_at DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB;
DELIMITER $$
DROP PROCEDURE IF EXISTS bank_review_lab_1020095404.sp_expect_error$$
CREATE PROCEDURE bank_review_lab_1020095404.sp_expect_error(IN p_db VARCHAR(64), IN p_test VARCHAR(200), IN p_sql TEXT, IN p_expected_errno INT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_errno INT DEFAULT 0;
 DECLARE v_prepared BOOLEAN DEFAULT FALSE;
 DECLARE v_status VARCHAR(4);
 DECLARE v_detail VARCHAR(500);
 BEGIN
  -- Strict enum conversion can report errno 1265 with SQLSTATE class 01.
  DECLARE EXIT HANDLER FOR SQLEXCEPTION, SQLWARNING
  BEGIN
   GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
  END;
  SET @lab_sql = REPLACE(p_sql,'{db}',REPLACE(p_db,'`','``'));
  PREPARE lab_stmt FROM @lab_sql;
  SET v_prepared=TRUE;
  EXECUTE lab_stmt;
 END;
 IF v_prepared THEN DEALLOCATE PREPARE lab_stmt; END IF;
 SET v_status=IF(v_errno<>0 AND (p_expected_errno IS NULL OR p_expected_errno=v_errno),'PASS','FAIL');
 SET v_detail=CONCAT('expected errno=',COALESCE(p_expected_errno,'any'),'; actual errno=',v_errno);
 INSERT INTO bank_review_lab_1020095404.Test_Results(run_id,db_name,test_name,status,detail) VALUES(COALESCE(@test_run_id,'adhoc'),p_db,p_test,v_status,v_detail);
 SELECT CONCAT('TEST|',v_status,'|',p_test,'|',v_detail) AS result;
END$$
DROP PROCEDURE IF EXISTS bank_review_lab_1020095404.sp_expect_ok$$
CREATE PROCEDURE bank_review_lab_1020095404.sp_expect_ok(IN p_db VARCHAR(64), IN p_test VARCHAR(200), IN p_sql TEXT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_errno INT DEFAULT 0;
 DECLARE v_prepared BOOLEAN DEFAULT FALSE;
 DECLARE v_status VARCHAR(4);
 DECLARE v_detail VARCHAR(500);
 BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION, SQLWARNING BEGIN GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO; END;
  SET @lab_sql=REPLACE(p_sql,'{db}',REPLACE(p_db,'`','``'));
  PREPARE lab_stmt FROM @lab_sql;
  SET v_prepared=TRUE;
  EXECUTE lab_stmt;
 END;
 IF v_prepared THEN DEALLOCATE PREPARE lab_stmt; END IF;
 SET v_status=IF(v_errno=0,'PASS','FAIL');
 SET v_detail=CONCAT('actual errno=',v_errno);
 INSERT INTO bank_review_lab_1020095404.Test_Results(run_id,db_name,test_name,status,detail) VALUES(COALESCE(@test_run_id,'adhoc'),p_db,p_test,v_status,v_detail);
 SELECT CONCAT('TEST|',v_status,'|',p_test,'|',v_detail) AS result;
END$$
DROP PROCEDURE IF EXISTS bank_review_lab_1020095404.sp_assert_equal$$
CREATE PROCEDURE bank_review_lab_1020095404.sp_assert_equal(IN p_db VARCHAR(64), IN p_test VARCHAR(200), IN p_expected TEXT, IN p_actual TEXT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_status VARCHAR(4);
 DECLARE v_detail VARCHAR(500);
 SET v_status=IF(BINARY p_expected <=> BINARY p_actual,'PASS','FAIL');
 SET v_detail=LEFT(CONCAT('expected=',COALESCE(p_expected,'NULL'),'; actual=',COALESCE(p_actual,'NULL')),500);
 INSERT INTO bank_review_lab_1020095404.Test_Results(run_id,db_name,test_name,status,detail) VALUES(COALESCE(@test_run_id,'adhoc'),p_db,p_test,v_status,v_detail);
 SELECT CONCAT('TEST|',v_status,'|',p_test,'|',v_detail) AS result;
END$$
DROP PROCEDURE IF EXISTS bank_review_lab_1020095404.sp_assert_true$$
CREATE PROCEDURE bank_review_lab_1020095404.sp_assert_true(IN p_db VARCHAR(64), IN p_test VARCHAR(200), IN p_condition TINYINT, IN p_detail VARCHAR(500))
SQL SECURITY DEFINER
BEGIN
 DECLARE v_status VARCHAR(4);
 SET v_status=IF(COALESCE(p_condition,0)<>0,'PASS','FAIL');
 INSERT INTO bank_review_lab_1020095404.Test_Results(run_id,db_name,test_name,status,detail) VALUES(COALESCE(@test_run_id,'adhoc'),p_db,p_test,v_status,p_detail);
 SELECT CONCAT('TEST|',v_status,'|',p_test,'|',COALESCE(p_detail,'')) AS result;
END$$
DELIMITER ;
CREATE TABLE Branches (
 branch_id INT AUTO_INCREMENT, branch_name VARCHAR(100) NOT NULL,
 ifsc_code VARCHAR(15) NOT NULL, address VARCHAR(200) NOT NULL,
 city VARCHAR(50) NOT NULL, state VARCHAR(50) NOT NULL, phone VARCHAR(20) NOT NULL,
 CONSTRAINT pk_branches PRIMARY KEY (branch_id), CONSTRAINT uq_branches_ifsc UNIQUE (ifsc_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE Employees (
 employee_id INT AUTO_INCREMENT, branch_id INT NOT NULL, full_name VARCHAR(100) NOT NULL,
 role ENUM('Teller','Manager','DBA') NOT NULL, email VARCHAR(100) NOT NULL,
 hire_date DATE NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE,
 CONSTRAINT pk_employees PRIMARY KEY(employee_id), CONSTRAINT uq_employees_email UNIQUE(email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE Customers (
 customer_id INT AUTO_INCREMENT, full_name VARCHAR(100) NOT NULL, dob DATE NOT NULL,
 gender VARCHAR(15) NULL, email VARCHAR(100) NOT NULL, phone VARCHAR(20) NOT NULL,
 address VARCHAR(200) NOT NULL, id_proof_number VARCHAR(30) NOT NULL,
 id_proof_type ENUM('Aadhaar','PAN','Passport','DrivingLicense','VoterID') NOT NULL,
 kyc_status ENUM('Pending','Verified','Rejected') NOT NULL DEFAULT 'Pending',
 is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT pk_customers PRIMARY KEY(customer_id), CONSTRAINT uq_customers_email UNIQUE(email),
 CONSTRAINT uq_customers_phone UNIQUE(phone), CONSTRAINT uq_customers_id_proof UNIQUE(id_proof_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE Account_Types (
 account_type_id INT AUTO_INCREMENT, type_name VARCHAR(30) NOT NULL,
 interest_rate DECIMAL(5,2) NOT NULL, min_balance DECIMAL(12,2) NOT NULL,
 CONSTRAINT pk_account_types PRIMARY KEY(account_type_id), CONSTRAINT uq_account_types_name UNIQUE(type_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE Accounts (
 account_id INT AUTO_INCREMENT, customer_id INT NOT NULL, branch_id INT NOT NULL,
 account_type_id INT NOT NULL, account_number VARCHAR(20) NOT NULL, balance DECIMAL(14,2) NOT NULL,
 status ENUM('Active','Frozen','Closed') NOT NULL DEFAULT 'Active', opened_date DATE NOT NULL,
 CONSTRAINT pk_accounts PRIMARY KEY(account_id), CONSTRAINT uq_accounts_number UNIQUE(account_number),
 CONSTRAINT chk_accounts_balance CHECK(balance>=0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE Transactions (
 transaction_id BIGINT AUTO_INCREMENT, account_id INT NOT NULL, related_account_id INT NULL,
 employee_id INT NULL, transfer_group_id CHAR(36) NULL, device_id INT NULL, location_id INT NULL,
 transaction_type ENUM('Deposit','Withdrawal','TransferIn','TransferOut','InterestCredit','Fee') NOT NULL,
 amount DECIMAL(14,2) NOT NULL, balance_after DECIMAL(14,2) NOT NULL,
 channel ENUM('ATM','Branch','Online','Mobile') NOT NULL,
 status ENUM('Pending','Completed','Failed','RolledBack') NOT NULL,
 transaction_timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, reference_no VARCHAR(30) NOT NULL,
 CONSTRAINT pk_transactions PRIMARY KEY(transaction_id), CONSTRAINT uq_transactions_reference UNIQUE(reference_no),
 CONSTRAINT uq_transactions_group_type UNIQUE(transfer_group_id,transaction_type),
 CONSTRAINT chk_transactions_amount CHECK(amount>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE Loans (
 loan_id INT AUTO_INCREMENT, customer_id INT NOT NULL, disbursement_account_id INT NULL,
 principal_amount DECIMAL(14,2) NOT NULL, interest_rate DECIMAL(5,2) NOT NULL,
 tenure_months INT NOT NULL, status ENUM('Active','Closed','Defaulted') NOT NULL, disbursed_date DATE NOT NULL,
 CONSTRAINT pk_loans PRIMARY KEY(loan_id), CONSTRAINT chk_loans_principal CHECK(principal_amount>0),
 CONSTRAINT chk_loans_tenure CHECK(tenure_months>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE Fraud_Flags (
 flag_id INT AUTO_INCREMENT, transaction_id BIGINT NOT NULL, rule_id INT NOT NULL,
 risk_score DECIMAL(5,2) NOT NULL, evidence JSON NULL,
 flag_status ENUM('Open','UnderReview','Confirmed','Dismissed') NOT NULL DEFAULT 'Open',
 reviewed_by INT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT pk_fraud_flags PRIMARY KEY(flag_id), CONSTRAINT uq_fraud_flags_transaction_rule UNIQUE(transaction_id,rule_id),
 CONSTRAINT chk_fraud_flags_risk CHECK(risk_score BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE Audit_Log (
 audit_id BIGINT AUTO_INCREMENT, table_name VARCHAR(50) NOT NULL, record_pk VARCHAR(50) NOT NULL,
 action_type ENUM('INSERT','UPDATE','DELETE') NOT NULL, old_value JSON NULL, new_value JSON NULL,
 db_session_user VARCHAR(100) NOT NULL, actor_type ENUM('Customer','Employee','System') NOT NULL,
 actor_employee_id INT NULL, actor_customer_id INT NULL, performed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT pk_audit_log PRIMARY KEY(audit_id),
 CONSTRAINT chk_audit_log_actor CHECK(
 (actor_type='Employee' AND actor_employee_id IS NOT NULL AND actor_customer_id IS NULL) OR
 (actor_type='Customer' AND actor_customer_id IS NOT NULL AND actor_employee_id IS NULL) OR
 (actor_type='System' AND actor_employee_id IS NULL AND actor_customer_id IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE Devices (
    device_id INT AUTO_INCREMENT,
    customer_id INT NOT NULL,
    device_fingerprint CHAR(64) NOT NULL,
    device_type VARCHAR(20) NOT NULL,
    first_seen_at DATETIME NOT NULL,
    last_seen_at DATETIME NOT NULL,
    is_trusted BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_devices
        PRIMARY KEY (device_id),

    CONSTRAINT uq_devices_fingerprint
        UNIQUE (device_fingerprint),

    CONSTRAINT fk_devices_customer_id
        FOREIGN KEY (customer_id)
        REFERENCES Customers(customer_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT
);
CREATE TABLE Locations (
    location_id INT AUTO_INCREMENT,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50),
    country VARCHAR(50) NOT NULL,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,

    CONSTRAINT pk_locations
        PRIMARY KEY (location_id),

    CONSTRAINT chk_locations_latitude
        CHECK (latitude BETWEEN -90 AND 90),

    CONSTRAINT chk_locations_longitude
        CHECK (longitude BETWEEN -180 AND 180)
);
CREATE TABLE Fraud_Rules (
    rule_id INT AUTO_INCREMENT,
    rule_code VARCHAR(40) NOT NULL,
    description VARCHAR(200),
    weight DECIMAL(5,2) NOT NULL,
    param_json JSON,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_fraud_rules
        PRIMARY KEY (rule_id),

    CONSTRAINT uq_fraud_rules_code
        UNIQUE (rule_code),

    CONSTRAINT chk_fraud_rules_weight
        CHECK (weight BETWEEN 0 AND 100)
);
CREATE TABLE Account_Risk_Profile (
    account_id INT NOT NULL,
    risk_score DECIMAL(5,2) NOT NULL DEFAULT 0,
    risk_level ENUM('Low','Medium','High','Critical')
        NOT NULL DEFAULT 'Low',
    last_evaluated_at DATETIME NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_account_risk_profile
        PRIMARY KEY (account_id),

    CONSTRAINT chk_account_risk_score
        CHECK (risk_score BETWEEN 0 AND 100),

    CONSTRAINT fk_account_risk_profile_account
        FOREIGN KEY (account_id)
        REFERENCES Accounts(account_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT
);
CREATE TABLE DB_User_Map (
    db_login VARCHAR(100) NOT NULL,
    actor_type ENUM('Customer','Employee') NOT NULL,
    employee_id INT NULL,
    customer_id INT NULL,

    CONSTRAINT pk_db_user_map PRIMARY KEY (db_login),

    CONSTRAINT chk_db_user_map_actor CHECK (
        (actor_type = 'Employee'
            AND employee_id IS NOT NULL AND customer_id IS NULL)
        OR
        (actor_type = 'Customer'
            AND customer_id IS NOT NULL AND employee_id IS NULL)
    ),

    CONSTRAINT fk_db_user_map_employee
        FOREIGN KEY (employee_id)
        REFERENCES Employees(employee_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,

    CONSTRAINT fk_db_user_map_customer
        FOREIGN KEY (customer_id)
        REFERENCES Customers(customer_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
);
CREATE TABLE Transaction_Approvals (
    approval_id INT AUTO_INCREMENT,
    requested_by_actor_type ENUM('Customer','Employee') NOT NULL,
    requested_by_employee_id INT NULL,
    requested_by_customer_id INT NULL,
    requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    from_account_id INT NOT NULL,
    to_account_id INT NOT NULL,
    amount DECIMAL(14,2) NOT NULL,
    status ENUM('Requested','Approved','Rejected')
        NOT NULL DEFAULT 'Requested',
    decided_by INT NULL,
    decided_at DATETIME NULL,
    resulting_transfer_group_id CHAR(36) NULL,

    CONSTRAINT pk_transaction_approvals
        PRIMARY KEY (approval_id),

    CONSTRAINT chk_approval_amount CHECK (amount > 0),
    CONSTRAINT chk_approval_different_accounts
        CHECK (from_account_id <> to_account_id),

    CONSTRAINT chk_approval_requester CHECK (
        (requested_by_actor_type = 'Customer'
            AND requested_by_customer_id IS NOT NULL
            AND requested_by_employee_id IS NULL)
        OR
        (requested_by_actor_type = 'Employee'
            AND requested_by_employee_id IS NOT NULL
            AND requested_by_customer_id IS NULL)
    ),

    CONSTRAINT fk_approvals_from_account
        FOREIGN KEY (from_account_id)
        REFERENCES Accounts(account_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,

    CONSTRAINT fk_approvals_to_account
        FOREIGN KEY (to_account_id)
        REFERENCES Accounts(account_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,

    CONSTRAINT fk_approvals_requester_employee
        FOREIGN KEY (requested_by_employee_id)
        REFERENCES Employees(employee_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,

    CONSTRAINT fk_approvals_requester_customer
        FOREIGN KEY (requested_by_customer_id)
        REFERENCES Customers(customer_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,

    CONSTRAINT fk_approvals_decided_by
        FOREIGN KEY (decided_by)
        REFERENCES Employees(employee_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
);
CREATE TABLE Fraud_Ground_Truth (
    transaction_id BIGINT NOT NULL,
    is_fraud BOOLEAN NOT NULL,
    scenario_label VARCHAR(40),

    CONSTRAINT pk_fraud_ground_truth
        PRIMARY KEY (transaction_id),

    CONSTRAINT fk_fraud_ground_truth_transaction
        FOREIGN KEY (transaction_id)
        REFERENCES Transactions(transaction_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE Employees ADD CONSTRAINT fk_employees_branch_id FOREIGN KEY (branch_id) REFERENCES Branches(branch_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE Accounts ADD CONSTRAINT fk_accounts_customer_id FOREIGN KEY (customer_id) REFERENCES Customers(customer_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE Accounts ADD CONSTRAINT fk_accounts_branch_id FOREIGN KEY (branch_id) REFERENCES Branches(branch_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE Accounts ADD CONSTRAINT fk_accounts_account_type_id FOREIGN KEY (account_type_id) REFERENCES Account_Types(account_type_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE Transactions ADD CONSTRAINT fk_transactions_account_id FOREIGN KEY (account_id) REFERENCES Accounts(account_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE Transactions ADD CONSTRAINT fk_transactions_related_account_id FOREIGN KEY (related_account_id) REFERENCES Accounts(account_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE Transactions ADD CONSTRAINT fk_transactions_employee_id FOREIGN KEY (employee_id) REFERENCES Employees(employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE Loans ADD CONSTRAINT fk_loans_customer_id FOREIGN KEY (customer_id) REFERENCES Customers(customer_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE Loans ADD CONSTRAINT fk_loans_disbursement_account_id FOREIGN KEY (disbursement_account_id) REFERENCES Accounts(account_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE Fraud_Flags ADD CONSTRAINT fk_fraud_flags_transaction_id FOREIGN KEY (transaction_id) REFERENCES Transactions(transaction_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE Fraud_Flags ADD CONSTRAINT fk_fraud_flags_reviewed_by FOREIGN KEY (reviewed_by) REFERENCES Employees(employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE Audit_Log ADD CONSTRAINT fk_audit_log_actor_employee_id FOREIGN KEY (actor_employee_id) REFERENCES Employees(employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE Audit_Log ADD CONSTRAINT fk_audit_log_actor_customer_id FOREIGN KEY (actor_customer_id) REFERENCES Customers(customer_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
SET @cross_sql = IF(
 EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='Devices')
 AND NOT EXISTS(SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema=DATABASE() AND table_name='Transactions' AND constraint_name='fk_transactions_device'),
 'ALTER TABLE Transactions ADD CONSTRAINT fk_transactions_device FOREIGN KEY (device_id) REFERENCES Devices(device_id) ON DELETE RESTRICT ON UPDATE RESTRICT', 'DO 0');
PREPARE cross_stmt FROM @cross_sql;
EXECUTE cross_stmt;
DEALLOCATE PREPARE cross_stmt;
SET @cross_sql = IF(
 EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='Locations')
 AND NOT EXISTS(SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema=DATABASE() AND table_name='Transactions' AND constraint_name='fk_transactions_location'),
 'ALTER TABLE Transactions ADD CONSTRAINT fk_transactions_location FOREIGN KEY (location_id) REFERENCES Locations(location_id) ON DELETE RESTRICT ON UPDATE RESTRICT', 'DO 0');
PREPARE cross_stmt FROM @cross_sql;
EXECUTE cross_stmt;
DEALLOCATE PREPARE cross_stmt;
SET @cross_sql = IF(
 EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='Fraud_Rules')
 AND NOT EXISTS(SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema=DATABASE() AND table_name='Fraud_Flags' AND constraint_name='fk_fraud_flags_rule'),
 'ALTER TABLE Fraud_Flags ADD CONSTRAINT fk_fraud_flags_rule FOREIGN KEY (rule_id) REFERENCES Fraud_Rules(rule_id) ON DELETE RESTRICT ON UPDATE RESTRICT', 'DO 0');
PREPARE cross_stmt FROM @cross_sql;
EXECUTE cross_stmt;
DEALLOCATE PREPARE cross_stmt;
-- Query-pattern indexes. Validate with EXPLAIN and workload benchmarks before production rollout.
CREATE INDEX idx_transactions_account_time
  ON Transactions(account_id, transaction_timestamp, transaction_id);
CREATE INDEX idx_transactions_status_time
  ON Transactions(status, transaction_timestamp);
CREATE INDEX idx_fraud_flags_status_score
  ON Fraud_Flags(flag_status, risk_score, created_at);
CREATE INDEX idx_fraud_flags_rule_created
  ON Fraud_Flags(rule_id, created_at);
CREATE INDEX idx_approvals_status_requested
  ON Transaction_Approvals(status, requested_at);
CREATE INDEX idx_audit_log_table_time
  ON Audit_Log(table_name, performed_at);
CREATE INDEX idx_devices_customer_trusted
  ON Devices(customer_id, is_trusted);
-- SOURCE schema/04_lab/02_benchmark_results.sql; -- Optional B-owned file when supplied.
DELIMITER $$
CREATE FUNCTION fn_approval_threshold() RETURNS DECIMAL(14,2)
DETERMINISTIC NO SQL SQL SECURITY DEFINER
BEGIN
 RETURN 100000.00;
END$$
DELIMITER ;
DELIMITER $$
CREATE FUNCTION fn_available_balance(p_account_id INT) RETURNS DECIMAL(14,2)
NOT DETERMINISTIC READS SQL DATA SQL SECURITY DEFINER
BEGIN
 RETURN COALESCE((SELECT GREATEST(a.balance-t.min_balance,0) FROM Accounts a
 JOIN Account_Types t USING(account_type_id) WHERE a.account_id=p_account_id AND a.status='Active'),0.00);
END$$
DELIMITER ;
DELIMITER $$
CREATE FUNCTION fn_calc_interest(p_account_id INT) RETURNS DECIMAL(14,2)
NOT DETERMINISTIC READS SQL DATA SQL SECURITY DEFINER
BEGIN
 RETURN COALESCE((SELECT ROUND(a.balance*t.interest_rate/100/12,2) FROM Accounts a
 JOIN Account_Types t USING(account_type_id) WHERE a.account_id=p_account_id AND a.status='Active'),0.00);
END$$
DELIMITER ;
DELIMITER $$
CREATE FUNCTION fn_generate_reference() RETURNS VARCHAR(30)
NOT DETERMINISTIC READS SQL DATA SQL SECURITY DEFINER
BEGIN
 -- 28 characters. UUID_SHORT supplies a server-wide advancing suffix; no table writes.
 RETURN CONCAT('T',DATE_FORMAT(NOW(6),'%Y%m%d%H%i%s%f'),'-',
 LPAD(CONV(MOD(UUID_SHORT(),2176782336),10,36),6,'0'));
END$$
DELIMITER ;
-- Deterministic base scoring helper; procedure adds active rule weights and caps at 100.
DELIMITER $$
CREATE FUNCTION fn_fraud_score(p_amount DECIMAL(14,2), p_channel VARCHAR(10),
                               p_device_trusted BOOLEAN, p_account_risk DECIMAL(5,2))
RETURNS DECIMAL(5,2)
DETERMINISTIC
NO SQL
BEGIN
  DECLARE v_score DECIMAL(5,2) DEFAULT 0;
  IF p_amount >= 10000 THEN SET v_score = v_score + 35; END IF;
  IF p_amount >= 5000 AND p_amount < 10000 THEN SET v_score = v_score + 20; END IF;
  IF p_channel IN ('Online','Mobile') THEN SET v_score = v_score + 10; END IF;
  IF p_device_trusted = FALSE OR p_device_trusted IS NULL THEN SET v_score = v_score + 20; END IF;
  SET v_score = v_score + LEAST(35, GREATEST(0, COALESCE(p_account_risk,0) * 0.35));
  RETURN LEAST(100,GREATEST(0,v_score));
END$$
DELIMITER ;
DELIMITER $$
CREATE FUNCTION fn_get_balance(p_account_id INT) RETURNS DECIMAL(14,2)
NOT DETERMINISTIC READS SQL DATA SQL SECURITY DEFINER
BEGIN
 RETURN (SELECT balance FROM Accounts WHERE account_id=p_account_id);
END$$
DELIMITER ;
DELIMITER $$
CREATE FUNCTION fn_mask_id_proof(p_id_proof VARCHAR(30)) RETURNS VARCHAR(30)
DETERMINISTIC NO SQL SQL SECURITY DEFINER
BEGIN
 IF p_id_proof IS NULL THEN RETURN NULL; END IF;
 RETURN CONCAT(REPEAT('X',GREATEST(CHAR_LENGTH(p_id_proof)-4,0)),RIGHT(p_id_proof,4));
END$$
DELIMITER ;
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
DELIMITER $$
CREATE PROCEDURE sp_internal_assert_staff(IN p_employee_id INT, IN p_account_id INT, IN p_roles VARCHAR(40))
SQL SECURITY DEFINER
BEGIN
 DECLARE v_actor VARCHAR(10); DECLARE v_e INT; DECLARE v_c INT;
 CALL sp_resolve_actor(USER(),v_actor,v_e,v_c);
 IF v_actor='Customer' OR (v_actor='Employee' AND NOT (p_employee_id <=> v_e)) OR p_employee_id IS NULL OR NOT EXISTS(SELECT 1 FROM Employees e WHERE e.employee_id=p_employee_id AND e.is_active AND FIND_IN_SET(e.role,p_roles)>0 AND (p_account_id IS NULL OR e.branch_id=(SELECT branch_id FROM Accounts WHERE account_id=p_account_id))) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: active authorized staff required'; END IF;
END$$
DELIMITER ;
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
DELIMITER $$
CREATE PROCEDURE sp_internal_insert_ledger(IN p_account_id INT, IN p_related INT, IN p_employee INT, IN p_group CHAR(36), IN p_device INT, IN p_location INT, IN p_type VARCHAR(20), IN p_amount DECIMAL(14,2), IN p_balance DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_status VARCHAR(12), IN p_timestamp DATETIME, OUT p_transaction_id BIGINT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_attempt INT DEFAULT 0; DECLARE v_duplicate BOOLEAN;
 SET p_transaction_id=NULL;
 reference_retry: LOOP
  SET v_attempt=v_attempt+1,v_duplicate=FALSE;
  BEGIN
   DECLARE CONTINUE HANDLER FOR 1062 SET v_duplicate=TRUE;
   INSERT INTO Transactions(account_id,related_account_id,employee_id,transfer_group_id,device_id,location_id,transaction_type,amount,balance_after,channel,status,transaction_timestamp,reference_no)
   VALUES(p_account_id,p_related,p_employee,p_group,p_device,p_location,p_type,p_amount,p_balance,p_channel,p_status,COALESCE(p_timestamp,NOW()),fn_generate_reference());
  END;
  IF NOT v_duplicate THEN SET p_transaction_id=LAST_INSERT_ID(); LEAVE reference_retry; END IF;
  IF v_attempt>=5 THEN SIGNAL SQLSTATE '23000' SET MYSQL_ERRNO=1062,MESSAGE_TEXT='E_INVALID_REFERENCE: reference collision retry exhausted'; END IF;
 END LOOP;
END$$
DELIMITER ;
DELIMITER $$
CREATE PROCEDURE sp_internal_post_single(IN p_account_id INT, IN p_amount DECIMAL(14,2), IN p_type VARCHAR(20), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, OUT p_transaction_id BIGINT, OUT p_balance_after DECIMAL(14,2))
SQL SECURITY DEFINER
BEGIN
 DECLARE v_balance DECIMAL(14,2); DECLARE v_min DECIMAL(12,2); DECLARE v_status VARCHAR(10);
 IF p_amount IS NULL OR p_amount<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: amount must be positive'; END IF;
 IF p_account_id IS NULL OR NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_account_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: account does not exist'; END IF;
 SELECT a.balance,a.status,t.min_balance INTO v_balance,v_status,v_min FROM Accounts a JOIN Account_Types t USING(account_type_id) WHERE a.account_id=p_account_id FOR UPDATE OF a;
 IF v_status<>'Active' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5003,MESSAGE_TEXT='E_ACCOUNT_NOT_ACTIVE: active account required'; END IF;
 CALL sp_internal_authorize(p_account_id,p_channel,p_employee_id,p_type='Withdrawal',0);
 IF p_type='Withdrawal' AND v_balance-p_amount<v_min THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5004,MESSAGE_TEXT='E_INSUFFICIENT_FUNDS: minimum balance would be breached'; END IF;
 IF p_type='Deposit' THEN UPDATE Accounts SET balance=balance+p_amount WHERE account_id=p_account_id; SET p_balance_after=v_balance+p_amount;
 ELSEIF p_type='Withdrawal' THEN UPDATE Accounts SET balance=balance-p_amount WHERE account_id=p_account_id; SET p_balance_after=v_balance-p_amount;
 ELSE SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: unsupported single-leg posting'; END IF;
 CALL sp_internal_insert_ledger(p_account_id,NULL,p_employee_id,NULL,p_device_id,p_location_id,p_type,p_amount,p_balance_after,p_channel,'Completed',NULL,p_transaction_id);
END$$
DELIMITER ;
DELIMITER $$
CREATE PROCEDURE sp_internal_post_transfer(IN p_from_account_id INT, IN p_to_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, IN p_lab_mode TINYINT, IN p_allow_approval TINYINT, OUT p_transfer_group_id CHAR(36), OUT p_debit_txn_id BIGINT, OUT p_credit_txn_id BIGINT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_first INT; DECLARE v_second INT; DECLARE v_lock INT; DECLARE v_fb DECIMAL(14,2); DECLARE v_tb DECIMAL(14,2); DECLARE v_min DECIMAL(12,2); DECLARE v_fs VARCHAR(10); DECLARE v_ts VARCHAR(10); DECLARE v_sleep INT;
 IF p_amount IS NULL OR p_amount<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: amount must be positive'; END IF;
 IF p_lab_mode IS NULL OR p_lab_mode NOT IN (0,1,2,3) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid lab mode'; END IF;
 -- RELEASE_GUARD_PLACEHOLDER
 IF p_from_account_id IS NULL OR p_to_account_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: transfer account does not exist'; END IF;
 -- LAB_NAIVE_BEGIN
 IF p_lab_mode=3 THEN
  SET v_first=p_from_account_id,v_second=p_to_account_id;
 ELSE
 -- LAB_NAIVE_END
  SET v_first=LEAST(p_from_account_id,p_to_account_id),v_second=GREATEST(p_from_account_id,p_to_account_id);
 -- LAB_NAIVE_BEGIN
 END IF;
 -- LAB_NAIVE_END
 -- The locking reads also validate existence: no shared lookup locks may precede
 -- the canonical exclusive-lock order. The local handler cannot mask later reads.
 BEGIN
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_lock=NULL;
  SET v_lock=NULL;
  SELECT account_id INTO v_lock FROM Accounts WHERE account_id=v_first FOR UPDATE;
  IF v_lock IS NULL THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: transfer account does not exist'; END IF;
  SET v_lock=NULL;
  SELECT account_id INTO v_lock FROM Accounts WHERE account_id=v_second FOR UPDATE;
  IF v_lock IS NULL THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: transfer account does not exist'; END IF;
 END;
 IF p_from_account_id=p_to_account_id THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5005,MESSAGE_TEXT='E_SAME_ACCOUNT: accounts must differ'; END IF;
 IF p_allow_approval=0 AND p_amount>=fn_approval_threshold() THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5006,MESSAGE_TEXT='E_APPROVAL_REQUIRED: approval threshold reached'; END IF;
 SELECT a.balance,a.status,t.min_balance INTO v_fb,v_fs,v_min FROM Accounts a JOIN Account_Types t USING(account_type_id) WHERE a.account_id=p_from_account_id;
 SELECT balance,status INTO v_tb,v_ts FROM Accounts WHERE account_id=p_to_account_id;
 IF v_fs<>'Active' OR v_ts<>'Active' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5003,MESSAGE_TEXT='E_ACCOUNT_NOT_ACTIVE: both accounts must be active'; END IF;
 CALL sp_internal_authorize(p_from_account_id,p_channel,p_employee_id,1,p_allow_approval);
 IF v_fb-p_amount<v_min THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5004,MESSAGE_TEXT='E_INSUFFICIENT_FUNDS: transfer would breach minimum balance'; END IF;
 SET p_transfer_group_id=UUID();
 UPDATE Accounts SET balance=balance-p_amount WHERE account_id=p_from_account_id;
 CALL sp_internal_insert_ledger(p_from_account_id,p_to_account_id,p_employee_id,p_transfer_group_id,p_device_id,p_location_id,'TransferOut',p_amount,v_fb-p_amount,p_channel,'Completed',NULL,p_debit_txn_id);
 -- LAB_HOOK_BEGIN
 IF p_lab_mode=1 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5016,MESSAGE_TEXT='E_LAB_INJECTED_FAILURE: failure after debit'; END IF;
 IF p_lab_mode IN (2,3) THEN SELECT SLEEP(IFNULL(@lab_sleep_seconds,5)) INTO v_sleep; END IF;
 -- LAB_HOOK_END
 UPDATE Accounts SET balance=balance+p_amount WHERE account_id=p_to_account_id;
 CALL sp_internal_insert_ledger(p_to_account_id,p_from_account_id,p_employee_id,p_transfer_group_id,NULL,NULL,'TransferIn',p_amount,v_tb+p_amount,p_channel,'Completed',NULL,p_credit_txn_id);
END$$
DELIMITER ;
DELIMITER $$
CREATE PROCEDURE sp_internal_record_failed(IN p_account_id INT, IN p_amount DECIMAL(14,2), IN p_type VARCHAR(20), IN p_channel VARCHAR(10))
SQL SECURITY DEFINER
BEGIN
 DECLARE v_balance DECIMAL(14,2); DECLARE v_tx BIGINT;
 -- No transaction control: the public handler owns this separate small transaction.
 IF p_amount IS NOT NULL AND p_amount>0 AND EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_account_id) THEN
  SELECT balance INTO v_balance FROM Accounts WHERE account_id=p_account_id FOR UPDATE;
  CALL sp_internal_insert_ledger(p_account_id,NULL,NULL,NULL,NULL,NULL,p_type,p_amount,v_balance,IF(p_channel IN ('ATM','Branch','Online','Mobile'),p_channel,'Online'),'Failed',NULL,v_tx);
 END IF;
END$$
DELIMITER ;
DELIMITER $$
CREATE PROCEDURE sp_close_account(IN p_account_id INT, IN p_employee_id INT, IN p_settle_balance TINYINT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_bal DECIMAL(14,2); DECLARE v_status VARCHAR(10); DECLARE v_tx BIGINT;
 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK;
  
  IF v_errno IN (5003,5004,5005,5006,5010) THEN
   BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
    START TRANSACTION;
    CALL sp_internal_record_failed(p_account_id,v_bal,'Withdrawal',IF(p_employee_id IS NULL,'Online','Branch'));
    COMMIT;
   END;
  END IF;
  RESIGNAL;
 END;
 IF p_settle_balance IS NULL OR p_settle_balance NOT IN (0,1) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid settlement flag'; END IF;
 START TRANSACTION;
 IF p_account_id IS NULL OR NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_account_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: account does not exist'; END IF;
 SELECT balance,status INTO v_bal,v_status FROM Accounts WHERE account_id=p_account_id FOR UPDATE;
 IF v_status='Closed' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5011,MESSAGE_TEXT='E_INVALID_TRANSITION: account already closed'; END IF;
 CALL sp_internal_authorize(p_account_id,IF(p_employee_id IS NULL,'Online','Branch'),p_employee_id,1,0);
 IF EXISTS(SELECT 1 FROM Loans WHERE disbursement_account_id=p_account_id AND status='Active') OR (p_settle_balance=0 AND v_bal<>0) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5008,MESSAGE_TEXT='E_CLOSE_BLOCKED: balance or active loan blocks closure'; END IF;
 IF v_bal>0 THEN CALL sp_internal_insert_ledger(p_account_id,NULL,p_employee_id,NULL,NULL,NULL,'Withdrawal',v_bal,0,IF(p_employee_id IS NULL,'Online','Branch'),'Completed',NULL,v_tx); END IF;
 UPDATE Accounts SET balance=0,status='Closed' WHERE account_id=p_account_id;
 COMMIT;
END$$
DELIMITER ;
DELIMITER $$
CREATE PROCEDURE sp_decide_approval(IN p_approval_id INT, IN p_decision VARCHAR(10), IN p_manager_employee_id INT, OUT p_transfer_group_id CHAR(36)) SQL SECURITY DEFINER
BEGIN
 DECLARE v_from INT; DECLARE v_to INT; DECLARE v_amount DECIMAL(14,2); DECLARE v_requester INT; DECLARE v_status VARCHAR(12); DECLARE v_debit BIGINT; DECLARE v_credit BIGINT;
 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK; SET p_transfer_group_id=NULL;
  IF v_errno IN (5003,5004,5005,5006,5010) THEN BEGIN
   DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
   START TRANSACTION; CALL sp_internal_record_failed(v_from,v_amount,'TransferOut','Branch'); COMMIT;
  END; END IF;
  RESIGNAL;
 END;
 SET p_transfer_group_id=NULL;
 IF p_decision IS NULL OR p_decision NOT IN ('Approved','Rejected') THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid approval decision'; END IF;
 START TRANSACTION;
 IF p_approval_id IS NULL OR NOT EXISTS(SELECT 1 FROM Transaction_Approvals WHERE approval_id=p_approval_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5007,MESSAGE_TEXT='E_INVALID_REFERENCE: approval does not exist'; END IF;
 SELECT from_account_id,to_account_id,amount,requested_by_employee_id,status INTO v_from,v_to,v_amount,v_requester,v_status FROM Transaction_Approvals WHERE approval_id=p_approval_id FOR UPDATE;
 IF v_status<>'Requested' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5009,MESSAGE_TEXT='E_APPROVAL_STATE: request is already decided'; END IF;
 CALL sp_internal_assert_staff(p_manager_employee_id,v_from,'Manager');
 IF v_requester=p_manager_employee_id THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: requester cannot decide own request'; END IF;
 IF p_decision='Approved' THEN
  CALL sp_internal_post_transfer(v_from,v_to,v_amount,'Branch',p_manager_employee_id,NULL,NULL,0,1,p_transfer_group_id,v_debit,v_credit);
 END IF;
 UPDATE Transaction_Approvals SET status=p_decision,decided_by=p_manager_employee_id,decided_at=NOW(),resulting_transfer_group_id=p_transfer_group_id WHERE approval_id=p_approval_id;
 COMMIT;
END$$
DELIMITER ;
DELIMITER $$
CREATE PROCEDURE sp_deposit(IN p_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, OUT p_transaction_id BIGINT, OUT p_balance_after DECIMAL(14,2))
SQL SECURITY DEFINER
BEGIN

 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK;
  SET p_transaction_id=NULL,p_balance_after=NULL;
  IF v_errno IN (5003,5004,5005,5006,5010) THEN
   BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
    START TRANSACTION;
    CALL sp_internal_record_failed(p_account_id,p_amount,'Deposit',p_channel);
    COMMIT;
   END;
  END IF;
  RESIGNAL;
 END;
 SET p_transaction_id=NULL,p_balance_after=NULL;
 IF p_amount IS NULL OR p_amount<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: amount must be positive'; END IF;
 START TRANSACTION;
 CALL sp_internal_post_single(p_account_id,p_amount,'Deposit',p_channel,p_employee_id,p_device_id,p_location_id,p_transaction_id,p_balance_after);
 COMMIT;
END$$
DELIMITER ;
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
DELIMITER $$
CREATE PROCEDURE sp_generate_statement(IN p_account_id INT, IN p_from DATE, IN p_to DATE)
READS SQL DATA SQL SECURITY DEFINER
BEGIN
 DECLARE v_open DECIMAL(14,2) DEFAULT 0;
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR DATEDIFF(p_to,p_from)+1>366 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid statement date range'; END IF;
 IF p_account_id IS NULL OR NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_account_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: account does not exist'; END IF;
 SET v_open=COALESCE((SELECT balance_after FROM Transactions WHERE account_id=p_account_id AND status='Completed' AND transaction_timestamp<p_from ORDER BY transaction_id DESC LIMIT 1),0);
 SELECT p_account_id AS account_id,p_from AS period_start,v_open AS opening_balance;
 SELECT transaction_id,transaction_timestamp AS timestamp,transaction_type AS type,amount,balance_after,related_account_id,reference_no,
 v_open+SUM(CASE WHEN transaction_type IN ('Deposit','TransferIn','InterestCredit') THEN amount ELSE -amount END) OVER(ORDER BY transaction_id ROWS UNBOUNDED PRECEDING) AS running_balance
 FROM Transactions WHERE account_id=p_account_id AND status='Completed' AND transaction_timestamp>=p_from AND transaction_timestamp<DATE_ADD(p_to,INTERVAL 1 DAY) ORDER BY transaction_id;
END$$
DELIMITER ;
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
DELIMITER $$
CREATE PROCEDURE sp_post_monthly_interest(IN p_period_start DATE, IN p_employee_id INT, OUT p_accounts_credited INT, OUT p_total_interest DECIMAL(16,2))
SQL SECURITY DEFINER
BEGIN
 DECLARE v_done BOOLEAN DEFAULT FALSE;
 DECLARE v_account INT;
 DECLARE v_month DATE;
 DECLARE v_actor VARCHAR(10); DECLARE v_e INT; DECLARE v_c INT;
 DECLARE accounts_cursor CURSOR FOR SELECT a.account_id FROM Accounts a JOIN Account_Types t USING(account_type_id) WHERE a.status='Active' AND t.type_name='Savings' ORDER BY a.account_id;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done=TRUE;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 SET p_accounts_credited=0,p_total_interest=0,@interest_errors=0;
 IF p_period_start IS NULL THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: interest period is required'; END IF;
 SET v_month=CAST(DATE_FORMAT(p_period_start,'%Y-%m-01') AS DATE);
 CALL sp_resolve_actor(USER(),v_actor,v_e,v_c);
 IF v_actor='Customer' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: interest posting requires staff or system'; END IF;
 IF p_employee_id IS NOT NULL THEN CALL sp_internal_assert_staff(p_employee_id,NULL,'Manager,DBA'); END IF;
 IF v_actor='Employee' AND NOT EXISTS(SELECT 1 FROM Employees WHERE employee_id=v_e AND is_active AND role IN ('Manager','DBA')) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: manager or DBA required'; END IF;
 OPEN accounts_cursor;
 interest_loop: LOOP
  FETCH accounts_cursor INTO v_account;
  IF v_done THEN LEAVE interest_loop; END IF;
  account_work: BEGIN
   DECLARE v_missing BOOLEAN DEFAULT FALSE;
   DECLARE v_balance DECIMAL(14,2); DECLARE v_interest DECIMAL(14,2); DECLARE v_rate DECIMAL(5,2);
   DECLARE v_status VARCHAR(10); DECLARE v_type VARCHAR(30); DECLARE v_tx BIGINT; DECLARE v_reference VARCHAR(30);
   DECLARE v_errno INT;
   DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_missing=TRUE;
   DECLARE EXIT HANDLER FOR SQLEXCEPTION
   BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
    ROLLBACK;
    IF v_errno IN (5003,5004,5005,5006,5010) THEN
     BEGIN
      DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
      START TRANSACTION;
      CALL sp_internal_record_failed(v_account,v_interest,'InterestCredit','Branch');
      COMMIT;
     END;
    END IF;
    SET @interest_errors=@interest_errors+1;
   END;
   START TRANSACTION;
   SELECT a.balance,a.status,t.type_name,t.interest_rate INTO v_balance,v_status,v_type,v_rate FROM Accounts a JOIN Account_Types t USING(account_type_id) WHERE a.account_id=v_account FOR UPDATE OF a;
   IF v_missing OR v_status<>'Active' OR v_type<>'Savings' THEN COMMIT; LEAVE account_work; END IF;
   -- New postings keep their actual timestamp. A reference-linked period marker
   -- identifies historical/future requested months without corrupting statements.
   -- Unmarked (legacy) credits retain the timestamp-month convention.
   IF EXISTS(SELECT 1 FROM Transactions t WHERE t.account_id=v_account AND t.transaction_type='InterestCredit' AND t.status='Completed' AND (
    EXISTS(SELECT 1 FROM bank_review_lab_1020095404.Experiment_Log l WHERE l.db_name=DATABASE() AND l.event_type='MONTHLY_INTEREST_POSTED' AND JSON_UNQUOTE(JSON_EXTRACT(l.detail,'$.reference_no'))=t.reference_no AND JSON_UNQUOTE(JSON_EXTRACT(l.detail,'$.period_start'))=CAST(v_month AS CHAR))
    OR (t.transaction_timestamp>=v_month AND t.transaction_timestamp<DATE_ADD(v_month,INTERVAL 1 MONTH) AND NOT EXISTS(SELECT 1 FROM bank_review_lab_1020095404.Experiment_Log l WHERE l.db_name=DATABASE() AND l.event_type='MONTHLY_INTEREST_POSTED' AND JSON_UNQUOTE(JSON_EXTRACT(l.detail,'$.reference_no'))=t.reference_no))
   )) THEN COMMIT; LEAVE account_work; END IF;
   SET v_interest=ROUND(v_balance*v_rate/100/12,2);
   IF v_interest<=0 THEN COMMIT; LEAVE account_work; END IF;
   UPDATE Accounts SET balance=balance+v_interest WHERE account_id=v_account;
   CALL sp_internal_insert_ledger(v_account,NULL,p_employee_id,NULL,NULL,NULL,'InterestCredit',v_interest,v_balance+v_interest,'Branch','Completed',NULL,v_tx);
   SELECT reference_no INTO v_reference FROM Transactions WHERE transaction_id=v_tx;
   INSERT INTO bank_review_lab_1020095404.Experiment_Log(db_name,exp_id,event_type,detail) VALUES(DATABASE(),'INTEREST','MONTHLY_INTEREST_POSTED',JSON_OBJECT('account_id',v_account,'period_start',CAST(v_month AS CHAR),'reference_no',v_reference,'transaction_id',v_tx));
   COMMIT;
   SET p_accounts_credited=p_accounts_credited+1,p_total_interest=p_total_interest+v_interest;
  END;
 END LOOP;
 CLOSE accounts_cursor;
END$$
DELIMITER ;
DELIMITER $$
CREATE PROCEDURE sp_reconcile_balances(IN p_account_id INT)
READS SQL DATA SQL SECURITY DEFINER
BEGIN
 DECLARE v_checked DATETIME(3);
 IF p_account_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_account_id) THEN
 SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: account does not exist'; END IF;
 SET v_checked=NOW(3);
 WITH
 ledger AS (SELECT account_id,transaction_id,transaction_type,amount,balance_after,
 CASE WHEN transaction_type IN ('Deposit','TransferIn','InterestCredit') THEN amount ELSE -amount END AS signed_amount
 FROM Transactions WHERE status='Completed'),
 totals AS (SELECT account_id,SUM(signed_amount) AS net,MAX(transaction_id) AS last_id FROM ledger GROUP BY account_id),
 chain AS (SELECT *,LAG(balance_after,1,0) OVER(PARTITION BY account_id ORDER BY transaction_id) AS prior_balance FROM ledger),
 wm AS (SELECT COALESCE((SELECT detail FROM bank_review_lab_1020095404.Experiment_Log WHERE db_name=DATABASE() AND event_type='AUDIT_TRIGGERS_INSTALLED' ORDER BY log_id DESC LIMIT 1),JSON_OBJECT()) AS j),
 latest_audit AS (SELECT record_pk,new_value,ROW_NUMBER() OVER(PARTITION BY record_pk ORDER BY audit_id DESC) AS rn FROM Audit_Log,wm WHERE table_name='Accounts' AND action_type='UPDATE' AND audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0)),
 problems AS (
 SELECT 'I1' AS invariant,a.account_id,CAST(a.account_id AS CHAR(64)) AS record_pk,'balance differs from completed ledger' AS detail
 FROM Accounts a LEFT JOIN totals t USING(account_id) WHERE (p_account_id IS NULL OR a.account_id=p_account_id) AND a.balance<>COALESCE(t.net,0)
 UNION ALL
 SELECT 'I1',NULL,'TOTAL','aggregate balance differs from completed ledger' FROM Accounts a LEFT JOIN totals t USING(account_id) WHERE p_account_id IS NULL OR a.account_id=p_account_id HAVING COALESCE(SUM(a.balance),0)<>COALESCE(SUM(t.net),0)
 UNION ALL
 SELECT 'I1b',account_id,CAST(transaction_id AS CHAR(64)),'balance_after chain break' FROM chain WHERE (p_account_id IS NULL OR account_id=p_account_id) AND balance_after<>prior_balance+signed_amount
 UNION ALL
 SELECT 'I2',MIN(account_id),transfer_group_id,'invalid paired transfer' FROM Transactions WHERE transfer_group_id IS NOT NULL GROUP BY transfer_group_id
 HAVING NOT (COUNT(*)=2 AND SUM(status='Completed')=2 AND SUM(transaction_type='TransferOut')=1 AND SUM(transaction_type='TransferIn')=1 AND MIN(amount)=MAX(amount)
 AND (MAX(CASE WHEN transaction_type='TransferOut' THEN account_id END) <=> MAX(CASE WHEN transaction_type='TransferIn' THEN related_account_id END))
 AND (MAX(CASE WHEN transaction_type='TransferIn' THEN account_id END) <=> MAX(CASE WHEN transaction_type='TransferOut' THEN related_account_id END)))
 UNION ALL
 SELECT 'I3',a.account_id,CAST(a.account_id AS CHAR(64)),'minimum or nonnegative balance violated' FROM Accounts a JOIN Account_Types t USING(account_type_id) WHERE (p_account_id IS NULL OR a.account_id=p_account_id) AND (a.balance<0 OR (a.status<>'Closed' AND a.balance<t.min_balance))
 UNION ALL
 SELECT 'I5',a.account_id,CAST(a.account_id AS CHAR(64)),'latest completed balance_after differs' FROM Accounts a JOIN totals t USING(account_id) JOIN ledger l ON l.transaction_id=t.last_id WHERE (p_account_id IS NULL OR a.account_id=p_account_id) AND a.balance<>l.balance_after
 UNION ALL
 SELECT 'I4',a.account_id,CAST(a.account_id AS CHAR(64)),'missing Accounts INSERT audit' FROM Accounts a CROSS JOIN wm WHERE a.account_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.accounts_max_id')) AS UNSIGNED),0)
 AND NOT EXISTS(SELECT 1 FROM Audit_Log x WHERE x.table_name='Accounts' AND x.record_pk=CAST(a.account_id AS CHAR) AND x.action_type='INSERT' AND x.audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0))
 UNION ALL
 SELECT 'I4',t.account_id,CAST(t.transaction_id AS CHAR(64)),'missing Transactions INSERT audit' FROM Transactions t CROSS JOIN wm WHERE t.transaction_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.transactions_max_id')) AS UNSIGNED),0)
 AND NOT EXISTS(SELECT 1 FROM Audit_Log x WHERE x.table_name='Transactions' AND x.record_pk=CAST(t.transaction_id AS CHAR) AND x.action_type='INSERT' AND x.audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0))
 UNION ALL
 SELECT 'I4',l.disbursement_account_id,CAST(l.loan_id AS CHAR(64)),'missing Loans INSERT audit' FROM Loans l CROSS JOIN wm WHERE l.loan_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.loans_max_id')) AS UNSIGNED),0)
 AND NOT EXISTS(SELECT 1 FROM Audit_Log x WHERE x.table_name='Loans' AND x.record_pk=CAST(l.loan_id AS CHAR) AND x.action_type='INSERT' AND x.audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0))
 UNION ALL
 SELECT 'I4',a.account_id,CAST(a.account_id AS CHAR(64)),'newest UPDATE audit balance differs' FROM Accounts a JOIN latest_audit x ON x.record_pk=CAST(a.account_id AS CHAR) AND x.rn=1 WHERE NOT (CAST(JSON_UNQUOTE(JSON_EXTRACT(x.new_value,'$.balance')) AS DECIMAL(14,2)) <=> a.balance)
),
 ids AS (SELECT 'I1' AS invariant UNION ALL SELECT 'I1b' UNION ALL SELECT 'I2' UNION ALL SELECT 'I3' UNION ALL SELECT 'I4' UNION ALL SELECT 'I5'),
 counts AS (SELECT ids.invariant,COUNT(p.invariant) AS violations FROM ids LEFT JOIN problems p USING(invariant) GROUP BY ids.invariant)
 SELECT JSON_ARRAYAGG(JSON_OBJECT('invariant',invariant,'violations',violations,'status',IF(violations=0,'PASS','FAIL'))) INTO @reconcile_results FROM counts;
 SELECT invariant,violations,status,v_checked AS checked_at FROM JSON_TABLE(@reconcile_results,'$[*]' COLUMNS(invariant VARCHAR(4) PATH '$.invariant',violations BIGINT PATH '$.violations',status VARCHAR(4) PATH '$.status')) j ORDER BY invariant;
 WITH
 ledger AS (SELECT account_id,transaction_id,transaction_type,amount,balance_after,
 CASE WHEN transaction_type IN ('Deposit','TransferIn','InterestCredit') THEN amount ELSE -amount END AS signed_amount
 FROM Transactions WHERE status='Completed'),
 totals AS (SELECT account_id,SUM(signed_amount) AS net,MAX(transaction_id) AS last_id FROM ledger GROUP BY account_id),
 chain AS (SELECT *,LAG(balance_after,1,0) OVER(PARTITION BY account_id ORDER BY transaction_id) AS prior_balance FROM ledger),
 wm AS (SELECT COALESCE((SELECT detail FROM bank_review_lab_1020095404.Experiment_Log WHERE db_name=DATABASE() AND event_type='AUDIT_TRIGGERS_INSTALLED' ORDER BY log_id DESC LIMIT 1),JSON_OBJECT()) AS j),
 latest_audit AS (SELECT record_pk,new_value,ROW_NUMBER() OVER(PARTITION BY record_pk ORDER BY audit_id DESC) AS rn FROM Audit_Log,wm WHERE table_name='Accounts' AND action_type='UPDATE' AND audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0)),
 problems AS (
 SELECT 'I1' AS invariant,a.account_id,CAST(a.account_id AS CHAR(64)) AS record_pk,'balance differs from completed ledger' AS detail
 FROM Accounts a LEFT JOIN totals t USING(account_id) WHERE (p_account_id IS NULL OR a.account_id=p_account_id) AND a.balance<>COALESCE(t.net,0)
 UNION ALL
 SELECT 'I1',NULL,'TOTAL','aggregate balance differs from completed ledger' FROM Accounts a LEFT JOIN totals t USING(account_id) WHERE p_account_id IS NULL OR a.account_id=p_account_id HAVING COALESCE(SUM(a.balance),0)<>COALESCE(SUM(t.net),0)
 UNION ALL
 SELECT 'I1b',account_id,CAST(transaction_id AS CHAR(64)),'balance_after chain break' FROM chain WHERE (p_account_id IS NULL OR account_id=p_account_id) AND balance_after<>prior_balance+signed_amount
 UNION ALL
 SELECT 'I2',MIN(account_id),transfer_group_id,'invalid paired transfer' FROM Transactions WHERE transfer_group_id IS NOT NULL GROUP BY transfer_group_id
 HAVING NOT (COUNT(*)=2 AND SUM(status='Completed')=2 AND SUM(transaction_type='TransferOut')=1 AND SUM(transaction_type='TransferIn')=1 AND MIN(amount)=MAX(amount)
 AND (MAX(CASE WHEN transaction_type='TransferOut' THEN account_id END) <=> MAX(CASE WHEN transaction_type='TransferIn' THEN related_account_id END))
 AND (MAX(CASE WHEN transaction_type='TransferIn' THEN account_id END) <=> MAX(CASE WHEN transaction_type='TransferOut' THEN related_account_id END)))
 UNION ALL
 SELECT 'I3',a.account_id,CAST(a.account_id AS CHAR(64)),'minimum or nonnegative balance violated' FROM Accounts a JOIN Account_Types t USING(account_type_id) WHERE (p_account_id IS NULL OR a.account_id=p_account_id) AND (a.balance<0 OR (a.status<>'Closed' AND a.balance<t.min_balance))
 UNION ALL
 SELECT 'I5',a.account_id,CAST(a.account_id AS CHAR(64)),'latest completed balance_after differs' FROM Accounts a JOIN totals t USING(account_id) JOIN ledger l ON l.transaction_id=t.last_id WHERE (p_account_id IS NULL OR a.account_id=p_account_id) AND a.balance<>l.balance_after
 UNION ALL
 SELECT 'I4',a.account_id,CAST(a.account_id AS CHAR(64)),'missing Accounts INSERT audit' FROM Accounts a CROSS JOIN wm WHERE a.account_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.accounts_max_id')) AS UNSIGNED),0)
 AND NOT EXISTS(SELECT 1 FROM Audit_Log x WHERE x.table_name='Accounts' AND x.record_pk=CAST(a.account_id AS CHAR) AND x.action_type='INSERT' AND x.audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0))
 UNION ALL
 SELECT 'I4',t.account_id,CAST(t.transaction_id AS CHAR(64)),'missing Transactions INSERT audit' FROM Transactions t CROSS JOIN wm WHERE t.transaction_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.transactions_max_id')) AS UNSIGNED),0)
 AND NOT EXISTS(SELECT 1 FROM Audit_Log x WHERE x.table_name='Transactions' AND x.record_pk=CAST(t.transaction_id AS CHAR) AND x.action_type='INSERT' AND x.audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0))
 UNION ALL
 SELECT 'I4',l.disbursement_account_id,CAST(l.loan_id AS CHAR(64)),'missing Loans INSERT audit' FROM Loans l CROSS JOIN wm WHERE l.loan_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.loans_max_id')) AS UNSIGNED),0)
 AND NOT EXISTS(SELECT 1 FROM Audit_Log x WHERE x.table_name='Loans' AND x.record_pk=CAST(l.loan_id AS CHAR) AND x.action_type='INSERT' AND x.audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0))
 UNION ALL
 SELECT 'I4',a.account_id,CAST(a.account_id AS CHAR(64)),'newest UPDATE audit balance differs' FROM Accounts a JOIN latest_audit x ON x.record_pk=CAST(a.account_id AS CHAR) AND x.rn=1 WHERE NOT (CAST(JSON_UNQUOTE(JSON_EXTRACT(x.new_value,'$.balance')) AS DECIMAL(14,2)) <=> a.balance)
)
 SELECT invariant,account_id,record_pk,detail FROM problems ORDER BY invariant,account_id,record_pk LIMIT 100;
END$$
DELIMITER ;
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
DELIMITER $$
CREATE PROCEDURE sp_request_approval(IN p_from_account_id INT, IN p_to_account_id INT, IN p_amount DECIMAL(14,2), IN p_requested_by_employee_id INT, IN p_requested_by_customer_id INT, OUT p_approval_id INT) SQL SECURITY DEFINER
BEGIN
 DECLARE v_actor VARCHAR(10); DECLARE v_e INT; DECLARE v_c INT;
 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK; SET p_approval_id=NULL;
  IF v_errno IN (5003,5004,5005,5006,5010) THEN BEGIN
   DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
   START TRANSACTION; CALL sp_internal_record_failed(p_from_account_id,p_amount,'TransferOut','Online'); COMMIT;
  END; END IF;
  RESIGNAL;
 END;
 SET p_approval_id=NULL;
 IF p_amount IS NULL OR p_amount<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: amount must be positive'; END IF;
 START TRANSACTION;
 IF p_from_account_id IS NULL OR p_to_account_id IS NULL OR NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_from_account_id) OR NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_to_account_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: transfer account does not exist'; END IF;
 IF p_from_account_id=p_to_account_id THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5005,MESSAGE_TEXT='E_SAME_ACCOUNT: accounts must differ'; END IF;
 IF EXISTS(SELECT 1 FROM Accounts WHERE account_id IN (p_from_account_id,p_to_account_id) AND status<>'Active') THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5003,MESSAGE_TEXT='E_ACCOUNT_NOT_ACTIVE: both accounts must be active'; END IF;
 CALL sp_resolve_actor(USER(),v_actor,v_e,v_c);
 IF (v_actor='Employee' AND p_requested_by_employee_id=v_e AND p_requested_by_customer_id IS NULL AND EXISTS(SELECT 1 FROM Employees WHERE employee_id=v_e AND is_active)) THEN
  CALL sp_internal_authorize(p_from_account_id,'Branch',p_requested_by_employee_id,1,1);
 ELSEIF (v_actor='Customer' AND p_requested_by_customer_id=v_c AND p_requested_by_employee_id IS NULL AND EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_from_account_id AND customer_id=v_c)) THEN
  CALL sp_internal_authorize(p_from_account_id,'Online',NULL,1,0);
 ELSE SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: requester must match resolved actor'; END IF;
 INSERT INTO Transaction_Approvals(requested_by_actor_type,requested_by_employee_id,requested_by_customer_id,from_account_id,to_account_id,amount,status) VALUES(v_actor,p_requested_by_employee_id,p_requested_by_customer_id,p_from_account_id,p_to_account_id,p_amount,'Requested');
 SET p_approval_id=LAST_INSERT_ID();
 COMMIT;
END$$
DELIMITER ;
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
-- Evaluates one posted transaction. Safe to call repeatedly: unique(transaction_id,rule_id).
DELIMITER $$
CREATE PROCEDURE sp_evaluate_fraud(IN p_transaction_id BIGINT)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_account INT;
  DECLARE v_amount DECIMAL(14,2);
  DECLARE v_channel VARCHAR(10);
  DECLARE v_device INT;
  DECLARE v_customer INT;
  DECLARE v_trusted BOOLEAN DEFAULT FALSE;
  DECLARE v_risk DECIMAL(5,2) DEFAULT 0;
  DECLARE v_score DECIMAL(5,2) DEFAULT 0;
  DECLARE v_rule_id INT;
  DECLARE v_weight DECIMAL(5,2);
  DECLARE v_code VARCHAR(40);
  DECLARE v_done INT DEFAULT 0;
  DECLARE c_rules CURSOR FOR SELECT rule_id,rule_code,weight FROM Fraud_Rules WHERE is_active=TRUE ORDER BY rule_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done=1;

  IF NOT EXISTS(SELECT 1 FROM Transactions WHERE transaction_id=p_transaction_id AND status='Completed') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='E_FRAUD_TXN_NOT_FOUND_OR_NOT_COMPLETED';
  END IF;
  SELECT t.account_id,t.amount,t.channel,t.device_id,a.customer_id
    INTO v_account,v_amount,v_channel,v_device,v_customer
    FROM Transactions t JOIN Accounts a ON a.account_id=t.account_id
   WHERE t.transaction_id=p_transaction_id;
  SET v_risk=COALESCE((SELECT risk_score FROM Account_Risk_Profile WHERE account_id=v_account),0);
  SET v_trusted=COALESCE((SELECT is_trusted FROM Devices WHERE device_id=v_device),FALSE);
  SET v_score=fn_fraud_score(v_amount,v_channel,v_trusted,v_risk);

  OPEN c_rules;
  rule_loop: LOOP
    FETCH c_rules INTO v_rule_id,v_code,v_weight;
    IF v_done=1 THEN LEAVE rule_loop; END IF;
    IF (v_code='HIGH_AMOUNT' AND v_amount>=5000)
       OR (v_code='UNTRUSTED_DEVICE' AND (v_device IS NULL OR v_trusted=FALSE))
       OR (v_code='DIGITAL_CHANNEL' AND v_channel IN ('Online','Mobile'))
       OR (v_code='HIGH_ACCOUNT_RISK' AND v_risk>=60)
       OR (v_code='RAPID_ACTIVITY' AND
           (SELECT COUNT(*) FROM Transactions t2
             WHERE t2.account_id=v_account AND t2.status='Completed'
               AND t2.transaction_timestamp >= (SELECT transaction_timestamp FROM Transactions WHERE transaction_id=p_transaction_id) - INTERVAL 10 MINUTE
               AND t2.transaction_timestamp <= (SELECT transaction_timestamp FROM Transactions WHERE transaction_id=p_transaction_id)) >= 3)
    THEN
      SET v_score=LEAST(100,v_score+v_weight);
      INSERT INTO Fraud_Flags(transaction_id,rule_id,risk_score,evidence)
      VALUES(p_transaction_id,v_rule_id,v_score,
        JSON_OBJECT('rule_code',v_code,'amount',v_amount,'channel',v_channel,
                    'device_id',v_device,'device_trusted',v_trusted,
                    'account_risk_score',v_risk,'evaluated_at',NOW()))
      ON DUPLICATE KEY UPDATE risk_score=GREATEST(risk_score,VALUES(risk_score)),
                              evidence=VALUES(evidence);
    END IF;
  END LOOP;
  CLOSE c_rules;

  INSERT INTO Account_Risk_Profile(account_id,risk_score,risk_level,last_evaluated_at)
  VALUES(v_account,v_score,
    CASE WHEN v_score>=85 THEN 'Critical' WHEN v_score>=60 THEN 'High'
         WHEN v_score>=30 THEN 'Medium' ELSE 'Low' END,NOW())
  ON DUPLICATE KEY UPDATE risk_score=VALUES(risk_score),risk_level=VALUES(risk_level),
                          last_evaluated_at=VALUES(last_evaluated_at);
END$$
DELIMITER ;
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
DELIMITER $$
CREATE PROCEDURE sp_transfer_funds_retry(IN p_from_account_id INT, IN p_to_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, IN p_lab_mode TINYINT, IN p_max_retries INT, OUT p_transfer_group_id CHAR(36), OUT p_debit_txn_id BIGINT, OUT p_credit_txn_id BIGINT, OUT p_attempts INT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_limit INT; DECLARE v_error INT DEFAULT 0; DECLARE v_backoff DOUBLE;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 SET p_attempts=0,p_transfer_group_id=NULL,p_debit_txn_id=NULL,p_credit_txn_id=NULL;
 SET v_limit=COALESCE(p_max_retries,5);
 IF v_limit<1 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: retry limit must be positive'; END IF;
 retry_loop: LOOP
  SET p_attempts=p_attempts+1,v_error=0;
  BEGIN
   DECLARE CONTINUE HANDLER FOR 1213 SET v_error=1213;
   DECLARE CONTINUE HANDLER FOR 1205 SET v_error=1205;
   CALL sp_transfer_funds(p_from_account_id,p_to_account_id,p_amount,p_channel,p_employee_id,p_device_id,p_location_id,p_lab_mode,p_transfer_group_id,p_debit_txn_id,p_credit_txn_id);
  END;
  IF v_error=0 THEN LEAVE retry_loop; END IF;
  BEGIN
   DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
   START TRANSACTION;
   INSERT INTO bank_review_lab_1020095404.Experiment_Log(db_name,exp_id,event_type,detail) VALUES(DATABASE(),'RETRY',IF(v_error=1213,'DEADLOCK_RETRY','LOCKWAIT_RETRY'),JSON_OBJECT('from_account',p_from_account_id,'to_account',p_to_account_id,'attempt',p_attempts));
   COMMIT;
  END;
  IF p_attempts>=v_limit THEN
   BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
    START TRANSACTION;
    INSERT INTO bank_review_lab_1020095404.Experiment_Log(db_name,exp_id,event_type,detail) VALUES(DATABASE(),'RETRY','RETRY_EXHAUSTED',JSON_OBJECT('from_account',p_from_account_id,'to_account',p_to_account_id,'attempt',p_attempts));
    COMMIT;
   END;
   SIGNAL SQLSTATE '40001' SET MYSQL_ERRNO=1213,MESSAGE_TEXT='E_RETRY_EXHAUSTED: whole-transaction retry limit reached';
  END IF;
  SELECT SLEEP(RAND()*0.2) INTO v_backoff;
 END LOOP;
END$$
DELIMITER ;
DELIMITER $$
CREATE PROCEDURE sp_transfer_funds(IN p_from_account_id INT, IN p_to_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, IN p_lab_mode TINYINT, OUT p_transfer_group_id CHAR(36), OUT p_debit_txn_id BIGINT, OUT p_credit_txn_id BIGINT)
SQL SECURITY DEFINER
BEGIN

 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK;
  SET p_transfer_group_id=NULL,p_debit_txn_id=NULL,p_credit_txn_id=NULL;
  IF v_errno IN (5003,5004,5005,5006,5010) THEN
   BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
    START TRANSACTION;
    CALL sp_internal_record_failed(p_from_account_id,p_amount,'TransferOut',p_channel);
    COMMIT;
   END;
  END IF;
  RESIGNAL;
 END;
 SET p_transfer_group_id=NULL,p_debit_txn_id=NULL,p_credit_txn_id=NULL;
 IF p_amount IS NULL OR p_amount<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: amount must be positive'; END IF;
 IF p_lab_mode IS NULL OR p_lab_mode NOT IN (0,1,2,3) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid lab mode'; END IF;
 IF p_from_account_id=p_to_account_id THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5005,MESSAGE_TEXT='E_SAME_ACCOUNT: accounts must differ'; END IF;
 IF p_amount>=fn_approval_threshold() THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5006,MESSAGE_TEXT='E_APPROVAL_REQUIRED: approval threshold reached'; END IF;
 -- RELEASE_GUARD_PLACEHOLDER
 START TRANSACTION;
 -- LAB_HOOK_BEGIN
 -- The hook executes in the private helper within this public transaction.
 -- LAB_HOOK_END
 -- LAB_NAIVE_BEGIN
 -- Lab lock-order selection is delegated to the same private helper.
 -- LAB_NAIVE_END
 CALL sp_internal_post_transfer(p_from_account_id,p_to_account_id,p_amount,p_channel,p_employee_id,p_device_id,p_location_id,p_lab_mode,0,p_transfer_group_id,p_debit_txn_id,p_credit_txn_id);
 COMMIT;
END$$
DELIMITER ;
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
DELIMITER $$
CREATE PROCEDURE sp_withdraw(IN p_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, OUT p_transaction_id BIGINT, OUT p_balance_after DECIMAL(14,2))
SQL SECURITY DEFINER
BEGIN

 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK;
  SET p_transaction_id=NULL,p_balance_after=NULL;
  IF v_errno IN (5003,5004,5005,5006,5010) THEN
   BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
    START TRANSACTION;
    CALL sp_internal_record_failed(p_account_id,p_amount,'Withdrawal',p_channel);
    COMMIT;
   END;
  END IF;
  RESIGNAL;
 END;
 SET p_transaction_id=NULL,p_balance_after=NULL;
 IF p_amount IS NULL OR p_amount<=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5001,MESSAGE_TEXT='E_INVALID_AMOUNT: amount must be positive'; END IF;
 START TRANSACTION;
 CALL sp_internal_post_single(p_account_id,p_amount,'Withdrawal',p_channel,p_employee_id,p_device_id,p_location_id,p_transaction_id,p_balance_after);
 COMMIT;
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_accounts_bu_minbal_guard BEFORE UPDATE ON Accounts FOR EACH ROW
BEGIN
 DECLARE v_min DECIMAL(12,2);
 IF OLD.status='Closed' AND (NOT (NEW.balance <=> OLD.balance) OR NEW.status<>'Closed') THEN
  SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5011,MESSAGE_TEXT='E_INVALID_TRANSITION: closed account cannot change balance or status';
 END IF;
 SELECT min_balance INTO v_min FROM Account_Types WHERE account_type_id=NEW.account_type_id;
 IF NOT (NEW.balance <=> OLD.balance) AND NEW.balance=0 AND NEW.status<>'Closed' THEN
  SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5015,MESSAGE_TEXT='E_MINBAL_GUARD: zero balance requires closure';
 END IF;
 IF NEW.balance<OLD.balance AND NEW.balance<v_min AND NOT (NEW.balance=0 AND NEW.status='Closed') THEN
  SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5015,MESSAGE_TEXT='E_MINBAL_GUARD: decrease would breach minimum balance';
 END IF;
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_audit_log_bd_immutable BEFORE DELETE ON Audit_Log FOR EACH ROW
BEGIN
 SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5013,MESSAGE_TEXT='E_AUDIT_IMMUTABLE: audit rows cannot be deleted';
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_audit_log_bu_immutable BEFORE UPDATE ON Audit_Log FOR EACH ROW
BEGIN
 SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5013,MESSAGE_TEXT='E_AUDIT_IMMUTABLE: audit rows cannot be updated';
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_transactions_bd_immutable BEFORE DELETE ON Transactions FOR EACH ROW
BEGIN
 SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5012,MESSAGE_TEXT='E_LEDGER_IMMUTABLE: ledger rows cannot be deleted';
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_transactions_bi_device_owner BEFORE INSERT ON Transactions FOR EACH ROW
BEGIN
 DECLARE v_account_owner INT;
 DECLARE v_device_owner INT;
 IF NEW.related_account_id=NEW.account_id THEN
  SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5005,MESSAGE_TEXT='E_SAME_ACCOUNT: counterparty must be a different account';
 END IF;
 IF NEW.device_id IS NOT NULL THEN
  SET v_account_owner=(SELECT customer_id FROM Accounts WHERE account_id=NEW.account_id);
  SET v_device_owner=(SELECT customer_id FROM Devices WHERE device_id=NEW.device_id);
  -- A missing reference is left to the FK (1452); an existing mismatched device is 5014.
  IF v_account_owner IS NOT NULL AND v_device_owner IS NOT NULL AND v_account_owner<>v_device_owner THEN
   SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5014,MESSAGE_TEXT='E_DEVICE_OWNER_MISMATCH: device belongs to another customer';
  END IF;
 END IF;
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_transactions_bu_immutable BEFORE UPDATE ON Transactions FOR EACH ROW
BEGIN
 SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5012,MESSAGE_TEXT='E_LEDGER_IMMUTABLE: ledger rows cannot be updated';
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_accounts_ad_audit AFTER DELETE ON Accounts FOR EACH ROW
BEGIN
 DECLARE v_actor VARCHAR(10);
 DECLARE v_employee INT;
 DECLARE v_customer INT;
 CALL sp_resolve_actor(USER(),v_actor,v_employee,v_customer);
 INSERT INTO Audit_Log(table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,actor_employee_id,actor_customer_id)
 VALUES('Accounts',CAST(OLD.account_id AS CHAR),'DELETE',JSON_OBJECT('account_id',OLD.account_id,'customer_id',OLD.customer_id,'branch_id',OLD.branch_id,'account_type_id',OLD.account_type_id,'account_number',OLD.account_number,'balance',OLD.balance,'status',OLD.status,'opened_date',OLD.opened_date),NULL,USER(),v_actor,v_employee,v_customer);
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_accounts_ai_audit AFTER INSERT ON Accounts FOR EACH ROW
BEGIN
 DECLARE v_actor VARCHAR(10);
 DECLARE v_employee INT;
 DECLARE v_customer INT;
 CALL sp_resolve_actor(USER(),v_actor,v_employee,v_customer);
 INSERT INTO Audit_Log(table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,actor_employee_id,actor_customer_id)
 VALUES('Accounts',CAST(NEW.account_id AS CHAR),'INSERT',NULL,JSON_OBJECT('account_id',NEW.account_id,'customer_id',NEW.customer_id,'branch_id',NEW.branch_id,'account_type_id',NEW.account_type_id,'account_number',NEW.account_number,'balance',NEW.balance,'status',NEW.status,'opened_date',NEW.opened_date),USER(),v_actor,v_employee,v_customer);
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_accounts_au_audit AFTER UPDATE ON Accounts FOR EACH ROW
BEGIN
 DECLARE v_actor VARCHAR(10);
 DECLARE v_employee INT;
 DECLARE v_customer INT;
 CALL sp_resolve_actor(USER(),v_actor,v_employee,v_customer);
 INSERT INTO Audit_Log(table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,actor_employee_id,actor_customer_id)
 VALUES('Accounts',CAST(NEW.account_id AS CHAR),'UPDATE',JSON_OBJECT('account_id',OLD.account_id,'customer_id',OLD.customer_id,'branch_id',OLD.branch_id,'account_type_id',OLD.account_type_id,'account_number',OLD.account_number,'balance',OLD.balance,'status',OLD.status,'opened_date',OLD.opened_date),JSON_OBJECT('account_id',NEW.account_id,'customer_id',NEW.customer_id,'branch_id',NEW.branch_id,'account_type_id',NEW.account_type_id,'account_number',NEW.account_number,'balance',NEW.balance,'status',NEW.status,'opened_date',NEW.opened_date),USER(),v_actor,v_employee,v_customer);
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_loans_ad_audit AFTER DELETE ON Loans FOR EACH ROW
BEGIN
 DECLARE v_actor VARCHAR(10);
 DECLARE v_employee INT;
 DECLARE v_customer INT;
 CALL sp_resolve_actor(USER(),v_actor,v_employee,v_customer);
 INSERT INTO Audit_Log(table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,actor_employee_id,actor_customer_id)
 VALUES('Loans',CAST(OLD.loan_id AS CHAR),'DELETE',JSON_OBJECT('loan_id',OLD.loan_id,'customer_id',OLD.customer_id,'disbursement_account_id',OLD.disbursement_account_id,'principal_amount',OLD.principal_amount,'interest_rate',OLD.interest_rate,'tenure_months',OLD.tenure_months,'status',OLD.status,'disbursed_date',OLD.disbursed_date),NULL,USER(),v_actor,v_employee,v_customer);
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_loans_ai_audit AFTER INSERT ON Loans FOR EACH ROW
BEGIN
 DECLARE v_actor VARCHAR(10);
 DECLARE v_employee INT;
 DECLARE v_customer INT;
 CALL sp_resolve_actor(USER(),v_actor,v_employee,v_customer);
 INSERT INTO Audit_Log(table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,actor_employee_id,actor_customer_id)
 VALUES('Loans',CAST(NEW.loan_id AS CHAR),'INSERT',NULL,JSON_OBJECT('loan_id',NEW.loan_id,'customer_id',NEW.customer_id,'disbursement_account_id',NEW.disbursement_account_id,'principal_amount',NEW.principal_amount,'interest_rate',NEW.interest_rate,'tenure_months',NEW.tenure_months,'status',NEW.status,'disbursed_date',NEW.disbursed_date),USER(),v_actor,v_employee,v_customer);
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_loans_au_audit AFTER UPDATE ON Loans FOR EACH ROW
BEGIN
 DECLARE v_actor VARCHAR(10);
 DECLARE v_employee INT;
 DECLARE v_customer INT;
 CALL sp_resolve_actor(USER(),v_actor,v_employee,v_customer);
 INSERT INTO Audit_Log(table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,actor_employee_id,actor_customer_id)
 VALUES('Loans',CAST(NEW.loan_id AS CHAR),'UPDATE',JSON_OBJECT('loan_id',OLD.loan_id,'customer_id',OLD.customer_id,'disbursement_account_id',OLD.disbursement_account_id,'principal_amount',OLD.principal_amount,'interest_rate',OLD.interest_rate,'tenure_months',OLD.tenure_months,'status',OLD.status,'disbursed_date',OLD.disbursed_date),JSON_OBJECT('loan_id',NEW.loan_id,'customer_id',NEW.customer_id,'disbursement_account_id',NEW.disbursement_account_id,'principal_amount',NEW.principal_amount,'interest_rate',NEW.interest_rate,'tenure_months',NEW.tenure_months,'status',NEW.status,'disbursed_date',NEW.disbursed_date),USER(),v_actor,v_employee,v_customer);
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_transactions_ad_audit AFTER DELETE ON Transactions FOR EACH ROW
BEGIN
 DECLARE v_actor VARCHAR(10);
 DECLARE v_employee INT;
 DECLARE v_customer INT;
 CALL sp_resolve_actor(USER(),v_actor,v_employee,v_customer);
 INSERT INTO Audit_Log(table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,actor_employee_id,actor_customer_id)
 VALUES('Transactions',CAST(OLD.transaction_id AS CHAR),'DELETE',JSON_OBJECT('transaction_id',OLD.transaction_id,'account_id',OLD.account_id,'related_account_id',OLD.related_account_id,'employee_id',OLD.employee_id,'transfer_group_id',OLD.transfer_group_id,'device_id',OLD.device_id,'location_id',OLD.location_id,'transaction_type',OLD.transaction_type,'amount',OLD.amount,'balance_after',OLD.balance_after,'channel',OLD.channel,'status',OLD.status,'transaction_timestamp',OLD.transaction_timestamp,'reference_no',OLD.reference_no),NULL,USER(),v_actor,v_employee,v_customer);
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_transactions_ai_audit AFTER INSERT ON Transactions FOR EACH ROW
BEGIN
 DECLARE v_actor VARCHAR(10);
 DECLARE v_employee INT;
 DECLARE v_customer INT;
 CALL sp_resolve_actor(USER(),v_actor,v_employee,v_customer);
 INSERT INTO Audit_Log(table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,actor_employee_id,actor_customer_id)
 VALUES('Transactions',CAST(NEW.transaction_id AS CHAR),'INSERT',NULL,JSON_OBJECT('transaction_id',NEW.transaction_id,'account_id',NEW.account_id,'related_account_id',NEW.related_account_id,'employee_id',NEW.employee_id,'transfer_group_id',NEW.transfer_group_id,'device_id',NEW.device_id,'location_id',NEW.location_id,'transaction_type',NEW.transaction_type,'amount',NEW.amount,'balance_after',NEW.balance_after,'channel',NEW.channel,'status',NEW.status,'transaction_timestamp',NEW.transaction_timestamp,'reference_no',NEW.reference_no),USER(),v_actor,v_employee,v_customer);
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_transactions_au_audit AFTER UPDATE ON Transactions FOR EACH ROW
BEGIN
 DECLARE v_actor VARCHAR(10);
 DECLARE v_employee INT;
 DECLARE v_customer INT;
 CALL sp_resolve_actor(USER(),v_actor,v_employee,v_customer);
 INSERT INTO Audit_Log(table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,actor_employee_id,actor_customer_id)
 VALUES('Transactions',CAST(NEW.transaction_id AS CHAR),'UPDATE',JSON_OBJECT('transaction_id',OLD.transaction_id,'account_id',OLD.account_id,'related_account_id',OLD.related_account_id,'employee_id',OLD.employee_id,'transfer_group_id',OLD.transfer_group_id,'device_id',OLD.device_id,'location_id',OLD.location_id,'transaction_type',OLD.transaction_type,'amount',OLD.amount,'balance_after',OLD.balance_after,'channel',OLD.channel,'status',OLD.status,'transaction_timestamp',OLD.transaction_timestamp,'reference_no',OLD.reference_no),JSON_OBJECT('transaction_id',NEW.transaction_id,'account_id',NEW.account_id,'related_account_id',NEW.related_account_id,'employee_id',NEW.employee_id,'transfer_group_id',NEW.transfer_group_id,'device_id',NEW.device_id,'location_id',NEW.location_id,'transaction_type',NEW.transaction_type,'amount',NEW.amount,'balance_after',NEW.balance_after,'channel',NEW.channel,'status',NEW.status,'transaction_timestamp',NEW.transaction_timestamp,'reference_no',NEW.reference_no),USER(),v_actor,v_employee,v_customer);
END$$
DELIMITER ;
INSERT INTO bank_review_lab_1020095404.Experiment_Log(db_name,exp_id,event_type,detail)
SELECT DATABASE(),'SYS','AUDIT_TRIGGERS_INSTALLED',JSON_OBJECT(
 'db',DATABASE(),'accounts_max_id',(SELECT COALESCE(MAX(account_id),0) FROM Accounts),
 'transactions_max_id',(SELECT COALESCE(MAX(transaction_id),0) FROM Transactions),
 'loans_max_id',(SELECT COALESCE(MAX(loan_id),0) FROM Loans),
 'audit_max_id',(SELECT COALESCE(MAX(audit_id),0) FROM Audit_Log),'installed_at',NOW(3));
-- Idempotent synthetic rule catalog. Weights are additive and scores are capped at 100.
INSERT INTO Fraud_Rules(rule_code,description,weight,param_json,is_active) VALUES
('HIGH_AMOUNT','Transaction amount is at least 5000',20,JSON_OBJECT('minimum_amount',5000),TRUE),
('UNTRUSTED_DEVICE','Transaction uses a missing or untrusted device',20,NULL,TRUE),
('DIGITAL_CHANNEL','Transaction is initiated through online/mobile channel',10,NULL,TRUE),
('HIGH_ACCOUNT_RISK','Account risk profile is at least 60',25,JSON_OBJECT('minimum_risk',60),TRUE),
('RAPID_ACTIVITY','At least three completed transactions in a rolling ten-minute window',25,JSON_OBJECT('window_minutes',10,'minimum_count',3),TRUE)
ON DUPLICATE KEY UPDATE description=VALUES(description),weight=VALUES(weight),
  param_json=VALUES(param_json),is_active=VALUES(is_active);
-- Runs after audit capture; only completed transactions are scored.
DELIMITER $$
CREATE TRIGGER trg_transactions_ai_fraud_evaluate
AFTER INSERT ON Transactions
FOR EACH ROW FOLLOWS trg_transactions_ai_audit
BEGIN
  IF NEW.status='Completed' THEN
    CALL sp_evaluate_fraud(NEW.transaction_id);
  END IF;
END$$
DELIMITER ;
-- Synthetic reference data only. Natural unique keys make repeated loads idempotent.
INSERT INTO Branches(branch_name,ifsc_code,address,city,state,phone) VALUES
 ('Synthetic Central','SYNB0000001','1 Synthetic Road','Bengaluru','Karnataka','0000000001'),
 ('Synthetic North','SYNB0000002','2 Synthetic Road','Mysuru','Karnataka','0000000002'),
 ('Synthetic South','SYNB0000003','3 Synthetic Road','Mangaluru','Karnataka','0000000003')
ON DUPLICATE KEY UPDATE branch_name=VALUES(branch_name),address=VALUES(address),city=VALUES(city),state=VALUES(state),phone=VALUES(phone);
INSERT INTO Account_Types(type_name,interest_rate,min_balance) VALUES
 ('Savings',3.50,1000.00),('Current',0.00,5000.00),('Fixed Deposit',6.50,10000.00)
ON DUPLICATE KEY UPDATE interest_rate=VALUES(interest_rate),min_balance=VALUES(min_balance);
INSERT INTO Employees(branch_id,full_name,role,email,hire_date,is_active)
SELECT branch_id,'Synthetic Teller One','Teller','teller.one@example.invalid','2020-01-01',TRUE FROM Branches WHERE ifsc_code='SYNB0000001'
UNION ALL SELECT branch_id,'Synthetic Teller Two','Teller','teller.two@example.invalid','2020-01-01',TRUE FROM Branches WHERE ifsc_code='SYNB0000002'
UNION ALL SELECT branch_id,'Synthetic Manager One','Manager','manager.one@example.invalid','2020-01-01',TRUE FROM Branches WHERE ifsc_code='SYNB0000001'
UNION ALL SELECT branch_id,'Synthetic Manager Two','Manager','manager.two@example.invalid','2020-01-01',TRUE FROM Branches WHERE ifsc_code='SYNB0000002'
UNION ALL SELECT branch_id,'Synthetic DBA','DBA','dba@example.invalid','2020-01-01',TRUE FROM Branches WHERE ifsc_code='SYNB0000001'
ON DUPLICATE KEY UPDATE branch_id=VALUES(branch_id),full_name=VALUES(full_name),role=VALUES(role),hire_date=VALUES(hire_date),is_active=VALUES(is_active);
-- All identities and numbers are synthetic. Calls public APIs; no bulk ledger writes.
DELIMITER $$
DROP PROCEDURE IF EXISTS p3_load_tiny_seed$$
CREATE PROCEDURE p3_load_tiny_seed()
SQL SECURITY DEFINER
BEGIN
 DECLARE v_i INT DEFAULT 1;
 DECLARE v_customer INT; DECLARE v_branch INT; DECLARE v_type INT; DECLARE v_employee INT;
 DECLARE v_account INT; DECLARE v_number VARCHAR(20); DECLARE v_email VARCHAR(100); DECLARE v_proof VARCHAR(20);
 DECLARE v_initial DECIMAL(14,2); DECLARE v_tx BIGINT; DECLARE v_balance DECIMAL(14,2);
 DECLARE v_from INT; DECLARE v_to INT; DECLARE v_group CHAR(36); DECLARE v_debit BIGINT; DECLARE v_credit BIGINT; DECLARE v_loan INT;
 WHILE v_i<=6 DO
  SET v_email=CONCAT('seed.customer.',v_i,'@example.invalid');
  IF NOT EXISTS(SELECT 1 FROM Customers WHERE email=v_email) THEN
   SET v_proof=ELT(v_i,'Aadhaar','PAN','Passport','DrivingLicense','VoterID','PAN');
   CALL sp_register_customer(CONCAT('Synthetic Seed Customer ',v_i),'1990-01-01',NULL,v_email,CONCAT('900000000',v_i),'Synthetic seed address',CONCAT('SYN-',v_proof,'-',LPAD(v_i,6,'0')),v_proof,v_customer);
  END IF;
  SET v_i=v_i+1;
 END WHILE;
 SET v_i=1;
 WHILE v_i<=8 DO
  SET v_number=CONCAT('SEED-',LPAD(v_i,4,'0'));
  IF NOT EXISTS(SELECT 1 FROM Accounts WHERE account_number=v_number) THEN
   SET v_customer=(SELECT customer_id FROM Customers WHERE email=CONCAT('seed.customer.',IF(v_i<=6,v_i,v_i-6),'@example.invalid'));
   SET v_branch=(SELECT branch_id FROM Branches WHERE ifsc_code=IF(MOD(v_i,2)=1,'SYNB0000001','SYNB0000002'));
   SET v_type=(SELECT account_type_id FROM Account_Types WHERE type_name=IF(v_i=7,'Fixed Deposit',IF(v_i=8,'Current','Savings')));
   SET v_employee=(SELECT employee_id FROM Employees WHERE branch_id=v_branch AND role='Teller' AND is_active ORDER BY employee_id LIMIT 1);
   SET v_initial=CASE v_i WHEN 1 THEN 300000 WHEN 2 THEN 200000 WHEN 7 THEN 15000 WHEN 8 THEN 10000 ELSE 5000 END;
   CALL sp_open_account(v_customer,v_branch,v_type,v_initial,v_employee,v_number,v_account,v_number);
  END IF;
  SET v_i=v_i+1;
 END WHILE;
 SET v_from=(SELECT account_id FROM Accounts WHERE account_number='SEED-0003');
 SET v_customer=(SELECT customer_id FROM Accounts WHERE account_id=v_from);
 IF NOT EXISTS(SELECT 1 FROM Loans WHERE customer_id=v_customer AND disbursement_account_id=v_from AND principal_amount=10000) THEN
  CALL sp_disburse_loan(v_customer,v_from,10000,8.00,12,NULL,v_loan);
 END IF;
 SET v_i=1;
 WHILE v_i<=6 DO
  SET v_from=(SELECT account_id FROM Accounts WHERE account_number=CONCAT('SEED-',LPAD(IF(v_i<=5,v_i,1),4,'0')));
  IF NOT EXISTS(SELECT 1 FROM Transactions WHERE account_id=v_from AND transaction_type='Deposit' AND status='Completed' AND amount=110+v_i) THEN
   CALL sp_deposit(v_from,110+v_i,'Online',NULL,NULL,NULL,v_tx,v_balance);
  END IF;
  SET v_i=v_i+1;
 END WHILE;
 SET v_i=1;
 WHILE v_i<=2 DO
  SET v_from=(SELECT account_id FROM Accounts WHERE account_number=CONCAT('SEED-',LPAD(v_i,4,'0')));
  IF NOT EXISTS(SELECT 1 FROM Transactions WHERE account_id=v_from AND transaction_type='Withdrawal' AND status='Completed' AND amount=20+v_i) THEN
   CALL sp_withdraw(v_from,20+v_i,'Online',NULL,NULL,NULL,v_tx,v_balance);
  END IF;
  SET v_to=(SELECT account_id FROM Accounts WHERE account_number=CONCAT('SEED-',LPAD(3-v_i,4,'0')));
  IF NOT EXISTS(SELECT 1 FROM Transactions WHERE account_id=v_from AND related_account_id=v_to AND transaction_type='TransferOut' AND status='Completed' AND amount=200+v_i) THEN
   CALL sp_transfer_funds(v_from,v_to,200+v_i,'Online',NULL,NULL,NULL,0,v_group,v_debit,v_credit);
  END IF;
  SET v_i=v_i+1;
 END WHILE;
 SET v_account=(SELECT account_id FROM Accounts WHERE account_number='SEED-0006');
 IF (SELECT status FROM Accounts WHERE account_id=v_account)='Active' THEN
  SET v_employee=(SELECT e.employee_id FROM Employees e JOIN Accounts a ON a.branch_id=e.branch_id WHERE a.account_id=v_account AND e.role='Teller' AND e.is_active ORDER BY e.employee_id LIMIT 1);
  CALL sp_set_account_status(v_account,'Frozen',v_employee);
 END IF;
END$$
DELIMITER ;
CALL p3_load_tiny_seed();
DROP PROCEDURE p3_load_tiny_seed;
-- Row-scoped view: only the customer mapped to the current DB login can see these rows.
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_customer_account_summary AS
SELECT a.account_id,a.account_number,a.account_type_id,a.status,a.opened_date,
       a.balance, c.customer_id,c.full_name
FROM Accounts a JOIN Customers c ON c.customer_id=a.customer_id
WHERE c.customer_id = (
  SELECT m.customer_id FROM DB_User_Map m
  WHERE m.actor_type='Customer'
    AND m.db_login IN (USER(), SUBSTRING_INDEX(USER(),'@',1))
  ORDER BY (m.db_login=USER()) DESC LIMIT 1
);
-- Row-scoped view for mapped customer logins; do not grant it to untrusted shared accounts.
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_transaction_activity AS
SELECT t.transaction_id,t.account_id,t.related_account_id,t.transaction_type,
       t.amount,t.balance_after,t.channel,t.status,t.transaction_timestamp,
       t.reference_no,t.transfer_group_id
FROM Transactions t
WHERE EXISTS (
  SELECT 1 FROM Accounts a JOIN DB_User_Map m ON m.customer_id=a.customer_id
  WHERE a.account_id=t.account_id AND m.actor_type='Customer'
    AND m.db_login IN (USER(), SUBSTRING_INDEX(USER(),'@',1))
);
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_fraud_case_queue AS
SELECT f.flag_id,f.transaction_id,f.rule_id,r.rule_code,r.description,
       f.risk_score,f.flag_status,f.created_at,f.reviewed_by,
       t.account_id,t.amount,t.channel,t.transaction_timestamp
FROM Fraud_Flags f JOIN Fraud_Rules r ON r.rule_id=f.rule_id
JOIN Transactions t ON t.transaction_id=f.transaction_id
WHERE f.flag_status IN ('Open','UnderReview');