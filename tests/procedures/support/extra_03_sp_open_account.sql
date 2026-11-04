CALL bank_lab.sp_expect_error(DATABASE(),'open NULL customer','CALL {db}.sp_open_account(NULL,@p3_b1,@p3_type,1000,NULL,NULL,@p3_new,@p3_number)',5007);
CALL bank_lab.sp_expect_error(DATABASE(),'open NULL branch','CALL {db}.sp_open_account(@p3_c1,NULL,@p3_type,1000,NULL,NULL,@p3_new,@p3_number)',5007);
CALL bank_lab.sp_expect_error(DATABASE(),'open NULL type','CALL {db}.sp_open_account(@p3_c1,@p3_b1,NULL,1000,NULL,NULL,@p3_new,@p3_number)',5007);
INSERT INTO Employees(branch_id,full_name,role,email,hire_date,is_active) VALUES(@p3_b1,'Synthetic inactive Teller','Teller',CONCAT('inactive.',@p3_tag,'@example.invalid'),'2020-01-01',FALSE);
SET @p3_inactive_employee=LAST_INSERT_ID();
CALL bank_lab.sp_expect_error(DATABASE(),'open inactive employee','CALL {db}.sp_open_account(@p3_c1,@p3_b1,@p3_type,1000,@p3_inactive_employee,NULL,@p3_new,@p3_number)',5010);
SET @p3_existing_number=(SELECT account_number FROM Accounts WHERE account_id=@p3_a);
DROP TRIGGER IF EXISTS p3_account_collision_probe;
DELIMITER $$
CREATE TRIGGER p3_account_collision_probe BEFORE INSERT ON Accounts FOR EACH ROW
BEGIN
 IF COALESCE(@p3_account_collisions,0)>0 THEN SET @p3_account_collisions=@p3_account_collisions-1; SET NEW.account_number=@p3_existing_number; END IF;
END$$
DELIMITER ;
SET @p3_account_collisions=2;
CALL bank_lab.sp_expect_ok(DATABASE(),'open random number collision retries','CALL {db}.sp_open_account(@p3_c1,@p3_b1,@p3_type,1000,NULL,NULL,@p3_new,@p3_number)');
SET @p3_ok=(SELECT @p3_account_collisions=0 AND @p3_number<>@p3_existing_number);
CALL bank_lab.sp_assert_true(DATABASE(),'open collision retry complete',@p3_ok,'Expected procedure contract');
SET @p3_account_collisions=5;
SET @p3_rows=(SELECT COUNT(*) FROM Accounts);
CALL bank_lab.sp_expect_error(DATABASE(),'open random collision exhaustion','CALL {db}.sp_open_account(@p3_c1,@p3_b1,@p3_type,1000,NULL,NULL,@p3_new,@p3_number)',1062);
SET @p3_ok=(SELECT COUNT(*)=@p3_rows FROM Accounts);
CALL bank_lab.sp_assert_true(DATABASE(),'open collision exhaustion atomic',@p3_ok,'Expected procedure contract');
DROP TRIGGER p3_account_collision_probe;
