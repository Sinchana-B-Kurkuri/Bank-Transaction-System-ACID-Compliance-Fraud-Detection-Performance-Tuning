> Historical report: the 2026-10-19 runtime-absence findings below describe the pre-PR7 checkout. For current PR7 failures and Member A tooling corrections, see PROMPT6_TOOLING_DELIVERY.md and ISOLATED_REGRESSION.md. Whole-system acceptance remains blocked.

# Member A status report — 2026-10-19

Source of rows: explicit Prompts 1–6 and frozen SPEC. A separate coverage matrix/Section 6 plan was not supplied; this is not a verbatim crosswalk to an unavailable plan. “Locally tested” distinguishes current Prompt 6 runs from historical native measurements. No human/GUI/crash/PITR demonstration is marked manually verified without observed evidence.

Final measured run: evidence/regression/20261019-225728-899.md. Standalone 788 PASS / 0 FAIL; Integrated 797 PASS / 0 FAIL; release procedures 311 PASS / 0 FAIL; static checks 10 PASS / 0 FAIL per mode; all six invariants PASS on both final databases. Orchestrator FAIL=0 / BLOCKED=4, exit 2. These counts are separate suites, not a count of unique cases added together.

| Deliverable | Implemented | Locally tested | Manually verified | Blocked | Evidence file | Notes |
|---|---|---|---|---|---|---|
| SPEC, D1–D7/A1–A17 and table contracts | Yes | Source inspection + signature checks | No | No (A contract) | SPEC.md, decisions.md, interfaces.md | Frozen SPEC unchanged |
| Environment / CLI wrapper | Yes | Yes, Windows PowerShell 5.1 | No | No | evidence/p6 logs; schema/04 test | Five probes; Windows fallback corrected; macOS not run here |
| Nine core tables/core FKs | Yes | Both modes | No | No | timestamped *-build/suite logs | Original source preserved |
| Three conditional cross-module FKs | Yes | Both modes | No | No | schema negative/structure tests | Actual Devices/Locations/Fraud_Rules in Integrated |
| bank_lab helpers | Yes | Both modes | No | No | complete suites | No B Benchmark_Results invented |
| Standalone interface stubs | Yes | Standalone | No | No | Standalone-suite.txt | Stand-ins explicitly distinguished |
| Real seven B tables | B supplied | Integrated | No | No | Integrated-suite.txt; integration/07 | Extra checks/FKs tested; Account_Risk_Profile present |
| B0 core baseline | Yes | Both modes | No | No | *-B0.txt; *-static.txt | 36 core index-column records, FK-only secondaries |
| Six A functions | Yes | Both modes | No | No | functions tests in suites | Reference generation/rounding/NULL cases |
| Actor resolver | Yes | Both modes + release | No | No | restricted-login tests; 06 signature SQL | USER() source preserved |
| Six guards/nine audit triggers | Yes | Both modes | No | No | trigger suites/static scans | Source unchanged; no CURRENT_USER audit body |
| Reference/tiny seed | Yes | Both seeded builds | No | No | build/function seed tests | Natural-key idempotency; opening ledger |
| Seventeen public procedures/private helpers | Yes | Both modes + release | No | No | suites; EV-REL-1.txt | Exact SPEC parameters and DEFINER type |
| Atomic transfer/business failure rows | Yes | Both modes | No | No | procedure/08/09 and related tests | Synthetic 1213 probes are control-flow evidence only |
| Corrected ordered locking | Yes | Regression; historical real concurrency | No | No | EV-EXP10-corrected-1/2-compare.md | Procedure source untouched; no preliminary EXISTS |
| Statements/monthly interest | Yes | Both modes + release | No | No | procedure/14/16/17 tests | Running balances and idempotency |
| I1/I1b/I2/I3/I4/I5 | Yes | Both modes/final/release | No | No | *-invariants.txt; final-*.txt | Six summaries, not five silently conflated |
| EXP-01 atomicity and owned KILL | Yes | Historical real sessions | No | No | raw/EXP-01; EV-EXP01-final-driver.txt | Not rerun as integrated fraud proof |
| EXP-02 consistency | Yes | Historical lab + current regression | No | No | integration/03_exp02.sql; EV-EXP02-1.md | Error codes measured |
| EXP-03 durability preparation/default dry-run | Yes | Historical preparation/rollback | No | No (preparation) | EV-EXP03-driver/dry-run/teardown.txt | No server crash performed |
| EXP-03 process crash/restart | Yes (guarded script) | No | No | Manual | EXP-03/RESULTS.md | Verify correct PID/service in elevated operator shell |
| EXP-04 lost updates/fixes | Yes | Historical real sessions | No | No | raw/EXP-04; RESULTS.md | No fresh Prompt 6 rerun |
| EXP-05 dirty reads | Yes | Historical real sessions | No | No | raw/EXP-05; RESULTS.md | Isolation-level outcomes retained |
| EXP-06 nonrepeatable reads | Yes | Historical real sessions | No | No | raw/EXP-06; RESULTS.md | Snapshot versus blocking outcomes |
| EXP-07 phantoms/gap locks | Yes | Historical real sessions | No | No | raw/EXP-07; RESULTS.md | RR current-read nuance retained |
| EXP-08 matrix / throughput | Yes | Historical measurements | No | No (historical scope) | EV-EXP08-matrix.md; *throughput.csv | No grid rerun in Prompt 6 |
| EXP-09 stress P20/P50 | Yes | Historical concurrent workers | No | No | EV-EXP09-20/50-driver.txt | Current regression is not a fresh stress run |
| EXP-10 deadlocks/retry/prevention | Yes | Historical corrected native runs | No | Error-log admin capture manual | EXP10_ORDERED_LOCK_FIX.md; raw graphs | Two corrected ordered runs 0 deadlocks/0 retries/100 of 100 completions each |
| EXP-16 full backup/workload/loss/dump restore | Yes | Historical real chain | No | Native JSON checksum limitation | EV-EXP16-summary.md | Dump-only RTO 2.857 s; RPO lower bound 21.159330 s; eight native matches |
| EXP-16 PITR to S1/S2 | Yes (scripts) | Replay not run | No | Binlog ACL/manual | EXP-16/RESULTS.md | No PITR RTO/RPO or operator-error recovery pass claimed |
| EXP-17 count/JSON/actor/gap/watermark | Yes | Historical 74/0 plus current DB assertions | No | No (A scope) | EV-EXP17-counts.md/json.txt; integration/05 | Temporary users/maps removed; DBA limit honest |
| P6 A1 regression orchestrator | Yes | Yes | No | Four acceptance gaps below | evidence/regression latest summary | Exit 2 distinguishes BLOCKED from passing SQL suites |
| P6 A2 release procedure suite | Yes | Yes | No | No | EV-REL-1.txt | 311 assertions in measured run; two rebuilding development harnesses excluded explicitly |
| P6 A3 Workbench ordered path | Yes | CLI order tested | No | GUI manual | WORKBENCH_RUNBOOK.md | SOURCE is CLI-only; B tables mode-tagged |
| P6 A4 final signatures/errors/grant allowlist | Yes | Parameters/DEFINER tested | No | B role deployment absent | interfaces.md; integration/06 | Public-only policy, no sp_internal_* grants |
| P6 A5 decision statuses | Yes | All IDs inspected | No | D7/A14 runtime deferred | decisions.md final appendix | Append-only A entries |
| P6 A6 ER | Yes | Real metadata checked | No GUI render | No schema difference | er_core.mmd; integration/08 | 15 entities, 117 columns, 25 FKs; two standalone requester-FK differences |
| P6 A6 Review 1 correction list | Text yes | Schema/source cross-check | No binary edit | Originals absent | CORRECTIONS_A.md | Exact pages/slide numbers not invented |
| P6 A7 README/bus-factor runbooks | Yes | CLI commands tested where reported | No GUI | Manual actions remain | README.md | Runtime estimates labeled, evidence linked |
| P6 A8 status/evidence index | Yes | Generated from observed artifacts | No | No | this file; evidence_index.md | Historical and current scopes explicit |
| P6 A9 checklist/viva | Yes, derived | Source-based answers | No external-plan comparison | Plan source absent | INTEGRATION_CHECKLIST.md; VIVA_QUESTIONS.md | No claim of exact copy of unavailable Section 6 |
| P6 A10 DoD/cut list | Yes, derived | Source/evidence audit | No external-plan comparison | Plan source absent | DOD_CHECKLIST.md; P2_CUTS.md | No overall full-project DONE claim |
| B fraud functions/evaluator | Not supplied | No | No | Yes | REQUESTS_TO_B.md P6-01 | Seven functions + sp_evaluate_fraud missing |
| B fraud trigger/order/rollback integration | Not supplied | No | No | Yes | REQUESTS_TO_B.md P6-01 | Absence is not a FOLLOWS pass |
| B RBAC/views | Not supplied | No | No | Yes | REQUESTS_TO_B.md P6-02 | Existing A auth tests do not certify B roles |
| B indexes/benchmarks/generators/EXP-11..15 | Not supplied | No | No | Yes | REQUESTS_TO_B.md P6-03 | Do not duplicate B implementation |
| Aggregate real-B Quick experiments | No supported entry point | No | No | Yes | INTEGRATION_FINDINGS.md; regression summary | Missing -Quick; drivers rebuild Standalone; no out-of-scope edits/full-grid substitute |
| Optional Berka P2 | No, notes only | No | No | Deferred until P1 passes | P2_CUTS.md | No data, staging or behavior generators added |

Current exact counts and overall FAIL/BLOCKED totals are in PROMPT6_DELIVERY.md and the latest evidence/regression timestamped report. Earlier failed orchestration evidence is retained: its new grant check queried a nonexistent information_schema table; corrected code uses the measured MySQL mysql.procs_priv schema. No original fraud/audit measurements were rewritten to hide that error.
