-- Explicit Integrated optimized entry point; baseline run_all.sql never installs these indexes.
SOURCE build/run_all.sql;
SOURCE indexes/01_performance_indexes.sql;
