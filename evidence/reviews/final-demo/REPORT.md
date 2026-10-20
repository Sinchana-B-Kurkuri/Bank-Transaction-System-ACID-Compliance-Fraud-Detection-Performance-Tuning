# Final working banking demo — 2026-10-20

**WORKING MODEL READY FOR DEMO** — with the explicit privileged/non-security
walkthrough described below. Integrated initialization, the actual CLI, end-to-end
banking, real fraud/audit behavior, safe regressions, real concurrent sessions and
all six invariants were executed successfully. Fresh least-privilege authenticated
role certification and disruptive recovery are not claimed.

## Revision, scope and preservation

- Branch: `feature/final-demo`.
- Exact HEAD: `8298f855f2020f01a518eaa53425fa66af629962`.
- Live `origin/develop` was read with `git ls-remote` and matched that HEAD.
  History includes PR9 at f59c520 and PR11's merge at8298f85; both source merge
  commits were verified ancestors.
- These demo additions are **uncommitted worktree changes** atop that commit.
  No commit/push/merge/branch switch/PR creation occurred.
- Production functions, procedures, tables, constraints, audit/guard/fraud
  triggers, security sources, views and index definitions have no source changes.
  Corrected ordered locks, all public signatures and approved fraud rules remain
  intact. No Member B implementation was rewritten.
- Historical tracked and untracked evidence remains intact. Every new execution
  has a timestamp/GUID evidence directory. Earlier failed demo-development runs
  are retained and explained below.

Gap analysis before substantial implementation:
`docs/member-a/FINAL_DEMO_GAPS.md`. The missing application/lifecycle has now been
implemented; documented security/view/rule limitations were preserved.

## Added/modified files and architecture

| File | Purpose/status |
|---|---|
| demo/bank_cli.py | IMPLEMENTED / LOCALLY TESTED: dependency-free Python CLI; native mysql subprocess; public API mutations; safe decimal/date/ID inputs and hex text literals; real error propagation |
| demo/start_demo.ps1 | IMPLEMENTED / LOCALLY TESTED: collision-checked owner-marked Integrated/Baseline initialization; persistent demo session record; preflight ownership checks and verified cleanup |
| demo/README.md | IMPLEMENTED: Windows setup, exact startup/stop/test commands, professor walkthrough, actual role/view limits, fraud thresholds, evidence/performance interpretation |
| tests/demo/test_cli.py | LOCALLY TESTED:6 input-boundary unit tests; protected-name refusal, decimal/rate/date validation, quote safety and public transfer-call generation |
| tests/demo/run_demo.ps1 | LOCALLY TESTED: actual CLI workflows, real MySQL isolation/deadlock/retry, normal/suspicious fraud,120 timing samples, EXPLAIN, invariant verification and finally cleanup |
| tests/demo/run_safe_regression.ps1 | LOCALLY TESTED: reusable version of the previously audited isolated SQL/vetted-child driver, avoiding fixed/global-account test scripts |
| tests/demo/verify_all.ps1 | LOCALLY TESTED: one-command orchestrator for units, safe Standalone/Integrated regression, PR9 acceptance, ERROR1222 and actual demo workflow |
| docs/member-a/FINAL_DEMO_GAPS.md | IMPLEMENTED: initial gap and scope record |
| README.md | Added final-demo entry and guide/report links; existing A/B material retained |
| .gitignore | Added demo/out/ for generated local lifecycle sessions |
| evidence/reviews/final-demo/ | New reports, raw output, measurements and lifecycle/cleanup evidence |

Architecture: PowerShell allocates only fresh owned schemas and invokes the
existing isolated build context. Python passes SQL as UTF-8 stdin to native
mysql8.4 using the external option file; all financial mutations CALL the existing
DEFINER public routines. Procedures/constraints/guards enforce business rules;
transactions trigger audit then fraud evaluation. Read surfaces are the existing
views in authenticated role mode, and expressly privileged base-table reporting
only in non-security mode. There is no ORM, web framework, cloud dependency,
financial DML, private-helper grant or role-selection impersonation in the CLI.

## Setup/start/run/stop — Windows

Run from the repository root. Python3.10+ and native mysql8.4 are needed; no pip
dependencies. Keep credentials in an external private client option file:

