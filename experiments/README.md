# Concurrency and consistency experiments

Owner A runs only EXP-01..10,16,17; EXP-11..15 belong to B and are not modified here. Every driver defaults to disposable bank_txn_scratch and rebuilds with seed and 100 lab accounts. Do not run two drivers against the same database simultaneously. Set BANK_MYSQL_CNF to your local option file; BANK_MYSQL_BIN can select mysql.exe. Credentials are never copied to evidence.

Run all: powershell -NoProfile -File experiments/run_all_auto.ps1

After a throughput-only infrastructure failure, -ResumeThroughput reuses the nine recorded completed SQL/stress runs, regenerates the matrix, reruns Quick and performs cleanup. It refuses to resume without all nine evidence rows. A completed measurement is distinct from a hypothesis match: EXP-10 explicitly reports TARGET NOT MET when ordered mode still deadlocks.

| Experiment | Owner | Status source | Run |
|---|---|---|---|
| EXP-01 | A | See folder RESULTS.md and evidence/EV-EXP-SUMMARY.md | EXP-01_atomicity/run_auto.ps1 |
| EXP-02 | A | See folder RESULTS.md and evidence/EV-EXP-SUMMARY.md | EXP-02_consistency/run_auto.ps1 |
| EXP-03 | A | Outside Prompt 4 scope | Owner's later plan |
| EXP-04 | A | See folder RESULTS.md and evidence/EV-EXP-SUMMARY.md | EXP-04_lost_update/run_auto.ps1 |
| EXP-05 | A | See folder RESULTS.md and evidence/EV-EXP-SUMMARY.md | EXP-05_dirty_read/run_auto.ps1 |
| EXP-06 | A | See folder RESULTS.md and evidence/EV-EXP-SUMMARY.md | EXP-06_nonrepeatable_read/run_auto.ps1 |
| EXP-07 | A | See folder RESULTS.md and evidence/EV-EXP-SUMMARY.md | EXP-07_phantom_read/run_auto.ps1 |
| EXP-08 | A | See folder RESULTS.md and evidence/EV-EXP-SUMMARY.md | EXP-08_isolation_matrix/build_matrix.ps1 + run_throughput.ps1 |
| EXP-09 | A | See folder RESULTS.md and evidence/EV-EXP-SUMMARY.md | EXP-09_stress/run_stress.ps1 |
| EXP-10 | A | See folder RESULTS.md and evidence/EV-EXP-SUMMARY.md | EXP-10_deadlocks/run_auto.ps1 |
| EXP-11 | B | Outside Prompt 4 scope | Owner's later plan |
| EXP-12 | B | Outside Prompt 4 scope | Owner's later plan |
| EXP-13 | B | Outside Prompt 4 scope | Owner's later plan |
| EXP-14 | B | Outside Prompt 4 scope | Owner's later plan |
| EXP-15 | B | Outside Prompt 4 scope | Owner's later plan |
| EXP-16 | A | Outside Prompt 4 scope | Owner's later plan |
| EXP-17 | A | Outside Prompt 4 scope | Owner's later plan |

Evidence naming: EV-EXP<NN>-<n> for summaries; evidence/raw/EXP-<NN>/<yyyyMMdd-HHmmss-fff>/ for expanded SQL, stdout, stderr, locks and timing. Each native session prints META server version/time/connection ID. Never substitute textbook expectations for measured RESULT lines. Matrix parser requires completed runs; rejected/incomplete captures remain raw evidence but are excluded from the matrix. Screenshots are manual supplements, not fabricated by scripts.

Unsafe lost-update writes intentionally break ledger consistency. EXP-04 rebuilds between cases and again before its final invariant check. Ordinary application procedures and source files are preserved. EXP-10's DB-only first-lock scheduling probe is disclosed in its README and always restored in finally. Lab objects are never included in build/run_all; uninstall after use. MySQL 8 does not support optional stored-procedure arguments: no-argument sp_lab_random_transfer() serves mysqlslap; sp_lab_random_transfer_at_level(p_level) is the typed optional-isolation entry point (1 RU,2 RC,3 RR,4 SER,NULL unchanged).
