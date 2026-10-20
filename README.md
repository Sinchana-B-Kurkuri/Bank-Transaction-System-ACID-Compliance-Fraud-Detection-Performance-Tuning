# Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning

## Member A — build & test

Requires MySQL 8.0.16+ (enforced CHECK constraints), the mysql CLI on PATH, and PowerShell. Set `BANK_MYSQL_CNF` to a local MySQL option file; never commit credentials. Run from the repository root:

```powershell
$env:BANK_MYSQL_CNF = Join-Path $HOME '.bank_mysql.cnf'
powershell -File build/env_check.ps1
powershell -File build/rebuild.ps1 -Database bank_txn -Mode Integrated -WithSeed
powershell -File tests/run_regression.ps1
```

Rebuild drops only `bank_txn` or `bank_txn_scratch`. The default test run rebuilds first. `-NoRebuild` is for an already disposable schema; procedure tests cannot rely on rollback. `-Filter` matches test file basenames with a PowerShell wildcard. Logs are saved under evidence/test-runs. B0 is saved by rebuild in evidence/EV-B0-1.txt.

Standalone uses interface stand-ins under tests/stubs; Integrated uses the seven real B table files now merged in develop. Their extra constraints are tested separately; the two modes are not equivalent. B runtime fraud/security/views/benchmark files are absent in this checkout. Workbench users follow the mode annotations in build/file_order.txt and docs/member-a/WORKBENCH_RUNBOOK.md. Optional `-WithSeed` loads sorted data/seed/*.sql files; it fails before dropping anything if no seed loader exists. Raw bulk loaders run before triggers and must supply opening Completed Deposit rows. Procedure-based tiny seed runs after installation and generates its ledger/audit normally.

A schema, functions, procedures and triggers are implemented. docs/member-a/SPEC.md remains authoritative; docs/member-a/status_report.md records final tested/blocked/manual status. Earlier DELIVERY/PROMPT reports are historical evidence, not a blanket current full-system acceptance claim.

The wrapper supports Windows PowerShell 5.1 and paths containing spaces. It captures MySQL stdout and stderr separately and saves original errors in the environment evidence file. Oracle MySQL does not support `--abort-source-on-error`; the wrapper expands standalone `SOURCE` lines (relative to the working directory) into UTF-8 batch input and disables `--force`, so execution stops on the first SQL error. A normal PowerShell variable such as `$env` is not inherited by child processes; set `$env:BANK_MYSQL_CNF` as shown above. If mysql.exe is absent from PATH, the wrapper also detects a single standard installation under Program Files/MySQL.

### Member A — final integration and reruns

Prerequisites: MySQL 8.0.16+ with InnoDB/CHECK/window/JSON support (measured here: 8.4.11), Windows PowerShell 5.1 or compatible PowerShell, native mysql client and optional mysqldump/mysqlbinlog/mysqlslap tools. Tests need a disposable permitted database plus local administrative privileges to create/drop reserved zz_a_* users and grant temporary access. Crash/service actions remain operator-only. Credentials must be configured privately; no repository credential file exists. A minimal local file template without secrets is:

```ini
[client]
host=127.0.0.1
port=3306
# Set user and password privately for your own local server.
```

Set `$env:BANK_MYSQL_CNF` to that complete private file. `$env:BANK_MYSQL_BIN` optionally names the exact mysql.exe path (including spaces); it overrides PATH. No credentials belong in commands, Git or evidence. A copied normal `$env` variable does not propagate to child PowerShell processes. The wrapper probes explicitly isolate both environment settings and test Windows installation fallback.

```powershell
# Both modes and release, with real components available in this checkout:
powershell -NoProfile -File tests/run_regression.ps1
# One existing disposable schema, without an implicit rebuild:
powershell -NoProfile -File tests/run_tests.ps1 -Database bank_txn -NoRebuild
# Explicit standalone development build:
powershell -NoProfile -File build/rebuild.ps1 -Database bank_txn_scratch -Mode Standalone -WithSeed
# Release generation and actual release procedure suite:
powershell -NoProfile -File build/release_strip_lab_hook.ps1
powershell -NoProfile -File tests/run_release.ps1 -Mode Integrated
```

Build order is lab helpers → nine A tables → real B tables (or standalone stubs) → core/cross FKs → functions → resolver/private/public procedures → guards/audits → installation watermark → reference/tiny seed. file_order.txt and both CLI build files are checked together. No optimized B indexes are silently installed into B0. The release directory is ignored; signatures stay fixed, nonzero lab modes become 5017. tests/run_release.ps1 leaves scratch with release objects and checks that tests do not replace them. The development suite's two self-rebuilding scratch harnesses are reported not applicable inside that release run; they are exercised by both full development suites.

tests/run_regression.ps1 saves evidence/regression/<timestamp>.md plus raw stage logs. Exit 0 means all acceptance checks passed; 1 means an executed failure; 2 means remaining blockers. Missing B runtime/security and unsupported experiment -Quick are explicitly BLOCKED, even if both SQL suites pass. No full throughput grid is rerun as a substitute. New generated evidence is archived and tracked historical evidence restored; manually inspecting an old EV file alone does not identify the latest run.

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
