SELECT 'version', VERSION();
SELECT 'version_comment', @@version_comment;
SHOW GLOBAL VARIABLES WHERE Variable_name IN ('log_bin','binlog_format','sync_binlog','local_infile','performance_schema','transaction_isolation','innodb_flush_log_at_trx_commit','innodb_lock_wait_timeout','innodb_deadlock_detect','innodb_print_all_deadlocks','log_bin_trust_function_creators','secure_file_priv','datadir','max_connections','sql_mode','character_set_server');
SELECT 'session_transaction_isolation', @@transaction_isolation;
