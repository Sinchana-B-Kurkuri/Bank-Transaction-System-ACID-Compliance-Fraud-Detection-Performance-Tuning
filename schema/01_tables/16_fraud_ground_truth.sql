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