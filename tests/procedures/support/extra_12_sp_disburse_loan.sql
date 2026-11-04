CALL bank_lab.sp_expect_ok(DATABASE(),'loan unrouted Manager','CALL {db}.sp_disburse_loan(@p3_c1,NULL,100,0,1,@p3_m1,@p3_loan)');
INSERT INTO DB_User_Map(db_login,actor_type,customer_id) VALUES(USER(),'Customer',@p3_c2);
CALL bank_lab.sp_expect_error(DATABASE(),'loan Customer cannot borrow as another owner','CALL {db}.sp_disburse_loan(@p3_c1,@p3_a,100,6,12,NULL,@p3_loan)',5010);
DELETE FROM DB_User_Map WHERE db_login=USER();
INSERT INTO DB_User_Map(db_login,actor_type,employee_id) VALUES(USER(),'Employee',@p3_t1);
CALL bank_lab.sp_expect_error(DATABASE(),'loan unrouted employee spoof','CALL {db}.sp_disburse_loan(@p3_c1,NULL,100,6,12,@p3_t2,@p3_loan)',5010);
DELETE FROM DB_User_Map WHERE db_login=USER();
