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

## Prompt 2 — functions, actor resolution, and trigger contracts

The following objects are installed by both build lists, after core/B tables and FKs. The frozen schema and SPEC signatures are unchanged; no migration is needed.

| Function | Signature / return | Behavior |
|---|---|---|
| fn_get_balance | (p_account_id INT) RETURNS DECIMAL(14,2) | Stored balance in any status; NULL for NULL/missing account |
| fn_available_balance | (p_account_id INT) RETURNS DECIMAL(14,2) | Active: GREATEST(balance-min_balance,0); otherwise 0.00 |
| fn_calc_interest | (p_account_id INT) RETURNS DECIMAL(14,2) | Active: ROUND(balance*type interest_rate/100/12,2); otherwise 0.00 |
| fn_generate_reference | () RETURNS VARCHAR(30) | 28 characters: T + 20 timestamp digits including six microseconds + hyphen + six uppercase base36 characters |
| fn_mask_id_proof | (p_id_proof VARCHAR(30)) RETURNS VARCHAR(30) | NULL-safe; keeps last four characters; shorter values unchanged; uses character length |
| fn_approval_threshold | () RETURNS DECIMAL(14,2) | 100000.00 |

The first four are NOT DETERMINISTIC / READS SQL DATA; mask and threshold are DETERMINISTIC / NO SQL. All use SQL SECURITY DEFINER. Reference generation combines NOW(6) with a six-character base36 residue of UUID_SHORT(); the 1000-call test includes one statement with a shared timestamp. It is not a cryptographic identifier. The unique reference_no constraint remains the definitive duplicate guard.

sp_resolve_actor retains its SPEC signature and performs no transaction control or result-set emission. Matching is case-sensitive: exact full login first, then an explicit bare-user key, then host-specific rows with the same user part. Multiple matching rows that agree on actor/ids are accepted; conflicting fallback identities return System with NULL ids. Exact full-login mappings always win. NULL/unmapped logins resolve to System. No schema or B table contract changes are required.

The six guards enforce: below-minimum balance decreases/zero without simultaneous closure (5015), balance/status changes on already Closed accounts (5011), ledger UPDATE/DELETE (5012), audit UPDATE/DELETE (5013), device ownership mismatch (5014), and self-counterparty (5005). An absent device/account reference is left to the FK (1452). Balance increases below the minimum are permitted; settlement must set balance=0 and status=Closed together. These are UPDATE guards, not a replacement for later account-opening procedures or loader validation.

The nine audit triggers serialize all 8 Accounts, 14 Transactions, and 8 Loans columns into old/new JSON snapshots. They call sp_resolve_actor(USER(),...) into local variables; Audit_Log.db_session_user is always USER(). INSERT old_value and DELETE new_value are SQL NULL. Transactions AFTER UPDATE/DELETE audit triggers remain installed as specified but cannot be reached while ledger immutability guards are installed. No trigger commits or rolls back; audit rows roll back with their originating statement/transaction. The install script records DATABASE()-scoped maxima and installed_at in bank_lab.Experiment_Log. Reinstallation records a new watermark; it cannot retroactively audit changes made while auditing was disabled.

### EXP-13 / EXP-17 audit toggles

From the repository root, use the fail-fast wrapper (or a client configured to stop on SQL errors):

```powershell
. ./build/mysql_common.ps1
Invoke-BankMysql -Database bank_txn_scratch -Sql 'source triggers/lab/drop_audit_triggers.sql'
Invoke-BankMysql -Database bank_txn_scratch -Sql 'source triggers/lab/create_audit_triggers.sql'
```

Each script validates the selected database before any trigger DDL. The default is scratch only; another selected database requires `SET @allow_trigger_toggle=1;` in the SAME client session before SOURCE. It is not a persistent setting. Validation uses a disposable bank_lab procedure, which is dropped after a successful check; a denied invocation can leave that harmless validator until the next invocation. Neither script touches guards or B triggers. Create drops/recreates A's nine audits and records a fresh watermark.

A14 remains mandatory: B's fraud AFTER INSERT trigger must be created with FOLLOWS trg_transactions_ai_audit. The toggle validator rejects an existing dependent Transactions AFTER INSERT trigger (5017) to prevent silently reversing ordering when auditing is recreated. B must manage its own fraud trigger lifecycle around EXP-13 and reinstall it with FOLLOWS after A's audits are restored. No B code is edited by these scripts.

### Reference loaders and regression tests

Build order is bank_lab, tables, constraints, functions, resolver, guards, audits, watermark, reference data. Natural-key reference data is always included; -WithSeed additionally runs all data/seed/NN_*.sql loaders in numeric order (the reference script may run again safely). Branch assignments resolve synthetic IFSC keys, not assumed auto-increment ids. No B-owned reference rows are seeded.

The unchanged Prompt 1 native-constraint fixture contains three Transactions UPDATE-to-NULL checks. The runner temporarily removes ONLY trg_transactions_bu_immutable around that fixture and restores it in finally, allowing the existing 1048 assertions to continue testing native column constraints. Guard tests then separately require every ledger UPDATE/DELETE to raise 5012. Tests require disposable databases and an unmapped administrative login.

