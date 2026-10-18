# EXP-16 measured recovery

| Variant | Status | Dump seconds | Replay seconds | RTO seconds | RPO seconds |
|---|---|---:|---:|---:|---:|
| dump-only | PASS (JSON-normalized; native checksum differs) | 2.854 | 0.000 | 2.857 | 21.159330 |
| before-loss | NEEDS MANUAL VERIFICATION | 1.156 | NOT YET RUN | NOT YET RUN | NOT YET RUN |
| before-oops | NEEDS MANUAL VERIFICATION | 1.237 | NOT YET RUN | NOT YET RUN | NOT YET RUN |

## Notes

dump-only Audit_Log native checksum differs; semantic comparison of every field in every row found 0 differences. Opaque MySQL DATE/DATETIME/DECIMAL JSON values become text representations during SQL dump/load. Native checksum match is FALSE; this is explicitly not an all-checksums-match claim.
before-loss : Binlog file access denied/unavailable. Run restore_and_pitr.ps1 in an elevated shell with read access to datadir.
before-oops : Binlog file access denied/unavailable. Run restore_and_pitr.ps1 in an elevated shell with read access to datadir.

RPO is measured from the last recovered workload commit observation to the recorded loss time; snapshot completion is an upper bound on commit time, so these values are lower bounds on the exact commit-to-loss interval. Before-oops intentionally excludes the erroneous DELETE transaction and all later work. RTO measures dump load plus replay only (not human response or checksum verification).

Dump-only lost 501 post-dump ledger rows and 1003 post-dump audit rows in this run. Restoring dumped triggers does not reinstall the D5 watermark; bank_lab is intentionally outside the dump. No new watermark is fabricated. Transactions cannot be deleted due to ledger immutability; the operator error targets Loans.

Binlog boundary method: record SHOW BINARY LOG STATUS immediately before DELETE, inspect SHOW BINLOG EVENTS from that position (Table_map/Delete_rows/Xid), and stop replay before that transaction. Replay SQL and dumps remain in ignored backup/out/.

## Checksums (all nine A tables)
| Variant | Table | Expected rows | Actual rows | Expected checksum | Actual checksum | Match |
|---|---|---:|---:|---|---|---|
| dump-only | Branches | 3 | 3 | 3820862213 | 3820862213 | True |
| dump-only | Employees | 5 | 5 | 3343467282 | 3343467282 | True |
| dump-only | Customers | 7 | 7 | 3807025148 | 3807025148 | True |
| dump-only | Account_Types | 3 | 3 | 3543379354 | 3543379354 | True |
| dump-only | Accounts | 108 | 108 | 2950455732 | 2950455732 | True |
| dump-only | Transactions | 121 | 121 | 1610127366 | 1610127366 | True |
| dump-only | Loans | 1 | 1 | 519280957 | 519280957 | True |
| dump-only | Fraud_Flags | 0 | 0 | 0 | 0 | True |
| dump-only | Audit_Log | 352 | 352 | 1444727470 | 658478443 | False |