# Prompt 5 delivery — 2026-10-18

Branch verified: feature/A-recovery-audit (HEAD 6b5c2c6). No commit, push, merge, branch creation or switch. Existing banking procedures, ordered locking, schema, functions, triggers, build files, interfaces and Member B source files are unchanged. No B changes requested.

| Deliverable | Status | Actual evidence / limit |
|---|---|---|
| EXP-03 setup and dry-run | IMPLEMENTED / LOCALLY TESTED | 100 committed deposits; second connection UNCOMMITTED_READY; dry-run refused ambiguous mysqld PID; own sleeping connection killed/rolled back; six invariants PASS |
| EXP-03 crash/restart durability | IMPLEMENTED / NEEDS MANUAL VERIFICATION | No crash/restart executed. MySQL84 detected, two mysqld PIDs; elevated operator must identify correct PID, rerun setup and type confirmation. No crash RTO or survival claim |
| EXP-16 dump/workload/loss/dump restore | IMPLEMENTED / LOCALLY TESTED | 316423-byte dump, 500 committed deposits, one deleted loan and one later deposit; scratch loss and restore executed; final dump-only RTO 2.857 s |
| EXP-16 checksums | LOCALLY TESTED, limitation recorded | Nine row counts match; eight native checksums match; Audit_Log native checksum differs, but every normalized JSON row/field compares equal. No claim of nine native checksum matches |
| EXP-16 PITR before loss / before oops | IMPLEMENTED / NEEDS MANUAL VERIFICATION | Local binlog read access blocked. No replay or PITR RTO/RPO measured. Binlog DELETE transaction boundary is captured via SHOW BINLOG EVENTS |
| EXP-17 audit completeness | IMPLEMENTED / LOCALLY TESTED | 74 PASS / 0 FAIL; restricted Teller/Customer procedure runs, per-operation expected/actual groups and total counts, JSON and actor assertions, direct DBA DML, guard rejection, immutable audit, disabled-trigger gap, new D5 watermark |
| Full regression | LOCALLY TESTED | 743 PASS / 0 FAIL, exit 0 (734 previous + 9 new DB audit checks) |
| Final invariants / cleanup | LOCALLY TESTED | I1, I1b, I2, I3, I4, I5 PASS on both databases; zero remaining lab routines and zz_a_* users |
| Script compatibility and guards | LOCALLY TESTED | All 14 PowerShell files parsed in Windows PowerShell 5.1; seven entry points rejected bank_txn before mutation; durability verifier refused to claim an unexecuted crash |

Files added: backup/README.md and backup/ps/{Common,take_full_backup,apply_workload,oops_delete,simulate_loss,restore_and_pitr}.ps1; experiments/EXP-03_durability/{README.md,RESULTS.md,setup_commit.sql,setup.ps1,kill_and_restart.ps1,verify_after_restart.sql,verify.ps1,teardown.ps1}; EXP-16_backup_restore_pitr/{README.md,RESULTS.md}; EXP-17_audit_completeness/{README.md,RESULTS.md,setup.ps1,mutations.ps1,teardown.ps1,run_auto.ps1}; tests/integration/05_exp17.sql; this report and new evidence. Existing regression evidence rewritten by tests is archived under evidence/p5-regression-derived, while its tracked originals are preserved.

Commands actually run:

```powershell
powershell -NoProfile -File backup/ps/take_full_backup.ps1 -Database bank_txn_scratch
powershell -NoProfile -File backup/ps/apply_workload.ps1            # default N=500
powershell -NoProfile -File backup/ps/oops_delete.ps1
powershell -NoProfile -File backup/ps/simulate_loss.ps1
powershell -NoProfile -File backup/ps/restore_and_pitr.ps1
powershell -NoProfile -File experiments/EXP-03_durability/setup.ps1
powershell -NoProfile -File experiments/EXP-03_durability/kill_and_restart.ps1   # no -Execute
powershell -NoProfile -File experiments/EXP-03_durability/teardown.ps1
powershell -NoProfile -File experiments/EXP-17_audit_completeness/run_auto.ps1
powershell -NoProfile -File tests/run_tests.ps1 -Database bank_txn
```

The first dump attempt failed because the private [client] local-infile option is mysql-specific. The recovery helper now reads connection settings only in memory, sets a password only on the child process environment and never copies the option file. Subsequent dump/load commands worked in Windows PowerShell 5.1 with paths containing spaces. mysqldump/mysqlbinlog output files use --result-file; no binary PowerShell pipeline or UTF-16 dump redirection is used. Dumps, audit data baselines, replay files and state are under already-ignored backup/out/. No credentials, dumps or binlogs were added to tracked paths.

The first checksum validation exposed the opaque DATE/DATETIME/DECIMAL JSON representation difference on Audit_Log. The native mismatch is retained; a separate text-normalized comparison verifies all original rows/fields, rather than relabeling the native checksum as equal. Initial failure outputs remain in the evidence. RPO_dump_only=21.159330 s is a measured lower bound based on post-commit observation, not an exact commit-time/power-failure guarantee. No PITR number is fabricated. Dump-only loses all post-dump audit rows too; restoring trigger definitions does not itself reset D5. Trigger reinstallation in EXP-17 deliberately records a fresh boundary and cannot repair past gaps.

Evidence: EV-EXP03-{driver,dry-run,teardown}.txt plus raw/EXP-03/20261018-230805-373; EV-EXP16-{driver,restore-driver}.txt, EV-EXP16-summary.md and raw/EXP-16/20261018-230550-774; EV-EXP17-{driver.txt,counts.md,json.txt} and raw/EXP-17/20261018-231759-061; EV-P5-{REGRESSION,ENV,TOOLS,FINAL,SCRIPT-CHECKS}.txt. The initial EXP-16 driver includes failed validation attempts; the final restore-driver and summary hold the corrected measured outcome. No unrelated experiment or throughput grid was rerun.

Manual continuation: first read the runbooks. For PITR, an operator with datadir read access may rerun backup/ps/restore_and_pitr.ps1 using the existing ignored state and retained binlog. For durability, rebuild/prep fresh in one PowerShell window and run the confirmation-gated -Execute script in another elevated window only after identifying the correct mysqld PID. The historical durability fixture has already been cleaned up and scratch subsequently restored/rebuilt. The agent has not run any Administrator/service/crash step.
