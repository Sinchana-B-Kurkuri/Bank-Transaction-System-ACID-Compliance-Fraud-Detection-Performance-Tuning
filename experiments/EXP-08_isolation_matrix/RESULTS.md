# Measured results

## Hypothesis
See README for expectations recorded before measurement.

## Procedure run
Windows PowerShell driver; independent native mysql processes. Run timestamps are in the raw directory names and session META records. Report generated 2026-10-18T22:17:53.3086246+05:30.

## Raw output paths
evidence/raw/EXP-08/20261018-220704-145/ (full)
evidence/raw/EXP-08/20261018-220831-714/ (latest Quick)

## Actual
RESULT|EXP-08|FULL|settings|16
RESULT|EXP-08|FULL|successful_transfers|9600
RESULT|EXP-08|QUICK|settings|4
Native mysqlslap timing disagreement is flagged; server mean CALL latency measured separately.

## Match?
Throughput is a measured workload result with no assumed winning isolation level; see CSV. Matrix differences from textbook minimum guarantees are flagged explicitly.

## Notes
Session SQL, stdout and stderr retained; META includes server version, time and connection ID.
