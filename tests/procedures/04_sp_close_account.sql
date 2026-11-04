SOURCE tests/procedures/support/fixture.sql;
CALL bank_lab.sp_expect_error(DATABASE(),'close nonzero default','CALL {db}.sp_close_account(@p3_a,NULL,0)',5008);
CALL bank_lab.sp_expect_error(DATABASE(),'close nonexistent','CALL {db}.sp_close_account(-1,NULL,1)',5002);
CALL bank_lab.sp_expect_error(DATABASE(),'close invalid flag','CALL {db}.sp_close_account(@p3_a,NULL,2)',5018);
CALL bank_lab.sp_expect_error(DATABASE(),'close wrong branch teller','CALL {db}.sp_close_account(@p3_a,@p3_t2,1)',5010);
CALL sp_disburse_loan(@p3_c1,@p3_a,1000,6,12,NULL,@p3_loan);
CALL bank_lab.sp_expect_error(DATABASE(),'close active loan blocks settlement','CALL {db}.sp_close_account(@p3_a,NULL,1)',5008);
UPDATE Loans SET status='Closed' WHERE loan_id=@p3_loan;
SET @p3_old=(SELECT balance FROM Accounts WHERE account_id=@p3_a);
CALL bank_lab.sp_expect_ok(DATABASE(),'close settle atomically','CALL {db}.sp_close_account(@p3_a,@p3_t1,1)');
SET @p3_ok=(SELECT a.status='Closed' AND a.balance=0 AND EXISTS(SELECT 1 FROM Transactions WHERE account_id=a.account_id AND transaction_type='Withdrawal' AND amount=@p3_old AND balance_after=0 AND status='Completed') FROM Accounts a WHERE a.account_id=@p3_a);
CALL bank_lab.sp_assert_true(DATABASE(),'close final withdrawal and zero',@p3_ok,'Expected procedure contract');
CALL bank_lab.sp_expect_error(DATABASE(),'close already closed','CALL {db}.sp_close_account(@p3_a,NULL,1)',5011);

SOURCE tests/procedures/support/extra_04_sp_close_account.sql;
