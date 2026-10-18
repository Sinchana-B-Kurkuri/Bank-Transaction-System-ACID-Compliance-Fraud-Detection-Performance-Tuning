# Measured results

## Hypothesis
See README for expectations recorded before measurement.

## Procedure run
Windows PowerShell driver; independent native mysql processes. Run timestamps are in the raw directory names and session META records. Report generated 2026-10-18T22:17:53.2755834+05:30.

## Raw output paths
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-04\20261018-215039-090

## Actual
RESULT|EXP-04|READ UNCOMMITTED|naive|OBSERVED
RESULT|EXP-04|READ UNCOMMITTED|naive-balances|expected=999700;actual=999800.00;committed_amount=300
RESULT|EXP-04|READ UNCOMMITTED|atomic|NOT OBSERVED
RESULT|EXP-04|READ UNCOMMITTED|atomic-balances|expected=999700;actual=999700.00;committed_amount=300
RESULT|EXP-04|READ UNCOMMITTED|ordered|NOT OBSERVED
RESULT|EXP-04|READ UNCOMMITTED|ordered-balances|expected=999700;actual=999700.00;committed_amount=300
RESULT|EXP-04|READ COMMITTED|naive|OBSERVED
RESULT|EXP-04|READ COMMITTED|naive-balances|expected=999700;actual=999800.00;committed_amount=300
RESULT|EXP-04|READ COMMITTED|atomic|NOT OBSERVED
RESULT|EXP-04|READ COMMITTED|atomic-balances|expected=999700;actual=999700.00;committed_amount=300
RESULT|EXP-04|READ COMMITTED|ordered|NOT OBSERVED
RESULT|EXP-04|READ COMMITTED|ordered-balances|expected=999700;actual=999700.00;committed_amount=300
RESULT|EXP-04|REPEATABLE READ|naive|OBSERVED
RESULT|EXP-04|REPEATABLE READ|naive-balances|expected=999700;actual=999800.00;committed_amount=300
RESULT|EXP-04|REPEATABLE READ|atomic|NOT OBSERVED
RESULT|EXP-04|REPEATABLE READ|atomic-balances|expected=999700;actual=999700.00;committed_amount=300
RESULT|EXP-04|REPEATABLE READ|ordered|NOT OBSERVED
RESULT|EXP-04|REPEATABLE READ|ordered-balances|expected=999700;actual=999700.00;committed_amount=300
RESULT|EXP-04|SERIALIZABLE|naive|BLOCKED
RESULT|EXP-04|SERIALIZABLE|naive-balances|expected=999900;actual=999900.00;committed_amount=100
RESULT|EXP-04|SERIALIZABLE|atomic|NOT OBSERVED
RESULT|EXP-04|SERIALIZABLE|atomic-balances|expected=999700;actual=999700.00;committed_amount=300
RESULT|EXP-04|SERIALIZABLE|ordered|NOT OBSERVED
RESULT|EXP-04|SERIALIZABLE|ordered-balances|expected=999700;actual=999700.00;committed_amount=300

## Match?
Unsafe RU/RC/RR lost updates were observed; SERIALIZABLE aborted a writer. Relative updates and ordered locks preserved balances under actual contention. See raw expected/actual balance fields.

## Notes
Session SQL, stdout and stderr retained; META includes server version, time and connection ID.
