INSERT INTO Employees(branch_id,full_name,role,email,hire_date,is_active) VALUES(@p3_b2,'Synthetic inactive Manager','Manager',CONCAT('inactive.',@p3_tag,'@example.invalid'),'2020-01-01',FALSE);
SET @p3_inactive_employee=LAST_INSERT_ID();
CALL bank_lab.sp_expect_error(DATABASE(),'status inactive employee','CALL {db}.sp_set_account_status(@p3_b,''Frozen'',@p3_inactive_employee)',5010);
