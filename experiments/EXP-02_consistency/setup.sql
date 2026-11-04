-- LAB ONLY — never ship
-- Requires initialized seeded lab; safe to source independently in both windows.
SET @a=(SELECT account_id FROM Accounts WHERE account_number='LAB-0001');
SET @b=(SELECT account_id FROM Accounts WHERE account_number='LAB-0002');
SET @c=(SELECT account_id FROM Accounts WHERE account_number='LAB-0003');
SELECT CONCAT('RESULT|EXP-02|MANUAL|metadata|',VERSION(),' ',NOW(6),' connection=',CONNECTION_ID());
