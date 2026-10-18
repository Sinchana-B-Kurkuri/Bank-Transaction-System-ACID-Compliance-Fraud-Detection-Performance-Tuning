-- INTERFACE STAND-IN — NOT A DEFINITION — B's files replace this
CREATE TABLE IF NOT EXISTS Devices (
 device_id INT AUTO_INCREMENT PRIMARY KEY, customer_id INT NOT NULL,
 device_fingerprint CHAR(64) NOT NULL UNIQUE, device_type VARCHAR(20) NOT NULL,
 first_seen_at DATETIME NOT NULL, last_seen_at DATETIME NOT NULL, is_trusted BOOLEAN NOT NULL DEFAULT FALSE,
 CONSTRAINT fk_devices_customer_id FOREIGN KEY(customer_id) REFERENCES Customers(customer_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS Locations (
 location_id INT AUTO_INCREMENT PRIMARY KEY, city VARCHAR(50) NOT NULL, state VARCHAR(50), country VARCHAR(50) NOT NULL,
 latitude DECIMAL(9,6) NOT NULL, longitude DECIMAL(9,6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS Fraud_Rules (
 rule_id INT AUTO_INCREMENT PRIMARY KEY, rule_code VARCHAR(40) NOT NULL UNIQUE,
 description VARCHAR(200), weight DECIMAL(5,2) NOT NULL, param_json JSON, is_active BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS DB_User_Map (
 db_login VARCHAR(100) PRIMARY KEY, actor_type ENUM('Customer','Employee') NOT NULL,
 employee_id INT NULL, customer_id INT NULL,
 CONSTRAINT fk_db_user_map_employee_id FOREIGN KEY(employee_id) REFERENCES Employees(employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 CONSTRAINT fk_db_user_map_customer_id FOREIGN KEY(customer_id) REFERENCES Customers(customer_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 CONSTRAINT chk_db_user_map_actor CHECK(
 (actor_type='Employee' AND employee_id IS NOT NULL AND customer_id IS NULL) OR
 (actor_type='Customer' AND customer_id IS NOT NULL AND employee_id IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS Transaction_Approvals (
 approval_id INT AUTO_INCREMENT PRIMARY KEY, requested_by_actor_type ENUM('Customer','Employee') NOT NULL,
 requested_by_employee_id INT NULL, requested_by_customer_id INT NULL,
 requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 from_account_id INT NOT NULL, to_account_id INT NOT NULL, amount DECIMAL(14,2) NOT NULL,
 status ENUM('Requested','Approved','Rejected') NOT NULL DEFAULT 'Requested', decided_by INT NULL,
 decided_at DATETIME NULL, resulting_transfer_group_id CHAR(36) NULL,
 CONSTRAINT chk_transaction_approvals_amount CHECK(amount>0),
 CONSTRAINT fk_transaction_approvals_from_account_id FOREIGN KEY(from_account_id) REFERENCES Accounts(account_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 CONSTRAINT fk_transaction_approvals_to_account_id FOREIGN KEY(to_account_id) REFERENCES Accounts(account_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 CONSTRAINT fk_transaction_approvals_decided_by FOREIGN KEY(decided_by) REFERENCES Employees(employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS Fraud_Ground_Truth (
 transaction_id BIGINT PRIMARY KEY, is_fraud BOOLEAN NOT NULL, scenario_label VARCHAR(40),
 CONSTRAINT fk_fraud_ground_truth_transaction_id FOREIGN KEY(transaction_id) REFERENCES Transactions(transaction_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
