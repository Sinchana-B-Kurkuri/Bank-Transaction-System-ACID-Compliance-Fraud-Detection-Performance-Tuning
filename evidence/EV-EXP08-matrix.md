# Measured isolation matrix

Sources:
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-04\20261018-215039-090
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-05\20261018-215342-152
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-06\20261018-215431-512
C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-07\20261018-215504-624

| Isolation | Lost update: textbook expectation | Measured | Dirty: textbook expectation | Measured | Nonrepeatable: textbook expectation | Measured | Phantom: textbook expectation | Measured | Difference / implementation detail |
|---|---|---|---|---|---|---|---|---|---|
| READ UNCOMMITTED | OBSERVED | OBSERVED | OBSERVED | OBSERVED | OBSERVED | OBSERVED | OBSERVED | OBSERVED | None |
| READ COMMITTED | OBSERVED | OBSERVED | NOT OBSERVED | NOT OBSERVED | OBSERVED | OBSERVED | OBSERVED | OBSERVED | None |
| REPEATABLE READ | OBSERVED | OBSERVED | NOT OBSERVED | NOT OBSERVED | NOT OBSERVED | NOT OBSERVED | PERMITTED | NOT OBSERVED (nuance) | 07 |
| SERIALIZABLE | NOT OBSERVED | BLOCKED | NOT OBSERVED | BLOCKED | NOT OBSERVED | BLOCKED | NOT OBSERVED | BLOCKED | 04,05,06,07 |

Textbook OBSERVED means the anomaly is permitted and the schedule is designed to expose it, not that every execution must exhibit it. PERMITTED for RR phantoms is the ANSI minimum guarantee: InnoDB plain consistent reads provide a stable snapshot, hence the flagged stronger result. SERIALIZABLE BLOCKED also prevents the anomaly; its flagged difference describes the protection mechanism, not a violation. Locking reads use the current committed version. Lost-update expectations concern the deliberately unsafe read/absolute-write procedure, not an additional ANSI isolation prohibition.
