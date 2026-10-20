-- Run in the target application schema as a DBA. No database name is hard-coded.
-- Definer views encapsulate base-table access; role users receive view access, not base-table SELECT.
SET @rbac_db=DATABASE();
SELECT @rbac_db AS rbac_target_database;

CREATE ROLE IF NOT EXISTS 'bank_customer_role';
CREATE ROLE IF NOT EXISTS 'bank_teller_role';
CREATE ROLE IF NOT EXISTS 'bank_manager_role';
CREATE ROLE IF NOT EXISTS 'bank_auditor_role';

-- View privileges. Rows are filtered by USER() and the same exact/bare/unambiguous
-- mapping precedence used by sp_resolve_actor.
SET @rbac_sql=CONCAT('GRANT SELECT ON `',REPLACE(@rbac_db,'`','``'),'`.v_customer_account_summary TO ''bank_customer_role''');
PREPARE rbac_stmt FROM @rbac_sql; EXECUTE rbac_stmt; DEALLOCATE PREPARE rbac_stmt;
SET @rbac_sql=CONCAT('GRANT SELECT ON `',REPLACE(@rbac_db,'`','``'),'`.v_transaction_activity TO ''bank_customer_role''');
PREPARE rbac_stmt FROM @rbac_sql; EXECUTE rbac_stmt; DEALLOCATE PREPARE rbac_stmt;
SET @rbac_sql=CONCAT('GRANT SELECT ON `',REPLACE(@rbac_db,'`','``'),'`.v_transaction_activity TO ''bank_teller_role''');
PREPARE rbac_stmt FROM @rbac_sql; EXECUTE rbac_stmt; DEALLOCATE PREPARE rbac_stmt;
SET @rbac_sql=CONCAT('GRANT SELECT ON `',REPLACE(@rbac_db,'`','``'),'`.v_customer_account_summary TO ''bank_manager_role''');
PREPARE rbac_stmt FROM @rbac_sql; EXECUTE rbac_stmt; DEALLOCATE PREPARE rbac_stmt;
SET @rbac_sql=CONCAT('GRANT SELECT ON `',REPLACE(@rbac_db,'`','``'),'`.v_transaction_activity TO ''bank_manager_role''');
PREPARE rbac_stmt FROM @rbac_sql; EXECUTE rbac_stmt; DEALLOCATE PREPARE rbac_stmt;
SET @rbac_sql=CONCAT('GRANT SELECT ON `',REPLACE(@rbac_db,'`','``'),'`.v_fraud_case_queue TO ''bank_manager_role''');
PREPARE rbac_stmt FROM @rbac_sql; EXECUTE rbac_stmt; DEALLOCATE PREPARE rbac_stmt;
SET @rbac_sql=CONCAT('GRANT SELECT ON `',REPLACE(@rbac_db,'`','``'),'`.v_fraud_case_queue TO ''bank_auditor_role''');
PREPARE rbac_stmt FROM @rbac_sql; EXECUTE rbac_stmt; DEALLOCATE PREPARE rbac_stmt;
SET @rbac_sql=CONCAT('GRANT SELECT ON `',REPLACE(@rbac_db,'`','``'),'`.v_transaction_activity TO ''bank_auditor_role''');
PREPARE rbac_stmt FROM @rbac_sql; EXECUTE rbac_stmt; DEALLOCATE PREPARE rbac_stmt;
SET @rbac_sql=CONCAT('GRANT SELECT ON `',REPLACE(@rbac_db,'`','``'),'`.Audit_Log TO ''bank_auditor_role''');
PREPARE rbac_stmt FROM @rbac_sql; EXECUTE rbac_stmt; DEALLOCATE PREPARE rbac_stmt;

-- Public API EXECUTE policy. Private sp_internal_* helpers are intentionally excluded.
-- Customers: own-account constrained deposit/withdraw/transfer APIs and statement.
-- Teller: customer/account servicing and ordinary transaction APIs.
-- Manager: public servicing plus approval and fraud review APIs.
-- Transient helper: dynamically grants only the literal procedure lists below, then is dropped.
DELIMITER $$
CREATE PROCEDURE sp_install_role_procedure_grants(IN p_db VARCHAR(64), IN p_role VARCHAR(64), IN p_csv TEXT)
SQL SECURITY INVOKER
BEGIN
  DECLARE v_rest TEXT DEFAULT p_csv;
  DECLARE v_proc VARCHAR(64);
  DECLARE v_pos INT;
  DECLARE v_sql TEXT;
  IF p_db IS NULL OR p_role NOT IN ('bank_customer_role','bank_teller_role','bank_manager_role') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid RBAC target or role';
  END IF;
  grant_loop: LOOP
    SET v_pos=LOCATE(',',v_rest);
    IF v_pos=0 THEN SET v_proc=TRIM(v_rest); ELSE SET v_proc=TRIM(SUBSTRING(v_rest,1,v_pos-1)); END IF;
    IF v_proc='' THEN LEAVE grant_loop; END IF;
    SET v_sql=CONCAT('GRANT EXECUTE ON PROCEDURE `',REPLACE(p_db,'`','``'),'`.`',REPLACE(v_proc,'`','``'),
                     '` TO ''',p_role,'''');
    PREPARE grant_stmt FROM v_sql; EXECUTE grant_stmt; DEALLOCATE PREPARE grant_stmt;
    IF v_pos=0 THEN LEAVE grant_loop; END IF;
    SET v_rest=SUBSTRING(v_rest,v_pos+1);
  END LOOP;
END$$
DELIMITER ;
SET @rbac_procs_customer='sp_deposit,sp_withdraw,sp_transfer_funds,sp_transfer_funds_retry,sp_generate_statement';
SET @rbac_procs_teller='sp_register_customer,sp_update_customer,sp_open_account,sp_close_account,sp_set_account_status,sp_deposit,sp_withdraw,sp_transfer_funds,sp_transfer_funds_retry,sp_generate_statement,sp_reconcile_balances';
SET @rbac_procs_manager='sp_register_customer,sp_update_customer,sp_open_account,sp_close_account,sp_set_account_status,sp_deposit,sp_withdraw,sp_transfer_funds,sp_transfer_funds_retry,sp_generate_statement,sp_request_approval,sp_decide_approval,sp_disburse_loan,sp_review_fraud_flag,sp_reconcile_balances,sp_post_monthly_interest';
-- Procedure identifiers are drawn only from the constants above.
SET @role_name='bank_customer_role'; SET @proc_list=@rbac_procs_customer; CALL sp_install_role_procedure_grants(@rbac_db,@role_name,@proc_list);
SET @role_name='bank_teller_role'; SET @proc_list=@rbac_procs_teller; CALL sp_install_role_procedure_grants(@rbac_db,@role_name,@proc_list);
SET @role_name='bank_manager_role'; SET @proc_list=@rbac_procs_manager; CALL sp_install_role_procedure_grants(@rbac_db,@role_name,@proc_list);
-- Auditor intentionally receives no banking mutation API.

DROP PROCEDURE IF EXISTS sp_install_role_procedure_grants;
