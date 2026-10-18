# Prompt 3 delivery — 2026-10-18

Work remains uncommitted on `feature/A-core-procedures`. Initial branch/status/history inspection showed a clean tree and merged Prompts 1/2 (`c1cb761`, `471dfe7`, `68ca1a5`, `eb31f53`). The prerequisite complete suite ran successfully: 332 PASS / 0 FAIL before implementation.

No commit, push, merge, branch creation/switch, main/develop write, service change, or mysqld termination was performed. Database creation/drop was limited to bank_txn and bank_txn_scratch. No schema migration was necessary.

## Status

| Deliverable | Status | Actual evidence |
|---|---|---|
| Sixteen new public procedures + six private helpers | LOCALLY TESTED | All installed as DEFINER; 23 procedures including unchanged sp_resolve_actor; EV-P3-INVENTORY-1.txt |
| Authorization, validation, account/customer/loan/flag lifecycle | LOCALLY TESTED | Per-procedure SQL tests and real restricted Customer/Teller logins |
| Atomic transfers, both ordered directions, lab modes | LOCALLY TESTED | Mode 1 restores both balances, ledger count and audit count; ordered forward/reverse and modes 2/3 exercised |
| D4/A8 Failed rules and protected logging | LOCALLY TESTED | Exact eligible-error increments; no Failed rows for 5002/5016/1213/1205/5017; a rejecting logger cannot mask original 5010 |
| Retry and exhaustion paths | LOCALLY TESTED | Controlled SIGNAL 1213/1205 tests exercise retries/logs/exhaustion, defaults and positive limits |
| Real concurrent deadlock scheduling | NEEDS MANUAL VERIFICATION | Explicitly deferred to EXP-10; signal probes are not claimed as real lock-contention evidence |
| Interest cursor, per-account rollback, idempotency, statements | LOCALLY TESTED | Zero-rate skip, isolated failure/recovery, second-run zero, actual statement outputs before/after historical-period processing |
| I1/I1b/I2/I3/I4/I5 | LOCALLY TESTED | Seed and final suite data all PASS; all six detectors deliberately fail on scratch injections, then rebuilt scratch passes |
| Tiny seed repeatability/idempotency | LOCALLY TESTED | Two seeded rebuilds and unchanged 6/8/1/21 counts after a third loader invocation; EV-P3-SEED-1.txt |
| Release generation and scratch execution | LOCALLY TESTED | Signatures retained; forbidden lab logic removed; both procedures reject mode 1; ordered mode 0 transfers and six invariants pass |
| Frozen schema, functions, triggers, existing tests/interfaces | LOCALLY TESTED | No edits to schema/functions/triggers or existing tests; interfaces and decisions extended, not replaced |
| B integration | NEEDS MANUAL VERIFICATION | B's real files are absent; unchanged interface stand-ins and original contract test are used |

## Required commands and results

1. `powershell -File build/rebuild.ps1 -Database bank_txn -Mode Standalone -WithSeed`: exit 0, 3.61 seconds.
2. The same seeded rebuild again: exit 0, 3.80 seconds.
3. `source data/seed/02_tiny_seed.sql` against bank_txn through mysql with BANK_MYSQL_CNF: before `COUNTS|6|8|1|21`, after `COUNTS|6|8|1|21`. Columns are Customers, Accounts, Loans, Transactions. Evidence: EV-P3-SEED-1.txt.
4. Seed-only `CALL sp_reconcile_balances(NULL)`: all six summaries PASS with zero violations; EV-P3-SEED-INVARIANTS-1.txt.
5. `powershell -File tests/run_tests.ps1 -Database bank_txn`: final exit 0, **707 PASS / 0 FAIL**. Raw log: evidence/test-runs/20261018-193644-850.txt. The previous complete run also passed the same 707 cases; these are not 1414 distinct tests.
6. `powershell -File build/release_strip_lab_hook.ps1`: final exit 0. Public diff: 2 insertions / 8 deletions; private diff: 3 insertions / 15 deletions. EV-P3-STRIP-1.txt records actual output. Generated SQL remains gitignored under build/release/procedures.
7. Release verification loads both generated procedures only into scratch, expects 5017 from public and private mode 1, checks no ledger/Failed additions, executes an ordered mode 0 transfer, and reconciles all six invariants. It then rebuilds scratch to restore development objects. EV-P3-RELEASE-1.txt.
8. Final `CALL sp_reconcile_balances(NULL)` against bank_txn: I1/I1b/I2/I3/I4/I5 all PASS, zero violations; evidence/EV-INV-1.txt.
9. Final inventory/cleanup: 23 procedures, all DEFINER; main has the original 15 triggers; reserved users=0, reserved maps=0, administrative USER() map=0. The original banking B0 snapshot was remeasured and restored with its original UTF-8 BOM; git diff is empty for that file.
10. PowerShell AST parsing: zero errors. `git diff --check`: exit 0; only normal LF/CRLF notices. Protected paths (schema, functions, triggers, original schema/function/trigger tests, runner, stubs, SPEC, resolver, and B directories) have no changes.

