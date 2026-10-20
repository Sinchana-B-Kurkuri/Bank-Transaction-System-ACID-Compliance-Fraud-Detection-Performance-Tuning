-- Included from tests/regression/error1222_seed.sql
-- Invoked only by error1222_seed.ps1 in a fresh owned disposable database.
-- The harness installs the ORIGINAL tiny-loader definition without its final
-- CALL/DROP, so each invocation below exercises the real public API/trigger chain.
CALL p3_load_tiny_seed();
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_equal(DATABASE(),'1222 seed customers','6',(SELECT COUNT(*) FROM Customers));
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_equal(DATABASE(),'1222 seed accounts','8',(SELECT COUNT(*) FROM Accounts));
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_equal(DATABASE(),'1222 seed loan','1',(SELECT COUNT(*) FROM Loans));
SET @counts=CONCAT((SELECT COUNT(*) FROM Customers),'|',(SELECT COUNT(*) FROM Accounts),'|',(SELECT COUNT(*) FROM Loans),'|',(SELECT COUNT(*) FROM Transactions),'|',(SELECT COUNT(*) FROM Audit_Log),'|',(SELECT COUNT(*) FROM Fraud_Flags));
CALL p3_load_tiny_seed();
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_true(DATABASE(),'1222 seed rerun idempotent',@counts=CONCAT((SELECT COUNT(*) FROM Customers),'|',(SELECT COUNT(*) FROM Accounts),'|',(SELECT COUNT(*) FROM Loans),'|',(SELECT COUNT(*) FROM Transactions),'|',(SELECT COUNT(*) FROM Audit_Log),'|',(SELECT COUNT(*) FROM Fraud_Flags)),'No duplicate rows or extra audit/flag writes');

SET @customer=(SELECT customer_id FROM Customers WHERE email='seed.customer.1@example.invalid');
SET @branch=(SELECT branch_id FROM Branches WHERE ifsc_code='SYNB0000001');
SET @type=(SELECT account_type_id FROM Account_Types WHERE type_name='Savings');
SET @teller=(SELECT employee_id FROM Employees WHERE email='teller.one@example.invalid');
CALL sp_open_account(@customer,@branch,@type,2000,@teller,'E1222-OPEN-01',@opened,@number);
SET @tx=(SELECT transaction_id FROM Transactions WHERE account_id=@opened);
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_true(DATABASE(),'1222 independent opening account',@opened IS NOT NULL AND (SELECT balance=2000 FROM Accounts WHERE account_id=@opened),'Real sp_open_account returned and committed');
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_equal(DATABASE(),'1222 opening ledger','1',(SELECT COUNT(*) FROM Transactions WHERE account_id=@opened AND transaction_type='Deposit' AND amount=2000 AND balance_after=2000 AND status='Completed'));
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_true(DATABASE(),'1222 automatic fraud evaluation',(SELECT COUNT(*)>0 FROM Fraud_Flags WHERE transaction_id=@tx),'Actual AFTER INSERT fraud trigger wrote flags');
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_equal(DATABASE(),'1222 opening risk profile','1',(SELECT COUNT(*) FROM Account_Risk_Profile WHERE account_id=@opened));
CALL sp_evaluate_fraud(@tx);
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_true(DATABASE(),'1222 direct evaluator timestamp',(SELECT COUNT(*)>0 AND SUM(CAST(JSON_UNQUOTE(JSON_EXTRACT(f.evidence,'$.evaluated_transaction_timestamp')) AS DATETIME)=t.transaction_timestamp)=COUNT(*) FROM Fraud_Flags f JOIN Transactions t ON t.transaction_id=f.transaction_id WHERE f.transaction_id=@tx),'Fifth SELECT value reaches v_txn_ts and JSON evidence');
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_equal(DATABASE(),'1222 opening account INSERT audit','1',(SELECT COUNT(*) FROM Audit_Log WHERE table_name='Accounts' AND record_pk=CAST(@opened AS CHAR) AND action_type='INSERT'));
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_equal(DATABASE(),'1222 opening account UPDATE audit','1',(SELECT COUNT(*) FROM Audit_Log WHERE table_name='Accounts' AND record_pk=CAST(@opened AS CHAR) AND action_type='UPDATE' AND CAST(JSON_UNQUOTE(JSON_EXTRACT(new_value,'$.balance')) AS DECIMAL(14,2))=2000 AND db_session_user=USER()));
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_equal(DATABASE(),'1222 opening transaction audit','1',(SELECT COUNT(*) FROM Audit_Log WHERE table_name='Transactions' AND record_pk=CAST(@tx AS CHAR) AND action_type='INSERT' AND JSON_UNQUOTE(JSON_EXTRACT(new_value,'$.status'))='Completed' AND db_session_user=USER()));
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_true(DATABASE(),'1222 audit before fraud',(SELECT a.action_order<f.action_order FROM information_schema.triggers a JOIN information_schema.triggers f ON f.trigger_schema=a.trigger_schema WHERE a.trigger_schema=DATABASE() AND a.trigger_name='trg_transactions_ai_audit' AND f.trigger_name='trg_transactions_ai_fraud_evaluate'),'Real installed AFTER INSERT action ordering');

SET @a=(SELECT account_id FROM Accounts WHERE account_number='SEED-0001');
SET @b=(SELECT account_id FROM Accounts WHERE account_number='SEED-0002');
SET @snapshot=CONCAT((SELECT balance FROM Accounts WHERE account_id=@a),'|',(SELECT balance FROM Accounts WHERE account_id=@b),'|',(SELECT COUNT(*) FROM Transactions),'|',(SELECT COUNT(*) FROM Audit_Log),'|',(SELECT COUNT(*) FROM Fraud_Flags),'|',(SELECT SUM(risk_score) FROM Account_Risk_Profile));
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_expect_error(DATABASE(),'1222 transfer real injected rollback','CALL {db}.sp_transfer_funds(@a,@b,1,''Online'',NULL,NULL,NULL,1,@g,@d,@c)',5016);
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_true(DATABASE(),'1222 rollback balances ledger audit fraud',@snapshot=CONCAT((SELECT balance FROM Accounts WHERE account_id=@a),'|',(SELECT balance FROM Accounts WHERE account_id=@b),'|',(SELECT COUNT(*) FROM Transactions),'|',(SELECT COUNT(*) FROM Audit_Log),'|',(SELECT COUNT(*) FROM Fraud_Flags),'|',(SELECT SUM(risk_score) FROM Account_Risk_Profile)),'Both balances and all transactional side effects unchanged');
CALL sp_transfer_funds(@a,@b,1,'Online',NULL,NULL,NULL,0,@g,@d,@c);
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_equal(DATABASE(),'1222 ordered forward pair','2',(SELECT COUNT(*) FROM Transactions WHERE transfer_group_id=@g AND status='Completed'));
CALL sp_transfer_funds(@b,@a,1,'Online',NULL,NULL,NULL,0,@g,@d,@c);
CALL bank_b_1222_99291cc5eb2d45339bec1be511d0c743_after.sp_assert_equal(DATABASE(),'1222 ordered reverse pair','2',(SELECT COUNT(*) FROM Transactions WHERE transfer_group_id=@g AND status='Completed'));
CALL sp_reconcile_balances(NULL);
SELECT CONCAT('TEST|',status,'|1222 invariant ',invariant,'|violations=',violations)
FROM JSON_TABLE(@reconcile_results,'$[*]' COLUMNS(invariant VARCHAR(4) PATH '$.invariant',violations BIGINT PATH '$.violations',status VARCHAR(4) PATH '$.status')) j ORDER BY invariant;
