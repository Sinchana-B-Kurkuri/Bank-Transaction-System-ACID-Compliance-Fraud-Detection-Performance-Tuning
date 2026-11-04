# Performance experiment protocol

1. Rebuild a disposable database and load the same synthetic seed/workload.
2. Run `benchmarks/01_query_plan_comparison.sql` before installing `indexes/01_performance_indexes.sql`.
3. Save the EXPLAIN output as a baseline; record row estimates, chosen key, access type and actual time when using EXPLAIN ANALYZE.
4. Install indexes, rerun identical queries against the same data, and save the second output.
5. Report the result only from measured output. Indexes can improve reads while increasing write/storage costs; do not invent speedup percentages.
6. Use `DROP INDEX index_name ON table_name;` only on a disposable copy to repeat the baseline.