## Test counts and branch evidence

| Suite component | PASS | FAIL |
|---|---:|---:|
| Existing schema tests | 157 | 0 |
| Build SOURCE/Workbench ordering (expanded lists) | 119 | 0 |
| Existing wrapper regression | 4 | 0 |
| Existing function/reference tests | 44 | 0 |
| Existing trigger/actor tests | 54 | 0 |
| New procedure SQL assertions | 264 | 0 |
| Actual statement result sets, scratch injections/restoration, release PS checks | 13 | 0 |
| Invariant summaries | 6 | 0 |
| Real procedure actor integration | 8 | 0 |
| Reused B interface contract | 38 | 0 |
| **Final complete run** | **707** | **0** |

| Public procedure | SQL assertions | Representative demonstrated paths |
|---|---:|---|
| sp_register_customer | 20 | Valid/defaults, NULL/empty/bad attributes, future DOB, duplicate email/phone/id proof, plus-prefixed phone |
| sp_update_customer | 16 | COALESCE updates, missing customer, validation, duplicate sanitization, A11 deactivation/reactivation, Customer mismatch |
| sp_open_account | 25 | Generated/fixed numbers, opening Deposit, exact minimum, invalid references/amounts, inactive customer/staff, actor/branch rejection, collision retry/exhaustion |
| sp_close_account | 10 | Nonzero default rejection, active-loan block, settled zero/Closed withdrawal, invalid flag, nonexistent/already Closed, wrong staff, Frozen settlement |
| sp_set_account_status | 14 | Freeze/unfreeze, same/invalid/Closed transitions, nonexistent account, unauthorized/inactive staff |
| sp_deposit | 26 | Outputs/relative balance, Branch/Online/Mobile context, amount/reference/state/auth errors, device/FK rollback, reference retry/exhaustion |
| sp_withdraw | 18 | Completed posting, exact minimum, insufficient/below-minimum, invalid amount/account/channel/staff, Frozen/Closed, spoofed Employee |
| sp_transfer_funds | 40 | Both ordered directions, threshold minus-cent/exact threshold, all eligible Failed categories, metadata, atomic lab failure, native-code probes, sleep/naive paths, source/destination states |
| sp_transfer_funds_retry | 12 | NULL/default/explicit/large-positive limits, invalid limits, controlled transient 1213/1205, durable retry and exhaustion events |
| sp_request_approval | 15 | Matching Customer/Employee, no money movement, actor/reference/amount/state/branch rejection |
| sp_decide_approval | 16 | Approved linkage and money, Rejected/no movement, double decision, bad manager/branch/self-decision, failed transfer preserves Requested |
| sp_disburse_loan | 21 | Routed/unrouted/Branch loans, Deposit proceeds, amount/rate/tenure/reference/owner/state/actor/staff rejection |
| sp_review_fraud_flag | 10 | Open->UnderReview->Confirmed/Dismissed, reviewer, nonexistent/unauthorized/illegal/terminal cases |
| sp_generate_statement | 6 | Valid range, inclusive 366-day boundary, too-long/reversed/NULL range, missing account; additional PS checks actual returned running balances |
| sp_reconcile_balances | 3 | Scoped success, six summaries, missing account; additional scratch tests prove all six failure detectors |
| sp_post_monthly_interest | 12 | Manager/DBA, bad period/Teller, cursor totals, second-run zero, zero-rate skip, isolated rollback and recovery |

