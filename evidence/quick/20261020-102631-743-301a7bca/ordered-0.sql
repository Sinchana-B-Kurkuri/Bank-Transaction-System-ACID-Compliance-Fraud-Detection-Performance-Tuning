SELECT CONCAT('META|',VERSION(),'|',NOW(6),'|',CONNECTION_ID()); SELECT CONCAT('CONNECTION|',CONNECTION_ID());
SET SESSION innodb_lock_wait_timeout=3; SET @lab_sleep_seconds=0.05;
CALL sp_transfer_funds(1,2,1,'Online',NULL,NULL,NULL,2,@g,@d,@c); SELECT 'RESULT|QUICK|ordered|completed|1';
CALL sp_transfer_funds(1,2,1,'Online',NULL,NULL,NULL,2,@g,@d,@c); SELECT 'RESULT|QUICK|ordered|completed|1';
CALL sp_transfer_funds(1,2,1,'Online',NULL,NULL,NULL,2,@g,@d,@c); SELECT 'RESULT|QUICK|ordered|completed|1';
CALL sp_transfer_funds(1,2,1,'Online',NULL,NULL,NULL,2,@g,@d,@c); SELECT 'RESULT|QUICK|ordered|completed|1';
CALL sp_transfer_funds(1,2,1,'Online',NULL,NULL,NULL,2,@g,@d,@c); SELECT 'RESULT|QUICK|ordered|completed|1';
