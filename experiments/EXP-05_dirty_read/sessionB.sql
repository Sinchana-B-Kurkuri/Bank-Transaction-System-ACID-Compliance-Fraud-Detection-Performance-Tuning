-- LAB ONLY — never ship
-- STEP 2 (B) @ t+3s: follow README sequence.
SOURCE experiments/EXP-05_dirty_read/setup.sql;
SET SESSION innodb_lock_wait_timeout=3; START TRANSACTION; SELECT balance FROM Accounts WHERE account_id=@a; COMMIT;
SELECT 'RESULT|EXP-05|MANUAL|sessionB|DONE';
