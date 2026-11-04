CALL bank_lab.sp_expect_error(DATABASE(),'close NULL settlement','CALL {db}.sp_close_account(@p3_b,NULL,NULL)',5018);
CALL sp_set_account_status(@p3_b,'Frozen',@p3_t2);
CALL bank_lab.sp_expect_ok(DATABASE(),'close Frozen settlement','CALL {db}.sp_close_account(@p3_b,NULL,1)');