```powershell
$env:BANK_MYSQL_CNF = Join-Path $HOME '.bank_mysql.cnf'
$env:BANK_MYSQL_BIN = 'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe'
$env:BANK_PYTHON_BIN = 'C:\Path To Python\python.exe'
$env:PYTHONUTF8 = '1'
powershell -NoProfile -File demo/start_demo.ps1
$session = Get-Content demo/out/session.json -Raw | ConvertFrom-Json
$db = $session.Database
& $env:BANK_PYTHON_BIN demo/bank_cli.py --database $db --non-security-demo whoami
& $env:BANK_PYTHON_BIN demo/bank_cli.py --database $db --non-security-demo accounts
# See demo/README.md for registration/open/deposit/withdraw/transfer/review walkthrough.
powershell -NoProfile -File demo/start_demo.ps1 -Action Stop
```

Start refuses an existing session file; choose a fresh `-SessionFile` for another
run instead of deleting historical evidence. Stop validates all exact demo schema
names and all ownership markers before dropping anything. The JSON records the
owner token and database/evidence names, **not a password**. CLI permits only
`bank_a_ci_demo_<12hex>_main`; it rejects all three protected names before connecting.
The admin build connection must have schema/routine creation rights; no new
accounts or grants are provisioned by this process.

Actual local Python used for this execution (not a project dependency):
`C:\Users\sinch\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`.
Native client was `C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe`, server8.4.11.
The Python executable reported3.12.14. Final `static-checks.txt` records four
additional PASS checks: production-source preservation, no conflict markers,
all four new PowerShell scripts parsed, and tracked whitespace validation.

## Commands actually executed

Repository/history/status/tree reads; live develop ref and PR ancestry checks;
inspection of build/test/helper scripts, schema, routines, triggers, views,
security, fraud catalog and prior reports; initial gap analysis; PowerShell AST
parse checks; `git diff --check`; production-path preservation diff.

After source inspection, actual database executions were:

```powershell
# Initial independent fresh checks (all owned disposable targets):
powershell -NoProfile -File evidence/reviews/A-B-merge-resolution/verify-isolated.ps1
powershell -NoProfile -File tests/regression/pr9_acceptance.ps1
powershell -NoProfile -File tests/regression/error1222_seed.ps1
# Input tests and iterative real demo workflow runs (failures retained):
& $env:BANK_PYTHON_BIN -m unittest discover -s tests/demo -p 'test_*.py'
powershell -NoProfile -File tests/demo/run_demo.ps1
# Final one-command execution of all new orchestration:
powershell -NoProfile -File tests/demo/verify_all.ps1
```

The final orchestrator actually ran the six unit tests, safe regression,
PR9 acceptance, ERROR1222 regression and complete CLI/concurrency/measurement
workflow; it returned exit0 and `VERIFY|failed stages=0`.

Safe regression executes actual `build/rebuild.ps1` through its unchanged owned
isolation context, Standalone then Integrated with seed/B0, all numbered SQL
tests with mode-aware discovery, vetted schema/statement PS children, signature
checks, static release generation, actual bounded `run_all_auto.ps1 -Quick`,
invariants, then explicit Optimized on an owned scratch schema. It does not call
legacy nested tests with reserved global users. The PR9 installer is exercised in
preview/PREPARE-only mode; no grant is executed.

Hardware querying through Get-CimInstance was denied in the sandbox; a separately
approved read-only retry succeeded and is saved as `hardware-verified.json`. No
service, privilege, global variable or MySQL account change was part of that read.

## Final actual test populations

These populations overlap. Do not sum them into a unique-test total.

| Final execution population | PASS | FAIL | Detail |
|---|---:|---:|---|
| Standard-library CLI units | 6 | 0 | actual unittest execution |
| Standalone numbered SQL assertions | 632 | 0 |3 real-B runtime files explicitly SKIP, never reported PASS |
| Standalone vetted PS/static/final-invariant assertions | 186 | 0 | includes144 SOURCE checks and5 wrapper checks |
| Integrated numbered SQL assertions | 688 | 0 | actual real B tables/functions/evaluator/trigger/views |
| Integrated vetted PS/static/final-invariant assertions | 195 | 0 | includes real-B schema checks and all six invariants |
| Safe driver stage checks | 98 | 0 | aggregates stages and cleanup, not independent unique cases |
| Independent PR9 Integrated SQL | 688 | 0 |0 SQL-error files;0 files without TEST output |
| Independent PR9 focused checks | 58 | 0 | seven signatures, scoring, identity/views/statement logic, native RBAC preview, B0/Optimized |
| Independent ERROR1222 | 25 | 0 | tiny seed/open→fraud path, atomic rollback, audit order and six invariants |
| Bounded Quick | 10 | 0 |3 actual5016 rollback probes,2 real sessions ×5 ordered transfers and6 invariants |
| Actual final CLI/workflow assertions | 41 | 0 | includes isolation/deadlock/retry/performance/invariant stage assertions; cleanup additionally logged |

