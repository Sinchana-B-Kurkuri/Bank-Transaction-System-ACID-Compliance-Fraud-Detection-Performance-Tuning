-- Query-pattern indexes. Validate with EXPLAIN and workload benchmarks before production rollout.
CREATE INDEX idx_transactions_account_time
  ON Transactions(account_id, transaction_timestamp, transaction_id);
CREATE INDEX idx_transactions_status_time
  ON Transactions(status, transaction_timestamp);
CREATE INDEX idx_fraud_flags_status_score
  ON Fraud_Flags(flag_status, risk_score, created_at);
CREATE INDEX idx_fraud_flags_rule_created
  ON Fraud_Flags(rule_id, created_at);
CREATE INDEX idx_approvals_status_requested
  ON Transaction_Approvals(status, requested_at);
CREATE INDEX idx_audit_log_table_time
  ON Audit_Log(table_name, performed_at);
CREATE INDEX idx_devices_customer_trusted
  ON Devices(customer_id, is_trusted);
