-- Reference and expected checksums are supplied by verify.ps1 from saved state.
SELECT CONCAT('META|',VERSION(),'|',NOW(6));
SELECT COUNT(*) AS uncommitted_reference_rows FROM Transactions WHERE reference_no=@durability_reference;
CHECKSUM TABLE Accounts, Transactions;
SELECT COUNT(*),SUM(balance) FROM Accounts;
SELECT COUNT(*) FROM Transactions;
CALL sp_reconcile_balances(NULL);
