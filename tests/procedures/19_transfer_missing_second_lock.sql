-- The missing id sorts AFTER both fixtures, exercising the second locking read.
SOURCE tests/procedures/support/fixture.sql;
SET @p4_missing=(SELECT MAX(account_id)+1000 FROM Accounts);
SET @p4_before_a=(SELECT balance FROM Accounts WHERE account_id=@p3_a);
SET @p4_before_b=(SELECT balance FROM Accounts WHERE account_id=@p3_b);
SET @p4_before_tx=(SELECT COUNT(*) FROM Transactions);
SET @p4_before_audit=(SELECT COUNT(*) FROM Audit_Log);
CALL bank_lab.sp_expect_error(DATABASE(),'ordered locking missing high destination','CALL {db}.sp_transfer_funds(@p3_a,@p4_missing,1,''Online'',NULL,NULL,NULL,0,@p3_group,@p3_debit,@p3_credit)',5002);
CALL bank_lab.sp_expect_error(DATABASE(),'ordered locking missing high source','CALL {db}.sp_transfer_funds(@p4_missing,@p3_b,1,''Online'',NULL,NULL,NULL,0,@p3_group,@p3_debit,@p3_credit)',5002);
SET @p4_unchanged=(SELECT balance=@p4_before_a FROM Accounts WHERE account_id=@p3_a)
 AND (SELECT balance=@p4_before_b FROM Accounts WHERE account_id=@p3_b)
 AND (SELECT COUNT(*)=@p4_before_tx FROM Transactions)
 AND (SELECT COUNT(*)=@p4_before_audit FROM Audit_Log);
CALL bank_lab.sp_assert_true(DATABASE(),'missing second lock rolls back without ledger or audit writes',@p4_unchanged,'5002 preserves balances, ledger (including Failed rows) and audit counts');
