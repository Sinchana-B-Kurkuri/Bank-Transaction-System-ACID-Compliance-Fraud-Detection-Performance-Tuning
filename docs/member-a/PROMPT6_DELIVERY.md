> Historical report: the 2026-10-19 runtime-absence findings below describe the pre-PR7 checkout. For current PR7 failures and Member A tooling corrections, see PROMPT6_TOOLING_DELIVERY.md and ISOLATED_REGRESSION.md. Whole-system acceptance remains blocked.

# Prompt 6 delivery — 2026-10-19

The available A implementation integrates successfully with B's **actual seven table definitions**, with no changes to banking procedure contracts, corrected ordered locking, schema, functions or triggers. Whole-system acceptance is **BLOCKED**, because this checkout/develop does not contain B's fraud/security runtime or its tests. No stubs were used for the Integrated build, and no substitute B fraud/security implementation was invented.

Branch: feature/A-integration-docs; inspected HEAD 7c50b73. Clean tree at task start. No commit, push, merge, branch creation or switch. Only authorized A-owned files changed. The B schema merge 0641a61 is real but contains seven tables and cross-platform wrapper/build changes, not the rest of the claimed B module.

## Actual results

| Deliverable | Status | Observed result |
|---|---|---|
| Seeded Standalone full development suite | LOCALLY TESTED | **788 PASS / 0 FAIL** |
| Seeded Integrated full development suite | LOCALLY TESTED | **797 PASS / 0 FAIL**, using real B files 10–16 |
| Actual release procedure suite on scratch | LOCALLY TESTED | **311 PASS / 0 FAIL**; release routines stayed installed after each test file |
| Static/source/B0 checks | LOCALLY TESTED | **10 PASS / 0 FAIL per mode**; all active SOURCE paths exist and follow the Workbench list; core snapshot has 36 index-column records |
| Six invariants | LOCALLY TESTED | I1, I1b, I2, I3, I4, I5 PASS in both modes, release and both final databases |
| Public SPEC signatures / DEFINER | LOCALLY TESTED | All 17 public routines; 34 checks in each applicable suite; fixture generated from SPEC, not installed routines |
| Real B extra constraints | LOCALLY TESTED | Ten CHECK/FK probes; standalone boundary explicitly reported rather than emulated |
| ER | IMPLEMENTED / LOCALLY TESTED | 15 core/interface entities, 117 columns/types/nullability and 25 FKs; zero Integrated differences; two requester FK differences disclosed for standalone |
| Wrapper fallback | LOCALLY TESTED | Five probes in Windows PowerShell 5.1, including no PATH/override, paths with spaces and original stderr retention |
| B runtime/security/Quick acceptance | BLOCKED | Four blocked orchestration rows; final runner exit **2**, not a green completion claim |
| Documentation/checklists/viva/evidence index | IMPLEMENTED | Final interfaces/allowlist, append-only decision statuses, runbooks, ER/review correction list, status/evidence/DoD/cut lists |
| Workbench GUI / original binary edits | NEEDS MANUAL VERIFICATION | CLI order tested only; no original DOCX/PPTX or exact slide/page numbers supplied |
| Crash/PITR | NEEDS MANUAL VERIFICATION | Historical preparation/dump restore retained; no crash, elevated replay or new administrative action executed |
| Part B P2 | NOT IMPLEMENTED / DEFERRED | Part A blockers remain; A-ready notes only in P2_CUTS.md |

Counts are reported per suite, not summed as unique cases. Historical native EXP-01..10/16/17 measurements are preserved and labeled historical; no fresh integrated concurrency run, full throughput grid or unrelated experiment was substituted for missing Quick integration.

## Commands and evidence

```powershell
git branch --show-current
git status --short
git log --oneline -20
git branch -a
powershell -NoProfile -File build/rebuild.ps1 -Database bank_txn -Mode Integrated -WithSeed
powershell -NoProfile -File tests/run_tests.ps1 -Database bank_txn -NoRebuild
powershell -NoProfile -File tests/integration/support/Write-SignatureContract.ps1
powershell -NoProfile -File build/write_er_core.ps1 -Database bank_txn
powershell -NoProfile -File tests/schema/04_mysql_wrapper.ps1
powershell -NoProfile -File tests/run_release.ps1 -Mode Integrated
powershell -NoProfile -File tests/run_regression.ps1
powershell -NoProfile -File build/release_strip_lab_hook.ps1
git status --short
```

