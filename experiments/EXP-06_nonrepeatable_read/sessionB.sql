-- LAB ONLY — never ship
-- STEP 2 (B) @ t+0s: follow README sequence.
SOURCE experiments/EXP-06_nonrepeatable_read/setup.sql;
START TRANSACTION; SELECT balance FROM Accounts WHERE account_id=@a; SELECT SLEEP(6); SELECT balance FROM Accounts WHERE account_id=@a; COMMIT;
SELECT 'RESULT|EXP-06|MANUAL|sessionB|DONE';
