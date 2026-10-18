-- LAB ONLY — never ship
-- STEP 2 (B) @ t+1s: follow README sequence.
SOURCE experiments/EXP-04_lost_update/setup.sql;
SET @lab_sleep_seconds=5; CALL sp_transfer_naive(@a,@c,200);
SELECT 'RESULT|EXP-04|MANUAL|sessionB|DONE';
