DELIMITER $$
CREATE TRIGGER trg_loans_au_audit AFTER UPDATE ON Loans FOR EACH ROW
BEGIN
 DECLARE v_actor VARCHAR(10);
 DECLARE v_employee INT;
 DECLARE v_customer INT;
 CALL sp_resolve_actor(USER(),v_actor,v_employee,v_customer);
 INSERT INTO Audit_Log(table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,actor_employee_id,actor_customer_id)
 VALUES('Loans',CAST(NEW.loan_id AS CHAR),'UPDATE',JSON_OBJECT('loan_id',OLD.loan_id,'customer_id',OLD.customer_id,'disbursement_account_id',OLD.disbursement_account_id,'principal_amount',OLD.principal_amount,'interest_rate',OLD.interest_rate,'tenure_months',OLD.tenure_months,'status',OLD.status,'disbursed_date',OLD.disbursed_date),JSON_OBJECT('loan_id',NEW.loan_id,'customer_id',NEW.customer_id,'disbursement_account_id',NEW.disbursement_account_id,'principal_amount',NEW.principal_amount,'interest_rate',NEW.interest_rate,'tenure_months',NEW.tenure_months,'status',NEW.status,'disbursed_date',NEW.disbursed_date),USER(),v_actor,v_employee,v_customer);
END$$
DELIMITER ;
