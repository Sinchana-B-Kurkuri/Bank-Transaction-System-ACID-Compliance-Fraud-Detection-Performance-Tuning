# EXP-10: deadlocks

Owner A. LAB ONLY — never ship. Create, detect, contrast, retry and prevent genuine lock cycles.

## Hypothesis
HYPOTHESIS — not yet measured: Naive ordering can deadlock; retry rows survive rollback; ordered locking removes this two-row cycle.

## Prerequisites
MySQL 8.x; Windows PowerShell 5.1; BANK_MYSQL_CNF points to an existing local option file. Rebuild with Standalone -WithSeed, then install lab_objects/install.sql and setup_lab_accounts.sql. Default automated target is disposable bank_txn_scratch; drivers rebuild it. No B schema files are changed.

## Manual two-window procedure
1. At wall clock t+0 record SELECT VERSION(), NOW(6), CONNECTION_ID(); in both windows. Set session isolation to the level under test before START TRANSACTION. SOURCE this folder's setup.sql in each window (a new session does not inherit @variables).
2. A/B start opposing transfers at t+0; driver captures granted locks t+1.5; first-lock scheduling pause makes cycle reproducible.
3. Execute sessionA.sql/sessionB.sql in that order with the stated offsets; retain stderr and timestamps. The manual session files state individual actions; shared driver contains the complete four-level schedule and machine checks.
4. Capture a screenshot including MySQL version, visible timestamp, both connection IDs and outputs; save as evidence/EV-EXP10-<n>.png. Raw CLI evidence is sufficient for automated runs; screenshots require manual capture.
5. Run teardown.sql; unsafe EXP04 changes must be discarded by rebuilding, never by editing immutable ledger rows.

## Automated
powershell -NoProfile -File experiments/EXP-10_deadlocks/run_auto.ps1

Correction verification (50 calls per session per mode; fresh native sessions):

    powershell -NoProfile -File experiments/EXP-10_deadlocks/run_auto.ps1 -EvidencePrefix EV-EXP10-corrected-1 -RequireOrderedZero
    powershell -NoProfile -File experiments/EXP-10_deadlocks/run_auto.ps1 -EvidencePrefix EV-EXP10-corrected-2 -RequireOrderedZero

EvidencePrefix keeps corrected comparison files separate from EV-EXP10-compare.md and the original raw run. RequireOrderedZero checks both zero ordered deadlocks and full ordered completion, after retaining actual output and restoring the routine/globals; it raises an error if the requirement is not met. Naive errors must still be genuine native 1213, never a simulated SIGNAL.

The original nine-deadlock ordered graph was an S-to-X conversion cycle: preliminary account EXISTS expressions held S locks before the first ordered FOR UPDATE. The corrected helper uses the locking reads themselves for existence checks. diagnose_ordered_lock.ps1 pauses before the first exclusive read in archived-original and corrected helpers; it observed two shared records in the former and zero in the latter. This is a diagnostic scheduling pause, not a manufactured error. Shipping DDL is restored and lab routines removed in finally. Original measurements and their SHA256 manifest are under evidence/EXP10-lock-fix/original/. See docs/member-a/EXP10_ORDERED_LOCK_FIX.md for current measured results and limitations.

Drivers retain expanded per-session SQL, stdout/stderr, native errors and META server/version/time/connection ID in evidence/raw/EXP-10/<timestamp>/. No result is inferred from a hypothesis. RESULTS.md is written only after a successful measured run; failed runs retain raw evidence and the summary records failure.

## Scheduling probe
The original mode-3 hook sleeps only after both account locks are held. The automated driver temporarily adds a mode-3-only sleep immediately after the first lock in the DATABASE object sp_internal_post_transfer (not its source file), then restores the original DDL in finally. This widens an existing scheduling race, does not inject SQL errors and is disclosed in evidence. CREATE uses 3 seconds; HANDLE uses 0.05 seconds. Public transfer/retry procedures still execute and actual InnoDB 1213 errors are required. A cycle can disappear too quickly for data_lock_waits; INNODB STATUS retains the detected cycle. Ordered mode 2 has no first-lock pause. Manual A/B files without this probe may serialize; that is not evidence of a deadlock.
