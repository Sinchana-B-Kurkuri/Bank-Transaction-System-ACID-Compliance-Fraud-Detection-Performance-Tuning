# Member A SPEC (single source of truth for Prompts 1–6)

## Ownership
A: Branches, Employees, Customers, Account_Types, Accounts, Transactions, Loans, Fraud_Flags, Audit_Log; bank_lab.Experiment_Log + test helpers; A procedures/functions/triggers listed below; EXP-01..10, 16, 17; backup/recovery.
B: Devices, Locations, Fraud_Rules, Account_Risk_Profile, DB_User_Map, Transaction_Approvals, Fraud_Ground_Truth, bank_lab.Benchmark_Results; fraud functions (fn_distance_km, fn_amount_zscore, fn_txn_count_window, fn_is_odd_hour, fn_account_age_days, fn_txn_risk_score, fn_risk_level), sp_evaluate_fraud, fraud trigger, views, RBAC, indexes, benchmarks, data generators, EXP-11..15.
File numbering: A schema/01_tables 01-09; B 10-16.
Database: bank_txn (scratch: bank_txn_scratch). utf8mb4. InnoDB. MySQL 8.x. No DB name hard-coded inside object files; run_all/rebuild select the DB. bank_lab is a fixed schema name.

## Decisions
D1 Approval: high-value request creates Transaction_Approvals row, moves no money; approve calls the transfer logic; reject closes request.
D2 Close: not allowed if balance<>0 or account is disbursement_account_id of an Active loan.
D3 Loan disbursement posted as a Deposit transaction.
D4 Business-rule rejections recorded as Failed rows inserted AFTER rollback in a separate small transaction.
D5 Audit coverage starts at trigger installation (watermark recorded in bank_lab.Experiment_Log event AUDIT_TRIGGERS_INSTALLED).
D6 p_lab_mode on sp_transfer_funds: 0 normal, 1 fail after debit, 2 sleep after debit, (A6) 3 sleep after debit AND naive lock order. Release build strips the hook.
D7 Fraud is detective (flag, do not block).
A1 db_session_user = USER() and actor resolution via sp_resolve_actor(USER()); never CURRENT_USER(). DB_User_Map.db_login stores the USER() string; fallback match on user part; unmapped => actor_type 'System'.
A2 Opening balance convention: every account gets an opening Deposit transaction (Completed) so that Accounts.balance = SUM(credits)-SUM(debits) over Completed rows. Credits: Deposit, TransferIn, InterestCredit. Debits: Withdrawal, TransferOut, Fee. Loaders must follow this.
A3 sp_close_account(p_settle_balance=1) posts a final Withdrawal of the whole balance then sets balance=0,status='Closed' in one UPDATE; guard allows NEW.balance=0 only when NEW.status='Closed'. Default 0 = D2 literal.
A4 fn_approval_threshold()=100000.00. sp_transfer_funds rejects amount>=threshold (5006). sp_decide_approval uses internal procedure.
A5 device_id/location_id are stored only on single-leg transactions and the DEBIT (TransferOut) leg; credit leg NULL; Failed rows NULL.
A6 see D6.
A7 Private procedures sp_internal_* have no transaction control; public procedures own START/COMMIT/ROLLBACK. Never grant sp_internal_* to roles. START TRANSACTION inside a procedure implicitly commits the caller's open transaction — design around it.
A8 Failed rows eligible only for errors 5003,5004,5005,5006,5010; transfer_group_id NULL; never for deadlock/timeout/lab errors.
A9 sp_generate_statement is A-owned (Guide), B must not duplicate.
A10 Error convention: SIGNAL SQLSTATE '45000', MYSQL_ERRNO per table below, MESSAGE_TEXT 'E_NAME: text' with no PII.
A11 sp_update_customer may not deactivate a customer who has a non-Closed account; inactive customers cannot open accounts.
A12 B-owned tables are stubbed only in tests/stubs/ for standalone builds; B's real files replace stubs.
A13 Baseline index set B0 = PK/UNIQUE/FK-required only. A adds NO secondary indexes.
A14 B's fraud AFTER INSERT trigger on Transactions must be created with FOLLOWS trg_transactions_ai_audit. Flags written by the trigger roll back with a failed transfer (accepted).
A15 Ledger rows are immutable (no UPDATE/DELETE). Bulk loaders must run BEFORE triggers are installed.
A16 Procedures are DEFINER with SQL SECURITY DEFINER. Tests use disposable DBs (rebuild first); procedures commit, so tests cannot rely on ROLLBACK.
A17 Customer-actor check: if sp_resolve_actor(USER()) = Customer, the debited account must belong to that customer (5010). If Employee, p_employee_id must be NULL or equal the resolved employee. System: no actor restriction. Channel 'Branch' requires an active Teller whose branch = account's branch (from-account for transfers); other channels require p_employee_id NULL.

