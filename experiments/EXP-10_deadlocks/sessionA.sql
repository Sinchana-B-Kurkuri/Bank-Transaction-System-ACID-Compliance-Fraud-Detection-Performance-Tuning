-- LAB ONLY — never ship
-- STEP 1 (A) @ t+0s: follow README sequence.
SOURCE experiments/EXP-10_deadlocks/setup.sql;
SET @lab_sleep_seconds=3; CALL sp_transfer_funds(@a,@b,10,'Online',NULL,NULL,NULL,3,@g,@d,@c);
SELECT 'RESULT|EXP-10|MANUAL|sessionA|DONE';