Final measured orchestrator: **evidence/regression/20261019-225728-899.md**, raw stage directory of the same name, and evidence/p6/regression-driver-final.txt. Direct release proof: evidence/EV-REL-1.txt (copied into the run directory). Final objects/engine/routine/trigger inventory, globals and temporary-user cleanup: evidence/p6/final-database-inventory.txt. Both final banking databases contain zero lab routines; temporary zz_a_* users remaining=0. bank_txn is Integrated development; scratch remains an Integrated release database.

Initial raw Integrated regression was 750/0 before the new signature/real-B/ER/fallback cases were included. The first orchestrator run (20261019-220227-017) retained two static-stage failures caused by my new query to a nonexistent information_schema.ROUTINE_PRIVILEGES table. I inspected MySQL's actual mysql.procs_priv columns and corrected that A-owned check; the complete final orchestrator rerun has zero failed stages. The initial failed report/logs were retained, not relabeled as passing.

The wrapper's previous `$IsWindows` condition did not work in Windows PowerShell 5.1. The one-line platform check now uses Environment.OSVersion.Platform, preserving B's mysql/mysql.exe and explicit override discovery. The isolated probe validates this without a credential copy. Original stdout/stderr handling and BANK_MYSQL_CNF/BIN isolation are retained.

## Files

Changed existing A files: README Member A sections; build/file_order.txt (B ownership/mode annotations), build/mysql_common.ps1 (5.1 fallback), build/rebuild.ps1 (temporary test-only mode inheritance); docs/interfaces.md A sections; docs/decisions.md A append-only statuses; docs/member-a/REQUESTS_TO_B.md; tests/schema/04_mysql_wrapper.ps1.

Added scripts/tests: build/write_er_core.ps1; tests/run_regression.ps1; tests/run_release.ps1; tests/p6_static.ps1; tests/integration/06_signature_check.sql; support/Write-SignatureContract.ps1; 07_real_b_schema.ps1; 08_er_contract.ps1. Release generation remains in ignored build/release/. The release test adapter changes only lab-specific expectations to 5017, preserving business assertions; two self-rebuilding development harnesses are explicitly excluded from the release target and are tested in both development suites.

Added documentation: docs/er/er_core.mmd; docs/review1/CORRECTIONS_A.md; Member A INTEGRATION_FINDINGS, WORKBENCH_RUNBOOK, status_report, evidence_index, INTEGRATION_CHECKLIST, VIVA_QUESTIONS, DOD_CHECKLIST, P2_CUTS and this delivery report. New measurement inventory is evidence/p6/files.txt. Tracked historical evidence overwritten by legacy tests was archived under the timestamped generated directories and restored to its original content. No old experiment/audit measurement or B file was changed.

## Remaining blockers and requests

1. **B fraud runtime:** seven functions, sp_evaluate_fraud and fraud trigger absent. B must supply sources and behavior tests; real detector output is not established by manually inserted Fraud_Flags fixtures.
2. **B trigger ordering/rollback:** no fraud trigger means no actual FOLLOWS/ACTION_ORDER or flag-rollback acceptance run. Requirement remains unchanged.
3. **B RBAC/views:** no executable security/views scripts or B role acceptance tests. Existing A restricted-user tests prove A authorization/attribution only. The final public-only EXECUTE allowlist is documented; never grant sp_internal_*.
4. **Quick orchestration:** experiments/run_all_auto.ps1 has no Quick parameter and its drivers rebuild Standalone. Passing an ignored switch could run the full workload and overwrite historical experiment reports. That file is outside Prompt 6's allowed edit paths; no such edit or unsafe full substitute was made. P2 stays deferred.

B requests are recorded in REQUESTS_TO_B.md, including absent benchmarks/indexes/generators/EXP-11..15. No B-owned source change was made. Original Review binaries, external coverage matrix/Section 6 plan and separate formal DoD are missing; provided checklists are explicitly derived from the supplied Prompt/SPEC, not claimed exact copies. Obtain those sources for page/slide numbering and formal crosswalk verification.

The final regression is therefore **executed SQL checks passed, four acceptance blockers outstanding**, not “all project deliverables done.”