The real Customer login cannot debit another owner (5010), can transfer from its own account with both ledger audits attributed to that exact USER(), and cannot execute a private helper (1370). The real Teller login is rejected for wrong branch and Employee impersonation, and succeeds at the correct branch with Employee audit attribution. Passwords remain runtime-only child MYSQL_PWD values; users/maps are cleaned in finally.

The controlled retry probes SIGNAL MySQL 1213/1205; they do not create a real wait-for cycle or demonstrate live deadlock scheduling. Reference/account collision probes create genuine duplicate-key conflicts. All test-only triggers are dropped. Actual native concurrency testing belongs to EXP-10.

## Invariants, release, and semantic clarifications

Scratch testing first increases a balance by 1 and observes I1/I5 FAIL. It then uses the guarded scratch audit toggle and public APIs to create missing Account/Transaction/Loan INSERT audits, demonstrating I4. Additional orphan-transfer, chain, and below-minimum fixtures make all six summaries FAIL. Actual diagnostics are saved in EV-P3-INJECT-1.txt, EV-P3-AUDIT-GAP-1.txt, and EV-P3-ALL-INVARIANTS-1.txt. A finally rebuild removes all injected data and restores audit triggers/development routines.

The ordinary Branch Teller rule is preserved. The explicitly required approval Manager and monthly Manager/DBA paths are confined administrative exceptions. Private helpers have no transaction control and must never be granted. Failed logging runs after rollback in its own protected transaction; retry does not log duplicate Failed rows. See procedures/README.md and the appended interface/decision sections for complete contracts and caller transaction warnings.

Historical interest processing preserves actual posting timestamps. Its month is atomically registered in the existing A-owned Experiment_Log and linked by generated reference, preserving idempotency across audit toggles and preventing stale records after rebuild from matching new ledger rows. Unmarked legacy credits retain timestamp-month semantics. This avoids the incorrect statement opening/running balances caused by backdating newly posted interest. The calculation still uses the current locked balance/rate, not reconstructed historical balances. No schema/table changes were made.

Statements use 366 inclusive calendar days. Reconciliation is read-only and keeps the requested two result sets; session @reconcile_results duplicates the six summaries for test consumption. I2/I4 are global when an account id is supplied.

Early regression logs are retained as real evidence. Initial new helper CALL strings incorrectly resolved unqualified names in bank_lab (1305); they now use `{db}.` qualification. An insufficient-funds fixture accidentally used an account just funded by the threshold success test; it was replaced by a dedicated account at the minimum. These were test-fixture failures, now corrected. The final 707/0 log supersedes earlier failed/intermediate runs.

## Blockers and requests to B

No blocker remains for Prompt 3 standalone delivery. B's real tables/fraud/RBAC implementation is absent, so integrated behavior and B role grants cannot be verified. No B file was edited. REQUESTS_TO_B.md remains its empty header; no B change request was needed. B must continue to grant only public routines and preserve the existing FOLLOWS audit ordering contract.

## Completion checklist

- [x] Sixteen new public procedures, existing resolver preserved, six non-public helpers, retry wrapper.
- [x] Success and rejection categories tested; final full suite 707 PASS / 0 FAIL.
- [x] Mode 1 transfer rollback proves unchanged balances, ledger rows and audit rows.
- [x] Deterministic lock code retained and exercised in both directions and release.
- [x] Eligible Failed recording and non-eligible exclusions verified; logging failure does not mask the original error.
- [x] I1/I1b/I2/I3/I4/I5 pass on seed and final data; detectors fail on scratch corruption and pass after rebuilding.
- [x] Seed repeatability and idempotency measured.
- [x] Release strip, diff stats, forbidden-logic checks, scratch load/rejection/success and restoration verified.
- [x] Interfaces/decisions extended; frozen schema/functions/triggers/tests unchanged.
- [x] No B files, credentials, dumps, or real PII added/modified.
- [x] Status, commands, counts, limitations and inventory recorded.

## Files created / changed

Existing files changed: .gitignore (release output only), build/file_order.txt, build/run_all.sql, build/run_all_A_standalone.sql, docs/interfaces.md, and append-only docs/decisions.md. All procedure implementations, new procedure/invariant/integration tests, seed loader, release script, this report and Prompt 3 evidence are new files. The exact changed/new-file inventory follows; ignored generated release SQL is intentionally absent from git's inventory.

