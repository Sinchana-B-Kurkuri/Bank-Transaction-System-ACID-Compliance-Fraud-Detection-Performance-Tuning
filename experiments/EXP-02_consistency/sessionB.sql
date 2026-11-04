-- LAB ONLY — never ship
-- STEP 2 (B) @ t+1s: follow README sequence.
SOURCE experiments/EXP-02_consistency/setup.sql;
SELECT * FROM bank_lab.Test_Results WHERE test_name LIKE 'EXP02 %' ORDER BY result_id DESC LIMIT 18;
SELECT 'RESULT|EXP-02|MANUAL|sessionB|DONE';
