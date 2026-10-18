# Prompt 2 delivery — 2026-10-18

All work remains uncommitted on `feature/A-functions-triggers`. The branch was verified before editing; its initial working tree was clean. History contains merge `68ca1a5` and schema commit `eb31f53`. No commit, push, merge, branch creation/switch, or main/develop write was performed.

## Status

| Deliverable | Status | Evidence |
|---|---|---|
| Six non-fraud functions and sp_resolve_actor | LOCALLY TESTED | Function/actor tests; EV-P2-ROUTINES-1.txt verifies security/determinism/data access |
| Six guards, nine audits, install watermark | LOCALLY TESTED | Guard/audit/inventory tests; EV-TRIG-1.txt contains all 15 names/timing/events |
| Audit toggle scripts | LOCALLY TESTED | Five safety scenarios, 5 PASS / 0 FAIL in EV-P2-TOGGLE-1.txt |
| Reference data and numeric -WithSeed ordering | LOCALLY TESTED | Seeded rebuild and six reference tests, including two loads and unchanged counts |
| Restricted USER() attribution and cleanup | LOCALLY TESTED | Eleven assertions, including both negative controls, exact session mapping, cleanup, and ledger reconciliation |
| Standalone build + complete regression suite | LOCALLY TESTED | 332 PASS / 0 FAIL for both required runner modes |
| Frozen schema / SPEC / Prompt 1 schema tests / B files | LOCALLY TESTED | Protected-path git diff exits 0; no migration needed |
| Integration with B's real objects | NEEDS MANUAL VERIFICATION | B's implementation is absent; standalone uses existing interface stand-ins |

## Commands and actual results

On MySQL 8.4.11 and Windows PowerShell, with the user-provided option file configured through BANK_MYSQL_CNF:

