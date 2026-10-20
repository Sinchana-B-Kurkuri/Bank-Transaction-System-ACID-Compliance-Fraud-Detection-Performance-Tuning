DELIMITER $$
CREATE FUNCTION fn_amount_zscore(p_amount DECIMAL(14,2), p_mean DECIMAL(14,4),
                                 p_stddev DECIMAL(14,4))
RETURNS DECIMAL(10,4)
DETERMINISTIC NO SQL
BEGIN
  IF p_amount IS NULL OR p_mean IS NULL OR p_stddev IS NULL OR p_stddev <= 0 THEN
    RETURN 0.0000;
  END IF;
  RETURN ROUND((p_amount-p_mean)/p_stddev,4);
END$$
DELIMITER ;
