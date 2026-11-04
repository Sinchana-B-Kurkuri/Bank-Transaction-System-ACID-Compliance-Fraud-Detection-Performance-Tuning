# EXP-16 measured recovery

| Variant | Status | Dump seconds | Replay seconds | RTO seconds | RPO seconds |
|---|---|---:|---:|---:|---:|
| dump-only | FAIL | 2.535 | 0.000 | 2.538 | 33.893948 |
| before-loss | NEEDS MANUAL VERIFICATION | 1.098 | NOT YET RUN | NOT YET RUN | NOT YET RUN |

before-loss : Binlog file access denied/unavailable. Run restore_and_pitr.ps1 in an elevated shell with read access to datadir.

| before-oops | NEEDS MANUAL VERIFICATION | 1.165 | NOT YET RUN | NOT YET RUN | NOT YET RUN |

before-oops : Binlog file access denied/unavailable. Run restore_and_pitr.ps1 in an elevated shell with read access to datadir.


RPO is measured from the last recovered workload commit observation to the recorded loss time; snapshot completion is an upper bound on commit time, so these values are lower bounds on the exact commit-to-loss interval. Before-oops intentionally excludes the erroneous DELETE transaction and all later work. RTO measures dump load plus replay only (not human response or checksum verification).

Dump-only loses every post-dump transaction and corresponding audit rows. Restoring dumped triggers does not reinstall the D5 watermark; bank_lab is intentionally outside the dump. No new watermark is fabricated. Transactions cannot be deleted due to ledger immutability; the operator error targets Loans.

Binlog boundary method: record SHOW BINARY LOG STATUS immediately before DELETE, inspect SHOW BINLOG EVENTS from that position (Table_map/Delete_rows/Xid), and stop replay before that transaction. Replay SQL and dumps remain in ignored backup/out/.

## Checksums (all nine A tables)
| Variant | Table | Expected rows | Actual rows | Expected checksum | Actual checksum | Match |
|---|---|---:|---:|---|---|---|
| dump-only | Branches | 3 | 3 | 3820862213 | 3820862213 | True |
| dump-only | Employees | 5 | 5 | 3343467282 | 3343467282 | True |
| dump-only | Customers | 7 | 7 | 4187877886 | 4187877886 | True |
| dump-only | Account_Types | 3 | 3 | 3543379354 | 3543379354 | True |
| dump-only | Accounts | 108 | 108 | 2950455732 | 2950455732 | True |
| dump-only | Transactions | 121 | 121 | 1975241564 | 1975241564 | True |
| dump-only | Loans | 1 | 1 | 519280957 | 519280957 | True |
| dump-only | Fraud_Flags | 0 | 0 | 0 | 0 | True |
| dump-only | Audit_Log | 352 | 352 | 1511053436 | 3368817048 | False |