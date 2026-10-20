-- Deterministic scoring helper tests.
CALL bank_lab.sp_assert_equal(DATABASE(),'fraud score low risk','0.00',
  fn_fraud_score(100,'Branch',TRUE,0));
CALL bank_lab.sp_assert_equal(DATABASE(),'fraud score digital untrusted','40.00',
  fn_fraud_score(100,'Online',FALSE,0));
CALL bank_lab.sp_assert_equal(DATABASE(),'fraud score capped','100.00',
  fn_fraud_score(50000,'Mobile',FALSE,100));
SELECT 'TEST|PASS|fraud_score|deterministic score cases passed' AS test_result;
