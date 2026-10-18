# Prompt 1 delivery — 2026-10-18

## Connectivity follow-up — current status

LOCALLY TESTED on MySQL 8.4.11 using Windows PowerShell. This follow-up supersedes the original blocked statuses below; those original entries are retained as history.

Exact cause: build/mysql_common.ps1 supplied `--abort-source-on-error`, which the installed Oracle MySQL client rejects with `mysql: [ERROR] unknown option '--abort-source-on-error'.` and exit code 2. The old env_check.ps1 catch block discarded RawOutput and saved only `mysql exited 2`, hiding the useful diagnostic. This was independent of successful direct connection commands.

The wrapper now uses ProcessStartInfo with Windows argument quoting, separate asynchronous stdout/stderr capture, and explicit UTF-8 stdin bytes compatible with Windows PowerShell 5.1/.NET Framework. It expands SOURCE includes before batch execution and uses --skip-force to stop on SQL errors. SQL no longer crosses the native command-line quoting boundary. Error exceptions retain ExitCode, StdOut, StdErr and RawOutput, and include stderr in the message. env_check.ps1 saves these diagnostics and balances Push/Pop-Location even on failure. No option-file contents or credentials are logged.

| Follow-up verification | Status / actual result |
|---|---|
| powershell -File build/env_check.ps1 | LOCALLY TESTED — exit 0, version 8.4.11; measured environment.md and EV-ENV-1.txt |
| powershell -File build/rebuild.ps1 -Database bank_txn -Mode Standalone | LOCALLY TESTED — exit 0; rebuilt in 3.38 seconds |
| powershell -File tests/run_tests.ps1 -Database bank_txn | LOCALLY TESTED — exit 0; second successful rebuild, 186 PASS / 0 FAIL |
| SQL coverage | LOCALLY TESTED — 38 interface + 57 negative + 62 structure/idempotence assertions |
| PowerShell coverage in that run | LOCALLY TESTED — 25 SOURCE checks + 4 wrapper regression checks |
| Real client, option-file path containing spaces | LOCALLY TESTED — SELECT VERSION() returned 8.4.11; EV-MYSQL-SPACES-1.txt |
| Real client, stop on first SQL error | LOCALLY TESTED — ERROR 1054 retained; preceding SELECT ran and following SELECT did not; EV-MYSQL-BATCH-1.txt |
| Five SHOW CREATE outputs and B0 snapshot | LOCALLY TESTED — EV-SCHEMA-1.txt and EV-B0-1.txt now contain actual output |

The successful test log is evidence/test-runs/20261018-182116-620.txt. Wrapper probes are isolated synthetic executable tests; they are distinct from the 157 real SQL assertions. See EV-MYSQL-WRAPPER-1.txt for the regression and failure-diagnostic evidence. Environment/rebuild/tests ran with BANK_MYSQL_CNF pointing to the user-provided local option file. No commit, push, branch switch or Prompt 2 work occurred. Requests to B: none. Integrated build still awaits B's real files.

Changed for this fix: build/mysql_common.ps1, build/env_check.ps1, README.md, this delivery report, measured environment/evidence and inventory; added tests/schema/04_mysql_wrapper.ps1 and diagnostic evidence. The earlier foundation files were otherwise retained.

## Original delivery record

IMPLEMENTED in the working tree on `feature/A-core-schema`. No commit, push, branch creation/switch, or main/develop modification was performed. Initial inspection found only README.md and an existing untracked .gitignore. `git log --oneline -15` returned `544b104 Initial commit`; `git ls-tree -r --name-only develop` returned only README.md. No B implementation exists on develop or the current branch.

## Deliverable status

| Deliverable | Status | Evidence / limitation |
|---|---|---|
| Exact SPEC; D1–D7 and A1–A17; public interface; requests header | IMPLEMENTED | docs/member-a/SPEC.md, docs/decisions.md, docs/interfaces.md; no previous decision/interface files existed |
| Environment scripts | IMPLEMENTED | build/env_check.sql and build/env_check.ps1 |
| Measured environment values | BLOCKED | evidence/EV-ENV-1.txt; BANK_MYSQL_CNF unset and mysql absent from PATH |
| Nine core tables; 13 core FKs; three conditional cross FKs | IMPLEMENTED | schema/01_tables and schema/02_constraints; MySQL execution pending |
| Cross-FK idempotence | NEEDS MANUAL VERIFICATION | 02_structure.sql reapplies the file twice; SQL not executed |
| Six B stand-ins and 38 column contract checks | IMPLEMENTED | tests/stubs and tests/schema/00_interface_contract.sql |
| bank_lab log/result tables and four helpers | IMPLEMENTED | schema/04_lab/01_bank_lab.sql; runtime verification pending |
| Standalone/integrated build and test runner | IMPLEMENTED | build and tests/run_tests.ps1; integrated mode requires B's real files |
| SOURCE/Workbench synchronization | LOCALLY TESTED | 25 PASS, 0 FAIL; evidence/EV-SOURCE-1.txt |
| PowerShell parsing | LOCALLY TESTED | Five files, zero parse errors; evidence/EV-PS-PARSE-1.txt |
| Database allowlist | LOCALLY TESTED | Rejected forbidden_database before connecting; evidence/EV-DB-GUARD-1.txt |
| 57 negative and 62 structure checks | NEEDS MANUAL VERIFICATION | Written, but no SQL cases executed |
| Successful rebuild from empty twice | BLOCKED | Both repeat attempts exited 1 before database execution; evidence/EV-VERIFY-1.txt |
| SHOW CREATE and B0 measurements | BLOCKED | EV-SCHEMA-1.txt and EV-B0-1.txt contain blocker notices, not measured output |
| README, ignore rules, migration freeze, empty layout folders | IMPLEMENTED | Existing README/.gitignore extended; no existing text removed |
| B files / credentials / dumps | LOCALLY TESTED | No B implementation edited; only permitted empty-folder markers; no credentials, dumps or real PII added |

