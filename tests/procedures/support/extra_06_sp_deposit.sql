CALL sp_open_account(@p3_c1,@p3_b1,@p3_type,2000,NULL,NULL,@p3_active,@p3_number);
INSERT INTO Devices(customer_id,device_fingerprint,device_type,first_seen_at,last_seen_at) VALUES(@p3_c1,SHA2(CONCAT(@p3_tag,'own'),256),'Synthetic',NOW(),NOW());
SET @p3_device=LAST_INSERT_ID();
INSERT INTO Locations(city,state,country,latitude,longitude) VALUES('Synthetic',NULL,'Synthetic',0,0);
SET @p3_location=LAST_INSERT_ID();
CALL bank_lab.sp_expect_ok(DATABASE(),'deposit stores context','CALL {db}.sp_deposit(@p3_active,1,''Mobile'',NULL,@p3_device,@p3_location,@p3_tx,@p3_balance)');
SET @p3_ok=(SELECT device_id=@p3_device AND location_id=@p3_location AND channel='Mobile' FROM Transactions WHERE transaction_id=@p3_tx);
CALL bank_lab.sp_assert_true(DATABASE(),'deposit context columns',@p3_ok,'Expected procedure contract');
