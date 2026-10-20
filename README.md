# Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning

## Member A — build & test

Requires MySQL 8.0.16+ (enforced CHECK constraints), the native mysql CLI and PowerShell (measured environment: Windows PowerShell5.1 / MySQL8.4.11). Set `BANK_MYSQL_CNF` to a private option file; never commit credentials. For safe integration verification from the repository root:

```powershell
$env:BANK_MYSQL_CNF = Join-Path $HOME '.bank_mysql.cnf'
powershell -NoProfile -File tests/regression/pr9_acceptance.ps1
powershell -NoProfile -File tests/regression/error1222_seed.ps1
```

The default rebuild/test entry points retain their historical bank_txn/bank_txn_scratch targets; do not run them against databases you need to preserve. A's isolated context restricts operations to fresh owned names and redirects helper/evidence namespaces. The dedicated PR9 runners above allocate and clean their own disposable targets and do not create roles/users by default. Public procedures commit, so tests cannot rely on caller rollback. -Filter matches test file basenames; -NoRebuild only skips the initial rebuild, not every nested test's work.

Standalone uses interface stand-ins under tests/stubs; Integrated uses all seven real B tables, seven fraud functions, identity helpers, evaluator, fraud trigger and DEFINER views. Their extra constraints/runtime behavior are tested separately; the modes are not equivalent. RBAC is a separate preview/approved deployment step; optimized indexes are explicit, not part of B0. The optional Benchmark_Results include remains commented when unavailable. Workbench users follow build/file_order.txt mode annotations and docs/member-a/WORKBENCH_RUNBOOK.md. -WithSeed reruns numeric loaders idempotently; raw bulk loaders precede triggers and supply opening Completed Deposits. Procedure-based tiny seed follows triggers and generates normal ledger/audit rows.

A schema, functions, procedures and triggers are implemented. docs/member-a/SPEC.md remains authoritative; docs/member-a/status_report.md records final tested/blocked/manual status. Earlier DELIVERY/PROMPT reports are historical evidence, not a blanket current full-system acceptance claim.

The wrapper supports Windows PowerShell 5.1 and paths containing spaces. It captures MySQL stdout and stderr separately and saves original errors in the environment evidence file. Oracle MySQL does not support `--abort-source-on-error`; the wrapper expands standalone `SOURCE` lines (relative to the working directory) into UTF-8 batch input and disables `--force`, so execution stops on the first SQL error. A normal PowerShell variable such as `$env` is not inherited by child processes; set `$env:BANK_MYSQL_CNF` as shown above. If mysql.exe is absent from PATH, the wrapper also detects a single standard installation under Program Files/MySQL.

### Member A — final integration and reruns

Prerequisites: MySQL with InnoDB/CHECK/window/JSON support, PowerShell, native mysql and optional backup/benchmark tools. Full legacy regression includes tests that create/drop reserved zz_a_* users and grants, so it requires separate explicit authorization even in an isolated database context. Database isolation alone does not isolate global MySQL accounts. Crash/service actions remain operator-only. Credentials stay private; a local template without secrets is:

```ini
[client]
host=127.0.0.1
port=3306
# Set user and password privately for your own local server.
```

Set `$env:BANK_MYSQL_CNF` to that complete private file. `$env:BANK_MYSQL_BIN` optionally names the exact mysql.exe path (including spaces); it overrides PATH. No credentials belong in commands, Git or evidence. A copied normal `$env` variable does not propagate to child PowerShell processes. The wrapper probes explicitly isolate both environment settings and test Windows installation fallback.

```powershell
# Both modes, release and bounded Quick; only AFTER approval for its temporary account tests:
powershell -NoProfile -File tests/run_regression.ps1 -IsolatedPrefix bank_a_ci_unique_run -VerifyOptimized
# One existing disposable schema, without an implicit rebuild:
powershell -NoProfile -File tests/run_tests.ps1 -Database bank_txn -NoRebuild
# Explicit standalone development build:
powershell -NoProfile -File build/rebuild.ps1 -Database bank_txn_scratch -Mode Standalone -WithSeed
# Release generation and actual release procedure suite:
powershell -NoProfile -File build/release_strip_lab_hook.ps1
powershell -NoProfile -File tests/run_release.ps1 -Mode Integrated
```

Integrated build order is lab helpers → nine A tables → seven real B tables → core/cross FKs → A/B functions (risk heuristic before legacy wrapper) → resolver/private/public/evaluator procedures → guards/audits → watermark → reference/rule seed → fraud trigger FOLLOWS audit → tiny seed → views. Standalone uses its six interface stubs and omits B runtime. RBAC is a separate manual preview/approved deployment after views. file_order.txt and both CLI build files are checked together. No optimized B indexes are silently installed into B0. The release directory is ignored; signatures stay fixed, nonzero lab modes become 5017. tests/run_release.ps1 leaves scratch with release objects and checks that tests do not replace them. The development suite's two self-rebuilding scratch harnesses are reported not applicable inside that release run; they are exercised by both full development suites.

tests/run_regression.ps1 saves raw stage logs and a summary. Exit0 means its acceptance checks passed;1 means an executed failure;2 means remaining missing/blocked/not-run checks. The merged checkout supplies B runtime and a bounded -Quick branch, but installed files do not prove deployed privileges. RBAC preview/actor-map checks are separate from authenticated restricted-role tests, which require new approval. Historical evidence is not replaced by a fresh passing summary; inspect each run's paths and limits.

### Member A experiment index (bus-factor instructions)

