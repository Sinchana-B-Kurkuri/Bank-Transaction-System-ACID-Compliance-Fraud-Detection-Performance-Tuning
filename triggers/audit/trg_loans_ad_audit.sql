DELIMITER $$
CREATE TRIGGER trg_loans_ad_audit AFTER DELETE ON Loans FOR EACH ROW
BEGIN
 DECLARE v_actor VARCHAR(10);
 DECLARE v_employee INT;
 DECLARE v_customer INT;
 CALL sp_resolve_actor(USER(),v_actor,v_employee,v_customer);
 INSERT INTO Audit_Log(table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,actor_employee_id,actor_customer_id)
 VALUES('Loans',CAST(OLD.loan_id AS CHAR),'DELETE',JSON_OBJECT('loan_id',OLD.loan_id,'customer_id',OLD.customer_id,'disbursement_account_id',OLD.disbursement_account_id,'principal_amount',OLD.principal_amount,'interest_rate',OLD.interest_rate,'tenure_months',OLD.tenure_months,'status',OLD.status,'disbursed_date',OLD.disbursed_date),NULL,USER(),v_actor,v_employee,v_customer);
END$$
DELIMITER ;