```text
.gitignore
build/file_order.txt
build/release_strip_lab_hook.ps1
build/run_all_A_standalone.sql
build/run_all.sql
data/seed/02_tiny_seed.sql
docs/decisions.md
docs/interfaces.md
docs/member-a/PROMPT3_DELIVERY.md
evidence/EV-INV-1.txt
evidence/EV-P3-ALL-INVARIANTS-1.txt
evidence/EV-P3-AUDIT-GAP-1.txt
evidence/EV-P3-INJECT-1.txt
evidence/EV-P3-INVENTORY-1.txt
evidence/EV-P3-RELEASE-1.txt
evidence/EV-P3-SEED-1.txt
evidence/EV-P3-SEED-INVARIANTS-1.txt
evidence/EV-P3-STRIP-1.txt
evidence/test-runs/20261018-185656-639.txt
evidence/test-runs/20261018-191310-281.txt
evidence/test-runs/20261018-191446-300.txt
evidence/test-runs/20261018-191619-528.txt
evidence/test-runs/20261018-192217-574.txt
evidence/test-runs/20261018-192634-571.txt
evidence/test-runs/20261018-192924-909.txt
evidence/test-runs/20261018-193644-850.txt
procedures/README.md
procedures/sp_close_account.sql
procedures/sp_decide_approval.sql
procedures/sp_deposit.sql
procedures/sp_disburse_loan.sql
procedures/sp_generate_statement.sql
procedures/sp_internal_assert_staff.sql
procedures/sp_internal_authorize.sql
procedures/sp_internal_insert_ledger.sql
procedures/sp_internal_post_single.sql
procedures/sp_internal_post_transfer.sql
procedures/sp_internal_record_failed.sql
procedures/sp_open_account.sql
procedures/sp_post_monthly_interest.sql
procedures/sp_reconcile_balances.sql
procedures/sp_register_customer.sql
procedures/sp_request_approval.sql
procedures/sp_review_fraud_flag.sql
procedures/sp_set_account_status.sql
procedures/sp_transfer_funds_retry.sql
procedures/sp_transfer_funds.sql
procedures/sp_update_customer.sql
procedures/sp_withdraw.sql
tests/integration/01_actor_attribution_procs.ps1
tests/integration/02_interface_contract_b.sql
tests/invariants/01_invariants.sql
tests/invariants/README.md
tests/procedures/01_sp_register_customer.sql
tests/procedures/02_sp_update_customer.sql
tests/procedures/03_sp_open_account.sql
tests/procedures/04_sp_close_account.sql
tests/procedures/05_sp_set_account_status.sql
tests/procedures/06_sp_deposit.sql
tests/procedures/07_sp_withdraw.sql
tests/procedures/08_sp_transfer_funds.sql
tests/procedures/09_sp_transfer_funds_retry.sql
tests/procedures/10_sp_request_approval.sql
tests/procedures/11_sp_decide_approval.sql
tests/procedures/12_sp_disburse_loan.sql
tests/procedures/13_sp_review_fraud_flag.sql
tests/procedures/14_sp_generate_statement.sql
tests/procedures/14_statement_resultsets.ps1
tests/procedures/15_reconcile_scratch.ps1
tests/procedures/15_sp_reconcile_balances.sql
tests/procedures/16_sp_post_monthly_interest.sql
tests/procedures/17_statement_after_interest.ps1
tests/procedures/18_release_strip.ps1
tests/procedures/support/extra_01_sp_register_customer.sql
tests/procedures/support/extra_03_sp_open_account.sql
tests/procedures/support/extra_04_sp_close_account.sql
tests/procedures/support/extra_05_sp_set_account_status.sql
tests/procedures/support/extra_06_sp_deposit.sql
tests/procedures/support/extra_08_sp_transfer_funds.sql
tests/procedures/support/extra_10_sp_request_approval.sql
tests/procedures/support/extra_11_sp_decide_approval.sql
tests/procedures/support/extra_12_sp_disburse_loan.sql
tests/procedures/support/fault_trigger.sql
tests/procedures/support/fixture.sql
```
