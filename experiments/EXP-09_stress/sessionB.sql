-- LAB ONLY — never ship
-- STEP 2 (B) @ t+0s: follow README sequence.
SOURCE experiments/EXP-09_stress/setup.sql;
CALL sp_lab_stress_loop(50,2);
SELECT 'RESULT|EXP-09|MANUAL|sessionB|DONE';