## Error codes (MYSQL_ERRNO)
5001 E_INVALID_AMOUNT | 5002 E_ACCOUNT_NOT_FOUND | 5003 E_ACCOUNT_NOT_ACTIVE | 5004 E_INSUFFICIENT_FUNDS (includes min-balance) | 5005 E_SAME_ACCOUNT | 5006 E_APPROVAL_REQUIRED | 5007 E_INVALID_REFERENCE | 5008 E_CLOSE_BLOCKED | 5009 E_APPROVAL_STATE | 5010 E_NOT_AUTHORIZED | 5011 E_INVALID_TRANSITION | 5012 E_LEDGER_IMMUTABLE | 5013 E_AUDIT_IMMUTABLE | 5014 E_DEVICE_OWNER_MISMATCH | 5015 E_MINBAL_GUARD | 5016 E_LAB_INJECTED_FAILURE | 5017 E_LAB_MODE_FORBIDDEN | 5018 E_INVALID_ARGUMENT
Native codes to expect in tests: 1062 dup key, 3819 CHECK violated, 1452 FK child, 1451 FK parent, 1265/1366 bad enum/value, 1213 deadlock, 1205 lock wait timeout, 1142/1143/1370 privilege.

## Tables (types exact)
Branches(branch_id INT PK AI, branch_name VARCHAR(100) NN, ifsc_code VARCHAR(15) UNIQUE NN, address VARCHAR(200) NN, city VARCHAR(50) NN, state VARCHAR(50) NN, phone VARCHAR(20) NN)
Employees(employee_id INT PK AI, branch_id INT NN FK, full_name VARCHAR(100) NN, role ENUM('Teller','Manager','DBA') NN, email VARCHAR(100) UNIQUE NN, hire_date DATE NN, is_active BOOLEAN NN DEFAULT TRUE)
Customers(customer_id INT PK AI, full_name VARCHAR(100) NN, dob DATE NN, gender VARCHAR(15) NULL, email VARCHAR(100) UNIQUE NN, phone VARCHAR(20) UNIQUE NN, address VARCHAR(200) NN, id_proof_number VARCHAR(30) UNIQUE NN, id_proof_type ENUM('Aadhaar','PAN','Passport','DrivingLicense','VoterID') NN, kyc_status ENUM('Pending','Verified','Rejected') NN DEFAULT 'Pending', is_active BOOLEAN NN DEFAULT TRUE, created_at DATETIME NN DEFAULT CURRENT_TIMESTAMP)
Account_Types(account_type_id INT PK AI, type_name VARCHAR(30) UNIQUE NN, interest_rate DECIMAL(5,2) NN, min_balance DECIMAL(12,2) NN)
Accounts(account_id INT PK AI, customer_id INT NN FK, branch_id INT NN FK, account_type_id INT NN FK, account_number VARCHAR(20) UNIQUE NN, balance DECIMAL(14,2) NN CHECK(balance>=0), status ENUM('Active','Frozen','Closed') NN DEFAULT 'Active', opened_date DATE NN)
Transactions(transaction_id BIGINT PK AI, account_id INT NN FK, related_account_id INT NULL FK Accounts, employee_id INT NULL FK Employees, transfer_group_id CHAR(36) NULL, device_id INT NULL, location_id INT NULL, transaction_type ENUM('Deposit','Withdrawal','TransferIn','TransferOut','InterestCredit','Fee') NN, amount DECIMAL(14,2) NN CHECK(amount>0), balance_after DECIMAL(14,2) NN, channel ENUM('ATM','Branch','Online','Mobile') NN, status ENUM('Pending','Completed','Failed','RolledBack') NN, transaction_timestamp DATETIME NN DEFAULT CURRENT_TIMESTAMP, reference_no VARCHAR(30) UNIQUE NN, UNIQUE(transfer_group_id, transaction_type))
Loans(loan_id INT PK AI, customer_id INT NN FK Customers, disbursement_account_id INT NULL FK Accounts, principal_amount DECIMAL(14,2) NN CHECK>0, interest_rate DECIMAL(5,2) NN, tenure_months INT NN CHECK>0, status ENUM('Active','Closed','Defaulted') NN, disbursed_date DATE NN)
Fraud_Flags(flag_id INT PK AI, transaction_id BIGINT NN FK Transactions, rule_id INT NN FK Fraud_Rules(rule_id) [cross-module], risk_score DECIMAL(5,2) NN CHECK(risk_score BETWEEN 0 AND 100), evidence JSON NULL, flag_status ENUM('Open','UnderReview','Confirmed','Dismissed') NN DEFAULT 'Open', reviewed_by INT NULL FK Employees, created_at DATETIME NN DEFAULT CURRENT_TIMESTAMP, UNIQUE(transaction_id, rule_id))
Audit_Log(audit_id BIGINT PK AI, table_name VARCHAR(50) NN, record_pk VARCHAR(50) NN, action_type ENUM('INSERT','UPDATE','DELETE') NN, old_value JSON NULL, new_value JSON NULL, db_session_user VARCHAR(100) NN, actor_type ENUM('Customer','Employee','System') NN, actor_employee_id INT NULL FK Employees, actor_customer_id INT NULL FK Customers, performed_at DATETIME NN DEFAULT CURRENT_TIMESTAMP, CHECK((actor_type='Employee' AND actor_employee_id IS NOT NULL AND actor_customer_id IS NULL) OR (actor_type='Customer' AND actor_customer_id IS NOT NULL AND actor_employee_id IS NULL) OR (actor_type='System' AND actor_employee_id IS NULL AND actor_customer_id IS NULL)))
All FKs ON DELETE RESTRICT ON UPDATE RESTRICT. No Audit_Log FK on table_name/record_pk. Name constraints: pk_, uq_, chk_, fk_<child>_<col>.
Transactions.device_id/location_id FKs (to Devices/Locations) live ONLY in schema/02_constraints/02_cross_module_fks.sql as fk_transactions_device / fk_transactions_location; Fraud_Flags.rule_id FK as fk_fraud_flags_rule. That file applies each FK only if (a) the referenced table exists and (b) the constraint is not already present, using information_schema + PREPARE; idempotent.

