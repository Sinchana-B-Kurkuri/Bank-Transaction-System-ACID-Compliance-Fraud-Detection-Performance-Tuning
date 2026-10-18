SOURCE tests/procedures/support/fixture.sql;
CALL bank_lab.sp_expect_error(DATABASE(),'interest NULL period','CALL {db}.sp_post_monthly_interest(NULL,NULL,@p3_count,@p3_total)',5018);
CALL bank_lab.sp_expect_error(DATABASE(),'interest Teller denied','CALL {db}.sp_post_monthly_interest(CURDATE(),@p3_t1,@p3_count,@p3_total)',5010);
CALL bank_lab.sp_expect_ok(DATABASE(),'interest Manager success','CALL {db}.sp_post_monthly_interest(CURDATE(),@p3_m1,@p3_count,@p3_total)');
SET @p3_ok=(SELECT @p3_count>0 AND @p3_total>0 AND @interest_errors=0);
CALL bank_lab.sp_assert_true(DATABASE(),'interest count total and errors',@p3_ok,'Expected procedure contract');
CALL bank_lab.sp_expect_ok(DATABASE(),'interest second run idempotent','CALL {db}.sp_post_monthly_interest(CURDATE(),@p3_m1,@p3_count,@p3_total)');
SET @p3_ok=(SELECT @p3_count=0 AND @p3_total=0 AND @interest_errors=0);
CALL bank_lab.sp_assert_true(DATABASE(),'interest second run zero',@p3_ok,'Expected procedure contract');
UPDATE Account_Types SET interest_rate=0 WHERE account_type_id=@p3_type;
CALL bank_lab.sp_expect_ok(DATABASE(),'interest skips zero amounts','CALL {db}.sp_post_monthly_interest(DATE_SUB(CURDATE(),INTERVAL 2 MONTH),NULL,@p3_count,@p3_total)');
SET @p3_ok=(SELECT @p3_count=0 AND @p3_total=0);
CALL bank_lab.sp_assert_true(DATABASE(),'interest zero-rate results',@p3_ok,'Expected procedure contract');
UPDATE Account_Types SET interest_rate=3.50 WHERE account_type_id=@p3_type;
DROP TRIGGER IF EXISTS p3_interest_error_probe;
DELIMITER $$
CREATE TRIGGER p3_interest_error_probe BEFORE INSERT ON Transactions FOR EACH ROW FOLLOWS trg_transactions_bi_device_owner
BEGIN
 IF NEW.account_id=@p3_a AND NEW.transaction_type='InterestCredit' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='synthetic per-account interest failure'; END IF;
END$$
DELIMITER ;
CALL bank_lab.sp_expect_ok(DATABASE(),'interest per-account error continues','CALL {db}.sp_post_monthly_interest(DATE_SUB(CURDATE(),INTERVAL 3 MONTH),NULL,@p3_count,@p3_total)');
SET @p3_ok=(SELECT @interest_errors=1 AND @p3_count>0);
CALL bank_lab.sp_assert_true(DATABASE(),'interest counts one isolated error',@p3_ok,'Expected procedure contract');
DROP TRIGGER p3_interest_error_probe;
CALL bank_lab.sp_expect_ok(DATABASE(),'interest retries only previously failed account','CALL {db}.sp_post_monthly_interest(DATE_SUB(CURDATE(),INTERVAL 3 MONTH),@p3_dba,@p3_count,@p3_total)');
SET @p3_ok=(SELECT @p3_count=1 AND @interest_errors=0);
CALL bank_lab.sp_assert_true(DATABASE(),'interest one missed account recovered',@p3_ok,'Expected procedure contract');
