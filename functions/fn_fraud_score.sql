DELIMITER $$

DROP FUNCTION IF EXISTS fn_fraud_score$$

CREATE FUNCTION fn_fraud_score(
    p_amount DECIMAL(14,2),
    p_channel VARCHAR(10),
    p_device_trusted BOOLEAN,
    p_account_risk DECIMAL(5,2)
)
RETURNS DECIMAL(5,2)
NO SQL
DETERMINISTIC
-- Compatibility entry point. The approved transaction heuristic has one definition.
RETURN fn_txn_risk_score(p_amount,p_channel,p_device_trusted,p_account_risk)$$

DELIMITER ;