## Commands and actual results

* `git branch --show-current`: feature/A-core-schema (checked before changes and after verification).
* Repository inventory (`rg --files --hidden -g '!.git/**'`), git status, git log, README/.gitignore reads, and develop tree inspection completed. No existing schema/build/tests, decisions.md, interfaces.md or AGENTS.md were found.
* `powershell -File build/env_check.ps1`: exit 1, BANK_MYSQL_CNF unset. The initial Windows PowerShell encoding parse failure was fixed and the command rerun; the final failure is connection configuration.
* `powershell -File build/rebuild.ps1 -Database bank_txn -Mode Standalone`: exit 1, BANK_MYSQL_CNF unset. Two further repeat attempts both exited 1 before connecting. No successful rebuild or database drop occurred.
* `powershell -File tests/run_tests.ps1 -Database bank_txn`: exit 1; final default-run log reports PASS=0, FAIL=1 (rebuild blocked), no SQL tests executed.
* `powershell -File tests/run_tests.ps1 -Database bank_txn -NoRebuild`: exit 1; PASS=25, FAIL=3. All 25 are SOURCE synchronization checks; the three failures are blocked SQL-file invocations, not evaluated SQL assertions.
* `powershell -File tests/schema/03_source_order.ps1 -Database bank_txn`: exit 0, 25 PASS / 0 FAIL.
* PowerShell AST parser over the five final .ps1 files: zero errors. Windows PowerShell also executed env_check, rebuild, runner and SOURCE check scripts.
* `powershell -File build/rebuild.ps1 -Database forbidden_database`: exit 1, expected allowlist rejection before connection.
* SHOW CREATE TABLE for Transactions, Accounts, Loans, Audit_Log and Fraud_Flags, plus the B0 query, were attempted through the mysql wrapper and stopped at its missing-option-file preflight. The mysql executable itself could not run: it is absent from PATH. No schema/index output was fabricated.
* `git diff --check`: exit 0; Git reports only its normal LF-to-CRLF warning for README.md.

Raw test logs are under evidence/test-runs. The earliest log preserves the initial runner failure; the later default and NoRebuild logs preserve the corrected diagnostic behavior. Do not sum repeated checks across runs as distinct tests.

## Blockers and requests to B

Configure a MySQL 8.0.16+ CLI on PATH and set BANK_MYSQL_CNF to an existing local option file. Then rerun the README commands, repeat rebuild twice, capture the five SHOW CREATE statements, and inspect the measured environment/B0 outputs. No connection configuration or server version was available in this session. No installer, service change or guessed credentials were used.

No change requests to B were needed; REQUESTS_TO_B.md contains its requested empty header. The Transaction_Approvals assumption remains explicitly marked in SPEC/interfaces for B confirmation. Integrated mode remains unavailable until B's seven tables and matching include/order entries are supplied. Optional Benchmark_Results includes are comments only; no B benchmark table was created.

Prompt 1 does not install the later business routines or audit/guard triggers, so no AUDIT_TRIGGERS_INSTALLED watermark was falsely recorded. The SQL fixtures roll back their data and helper result inserts; their emitted TEST lines remain in the external runner log. MySQL exposes PRIMARY KEY names as PRIMARY even when a pk_ constraint symbol is declared; structure tests use that native name.

## Completion checklist

- [x] SPEC, decisions D1–D7/A1–A17, interfaces written.
- [ ] Environment record contains measured server values (BLOCKED).
- [x] Nine table files and core constraints written.
- [ ] Cross-FK idempotence proven on MySQL (test written).
- [x] Stand-ins and column contract test written.
- [x] bank_lab and helper code written.
- [ ] Rebuild successful twice from empty (BLOCKED).
- [ ] Negative SQL tests all PASS (not executed).
- [ ] B0 snapshot measured (BLOCKED).
- [x] No existing B implementation modified.
- [x] No secrets/dumps added; fixtures are synthetic.
- [x] Summary, status table and inventory recorded.

## Files created / changed

Existing README.md and the previously untracked .gitignore were extended. All other listed files are newly created; no pre-existing schema or test file was overwritten. See FILES.txt for the complete inventory, including empty-folder markers and evidence logs.
