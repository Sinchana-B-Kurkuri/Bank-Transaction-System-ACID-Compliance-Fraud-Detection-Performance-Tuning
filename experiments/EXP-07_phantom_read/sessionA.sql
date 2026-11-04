-- LAB ONLY — never ship
-- STEP 1 (A) @ t+2s: follow README sequence.
SOURCE experiments/EXP-07_phantom_read/setup.sql;
SET SESSION innodb_lock_wait_timeout=2; CALL sp_deposit(@a,10,'Online',NULL,NULL,NULL,@t,@balance);
SELECT 'RESULT|EXP-07|MANUAL|sessionA|DONE';
