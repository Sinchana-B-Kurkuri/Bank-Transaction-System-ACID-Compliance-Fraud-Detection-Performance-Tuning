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
SOURCE tests/stubs/member_b_interface_stubs.sql;
SOURCE schema/02_constraints/02_cross_module_fks.sql;
SOURCE schema/04_lab/01_bank_lab.sql;
-- SOURCE schema/04_lab/02_benchmark_results.sql; -- Optional B-owned file when supplied.
