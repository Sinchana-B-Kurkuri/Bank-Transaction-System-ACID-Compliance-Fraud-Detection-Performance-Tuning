-- Run from repository root through build/rebuild.ps1 (fail-fast UTF-8 batch).
SET SESSION sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SOURCE schema/04_lab/01_bank_lab.sql;
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
-- SOURCE schema/04_lab/02_benchmark_results.sql; -- Optional B-owned file when supplied.
SOURCE functions/fn_approval_threshold.sql;
SOURCE functions/fn_available_balance.sql;
SOURCE functions/fn_calc_interest.sql;
SOURCE functions/fn_generate_reference.sql;
SOURCE functions/fn_get_balance.sql;
SOURCE functions/fn_mask_id_proof.sql;
SOURCE procedures/sp_resolve_actor.sql;
SOURCE triggers/guards/trg_accounts_bu_minbal_guard.sql;
SOURCE triggers/guards/trg_audit_log_bd_immutable.sql;
SOURCE triggers/guards/trg_audit_log_bu_immutable.sql;
SOURCE triggers/guards/trg_transactions_bd_immutable.sql;
SOURCE triggers/guards/trg_transactions_bi_device_owner.sql;
SOURCE triggers/guards/trg_transactions_bu_immutable.sql;
SOURCE triggers/audit/trg_accounts_ad_audit.sql;
SOURCE triggers/audit/trg_accounts_ai_audit.sql;
SOURCE triggers/audit/trg_accounts_au_audit.sql;
SOURCE triggers/audit/trg_loans_ad_audit.sql;
SOURCE triggers/audit/trg_loans_ai_audit.sql;
SOURCE triggers/audit/trg_loans_au_audit.sql;
SOURCE triggers/audit/trg_transactions_ad_audit.sql;
SOURCE triggers/audit/trg_transactions_ai_audit.sql;
SOURCE triggers/audit/trg_transactions_au_audit.sql;
SOURCE triggers/99_record_audit_install.sql;
SOURCE data/seed/01_reference_data.sql;