1. `powershell -File build/rebuild.ps1 -Database bank_txn -Mode Standalone -WithSeed`: exit 0, 3.89 seconds; evidence/EV-P2-BUILD-1.txt.
2. `powershell -File tests/run_tests.ps1 -Database bank_txn -NoRebuild`: exit 0, 332 PASS / 0 FAIL; evidence/test-runs/20261018-184547-243.txt.
3. `powershell -File tests/run_tests.ps1 -Database bank_txn`: exit 0, full rebuild then 332 PASS / 0 FAIL; evidence/test-runs/20261018-184658-313.txt.
4. Required information_schema.triggers query: 15 rows saved as UTF-8 in evidence/EV-TRIG-1.txt. Routine metadata is saved in evidence/EV-P2-ROUTINES-1.txt.
5. Scratch rebuild and audit toggles: bank_txn rejected with 5017 and 15 triggers retained; scratch drop left six guards; scratch create restored 15; explicit same-session override restored 15; synthetic dependent AFTER INSERT trigger caused 5017 before audit changes. Synthetic probe was removed. Evidence: EV-P2-TOGGLE-1.txt.
6. PowerShell AST parsing: zero errors. `git diff --check`: exit 0 (only Git's LF/CRLF normalization notices). No secrets/dumps were added.
7. Final administrative cleanup queries: remaining reserved users=0 and remaining reserved DB_User_Map rows=0. bank_lab retains historical install events across rebuilds; each new installation appends a DATABASE()-scoped watermark.

EV-P2-VERIFY-1.txt indexes the verification evidence. The two final suite runs are separate executions of the same 332 assertions, not 664 distinct tests.

## Test counts

| Tests | PASS | FAIL |
|---|---:|---:|
| Existing schema/interface/native constraint tests | 157 | 0 |
| Build SOURCE ordering | 73 | 0 |
| Existing Windows MySQL wrapper regression | 4 | 0 |
| Functions and actor resolution | 38 | 0 |
| Reference data | 6 | 0 |
| Guards | 17 | 0 |
| Audit snapshots and watermark | 11 | 0 |
| Restricted-login attribution, cleanup, fixture reconciliation | 11 | 0 |
| Trigger inventory | 15 | 0 |
| **Full suite per run** | **332** | **0** |
| Additional toggle safety verification | 5 | 0 |

## Implementation details and limits

The original native constraint test makes three Transactions UPDATE-to-NULL attempts expecting 1048. An unconditional immutability guard correctly preempts them with 5012. Rather than changing that frozen test or weakening the guard, the runner isolates that single fixture by dropping only the ledger UPDATE guard and restoring it in finally. The later guard tests and final inventory verify restoration. All other objects remain installed during those native checks. Tests must run against a disposable, exclusively used schema.

The resolver has the SPEC OUT signature, no transaction control, and DEFINER execution. Full login matches precede bare-user and host-part fallback; conflicting fallback identities remain System/unattributed. The function API and guard error choices are documented in interfaces.md and appended decisions. The SPEC itself is untouched.

All audit JSON snapshots include every column. INSERT old_value and DELETE new_value are SQL NULL. Transactions UPDATE/DELETE audit triggers are installed but unreachable while immutable guards are present, as explicitly required. Auditing is transactional; install/reinstall watermark events describe the start of each coverage period, not retroactive coverage.

Audit toggles require fail-fast execution and validate the selected DB before trigger DDL. They use a disposable bank_lab validator; a denied invocation can leave the validator until the next call. They do not alter B triggers; they reject an existing dependent Transactions AFTER INSERT trigger so its owner can manage lifecycle and restore FOLLOWS ordering. A create/reinstall records a fresh watermark.

The attribution test grants only Accounts SELECT/UPDATE columns and EXECUTE on its temporary DEFINER-context identity probe. Actual evidence shows USER() values `zz_a_teller_test@localhost` and `zz_a_customer_test@localhost`, while CURRENT_USER() in the matching trigger-definer context is `root@localhost`. Both users and exact calibrated mappings are removed in finally. Synthetic customer/employee/account/ledger fixtures remain in the disposable banking database because immutable audit history references them. Opening and subsequent credit transactions reconcile their final balance and latest balance_after. Runtime random passwords are never written to files or command arguments.

## Blockers and requests to B

No blocker remains for Prompt 2 standalone delivery. B's real table/fraud implementation is absent, so integrated execution cannot be validated yet. No B file was touched and no B change request was necessary; REQUESTS_TO_B.md remains an empty header. B must continue to honor the existing A14 FOLLOWS contract and manage its own trigger lifecycle during EXP-13.

## Completion checklist

- [x] Six functions and sp_resolve_actor.
- [x] Six guards, nine audit triggers, installation watermark.
- [x] Guarded toggle scripts, including dependent-trigger ordering protection.
- [x] Idempotent natural-key reference data, verified with two loads.
- [x] Both required runner modes all PASS, including real USER() attribution.
- [x] SPEC/interfaces/decisions consistent; frozen schema and original schema tests unchanged.
- [x] No B files, credentials, dumps, or real PII added/modified.
- [x] Commands, counts, status table, blockers, and inventory recorded.

## Files created / changed

Existing files extended: build/file_order.txt, build/rebuild.ps1, build/run_all.sql, build/run_all_A_standalone.sql, tests/run_tests.ps1, docs/interfaces.md, and append-only docs/decisions.md. New files are the six functions, resolver, guard/audit/toggle scripts, reference loader, function/trigger tests, this report, and verification evidence. The exact changed/new-file inventory follows.

```text
build/file_order.txt
build/rebuild.ps1
build/run_all_A_standalone.sql
build/run_all.sql
data/seed/01_reference_data.sql
docs/decisions.md
docs/interfaces.md
docs/member-a/PROMPT2_DELIVERY.md
evidence/EV-P2-BUILD-1.txt
evidence/EV-P2-ROUTINES-1.txt
evidence/EV-P2-TOGGLE-1.txt
evidence/EV-P2-VERIFY-1.txt
evidence/EV-TRIG-1.txt
evidence/test-runs/20261018-183314-389.txt
evidence/test-runs/20261018-183840-311.txt
evidence/test-runs/20261018-184000-615.txt
evidence/test-runs/20261018-184257-806.txt
evidence/test-runs/20261018-184404-214.txt
evidence/test-runs/20261018-184547-243.txt
evidence/test-runs/20261018-184658-313.txt
functions/fn_approval_threshold.sql
functions/fn_available_balance.sql
functions/fn_calc_interest.sql
functions/fn_generate_reference.sql
functions/fn_get_balance.sql
functions/fn_mask_id_proof.sql
procedures/sp_resolve_actor.sql
tests/functions/01_functions.sql
tests/functions/02_reference_data.sql
tests/run_tests.ps1
tests/triggers/01_guards.sql
tests/triggers/02_audit.sql
tests/triggers/03_actor_attribution.ps1
tests/triggers/04_trigger_inventory.sql
triggers/99_record_audit_install.sql
triggers/audit/trg_accounts_ad_audit.sql
triggers/audit/trg_accounts_ai_audit.sql
triggers/audit/trg_accounts_au_audit.sql
triggers/audit/trg_loans_ad_audit.sql
triggers/audit/trg_loans_ai_audit.sql
triggers/audit/trg_loans_au_audit.sql
triggers/audit/trg_transactions_ad_audit.sql
triggers/audit/trg_transactions_ai_audit.sql
triggers/audit/trg_transactions_au_audit.sql
triggers/guards/trg_accounts_bu_minbal_guard.sql
triggers/guards/trg_audit_log_bd_immutable.sql
triggers/guards/trg_audit_log_bu_immutable.sql
triggers/guards/trg_transactions_bd_immutable.sql
triggers/guards/trg_transactions_bi_device_owner.sql
triggers/guards/trg_transactions_bu_immutable.sql
triggers/lab/create_audit_triggers.sql
triggers/lab/drop_audit_triggers.sql
```