The restricted-login attribution test creates only reserved zz_a_teller_test / zz_a_customer_test users after confirming they do not already exist. Random passwords stay in memory and the child MYSQL_PWD environment; no password is written to disk or arguments. Grants are Accounts SELECT(account_id,balance)/UPDATE(balance) plus EXECUTE on a temporary identity probe. Exact USER() strings are calibrated from each session, and the probe demonstrates that CURRENT_USER() in the matching definer context is different. Users, maps, and the probe are removed in finally. Synthetic actor fixtures remain in the disposable schema because immutable audit rows reference them; a subsequent rebuild removes them. The test requires CREATE USER, GRANT, routine DDL, and administrative fixture privileges; inability to obtain them is a reported failure/blocker, never a claimed pass.

The persistent actor fixture includes an opening Completed Deposit and one matching Deposit for each of its four test credits. Its final balance and latest balance_after are explicitly reconciled, so it does not leave an inconsistent ledger for later invariant tests.

## Prompt 3 — public transaction engine

All sixteen new public procedure signatures exactly match SPEC; sp_resolve_actor and the Prompt 1/2 schemas/functions/triggers remain unchanged. See procedures/README.md for the installed public list, dependency order and private helper argument contracts. No schema migration or B table alteration is required.

Only public procedures may be granted to application roles. sp_internal_post_transfer, sp_internal_post_single, sp_internal_insert_ledger, sp_internal_record_failed, sp_internal_authorize and sp_internal_assert_staff are non-public DEFINER helpers; never grant them. They do not control transactions. Public mutations own transactions, approvals use the private transfer inside their own transaction, and retry invokes a complete public transaction for each attempt. Caller transactions must not be expected to survive a public START TRANSACTION. OUT values are reliable only after a successful CALL; exhaustion details remain in bank_lab.Experiment_Log.

A17 applies to ordinary postings: Customer debit ownership, resolved Employee identity, active same-branch Teller for Branch, NULL employee for other channels. The explicitly required approval Manager and monthly-interest Manager/DBA paths are confined administrative exceptions, not permission to call an ordinary Branch deposit/withdraw/transfer as a Manager. Approval requesters must be mapped to exactly one Customer/Employee matching the supplied ids; same-branch Teller/Manager Employee requests are supported. Status changes use active same-branch Teller/Manager. Approval decisions require the from-account branch Manager and reject self-approval.

D4/A8 Failed logging occurs only after rollback, in a separate small transaction owned by the public handler. The private recorder has no transaction control and omits all metadata that could fail device/location or transfer-group rules. Only 5003/5004/5005/5006/5010 are eligible; nonexistent/rolled-back accounts and invalid amounts are skipped. An inner logging error cannot mask the original rejection. Native 1213/1205 and 5016/5017 do not create Failed rows. Both transfer legs are Completed together, with device/location only on the debit leg.

Retry accepts any positive p_max_retries (NULL means five attempts), retries only 1213/1205, records DEADLOCK_RETRY or LOCKWAIT_RETRY after rollback, and raises SQLSTATE 40001 / errno 1213 with E_RETRY_EXHAUSTED when exhausted. Its event detail includes from_account, to_account and attempt. No private helper is used as a nested public transaction.

sp_generate_statement has two result sets: account_id/period_start/opening_balance; then transaction_id/timestamp/type/amount/balance_after/related_account_id/reference_no/running_balance. Its [from,to] interval is inclusive and limited to 366 days. sp_reconcile_balances has summaries invariant/violations/status/checked_at, then up to 100 offender rows invariant/account_id/record_pk/detail. The six invariant ids are I1, I1b, I2, I3, I4, I5; I2/I4 remain global with an account filter. @reconcile_results is a session-only JSON copy of the summaries, not a third result set or persistent schema object.

Monthly interest locks/commits each Active Savings account independently. Period labels use the first day of the supplied month, while transaction_timestamp remains the actual posting time. The existing A-owned Experiment_Log receives MONTHLY_INTEREST_POSTED (exp_id INTEREST) inside the same transaction, with account_id, period_start, generated reference_no and transaction_id. A matching reference/period marker establishes idempotency; an unmarked legacy credit uses its transaction timestamp month. Reference linkage prevents old bank_lab records from suppressing credits after a database rebuild. This is necessary for date-filtered statement running balances to stay correct after historical-period processing. The calculation uses the current locked balance/rate; it does not reconstruct a historical balance. NULL/zero/failed credits are skipped or rolled back as appropriate, and @interest_errors reports per-account failures.

The tiny loader uses public APIs, fixed SEED-0001..0008 account numbers and synthetic customer email/id keys. Every opening and routed loan has a Completed Deposit. It checks existing successful operation rows before posting its ten demonstration operations, so repeated complete or partially completed loads do not duplicate those operations. Both build lists include it; -WithSeed can safely run it again.

Release generation writes only build/release/procedures (gitignored), preserves both transfer signatures, removes sleep/injection/naive-lock code, and rejects nonzero lab mode with 5017. Verification loads those objects only into scratch and then rebuilds scratch back to development objects. B interface-contract tests reuse the existing six-table contract unchanged; integrated validation awaits B's real files.
