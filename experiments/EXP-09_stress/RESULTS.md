# Measured results

## Hypothesis
See README for expectations recorded before measurement.

## Procedure run
Windows PowerShell driver; independent native mysql processes. Run timestamps are in the raw directory names and session META records. Report generated 2026-10-18T22:17:53.3072093+05:30.

## Raw output paths
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-09\20261018-215543-477
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-09\20261018-215557-946

## Actual
Run with 20 concurrent sessions:
RESULT|EXP-09|ALL|parallel|20
RESULT|EXP-09|ALL|iterations_each|50
RESULT|EXP-09|ALL|successful|1000
RESULT|EXP-09|ALL|errors|0
RESULT|EXP-09|ALL|seconds|5.8121539
Run with 50 concurrent sessions:
RESULT|EXP-09|ALL|parallel|50
RESULT|EXP-09|ALL|iterations_each|50
RESULT|EXP-09|ALL|successful|2500
RESULT|EXP-09|ALL|errors|0
RESULT|EXP-09|ALL|seconds|12.0218262

## Match?
All six invariants passed. Worker successes/errors and expected call totals were checked; throughput has no predefined target.

## Notes
Session SQL, stdout and stderr retained; META includes server version, time and connection ID.
