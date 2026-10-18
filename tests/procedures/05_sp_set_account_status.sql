SOURCE tests/procedures/support/fixture.sql;
CALL bank_lab.sp_expect_ok(DATABASE(),'status freeze','CALL {db}.sp_set_account_status(@p3_a,''Frozen'',@p3_m1)');
SET @p3_ok=(SELECT status='Frozen' FROM Accounts WHERE account_id=@p3_a);
CALL bank_lab.sp_assert_true(DATABASE(),'status Frozen stored',@p3_ok,'Expected procedure contract');
CALL bank_lab.sp_expect_error(DATABASE(),'status same transition','CALL {db}.sp_set_account_status(@p3_a,''Frozen'',@p3_t1)',5011);
CALL bank_lab.sp_expect_ok(DATABASE(),'status unfreeze','CALL {db}.sp_set_account_status(@p3_a,''Active'',@p3_t1)');
CALL bank_lab.sp_expect_error(DATABASE(),'status missing account','CALL {db}.sp_set_account_status(-1,''Active'',@p3_t1)',5002);
CALL bank_lab.sp_expect_error(DATABASE(),'status invalid Closed','CALL {db}.sp_set_account_status(@p3_a,''Closed'',@p3_t1)',5011);
CALL bank_lab.sp_expect_error(DATABASE(),'status invalid Other','CALL {db}.sp_set_account_status(@p3_a,''Other'',@p3_t1)',5011);
CALL bank_lab.sp_expect_error(DATABASE(),'status invalid NULL','CALL {db}.sp_set_account_status(@p3_a,NULL,@p3_t1)',5011);
CALL bank_lab.sp_expect_error(DATABASE(),'status unauthorized NULL','CALL {db}.sp_set_account_status(@p3_a,''Frozen'',NULL)',5010);
CALL bank_lab.sp_expect_error(DATABASE(),'status unauthorized @p3_t2','CALL {db}.sp_set_account_status(@p3_a,''Frozen'',@p3_t2)',5010);
CALL bank_lab.sp_expect_error(DATABASE(),'status unauthorized @p3_dba','CALL {db}.sp_set_account_status(@p3_a,''Frozen'',@p3_dba)',5010);
CALL bank_lab.sp_expect_error(DATABASE(),'status unauthorized -1','CALL {db}.sp_set_account_status(@p3_a,''Frozen'',-1)',5010);
CALL sp_close_account(@p3_a,NULL,1);
CALL bank_lab.sp_expect_error(DATABASE(),'status Closed is terminal','CALL {db}.sp_set_account_status(@p3_a,''Active'',@p3_t1)',5011);

SOURCE tests/procedures/support/extra_05_sp_set_account_status.sql;
