-- LAB ONLY — never ship
-- STEP 1 (A) @ t+0s: follow README sequence.
SOURCE experiments/EXP-04_lost_update/setup.sql;
SET @lab_sleep_seconds=5; CALL sp_transfer_naive(@a,@b,100);
SELECT 'RESULT|EXP-04|MANUAL|sessionA|DONE';
