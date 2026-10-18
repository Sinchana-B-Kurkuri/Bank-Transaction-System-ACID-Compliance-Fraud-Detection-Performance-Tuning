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