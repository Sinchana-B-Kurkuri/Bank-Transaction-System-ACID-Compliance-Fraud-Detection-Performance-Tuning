DELIMITER $$
CREATE TRIGGER trg_accounts_ai_audit AFTER INSERT ON Accounts FOR EACH ROW
BEGIN
 DECLARE v_actor VARCHAR(10);
 DECLARE v_employee INT;
 DECLARE v_customer INT;
 CALL sp_resolve_actor(USER(),v_actor,v_employee,v_customer);
 INSERT INTO Audit_Log(table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,actor_employee_id,actor_customer_id)
 VALUES('Accounts',CAST(NEW.account_id AS CHAR),'INSERT',NULL,JSON_OBJECT('account_id',NEW.account_id,'customer_id',NEW.customer_id,'branch_id',NEW.branch_id,'account_type_id',NEW.account_type_id,'account_number',NEW.account_number,'balance',NEW.balance,'status',NEW.status,'opened_date',NEW.opened_date),USER(),v_actor,v_employee,v_customer);
END$$
DELIMITER ;