The general runtime acceptance child honestly returns **2** with
`ACCEPTANCE_FAIL=0; MISSING_OR_BLOCKED=2`: no target role grants were installed and
its generic EXECUTE-contract check remains blocked. The safe wrapper records
these as pending, not full role certification. PR9's more focused native preview
compiles the actual45-statement deployment plan and checks explicit public-only
grants against installed DEFINER APIs; no actual GRANT or CREATE ROLE is executed.

## Actual CLI banking walkthrough results

Fresh final workflow target: `bank_a_ci_demo_a99a890cc80b_main` (now removed).
All command stdout and original native stderr are retained.

- CLI launched and `whoami` returned the real native identity. Starting without
  the explicit non-security flag on the unprovisioned admin connection was
  correctly refused; a simulated menu identity is not accepted.
- Registered synthetic demo customer through `sp_register_customer` and opened
  `DEMO-0001` with200000 through `sp_open_account` (opening Completed Deposit).
- CLI deposit100, withdrawal25 and transfer200 produced199875.00. The statement's
  last Completed balance_after and returned running_balance both equaled199875.00.
- Overdraft through CLI failed with actual errno5004 and a nonzero CLI exit.
- History and fraud queue returned actual rows. An Open fraud flag moved through
  UnderReview→Confirmed using the public manager review API; reviewed_by matched
  the selected active manager.
- Routed loan500 created its loan and Deposit. A100000 approval request moved
  no money; approval by a distinct manager posted a linked paired transfer.
  Resulting account balance100375.00 was asserted.
- Approval request used a temporary row mapping this actual admin USER() to the
  synthetic Customer **only in the owned database**, removed in finally. This is
  explicitly an actor-map diagnostic, not authenticated Customer-role proof.
- Actual account INSERT audit count was1 with db_session_user=USER(); audit
  inspection and reconciliation commands executed through the CLI. Existing SQL
  tests verify JSON, all guards, ordering and the transactional rollback effects.

## Fraud configuration and observed results

Source policies are unchanged. Helper untrusted/missing device+20 and digital+10
produced the approved probe **30.00**. HIGH_ACCOUNT_RISK remains accumulated
transaction-local, evaluated in rule_id order, never feedback from stored profile.

Seed catalog: amount≥5000 weight20; untrusted20; digital10; local accumulated
risk≥60 weight25; at least3 Completed transactions within10minutes weight25.
Helper amount≥5000 adds20, ≥10000 adds35; evaluator supplies profile input0.
Matched catalog weights are added independently, capped100. This additive
implementation means helper30 is not synonymous with final catalog-evaluated30.
No rule/formula was changed merely to obtain the results.

Controlled normal: a trusted device/Branch deposit100 on the separate new
DEMO-NORMAL account, with only two recent Completed rows, produced **0 flags**
(transaction-local score0). Its earlier opening is a separate evaluated event.

Controlled suspicious: missing device/Online deposit6000 produced **Critical100**.
Base50 plus amount20, untrusted20 and digital10 reaches100; configured local-risk
and velocity matches also produce their flags. Exact rule/evidence JSON is saved
in `fraud-observations.txt`. Two actual reevaluations left flag count and summed
scores unchanged. Stored profile is the maximum across transaction evaluations,
not the individual transaction score.

Distance and odd-hour helpers were actually queried as diagnostics. No seeded
location-change or time-anomaly rule exists, so automatic detection of those
signals is **not claimed**. Adding rules requires a separate policy decision.

## ACID and real concurrency measurements

- COMMIT observed through CLI balances/ledger and approval/loan results.
- Actual injected5016 transfer failures in safe Quick/1222 rolled back balances,
  ledger, audit, flags and risk changes. No simulated deadlock errno was used.
