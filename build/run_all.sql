-- Run from repository root with mysql --database=<allowed-db> --abort-source-on-error.
SET SESSION sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SOURCE schema/01_tables/01_branches.sql;
SOURCE schema/01_tables/02_employees.sql;
SOURCE schema/01_tables/03_customers.sql;
SOURCE schema/01_tables/04_account_types.sql;
SOURCE schema/01_tables/05_accounts.sql;
SOURCE schema/01_tables/06_transactions.sql;
SOURCE schema/01_tables/07_loans.sql;
SOURCE schema/01_tables/08_fraud_flags.sql;
SOURCE schema/01_tables/09_audit_log.sql;
SOURCE schema/02_constraints/01_core_constraints.sql;
-- B 10_devices.sql: add SOURCE when supplied.
-- B 11_locations.sql: add SOURCE when supplied.
-- B 12_fraud_rules.sql: add SOURCE when supplied.
-- B 13_account_risk_profile.sql: add SOURCE when supplied.
-- B 14_db_user_map.sql: add SOURCE when supplied.
-- B 15_transaction_approvals.sql: add SOURCE when supplied.
-- B 16_fraud_ground_truth.sql: add SOURCE when supplied.
SOURCE schema/02_constraints/02_cross_module_fks.sql;
SOURCE schema/04_lab/01_bank_lab.sql;
-- SOURCE schema/04_lab/02_benchmark_results.sql; -- Optional B-owned file when supplied.
