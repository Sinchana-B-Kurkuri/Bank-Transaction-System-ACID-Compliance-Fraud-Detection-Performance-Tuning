# EXP-02: consistency

Owner A. LAB ONLY — never ship. Exercise procedure validation, constraints and immutability.

## Hypothesis
HYPOTHESIS — not yet measured: Every documented rejection returns its expected MySQL errno.

## Prerequisites
MySQL 8.x; Windows PowerShell 5.1; BANK_MYSQL_CNF points to an existing local option file. Rebuild with Standalone -WithSeed, then install lab_objects/install.sql and setup_lab_accounts.sql. Default automated target is disposable bank_txn_scratch; drivers rebuild it. No B schema files are changed.

## Manual two-window procedure
1. At wall clock t+0 record SELECT VERSION(), NOW(6), CONNECTION_ID(); in both windows. Set session isolation to the level under test before START TRANSACTION. SOURCE this folder's setup.sql in each window (a new session does not inherit @variables).
2. A runs integration/03_exp02.sql; B reads bank_lab.Test_Results at t+1.
3. Execute sessionA.sql/sessionB.sql in that order with the stated offsets; retain stderr and timestamps. The manual session files state individual actions; shared driver contains the complete four-level schedule and machine checks.
4. Capture a screenshot including MySQL version, visible timestamp, both connection IDs and outputs; save as evidence/EV-EXP02-<n>.png. Raw CLI evidence is sufficient for automated runs; screenshots require manual capture.
5. Run teardown.sql; unsafe EXP04 changes must be discarded by rebuilding, never by editing immutable ledger rows.

## Automated
powershell -NoProfile -File experiments/EXP-02_consistency/run_auto.ps1

Drivers retain expanded per-session SQL, stdout/stderr, native errors and META server/version/time/connection ID in evidence/raw/EXP-02/<timestamp>/. No result is inferred from a hypothesis. RESULTS.md is written only after a successful measured run; failed runs retain raw evidence and the summary records failure.
