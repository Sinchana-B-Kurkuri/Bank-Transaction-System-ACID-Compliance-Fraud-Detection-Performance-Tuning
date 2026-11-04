# EXP-03 results

## Hypothesis
Committed deposits survive a mysqld process crash; the uncommitted deposit is absent after recovery. This is not proof against OS/power failure.

## Procedure run
LOCALLY TESTED on MySQL 8.4.11, 2026-10-18: setup committed 100 deposits of 3.00 and opened connection 6457 (client PID 17520) with a separate uncommitted deposit of 7.00. The default crash driver was invoked without -Execute. Teardown killed only connection 6457 and all six invariants passed after rollback. No mysqld process or service was stopped.

## Raw output paths
evidence/raw/EXP-03/20261018-230805-373/; evidence/EV-EXP03-driver.txt; evidence/EV-EXP03-dry-run.txt; evidence/EV-EXP03-teardown.txt.

## Actual
Measured settings: innodb_flush_log_at_trx_commit=1, sync_binlog=1, innodb_doublewrite=ON, log_bin=1. Before the uncommitted transaction: Accounts checksum 1710400251; Transactions checksum 1398618177; 108 accounts totaling 100555938.00; 221 ledger rows. The second session emitted UNCOMMITTED_READY. Dry-run detected service MySQL84 and two mysqld candidates (6888, 8056); it refused to choose a PID. It printed the pending taskkill and Start-Service commands without running them.

Crash/restart: NOT YET RUN — NEEDS MANUAL VERIFICATION. No durability outcome or restart time claimed. Preparation state is historical evidence only: later recovery/regression tests rebuilt scratch. Rerun setup before any manual crash verification.

## Match?
Durability hypothesis NOT YET TESTED. Preparation, default dry-run safety and own-session rollback were observed; these are not crash-survival proof.

## Notes
Execute only in an isolated instance with the confirmation-gated -Execute script; never by the agent.
