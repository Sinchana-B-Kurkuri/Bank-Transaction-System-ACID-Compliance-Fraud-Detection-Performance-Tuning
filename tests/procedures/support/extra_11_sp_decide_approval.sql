INSERT INTO DB_User_Map(db_login,actor_type,customer_id) VALUES(USER(),'Customer',@p3_c1);
CALL sp_request_approval(@p3_a,@p3_b,1000000,NULL,@p3_c1,@p3_approval);
DELETE FROM DB_User_Map WHERE db_login=USER();
CALL bank_lab.sp_expect_error(DATABASE(),'decide NULL manager','CALL {db}.sp_decide_approval(@p3_approval,''Approved'',NULL,@p3_group)',5010);
CALL bank_lab.sp_expect_error(DATABASE(),'decide approval insufficient funds','CALL {db}.sp_decide_approval(@p3_approval,''Approved'',@p3_m1,@p3_group)',5004);
SET @p3_ok=(SELECT status='Requested' AND resulting_transfer_group_id IS NULL FROM Transaction_Approvals WHERE approval_id=@p3_approval);
CALL bank_lab.sp_assert_true(DATABASE(),'decide insufficient leaves Requested',@p3_ok,'Expected procedure contract');
