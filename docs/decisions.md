# Decisions

## 2026-10-18 — Member A foundation

### D1 — 2026-10-18 — owner: Member A

D1 Approval: high-value request creates Transaction_Approvals row, moves no money; approve calls the transfer logic; reject closes request.

Reason: Separate authorization from money movement.

### D2 — 2026-10-18 — owner: Member A

D2 Close: not allowed if balance<>0 or account is disbursement_account_id of an Active loan.

Reason: Prevent stranded balances and active-loan references.

### D3 — 2026-10-18 — owner: Member A

D3 Loan disbursement posted as a Deposit transaction.

Reason: Keep loan proceeds in the account ledger.

### D4 — 2026-10-18 — owner: Member A

D4 Business-rule rejections recorded as Failed rows inserted AFTER rollback in a separate small transaction.

Reason: Preserve rejection evidence outside rolled-back work.

### D5 — 2026-10-18 — owner: Member A

D5 Audit coverage starts at trigger installation (watermark recorded in bank_lab.Experiment_Log event AUDIT_TRIGGERS_INSTALLED).

Reason: Define an auditable coverage boundary.

### D6 — 2026-10-18 — owner: Member A

D6 p_lab_mode on sp_transfer_funds: 0 normal, 1 fail after debit, 2 sleep after debit, (A6) 3 sleep after debit AND naive lock order. Release build strips the hook.

Reason: Make failure and concurrency experiments reproducible.

### D7 — 2026-10-18 — owner: Member A

D7 Fraud is detective (flag, do not block).

Reason: Preserve detective fraud semantics.

### A1 — 2026-10-18 — owner: Member A

A1 db_session_user = USER() and actor resolution via sp_resolve_actor(USER()); never CURRENT_USER(). DB_User_Map.db_login stores the USER() string; fallback match on user part; unmapped => actor_type 'System'.

Reason: Attribute the actual connecting session.

### A2 — 2026-10-18 — owner: Member A

A2 Opening balance convention: every account gets an opening Deposit transaction (Completed) so that Accounts.balance = SUM(credits)-SUM(debits) over Completed rows. Credits: Deposit, TransferIn, InterestCredit. Debits: Withdrawal, TransferOut, Fee. Loaders must follow this.

Reason: Make ledger reconciliation exact from opening.

### A3 — 2026-10-18 — owner: Member A

A3 sp_close_account(p_settle_balance=1) posts a final Withdrawal of the whole balance then sets balance=0,status='Closed' in one UPDATE; guard allows NEW.balance=0 only when NEW.status='Closed'. Default 0 = D2 literal.

Reason: Settle and close atomically under the guard.

### A4 — 2026-10-18 — owner: Member A

A4 fn_approval_threshold()=100000.00. sp_transfer_funds rejects amount>=threshold (5006). sp_decide_approval uses internal procedure.

Reason: Use one high-value boundary.

### A5 — 2026-10-18 — owner: Member A

A5 device_id/location_id are stored only on single-leg transactions and the DEBIT (TransferOut) leg; credit leg NULL; Failed rows NULL.

Reason: Attach context only to the originating transaction.

### A6 — 2026-10-18 — owner: Member A

A6 see D6.

Reason: Support the naive-lock-order experiment.

### A7 — 2026-10-18 — owner: Member A

A7 Private procedures sp_internal_* have no transaction control; public procedures own START/COMMIT/ROLLBACK. Never grant sp_internal_* to roles. START TRANSACTION inside a procedure implicitly commits the caller's open transaction — design around it.

Reason: Make transaction ownership explicit.

### A8 — 2026-10-18 — owner: Member A

A8 Failed rows eligible only for errors 5003,5004,5005,5006,5010; transfer_group_id NULL; never for deadlock/timeout/lab errors.

Reason: Avoid fabricating ledger failures for infrastructure errors.

### A9 — 2026-10-18 — owner: Member A

A9 sp_generate_statement is A-owned (Guide), B must not duplicate.

Reason: Avoid duplicate ownership.

### A10 — 2026-10-18 — owner: Member A

A10 Error convention: SIGNAL SQLSTATE '45000', MYSQL_ERRNO per table below, MESSAGE_TEXT 'E_NAME: text' with no PII.

Reason: Keep error handling stable and free of PII.

### A11 — 2026-10-18 — owner: Member A

A11 sp_update_customer may not deactivate a customer who has a non-Closed account; inactive customers cannot open accounts.

Reason: Keep customer and account lifecycle consistent.

### A12 — 2026-10-18 — owner: Member A

A12 B-owned tables are stubbed only in tests/stubs/ for standalone builds; B's real files replace stubs.

Reason: Permit independent builds without redefining B objects.

### A13 — 2026-10-18 — owner: Member A

A13 Baseline index set B0 = PK/UNIQUE/FK-required only. A adds NO secondary indexes.

Reason: Preserve the unoptimized B0 baseline.

### A14 — 2026-10-18 — owner: Member A

A14 B's fraud AFTER INSERT trigger on Transactions must be created with FOLLOWS trg_transactions_ai_audit. Flags written by the trigger roll back with a failed transfer (accepted).

Reason: Audit before fraud evaluation.

### A15 — 2026-10-18 — owner: Member A

A15 Ledger rows are immutable (no UPDATE/DELETE). Bulk loaders must run BEFORE triggers are installed.

Reason: Protect ledger history.

### A16 — 2026-10-18 — owner: Member A

A16 Procedures are DEFINER with SQL SECURITY DEFINER. Tests use disposable DBs (rebuild first); procedures commit, so tests cannot rely on ROLLBACK.

Reason: Model procedure commits and definer execution correctly.

### A17 — 2026-10-18 — owner: Member A

A17 Customer-actor check: if sp_resolve_actor(USER()) = Customer, the debited account must belong to that customer (5010). If Employee, p_employee_id must be NULL or equal the resolved employee. System: no actor restriction. Channel 'Branch' requires an active Teller whose branch = account's branch (from-account for transfers); other channels require p_employee_id NULL.

Reason: Enforce actor and channel ownership.

## 2026-10-18 — Prompt 2 implementation clarifications (owner: Member A)

These clarify D5 and A1/A3/A4/A10/A14/A15 without replacing the frozen SPEC.

- Actor fallback: compare logins case-sensitively; full login outranks bare user, which outranks host-specific fallback. Conflicting fallback identities resolve to System. Reason: avoid arbitrary actor attribution when multiple hosts map the same user differently.
- Guard errors: a Closed account balance/status change is 5011; zero without simultaneous closure or a below-minimum decrease is 5015; a self-counterparty is 5005. Missing device references retain native FK 1452. Reason: preserve the established error table and separate transition, balance, ownership, and reference failures.
- Reference suffix: six uppercase base36 characters from UUID_SHORT(), combined with NOW(6), with the existing unique reference_no constraint as final enforcement. Reason: no writes inside the reference function and uniqueness across the 1000-call shared-timestamp test.
- Audit toggles: require scratch or an explicit same-session override, and refuse dependent Transactions AFTER INSERT triggers. B controls its own fraud trigger and reinstalls it FOLLOWS A's audit. Reason: preserve A14 without editing B's objects.
- Constraint regression isolation: suspend only the ledger UPDATE guard around the unchanged Prompt 1 native-constraint fixture, restoring it in finally. Reason: native 1048 tests and unconditional 5012 guards cover different layers and must both remain tested.
- Reference data loads after the watermark, using natural keys; -WithSeed runs numeric loaders and can harmlessly repeat the idempotent reference loader. Reason: standalone and integrated builds share the same required reference baseline.
