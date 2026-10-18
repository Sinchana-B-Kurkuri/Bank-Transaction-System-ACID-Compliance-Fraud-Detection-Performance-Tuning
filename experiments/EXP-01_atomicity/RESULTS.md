# Measured results

## Hypothesis
See README for expectations recorded before measurement.

## Procedure run
Windows PowerShell driver; independent native mysql processes. Run timestamps are in the raw directory names and session META records. Report generated 2026-10-18T22:19:16.5380576+05:30.

## Raw output paths
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-01\20261018-221911-398

## Actual
RESULT|EXP-01|ALL|iterations|200
RESULT|EXP-01|ALL|partial_transfers|0
RESULT|EXP-01|ALL|kill_snapshot_unchanged|YES

## Match?
Matched if partial_transfers=0 and kill_snapshot_unchanged=YES; the driver asserted both and all six invariants.

## Notes
Session SQL, stdout and stderr retained; META includes server version, time and connection ID.
