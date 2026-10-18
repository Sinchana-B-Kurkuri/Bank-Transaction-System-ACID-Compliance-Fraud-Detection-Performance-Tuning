# Measured mysqlslap throughput

Raw/config: C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-08\20261018-220449-450


isolation        concurrency iterations queries_requested started_utc                       finished_utc                      elapsed_seconds stopwatch_seconds completed_ledger_rows successful_transfers
---------        ----------- ---------- ----------------- -----------                       ------------                      --------------- ----------------- --------------------- --------------------
READ-UNCOMMITTED           5          3               200 2026-10-18T16:34:50.3553014+00:00 2026-10-18T16:34:51.6496126+00:00       1.2943112         1.2931813                  1200                  600
READ-UNCOMMITTED          10          3               200 2026-10-18T16:34:51.9096968+00:00 2026-10-18T16:34:53.9572729+00:00       2.0475761         2.0479429                  1200                  600
READ-UNCOMMITTED          25          3               200 2026-10-18T16:34:54.3420007+00:00 2026-10-18T16:34:56.9369987+00:00        2.594998         2.5949602                  1200                  600
READ-UNCOMMITTED          50          3               200 2026-10-18T16:34:57.1998621+00:00 2026-10-18T16:35:00.7896382+00:00       3.5897761         3.5905122                  1200                  600
READ-COMMITTED             5          3               200 2026-10-18T16:35:01.2081036+00:00 2026-10-18T16:35:02.7833935+00:00       1.5752899         1.5760759                  1200                  600
READ-COMMITTED            10          3               200 2026-10-18T16:35:03.2804811+00:00 2026-10-18T16:35:04.6627387+00:00       1.3822576         1.3814877                  1200                  600
READ-COMMITTED            25          3               200 2026-10-18T16:35:04.8831824+00:00 2026-10-18T16:35:07.5878631+00:00       2.7046807         2.7047678                  1200                  600
READ-COMMITTED            50          3               200 2026-10-18T16:35:07.9254869+00:00 2026-10-18T16:35:11.8310562+00:00       3.9055693          3.905668                  1200                  600
REPEATABLE-READ            5          3               200 2026-10-18T16:35:12.1434619+00:00 2026-10-18T16:35:13.3238443+00:00       1.1803824         1.1805894                  1200                  600
REPEATABLE-READ           10          3               200 2026-10-18T16:35:13.9320867+00:00 2026-10-18T16:35:15.3978237+00:00        1.465737         1.4663636                  1200                  600
REPEATABLE-READ           25          3               200 2026-10-18T16:35:15.6721428+00:00 2026-10-18T16:35:18.2584832+00:00       2.5863404         2.5858412                  1200                  600
REPEATABLE-READ           50          3               200 2026-10-18T16:35:18.7479106+00:00 2026-10-18T16:35:23.4923480+00:00       4.7444374         4.7457508                  1200                  600
SERIALIZABLE               5          3               200 2026-10-18T16:35:24.3087341+00:00 2026-10-18T16:35:25.4277333+00:00       1.1189992         1.1193221                  1200                  600
SERIALIZABLE              10          3               200 2026-10-18T16:35:26.0986589+00:00 2026-10-18T16:35:27.4641677+00:00       1.3655088           1.36628                  1200                  600
SERIALIZABLE              25          3               200 2026-10-18T16:35:27.7066154+00:00 2026-10-18T16:35:29.8364286+00:00       2.1298132           2.13024                  1200                  600
SERIALIZABLE              50          3               200 2026-10-18T16:35:30.1398860+00:00 2026-10-18T16:35:32.9170379+00:00       2.7771519         2.7778054                  1200                  600



mysqlslap reports mean batch duration, not individual call latency. estimated_mean_query_seconds is derived (mean batch duration * concurrency / requested queries), not a measured latency percentile. Completed ledger rows / 2 counts successful transfers. Global deadlocks include any other server workload; this lab used an otherwise idle local server.