# Measured mysqlslap throughput

Raw/config: C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-08\20261018-220831-714

| Isolation | Clients | Iterations | Transfers | Transfers/sec (wall) | Server mean CALL ms | Reported mean batch sec | Deadlocks | Retry rows |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| READ-COMMITTED | 5 | 1 | 500 | 504.66 | 7.753 | 1.922 | 5 | 5 |
| READ-COMMITTED | 25 | 1 | 500 | 280.09 | 67.197 | 3.734 | 60 | 60 |
| REPEATABLE-READ | 5 | 1 | 500 | 530.12 | 6.785 | 1.907 | 4 | 4 |
| REPEATABLE-READ | 25 | 1 | 500 | 321.64 | 52.067 | 2.453 | 52 | 52 |

Rates use UTC wall duration, independently checked by Stopwatch. CSV retains native mysqlslap timing disagreement flags; reported batch time is not verified per-call latency. Server mean CALL uses performance_schema digest counter/timer deltas (sample counts in CSV). Completed ledger rows / 2 counts successful transfers. Global deadlock deltas require an otherwise idle server. Hardware/config and before/after metrics are in the raw directory.