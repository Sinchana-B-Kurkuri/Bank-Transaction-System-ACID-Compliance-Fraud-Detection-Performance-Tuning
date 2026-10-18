-- LAB ONLY — never ship
-- STEP 1 (A) @ t+0s: follow README sequence.
SOURCE experiments/EXP-05_dirty_read/setup.sql;
START TRANSACTION; UPDATE Accounts SET balance=balance+1000 WHERE account_id=@a; SELECT SLEEP(10); ROLLBACK;
SELECT 'RESULT|EXP-05|MANUAL|sessionA|DONE';
