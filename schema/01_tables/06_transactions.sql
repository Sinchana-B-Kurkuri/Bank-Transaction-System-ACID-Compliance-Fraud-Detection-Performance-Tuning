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
