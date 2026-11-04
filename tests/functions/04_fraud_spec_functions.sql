-- No unconditional PASS rows: helpers persist and emit runner-compatible outcomes.
CALL bank_lab.sp_assert_true(DATABASE(),'distance normal',fn_distance_km(0,0,0,1) BETWEEN 111 AND 112,'equatorial degree');
CALL bank_lab.sp_assert_equal(DATABASE(),'distance same point','0.000',fn_distance_km(0,0,0,0));
CALL bank_lab.sp_assert_true(DATABASE(),'distance NULL',fn_distance_km(NULL,0,0,1) IS NULL,'missing coordinate');
CALL bank_lab.sp_assert_true(DATABASE(),'distance antipodal',fn_distance_km(0,0,0,180) BETWEEN 20015 AND 20016,'finite boundary');
CALL bank_lab.sp_assert_equal(DATABASE(),'zscore normal','2.0000',fn_amount_zscore(150,100,25));
CALL bank_lab.sp_assert_equal(DATABASE(),'zscore negative','-2.0000',fn_amount_zscore(50,100,25));
CALL bank_lab.sp_assert_equal(DATABASE(),'zscore zero deviation','0.0000',fn_amount_zscore(150,100,0));
CALL bank_lab.sp_assert_equal(DATABASE(),'zscore negative deviation','0.0000',fn_amount_zscore(150,100,-1));
CALL bank_lab.sp_assert_equal(DATABASE(),'zscore NULL','0.0000',fn_amount_zscore(NULL,100,25));
CALL bank_lab.sp_assert_equal(DATABASE(),'odd hour 0559','1',fn_is_odd_hour('2026-01-01 05:59:59'));
CALL bank_lab.sp_assert_equal(DATABASE(),'odd hour 0600','0',fn_is_odd_hour('2026-01-01 06:00:00'));
CALL bank_lab.sp_assert_equal(DATABASE(),'odd hour 2159','0',fn_is_odd_hour('2026-01-01 21:59:59'));
CALL bank_lab.sp_assert_equal(DATABASE(),'odd hour 2200','1',fn_is_odd_hour('2026-01-01 22:00:00'));
CALL bank_lab.sp_assert_equal(DATABASE(),'odd hour NULL','0',fn_is_odd_hour(NULL));
CALL bank_lab.sp_assert_equal(DATABASE(),'risk Low boundary','Low',fn_risk_level(29.99));
CALL bank_lab.sp_assert_equal(DATABASE(),'risk Medium boundary','Medium',fn_risk_level(30));
CALL bank_lab.sp_assert_equal(DATABASE(),'risk High boundary','High',fn_risk_level(60));
CALL bank_lab.sp_assert_equal(DATABASE(),'risk Critical boundary','Critical',fn_risk_level(85));
CALL bank_lab.sp_assert_equal(DATABASE(),'risk NULL','Low',fn_risk_level(NULL));
CALL bank_lab.sp_assert_equal(DATABASE(),'txn risk below 5000','0.00',fn_txn_risk_score(4999.99,'Branch',TRUE,0));
CALL bank_lab.sp_assert_equal(DATABASE(),'txn risk at 5000','20.00',fn_txn_risk_score(5000,'Branch',TRUE,0));
CALL bank_lab.sp_assert_equal(DATABASE(),'txn risk below 10000','20.00',fn_txn_risk_score(9999.99,'Branch',TRUE,0));
CALL bank_lab.sp_assert_equal(DATABASE(),'txn risk at 10000','35.00',fn_txn_risk_score(10000,'Branch',TRUE,0));
CALL bank_lab.sp_assert_equal(DATABASE(),'txn risk approved untrusted digital','30.00',fn_txn_risk_score(100,'Online',FALSE,0));
CALL bank_lab.sp_assert_equal(DATABASE(),'txn risk NULL inputs','20.00',fn_txn_risk_score(NULL,NULL,NULL,NULL));
CALL bank_lab.sp_assert_equal(DATABASE(),'txn risk cap','100.00',fn_txn_risk_score(10000,'Mobile',FALSE,100));
CALL bank_lab.sp_assert_equal(DATABASE(),'txn risk negative profile','0.00',fn_txn_risk_score(100,'Branch',TRUE,-1));
CALL bank_lab.sp_assert_equal(DATABASE(),'window NULL account','0',fn_txn_count_window(NULL,NOW(),10));
CALL bank_lab.sp_assert_equal(DATABASE(),'window missing account','0',fn_txn_count_window(-1,NOW(),10));
CALL bank_lab.sp_assert_equal(DATABASE(),'window NULL time','0',fn_txn_count_window(-1,NULL,10));
CALL bank_lab.sp_assert_equal(DATABASE(),'window zero minutes','0',fn_txn_count_window(-1,NOW(),0));
CALL bank_lab.sp_assert_equal(DATABASE(),'window NULL minutes','0',fn_txn_count_window(-1,NOW(),NULL));
CALL bank_lab.sp_assert_true(DATABASE(),'age missing account',fn_account_age_days(-1,NOW()) IS NULL,'missing account');
CALL bank_lab.sp_assert_true(DATABASE(),'age NULL account',fn_account_age_days(NULL,NOW()) IS NULL,'NULL account');
CALL bank_lab.sp_assert_true(DATABASE(),'age NULL time',fn_account_age_days(-1,NULL) IS NULL,'NULL timestamp');
START TRANSACTION;
INSERT INTO Accounts(customer_id,branch_id,account_type_id,account_number,balance,status,opened_date)
SELECT MIN(customer_id),(SELECT MIN(branch_id) FROM Branches),(SELECT account_type_id FROM Account_Types WHERE type_name='Savings'),
 CONCAT('FS-',LEFT(REPLACE(UUID(),'-',''),16)),3000,'Active','2026-01-01' FROM Customers;
