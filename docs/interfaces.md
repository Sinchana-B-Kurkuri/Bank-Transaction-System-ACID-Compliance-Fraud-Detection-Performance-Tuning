# Interfaces

## Member A public interface

IMPLEMENTED: table and test infrastructure. Procedure signatures below are contracts for Prompts 2–6; business routines are not installed by Prompt 1.

### Public procedure signatures

```text
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
```

The retry and single-leg signatures expanded for callers:

```text
sp_deposit(IN p_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, OUT p_transaction_id BIGINT, OUT p_balance_after DECIMAL(14,2))
sp_withdraw(IN p_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, OUT p_transaction_id BIGINT, OUT p_balance_after DECIMAL(14,2))
sp_transfer_funds_retry(IN p_from_account_id INT, IN p_to_account_id INT, IN p_amount DECIMAL(14,2), IN p_channel VARCHAR(10), IN p_employee_id INT, IN p_device_id INT, IN p_location_id INT, IN p_lab_mode TINYINT, IN p_max_retries INT, OUT p_transfer_group_id CHAR(36), OUT p_debit_txn_id BIGINT, OUT p_credit_txn_id BIGINT, OUT p_attempts INT)
```

### Tables A reads from B

Devices(device_id INT PK AI, customer_id INT NN FK, device_fingerprint CHAR(64) UNIQUE NN, device_type VARCHAR(20) NN, first_seen_at DATETIME NN, last_seen_at DATETIME NN, is_trusted BOOLEAN NN DEFAULT FALSE)
Locations(location_id INT PK AI, city VARCHAR(50) NN, state VARCHAR(50), country VARCHAR(50) NN, latitude DECIMAL(9,6) NN, longitude DECIMAL(9,6) NN)
Fraud_Rules(rule_id INT PK AI, rule_code VARCHAR(40) UNIQUE NN, description VARCHAR(200), weight DECIMAL(5,2) NN, param_json JSON, is_active BOOLEAN NN DEFAULT TRUE)
DB_User_Map(db_login VARCHAR(100) PK, actor_type ENUM('Customer','Employee') NN, employee_id INT NULL FK, customer_id INT NULL FK; exactly one FK set)
Transaction_Approvals(approval_id INT PK AI, requested_by_actor_type ENUM('Customer','Employee') NN, requested_by_employee_id INT NULL, requested_by_customer_id INT NULL, requested_at DATETIME NN DEFAULT CURRENT_TIMESTAMP, from_account_id INT NN FK, to_account_id INT NN FK, amount DECIMAL(14,2) NN CHECK>0, status ENUM('Requested','Approved','Rejected') NN DEFAULT 'Requested', decided_by INT NULL FK Employees, decided_at DATETIME NULL, resulting_transfer_group_id CHAR(36) NULL)  [ASSUMED from Blueprint S6 outline; B to confirm]
Fraud_Ground_Truth(transaction_id BIGINT PK FK Transactions, is_fraud BOOLEAN NN, scenario_label VARCHAR(40))

Every FK uses ON DELETE RESTRICT ON UPDATE RESTRICT. Transaction_Approvals is assumed from Blueprint S6 and requires B confirmation. Only tests/stubs supplies stand-ins; integrated builds must use B definitions. The contract test names every missing or mismatched column.

### Trigger ordering

B creates its Transactions AFTER INSERT fraud trigger with FOLLOWS trg_transactions_ai_audit, after A installs that trigger. Fraud flags roll back with the transaction. Record AUDIT_TRIGGERS_INSTALLED in bank_lab.Experiment_Log when audit triggers are installed. This foundation does not falsely record an installation watermark.

### Opening-deposit loader contract

Bulk loaders run before guards and immutable/audit triggers. Every account receives a Completed Deposit opening row whose amount and balance_after equal its initial balance; positive amounts are required. A zero initial balance therefore needs a positive opening deposit policy or an explicitly agreed spec amendment before a zero-opening loader is implemented. Credits: Deposit, TransferIn, InterestCredit; debits: Withdrawal, TransferOut, Fee. Devices/locations appear only on single-leg or debit legs, never credit/Failed rows. Loaders must reconcile balances, use synthetic ID proofs, and respect FKs.

### Error-code table

| MYSQL_ERRNO | Name / meaning |
|---|---|
| 5001 | E_INVALID_AMOUNT |
| 5002 | E_ACCOUNT_NOT_FOUND |
| 5003 | E_ACCOUNT_NOT_ACTIVE |
| 5004 | E_INSUFFICIENT_FUNDS (includes min-balance) |
| 5005 | E_SAME_ACCOUNT |
| 5006 | E_APPROVAL_REQUIRED |
| 5007 | E_INVALID_REFERENCE |
| 5008 | E_CLOSE_BLOCKED |
| 5009 | E_APPROVAL_STATE |
| 5010 | E_NOT_AUTHORIZED |
| 5011 | E_INVALID_TRANSITION |
| 5012 | E_LEDGER_IMMUTABLE |
| 5013 | E_AUDIT_IMMUTABLE |
| 5014 | E_DEVICE_OWNER_MISMATCH |
| 5015 | E_MINBAL_GUARD |
| 5016 | E_LAB_INJECTED_FAILURE |
| 5017 | E_LAB_MODE_FORBIDDEN |
| 5018 | E_INVALID_ARGUMENT |

Native codes to expect in tests: 1062 dup key, 3819 CHECK violated, 1452 FK child, 1451 FK parent, 1265/1366 bad enum/value, 1213 deadlock, 1205 lock wait timeout, 1142/1143/1370 privilege.

Use SIGNAL SQLSTATE '45000' and MESSAGE_TEXT 'E_NAME: text' without PII. Failed rows are allowed only for 5003, 5004, 5005, 5006 and 5010 after rollback, in a separate transaction; no transfer group or device/location metadata.

### Actor and transaction ownership

Resolve USER() through DB_User_Map, exact login then user-part fallback; unmapped means System. Public routines own transactions and use SQL SECURITY DEFINER; private sp_internal_* routines have no transaction control and receive no role grants. See SPEC A17 for customer debit ownership, employee identity, and Branch Teller restrictions.
