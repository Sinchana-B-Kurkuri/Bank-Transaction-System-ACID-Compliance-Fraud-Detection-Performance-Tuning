-- Deterministic scoring helper tests.
CALL bank_lab.sp_assert_equal(DATABASE(),'fraud score low risk','0.00',
  fn_fraud_score(100,'Branch',TRUE,0));
CALL bank_lab.sp_assert_equal(DATABASE(),'fraud score digital untrusted','30.00',
  fn_fraud_score(100,'Online',FALSE,0));
CALL bank_lab.sp_assert_equal(DATABASE(),'fraud score capped','100.00',
  fn_fraud_score(50000,'Mobile',FALSE,100));
CALL bank_lab.sp_assert_equal(DATABASE(),'fraud helper matches evaluator base',
  fn_txn_risk_score(100,'Online',FALSE,0),fn_fraud_score(100,'Online',FALSE,0));
