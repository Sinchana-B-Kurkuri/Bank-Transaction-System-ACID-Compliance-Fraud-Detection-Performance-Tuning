# Prompt 6 Member A tooling corrections — 2026-10-20

**IMPLEMENTED / LOCALLY TESTED. Whole-system acceptance remains BLOCKED.**

Branch stayed `feature/A-integration-docs`, HEAD `5c6fbb4`. No commit, push, merge, branch creation/switch, or history rewrite. Read the PR7 review and historical Prompt 6 report before implementation. No Member B source, banking procedure, function, schema, audit/guard trigger, or ordered-locking logic was modified. No protected banking database was rebuilt.

## Changes delivered

| Area | Correction | Status |
|---|---|---|
| SOURCE / ownership | Reference seed ordering synchronized; B fraud/view/index entries labeled B; optimized entry included in SOURCE checks. | LOCALLY TESTED |
| Test modes | Auto detects installed real B schema; explicit mode must agree. Standalone skips exactly the two registered B runtime tests with SKIP lines, not PASS. Integrated executes both B tests unchanged. | LOCALLY TESTED |
| Disposable targeting | Opt-in isolated prefix, three exact allowed names, owner markers, existing-name refusal, child propagation, helper-schema rewriting, protected/global SQL rejection, owned cleanup. Nested injection/release tests target isolated scratch. Normal banking target defaults retained. | LOCALLY TESTED |
| Evidence | Isolated regression redirects legacy evidence writers into its new run directory. Quick always creates a fresh timestamp/GUID directory. Historical tracked evidence is unchanged. | LOCALLY TESTED |
| Acceptance | Inventory now recognizes installed fn_fraud_score/evaluator/views/trigger separately from missing SPEC functions. Real scoring/reevaluation/order/automatic-evaluation/rollback probes remain visible. Missing target grants are distinct from failing behavior. | LOCALLY TESTED; B failures remain |
| Quick | Exclusive bounded branch: three real 5016 probes, two native concurrent sessions with five ordered transfers each, six invariants. No full drivers, rebuild, installation, matrix, throughput, service/global operation or historical RESULTS update. Invalid options/full isolated invocation refused. | LOCALLY TESTED |
| Index profiles | Baseline omits performance indexes. Explicit Integrated Optimized sources B's unchanged definitions. Independent FK-only B0 checks retained; optimized snapshot is not named EV-B0. | LOCALLY TESTED |

Usage and safety details: [ISOLATED_REGRESSION.md](ISOLATED_REGRESSION.md). This is opt-in targeting, not permission for arbitrary database names. The runner refuses existing names and cleanup checks its marker. If marker verification fails, it retains the database and reports failure rather than dropping it.

## Exact verification commands

MySQL 8.4.11; Windows PowerShell child scripts, configured BANK_MYSQL_CNF/BANK_MYSQL_BIN. The private option file remained outside the repository; its contents were not copied or logged.

```powershell
powershell -NoProfile -File tests/schema/03_source_order.ps1
powershell -NoProfile -File tests/schema/04_mysql_wrapper.ps1
powershell -NoProfile -File tests/integration/support/Write-SignatureContract.ps1 -Check
powershell -NoProfile -File tests/schema/05_isolated_context.ps1
powershell -NoProfile -File tests/schema/06_quick_arguments.ps1
powershell -NoProfile -File tests/run_regression.ps1 -IsolatedPrefix bank_a_ci_20261020_tooling1
powershell -NoProfile -File tests/run_regression.ps1 -IsolatedPrefix bank_a_ci_20261020_tooling2 -VerifyOptimized
git diff --check
git diff --cached --check
git diff --exit-code -- procedures functions triggers schema data security views indexes benchmarks tests/functions/03_fraud_score.sql tests/integration/06_fraud_security_objects.sql
git diff --exit-code -- evidence
git status --short
```

The final runner executed these actual child stages against its isolated names:

