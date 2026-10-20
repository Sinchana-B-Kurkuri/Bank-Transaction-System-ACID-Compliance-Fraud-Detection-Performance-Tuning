# Index profiles and repeatable comparison

The integrated `build/run_all.sql` now installs baseline profile B0 only (PK/UNIQUE/FK-required indexes). It does not install optional secondary indexes.

For an optimized run, rebuild a disposable database to B0 first, capture the baseline plans and timings from `benchmarks/01_query_plan_comparison.sql`, then execute `source indexes/01_performance_indexes.sql` against that same disposable database and capture optimized plans/timings. Do not run the index script twice; MySQL will report duplicate index names. Keep dataset, server version, query parameters, warm-up policy, and repetitions identical. No speedup is claimed until results are recorded.

`indexes/01_performance_indexes.sql` is the optimized profile's installer. This file is not included in the default integrated build.
