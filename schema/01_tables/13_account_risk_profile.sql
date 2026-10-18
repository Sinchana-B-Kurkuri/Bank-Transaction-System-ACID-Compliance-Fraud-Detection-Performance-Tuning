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