```powershell
build/rebuild.ps1 -Database bank_a_ci_20261020_tooling2_main -Mode Standalone -IndexProfile Baseline -WithSeed
tests/run_tests.ps1 -Database bank_a_ci_20261020_tooling2_main -Mode Standalone -NoRebuild
build/rebuild.ps1 -Database bank_a_ci_20261020_tooling2_main -Mode Integrated -IndexProfile Baseline -WithSeed
tests/run_tests.ps1 -Database bank_a_ci_20261020_tooling2_main -Mode Integrated -NoRebuild
tests/p6_static.ps1 -Database bank_a_ci_20261020_tooling2_main -Snapshot <run-directory>/<mode>-B0.txt
tests/runtime_acceptance.ps1 -Database bank_a_ci_20261020_tooling2_main -Mode Integrated
experiments/run_all_auto.ps1 -Database bank_a_ci_20261020_tooling2_main -Quick
tests/run_release.ps1 -Database bank_a_ci_20261020_tooling2_scratch -Mode Integrated
build/rebuild.ps1 -Database bank_a_ci_20261020_tooling2_scratch -Mode Integrated -IndexProfile Optimized -WithSeed
```

The static stage ran once per mode; release generation ran through build/release_strip_lab_hook.ps1. Invariants were called after both suites, Quick, release, and Optimized installation. No full EXP-08 grid or other full experiment workload ran.

## Final actual results

Final report: `evidence/regression/20261020-102316-264-6d7d94e0/summary.md`; per-stage raw logs and checks.csv are alongside it.

| Test population | Actual result |
|---|---|
| Standalone complete discovered suite | **814 PASS / 0 FAIL**, exit 0; two explicit B runtime SKIPs |
| Integrated complete discovered suite | **831 PASS / 1 FAIL**, exit 1 |
| Integrated failure | `fraud score digital untrusted: expected=40.00; actual=30.00` — unmodified B assertion |
| Release procedure suite | **311 PASS / 0 FAIL**, including 5017 guards/signatures and six invariants |
| Static/B0 stage | **11 PASS / 0 FAIL per mode**; 36 core index-column records; independent FK-only support check passed |
| Direct SOURCE-order check | **135 PASS / 0 FAIL** across three entry files |
| Independent wrapper probes | **5 PASS / 0 FAIL** |
| Signature fixture check | **1 PASS / 0 FAIL**; installed signature assertions also ran in suites |
| Isolated-context safety probes | **14 PASS / 0 FAIL** |
| Quick argument rejection probes | **3 PASS / 0 FAIL** |
| Bounded Quick | **10 PASS / 0 FAIL**: 3 failure probes + ordered concurrency check + 6 invariant checks |
| Quick concurrent measurement | Two native sessions, five transfers each; **10 completed transfers / 20 ledger rows**; session stderr empty |
| Explicit Optimized | Build exit 0, **7 named B performance indexes**, six invariants PASS; no benchmark run |
| Every final invariant call | I1, I1b, I2, I3, I4, I5: **6 PASS / 0 FAIL** |
| Final top-level acceptance | **4 FAIL rows / 8 MISSING entries**, exit **1** — intentionally not a green acceptance claim |

Counts describe separate populations and include emitted TEST summary lines; they are not additive unique-case counts. The four failed acceptance/stage rows are the Integrated suite, its repeated scoring behavior probe, reevaluation stability, and the public EXECUTE source contract. Eight missing entries are seven SPEC functions plus absent role grants on the isolated target; the role source exists but was deliberately not applied because it targets bank_txn.

Runtime inventory recognizes fn_fraud_score, sp_evaluate_fraud and all three views. Trigger ACTION_ORDER and source FOLLOWS passed. A real deposit generated fraud flags and exactly one INSERT audit. A real mode-1 transfer returned 5016 with balance/ledger/audit/flags/risk totals unchanged. Re-evaluating a clean transaction still changed its score **60.00 -> 100.00** without new activity. These are separate presence, success, and failure observations.

The initial tooling run is preserved at `evidence/regression/20261020-101816-092-0d7649ea/` (Standalone 795/0 before the final safety tests were all discovered; Integrated 831/1; release 311/0; Quick passed). The final complete run above includes all added safety tests. No earlier measurement was relabeled or erased.

### Destructive-path refusal proofs

Four independent negative executions all exited 1 with the expected refusal, before destructive/workload dispatch:

