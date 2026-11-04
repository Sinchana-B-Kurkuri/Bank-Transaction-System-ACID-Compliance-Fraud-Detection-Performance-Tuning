SOURCE tests/procedures/support/fixture.sql;
CALL bank_lab.sp_expect_ok(DATABASE(),'deposit Online','CALL {db}.sp_deposit(@p3_a,10,''Online'',NULL,NULL,NULL,@p3_tx,@p3_balance)');
SET @p3_ok=(SELECT @p3_balance=500010 AND account_id=@p3_a AND amount=10 AND balance_after=@p3_balance AND status='Completed' FROM Transactions WHERE transaction_id=@p3_tx);
CALL bank_lab.sp_assert_true(DATABASE(),'deposit return values',@p3_ok,'Expected procedure contract');
CALL bank_lab.sp_expect_ok(DATABASE(),'deposit Branch Teller','CALL {db}.sp_deposit(@p3_a,5,''Branch'',@p3_t1,NULL,NULL,@p3_tx,@p3_balance)');
CALL bank_lab.sp_expect_error(DATABASE(),'deposit amount 0','CALL {db}.sp_deposit(@p3_a,0,''Online'',NULL,NULL,NULL,@p3_tx,@p3_balance)',5001);
CALL bank_lab.sp_expect_error(DATABASE(),'deposit amount -1','CALL {db}.sp_deposit(@p3_a,-1,''Online'',NULL,NULL,NULL,@p3_tx,@p3_balance)',5001);
CALL bank_lab.sp_expect_error(DATABASE(),'deposit amount NULL','CALL {db}.sp_deposit(@p3_a,NULL,''Online'',NULL,NULL,NULL,@p3_tx,@p3_balance)',5001);
SET @p3_failed=(SELECT COUNT(*) FROM Transactions WHERE status='Failed');
CALL bank_lab.sp_expect_error(DATABASE(),'deposit missing account','CALL {db}.sp_deposit(-1,10,''Online'',NULL,NULL,NULL,@p3_tx,@p3_balance)',5002);
SET @p3_ok=(SELECT COUNT(*)=@p3_failed FROM Transactions WHERE status='Failed');
CALL bank_lab.sp_assert_true(DATABASE(),'deposit missing account no Failed',@p3_ok,'Expected procedure contract');
CALL bank_lab.sp_expect_error(DATABASE(),'deposit invalid channel','CALL {db}.sp_deposit(@p3_a,10,''Other'',NULL,NULL,NULL,@p3_tx,@p3_balance)',5018);
CALL bank_lab.sp_expect_error(DATABASE(),'deposit wrong branch','CALL {db}.sp_deposit(@p3_a,10,''Branch'',@p3_t2,NULL,NULL,@p3_tx,@p3_balance)',5010);
CALL bank_lab.sp_expect_error(DATABASE(),'deposit Branch NULL','CALL {db}.sp_deposit(@p3_a,10,''Branch'',NULL,NULL,NULL,@p3_tx,@p3_balance)',5010);
CALL bank_lab.sp_expect_error(DATABASE(),'deposit Branch Manager','CALL {db}.sp_deposit(@p3_a,10,''Branch'',@p3_m1,NULL,NULL,@p3_tx,@p3_balance)',5010);
CALL bank_lab.sp_expect_error(DATABASE(),'deposit Online employee','CALL {db}.sp_deposit(@p3_a,10,''Online'',@p3_t1,NULL,NULL,@p3_tx,@p3_balance)',5010);
INSERT INTO Devices(customer_id,device_fingerprint,device_type,first_seen_at,last_seen_at) VALUES(@p3_c2,SHA2(@p3_tag,256),'Synthetic',NOW(),NOW());
SET @p3_device=LAST_INSERT_ID();
SET @p3_old=(SELECT balance FROM Accounts WHERE account_id=@p3_a);
CALL bank_lab.sp_expect_error(DATABASE(),'deposit device owner mismatch','CALL {db}.sp_deposit(@p3_a,1,''Online'',NULL,@p3_device,NULL,@p3_tx,@p3_balance)',5014);
SET @p3_ok=(SELECT balance=@p3_old FROM Accounts WHERE account_id=@p3_a);
CALL bank_lab.sp_assert_true(DATABASE(),'deposit mismatch rolls back balance',@p3_ok,'Expected procedure contract');
CALL bank_lab.sp_expect_error(DATABASE(),'deposit missing device','CALL {db}.sp_deposit(@p3_a,1,''Online'',NULL,-1,NULL,@p3_tx,@p3_balance)',1452);
CALL bank_lab.sp_expect_error(DATABASE(),'deposit missing location','CALL {db}.sp_deposit(@p3_a,1,''Online'',NULL,NULL,-1,@p3_tx,@p3_balance)',1452);
SET @p3_collision_ref=(SELECT reference_no FROM Transactions WHERE account_id=@p3_a ORDER BY transaction_id LIMIT 1);
DROP TRIGGER IF EXISTS p3_reference_collision_probe;
DELIMITER $$
CREATE TRIGGER p3_reference_collision_probe BEFORE INSERT ON Transactions FOR EACH ROW FOLLOWS trg_transactions_bi_device_owner
BEGIN
 IF NEW.account_id=@p3_a AND NEW.transaction_type='Deposit' AND COALESCE(@p3_collisions,0)>0 THEN SET @p3_collisions=@p3_collisions-1; SET NEW.reference_no=@p3_collision_ref; END IF;
