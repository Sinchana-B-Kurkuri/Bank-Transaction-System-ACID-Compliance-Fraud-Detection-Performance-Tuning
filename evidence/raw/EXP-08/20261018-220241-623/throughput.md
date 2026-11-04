# Measured mysqlslap throughput

Raw/config: C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-08\20261018-220241-623


isolation       concurrency iterations queries_requested elapsed_seconds completed_ledger_rows successful_transfers ledger_rows_per_second transfers_per_second mean_run_seconds
---------       ----------- ---------- ----------------- --------------- --------------------- -------------------- ---------------------- -------------------- ----------------
READ-COMMITTED            5          1               500       0.9140408                  1000                  500       1094.04306678652     547.021533393258            1.813
READ-COMMITTED           25          1               500       1.4024671                  1000                  500        713.02920403623     356.514602018115            3.344
REPEATABLE-READ           5          1               500       0.6879821                  1000                  500       1453.52618912614     726.763094563071             1.64
REPEATABLE-READ          25          1               500       0.9672688                  1000                  500       1033.83878400709     516.919392003546             1.86



mysqlslap reports mean batch duration, not individual call latency. estimated_mean_query_seconds is derived (mean batch duration * concurrency / requested queries), not a measured latency percentile. Completed ledger rows / 2 counts successful transfers. Global deadlocks include any other server workload; this lab used an otherwise idle local server.