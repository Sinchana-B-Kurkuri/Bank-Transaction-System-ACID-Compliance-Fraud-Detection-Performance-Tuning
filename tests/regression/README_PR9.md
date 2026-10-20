# Safe Windows PR9 acceptance

Run from the repository root using Windows PowerShell5.1, native MySQL8.4.11, BANK_MYSQL_CNF pointing to an external option file and optional BANK_MYSQL_BIN executable path.

```powershell
powershell -NoProfile -File tests/regression/pr9_acceptance.ps1
```

This runner accepts **no database argument**. It generates a fresh GUID-qualified database, verifies nonexistence, writes a random ownership marker and requires that marker for cleanup. It reuses only AST-extracted function definitions from error1222_seed.ps1 (not that script's execution body) and quoting/SOURCE helpers from mysql_common.ps1. It never overrides or bypasses Assert-BankDatabase, never calls protected rebuild wrappers, and relocates bank_lab qualification only in SQL executed inside its own schema. Actual integrated sources, not B stubs, are tested. By default global operations are forbidden and RBAC is preview/prepare-only. After explicit approval, -WithRestrictedRoles invokes support/pr9_rbac.ps1: global account/grant batches must exactly match its in-memory allowlist, names must be fresh, and cleanup is limited to successfully created users/roles. Password-bearing SQL is never recorded; restricted MYSQL_PWD is child-process-only.

Every numbered SQL test in schema/functions/triggers/procedures/invariants/integration runs. As in the existing runner, only the ledger UPDATE guard is temporarily suspended for native constraint tests and restored in finally. Results include separate per-file and targeted assertion counts; do not add overlapping populations into a unique-test total. FAILED assertion, native SQL error or no TEST output makes the process fail. SQL/stdout/stderr, file-level counts and summary are retained under a unique evidence/reviews/PR9-final-fixes run folder, including failed runs.

It additionally checks seven exact function signatures, identity views, same/foreign/inactive statement actors, repeatable/configured fraud evaluation, the complete RBAC preview and public-only grant inventory, baseline-only default, explicit optimized indexes and six final invariants. Actor-map tests use the privileged native connection, **not** actual restricted authentication. The optional -WithRestrictedRoles path separately proves native restricted authentication/authorization; it requires explicit approval of security/README.md before use. The original nested PowerShell tests that create users or target fixed scratch/release schemas are not called. No concurrent/performance/crash/PITR experiment is run.

Also run the independent real seed/1222 regression and pure SOURCE-order/mysql-wrapper tests. See the delivery report for actual counts; written tests alone are not evidence of execution.
