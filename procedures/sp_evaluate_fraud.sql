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
