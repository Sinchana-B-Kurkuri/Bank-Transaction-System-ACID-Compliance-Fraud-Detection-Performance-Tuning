# Integration checklist — Member A

The separate “Section 6” plan was not supplied and is not in the repository. This is a traceable checklist derived from the Prompt 6 text and frozen SPEC, NOT a claimed verbatim copy of an unavailable document. Ticks below require the indicated executed command; remaining acceptance items are unticked.

- [x] Branch is feature/A-integration-docs and no branch operation performed — `git branch --show-current`; status/history/branches inspected before changes.
- [x] Real B schema distinguished from stubs — `git show --stat 0641a61`; inspected schema/01_tables/10_*..16_* and `tests/integration/07_real_b_schema.ps1` in Integrated full suite.
- [x] Standalone seeded build and complete development tests executed — `powershell -File tests/run_regression.ps1`, Standalone stage logs.
- [x] Integrated seeded build and complete development tests executed against real B tables — same command, Integrated stage logs; no B runtime stand-ins installed.
- [x] All six invariant summaries executed on both databases — same command's mode/final stages and `CALL sp_reconcile_balances(NULL)` through integration/04.
- [x] SPEC signatures and DEFINER types tested — `tests/integration/06_signature_check.sql` in both modes and release; `powershell -File tests/integration/support/Write-SignatureContract.ps1 -Check`.
- [x] Core B0 index metadata compared and nonunique FK-only rule tested — `powershell -File tests/run_regression.ps1`, both static stages compare their actual Standalone-B0.txt / Integrated-B0.txt snapshots; concrete results are in evidence/regression/20261019-225728-899/.
- [x] SOURCE existence/order, obsolete-table absence, audit USER() and released hook absence checked — tests/p6_static.ps1 and schema/03_source_order.ps1.
- [x] Release generation and actual procedure suite executed — `powershell -File tests/run_release.ps1 -Mode Integrated`; EV-REL-1.txt; nonzero lab modes return 5017 and business assertions retained.
- [x] ER schema comparison executed — `powershell -File build/write_er_core.ps1`; `powershell -File tests/integration/08_er_contract.ps1 -Database bank_txn`; 15 entities/117 columns/25 FKs, zero differences on Integrated.
- [x] Windows fallback fix exercised — `powershell -File tests/schema/04_mysql_wrapper.ps1`; five checks including missing PATH/override, spaces, stderr and recursion.
- [ ] Whole-system fraud integration accepted — BLOCKED: seven scoring functions, sp_evaluate_fraud and fraud trigger absent. Follow REQUESTS_TO_B.md; do not count schema tests as runtime tests.
- [ ] Actual B trigger FOLLOWS/audit order and flag rollback tested — BLOCKED by absent B trigger. A15 trigger inventory is not a substitute.
- [ ] B roles/views/security tests executed — BLOCKED: no source or B acceptance suite in checkout.
- [ ] Aggregate Quick experiment run with actual B runtime — BLOCKED: experiments/run_all_auto.ps1 has no Quick parameter and existing drivers rebuild Standalone. No full benchmark grid substituted.
- [ ] Complete regression exit 0 (all acceptance conditions green) — remains unticked while BLOCKED rows exist, even if executed SQL checks have zero failures.
- [ ] Workbench GUI execution verified — CLI order checked only; follow WORKBENCH_RUNBOOK.md manually.
- [ ] Crash/restart and local-binlog PITR demonstrations verified — Prompt 5 runbooks retain NEEDS MANUAL VERIFICATION; no administrative action taken here.
- [ ] Review DOCX/PPTX copies updated with exact page/slide numbers — originals missing; CORRECTIONS_A.md supplies exact textual changes by section/title only.
- [ ] Checklist reconciled against actual Section 6 plan — obtain that missing source and compare this derived checklist.
- [ ] P2 Berka implemented/tested — deliberately deferred until Part A passes; no real data or B generators added.

Final `git status --short` and source-diff audit are recorded in evidence/p6/final-status.txt. No B-owned source edits are permitted; ownership changes needed from B are requests only.
