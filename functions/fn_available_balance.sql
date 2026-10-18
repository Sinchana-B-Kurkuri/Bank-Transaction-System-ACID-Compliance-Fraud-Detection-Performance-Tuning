DELIMITER $$
CREATE FUNCTION fn_available_balance(p_account_id INT) RETURNS DECIMAL(14,2)
NOT DETERMINISTIC READS SQL DATA SQL SECURITY DEFINER
BEGIN
 RETURN COALESCE((SELECT GREATEST(a.balance-t.min_balance,0) FROM Accounts a
 JOIN Account_Types t USING(account_type_id) WHERE a.account_id=p_account_id AND a.status='Active'),0.00);
END$$
DELIMITER ;
