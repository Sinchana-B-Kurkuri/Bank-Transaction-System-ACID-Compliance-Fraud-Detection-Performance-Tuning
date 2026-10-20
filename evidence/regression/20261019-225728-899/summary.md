# Prompt 6 regression â€” measured results

Run: 20261019-225728-899; branch: feature/A-integration-docs. Native Windows PowerShell/MySQL; no simulated concurrency proof.

| Check | Status | Actual result | Evidence |
|---|---|---|---|
| Standalone rebuild | PASS | PASS=0; FAIL=0 | evidence/regression/20261019-225728-899/Standalone-build.txt |
| Standalone full suite | PASS | TOTAL/PASS=788/FAIL=0 | evidence/regression/20261019-225728-899/Standalone-suite.txt |
| Standalone invariants | PASS | Six summaries (I1,I1b,I2,I3,I4,I5) | evidence/regression/20261019-225728-899/Standalone-invariants.txt |
| Standalone static and B0 | PASS | PASS=10; FAIL=0 | evidence/regression/20261019-225728-899/Standalone-static.txt |
| Integrated rebuild | PASS | PASS=0; FAIL=0 | evidence/regression/20261019-225728-899/Integrated-build.txt |
| Integrated full suite | PASS | TOTAL/PASS=797/FAIL=0 | evidence/regression/20261019-225728-899/Integrated-suite.txt |
| Integrated invariants | PASS | Six summaries (I1,I1b,I2,I3,I4,I5) | evidence/regression/20261019-225728-899/Integrated-invariants.txt |
| Integrated static and B0 | PASS | PASS=10; FAIL=0 | evidence/regression/20261019-225728-899/Integrated-static.txt |
| Release procedure suite | PASS | TOTAL/RELEASE_PASS=311/FAIL=0 | evidence/regression/20261019-225728-899/release-suite.txt |
| B fraud runtime | BLOCKED | Missing: fn_distance_km, fn_amount_zscore, fn_txn_count_window, fn_is_odd_hour, fn_account_age_days, fn_txn_risk_score, fn_risk_level, sp_evaluate_fraud |  |
| Fraud trigger ordering/rollback integration | BLOCKED | No B fraud trigger exists; absence is not an ordering pass |  |
| B RBAC integration | BLOCKED | No executable B RBAC acceptance suite available; A restricted-login tests do not certify B roles |  |
| Quick experiments | BLOCKED | Aggregate does not implement -Quick; not invoking an argument it would silently ignore. Existing drivers rebuild Standalone; out of Prompt 6 edit scope. |  |
| Final bank_txn invariants | PASS | Six actual summaries; Quick not executed unless separately reported PASS | evidence/regression/20261019-225728-899/final-bank_txn.txt |
| Final bank_txn_scratch invariants | PASS | Six actual summaries; Quick not executed unless separately reported PASS | evidence/regression/20261019-225728-899/final-bank_txn_scratch.txt |

FAIL=0; BLOCKED=4. Missing modules and unsupported Quick are never labeled passed.