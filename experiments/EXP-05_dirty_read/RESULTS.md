# Measured results

## Hypothesis
See README for expectations recorded before measurement.

## Procedure run
Windows PowerShell driver; independent native mysql processes. Run timestamps are in the raw directory names and session META records. Report generated 2026-10-18T22:17:53.2674143+05:30.

## Raw output paths
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-05\20261018-215342-152

## Actual
RESULT|EXP-05|READ UNCOMMITTED|anomaly|OBSERVED
RESULT|EXP-05|READ COMMITTED|anomaly|NOT OBSERVED
RESULT|EXP-05|REPEATABLE READ|anomaly|NOT OBSERVED
RESULT|EXP-05|SERIALIZABLE|anomaly|BLOCKED

## Match?
RU exposed the uncommitted value; RC/RR did not. SERIALIZABLE protected the read by blocking until 1205.

## Notes
Session SQL, stdout and stderr retained; META includes server version, time and connection ID.
