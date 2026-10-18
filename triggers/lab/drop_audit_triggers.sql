-- Client must stop on errors (use Invoke-BankMysql); no --force.
DELIMITER $$
DROP PROCEDURE IF EXISTS bank_lab.sp_assert_audit_toggle_allowed$$
CREATE PROCEDURE bank_lab.sp_assert_audit_toggle_allowed(IN p_db VARCHAR(64))
SQL SECURITY INVOKER
BEGIN
 IF p_db IS NULL OR (p_db<>'bank_txn_scratch' AND COALESCE(@allow_trigger_toggle,0)<>1) THEN
  SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5017,MESSAGE_TEXT='E_LAB_MODE_FORBIDDEN: audit toggle requires scratch or explicit session override';
 END IF;
 IF EXISTS(SELECT 1 FROM information_schema.triggers WHERE trigger_schema=p_db AND event_object_table='Transactions' AND action_timing='AFTER' AND event_manipulation='INSERT' AND trigger_name<>'trg_transactions_ai_audit') THEN
  SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5017,MESSAGE_TEXT='E_LAB_MODE_FORBIDDEN: dependent fraud trigger must be removed by its owner before audit toggle';
 END IF;
END$$
DELIMITER ;
CALL bank_lab.sp_assert_audit_toggle_allowed(DATABASE());
DROP PROCEDURE bank_lab.sp_assert_audit_toggle_allowed;
DROP TRIGGER IF EXISTS trg_accounts_ai_audit;
DROP TRIGGER IF EXISTS trg_accounts_au_audit;
DROP TRIGGER IF EXISTS trg_accounts_ad_audit;
DROP TRIGGER IF EXISTS trg_transactions_ai_audit;
DROP TRIGGER IF EXISTS trg_transactions_au_audit;
DROP TRIGGER IF EXISTS trg_transactions_ad_audit;
DROP TRIGGER IF EXISTS trg_loans_ai_audit;
DROP TRIGGER IF EXISTS trg_loans_au_audit;
DROP TRIGGER IF EXISTS trg_loans_ad_audit;
