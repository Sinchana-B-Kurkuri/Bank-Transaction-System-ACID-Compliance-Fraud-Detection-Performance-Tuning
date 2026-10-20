DELIMITER $$
CREATE FUNCTION fn_account_age_days(p_account_id INT, p_as_of DATETIME)
RETURNS INT
READS SQL DATA SQL SECURITY DEFINER
BEGIN
  DECLARE v_opened DATE DEFAULT NULL;
  IF p_account_id IS NULL OR p_as_of IS NULL THEN RETURN NULL; END IF;
  SELECT opened_date INTO v_opened FROM Accounts WHERE account_id=p_account_id;
  IF v_opened IS NULL THEN RETURN NULL; END IF;
  RETURN GREATEST(0,DATEDIFF(DATE(p_as_of),v_opened));
END$$
DELIMITER ;
