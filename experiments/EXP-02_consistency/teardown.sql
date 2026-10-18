-- LAB ONLY — never ship
ROLLBACK;
SET @lab_sleep_seconds=NULL;
SELECT 'RESULT|EXP-02|MANUAL|teardown|SESSION RESET';
-- Run experiments/lab_objects/uninstall.sql after all sessions exit.
-- Rebuild the disposable database after unsafe writes; ledger is immutable.
