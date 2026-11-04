DELIMITER $$
CREATE TRIGGER trg_transactions_au_audit AFTER UPDATE ON Transactions FOR EACH ROW
BEGIN
 DECLARE v_actor VARCHAR(10);
 DECLARE v_employee INT;
 DECLARE v_customer INT;
 CALL sp_resolve_actor(USER(),v_actor,v_employee,v_customer);
 INSERT INTO Audit_Log(table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,actor_employee_id,actor_customer_id)
 VALUES('Transactions',CAST(NEW.transaction_id AS CHAR),'UPDATE',JSON_OBJECT('transaction_id',OLD.transaction_id,'account_id',OLD.account_id,'related_account_id',OLD.related_account_id,'employee_id',OLD.employee_id,'transfer_group_id',OLD.transfer_group_id,'device_id',OLD.device_id,'location_id',OLD.location_id,'transaction_type',OLD.transaction_type,'amount',OLD.amount,'balance_after',OLD.balance_after,'channel',OLD.channel,'status',OLD.status,'transaction_timestamp',OLD.transaction_timestamp,'reference_no',OLD.reference_no),JSON_OBJECT('transaction_id',NEW.transaction_id,'account_id',NEW.account_id,'related_account_id',NEW.related_account_id,'employee_id',NEW.employee_id,'transfer_group_id',NEW.transfer_group_id,'device_id',NEW.device_id,'location_id',NEW.location_id,'transaction_type',NEW.transaction_type,'amount',NEW.amount,'balance_after',NEW.balance_after,'channel',NEW.channel,'status',NEW.status,'transaction_timestamp',NEW.transaction_timestamp,'reference_no',NEW.reference_no),USER(),v_actor,v_employee,v_customer);
END$$
DELIMITER ;
