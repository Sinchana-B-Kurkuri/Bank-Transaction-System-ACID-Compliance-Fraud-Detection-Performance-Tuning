DELIMITER $$
CREATE PROCEDURE sp_generate_statement(IN p_account_id INT, IN p_from DATE, IN p_to DATE)
READS SQL DATA SQL SECURITY DEFINER
BEGIN
 DECLARE v_open DECIMAL(14,2) DEFAULT 0;
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR DATEDIFF(p_to,p_from)+1>366 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid statement date range'; END IF;
 IF p_account_id IS NULL OR NOT EXISTS(SELECT 1 FROM Accounts WHERE account_id=p_account_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5002,MESSAGE_TEXT='E_ACCOUNT_NOT_FOUND: account does not exist'; END IF;
 SET v_open=COALESCE((SELECT balance_after FROM Transactions WHERE account_id=p_account_id AND status='Completed' AND transaction_timestamp<p_from ORDER BY transaction_id DESC LIMIT 1),0);
 SELECT p_account_id AS account_id,p_from AS period_start,v_open AS opening_balance;
 SELECT transaction_id,transaction_timestamp AS timestamp,transaction_type AS type,amount,balance_after,related_account_id,reference_no,
 v_open+SUM(CASE WHEN transaction_type IN ('Deposit','TransferIn','InterestCredit') THEN amount ELSE -amount END) OVER(ORDER BY transaction_id ROWS UNBOUNDED PRECEDING) AS running_balance
 FROM Transactions WHERE account_id=p_account_id AND status='Completed' AND transaction_timestamp>=p_from AND transaction_timestamp<DATE_ADD(p_to,INTERVAL 1 DAY) ORDER BY transaction_id;
END$$
DELIMITER ;
