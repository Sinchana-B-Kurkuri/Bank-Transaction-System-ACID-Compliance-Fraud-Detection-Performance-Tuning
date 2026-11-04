-- LAB ONLY — never ship
-- STEP 2 (B) @ t+0s: follow README sequence.
SOURCE experiments/EXP-07_phantom_read/setup.sql;
START TRANSACTION; SELECT COUNT(*) FROM Transactions WHERE account_id=@a; SELECT SLEEP(6); SELECT COUNT(*) FROM Transactions WHERE account_id=@a; SELECT transaction_id FROM Transactions WHERE account_id=@a FOR UPDATE; COMMIT;
SELECT 'RESULT|EXP-07|MANUAL|sessionB|DONE';
