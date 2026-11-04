-- LAB ONLY — never ship
-- STEP 1 (A) @ t+2s: follow README sequence.
SOURCE experiments/EXP-06_nonrepeatable_read/setup.sql;
SET SESSION innodb_lock_wait_timeout=2; CALL sp_deposit(@a,1000,'Online',NULL,NULL,NULL,@t,@balance);
SELECT 'RESULT|EXP-06|MANUAL|sessionA|DONE';
