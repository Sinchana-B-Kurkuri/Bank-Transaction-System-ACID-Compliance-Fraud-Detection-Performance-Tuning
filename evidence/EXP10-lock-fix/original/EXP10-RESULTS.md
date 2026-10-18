# Measured results

## Hypothesis
See README for expectations recorded before measurement.

## Procedure run
Windows PowerShell driver; independent native mysql processes. Run timestamps are in the raw directory names and session META records. Report generated 2026-10-18T22:17:53.2721476+05:30.

## Raw output paths
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-10\20261018-221245-928

## Actual
RESULT|EXP-10|CREATE|victim_errno|1213
RESULT|EXP-10|DETECT|error_log|NEEDS MANUAL VERIFICATION: performance_schema returned no deadlock rows; datadir error log access denied
RESULT|EXP-10|CONTRAST|errno|1205
RESULT|EXP-10|MODE-3|deadlocks|54
RESULT|EXP-10|MODE-3|success|97/100
RESULT|EXP-10|MODE-3|retry_exhausted|3
RESULT|EXP-10|MODE-2|deadlocks|9
RESULT|EXP-10|MODE-2|success|100/100
RESULT|EXP-10|MODE-2|retry_exhausted|0
RESULT|EXP-10|PREVENT|target|TARGET NOT MET: ordered mode still had 9 deadlocks; inspect retained graph

## Match?
A real 1213 and separate 1205 were required. Retry success/exhaustion and ordered-mode deadlocks are measurements, not assumed to be zero. Error-log capture may still need administrator verification.

## Notes
Session SQL, stdout and stderr retained; META includes server version, time and connection ID.
