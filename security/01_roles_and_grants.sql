-- Native mysql CLI: select the target schema, then SOURCE this file.
-- PREVIEW ONLY by default. Global roles/grants require explicit operator approval.
-- SET @rbac_apply=1 only after reviewing security/README.md and the printed plan.
-- Optional isolated role suffix: @rbac_role_suffix='_pr9_' + 8 lowercase hex chars.
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_install_rbac$$
CREATE PROCEDURE sp_install_rbac()
SQL SECURITY INVOKER
BEGIN
 DECLARE v_db VARCHAR(64) DEFAULT DATABASE();
 DECLARE v_suffix VARCHAR(32) DEFAULT COALESCE(@rbac_role_suffix,'');
 DECLARE v_apply INT DEFAULT COALESCE(@rbac_apply,0);
 DECLARE v_id INT DEFAULT 1;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  DROP TEMPORARY TABLE IF EXISTS _rbac_deployment_plan;
  SET @rbac_apply=0;
  RESIGNAL;
 END;
 IF v_db IS NULL OR v_apply NOT IN (0,1)
    OR (v_suffix<>'' AND v_suffix NOT REGEXP '^_pr9_[a-f0-9]{8}$')
    OR (v_apply=1 AND v_suffix<>'') THEN
  SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,
   MESSAGE_TEXT='E_INVALID_ARGUMENT: select target schema and validate RBAC options';
 END IF;
 DROP TEMPORARY TABLE IF EXISTS _rbac_deployment_plan;
 CREATE TEMPORARY TABLE _rbac_deployment_plan(id INT PRIMARY KEY AUTO_INCREMENT,sql_text TEXT NOT NULL);
 -- Account names are explicit; role suffixes support an approved isolated deployment.
 INSERT INTO _rbac_deployment_plan(sql_text)
 SELECT CONCAT('CREATE ROLE IF NOT EXISTS ''bank_',r.role_name,'_role',v_suffix,'''@''%''')
 FROM (SELECT 'customer' AS role_name UNION ALL SELECT 'teller' UNION ALL SELECT 'manager' UNION ALL SELECT 'auditor') r;
 -- Approved SELECT surface. No application role gets SELECT/UPDATE on banking base tables.
 -- Auditor's existing read-only Audit_Log grant is retained deliberately.
 INSERT INTO _rbac_deployment_plan(sql_text)
 SELECT CONCAT('GRANT SELECT ON `',REPLACE(v_db,'`','``'),'`.`',g.object_name,
  '` TO ''bank_',g.role_name,'_role',v_suffix,'''@''%''')
 FROM (
  SELECT 'customer' AS role_name,'v_customer_account_summary' AS object_name
  UNION ALL SELECT 'customer','v_transaction_activity'
  UNION ALL SELECT 'teller','v_transaction_activity'
  UNION ALL SELECT 'manager','v_customer_account_summary'
  UNION ALL SELECT 'manager','v_transaction_activity'
  UNION ALL SELECT 'manager','v_fraud_case_queue'
  UNION ALL SELECT 'auditor','v_fraud_case_queue'
  UNION ALL SELECT 'auditor','v_transaction_activity'
  UNION ALL SELECT 'auditor','Audit_Log'
 ) g;
 -- Public API policy restored from the pre-regression installer. No arbitrary CSV input.
 -- No private helper, raw function, fraud evaluator or wildcard EXECUTE grants.
 INSERT INTO _rbac_deployment_plan(sql_text)
 SELECT CONCAT('GRANT EXECUTE ON PROCEDURE `',REPLACE(v_db,'`','``'),'`.`',p.proc_name,
  '` TO ''bank_',r.role_name,'_role',v_suffix,'''@''%''')
 FROM (
  SELECT 'customer' AS role_name,'["sp_deposit","sp_withdraw","sp_transfer_funds","sp_transfer_funds_retry","sp_generate_statement"]' AS procs
  UNION ALL SELECT 'teller','["sp_register_customer","sp_update_customer","sp_open_account","sp_close_account","sp_set_account_status","sp_deposit","sp_withdraw","sp_transfer_funds","sp_transfer_funds_retry","sp_generate_statement","sp_reconcile_balances"]'
  UNION ALL SELECT 'manager','["sp_register_customer","sp_update_customer","sp_open_account","sp_close_account","sp_set_account_status","sp_deposit","sp_withdraw","sp_transfer_funds","sp_transfer_funds_retry","sp_generate_statement","sp_request_approval","sp_decide_approval","sp_disburse_loan","sp_review_fraud_flag","sp_reconcile_balances","sp_post_monthly_interest"]'
 ) r JOIN JSON_TABLE(r.procs,'$[*]' COLUMNS(proc_name VARCHAR(64) PATH '$')) p ON TRUE;
 -- MySQL 8.4 returns1295 for PREPARE CREATE ROLE. Use static role DDL for the
 -- standard deployment. Suffixed isolated plans must be executed by the CLI,
 -- as top-level statements, after approval; server-side suffixed apply is refused.
 IF v_apply=1 THEN
  CREATE ROLE IF NOT EXISTS 'bank_customer_role'@'%';
  CREATE ROLE IF NOT EXISTS 'bank_teller_role'@'%';
  CREATE ROLE IF NOT EXISTS 'bank_manager_role'@'%';
  CREATE ROLE IF NOT EXISTS 'bank_auditor_role'@'%';
 END IF;
 -- INSERT...SELECT can reserve AUTO_INCREMENT gaps; visit actual keys, never assume continuity.
 SELECT MIN(id) INTO v_id FROM _rbac_deployment_plan;
 WHILE v_id IS NOT NULL DO
  SELECT sql_text INTO @rbac_grant_sql FROM _rbac_deployment_plan WHERE id=v_id;
  SELECT CONCAT('RBAC|',IF(v_apply=1,'APPLY','PLAN'),'|',@rbac_grant_sql) AS rbac_plan;
  IF v_apply=1 AND @rbac_grant_sql LIKE 'GRANT %' THEN
   PREPARE rbac_grant_stmt FROM @rbac_grant_sql;
   EXECUTE rbac_grant_stmt;
   DEALLOCATE PREPARE rbac_grant_stmt;
  END IF;
  SELECT MIN(id) INTO v_id FROM _rbac_deployment_plan WHERE id>v_id;
 END WHILE;
 DROP TEMPORARY TABLE _rbac_deployment_plan;
 SET @rbac_grant_sql=NULL;
 SET @rbac_apply=0;
END$$
DELIMITER ;
CALL sp_install_rbac();
DROP PROCEDURE sp_install_rbac;
