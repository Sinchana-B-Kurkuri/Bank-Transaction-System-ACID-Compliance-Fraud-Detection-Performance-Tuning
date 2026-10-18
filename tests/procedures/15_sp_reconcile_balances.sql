SOURCE tests/procedures/support/fixture.sql;
CALL bank_lab.sp_expect_ok(DATABASE(),'reconcile one account','CALL {db}.sp_reconcile_balances(@p3_a)');
SET @p3_ok=(SELECT COUNT(*)=6 AND SUM(status='FAIL')=0 FROM JSON_TABLE(@reconcile_results,'$[*]' COLUMNS(status VARCHAR(4) PATH '$.status')) j);
CALL bank_lab.sp_assert_true(DATABASE(),'reconcile six summaries',@p3_ok,'Expected procedure contract');
CALL bank_lab.sp_expect_error(DATABASE(),'reconcile missing account','CALL {db}.sp_reconcile_balances(-1)',5002);