1. Reusing the live final namespace: `tests/run_regression.ps1 -IsolatedPrefix bank_a_ci_20261020_tooling2 -SkipQuick` -> existing database refused. Its separate expected-failure report is `evidence/regression/20261020-102354-565-b3391083/summary.md`.
2. Rebuild with a deliberately wrong owner token -> database not owned by this run; refused.
3. Standalone plus IndexProfile Optimized -> Integrated required; refused before DROP.
4. Isolated aggregate without Quick -> full drivers not isolated-target certified; refused.

Detailed stdout/stderr: `evidence/tooling-20261020/{existing-target-refusal,wrong-owner-refusal,standalone-optimized-refusal,isolated-full-refusal}.txt`. These expected failures are safety successes, not product acceptance passes or hidden regression failures.

## Evidence and preservation

- `evidence/tooling-20261020/regression-final.txt`: top-level console output.
- `evidence/regression/20261020-102316-264-6d7d94e0/`: full suite logs, B0 snapshots, static/signature checks, runtime acceptance probes, release results, seven-index inventory, and invariant outputs.
- `evidence/quick/20261020-102631-743-301a7bca/`: actual concurrent SQL, stdout/stderr, atomicity and invariant results. Initial Quick evidence is in the separate 102215 directory.
- `evidence/tooling-20261020/`: independent static/negative tests, parser result, protected before/after sensors, cleanup verification.
- All build/tests/experiments PowerShell files parsed with **0 errors**. Git whitespace checks passed.
- Before/after **18 core table checksums** across bank_txn and bank_txn_scratch matched. bank_lab Experiment_Log count **3944** and Test_Results count **11452** were unchanged. Monitored global transaction isolation/deadlock-log/monitor settings matched. No write payload targeted these protected schemas.
- Final cleanup: **0 isolated databases / 0 reserved temporary test users remaining**. No global B roles were created or altered by this task.
- Git confirms tracked historical evidence, all banking sources and all B source/test files listed above are unchanged. Existing untracked review evidence was preserved. New measurements are append-only directories.

## Files changed or created

- Build: `build/file_order.txt`, `build/mysql_common.ps1`, `build/rebuild.ps1`, `build/run_all.sql`; new `build/run_all_optimized.sql`.
- Tests: `tests/run_regression.ps1`, `tests/run_tests.ps1`, `tests/run_release.ps1`, `tests/schema/03_source_order.ps1`, `tests/procedures/15_reconcile_scratch.ps1`, `tests/procedures/18_release_strip.ps1`; new `tests/component_tests.csv`, `tests/runtime_acceptance.ps1`, `tests/schema/05_isolated_context.ps1`, `tests/schema/06_quick_arguments.ps1`.
- A experiments: `experiments/run_all_auto.ps1`, `experiments/lib/Common.ps1`; new `experiments/run_quick.ps1`. No full experiment implementations or existing RESULTS were changed.
- Documentation: README A section; Member A REQUESTS_TO_B, WORKBENCH_RUNBOOK; historical notices on PROMPT6_DELIVERY, INTEGRATION_FINDINGS and status_report; new ISOLATED_REGRESSION and this report.
- Evidence: new tooling, regression and Quick run directories described above. Generated release SQL remains ignored under build/release/.

## Remaining blockers and coordination

**Member B:** resolve scoring expectation/implementation, feedback drift, reviewed view identity/privilege defects, and missing public EXECUTE grants. Provide target-aware RBAC deployment and restricted-role behavior tests. Supply seven SPEC functions or obtain an explicit approved interface change. Clarify rule-parameter/credit-leg policy and missing benchmark/generator/EXP-11..15 scope. B files were not patched, and assertions were not weakened.

**Member A integration:** the six requested tooling corrections are implemented and measured. Future B-only tests must be registered in the mode manifest; future scripts must honor isolated context before joining the isolated aggregate. The explicit profile interface is ready for B benchmark coordination without changing index definitions. Rerun this same isolated regression after B fixes; do not waive its current failures.

**NEEDS MANUAL VERIFICATION / not run here:** repaired B restricted-role acceptance, Workbench GUI, crash/restart/PITR demonstrations and full experiment/performance workloads. Quick is a measured bounded smoke profile, not certification of the entire experiment matrix. Optional loaders/features remain deferred. Public banking contracts, corrected ordered locking and audit behavior remain preserved.