Run from the repository root after configuring the two environment variables. Read each experiment README first. Lab drivers use scratch and may rebuild it; current concurrency drivers rebuild Standalone and are not proof of real B runtime integration. Runtime ranges below are planning estimates, not measured guarantees; measured results are in evidence/raw and RESULTS.md.

| Experiment | Command / next action | Planning runtime |
|---|---|---|
| EXP-01 atomicity | powershell -File experiments/EXP-01_atomicity/run_auto.ps1 | 1–2 min |
| EXP-02 consistency | powershell -File experiments/EXP-02_consistency/run_auto.ps1 | under 1 min |
| EXP-03 durability | powershell -File experiments/EXP-03_durability/setup.ps1; default kill_and_restart.ps1 in another window | preparation under 1 min; manual crash window up to 10 min |
| EXP-04 lost update | powershell -File experiments/EXP-04_lost_update/run_auto.ps1 | 1–3 min |
| EXP-05 dirty read | powershell -File experiments/EXP-05_dirty_read/run_auto.ps1 | about 1 min |
| EXP-06 nonrepeatable read | powershell -File experiments/EXP-06_nonrepeatable_read/run_auto.ps1 | about 1 min |
| EXP-07 phantom/gap | powershell -File experiments/EXP-07_phantom_read/run_auto.ps1 | 1–2 min |
| EXP-08 matrix | powershell -File experiments/EXP-08_isolation_matrix/build_matrix.ps1 | seconds; parses recorded raw data |
| EXP-08 throughput | powershell -File experiments/EXP-08_isolation_matrix/run_throughput.ps1 -Quick | 1–3 min; optional rerun, not executed in Prompt 6 |
| EXP-09 stress | powershell -File experiments/EXP-09_stress/run_stress.ps1 -Parallel 20 | 1–3 min; use 50 for the larger case |
| EXP-10 deadlocks | powershell -File experiments/EXP-10_deadlocks/run_auto.ps1 | 1–3 min; read corrected ordered-lock evidence |
| EXP-11..15 | Member B-owned; source not supplied | BLOCKED |
| EXP-16 recovery | follow backup/README.md: take_full_backup, apply_workload, oops_delete, simulate_loss, restore_and_pitr | minutes; PITR may require elevated datadir read access |
| EXP-17 audit | powershell -File experiments/EXP-17_audit_completeness/run_auto.ps1 | about 1 min |

Evidence navigation: docs/member-a/evidence_index.md; final acceptance: status_report.md and DOD_CHECKLIST.md; manual Workbench: WORKBENCH_RUNBOOK.md; review-document edits: docs/review1/CORRECTIONS_A.md. Each experiment retains its own instructions and limitations; preserve original measurements when making a new run.

Known limits: D5 begins coverage at audit-trigger installation; DBA can drop triggers or TRUNCATE/DROP audit data; fraud flags written transactionally roll back on transfer failure; each account has one owner and the system models one currency. Public routines own transactions, so do not wrap committing calls in a caller ROLLBACK test. Opening deposits must be positive under the ledger CHECK. SQL text restore can change opaque Audit_Log JSON representation, so native checksum mismatch is reported separately from normalized JSON equality. Crash/PITR and original Review 1 binary edits remain manual where the status report says so. Berka P2 is deferred until P1 blockers clear; no real data or B generators were added.

### Member A isolated integration checks — 2026-10-20

The merged PR9 corrections reconcile scoring/RBAC/views with Member A contracts. Older PR7/Prompt6 reports describe earlier commits and their blockers. To exercise A's complete orchestration, use a fresh disposable namespace and obtain approval for its reserved temporary-account tests first:

```powershell
powershell -NoProfile -File tests/run_regression.ps1 -IsolatedPrefix bank_a_ci_unique_run -VerifyOptimized
```

This preserves both-mode discovery, nested/release checks, bounded concurrent Quick and six invariants; cleanup is limited to owned isolated databases. Baseline remains default; Optimized explicitly sources B's unchanged index definitions. Integrated B assertions remain enabled. The component manifest excludes B runtime tests only in Standalone, emitting SKIP rather than PASS. Quick never invokes full drivers or overwrites historical reports. See docs/member-a/ISOLATED_REGRESSION.md for the tooling contract and evidence/reviews/A-B-merge-resolution/REPORT.md for actual merge verification. Earlier delivery counts remain historical; no complete current orchestration/role acceptance is inferred from them.

### Member A — safe PR9 acceptance

For acceptance without touching existing banking/helper schemas, use the dedicated isolated runner rather than the historical rebuild/test commands above:

```powershell
$env:BANK_MYSQL_CNF = Join-Path $HOME '.bank_mysql.cnf'
$env:BANK_MYSQL_BIN = 'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe'
powershell -NoProfile -File tests/regression/pr9_acceptance.ps1
powershell -NoProfile -File tests/regression/error1222_seed.ps1
```

The PR9 runner creates a fresh random marked disposable schema, installs actual Integrated A+B components with helper references relocated only in executed SQL, runs numbered SQL tests and targeted diagnostics, previews RBAC, compares baseline/optimized index inventories, reconciles six invariants, then verifies ownership before cleanup. It fails on SQL errors, failed assertions or missing TEST output. Logs are unique per run under evidence/reviews/PR9-final-fixes/. By default it never provisions global roles/users/grants. After explicit approval of security/README.md, -WithRestrictedRoles applies only fresh suffixed test roles and loopback users, runs native restricted-login assertions and cleans them up in finally. It never invokes the original nested PowerShell tests that rebuild fixed banking schemas. See the delivery report for measured results and remaining limits.
