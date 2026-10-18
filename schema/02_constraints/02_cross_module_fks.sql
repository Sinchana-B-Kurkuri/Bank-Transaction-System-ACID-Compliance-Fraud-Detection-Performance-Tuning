SET @cross_sql = IF(
 EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='Devices')
 AND NOT EXISTS(SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema=DATABASE() AND table_name='Transactions' AND constraint_name='fk_transactions_device'),
 'ALTER TABLE Transactions ADD CONSTRAINT fk_transactions_device FOREIGN KEY (device_id) REFERENCES Devices(device_id) ON DELETE RESTRICT ON UPDATE RESTRICT', 'DO 0');
PREPARE cross_stmt FROM @cross_sql;
EXECUTE cross_stmt;
DEALLOCATE PREPARE cross_stmt;
SET @cross_sql = IF(
 EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='Locations')
 AND NOT EXISTS(SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema=DATABASE() AND table_name='Transactions' AND constraint_name='fk_transactions_location'),
 'ALTER TABLE Transactions ADD CONSTRAINT fk_transactions_location FOREIGN KEY (location_id) REFERENCES Locations(location_id) ON DELETE RESTRICT ON UPDATE RESTRICT', 'DO 0');
PREPARE cross_stmt FROM @cross_sql;
EXECUTE cross_stmt;
DEALLOCATE PREPARE cross_stmt;
SET @cross_sql = IF(
 EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='Fraud_Rules')
 AND NOT EXISTS(SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema=DATABASE() AND table_name='Fraud_Flags' AND constraint_name='fk_fraud_flags_rule'),
 'ALTER TABLE Fraud_Flags ADD CONSTRAINT fk_fraud_flags_rule FOREIGN KEY (rule_id) REFERENCES Fraud_Rules(rule_id) ON DELETE RESTRICT ON UPDATE RESTRICT', 'DO 0');
PREPARE cross_stmt FROM @cross_sql;
EXECUTE cross_stmt;
DEALLOCATE PREPARE cross_stmt;
