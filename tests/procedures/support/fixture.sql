-- Public APIs commit: each invocation uses fresh synthetic identities/numbers.
SET @p3_tag=REPLACE(UUID(),'-','');
SET @p3_b1=(SELECT branch_id FROM Branches WHERE ifsc_code='SYNB0000001');
SET @p3_b2=(SELECT branch_id FROM Branches WHERE ifsc_code='SYNB0000002');
SET @p3_type=(SELECT account_type_id FROM Account_Types WHERE type_name='Savings');
SET @p3_t1=(SELECT employee_id FROM Employees WHERE email='teller.one@example.invalid');
SET @p3_t2=(SELECT employee_id FROM Employees WHERE email='teller.two@example.invalid');
SET @p3_m1=(SELECT employee_id FROM Employees WHERE email='manager.one@example.invalid');
SET @p3_m2=(SELECT employee_id FROM Employees WHERE email='manager.two@example.invalid');
SET @p3_dba=(SELECT employee_id FROM Employees WHERE email='dba@example.invalid');
CALL sp_register_customer('Synthetic procedure fixture','1990-01-01',NULL,CONCAT('p3.',@p3_tag,'.a@example.invalid'),CONCAT('8',LPAD(MOD(UUID_SHORT(),1000000000),9,'0')),'Synthetic address',CONCAT('SYN-',LEFT(@p3_tag,24)),'Passport',@p3_c1);
CALL sp_register_customer('Synthetic second fixture','1990-01-01',NULL,CONCAT('p3.',@p3_tag,'.b@example.invalid'),CONCAT('8',LPAD(MOD(UUID_SHORT(),1000000000),9,'0')),'Synthetic address',CONCAT('SYN2-',LEFT(@p3_tag,24)),'Passport',@p3_c2);
CALL sp_open_account(@p3_c1,@p3_b1,@p3_type,500000,NULL,NULL,@p3_a,@p3_number);
CALL sp_open_account(@p3_c2,@p3_b2,@p3_type,5000,NULL,NULL,@p3_b,@p3_number);
