-- Capture baseline plans before indexes, then rerun after indexes are installed.
-- MySQL 8.0.18+: EXPLAIN ANALYZE executes the SELECT; use only on a safe test database.
EXPLAIN SELECT transaction_id,amount,status,transaction_timestamp
FROM Transactions
WHERE account_id=1
  AND transaction_timestamp >= CURRENT_DATE - INTERVAL 30 DAY
ORDER BY transaction_timestamp DESC;

EXPLAIN SELECT flag_id,transaction_id,risk_score,created_at
FROM Fraud_Flags
WHERE flag_status IN ('Open','UnderReview')
ORDER BY risk_score DESC,created_at DESC;

EXPLAIN SELECT approval_id,from_account_id,to_account_id,amount,requested_at
FROM Transaction_Approvals
WHERE status='Requested'
ORDER BY requested_at;

-- Optional runtime measurement on a disposable database:
-- EXPLAIN ANALYZE SELECT ... (repeat the same predicates before/after indexing)
