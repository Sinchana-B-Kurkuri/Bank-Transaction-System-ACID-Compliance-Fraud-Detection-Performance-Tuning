# Focused ERROR 1222 seed regression

Run from the repository root with Windows PowerShell and the existing private MySQL option file:

```powershell
$env:BANK_MYSQL_CNF = 'C:/path with spaces/private.cnf'
$env:BANK_MYSQL_BIN = 'C:/Program Files/MySQL/MySQL Server 8.4/bin/mysql.exe'
powershell -NoProfile -File tests/regression/error1222_seed.ps1
```

To reproduce the actual original defect first, using the evaluator from corrective commit 053eb19, then test the current source in a separate fresh database:

```powershell
powershell -NoProfile -File tests/regression/error1222_seed.ps1 -ReproduceOriginal
```

MySQL 8.4.11 is explicitly checked. The default command fails if the current source reintroduces the mismatch: it must execute the real loader, account-opening public API, ledger INSERT and fraud trigger successfully before assertions can pass. This focused test lives outside the existing general runner because that runner on this branch still targets protected banking databases. Do not substitute the existing rebuild/run_tests scripts or source error1222_seed.sql directly against a banking database.

## Scope and safety

The harness generates fresh `bank_b_1222_<GUID>_before/after` names; there is no caller-supplied database parameter. It refuses existing schemas, creates without IF NOT EXISTS, records an ownership marker, checks ownership before cleanup, and removes only its own databases. Administrative connections default to information_schema; test connections explicitly default to the disposable database. It never calls or overrides Assert-BankDatabase or Invoke-BankMysql and never runs an existing destructive runner.

Member A's feature/A-integration-docs isolated tooling was inspected read-only. Its full regression requires other runner/build changes; importing that chain would exceed this defect's scope. This harness follows its exact-target, ownership and helper-namespace approach and reuses only the already-present native argument quoting and SOURCE expansion helpers. No merge, cherry-pick, branch switch, wrapper modification or unrelated tooling import is needed.

The dependency closure installs original files: nine core tables, B Devices/Locations/Fraud_Rules/Account_Risk_Profile/DB_User_Map, real constraints, required functions/public and private procedures, all A guards/audits, the audit watermark, synthetic reference/rule data and the real B fraud trigger. No stubs, views, role grants, users, optional indexes or benchmark objects are installed. bank_lab helper definitions/references are relocated **only in executed test SQL** to the owned disposable database. Original helper, banking and trigger sources are unchanged. Expanded SQL is checked before execution for protected targets, unrelated database DDL, USE, global changes and user/role operations; installed routines/triggers are checked again for protected references.

The original tiny-seed definition is loaded unchanged, except its final automatic CALL/DROP trailer is omitted in the test bundle so the harness can call it explicitly and rerun it. The ordinary seed source is not edited. Error 1222 reproduction comes from the original evaluator executing inside that call chain, not a simulated SIGNAL. All native SQL/stdout/stderr and an outcome summary go to a fresh `evidence/error1222/<timestamp-GUID>/` directory. No historical evidence is overwritten; no option-file contents or passwords are copied.

Assertions cover the loader and rerun, independent opening deposit, direct evaluator/timestamp mapping, automatic flags/profile, audit attribution/order, real mode-1 rollback with ledger/audit/fraud side effects, ordered transfers in both directions, all six invariants, namespace qualification and cleanup. These are focused functional checks, not a full regression or a concurrent deadlock/performance demonstration.
