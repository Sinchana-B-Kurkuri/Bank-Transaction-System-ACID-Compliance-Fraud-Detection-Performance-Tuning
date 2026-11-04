DELIMITER $$
CREATE FUNCTION fn_generate_reference() RETURNS VARCHAR(30)
NOT DETERMINISTIC READS SQL DATA SQL SECURITY DEFINER
BEGIN
 -- 28 characters. UUID_SHORT supplies a server-wide advancing suffix; no table writes.
 RETURN CONCAT('T',DATE_FORMAT(NOW(6),'%Y%m%d%H%i%s%f'),'-',
 LPAD(CONV(MOD(UUID_SHORT(),2176782336),10,36),6,'0'));
END$$
DELIMITER ;
