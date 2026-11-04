-- Stable transaction-local heuristic. Account profile is an input snapshot; callers must
-- not feed the score written by this same evaluation back as its own input.
DELIMITER $$
CREATE FUNCTION fn_txn_risk_score(p_amount DECIMAL(14,2), p_channel VARCHAR(10),
                                  p_device_trusted BOOLEAN, p_account_risk DECIMAL(5,2))
RETURNS DECIMAL(5,2)
DETERMINISTIC NO SQL
BEGIN
  DECLARE v_score DECIMAL(7,2) DEFAULT 0;
  IF p_amount >= 10000 THEN SET v_score=v_score+35;
  ELSEIF p_amount >= 5000 THEN SET v_score=v_score+20;
  END IF;
  IF p_channel IN ('Online','Mobile') THEN SET v_score=v_score+10; END IF;
  IF p_device_trusted=FALSE OR p_device_trusted IS NULL THEN SET v_score=v_score+20; END IF;
  SET v_score=v_score+LEAST(35,GREATEST(0,COALESCE(p_account_risk,0)*0.35));
  RETURN LEAST(100,GREATEST(0,v_score));
END$$
DELIMITER ;
