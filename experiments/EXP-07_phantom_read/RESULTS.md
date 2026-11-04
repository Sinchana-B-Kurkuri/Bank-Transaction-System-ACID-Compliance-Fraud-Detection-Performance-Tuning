# Measured results

## Hypothesis
See README for expectations recorded before measurement.

## Procedure run
Windows PowerShell driver; independent native mysql processes. Run timestamps are in the raw directory names and session META records. Report generated 2026-10-18T22:17:53.2112245+05:30.

## Raw output paths
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-07\20261018-215504-624

## Actual
RESULT|EXP-07|READ UNCOMMITTED|anomaly|OBSERVED
RESULT|EXP-07|READ COMMITTED|anomaly|OBSERVED
RESULT|EXP-07|REPEATABLE READ|anomaly|NOT OBSERVED (nuance)
RESULT|EXP-07|SERIALIZABLE|anomaly|BLOCKED
RESULT|EXP-07|REPEATABLE READ|gap_writer|BLOCKED

## Match?
RC observed a phantom; InnoDB RR snapshot remained stable while the locking current read saw an added row. Gap and SERIALIZABLE schedules blocked the writer.

## Notes
Session SQL, stdout and stderr retained; META includes server version, time and connection ID.
