INSERT INTO bank_lab.Experiment_Log(db_name,exp_id,event_type,detail)
SELECT DATABASE(),'SYS','AUDIT_TRIGGERS_INSTALLED',JSON_OBJECT(
 'db',DATABASE(),'accounts_max_id',(SELECT COALESCE(MAX(account_id),0) FROM Accounts),
 'transactions_max_id',(SELECT COALESCE(MAX(transaction_id),0) FROM Transactions),
 'loans_max_id',(SELECT COALESCE(MAX(loan_id),0) FROM Loans),
 'audit_max_id',(SELECT COALESCE(MAX(audit_id),0) FROM Audit_Log),'installed_at',NOW(3));
