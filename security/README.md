# RBAC installation and approval boundary

`01_roles_and_grants.sql` is a separate, native MySQL 8.4 CLI deployment step, after the real integrated routines and views. It uses `DATABASE()`, never a hard-coded application database. It is deliberately absent from automatic rebuild. **Default is preview only**: no global roles, users or grants are changed. Roles are server-wide accounts holding object-scoped privileges, not database-local objects.

From the repository root, open the native client with your external option file and the intended schema:

```powershell
& $env:BANK_MYSQL_BIN "--defaults-extra-file=$env:BANK_MYSQL_CNF" "--database=$db" --default-character-set=utf8mb4
```

Then, in that same mysql session:

```sql
SET @rbac_apply=0, @rbac_role_suffix='';
SOURCE security/01_roles_and_grants.sql;
```

Review the **45** `RBAC|PLAN|` statements: four CREATE ROLE, nine SELECT grants, 32 public-procedure EXECUTE grants. Nothing is applied. The transient INVOKER installer is removed after successful preview/application. SQL SECURITY DEFINER views and public routines encapsulate underlying operations; callers receive no broad database/base-table privileges. The existing auditor read-only Audit_Log grant is retained. No `sp_internal_*`, evaluator, raw function, wildcard EXECUTE or GRANT OPTION is granted.

Only after explicit approval, set `@rbac_apply=1` and source the script again in that same connection with an empty suffix. MySQL8.4 does not support PREPARE CREATE ROLE (1295): standard role DDL is static under the opt-in branch; GRANT uses valid session-variable PREPARE. Suffixed apply is refused server-side; an approved isolated deployment executes the printed suffixed statements as top-level native CLI SQL instead. The apply flag resets to0 on completion/error. CREATE ROLE IF NOT EXISTS and repeated identical GRANT statements support repeat installation; this is additive installation, **not** a privilege revocation/reconciliation tool. Existing broader privileges require a separate reviewed revocation plan. No user is created, assigned a role, or made default automatically. A failure can leave partially applied privileges because account/grant DDL is not transactionally rolled back; record the plan and use the approved cleanup inventory.

## Intended grant policy

| Role | SELECT | Public EXECUTE |
|---|---|---|
| Customer | own-customer account summary, actor-filtered activity | deposit, withdraw, transfer, transfer retry, statement |
| Teller | actor-filtered activity | register/update customer, open/close/status account, deposit/withdraw/transfer/retry, statement, reconcile |
| Manager | customer summary (still customer-filtered), actor-filtered activity, fraud queue | teller APIs plus approval request/decision, loan disbursement, fraud review, monthly interest |
| Auditor | fraud queue, actor-filtered activity, Audit_Log read-only | none |

This restores the explicit pre-regression public API lists, not new authorization behavior in other procedures. Having EXECUTE does not override a routine's validation: ordinary Branch postings still require an active same-branch Teller, and customer debits remain owner-constrained. Fraud queue is role-scoped rather than branch-filtered. An auditor without a mapped Customer/Employee sees no activity rows under the existing activity view; it still has the global read-only audit/queue access listed above.

Every application login must have a validated exact `USER()` mapping in DB_User_Map **before** receiving its role. Do not grant a banking role to an unmapped login: existing trusted-System semantics deliberately allow internal/admin workflows. The statement API permits Customers only their own accounts; Employees only active same-branch Tellers/Managers; trusted System remains supported. Authorization rejection uses 5010. A mapped DBA is not a servicing employee for this API. No broad table privilege is a workaround.

## Isolated restricted-role test plan — explicit approval required per deployment

No part of this plan is executed automatically by the safe acceptance runner.

1. Allocate a unique ownership-verified disposable database, its random owner token and an eight-hex suffix. Never target protected banking/helper schemas. Use the same SOURCE expansion/helper-namespace relocation and owner checks as `tests/regression/pr9_acceptance.ps1`; the original protected-target allowlist is not bypassed.
2. Set `@rbac_role_suffix='_pr9_<8hex>'`. Roles are `bank_customer_role_pr9_<8hex>`, `bank_teller_role_pr9_<8hex>`, `bank_manager_role_pr9_<8hex>`, `bank_auditor_role_pr9_<8hex>`, all within MySQL's account-name length limit. Preflight mysql.user: all four role names AND all three test-user names must be absent at every host. Abort on any collision; do not reuse or change existing accounts.
3. Reserved users: `zz_a_pr9_c_<8hex>`, `zz_a_pr9_t_<8hex>`, `zz_a_pr9_m_<8hex>`, host `127.0.0.1` only, TCP loopback only. Generate independent cryptographic random passwords in memory. Pass each password only as the child process's MYSQL_PWD environment; never write it, put it in command arguments or log its CREATE USER statement. CREATE USER must use a separate non-logged invocation. Clear child environment and memory references afterward.
4. Preview the exact suffixed 45-statement plan and obtain approval. Extract only the `RBAC|PLAN|` payloads to an in-memory UTF-8 native-client SQL batch with statement terminators; compare them against the approved schema/role/object allowlist. Execute as top-level SQL (CREATE ROLE cannot be prepared), never by applying the standard unsuffixed installer. With the approved inventory, apply only those CREATE ROLE/GRANT operations in the disposable target; assign exactly one corresponding suffixed role to each new test user and SET DEFAULT ROLE. Auditor role has no user in this three-login matrix. Record non-secret SHOW GRANTS, CURRENT_ROLE and CURRENT_USER/USER output.
5. Connect as each user with native mysql --no-defaults --protocol=TCP --host=127.0.0.1 and in-memory child MYSQL_PWD. Calibrate its actual USER() and populate only disposable DB_User_Map/fixture rows as administrator before making API calls. Assert positive role/view/statement behavior, customer foreign rejection 5010, staff wrong-branch/inactive rejection 5010, base-table SELECT/DML denial (1142/1143), private-helper EXECUTE denial (1370), no grant option, and no unintended roles. Verify audit session/actor attribution after an allowed posting, rollback behavior and six invariants.
6. **Finally, even after failure:** DROP only test users whose successful creation was recorded by this invocation, then DROP only its recorded fresh suffixed roles (dropping a test role also removes its target grants). Remove disposable maps with the database. Verify owner token before DROP DATABASE; verify zero remaining schema, exact role/user accounts and target privilege records. If any cleanup fails, retain the inventory and stop; never compensate by touching existing/global production accounts. Routine definer remains the administrative test connection, not a dropped test login.

Member A explicitly approved this isolated plan on2026-10-20. The -WithRestrictedRoles acceptance path implements it; see evidence/reviews/PR9-final-fixes/REPORT.md for actual results. That approval covered only fresh test accounts/roles, not deployment of standard roles or changes to existing users. Future deployments require their own authorization. Preview/prepare-only checks alone do not prove authentication, effective privileges or cleanup. A macOS editor extension is not required; its specific historical failure cannot be diagnosed without the extension/version and exact error.
