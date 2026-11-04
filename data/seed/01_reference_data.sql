-- Synthetic reference data only. Natural unique keys make repeated loads idempotent.
INSERT INTO Branches(branch_name,ifsc_code,address,city,state,phone) VALUES
 ('Synthetic Central','SYNB0000001','1 Synthetic Road','Bengaluru','Karnataka','0000000001'),
 ('Synthetic North','SYNB0000002','2 Synthetic Road','Mysuru','Karnataka','0000000002'),
 ('Synthetic South','SYNB0000003','3 Synthetic Road','Mangaluru','Karnataka','0000000003')
ON DUPLICATE KEY UPDATE branch_name=VALUES(branch_name),address=VALUES(address),city=VALUES(city),state=VALUES(state),phone=VALUES(phone);
INSERT INTO Account_Types(type_name,interest_rate,min_balance) VALUES
 ('Savings',3.50,1000.00),('Current',0.00,5000.00),('Fixed Deposit',6.50,10000.00)
ON DUPLICATE KEY UPDATE interest_rate=VALUES(interest_rate),min_balance=VALUES(min_balance);
INSERT INTO Employees(branch_id,full_name,role,email,hire_date,is_active)
SELECT branch_id,'Synthetic Teller One','Teller','teller.one@example.invalid','2020-01-01',TRUE FROM Branches WHERE ifsc_code='SYNB0000001'
UNION ALL SELECT branch_id,'Synthetic Teller Two','Teller','teller.two@example.invalid','2020-01-01',TRUE FROM Branches WHERE ifsc_code='SYNB0000002'
UNION ALL SELECT branch_id,'Synthetic Manager One','Manager','manager.one@example.invalid','2020-01-01',TRUE FROM Branches WHERE ifsc_code='SYNB0000001'
UNION ALL SELECT branch_id,'Synthetic Manager Two','Manager','manager.two@example.invalid','2020-01-01',TRUE FROM Branches WHERE ifsc_code='SYNB0000002'
UNION ALL SELECT branch_id,'Synthetic DBA','DBA','dba@example.invalid','2020-01-01',TRUE FROM Branches WHERE ifsc_code='SYNB0000001'
ON DUPLICATE KEY UPDATE branch_id=VALUES(branch_id),full_name=VALUES(full_name),role=VALUES(role),hire_date=VALUES(hire_date),is_active=VALUES(is_active);
