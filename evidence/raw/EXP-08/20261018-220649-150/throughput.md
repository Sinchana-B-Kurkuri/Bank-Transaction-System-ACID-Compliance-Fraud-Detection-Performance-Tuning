# Measured mysqlslap throughput

Raw/config: C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-08\20261018-220649-150

| Isolation | Clients | Iterations | Transfers | Transfers/sec (wall) | Server mean CALL ms | Reported mean batch sec | Deadlocks | Retry rows |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| READ-COMMITTED | 5 | 1 | 500 | 509.31 | 8.267 | 1.89 | 4 | 4 |
| READ-COMMITTED | 25 | 1 | 500 | 314.11 | 62.088 | 2.516 | 61 | 61 |
| REPEATABLE-READ | 5 | 1 | 500 | 516.72 | 6.362 | 1.906 | 4 | 4 |
| REPEATABLE-READ | 25 | 1 | 500 | 425.27 | 40.53 | 2.125 | 38 | 38 |

Rates use UTC wall duration, independently checked by Stopwatch. CSV retains native mysqlslap timing disagreement flags; reported batch time is not verified per-call latency. Server mean CALL uses performance_schema digest counter/timer deltas (sample counts in CSV). Completed ledger rows / 2 counts successful transfers. Global deadlock deltas require an otherwise idle server. Hardware/config and before/after metrics are in the raw directory.