# Offline banking dashboard — Windows

No Flask, pip install, frontend build or internet/CDN is needed. The local server
uses Python3.10+ standard library, the existing native mysql client and external
private option file. The CLI remains available; no production SQL is replaced.

## Start in two commands

From the repository root, configure these once in the PowerShell window:

```powershell
$env:BANK_MYSQL_CNF = Join-Path $HOME '.bank_mysql.cnf'
$env:BANK_MYSQL_BIN = 'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe'
$env:BANK_PYTHON_BIN = 'C:\Path To Python\python.exe'
$env:PYTHONUTF8 = '1'
```

The client option file remains outside Git; use your own private [client]
host/port/user/password configuration. No password goes into the dashboard UI.
Then:

```powershell
powershell -NoProfile -File demo/start_demo.ps1 -SessionFile demo/out/dashboard-session.json
powershell -NoProfile -File demo/start_dashboard.ps1 -SessionFile demo/out/dashboard-session.json
```

Open **http://127.0.0.1:5000**. The second command stays in the foreground. Debug
mode is absent/off; the server binds loopback only. An already occupied port is
an error, not permission to terminate an unrelated process. Optional `-Port 5001`
changes only the local HTTP port; the fixed live test uses5000.

Start refuses an existing session filename. After finishing a run, choose a new
filename (for example demo/out/dashboard-next.json) for both commands instead of
overwriting historical evidence. The server refuses cleaned sessions, malformed
names and mismatched database ownership. Page visits never allocate schemas.

## Professor flow

1. Click **Start guided demonstration** on Overview. Use Next/Previous through
   twelve stages. Live overview figures and charts come from MySQL.
2. Register using the generated example.invalid / SYN- defaults. The real returned
   Customer ID is selected in Open account. Choose a type and sufficient opening
   deposit; employee None means Online, while a selected Teller must match branch.
3. The returned new account is selected as a banking default. Deposit100,
   withdraw25 and transfer50 to a different Active account. The result panel shows
   original procedure output and actual before/after balances and effect counts.
4. Generate today's statement or history. Compare Completed balance_after and
   running_balance. A rejected excessive withdrawal may add a Failed row after
   rollback, as documented by D4; it does not commit a partial Completed transfer.
5. On Fraud Detection submit the actual Online6000 deposit. The latest matched
   flags/score and account risk are read from MySQL. Expand **Inspect JSON** for
   evidence. Catalog weights and thresholds are visible. Helper30 is distinct
   from final catalog-evaluated risk; the current dataset decides the result.
6. Trusted Branch100/low-velocity normal comparison is explicitly **previously
   verified evidence**, not a fake live normal fixture. No hidden direct financial
   INSERT is used to construct it. Location/time helpers are diagnostics only.
7. On Fraud Review filter status/risk, choose an Open flag and actual active
   Manager. Use UnderReview, then choose that flag again and Confirmed. Invalid
   transitions return the native error. The caller is still the administrative
   connection, not a simulated Manager login.
8. Run the safe5016 rollback probe on ACID with two different funded Active
   accounts and amount1. Expected5016 plus identical snapshots demonstrates
   rollback. Other native errors are displayed and do not count as proof.
9. Inspect live audit JSON and session USER(); explain the watermark and DBA limit.
10. Read labeled historical isolation/deadlock/retry and mixed performance results.
    Ordinary HTTP requests do not run those experiments or install indexes.
11. Show real installed FK relationships, DEFINER objects and trigger order under
    Database Architecture. Explain FOLLOWS audit and transactional fraud flags.
12. Explain RBAC limits, then use Project Verification → **Run six invariants now**.
    Historical SQL counts are overlapping and not automatically this live check.

## Finish and reset safely

Stop the web server with **Ctrl+C in its PowerShell window**, then:

```powershell
powershell -NoProfile -File demo/start_demo.ps1 -Action Stop -SessionFile demo/out/dashboard-session.json
```

Stop verifies all three ownership markers before dropping any schema and confirms
zero remaining names. No protected database is a target/helper. Never use the
legacy default rebuild commands to reset this demonstration. If cleanup reports
an ownership mismatch, investigate it; do not force a broad delete.

## Security and delivery status

The visible **NON-SECURITY DEMO** banner is intentional. The server authenticates
with the configured administrative client file; it has no role-switching illusion.
No users/roles/grants are provisioned. Fresh restricted-login certification needs
a separately approved scoped plan. CSRF, exact Origin/Host checks, escaped DOM
content, fixed endpoints and input validation protect this local demonstration;
they do not make it a production multi-user banking application.

Live data: MySQL. Previous experiments/performance: pinned successful evidence
run with source/date labels. If that evidence is not present in another checkout,
the UI says unavailable rather than generating invented values. Include the
referenced evidence folders when packaging the submission.

Academic report: [FINAL_PROJECT_REPORT.md](../docs/FINAL_PROJECT_REPORT.md).
Delivery/test evidence: [final-dashboard REPORT](../evidence/reviews/final-dashboard/REPORT.md).

## Focused tests (do not rerun the expensive suite unnecessarily)

```powershell
& $env:BANK_PYTHON_BIN -m unittest discover -s tests/dashboard -p 'test_*.py'
# Against a newly started owned dashboard:
& $env:BANK_PYTHON_BIN tests/dashboard/live_dashboard.py `
  --evidence-dir evidence/reviews/final-dashboard/new-http-run
# Optional browser QA only, if Playwright and installed Edge are already available:
node tests/dashboard/browser_smoke.cjs evidence/reviews/final-dashboard/new-browser-run
```

The application does not require Node or Playwright. Browser QA may use an
existing local tool environment; no bundled Codex path is a project prerequisite.
Use a new output folder for each test. After browser mutations run six invariants,
stop the server, and use the explicit ownership-checked Stop command.
