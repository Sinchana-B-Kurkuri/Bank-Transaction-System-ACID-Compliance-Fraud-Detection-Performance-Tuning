# Measured mysqlslap throughput

Raw/config: C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-08\20261018-220704-145

| Isolation | Clients | Iterations | Transfers | Transfers/sec (wall) | Server mean CALL ms | Reported mean batch sec | Deadlocks | Retry rows |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| READ-UNCOMMITTED | 5 | 3 | 600 | 473.33 | 7.321 | 1.062 | 3 | 3 |
| READ-UNCOMMITTED | 10 | 3 | 600 | 456.03 | 14.617 | 0.744 | 11 | 11 |
| READ-UNCOMMITTED | 25 | 3 | 600 | 227.51 | 60.985 | 1.849 | 47 | 47 |
| READ-UNCOMMITTED | 50 | 3 | 600 | 201.58 | 90.524 | 1.958 | 76 | 76 |
| READ-COMMITTED | 5 | 3 | 600 | 461.9 | 6.784 | 0.75 | 4 | 4 |
| READ-COMMITTED | 10 | 3 | 600 | 444.19 | 11.048 | 0.765 | 13 | 13 |
| READ-COMMITTED | 25 | 3 | 600 | 299.38 | 55.896 | 1.317 | 62 | 62 |
| READ-COMMITTED | 50 | 3 | 600 | 226.81 | 112.645 | 1.864 | 100 | 100 |
| REPEATABLE-READ | 5 | 3 | 600 | 598.65 | 5.268 | 0.651 | 4 | 4 |
| REPEATABLE-READ | 10 | 3 | 600 | 377.36 | 13.931 | 0.823 | 14 | 14 |
| REPEATABLE-READ | 25 | 3 | 600 | 362.26 | 36.859 | 0.869 | 48 | 48 |
| REPEATABLE-READ | 50 | 3 | 600 | 232.19 | 116.746 | 1.51 | 127 | 127 |
| SERIALIZABLE | 5 | 3 | 600 | 495.96 | 7.031 | 0.719 | 5 | 5 |
| SERIALIZABLE | 10 | 3 | 600 | 553.42 | 10.974 | 0.682 | 11 | 11 |
| SERIALIZABLE | 25 | 3 | 600 | 300.98 | 33.563 | 1.286 | 35 | 35 |
| SERIALIZABLE | 50 | 3 | 600 | 187.23 | 110.341 | 2.052 | 96 | 96 |

Rates use UTC wall duration, independently checked by Stopwatch. CSV retains native mysqlslap timing disagreement flags; reported batch time is not verified per-call latency. Server mean CALL uses performance_schema digest counter/timer deltas (sample counts in CSV). Completed ledger rows / 2 counts successful transfers. Global deadlock deltas require an otherwise idle server. Hardware/config and before/after metrics are in the raw directory.