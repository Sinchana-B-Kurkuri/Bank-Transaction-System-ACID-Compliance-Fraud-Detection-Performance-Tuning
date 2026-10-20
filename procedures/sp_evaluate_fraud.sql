-- Deterministic re-evaluation: score is rebuilt from transaction facts and active rule weights;
-- stored profile score is never fed back into the same transaction's score.
DELIMITER $$
CREATE PROCEDURE sp_evaluate_fraud(IN p_transaction_id BIGINT)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_account INT;
  DECLARE v_amount DECIMAL(14,2);
  DECLARE v_channel VARCHAR(10);
  DECLARE v_device INT;
  DECLARE v_txn_ts DATETIME;
  DECLARE v_trusted BOOLEAN DEFAULT FALSE;
  DECLARE v_profile_risk DECIMAL(5,2) DEFAULT 0;
  DECLARE v_score DECIMAL(5,2) DEFAULT 0;
  DECLARE v_rule_id INT;
  DECLARE v_weight DECIMAL(5,2);
  DECLARE v_code VARCHAR(40);
  DECLARE v_params JSON;
  DECLARE v_min_amount DECIMAL(14,2);
  DECLARE v_min_risk DECIMAL(5,2);
  DECLARE v_window INT;
  DECLARE v_min_count INT;
  DECLARE v_matches BOOLEAN;
  DECLARE v_done INT DEFAULT 0;
  DECLARE c_rules CURSOR FOR
    SELECT rule_id,rule_code,weight,param_json
      FROM Fraud_Rules WHERE is_active=TRUE ORDER BY rule_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done=1;

  IF NOT EXISTS(SELECT 1 FROM Transactions WHERE transaction_id=p_transaction_id AND status='Completed') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='E_FRAUD_TXN_NOT_FOUND_OR_NOT_COMPLETED';
  END IF;

  SELECT t.account_id,t.amount,t.channel,t.device_id,t.transaction_timestamp
    INTO v_account,v_amount,v_channel,v_device,v_txn_ts
    FROM Transactions t JOIN Accounts a ON a.account_id=t.account_id
   WHERE t.transaction_id=p_transaction_id;
  SET v_profile_risk=COALESCE((SELECT risk_score FROM Account_Risk_Profile WHERE account_id=v_account),0);
  SET v_trusted=COALESCE((SELECT d.is_trusted FROM Devices d WHERE d.device_id=v_device),FALSE);

  -- Use a stable transaction-local base. Account profile is used for the explicit risk rule only.
  SET v_score=fn_txn_risk_score(v_amount,v_channel,v_trusted,0);
  OPEN c_rules;
  rule_loop: LOOP
    FETCH c_rules INTO v_rule_id,v_code,v_weight,v_params;
    IF v_done=1 THEN LEAVE rule_loop; END IF;
    SET v_matches=FALSE;
    SET v_min_amount=COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(v_params,'$.minimum_amount')) AS DECIMAL(14,2)),5000);
    SET v_min_risk=COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(v_params,'$.minimum_risk')) AS DECIMAL(5,2)),60);
    SET v_window=COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(v_params,'$.window_minutes')) AS UNSIGNED),10);
    SET v_min_count=COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(v_params,'$.minimum_count')) AS UNSIGNED),3);

    IF v_code='HIGH_AMOUNT' THEN SET v_matches=(v_amount>=v_min_amount);
    ELSEIF v_code='UNTRUSTED_DEVICE' THEN SET v_matches=(v_device IS NULL OR v_trusted=FALSE);
    ELSEIF v_code='DIGITAL_CHANNEL' THEN SET v_matches=(v_channel IN ('Online','Mobile'));
    ELSEIF v_code='HIGH_ACCOUNT_RISK' THEN SET v_matches=(v_score>=v_min_risk);
    ELSEIF v_code='RAPID_ACTIVITY' THEN
      SET v_matches=(fn_txn_count_window(v_account,v_txn_ts,v_window)>=v_min_count);
    END IF;

    IF v_matches THEN
      SET v_score=LEAST(100,v_score+v_weight);
      INSERT INTO Fraud_Flags(transaction_id,rule_id,risk_score,evidence)
      VALUES(p_transaction_id,v_rule_id,v_score,
        JSON_OBJECT('rule_code',v_code,'amount',v_amount,'channel',v_channel,
                    'device_id',v_device,'device_trusted',v_trusted,
                    'account_profile_risk',v_profile_risk,'evaluated_transaction_timestamp',v_txn_ts))
      ON DUPLICATE KEY UPDATE risk_score=VALUES(risk_score),evidence=VALUES(evidence);
    END IF;
  END LOOP;
  CLOSE c_rules;

  INSERT INTO Account_Risk_Profile(account_id,risk_score,risk_level,last_evaluated_at)
  VALUES(v_account,v_score,fn_risk_level(v_score),NOW())
  ON DUPLICATE KEY UPDATE
    risk_score=GREATEST(Account_Risk_Profile.risk_score,VALUES(risk_score)),
    risk_level=fn_risk_level(GREATEST(Account_Risk_Profile.risk_score,VALUES(risk_score))),
    last_evaluated_at=VALUES(last_evaluated_at);
END$$
DELIMITER ;