## B tables A depends on (contract; stub columns)
Devices(device_id INT PK AI, customer_id INT NN FK, device_fingerprint CHAR(64) UNIQUE NN, device_type VARCHAR(20) NN, first_seen_at DATETIME NN, last_seen_at DATETIME NN, is_trusted BOOLEAN NN DEFAULT FALSE)
Locations(location_id INT PK AI, city VARCHAR(50) NN, state VARCHAR(50), country VARCHAR(50) NN, latitude DECIMAL(9,6) NN, longitude DECIMAL(9,6) NN)
Fraud_Rules(rule_id INT PK AI, rule_code VARCHAR(40) UNIQUE NN, description VARCHAR(200), weight DECIMAL(5,2) NN, param_json JSON, is_active BOOLEAN NN DEFAULT TRUE)
DB_User_Map(db_login VARCHAR(100) PK, actor_type ENUM('Customer','Employee') NN, employee_id INT NULL FK, customer_id INT NULL FK; exactly one FK set)
Transaction_Approvals(approval_id INT PK AI, requested_by_actor_type ENUM('Customer','Employee') NN, requested_by_employee_id INT NULL, requested_by_customer_id INT NULL, requested_at DATETIME NN DEFAULT CURRENT_TIMESTAMP, from_account_id INT NN FK, to_account_id INT NN FK, amount DECIMAL(14,2) NN CHECK>0, status ENUM('Requested','Approved','Rejected') NN DEFAULT 'Requested', decided_by INT NULL FK Employees, decided_at DATETIME NULL, resulting_transfer_group_id CHAR(36) NULL)  [ASSUMED from Blueprint S6 outline; B to confirm]
Fraud_Ground_Truth(transaction_id BIGINT PK FK Transactions, is_fraud BOOLEAN NN, scenario_label VARCHAR(40))