SET @fs_account=LAST_INSERT_ID();
INSERT INTO Transactions(account_id,transaction_type,amount,balance_after,channel,status,transaction_timestamp,reference_no)
VALUES(@fs_account,'Deposit',1000,1000,'Online','Completed','2026-01-02 11:50:00',fn_generate_reference()),
      (@fs_account,'Deposit',1000,2000,'Online','Completed','2026-01-02 11:59:59',fn_generate_reference()),
      (@fs_account,'Deposit',1000,3000,'Online','Completed','2026-01-02 12:00:00',fn_generate_reference()),
      (@fs_account,'Deposit',100,3000,'Online','Pending','2026-01-02 12:00:00',fn_generate_reference());
CALL bank_lab.sp_assert_equal(DATABASE(),'window exclusive start inclusive end','2',fn_txn_count_window(@fs_account,'2026-01-02 12:00:00',10));
CALL bank_lab.sp_assert_equal(DATABASE(),'window excludes future','1',fn_txn_count_window(@fs_account,'2026-01-02 11:59:59',1));
CALL bank_lab.sp_assert_equal(DATABASE(),'age same day','0',fn_account_age_days(@fs_account,'2026-01-01 23:59:59'));
CALL bank_lab.sp_assert_equal(DATABASE(),'age next day','1',fn_account_age_days(@fs_account,'2026-01-02'));
CALL bank_lab.sp_assert_equal(DATABASE(),'age before opening','0',fn_account_age_days(@fs_account,'2025-12-31'));
ROLLBACK;
-- Expected return followed by IN parameter types, in ordinal order.
WITH expected AS (
 SELECT 'fn_distance_km' AS fn,'decimal(10,3),decimal(9,6),decimal(9,6),decimal(9,6),decimal(9,6)' AS signature
 UNION ALL SELECT 'fn_amount_zscore','decimal(10,4),decimal(14,2),decimal(14,4),decimal(14,4)'
 UNION ALL SELECT 'fn_txn_count_window','int,int,datetime,int'
 UNION ALL SELECT 'fn_is_odd_hour','tinyint,datetime'
 UNION ALL SELECT 'fn_account_age_days','int,int,datetime'
 UNION ALL SELECT 'fn_txn_risk_score','decimal(5,2),decimal(14,2),varchar(10),tinyint(1),decimal(5,2)'
 UNION ALL SELECT 'fn_risk_level','varchar(10),decimal(5,2)'
), actual AS (
 SELECT specific_name,GROUP_CONCAT(LOWER(dtd_identifier) ORDER BY ordinal_position SEPARATOR ',') AS signature
 FROM information_schema.parameters WHERE specific_schema=DATABASE() GROUP BY specific_name
)
SELECT CONCAT('TEST|',IF(e.signature=a.signature,'PASS','FAIL'),'|fraud signature ',e.fn,
 '|expected=',e.signature,'; actual=',COALESCE(a.signature,'MISSING'))
FROM expected e LEFT JOIN actual a ON a.specific_name=e.fn ORDER BY e.fn;
