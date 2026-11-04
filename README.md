# Bank Transaction System — ACID Compliance, Fraud Detection & Performance Tuning

A MySQL banking project demonstrating ACID transactions, concurrency control,
fraud detection, audit logging, and query performance tuning. A local Python web
dashboard and command-line interface call the database's stored procedures.

The browser communicates with a local Python HTTP server, which invokes the native
MySQL client. Banking procedures manage transactions, while database constraints
and triggers enforce ledger rules, evaluate fraud, and record audit events.

## Features

- Customers, accounts, deposits, withdrawals, transfers, approvals, loans,
  interest posting, and statements.
- Transaction rollback, ordered account locks, and deadlock retry.
- Configurable fraud rules, risk scoring, and a fraud review queue.
- Immutable transaction records, audit triggers, and reconciliation invariants.
- Baseline and optimized index profiles with recorded query plans and timings.
- SQL tests and experiments for isolation, stress, and recovery.

## Requirements

- Windows PowerShell 5.1+ or PowerShell for the supplied automation.
- MySQL 8.0.16+ with InnoDB and the native `mysql` client.
- Python 3.10+ for the dashboard and CLI; no third-party Python packages required.
- Optional: Node.js, Playwright, and installed Microsoft Edge for browser tests.

## Run the dashboard

Run commands from the repository root. Create a private MySQL client option file
outside the repository with your local connection details:

```ini
[client]
host=127.0.0.1
port=3306
user=YOUR_LOCAL_MYSQL_USER
password=YOUR_LOCAL_MYSQL_PASSWORD
```

Configure PowerShell with the paths for your installation:

```powershell
$env:BANK_MYSQL_CNF = Join-Path $HOME '.bank_mysql.cnf'
$env:BANK_MYSQL_BIN = 'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe'
# Set this only if Python is not on PATH:
# $env:BANK_PYTHON_BIN = 'C:\Path To Python\python.exe'
$env:PYTHONUTF8 = '1'

powershell -NoProfile -File demo/start_demo.ps1 -SessionFile demo/out/dashboard-session.json
powershell -NoProfile -File demo/start_dashboard.ps1 -SessionFile demo/out/dashboard-session.json
```

Open **http://127.0.0.1:5000**. Initialization creates fresh, ownership-marked demo
databases and synthetic data. The administrative walkthrough is a **non-security
demo**; restricted-role deployment is a separate operation described in
[security/README.md](security/README.md).

Stop the dashboard with `Ctrl+C`, then clean up its databases:

```powershell
powershell -NoProfile -File demo/start_demo.ps1 -Action Stop -SessionFile demo/out/dashboard-session.json
```

For another run, choose a fresh session filename for both startup commands and
cleanup. See the [dashboard guide](demo/DASHBOARD_GUIDE.md) for the professor
walkthrough and the [CLI guide](demo/README.md) for command-line usage.

## Project documents

The [`docs/`](docs/) folder contains the three final submission files:

| Submission | File |
| --- | --- |
| Final project report | [Final Project Report.docx](docs/Final%20Project%20Report.docx) |
| Phase 1 design presentation | [Review1 Design Presentation.pptx](docs/Review1%20Design%20Presentation.pptx) |
| Final project presentation | [Final Project Presentation.pptx](docs/Final%20Project%20Presentation.pptx) |

## Repository layout

| Path | Contents |
| --- | --- |
| `schema/` | Tables, constraints, baseline indexes, and lab schema |
| `functions/`, `procedures/` | Banking, fraud, identity, and transaction routines |
| `triggers/`, `views/` | Audit, guard, and fraud triggers; reporting views |
| `data/seed/` | Synthetic reference data, banking dataset, and fraud rules |
| `build/` | Ordered SQL builds, environment checks, and release generation |
| `demo/` | Python CLI, local dashboard, web assets, and launchers |
| `tests/` | SQL, PowerShell, Python, and optional browser checks |
| `experiments/` | ACID, isolation, deadlock, stress, and recovery experiments |
| `indexes/`, `benchmarks/` | Optional performance indexes and query comparison |
| `backup/` | Backup and point-in-time recovery scripts |
| `security/` | Role/grant definitions and deployment instructions |
| `docs/` | Two project presentations and the final Word report |
| `evidence/` | Recorded measurements and outputs supporting project results |

The SQL build files and `build/file_order.txt` define the dependency order.
Integrated mode installs the actual banking and fraud components; Standalone mode
uses interface stubs for development. Baseline is the default index profile;
optimized indexes require explicit selection. See the
[procedure documentation](procedures/README.md),
[interface contracts](procedures/INTERFACES.md), and
[index profiles](indexes/README_PROFILES.md).

The [ER diagram source](schema/er_core.mmd) belongs to the schema and is checked by
the integration tests. The
[procedure signature contract](tests/integration/support/procedure_contract.md)
lives beside its test tooling. The `backup/` folder contains executable recovery
tools used by the durability and point-in-time recovery experiments; generated
dumps and state files belong to ignored `backup/out/`.

## Verification

Run focused checks without a database:

```powershell
python -m unittest discover -s tests/demo -p 'test_*.py'
python -m unittest discover -s tests/dashboard -p 'test_*.py'
powershell -NoProfile -File tests/schema/03_source_order.ps1
powershell -NoProfile -File tests/integration/support/Write-SignatureContract.ps1 -Check
```

With the private MySQL configuration set, the dedicated acceptance runners create
and clean up their own disposable schemas:

```powershell
powershell -NoProfile -File tests/regression/pr9_acceptance.ps1
powershell -NoProfile -File tests/regression/error1222_seed.ps1
```

Read the [acceptance instructions](tests/regression/README_PR9.md),
[seed regression guide](tests/regression/README_ERROR1222.md), and
[experiment index](experiments/README.md) before broader runs. Legacy rebuild/test
commands can recreate `bank_txn` or `bank_txn_scratch`; some suites also manage
temporary MySQL accounts. Recovery experiments can stop services or restore data.
Use their documented disposable targets and prerequisites.

The optional [browser regression](tests/dashboard/ui_regression.cjs) requires an
already running owned demo session, Playwright, and Microsoft Edge:

```powershell
node tests/dashboard/ui_regression.cjs http://127.0.0.1:5000 demo/out/browser-check
```

Choose a new output directory for each browser run. Node.js and Playwright are
test tools; the application itself uses Python's standard library and MySQL.

## Results and limitations

The dashboard displays live banking data and labels recorded experiment results
with their source and date. Retained evidence supplies isolation, deadlock,
performance, and test summaries; keep those files with the project. The
[retained evidence](evidence/) contains the recorded experiment outputs behind
those summaries. Experiment instructions and measured results remain beside
their scripts under `experiments/`.

This academic model uses synthetic data, one owner per account, and one currency.
Fraud detection flags transactions for review. Audit coverage begins when audit
triggers are installed, and a DBA can bypass those controls. Public procedures own
their transaction boundaries. Recorded results are historical measurements.
