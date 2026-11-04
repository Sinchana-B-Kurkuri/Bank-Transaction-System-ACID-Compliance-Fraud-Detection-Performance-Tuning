# Measured results

## Hypothesis
See README for expectations recorded before measurement.

## Procedure run
Windows PowerShell driver; independent native mysql processes. Run timestamps are in the raw directory names and session META records. Report generated 2026-10-18T22:17:53.2562619+05:30.

## Raw output paths
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-06\20261018-215431-512

## Actual
RESULT|EXP-06|READ UNCOMMITTED|anomaly|OBSERVED
RESULT|EXP-06|READ COMMITTED|anomaly|OBSERVED
RESULT|EXP-06|REPEATABLE READ|anomaly|NOT OBSERVED
RESULT|EXP-06|SERIALIZABLE|anomaly|BLOCKED

## Match?
RU/RC values changed, RR remained stable, and SERIALIZABLE blocked the writer (1205).

## Notes
Session SQL, stdout and stderr retained; META includes server version, time and connection ID.
