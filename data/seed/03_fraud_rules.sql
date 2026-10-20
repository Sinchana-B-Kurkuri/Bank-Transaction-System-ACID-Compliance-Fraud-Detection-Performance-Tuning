-- Idempotent synthetic rule catalog. Weights are additive and scores are capped at 100.
INSERT INTO Fraud_Rules(rule_code,description,weight,param_json,is_active) VALUES
('HIGH_AMOUNT','Transaction amount is at least 5000',20,JSON_OBJECT('minimum_amount',5000),TRUE),
('UNTRUSTED_DEVICE','Transaction uses a missing or untrusted device',20,NULL,TRUE),
('DIGITAL_CHANNEL','Transaction is initiated through online/mobile channel',10,NULL,TRUE),
('HIGH_ACCOUNT_RISK','Accumulated transaction-local risk before this rule is at least 60',25,JSON_OBJECT('minimum_risk',60),TRUE),
('RAPID_ACTIVITY','At least three completed transactions in a rolling ten-minute window',25,JSON_OBJECT('window_minutes',10,'minimum_count',3),TRUE)
ON DUPLICATE KEY UPDATE description=VALUES(description),weight=VALUES(weight),
  param_json=VALUES(param_json),is_active=VALUES(is_active);
