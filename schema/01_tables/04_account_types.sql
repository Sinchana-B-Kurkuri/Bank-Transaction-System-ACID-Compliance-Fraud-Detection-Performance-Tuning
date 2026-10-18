CREATE TABLE Account_Types (
 account_type_id INT AUTO_INCREMENT, type_name VARCHAR(30) NOT NULL,
 interest_rate DECIMAL(5,2) NOT NULL, min_balance DECIMAL(12,2) NOT NULL,
 CONSTRAINT pk_account_types PRIMARY KEY(account_type_id), CONSTRAINT uq_account_types_name UNIQUE(type_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
