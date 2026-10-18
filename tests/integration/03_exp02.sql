-- Synthetic committed fixtures: public APIs own transaction boundaries.
SOURCE tests/procedures/support/fixture.sql;
DROP PROCEDURE IF EXISTS sp_p4_expect;
DELIMITER $$
CREATE PROCEDURE sp_p4_expect(IN p_name VARCHAR(200),IN p_sql TEXT,IN p_errno INT)
BEGIN
 DECLARE n INT DEFAULT 0; DECLARE m TEXT DEFAULT 'no error';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 n=MYSQL_ERRNO,m=MESSAGE_TEXT;
  SET @p4_sql=REPLACE(p_sql,'{db}',DATABASE());
  PREPARE p4_stmt FROM @p4_sql; EXECUTE p4_stmt; DEALLOCATE PREPARE p4_stmt;
 END;
 INSERT INTO bank_lab.Test_Results(run_id,db_name,test_name,status,detail,created_at) VALUES(COALESCE(@test_run_id,'adhoc'),DATABASE(),CONCAT('EXP02 ',p_name),IF(n=p_errno,'PASS','FAIL'),LEFT(CONCAT('expected=',p_errno,';actual=',n,';message=',m),500),NOW(3));
 SELECT CONCAT('TEST|',IF(n=p_errno,'PASS','FAIL'),'|EXP02 ',p_name,'|expected=',p_errno,';actual=',n,';message=',m);
END$$
DELIMITER ;
CALL sp_p4_expect('overdraw','CALL {db}.sp_withdraw(@p3_a,500001,''Online'',NULL,NULL,NULL,@t,@b)',5004);
CALL sp_p4_expect('below minimum','CALL {db}.sp_withdraw(@p3_a,499001,''Online'',NULL,NULL,NULL,@t,@b)',5004);
CALL sp_p4_expect('negative amount','CALL {db}.sp_deposit(@p3_a,-1,''Online'',NULL,NULL,NULL,@t,@b)',5001);
CALL sp_p4_expect('zero amount','CALL {db}.sp_deposit(@p3_a,0,''Online'',NULL,NULL,NULL,@t,@b)',5001);
CALL sp_p4_expect('same account','CALL {db}.sp_transfer_funds(@p3_a,@p3_a,1,''Online'',NULL,NULL,NULL,0,@g,@d,@c)',5005);
CALL sp_p4_expect('nonexistent account','CALL {db}.sp_deposit(-1,1,''Online'',NULL,NULL,NULL,@t,@b)',5002);
CALL sp_p4_expect('threshold','CALL {db}.sp_transfer_funds(@p3_a,@p3_b,100000,''Online'',NULL,NULL,NULL,0,@g,@d,@c)',5006);
CALL sp_p4_expect('ledger update','UPDATE {db}.Transactions SET amount=amount WHERE account_id=@p3_a',5012);
CALL sp_p4_expect('ledger delete','DELETE FROM {db}.Transactions WHERE account_id=@p3_a',5012);
CALL sp_p4_expect('audit update','UPDATE {db}.Audit_Log SET table_name=table_name WHERE table_name=''Accounts''',5013);
CALL sp_p4_expect('audit delete','DELETE FROM {db}.Audit_Log WHERE table_name=''Accounts''',5013);
CALL sp_p4_expect('raw negative balance','UPDATE {db}.Accounts SET balance=-1 WHERE account_id=@p3_a',5015);
CALL sp_p4_expect('raw zero amount','INSERT INTO {db}.Transactions(account_id,transaction_type,amount,balance_after,channel,status,reference_no) VALUES(@p3_a,''Deposit'',0,500000,''Online'',''Completed'',LEFT(UUID(),30))',3819);
CALL sp_p4_expect('raw nonexistent FK','INSERT INTO {db}.Transactions(account_id,transaction_type,amount,balance_after,channel,status,reference_no) VALUES(-1,''Deposit'',1,1,''Online'',''Completed'',LEFT(UUID(),30))',1452);
CALL sp_p4_expect('duplicate reference','INSERT INTO {db}.Transactions(account_id,transaction_type,amount,balance_after,channel,status,reference_no) SELECT account_id,transaction_type,amount,balance_after,channel,status,reference_no FROM {db}.Transactions WHERE account_id=@p3_a LIMIT 1',1062);
CALL sp_set_account_status(@p3_b,'Frozen',@p3_t2);
CALL sp_p4_expect('frozen','CALL {db}.sp_deposit(@p3_b,1,''Online'',NULL,NULL,NULL,@t,@b)',5003);
CALL sp_close_account(@p3_b,NULL,1);
CALL sp_p4_expect('closed','CALL {db}.sp_deposit(@p3_b,1,''Online'',NULL,NULL,NULL,@t,@b)',5003);
INSERT INTO Devices(customer_id,device_fingerprint,device_type,first_seen_at,last_seen_at) VALUES(@p3_c2,SHA2(UUID(),256),'Synthetic',NOW(),NOW());
SET @p4_device=LAST_INSERT_ID();
CALL sp_p4_expect('device owner','CALL {db}.sp_deposit(@p3_a,1,''Online'',NULL,@p4_device,NULL,@t,@b)',5014);
DROP PROCEDURE sp_p4_expect;
