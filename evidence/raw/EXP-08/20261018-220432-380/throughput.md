# Measured mysqlslap throughput

Raw/config: C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-08\20261018-220432-380


isolation       concurrency iterations queries_requested started_utc                       finished_utc                      elapsed_seconds stopwatch_seconds completed_ledger_rows successful_transfers
---------       ----------- ---------- ----------------- -----------                       ------------                      --------------- ----------------- --------------------- --------------------
READ-COMMITTED            5          1               500 2026-10-18T16:34:33.3912529+00:00 2026-10-18T16:34:34.4302005+00:00       1.0389476         1.0372457                  1000                  500
READ-COMMITTED           25          1               500 2026-10-18T16:34:34.6854004+00:00 2026-10-18T16:34:36.6498399+00:00       1.9644395          1.964161                  1000                  500
REPEATABLE-READ           5          1               500 2026-10-18T16:34:37.0967977+00:00 2026-10-18T16:34:37.7584223+00:00       0.6616246         0.6617087                  1000                  500
REPEATABLE-READ          25          1               500 2026-10-18T16:34:37.9926187+00:00 2026-10-18T16:34:39.8081201+00:00       1.8155014         1.8155119                  1000                  500



mysqlslap reports mean batch duration, not individual call latency. estimated_mean_query_seconds is derived (mean batch duration * concurrency / requested queries), not a measured latency percentile. Completed ledger rows / 2 counts successful transfers. Global deadlocks include any other server workload; this lab used an otherwise idle local server.