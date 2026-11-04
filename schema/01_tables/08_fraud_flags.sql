CREATE TABLE Fraud_Flags (
 flag_id INT AUTO_INCREMENT, transaction_id BIGINT NOT NULL, rule_id INT NOT NULL,
 risk_score DECIMAL(5,2) NOT NULL, evidence JSON NULL,
 flag_status ENUM('Open','UnderReview','Confirmed','Dismissed') NOT NULL DEFAULT 'Open',
 reviewed_by INT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT pk_fraud_flags PRIMARY KEY(flag_id), CONSTRAINT uq_fraud_flags_transaction_rule UNIQUE(transaction_id,rule_id),
 CONSTRAINT chk_fraud_flags_risk CHECK(risk_score BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
