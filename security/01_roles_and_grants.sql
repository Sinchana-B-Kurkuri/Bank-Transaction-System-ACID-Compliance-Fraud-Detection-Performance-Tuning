-- Run as a database administrator after the views are installed.
-- Roles are intentionally narrow. Create application users separately and grant these roles.
CREATE ROLE IF NOT EXISTS 'bank_customer_role';
CREATE ROLE IF NOT EXISTS 'bank_teller_role';
CREATE ROLE IF NOT EXISTS 'bank_manager_role';
CREATE ROLE IF NOT EXISTS 'bank_auditor_role';

GRANT SELECT ON bank_txn.v_customer_account_summary TO 'bank_customer_role';
GRANT SELECT ON bank_txn.v_transaction_activity TO 'bank_customer_role';
GRANT SELECT ON bank_txn.v_transaction_activity TO 'bank_teller_role';
GRANT SELECT ON bank_txn.v_fraud_case_queue TO 'bank_manager_role';
GRANT SELECT ON bank_txn.v_customer_account_summary TO 'bank_manager_role';
GRANT SELECT ON bank_txn.v_transaction_activity TO 'bank_manager_role';
GRANT SELECT ON bank_txn.v_fraud_case_queue TO 'bank_auditor_role';
GRANT SELECT ON bank_txn.v_transaction_activity TO 'bank_auditor_role';
GRANT SELECT ON bank_txn.Audit_Log TO 'bank_auditor_role';

-- Do not grant roles to broad accounts automatically. Provision named users explicitly:
-- GRANT 'bank_customer_role' TO 'app_customer'@'localhost';
-- SET DEFAULT ROLE 'bank_customer_role' TO 'app_customer'@'localhost';
-- Apply least-privilege grants to actual app users after reviewing the deployment topology.
