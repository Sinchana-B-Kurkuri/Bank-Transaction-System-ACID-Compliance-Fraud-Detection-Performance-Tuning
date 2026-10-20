# Windows banking demo

For the professor-ready web dashboard, follow [DASHBOARD_GUIDE.md](DASHBOARD_GUIDE.md).
It reuses this CLI's MySQL adapter and owned lifecycle, needs no extra packages,
and runs at127.0.0.1:5000. The CLI instructions below remain valid.

This is a local, standard-library Python3.10+ CLI using the native MySQL8.4
client. Financial mutations call existing public stored procedures. There is no
web server, connector package, private-routine grant or direct financial DML in
the CLI. The server's procedures, views and grants remain authoritative.

## Setup

From the repository root in Windows PowerShell5.1 or newer:

```powershell
$env:BANK_MYSQL_CNF = Join-Path $HOME '.bank_mysql.cnf'
$env:BANK_MYSQL_BIN = 'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe'
$env:BANK_PYTHON_BIN = 'C:\Path To Python\python.exe'
$env:PYTHONUTF8 = '1'
& $env:BANK_PYTHON_BIN --version
& $env:BANK_MYSQL_BIN --version
```

Install Python3.10+ and MySQL8.4 locally if absent. `BANK_PYTHON_BIN` must name a
real executable, not a Windows Store alias. No pip install is required. On this
machine Python was provided by the desktop's bundled runtime; that machine-local
path is recorded in the final report rather than required by the project.

Private option-file **template only** (set your own credentials externally):

```ini
[client]
host=127.0.0.1
port=3306
# Set user and password privately; never commit them.
```

The administrative build connection needs permission to create the unique
disposable schemas and DEFINER routines/triggers. Building does not create
accounts, roles or grants, change globals, or target bank_txn, bank_txn_scratch or
bank_lab. A's isolated context relocates helper references to the owned helper
schema. External option-file paths and executable paths may contain spaces.

## Start, use and stop

```powershell
powershell -NoProfile -File demo/start_demo.ps1
$session = Get-Content demo/out/session.json -Raw | ConvertFrom-Json
$db = $session.Database
function bank {
    & $env:BANK_PYTHON_BIN demo/bank_cli.py --database $db --non-security-demo @args
}
bank whoami
bank accounts
& $env:BANK_PYTHON_BIN demo/bank_cli.py --help
```

**NON-SECURITY DEMO:** the flag is required for the privileged walkthrough. It
does not impersonate a role or prove least privilege. Each command authenticates
using the real option file and opens its own native session. No persistent client
transaction is assumed; public procedures own their COMMIT/ROLLBACK boundaries.
Native MySQL errors are printed and return a nonzero exit code. The CLI uses
UTF-8 stdin, no shell interpolation, validated decimal/id/date arguments and
hex-encoded text literals. Session lock waits are5s and command deadlines30s.

`Start` collision-checks three fresh `bank_a_ci_demo_<12hex>_{main,scratch,lab}`
names, writes random owner markers and builds Integrated/Baseline with synthetic
seed. It refuses an existing session file. The JSON contains names/owner token,
not passwords. Session files live under ignored `demo/out/`.

When finished:

```powershell
powershell -NoProfile -File demo/start_demo.ps1 -Action Stop
```

Stop checks **every** exact schema name and ownership marker before dropping any
database, checks zero remaining schemas, then marks the session cleaned. It never
adopts unrelated databases. To start another run without deleting evidence, use
a fresh `-SessionFile demo/out/another-session.json` on both Start and Stop. Do not
use protected default rebuild/test commands as a shortcut.

## Professor walkthrough (about five minutes)

1. Start as above; show `bank whoami`, database name, MySQL version in the build
   evidence and the explicit non-security banner.
2. Run `bank accounts`. Seed accounts1 and2 are active; verify displayed IDs
   instead of assuming IDs in another dataset. Show account6 is Frozen.
3. Run registration/opening, copying returned IDs. Use only synthetic data:

```powershell
bank register --name 'Synthetic Demo Customer' --dob 1992-01-01 `
  --email live.demo@example.invalid --phone 9000099992 `
  --address 'Synthetic demo address' --id-proof SYN-PAN-LIVE-0001 --id-type PAN
# Substitute returned customer ID and displayed branch/type/staff IDs.
bank open --customer 7 --branch 1 --type 1 --initial 2000 `
  --number DEMO-LIVE-1 --employee 1
