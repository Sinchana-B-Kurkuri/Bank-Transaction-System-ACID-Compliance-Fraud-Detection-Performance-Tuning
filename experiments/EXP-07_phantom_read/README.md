# EXP-07: phantom_read

Owner A. LAB ONLY — never ship. Compare consistent and current reads; inspect next-key locks.

## Hypothesis
HYPOTHESIS — not yet measured: RC count changes; RR snapshot stable/current locking read sees new rows; gap and SERIALIZABLE block deposits.

## Prerequisites
MySQL 8.x; Windows PowerShell 5.1; BANK_MYSQL_CNF points to an existing local option file. Rebuild with Standalone -WithSeed, then install lab_objects/install.sql and setup_lab_accounts.sql. Default automated target is disposable bank_txn_scratch; drivers rebuild it. No B schema files are changed.

## Manual two-window procedure
1. At wall clock t+0 record SELECT VERSION(), NOW(6), CONNECTION_ID(); in both windows. Set session isolation to the level under test before START TRANSACTION. SOURCE this folder's setup.sql in each window (a new session does not inherit @variables).
2. B COUNT at t+0, A deposit t+2; B recount t+6. Separate gap case holds FOR UPDATE 6s.
3. Execute sessionA.sql/sessionB.sql in that order with the stated offsets; retain stderr and timestamps. The manual session files state individual actions; shared driver contains the complete four-level schedule and machine checks.
4. Capture a screenshot including MySQL version, visible timestamp, both connection IDs and outputs; save as evidence/EV-EXP07-<n>.png. Raw CLI evidence is sufficient for automated runs; screenshots require manual capture.
5. Run teardown.sql; unsafe EXP04 changes must be discarded by rebuilding, never by editing immutable ledger rows.

## Automated
powershell -NoProfile -File experiments/EXP-07_phantom_read/run_auto.ps1

Drivers retain expanded per-session SQL, stdout/stderr, native errors and META server/version/time/connection ID in evidence/raw/EXP-07/<timestamp>/. No result is inferred from a hypothesis. RESULTS.md is written only after a successful measured run; failed runs retain raw evidence and the summary records failure.

## InnoDB nuance
The RR second plain COUNT remains in the original snapshot, whereas SELECT ... FOR UPDATE is a current read. Compare FIRST and CURRENT values in raw output. Gap evidence must name the actual INDEX_NAME, LOCK_MODE and LOCK_DATA. The banking deposit also updates Accounts and audit rows, so capture data_lock_waits rather than assuming every wait is on the ledger gap.
