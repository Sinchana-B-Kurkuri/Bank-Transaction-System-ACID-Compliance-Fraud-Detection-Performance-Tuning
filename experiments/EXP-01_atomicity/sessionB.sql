-- LAB ONLY — never ship
-- STEP 2 (B) @ t+2s: follow README sequence.
SOURCE experiments/EXP-01_atomicity/setup.sql;
SELECT * FROM performance_schema.data_locks WHERE OBJECT_SCHEMA=DATABASE();
SELECT 'RESULT|EXP-01|MANUAL|sessionB|DONE';
