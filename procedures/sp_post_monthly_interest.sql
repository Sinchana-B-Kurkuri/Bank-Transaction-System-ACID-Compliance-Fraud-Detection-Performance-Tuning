DELIMITER $$
CREATE PROCEDURE sp_post_monthly_interest(IN p_period_start DATE, IN p_employee_id INT, OUT p_accounts_credited INT, OUT p_total_interest DECIMAL(16,2))
SQL SECURITY DEFINER
BEGIN
 DECLARE v_done BOOLEAN DEFAULT FALSE;
 DECLARE v_account INT;
 DECLARE v_month DATE;
 DECLARE v_actor VARCHAR(10); DECLARE v_e INT; DECLARE v_c INT;
 DECLARE accounts_cursor CURSOR FOR SELECT a.account_id FROM Accounts a JOIN Account_Types t USING(account_type_id) WHERE a.status='Active' AND t.type_name='Savings' ORDER BY a.account_id;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done=TRUE;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 SET p_accounts_credited=0,p_total_interest=0,@interest_errors=0;
 IF p_period_start IS NULL THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: interest period is required'; END IF;
 SET v_month=CAST(DATE_FORMAT(p_period_start,'%Y-%m-01') AS DATE);
 CALL sp_resolve_actor(USER(),v_actor,v_e,v_c);
 IF v_actor='Customer' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: interest posting requires staff or system'; END IF;
 IF p_employee_id IS NOT NULL THEN CALL sp_internal_assert_staff(p_employee_id,NULL,'Manager,DBA'); END IF;
 IF v_actor='Employee' AND NOT EXISTS(SELECT 1 FROM Employees WHERE employee_id=v_e AND is_active AND role IN ('Manager','DBA')) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: manager or DBA required'; END IF;
 OPEN accounts_cursor;
 interest_loop: LOOP
  FETCH accounts_cursor INTO v_account;
  IF v_done THEN LEAVE interest_loop; END IF;
  account_work: BEGIN
   DECLARE v_missing BOOLEAN DEFAULT FALSE;
   DECLARE v_balance DECIMAL(14,2); DECLARE v_interest DECIMAL(14,2); DECLARE v_rate DECIMAL(5,2);
   DECLARE v_status VARCHAR(10); DECLARE v_type VARCHAR(30); DECLARE v_tx BIGINT; DECLARE v_reference VARCHAR(30);
   DECLARE v_errno INT;
   DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_missing=TRUE;
   DECLARE EXIT HANDLER FOR SQLEXCEPTION
   BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
    ROLLBACK;
    IF v_errno IN (5003,5004,5005,5006,5010) THEN
     BEGIN
      DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
      START TRANSACTION;
      CALL sp_internal_record_failed(v_account,v_interest,'InterestCredit','Branch');
      COMMIT;
     END;
    END IF;
    SET @interest_errors=@interest_errors+1;
   END;
   START TRANSACTION;
   SELECT a.balance,a.status,t.type_name,t.interest_rate INTO v_balance,v_status,v_type,v_rate FROM Accounts a JOIN Account_Types t USING(account_type_id) WHERE a.account_id=v_account FOR UPDATE OF a;
   IF v_missing OR v_status<>'Active' OR v_type<>'Savings' THEN COMMIT; LEAVE account_work; END IF;
   -- New postings keep their actual timestamp. A reference-linked period marker
   -- identifies historical/future requested months without corrupting statements.
   -- Unmarked (legacy) credits retain the timestamp-month convention.
   IF EXISTS(SELECT 1 FROM Transactions t WHERE t.account_id=v_account AND t.transaction_type='InterestCredit' AND t.status='Completed' AND (
    EXISTS(SELECT 1 FROM bank_lab.Experiment_Log l WHERE l.db_name=DATABASE() AND l.event_type='MONTHLY_INTEREST_POSTED' AND JSON_UNQUOTE(JSON_EXTRACT(l.detail,'$.reference_no'))=t.reference_no AND JSON_UNQUOTE(JSON_EXTRACT(l.detail,'$.period_start'))=CAST(v_month AS CHAR))
    OR (t.transaction_timestamp>=v_month AND t.transaction_timestamp<DATE_ADD(v_month,INTERVAL 1 MONTH) AND NOT EXISTS(SELECT 1 FROM bank_lab.Experiment_Log l WHERE l.db_name=DATABASE() AND l.event_type='MONTHLY_INTEREST_POSTED' AND JSON_UNQUOTE(JSON_EXTRACT(l.detail,'$.reference_no'))=t.reference_no))
   )) THEN COMMIT; LEAVE account_work; END IF;
   SET v_interest=ROUND(v_balance*v_rate/100/12,2);
   IF v_interest<=0 THEN COMMIT; LEAVE account_work; END IF;
   UPDATE Accounts SET balance=balance+v_interest WHERE account_id=v_account;
   CALL sp_internal_insert_ledger(v_account,NULL,p_employee_id,NULL,NULL,NULL,'InterestCredit',v_interest,v_balance+v_interest,'Branch','Completed',NULL,v_tx);
   SELECT reference_no INTO v_reference FROM Transactions WHERE transaction_id=v_tx;
   INSERT INTO bank_lab.Experiment_Log(db_name,exp_id,event_type,detail) VALUES(DATABASE(),'INTEREST','MONTHLY_INTEREST_POSTED',JSON_OBJECT('account_id',v_account,'period_start',CAST(v_month AS CHAR),'reference_no',v_reference,'transaction_id',v_tx));
   COMMIT;
   SET p_accounts_credited=p_accounts_credited+1,p_total_interest=p_total_interest+v_interest;
  END;
 END LOOP;
 CLOSE accounts_cursor;
END$$
DELIMITER ;
