# Member A recovery runbook

All recovery database drops assert the exact name `bank_txn_scratch`. The banking database is never restored in place. Configure `BANK_MYSQL_CNF` to the existing private option file and, if needed, `BANK_MYSQL_BIN` to mysql.exe. Run from the repository root in Windows PowerShell 5.1. `backup/out/` is gitignored and contains dumps, replay SQL, logical audit baselines, and resumable state; do not add these files to Git or evidence.

Run in sequence (each command must succeed before the next):

```powershell
powershell -NoProfile -File backup/ps/take_full_backup.ps1 -Database bank_txn_scratch
powershell -NoProfile -File backup/ps/apply_workload.ps1 -N 500
powershell -NoProfile -File backup/ps/oops_delete.ps1
powershell -NoProfile -File backup/ps/simulate_loss.ps1
powershell -NoProfile -File backup/ps/restore_and_pitr.ps1
```

The first command rebuilds scratch with seed (automatic Standalone/Integrated mode), installs lab routines and 100 lab accounts, flushes logs, and takes a consistent routines/triggers/events dump with the version-supported `--source-data=2` or `--master-data=2`. No concurrent workload should modify scratch during this bounded experiment. The second command records S1 after 500 committed deposits. The third records a binlog boundary immediately before deleting Loans, then commits one further deposit (S2). Ledger UPDATE/DELETE guards forbid deleting Transactions. SHOW BINLOG EVENTS identifies the row-based DELETE transaction and its boundary in retained evidence.

Restore measures three distinct variants: dump only to S0; dump plus replay to S2 immediately before simulated loss; dump plus replay to S1 before the operator error. Every variant starts with a fresh scratch restore. Replay is bounded to one binlog file; rotation during the workload causes a clear manual-verification result rather than replaying an incomplete sequence. Native tool stderr and errors remain visible. Dumps/binlogs are never captured with PowerShell `>` or a binary pipeline: tools use `--result-file`, and mysql loads with native `--execute=source <path>`.

The shared private option file can contain mysql-only `local-infile`. The dump helper reads connection options into memory and invokes mysqldump with `--no-defaults --no-login-paths`; the password is supplied only in that child process's MYSQL_PWD environment and removed in finally. No sanitized credential file is created. Self-contained standard `[client]`/`[mysqldump]` connection options are supported; `!include` is rejected clearly. Other mysqldump behavior is explicitly specified in the script.

If datadir ACLs deny mysqlbinlog read access, dump-only recovery still completes. Both replay paths are labeled NEEDS MANUAL VERIFICATION, without RTO/RPO claims. An operator with datadir read access can rerun only `restore_and_pitr.ps1 -StateFile backup/out/recovery_state.json` in an elevated shell, provided the same binlog and backup still exist. Do not rotate/purge these logs until verification is complete. No service restart or Administrator command is run automatically.

`evidence/EV-EXP16-summary.md` reports all nine native checksums honestly. SQL dump/load can change the binary numeric representation within JSON while preserving values; a native Audit_Log checksum mismatch remains FALSE in that table. In this case a second comparison loads the original audit documents from ignored backup/out into a temporary table and uses MySQL JSON equality for every field of every row, plus row counts. Passing semantic comparison never becomes a claim that all native checksums matched.

RTO is measured dump-load plus replay wall time, excluding operator response and verification. RPO uses the server observation immediately after the last recovered commit, compared with the server observation immediately before simulated loss; this is a measured lower bound on the precise commit-to-loss interval, not an exact crash-time guarantee. Dump-only discards all work and audit rows after T0. Dumped triggers restore their original definitions; restoring does not reset the D5 watermark. bank_lab is deliberately outside this database dump. Reinstalling audit triggers later creates a new watermark and cannot reconstruct historical audit gaps.

After experiments, use the normal scratch rebuild to remove lab accounts/fixtures, or source `experiments/lab_objects/uninstall.sql` to remove only installed lab routines. Crash testing has a separate manual runbook under EXP-03; this chain does not crash MySQL.
