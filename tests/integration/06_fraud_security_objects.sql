-- Smoke tests for the fraud trigger and security/reporting views.
CALL bank_lab.sp_assert_equal(DATABASE(),'fraud trigger installed','1',
 (SELECT COUNT(*) FROM information_schema.triggers
   WHERE trigger_schema=DATABASE() AND trigger_name='trg_transactions_ai_fraud_evaluate'));
CALL bank_lab.sp_assert_equal(DATABASE(),'fraud evaluator installed','1',
 (SELECT COUNT(*) FROM information_schema.routines
   WHERE routine_schema=DATABASE() AND routine_name='sp_evaluate_fraud' AND routine_type='PROCEDURE'));
CALL bank_lab.sp_assert_equal(DATABASE(),'fraud queue view installed','1',
 (SELECT COUNT(*) FROM information_schema.views
   WHERE table_schema=DATABASE() AND table_name='v_fraud_case_queue'));
CALL bank_lab.sp_assert_equal(DATABASE(),'customer summary view installed','1',
 (SELECT COUNT(*) FROM information_schema.views
   WHERE table_schema=DATABASE() AND table_name='v_customer_account_summary'));
SELECT 'TEST|PASS|fraud_security_objects|required objects installed' AS test_result;
