# EXP-16 results

## Hypothesis
Dump recovers S0; replay to before operator error recovers S1; replay to before loss recovers S2.

## Procedure run
LOCALLY TESTED on MySQL 8.4.11: scratch rebuild, lab setup, consistent full backup, 500 deposits, Loans bulk DELETE (one row), one further deposit, scratch DROP and dump-only restore. The initial attempts and corrective JSON comparison are retained in the driver/evidence. The final successful restore-only command is evidence/EV-EXP16-restore-driver.txt.

## Raw output paths
evidence/raw/EXP-16/20261018-230550-774/ is the final backup/workload chain; the earlier 20261018-230223-685/ attempt is retained separately. Summary: evidence/EV-EXP16-summary.md.

## Actual
Full dump: 316423 bytes; initial replay coordinate LAPTOP-TEKJAJEQ-bin.000010:158. The operator error begins at position 841158 (Anonymous_Gtid / BEGIN); Delete_rows is at 841496 and its COMMIT ends at 841871. These are real SHOW BINLOG EVENTS measurements.

Latest dump-only restore RTO: 2.857 seconds (dump load 2.854, replay 0). Measured RPO lower bound: 21.159330 seconds, using the last recovered commit observation and loss observation. Dump-only loses 501 ledger rows and 1003 audit rows written after the dump. All nine row counts match S0; eight native checksums match. Audit_Log native checksum differs: 0 differences after comparing every row and field with JSON text normalization. Opaque JSON temporal/numeric types are not preserved by a plain SQL text dump, so native checksum equality is explicitly FALSE, not a claimed nine-table checksum pass.

Both PITR-to-S2 and PITR-to-S1 are NEEDS MANUAL VERIFICATION: datadir binlog file read was denied/unavailable. Replay did not execute; replay RTO/RPO and recovery of the deleted loan are NOT YET RUN. Dump-only restoration and six invariants passed despite this blocker.

## Match?
Dump-only recovered S0 at the serialized-value level, with the native Audit_Log checksum limitation above. The replay/operator-error recovery hypotheses remain NOT YET RUN.

## Notes
RPO measurement is an observed commit-time lower bound. RTO excludes operator response/verification. Triggers restored from a dump do not create a new D5 watermark.
