CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_fraud_case_queue AS
SELECT f.flag_id,f.transaction_id,f.rule_id,r.rule_code,r.description,
       f.risk_score,f.flag_status,f.created_at,f.reviewed_by,
       t.account_id,t.amount,t.channel,t.transaction_timestamp
FROM Fraud_Flags f JOIN Fraud_Rules r ON r.rule_id=f.rule_id
JOIN Transactions t ON t.transaction_id=f.transaction_id
WHERE f.flag_status IN ('Open','UnderReview');