- Four real writer/reader session pairs: writer increased balance+7 under an open
  transaction for4seconds then rolled back; reader began after1second with a1s
  lock wait timeout. READ UNCOMMITTED observed100382.00; READ COMMITTED and
  REPEATABLE READ observed100375.00; SERIALIZABLE returned actual1205. Final
  balances and invariants were restored by rollback.
- Bounded ordered Quick:2 concurrent sessions ×5 opposite transfers completed,
  exactly20 new Completed ledger rows, no session SQL failures. This is a smoke
  workload, not a claim to have rerun the full EXP10 grid.
- A first uninstrumented naive run did **not** deadlock and failed the original
  expectation; that evidence is retained. To make the live comparison repeatable,
  reused EXP10's existing first-lock scheduling probe **only in the owned DB's
  mode3 routine instance**. No source file, ordered mode, signature or business
  rule changed. Original routine restored after the probe and in finally.
- With the scheduling probe, two opposite native calls yielded exactly one actual
  **1213** victim and one successful call; stderr is preserved verbatim. Two
  public retry-wrapper calls then both completed and wrote **1 committed
  DEADLOCK_RETRY row** after rollback. No globals/deadlock logging changed.

## Six final invariants

All six also passed after both regression modes, after ordered Quick, and on the
separate Optimized build. Final walkthrough results after real CLI, fraud,
isolation, deadlock/retry and indexes at2026-10-20 19:01:16.806:

| Invariant | Violations | Result |
|---|---:|---|
| I1 current balance versus Completed ledger | 0 | PASS |
| I1b per-account balance_after chain | 0 | PASS |
| I2 paired/mirrored transfer legs | 0 | PASS |
| I3 minimum/nonnegative/closed balance rules | 0 | PASS |
| I4 audit completeness since watermark | 0 | PASS |
| I5 latest Completed balance_after | 0 | PASS |

## Measured Baseline versus Optimized

Unchanged B definitions; no optional indexes in B0; explicit Optimized installs
the seven named performance indexes. Three fixed reporting SELECTs, two warmups
then20 samples each/profile: **120 measured samples**. Native session NOW(6)
brackets exclude process startup, but include query/result production and
interstatement client/protocol overhead; these are not isolated CPU timings.
EXPLAIN and every sample are retained. No EXPLAIN ANALYZE, full throughput/stress
grid or production-data benchmark was run.

Final fixture:10 Accounts,39 Transactions,132 Fraud_Flags,1 approval. All synthetic.
Environment: MySQL8.4.11; REPEATABLE-READ default; flush-at-commit1; sync_binlog1;
log_bin/performance_schema ON. Windows NT10.0.26200.0; Intel Core Ultra5 125H,
14cores/18logical processors, RAM16568156160bytes (~15.43GiB). Initial hardware
read denial is preserved alongside the approved read-only result.

| Query | Samples/profile | Baseline mean µs | Optimized mean µs | Plan observation |
|---|---:|---:|---:|---|
| Account recent transactions | 20 | 759.35 | 1226.40 | FK ref/filesort→account/time range, backward scan |
| Open/UnderReview flags sorted by risk/time | 20 | 926.05 | 1159.10 | Full scan/filesort retained; optimizer need not choose optional index |
| Requested approvals | 20 | 827.00 | 673.30 | ALL/filesort→status/requested ref with index condition |

**Mixed tiny-data observations, not a general performance improvement claim.**
Small cardinalities, empty/narrow predicate results, warm cache, Baseline-first
order and protocol noise limit inference. A larger separately bounded synthetic
fixture, randomized profile order and repeated representative load are needed
before a speedup claim. Existing definitions were not changed to force a plan.

## New-code failures found and corrected

No defect requiring production banking/fraud/security SQL changes was found.

| Development run | Actual outcome | Correction |
|---|---|---|
| workflow-20261020-185056-825-8d24cefd40de4380a78c682e29f733ab |0 PASS/1 FAIL; PowerShell invoked built-in cli alias | Renamed test helper Invoke-DemoCli; no alias removal or OS mutation |
| workflow-20261020-185148-920-fe87921a7a4a41bb9d53965154abe9be and185250-626-cdd14f8869e24d6ea0467052f79890fe |3 PASS/1 FAIL each; scalar string indexing cast branch1 to character code49 | Wrapped native query results in @() before numeric conversion; complete CLI flow now exercises real integer IDs |
| workflow-20261020-185324-196-ae0d63f87bb3451a9c513a01b6c6d9f3 |34 PASS/1 FAIL; uninstrumented naive run had no deadlock | Reused existing EXP10's DB-only mode3 scheduling probe; genuine1213/retry required and then observed |
| workflow-20261020-185558-888-96189c0908cb44d78e2cb36df89e1f9f |40 PASS/0 FAIL | Intermediate full real workflow passed |
| Final workflow-20261020-190002-497-51085f9cf61f46d4a5bbee110928b886 |41 PASS/0 FAIL | Added explicit statement running_balance check; final one-command verification passed |

