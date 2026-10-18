# Measured results

## Hypothesis
See README for expectations recorded before measurement.

## Procedure run
Windows PowerShell driver; independent native mysql processes. Run timestamps are in the raw directory names and session META records. Report generated 2026-10-18T22:35:33.4956963+05:30.

## Raw output paths
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-10\20261018-223504-859

## Actual
RESULT|EXP-10|CREATE|victim_errno|1213
RESULT|EXP-10|DETECT|error_log|NEEDS MANUAL VERIFICATION: performance_schema returned no deadlock rows; datadir error log access denied
RESULT|EXP-10|CONTRAST|errno|1205
RESULT|EXP-10|MODE-3|deadlocks|45
RESULT|EXP-10|MODE-3|success|94/100
RESULT|EXP-10|MODE-3|retry_exhausted|6
RESULT|EXP-10|MODE-2|deadlocks|0
RESULT|EXP-10|MODE-2|success|100/100
RESULT|EXP-10|MODE-2|retry_exhausted|0

## Match?
A real 1213 and separate 1205 were required. Retry success/exhaustion and ordered-mode deadlocks are measurements, not assumed to be zero. Error-log capture may still need administrator verification.

## Notes
Session SQL, stdout and stderr retained; META includes server version, time and connection ID.

## Correction verification — two independent runs

| Measurement | Original | Corrected 1 | Corrected 2 |
|---|---:|---:|---:|
| Naive deadlocks | 54 | 43 | 45 |
| Naive successful calls | 97/100 | 94/100 | 94/100 |
| Naive exhausted calls | 3 | 6 | 6 |
| Ordered deadlocks | 9 | **0** | **0** |
| Ordered retry rows | 9 | **0** | **0** |
| Ordered successful calls | 100/100 | **100/100** | **100/100** |
| Ordered exhausted calls | 0 | **0** | **0** |

Both corrected runs passed RequireOrderedZero and all six invariants. Full regression: 734 PASS, 0 FAIL. Raw corrected runs: evidence/raw/EXP-10/20261018-223416-983/ and 20261018-223504-859/. The original results and SHA256 manifest are preserved under evidence/EXP10-lock-fix/original/. The original raw nine-deadlock run remains unchanged.

Root cause and precise correction: docs/member-a/EXP10_ORDERED_LOCK_FIX.md. The original prevention target is now met for this repeated workload. Native server error-log file access remains NEEDS MANUAL VERIFICATION; this does not replace the captured actual 1213, 1205, lock snapshots or InnoDB graphs.