END$$
DELIMITER ;
SET @p3_collisions=2;
CALL bank_lab.sp_expect_ok(DATABASE(),'deposit reference collision retries','CALL {db}.sp_deposit(@p3_a,1,''Online'',NULL,NULL,NULL,@p3_tx,@p3_balance)');
SET @p3_ok=(SELECT balance=@p3_old+1 AND @p3_collisions=0 FROM Accounts WHERE account_id=@p3_a);
CALL bank_lab.sp_assert_true(DATABASE(),'deposit exactly one credit after retries',@p3_ok,'Expected procedure contract');
SET @p3_collisions=5;
SET @p3_old=(SELECT balance FROM Accounts WHERE account_id=@p3_a);
SET @p3_failed=(SELECT COUNT(*) FROM Transactions WHERE status='Failed');
CALL bank_lab.sp_expect_error(DATABASE(),'deposit collision retry exhausted','CALL {db}.sp_deposit(@p3_a,1,''Online'',NULL,NULL,NULL,@p3_tx,@p3_balance)',1062);
SET @p3_ok=(SELECT balance=@p3_old AND (SELECT COUNT(*) FROM Transactions WHERE status='Failed')=@p3_failed FROM Accounts WHERE account_id=@p3_a);
CALL bank_lab.sp_assert_true(DATABASE(),'deposit collision exhaustion rolls back',@p3_ok,'Expected procedure contract');
DROP TRIGGER p3_reference_collision_probe;
CALL sp_set_account_status(@p3_a,'Frozen',@p3_t1);
SET @p3_failed=(SELECT COUNT(*) FROM Transactions WHERE status='Failed');
CALL bank_lab.sp_expect_error(DATABASE(),'deposit Frozen','CALL {db}.sp_deposit(@p3_a,10,''Online'',NULL,NULL,NULL,@p3_tx,@p3_balance)',5003);
SET @p3_ok=(SELECT COUNT(*)=@p3_failed+1 FROM Transactions WHERE status='Failed');
CALL bank_lab.sp_assert_true(DATABASE(),'deposit Frozen records one Failed',@p3_ok,'Expected procedure contract');
CALL sp_set_account_status(@p3_a,'Active',@p3_t1);
CALL sp_close_account(@p3_a,NULL,1);
CALL bank_lab.sp_expect_error(DATABASE(),'deposit Closed','CALL {db}.sp_deposit(@p3_a,10,''Online'',NULL,NULL,NULL,@p3_tx,@p3_balance)',5003);

SOURCE tests/procedures/support/extra_06_sp_deposit.sql;