All failed-run owned schemas were cleaned in finally. They were not relabeled as
success. Native stdout/stderr capture was tightened to ProcessStartInfo so
PowerShell5.1's NativeCommandError rendering cannot obscure the original stderr.

## Evidence index and cleanup

Main one-command run:
`runs/verify-20261020-185809-667-1760b31be09647569d69d64477b924b8/`
(unit.txt and one raw log per child).

- Safe modes, index inventories, signature/static checks, SQL per-file counts:
  `runs/isolated-20261020-185810-465-c1fcdcc71d0446e5a090e67884cd375f/`.
- Final actual application and concurrent workflow:
  `runs/workflow-20261020-190002-497-51085f9cf61f46d4a5bbee110928b886/`:
  checks.txt, summary.txt, individual CLI stdout/stderr, driver-queries.sql,
  fraud-observations.txt, isolation-*/ native sessions, deadlock/ native errors
  and retry rows, mode3-scheduling-probe.sql, performance.csv,
  performance-summary.csv, both profiles' plans/indexes, benchmark-row-counts.txt,
  environment.txt, hardware-verified.json and final-invariants.txt.
- Final demo initialization metadata/snapshot:
  `runs/20261020-190003-157-63e09cbf608b40748c0e7e84732ed904/`.
- Final PR9 raw run:
  `evidence/reviews/PR9-final-fixes/20261020-185939-902-32043f9b64524979ba0dc600583a66df/`.
- Final1222 raw run:
  `evidence/error1222/20261020-185957-390-838bfda4c2ea445ba08d315bebec081c/`.
- Each Quick run reports its unique `evidence/quick/<timestamp-guid>/` directory
  in the safe-regression raw log, preserving old evidence.

Each driver verified ownership before cleanup and reported zero remaining owned
schemas. Final independent metadata check over all18 schema names recorded in
this task's six demo lifecycle sessions returned **0**; see
`cleanup-verification.txt`. Final session status is `cleaned`. Safe mode and
independent PR9/1222 cleanup checks also passed. No protected database was used
as a target/helper, no server globals/users/roles/grants/passwords/services were
changed, and no credentials/dumps/binlogs were added. Existing evidence was not
deleted, staged or overwritten.

## Remaining approvals, limits and manual features

- **Authenticated RBAC NEEDS MANUAL VERIFICATION / separate approval:** no fresh
  customer/teller/manager/auditor accounts or grants were authorized here.
  Privileged actor-map tests and native RBAC preview do not prove restricted-login
  least privilege. The CLI's authenticated-role path is IMPLEMENTED, not newly
  certified against real restricted logins. A new exact suffixed-account/role,
  target-only grant and finally-cleanup plan must be approved first.
- Existing view/grant behavior is preserved: customer summary stays
  customer-filtered even for Manager; staff activity is branch-filtered; Manager
  has no Audit_Log SELECT grant; Auditor has no mutation/statement EXECUTE and
  may have empty activity without a supported mapping. The CLI does not add
  privileges to hide these limitations.
- No active location/time-change fraud rules; no invented automatic signals.
- Crash/restart, PITR/recovery demonstrations, full concurrency/throughput grids
  and runtime release-database tests were not run. Static release stripping and
  existing safe atomic rollback/concurrency were tested. Historical evidence
  is not a new execution claim.
- Tiny-data query measurements have limited performance significance; larger
  load/privilege/performance certification remains unfinished.
- The safe regression deliberately omits legacy fixed/global-account PS tests.
  Its generic runtime acceptance retains two missing/blocked role checks.

The runnable database, CLI, reproducible lifecycle, actual workflows, fraud,
audit, rollback, concurrency and invariants satisfy the stated working-model
criteria with these disclosed limits. Source remains uncommitted for review.
