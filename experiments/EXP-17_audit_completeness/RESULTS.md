# Measured results

## Hypothesis
See README for expectations recorded before measurement.

## Procedure run
Windows PowerShell driver; independent native mysql processes. Run timestamps are in the raw directory names and session META records. Report generated 2026-10-18T23:18:20.9911281+05:30.

## Raw output paths
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-17\20261018-231759-061

## Actual
LOCALLY TESTED: 74 PASS / 0 FAIL; driver exit 0. Each restricted login executed open/deposit/withdraw/transfer/routed-loan, with derived totals 3+2+2+4+3=14 audit events: 28 committed procedure audit rows for the two logins. Five additional raw DBA events were observed transactionally and rolled back: Loans INSERT/UPDATE/DELETE, Accounts UPDATE and Transactions INSERT. Their individual table/action counts and JSON snapshots are retained. Per-operation groups/totals, JSON, identities, rejected DML and immutability assertions passed.
LOCALLY TESTED: DBA-disabled trigger gap demonstrated; D5 watermark respected; six invariants PASS.
Temporary users and mappings removed in finally. See EV-EXP17-counts.md and EV-EXP17-json.txt.

## Match?
Matched for this measured workload, including the deliberately missing audit trail when triggers were disabled. Reinstallation scoped I4 to the new D5 watermark. This does not establish protection against privileged DDL.

## Notes
Real native restricted sessions were used. The executed statement plans are in mutations.ps1; database assertions, individual DBA action counts, JSON, version/time metadata, gap evidence, watermark and invariant output are retained. Final users/maps were zero; no passwords are in files. Complete regression also passed 743 tests with zero failures after adding these DB assertions.
