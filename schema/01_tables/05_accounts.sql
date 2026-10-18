CREATE TABLE Accounts (
 account_id INT AUTO_INCREMENT, customer_id INT NOT NULL, branch_id INT NOT NULL,
 account_type_id INT NOT NULL, account_number VARCHAR(20) NOT NULL, balance DECIMAL(14,2) NOT NULL,
 status ENUM('Active','Frozen','Closed') NOT NULL DEFAULT 'Active', opened_date DATE NOT NULL,
 CONSTRAINT pk_accounts PRIMARY KEY(account_id), CONSTRAINT uq_accounts_number UNIQUE(account_number),
 CONSTRAINT chk_accounts_balance CHECK(balance>=0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
