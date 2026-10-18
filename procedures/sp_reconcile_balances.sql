DELIMITER $$
CREATE PROCEDURE sp_reconcile_balances(IN p_account_id INT)
READS SQL DATA SQL SECURITY DEFINER
BEGIN
 DECLARE v_checked DATETIME(3);
 IF p_account_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_account_id) THEN
 SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: account does not exist'; END IF;
 SET v_checked=NOW(3);
 WITH
 ledger AS (SELECT account_id,transaction_id,transaction_type,amount,balance_after,
 CASE WHEN transaction_type IN ('Deposit','TransferIn','InterestCredit') THEN amount ELSE -amount END AS signed_amount
 FROM Transactions WHERE status='Completed'),
 totals AS (SELECT account_id,SUM(signed_amount) AS net,MAX(transaction_id) AS last_id FROM ledger GROUP BY account_id),
 chain AS (SELECT *,LAG(balance_after,1,0) OVER(PARTITION BY account_id ORDER BY transaction_id) AS prior_balance FROM ledger),
 wm AS (SELECT COALESCE((SELECT detail FROM bank_lab.Experiment_Log WHERE db_name=DATABASE() AND event_type='AUDIT_TRIGGERS_INSTALLED' ORDER BY log_id DESC LIMIT 1),JSON_OBJECT()) AS j),
 latest_audit AS (SELECT record_pk,new_value,ROW_NUMBER() OVER(PARTITION BY record_pk ORDER BY audit_id DESC) AS rn FROM Audit_Log,wm WHERE table_name='Accounts' AND action_type='UPDATE' AND audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0)),
 problems AS (
 SELECT 'I1' AS invariant,a.account_id,CAST(a.account_id AS CHAR(64)) AS record_pk,'balance differs from completed ledger' AS detail
 FROM Accounts a LEFT JOIN totals t USING(account_id) WHERE (p_account_id IS NULL OR a.account_id=p_account_id) AND a.balance<>COALESCE(t.net,0)
 UNION ALL
 SELECT 'I1',NULL,'TOTAL','aggregate balance differs from completed ledger' FROM Accounts a LEFT JOIN totals t USING(account_id) WHERE p_account_id IS NULL OR a.account_id=p_account_id HAVING COALESCE(SUM(a.balance),0)<>COALESCE(SUM(t.net),0)
 UNION ALL
 SELECT 'I1b',account_id,CAST(transaction_id AS CHAR(64)),'balance_after chain break' FROM chain WHERE (p_account_id IS NULL OR account_id=p_account_id) AND balance_after<>prior_balance+signed_amount
 UNION ALL
 SELECT 'I2',MIN(account_id),transfer_group_id,'invalid paired transfer' FROM Transactions WHERE transfer_group_id IS NOT NULL GROUP BY transfer_group_id
 HAVING NOT (COUNT(*)=2 AND SUM(status='Completed')=2 AND SUM(transaction_type='TransferOut')=1 AND SUM(transaction_type='TransferIn')=1 AND MIN(amount)=MAX(amount)
 AND (MAX(CASE WHEN transaction_type='TransferOut' THEN account_id END) <=> MAX(CASE WHEN transaction_type='TransferIn' THEN related_account_id END))
 AND (MAX(CASE WHEN transaction_type='TransferIn' THEN account_id END) <=> MAX(CASE WHEN transaction_type='TransferOut' THEN related_account_id END)))
 UNION ALL
 SELECT 'I3',a.account_id,CAST(a.account_id AS CHAR(64)),'minimum or nonnegative balance violated' FROM Accounts a JOIN Account_Types t USING(account_type_id) WHERE (p_account_id IS NULL OR a.account_id=p_account_id) AND (a.balance<0 OR (a.status<>'Closed' AND a.balance<t.min_balance))
 UNION ALL
 SELECT 'I5',a.account_id,CAST(a.account_id AS CHAR(64)),'latest completed balance_after differs' FROM Accounts a JOIN totals t USING(account_id) JOIN ledger l ON l.transaction_id=t.last_id WHERE (p_account_id IS NULL OR a.account_id=p_account_id) AND a.balance<>l.balance_after
 UNION ALL
 SELECT 'I4',a.account_id,CAST(a.account_id AS CHAR(64)),'missing Accounts INSERT audit' FROM Accounts a CROSS JOIN wm WHERE a.account_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.accounts_max_id')) AS UNSIGNED),0)
 AND NOT EXISTS(SELECT 1 FROM Audit_Log x WHERE x.table_name='Accounts' AND x.record_pk=CAST(a.account_id AS CHAR) AND x.action_type='INSERT' AND x.audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0))
 UNION ALL
 SELECT 'I4',t.account_id,CAST(t.transaction_id AS CHAR(64)),'missing Transactions INSERT audit' FROM Transactions t CROSS JOIN wm WHERE t.transaction_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.transactions_max_id')) AS UNSIGNED),0)
 AND NOT EXISTS(SELECT 1 FROM Audit_Log x WHERE x.table_name='Transactions' AND x.record_pk=CAST(t.transaction_id AS CHAR) AND x.action_type='INSERT' AND x.audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0))
 UNION ALL
 SELECT 'I4',l.disbursement_account_id,CAST(l.loan_id AS CHAR(64)),'missing Loans INSERT audit' FROM Loans l CROSS JOIN wm WHERE l.loan_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.loans_max_id')) AS UNSIGNED),0)
 AND NOT EXISTS(SELECT 1 FROM Audit_Log x WHERE x.table_name='Loans' AND x.record_pk=CAST(l.loan_id AS CHAR) AND x.action_type='INSERT' AND x.audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0))
 UNION ALL
 SELECT 'I4',a.account_id,CAST(a.account_id AS CHAR(64)),'newest UPDATE audit balance differs' FROM Accounts a JOIN latest_audit x ON x.record_pk=CAST(a.account_id AS CHAR) AND x.rn=1 WHERE NOT (CAST(JSON_UNQUOTE(JSON_EXTRACT(x.new_value,'$.balance')) AS DECIMAL(14,2)) <=> a.balance)
),
 ids AS (SELECT 'I1' AS invariant UNION ALL SELECT 'I1b' UNION ALL SELECT 'I2' UNION ALL SELECT 'I3' UNION ALL SELECT 'I4' UNION ALL SELECT 'I5'),
 counts AS (SELECT ids.invariant,COUNT(p.invariant) AS violations FROM ids LEFT JOIN problems p USING(invariant) GROUP BY ids.invariant)
 SELECT JSON_ARRAYAGG(JSON_OBJECT('invariant',invariant,'violations',violations,'status',IF(violations=0,'PASS','FAIL'))) INTO @reconcile_results FROM counts;
 SELECT invariant,violations,status,v_checked AS checked_at FROM JSON_TABLE(@reconcile_results,'$[*]' COLUMNS(invariant VARCHAR(4) PATH '$.invariant',violations BIGINT PATH '$.violations',status VARCHAR(4) PATH '$.status')) j ORDER BY invariant;
 WITH
 ledger AS (SELECT account_id,transaction_id,transaction_type,amount,balance_after,
 CASE WHEN transaction_type IN ('Deposit','TransferIn','InterestCredit') THEN amount ELSE -amount END AS signed_amount
 FROM Transactions WHERE status='Completed'),
 totals AS (SELECT account_id,SUM(signed_amount) AS net,MAX(transaction_id) AS last_id FROM ledger GROUP BY account_id),
 chain AS (SELECT *,LAG(balance_after,1,0) OVER(PARTITION BY account_id ORDER BY transaction_id) AS prior_balance FROM ledger),
 wm AS (SELECT COALESCE((SELECT detail FROM bank_lab.Experiment_Log WHERE db_name=DATABASE() AND event_type='AUDIT_TRIGGERS_INSTALLED' ORDER BY log_id DESC LIMIT 1),JSON_OBJECT()) AS j),
 latest_audit AS (SELECT record_pk,new_value,ROW_NUMBER() OVER(PARTITION BY record_pk ORDER BY audit_id DESC) AS rn FROM Audit_Log,wm WHERE table_name='Accounts' AND action_type='UPDATE' AND audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0)),
 problems AS (
 SELECT 'I1' AS invariant,a.account_id,CAST(a.account_id AS CHAR(64)) AS record_pk,'balance differs from completed ledger' AS detail
 FROM Accounts a LEFT JOIN totals t USING(account_id) WHERE (p_account_id IS NULL OR a.account_id=p_account_id) AND a.balance<>COALESCE(t.net,0)
 UNION ALL
 SELECT 'I1',NULL,'TOTAL','aggregate balance differs from completed ledger' FROM Accounts a LEFT JOIN totals t USING(account_id) WHERE p_account_id IS NULL OR a.account_id=p_account_id HAVING COALESCE(SUM(a.balance),0)<>COALESCE(SUM(t.net),0)
 UNION ALL
 SELECT 'I1b',account_id,CAST(transaction_id AS CHAR(64)),'balance_after chain break' FROM chain WHERE (p_account_id IS NULL OR account_id=p_account_id) AND balance_after<>prior_balance+signed_amount
 UNION ALL
 SELECT 'I2',MIN(account_id),transfer_group_id,'invalid paired transfer' FROM Transactions WHERE transfer_group_id IS NOT NULL GROUP BY transfer_group_id
 HAVING NOT (COUNT(*)=2 AND SUM(status='Completed')=2 AND SUM(transaction_type='TransferOut')=1 AND SUM(transaction_type='TransferIn')=1 AND MIN(amount)=MAX(amount)
 AND (MAX(CASE WHEN transaction_type='TransferOut' THEN account_id END) <=> MAX(CASE WHEN transaction_type='TransferIn' THEN related_account_id END))
 AND (MAX(CASE WHEN transaction_type='TransferIn' THEN account_id END) <=> MAX(CASE WHEN transaction_type='TransferOut' THEN related_account_id END)))
 UNION ALL
 SELECT 'I3',a.account_id,CAST(a.account_id AS CHAR(64)),'minimum or nonnegative balance violated' FROM Accounts a JOIN Account_Types t USING(account_type_id) WHERE (p_account_id IS NULL OR a.account_id=p_account_id) AND (a.balance<0 OR (a.status<>'Closed' AND a.balance<t.min_balance))
 UNION ALL
 SELECT 'I5',a.account_id,CAST(a.account_id AS CHAR(64)),'latest completed balance_after differs' FROM Accounts a JOIN totals t USING(account_id) JOIN ledger l ON l.transaction_id=t.last_id WHERE (p_account_id IS NULL OR a.account_id=p_account_id) AND a.balance<>l.balance_after
 UNION ALL
 SELECT 'I4',a.account_id,CAST(a.account_id AS CHAR(64)),'missing Accounts INSERT audit' FROM Accounts a CROSS JOIN wm WHERE a.account_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.accounts_max_id')) AS UNSIGNED),0)
 AND NOT EXISTS(SELECT 1 FROM Audit_Log x WHERE x.table_name='Accounts' AND x.record_pk=CAST(a.account_id AS CHAR) AND x.action_type='INSERT' AND x.audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0))
 UNION ALL
 SELECT 'I4',t.account_id,CAST(t.transaction_id AS CHAR(64)),'missing Transactions INSERT audit' FROM Transactions t CROSS JOIN wm WHERE t.transaction_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.transactions_max_id')) AS UNSIGNED),0)
 AND NOT EXISTS(SELECT 1 FROM Audit_Log x WHERE x.table_name='Transactions' AND x.record_pk=CAST(t.transaction_id AS CHAR) AND x.action_type='INSERT' AND x.audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0))
 UNION ALL
 SELECT 'I4',l.disbursement_account_id,CAST(l.loan_id AS CHAR(64)),'missing Loans INSERT audit' FROM Loans l CROSS JOIN wm WHERE l.loan_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.loans_max_id')) AS UNSIGNED),0)
 AND NOT EXISTS(SELECT 1 FROM Audit_Log x WHERE x.table_name='Loans' AND x.record_pk=CAST(l.loan_id AS CHAR) AND x.action_type='INSERT' AND x.audit_id>COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(j,'$.audit_max_id')) AS UNSIGNED),0))
 UNION ALL
 SELECT 'I4',a.account_id,CAST(a.account_id AS CHAR(64)),'newest UPDATE audit balance differs' FROM Accounts a JOIN latest_audit x ON x.record_pk=CAST(a.account_id AS CHAR) AND x.rn=1 WHERE NOT (CAST(JSON_UNQUOTE(JSON_EXTRACT(x.new_value,'$.balance')) AS DECIMAL(14,2)) <=> a.balance)
)
 SELECT invariant,account_id,record_pk,detail FROM problems ORDER BY invariant,account_id,record_pk LIMIT 100;
END$$
DELIMITER ;
