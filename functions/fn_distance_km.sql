DELIMITER $$
CREATE FUNCTION fn_distance_km(p_lat1 DECIMAL(9,6), p_lon1 DECIMAL(9,6),
                               p_lat2 DECIMAL(9,6), p_lon2 DECIMAL(9,6))
RETURNS DECIMAL(10,3)
DETERMINISTIC NO SQL
BEGIN
  IF p_lat1 IS NULL OR p_lon1 IS NULL OR p_lat2 IS NULL OR p_lon2 IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN ROUND(6371 * 2 * ASIN(SQRT(
    LEAST(1, GREATEST(0,
      POWER(SIN(RADIANS(p_lat2-p_lat1)/2),2) +
      COS(RADIANS(p_lat1))*COS(RADIANS(p_lat2))*
      POWER(SIN(RADIANS(p_lon2-p_lon1)/2),2)
    ))
  )),3);
END$$
DELIMITER ;
