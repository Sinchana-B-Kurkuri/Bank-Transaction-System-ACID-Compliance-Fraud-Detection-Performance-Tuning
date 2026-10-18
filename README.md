# Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning

## Member A — build & test

Requires MySQL 8.0.16+ (enforced CHECK constraints), the mysql CLI on PATH, and PowerShell. Set `BANK_MYSQL_CNF` to a local MySQL option file; never commit credentials. Run from the repository root:

```powershell
$env:BANK_MYSQL_CNF = Join-Path $HOME '.bank_mysql.cnf'
powershell -File build/env_check.ps1
powershell -File build/rebuild.ps1 -Database bank_txn -Mode Standalone
powershell -File tests/run_tests.ps1 -Database bank_txn
```

Rebuild drops only `bank_txn` or `bank_txn_scratch`. The default test run rebuilds first. `-NoRebuild` is for an already disposable schema; procedure tests cannot rely on rollback. `-Filter` matches test file basenames with a PowerShell wildcard. Logs are saved under evidence/test-runs. B0 is saved by rebuild in evidence/EV-B0-1.txt.

Standalone uses interface stand-ins under tests/stubs; Integrated requires all seven B table files and their SOURCE lines in build/run_all.sql and build/file_order.txt. No B files were present when this foundation was created. Workbench users follow build/file_order.txt, selecting the banking database first. Optional `-WithSeed` loads sorted data/seed/*.sql files; it fails before dropping anything if no seed loader exists. Load opening Completed Deposit rows with balances before installing future triggers.

Prompt 1 implements schema and test infrastructure. Business procedures, functions and triggers listed in docs/member-a/SPEC.md are public contracts for subsequent prompts. See docs/member-a/DELIVERY.md for actual verification status.

The wrapper supports Windows PowerShell 5.1 and paths containing spaces. It captures MySQL stdout and stderr separately and saves original errors in the environment evidence file. Oracle MySQL does not support `--abort-source-on-error`; the wrapper expands standalone `SOURCE` lines (relative to the working directory) into UTF-8 batch input and disables `--force`, so execution stops on the first SQL error. A normal PowerShell variable such as `$env` is not inherited by child processes; set `$env:BANK_MYSQL_CNF` as shown above. If mysql.exe is absent from PATH, the wrapper also detects a single standard installation under Program Files/MySQL.