## Public procedures (signatures)
sp_register_customer(IN p_full_name VARCHAR(100), IN p_dob DATE, IN p_gender VARCHAR(15), IN p_email VARCHAR(100), IN p_phone VARCHAR(20), IN p_address VARCHAR(200), IN p_id_proof_number VARCHAR(30), IN p_id_proof_type VARCHAR(20), OUT p_customer_id INT)
sp_update_customer(IN p_customer_id INT, IN p_full_name VARCHAR(100), IN p_address VARCHAR(200), IN p_email VARCHAR(100), IN p_phone VARCHAR(20), IN p_kyc_status VARCHAR(10), IN p_is_active TINYINT)  -- NULL = unchanged
sp_open_account(IN p_customer_id INT, IN p_branch_id INT, IN p_account_type_id INT, IN p_initial_deposit DECIMAL(14,2), IN p_employee_id INT, IN p_account_number VARCHAR(20), OUT p_account_id INT, OUT p_account_number_out VARCHAR(20))
sp_close_account(IN p_account_id INT, IN p_employee_id INT, IN p_settle_balance TINYINT)
sp_set_account_status(IN p_account_id INT, IN p_new_status VARCHAR(10), IN p_employee_id INT)  -- Active<->Frozen only
sp_deposit / sp_withdraw(IN p_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, OUT p_transaction_id BIGINT, OUT p_balance_after DECIMAL(14,2))
sp_transfer_funds(IN p_from_account_id INT, IN p_to_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, IN p_lab_mode TINYINT, OUT p_transfer_group_id CHAR(36), OUT p_debit_txn_id BIGINT, OUT p_credit_txn_id BIGINT)
sp_transfer_funds_retry(same IN list + IN p_max_retries INT, same OUT list + OUT p_attempts INT)
sp_request_approval(IN p_from_account_id INT, IN p_to_account_id INT, IN p_amount DECIMAL(14,2), IN p_requested_by_employee_id INT, IN p_requested_by_customer_id INT, OUT p_approval_id INT)
sp_decide_approval(IN p_approval_id INT, IN p_decision VARCHAR(10), IN p_manager_employee_id INT, OUT p_transfer_group_id CHAR(36))
sp_disburse_loan(IN p_customer_id INT, IN p_disbursement_account_id INT, IN p_principal DECIMAL(14,2), IN p_interest_rate DECIMAL(5,2), IN p_tenure_months INT, IN p_employee_id INT, OUT p_loan_id INT)
sp_review_fraud_flag(IN p_flag_id INT, IN p_new_status VARCHAR(12), IN p_manager_employee_id INT)
sp_generate_statement(IN p_account_id INT, IN p_from DATE, IN p_to DATE)
sp_resolve_actor(IN p_db_login VARCHAR(100), OUT p_actor_type VARCHAR(10), OUT p_employee_id INT, OUT p_customer_id INT)
sp_reconcile_balances(IN p_account_id INT)  -- NULL = all
sp_post_monthly_interest(IN p_period_start DATE, IN p_employee_id INT, OUT p_accounts_credited INT, OUT p_total_interest DECIMAL(16,2))
Private: sp_internal_post_transfer, sp_internal_record_failed (and similar). Lab-only (experiments/lab_objects): sp_transfer_naive, lab_* helpers.

## Functions (A)
fn_get_balance, fn_available_balance, fn_calc_interest, fn_generate_reference, fn_mask_id_proof, fn_approval_threshold. Declare READS SQL DATA / DETERMINISTIC correctly (binlog on).

## Triggers (A) names
Audit: trg_{accounts,transactions,loans}_{ai,au,ad}_audit. Guards: trg_accounts_bu_minbal_guard, trg_transactions_bu_immutable, trg_transactions_bd_immutable, trg_audit_log_bu_immutable, trg_audit_log_bd_immutable, trg_transactions_bi_device_owner.

## Invariants
I1 Accounts.balance = SUM(credits)-SUM(debits) over Completed rows (per account and in total).
I2 every non-NULL transfer_group_id has exactly 2 Completed rows: one TransferOut one TransferIn, equal amount, mirrored account/related_account.
I3 balance>=0 and (status='Closed' OR balance>=Account_Types.min_balance).
I4 audit completeness since watermark: every Transactions/Loans/Accounts row created after install has an INSERT audit row; for accounts changed since install the newest UPDATE audit new_value balance equals Accounts.balance.
I5 for each account with Completed rows, the newest Completed row's balance_after = Accounts.balance.
