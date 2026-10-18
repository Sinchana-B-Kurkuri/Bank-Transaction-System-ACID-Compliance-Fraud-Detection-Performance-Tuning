CREATE DATABASE IF NOT EXISTS bank_lab CHARACTER SET utf8mb4;
CREATE TABLE IF NOT EXISTS bank_lab.Experiment_Log (
 log_id BIGINT AUTO_INCREMENT PRIMARY KEY, db_name VARCHAR(64), exp_id VARCHAR(16), event_type VARCHAR(40),
 detail JSON NULL, created_at DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS bank_lab.Test_Results (
 result_id BIGINT AUTO_INCREMENT PRIMARY KEY, run_id VARCHAR(40), db_name VARCHAR(64), test_name VARCHAR(200),
 status ENUM('PASS','FAIL'), detail VARCHAR(500), created_at DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB;
DELIMITER $$
DROP PROCEDURE IF EXISTS bank_lab.sp_expect_error$$
CREATE PROCEDURE bank_lab.sp_expect_error(IN p_db VARCHAR(64), IN p_test VARCHAR(200), IN p_sql TEXT, IN p_expected_errno INT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_errno INT DEFAULT 0;
 DECLARE v_prepared BOOLEAN DEFAULT FALSE;
 DECLARE v_status VARCHAR(4);
 DECLARE v_detail VARCHAR(500);
 BEGIN
  -- Strict enum conversion can report errno 1265 with SQLSTATE class 01.
  DECLARE EXIT HANDLER FOR SQLEXCEPTION, SQLWARNING
  BEGIN
   GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
  END;
  SET @lab_sql = REPLACE(p_sql,'{db}',REPLACE(p_db,'`','``'));
  PREPARE lab_stmt FROM @lab_sql;
  SET v_prepared=TRUE;
  EXECUTE lab_stmt;
 END;
 IF v_prepared THEN DEALLOCATE PREPARE lab_stmt; END IF;
 SET v_status=IF(v_errno<>0 AND (p_expected_errno IS NULL OR p_expected_errno=v_errno),'PASS','FAIL');
 SET v_detail=CONCAT('expected errno=',COALESCE(p_expected_errno,'any'),'; actual errno=',v_errno);
 INSERT INTO bank_lab.Test_Results(run_id,db_name,test_name,status,detail) VALUES(COALESCE(@test_run_id,'adhoc'),p_db,p_test,v_status,v_detail);
 SELECT CONCAT('TEST|',v_status,'|',p_test,'|',v_detail) AS result;
END$$
DROP PROCEDURE IF EXISTS bank_lab.sp_expect_ok$$
CREATE PROCEDURE bank_lab.sp_expect_ok(IN p_db VARCHAR(64), IN p_test VARCHAR(200), IN p_sql TEXT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_errno INT DEFAULT 0;
 DECLARE v_prepared BOOLEAN DEFAULT FALSE;
 DECLARE v_status VARCHAR(4);
 DECLARE v_detail VARCHAR(500);
 BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION, SQLWARNING BEGIN GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO; END;
  SET @lab_sql=REPLACE(p_sql,'{db}',REPLACE(p_db,'`','``'));
  PREPARE lab_stmt FROM @lab_sql;
  SET v_prepared=TRUE;
  EXECUTE lab_stmt;
 END;
 IF v_prepared THEN DEALLOCATE PREPARE lab_stmt; END IF;
 SET v_status=IF(v_errno=0,'PASS','FAIL');
 SET v_detail=CONCAT('actual errno=',v_errno);
 INSERT INTO bank_lab.Test_Results(run_id,db_name,test_name,status,detail) VALUES(COALESCE(@test_run_id,'adhoc'),p_db,p_test,v_status,v_detail);
 SELECT CONCAT('TEST|',v_status,'|',p_test,'|',v_detail) AS result;
END$$
DROP PROCEDURE IF EXISTS bank_lab.sp_assert_equal$$
CREATE PROCEDURE bank_lab.sp_assert_equal(IN p_db VARCHAR(64), IN p_test VARCHAR(200), IN p_expected TEXT, IN p_actual TEXT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_status VARCHAR(4);
 DECLARE v_detail VARCHAR(500);
 SET v_status=IF(BINARY p_expected <=> BINARY p_actual,'PASS','FAIL');
 SET v_detail=LEFT(CONCAT('expected=',COALESCE(p_expected,'NULL'),'; actual=',COALESCE(p_actual,'NULL')),500);
 INSERT INTO bank_lab.Test_Results(run_id,db_name,test_name,status,detail) VALUES(COALESCE(@test_run_id,'adhoc'),p_db,p_test,v_status,v_detail);
 SELECT CONCAT('TEST|',v_status,'|',p_test,'|',v_detail) AS result;
END$$
DROP PROCEDURE IF EXISTS bank_lab.sp_assert_true$$
CREATE PROCEDURE bank_lab.sp_assert_true(IN p_db VARCHAR(64), IN p_test VARCHAR(200), IN p_condition TINYINT, IN p_detail VARCHAR(500))
SQL SECURITY DEFINER
BEGIN
 DECLARE v_status VARCHAR(4);
 SET v_status=IF(COALESCE(p_condition,0)<>0,'PASS','FAIL');
 INSERT INTO bank_lab.Test_Results(run_id,db_name,test_name,status,detail) VALUES(COALESCE(@test_run_id,'adhoc'),p_db,p_test,v_status,p_detail);
 SELECT CONCAT('TEST|',v_status,'|',p_test,'|',COALESCE(p_detail,'')) AS result;
END$$
DELIMITER ;
