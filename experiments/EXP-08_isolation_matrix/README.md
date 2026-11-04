# EXP-08: isolation_matrix

Owner A. LAB ONLY — never ship. Build measured matrix and benchmark actual concurrent transfers.

## Hypothesis
HYPOTHESIS — not yet measured: Matrix reflects executed schedules; throughput is configuration-dependent, no assumed speed ordering.

## Prerequisites
MySQL 8.x; Windows PowerShell 5.1; BANK_MYSQL_CNF points to an existing local option file. Rebuild with Standalone -WithSeed, then install lab_objects/install.sql and setup_lab_accounts.sql. Default automated target is disposable bank_txn_scratch; drivers rebuild it. No B schema files are changed.

## Manual two-window procedure
1. At wall clock t+0 record SELECT VERSION(), NOW(6), CONNECTION_ID(); in both windows. Set session isolation to the level under test before START TRANSACTION. SOURCE this folder's setup.sql in each window (a new session does not inherit @variables).
2. Matrix parser reads completed EXP04..07. Throughput changes global isolation only within try/finally.
3. Execute sessionA.sql/sessionB.sql in that order with the stated offsets; retain stderr and timestamps. The manual session files state individual actions; shared driver contains the complete four-level schedule and machine checks.
4. Capture a screenshot including MySQL version, visible timestamp, both connection IDs and outputs; save as evidence/EV-EXP08-<n>.png. Raw CLI evidence is sufficient for automated runs; screenshots require manual capture.
5. Run teardown.sql; unsafe EXP04 changes must be discarded by rebuilding, never by editing immutable ledger rows.

## Automated
powershell -NoProfile -File experiments/EXP-08_isolation_matrix/build_matrix.ps1
powershell -NoProfile -File experiments/EXP-08_isolation_matrix/run_throughput.ps1 -Quick

Full grid: powershell -NoProfile -File experiments/EXP-08_isolation_matrix/run_throughput.ps1 -Queries 200

The driver checks this installation's mysqlslap --help. Oracle mysqlslap 8.4 rejects the shared [client] default-character-set option even though mysql.exe accepts it. MySqlSlapConnection.ps1 resolves the existing option file through my_print_defaults in memory, forwards supported connection settings with --no-defaults and supplies the password only in the child ProcessStartInfo environment (MYSQL_PWD). It never writes a replacement credential file or prints the resolved options. Ordinary mysql sessions still use --defaults-extra-file first.

Get-CimInstance can be denied inside the sandbox. An authorized same-day measurement in evidence/EV-EXP08-hardware.json is accepted and its original timestamp is preserved in config.txt; a stale record is rejected. Without a record, hardware remains explicitly NEEDS MANUAL VERIFICATION while the actual benchmark can still run.

CSV retains UTC start/end, wall duration, Stopwatch duration and mysqlslap's reported mean batch time separately. Throughput uses wall duration. If client-reported batch timing exceeds wall time, timing_note flags the disagreement instead of silently treating the reported value as verified per-call latency. estimated_mean_query_seconds is a derivation, not a measured latency percentile.

Drivers retain expanded per-session SQL, stdout/stderr, native errors and META server/version/time/connection ID in evidence/raw/EXP-08/<timestamp>/. No result is inferred from a hypothesis. RESULTS.md is written only after a successful measured run; failed runs retain raw evidence and the summary records failure.