# Substitute returned account ID:
bank deposit 9 100
bank withdraw 9 25
bank transfer 9 2 50
bank accounts
bank history 9
$today = Get-Date -Format yyyy-MM-dd
bank statement 9 --from $today --to $today
bank withdraw 9 99999999   # Expected5004; check nonzero $LASTEXITCODE.
```

4. Show opening Deposit, the paired transfer_group_id, Completed rows and balances.
   Explain that a business rejection may create a Failed row after rollback.
5. Run `bank flags`; choose an Open flag and an active Manager ID from the
   reference seed (branch1 manager is normally3):

```powershell
# Substitute a displayed Open flag ID and actual Manager ID.
bank review 1 UnderReview --manager 3
bank review 1 Confirmed --manager 3
bank audit
bank reconcile
```

6. Show all six PASS invariants. Explain the audit installation watermark and why
   DBA trigger removal is outside trigger protection. Fraud is detective and
   transactional: its flags roll back with a failed banking operation.
7. For reproducible normal/suspicious fraud, approval and loan examples, actual
   two-session isolation/deadlock/retry, rollback and measured B0/Optimized plans,
   execute `tests/demo/run_demo.ps1` below and inspect its retained artifacts.
   Its temporary actor mapping is expressly an authorization diagnostic, not a
   least-privilege demonstration. CLI commands `loan`, `request-approval` and
   `decide-approval` are also available; approval requests require a mapped actor,
   so an unmapped System request correctly fails5010.

## Authenticated role mode (pending fresh account approval)

Only after separately approved provisioning and cleanup, use each user's external
option file with **no** `--non-security-demo` flag:

```powershell
& $env:BANK_PYTHON_BIN demo/bank_cli.py --database $db `
  --config 'C:\Private\customer.cnf' whoami
```

The client checks actual `CURRENT_ROLE()` for a recognized banking role; it has
no role-selection flag. The server must have the approved role grants and a
`DB_User_Map` row matching actual `USER()` (with resolver fallback). A menu does
not replace authentication. The demo launcher deliberately provisions neither.
The CLI never calls private helpers or grants extra access to make a command work.

| Authenticated role | Existing permitted interface | Important limit |
|---|---|---|
| Customer | own summary/activity, deposit/withdraw/transfer, own statement | Ownership enforced by server; approved A17 debit rules retained |
| Teller | branch-filtered activity, derived latest Completed balances, public teller APIs/statements | No base-table SELECT; only active same-branch access |
| Manager | branch activity, fraud queue, public manager APIs/approvals/review | Customer-summary view remains customer-filtered; no manager Audit_Log SELECT grant |
| Auditor | fraud queue/activity and read-only Audit_Log | No mutation or statement EXECUTE; unmapped auditor activity may be empty |

Forbidden commands produce actual permission/authorization errors; the CLI does
not broaden the grant surface. Auditor mapping has no special enum value in
DB_User_Map (Customer/Employee only); role policy and view filtering remain as
implemented. Fresh restricted authentication is **not certified by this demo**.

## Safe verification commands

```powershell
# All audited safe regressions plus CLI workflow, owned cleanup, 2–4 minutes:
powershell -NoProfile -File tests/demo/verify_all.ps1
# Workflow alone (new DB every run, automatic finally cleanup):
powershell -NoProfile -File tests/demo/run_demo.ps1
# Standard-library input tests:
& $env:BANK_PYTHON_BIN -m unittest discover -s tests/demo -p 'test_*.py'
```

All reports use new timestamp/GUID directories under
`evidence/reviews/final-demo/runs/` (PR9/1222/Quick use their existing unique
destinations). Historical evidence is never overwritten. The safe regression
omits legacy nested scripts that create reserved global test users. It runs all
numbered SQL tests, vetted safe PowerShell tests, signatures, B0/Optimized and
actual bounded Quick. Missing deployed roles stay pending, not counted as pass.

The demo workflow captures four real two-session isolation probes; a temporary
**database-only mode3 first-lock pause** reused from EXP-10 makes the actual naive
deadlock/retry reproducible, then the exact original routine is restored in
finally. No source or ordered-mode behavior changes. Full EXP-10's global logging,
full stress grids and crash/restart/PITR are not run by these commands.

Performance output has3 fixed queries ×20 measured session-timestamp samples ×2
profiles, plus two warmups each. It retains EXPLAIN, per-sample microseconds,
index inventories and environment. Timings bracket native statements with
NOW(6); they exclude process startup but include result production and
interstatement client/protocol overhead (not isolated server CPU time). Tiny data,
warm cache, no representative load, and Baseline-then-Optimized order prevent a
general speedup conclusion. Scaling requires an approved synthetic fixture and
randomized profile order; no production index change is proposed.

## Fraud thresholds and honest scope

See unchanged `data/seed/03_fraud_rules.sql` and `functions/fn_txn_risk_score.sql`.
Helper: amount5000→+20, amount10000→+35; digital+10; untrusted/missing device+20;
profile input is zero in evaluator. Catalog matches add weights independently:
amount≥5000 +20, untrusted +20, digital +10, accumulated local risk≥60 +25,
≥3 Completed rows in10minutes +25. Score capped100. Classification: below30 Low,
below60 Medium, below85 High, otherwise Critical.

Thus the approved helper digital/untrusted probe is30; it is **not** a promise
that final evaluator score is30 after catalog weights. A trusted Branch100 with
only two recent rows produces no flags; a missing-device Online6000 generates
Critical100 in the controlled walkthrough. Repeating evaluation without changed
facts keeps flag count/scores stable. Stored account-profile score is a maximum
over evaluated transactions, not a replacement transaction-local score.

Distance/odd-hour functions are callable diagnostics, but there is no active
location-change/time-anomaly rule in this seed. Adding one needs a separate
policy decision. Security, recovery and performance limitations are also listed
in `evidence/reviews/final-demo/REPORT.md`.
