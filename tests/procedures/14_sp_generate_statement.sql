SOURCE tests/procedures/support/fixture.sql;
CALL bank_lab.sp_expect_ok(DATABASE(),'statement success','CALL {db}.sp_generate_statement(@p3_a,CURDATE(),CURDATE())');
CALL bank_lab.sp_expect_ok(DATABASE(),'statement 366 inclusive days','CALL {db}.sp_generate_statement(@p3_a,DATE_SUB(CURDATE(),INTERVAL 365 DAY),CURDATE())');
CALL bank_lab.sp_expect_error(DATABASE(),'statement too long','CALL {db}.sp_generate_statement(@p3_a,DATE_SUB(CURDATE(),INTERVAL 366 DAY),CURDATE())',5018);
CALL bank_lab.sp_expect_error(DATABASE(),'statement reversed dates','CALL {db}.sp_generate_statement(@p3_a,CURDATE(),DATE_SUB(CURDATE(),INTERVAL 1 DAY))',5018);
CALL bank_lab.sp_expect_error(DATABASE(),'statement NULL date','CALL {db}.sp_generate_statement(@p3_a,NULL,CURDATE())',5018);
CALL bank_lab.sp_expect_error(DATABASE(),'statement missing account','CALL {db}.sp_generate_statement(-1,CURDATE(),CURDATE())',5002);
