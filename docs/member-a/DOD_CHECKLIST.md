# Definition-of-Done self-audit — Member A

No separate plan/coverage-matrix/Definition-of-Done source was supplied. These lines cover every A-relevant requirement explicitly present in Prompts 1–6 and SPEC. They do not impersonate a missing formal checklist. See status_report.md and the latest timestamped regression summary for executed results.

| A-relevant DoD line | Status | Evidence / limitation |
|---|---|---|
| Nine core tables, named constraints, conditional cross-module FKs, lab helpers | LOCALLY TESTED | Both build modes/full schema suite; baseline and contract checks |
| Schema freeze, exact signatures/errors and ownership | LOCALLY TESTED / DOCUMENTED | No banking object altered; SPEC-derived parameter check; source ownership audit |
| Six functions and actor resolver | LOCALLY TESTED | Both complete suites, restricted real logins and exact USER() capture |
| Nine audit/six guard triggers, watermark, immutable ledger/audit | LOCALLY TESTED | Trigger tests, I4, EXP-17 recorded gap/JSON/actor checks |
| All public procedures plus private helpers, safe transaction boundaries and failure rows | LOCALLY TESTED | Both development suites and actual release procedure suite; no private grants |
| Corrected deterministic lock sequence retained | LOCALLY TESTED (regression); historical real-session proof preserved | Source untouched; ordered missing-second-read rollback test; EV-EXP10-corrected-1/2-compare.md |
| Tiny seed idempotency and six reconciliation invariants | LOCALLY TESTED | Seed/function tests and each mode/final invariant logs |
| Standalone and real B table integration | LOCALLY TESTED | Explicit mode rebuilds; real-B CHECK/FK probes; standalone differences reported |
| Real B fraud evaluator/trigger integration including ordering and rollback | BLOCKED | B files absent; requests P6-01/P6-03 |
| Actual B RBAC/views/privacy policy integration | BLOCKED | B files/tests absent; A restricted-user tests are not B role certification |
| Current aggregate Quick experiment run | BLOCKED | Unsupported parameter; no unsafe ignored-switch or Standalone substitute |
| EXP-01/02/04–10 concurrency measurements | HISTORICALLY LOCALLY TESTED | Existing raw native-session evidence retained, not rerun or relabeled as current integrated runtime |
| EXP-03 real durability crash | IMPLEMENTED / NEEDS MANUAL VERIFICATION | Preparation/dry-run/rollback tested; two mysqld PIDs; no crash performed |
| EXP-16 dump restore and native checksum comparison | LOCALLY TESTED WITH LIMIT | Measured dump-only recovery; eight checksums match, Audit_Log normalized equality only |
| EXP-16 PITR before loss/operator error | IMPLEMENTED / NEEDS MANUAL VERIFICATION | Local binlog read blocked; no invented RTO/RPO or replay pass |
| EXP-17 expected/actual auditing, JSON, actors, privileged limit | HISTORICALLY LOCALLY TESTED plus current DB regression | 74/0 historical run; nine assertions join both full suites; no claim of tamper-proof DBA auditing |
| Release hooks removed without signature/locking change | LOCALLY TESTED | EV-REL-1.txt, generated SQL scan, routine identity assertion after each procedure test |
| Reproducible CLI/Workbench runbook and bus-factor instructions | IMPLEMENTED / CLI LOCALLY TESTED | README, file_order, WORKBENCH_RUNBOOK; GUI remains manual |
| Final interfaces/decision status/error and RBAC allowlist docs | IMPLEMENTED / signatures LOCALLY TESTED | interfaces.md, append-only decisions.md; no B grants invented |
| ER core/interface diagram matches real schema | LOCALLY TESTED | 15 entities, 117 columns, 25 FKs checked against information_schema |
| Review 1 change list and binary updates | TEXT IMPLEMENTED / binaries NEEDS MANUAL VERIFICATION | CORRECTIONS_A.md; original binaries and exact slide numbers unavailable |
| Honest status/evidence index/final report | IMPLEMENTED | status_report, evidence_index, PROMPT6_DELIVERY; failures and blockers retained |
| No B source modified, no secrets/dumps committed, no commit/push/branch operation | LOCALLY CHECKED | Final diff/status; backup/out stays ignored; no Git write operation performed |
| All Definition-of-Done lines matched to external plan | BLOCKED / source unavailable | Need the actual plan to confirm a verbatim crosswalk |
| Optional P2 dimensions | DEFERRED | P1 blockers remain; see P2_CUTS.md for exact continuation |

No overall “DONE” declaration is made while runtime/security/Quick/manual acceptance items remain. P2/cut completion instructions are in P2_CUTS.md; B owns fraud behavior generators, PaySim, EXP-11..15 and its source. These were not implemented in A's integration task.
