-- LAB ONLY — never ship
-- STEP 2 (B) @ t+1s: follow README sequence.
SOURCE experiments/EXP-08_isolation_matrix/setup.sql;
SELECT COUNT(*) FROM Transactions WHERE status='Completed';
SELECT 'RESULT|EXP-08|MANUAL|sessionB|DONE';
