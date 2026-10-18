# Member A procedure engine

All public signatures are those in docs/member-a/SPEC.md. Execute with SQL SECURITY DEFINER; install through the build lists while the banking schema is selected. No banking database name is hard-coded. The existing sp_resolve_actor remains unchanged.

## Installation and dependencies

1. Core/B tables, FKs, bank_lab, six A functions, sp_resolve_actor.
2. Private helpers (creation-time forward routine references are supported): sp_internal_authorize, sp_internal_assert_staff, sp_internal_insert_ledger, sp_internal_record_failed, sp_internal_post_single, sp_internal_post_transfer.
3. Public routines: register/update customer; open/close/set account status; deposit/withdraw; transfer/retry; request/decide approval; disburse loan; review flag; generate statement; reconcile; post monthly interest.
4. Existing guards/audits and installation watermark, reference loader, tiny loader.

NEVER grant sp_internal_* to application roles. B owns RBAC and must grant individual public procedures only. The integration test proves that a user granted only sp_transfer_funds can use that API but cannot call sp_internal_record_failed (1370).

## Transaction ownership

Public mutations own START TRANSACTION/COMMIT and rollback on error. Private helpers have no START/COMMIT/ROLLBACK. Approval decisions call the private transfer helper inside the approval transaction; account opening and routed loans use the private single-leg path. Retry calls the public transfer once per attempt, after each previous attempt has fully rolled back. Interest commits independently per account and continues after a per-account error.

MySQL START TRANSACTION commits an existing caller transaction. Do not wrap these public mutations in a transaction expecting to roll back their committed changes; compose a new public orchestration procedure using private helpers instead. OUT values are meaningful on successful CALL completion; MySQL does not publish modified OUT values when a CALL exits with an exception. Retry exhaustion records attempted counts in the experiment log and raises SQLSTATE 40001 / errno 1213.

## Private contracts

| Helper | Purpose |
|---|---|
| sp_internal_authorize(account,channel,employee,is_debit,allow_manager) | USER()-based A17 ownership/identity and Branch Teller checks; manager exception only for approved transfers |
| sp_internal_assert_staff(employee,account,roles) | Active role and resolved Employee identity; optional account branch scope; rejects Customer actors |
| sp_internal_insert_ledger(account,related,employee,group,device,location,type,amount,balance,channel,status,timestamp,OUT id) | Append-only row with generated reference and five duplicate-key attempts |
| sp_internal_record_failed(account,amount,type,channel) | Append Failed only when account and positive amount are valid; NULL employee/group/device/location/related; caller owns the separate transaction |
| sp_internal_post_single(account,amount,type,channel,employee,device,location,OUT id,OUT balance) | Lock account only (FOR UPDATE OF a), read type minimum, authorize, relative update, Completed Deposit/Withdrawal |
| sp_internal_post_transfer(SPEC transfer INs,allow_approval,SPEC OUTs) | Lock two accounts sequentially by LEAST/GREATEST, validate, debit, lab hook, credit; trusted approval path can bypass threshold and use its Manager |

The public exception handler first captures errno and rolls back. Only 5003/5004/5005/5006/5010 can request a Failed row. A nested handler protects the original error if recording itself fails. No row is possible when its account was rolled back/not found or the amount is invalid. A validation error with no monetary/account context (customer/status/flag operations) likewise has no Failed ledger representation. Deadlocks, timeouts, lab failures and other errors never generate Failed rows.

## Authorization and reporting

Normal Branch postings require an active same-branch Teller; Online/Mobile/ATM require NULL employee. Customer ownership is checked on the debited account; Employee ids cannot be impersonated. Approval decisions require an active same-branch Manager different from the requester. Manager-approved transfers and Manager/DBA interest postings are explicit administrative exceptions to the ordinary Branch Teller path. Status changes require active same-branch Teller/Manager staff. Employee approval requests use same-branch Teller/Manager staff; Customer requests must match the owning Customer. Unmapped System cannot raise an approval request without a real mapped requester.

Opening requires a positive deposit, even for a zero-minimum account type: a zero opening cannot produce the required positive Completed Deposit. Loan proceeds use Deposit. Settlement posts the final Withdrawal and sets balance=0,status=Closed in a single account UPDATE.

Statements return opening balance, then Completed rows with a SUM window ordered by transaction_id. The date limit is 366 inclusive days. Reconciliation returns six summaries (including I1b), then at most 100 offending keys. I2 and I4 are global even when an account filter is supplied. The session @reconcile_results JSON is the machine-readable copy used by tests.

Monthly interest uses the current locked balance/rate and a month label derived from p_period_start. It preserves the actual transaction posting timestamp, so historical processing cannot reorder the ledger used by statements. An atomic MONTHLY_INTEREST_POSTED event in the existing bank_lab.Experiment_Log links period and generated reference. Old markers cannot match rebuilt ledger rows because their references differ; unmarked legacy InterestCredit rows retain timestamp-month idempotency. Failed accounts roll back the marker as well as their balance/ledger/audit changes. @interest_errors counts those account failures.

## Lab/release and tests

Development mode 1 fails after debit; modes 2/3 sleep after debit; mode 3 chooses naive lock order. The hook and naive regions reside in the private helper; the public wrapper carries matching delegation markers. build/release_strip_lab_hook.ps1 removes them, retains ordered locks and signatures, and inserts a 5017 guard in both procedures. Generated files are gitignored and are loaded only in scratch by tests, then development scratch is rebuilt.

Tests use committed, uniquely named synthetic fixtures and bank_lab helpers. Prepared CALL strings passed to bank_lab.sp_expect_* must qualify procedures with `{db}.`, because the helper itself executes in bank_lab. Signal-based 1213/1205 probes verify error/rollback/retry branches; real concurrent deadlock scheduling remains EXP-10 work. Scratch-only injections prove all six invariant detectors, with a rebuild in finally. Restricted users receive runtime-only random passwords through their child MYSQL_PWD environment and are removed with their mappings in finally.
