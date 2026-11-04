INSERT INTO DB_User_Map(db_login,actor_type,employee_id) VALUES(USER(),'Employee',@p3_t1);
CALL bank_lab.sp_expect_error(DATABASE(),'request employee wrong branch','CALL {db}.sp_request_approval(@p3_b,@p3_a,100000,@p3_t1,NULL,@p3_approval)',5010);
DELETE FROM DB_User_Map WHERE db_login=USER();
CALL sp_close_account(@p3_b,NULL,1);
INSERT INTO DB_User_Map(db_login,actor_type,customer_id) VALUES(USER(),'Customer',@p3_c1);
CALL bank_lab.sp_expect_error(DATABASE(),'request Closed account','CALL {db}.sp_request_approval(@p3_a,@p3_b,100000,NULL,@p3_c1,@p3_approval)',5003);
DELETE FROM DB_User_Map WHERE db_login=USER();
