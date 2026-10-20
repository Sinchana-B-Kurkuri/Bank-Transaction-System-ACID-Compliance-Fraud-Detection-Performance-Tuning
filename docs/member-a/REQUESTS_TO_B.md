# Requests to Member B

## 2026-10-19 — P6-01: runtime fraud integration BLOCKED

Current develop/HEAD 7c50b73 supplies seven B tables only. Please supply the completed source files for fn_distance_km, fn_amount_zscore, fn_txn_count_window, fn_is_odd_hour, fn_account_age_days, fn_txn_risk_score, fn_risk_level, sp_evaluate_fraud and the Transactions AFTER INSERT fraud trigger, plus your tests. The trigger must use FOLLOWS trg_transactions_ai_audit, remain detective, tolerate A5 NULL credit/Failed context, and roll its flags back with failed transfers. No B object was edited or recreated by A; real-schema regression is not a fraud-runtime pass.

## 2026-10-19 — P6-02: RBAC/views integration BLOCKED

security/ and views/ contain only .gitkeep. Please provide actual roles/grants/masked views and B acceptance tests. Use the final public-procedure allowlist in interfaces.md; never grant sp_internal_*. Demonstrate role-specific EXECUTE and forbidden base-table/private-procedure access with expected native privilege errors. Existing A restricted-login tests validate A's DEFINER/USER() authorization, not your absent RBAC deployment.

## 2026-10-19 — P6-03: completed B deliverables unavailable

Please supply the claimed implementations/tests for indexes, benchmarks/Benchmark_Results, data generators and EXP-11..15, or confirm their delivery status. Preserve B0 as a selectable PK/UNIQUE/FK-only baseline. A found no schema column mismatch requiring changes to your seven table files; the real additional CHECK/FK constraints are tested separately from stubs. Please confirm Transaction_Approvals is the final approved contract (the frozen SPEC still labels its outline as assumed).

The missing -Quick parameter is an A experiment-orchestrator scope gap, not a request for B to change A's files.

