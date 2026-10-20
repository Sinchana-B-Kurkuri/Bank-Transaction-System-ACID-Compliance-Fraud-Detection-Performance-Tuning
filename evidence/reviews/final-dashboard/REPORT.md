# Final banking dashboard delivery — 20 October 2026

**DASHBOARD READY / REPORT READY**

The localhost dashboard was actually launched against a new owned MySQL database,
tested through HTTP and installed Edge, and shut down. All three owned schemas
were removed after final reconciliation. The substantial academic Markdown report
is complete; optional DOCX conversion is deferred, not falsely claimed.

## Revision and preservation

- Branch: `feature/final-demo`.
- Exact HEAD: `8298f855f2020f01a518eaa53425fa66af629962`.
- Delivery additions remain uncommitted on that branch. No commit, push, merge,
  branch switch, reset/clean or PR creation was performed.
- Existing CLI/lifecycle work and historical untracked evidence were preserved.
- `git diff --name-only -- functions procedures triggers views security indexes
  schema build` returned no changes. Production banking/fraud/security SQL,
  corrected ordered locks, public signatures, audit behavior and approved scoring
  were not modified.
- Protected bank_txn, bank_txn_scratch and bank_lab were not used as targets or
  helpers. No global MySQL setting/user/role/grant/password/service change occurred.
  No crash/restart/PITR or long performance experiment was run.

## Architecture and scope actually implemented

Flask was absent. The expressly permitted standard-library HTTP fallback avoids
pip installation and external dependencies. HTML/CSS/vanilla JavaScript and
offline CSS bar charts provide the preferred navy/light-gray/blue/teal appearance;
Bootstrap/Chart.js CDN assets are not required. There is no Node build pipeline.
Node/Playwright were used only for optional automated browser QA.

The server binds **127.0.0.1:5000**, with no debug/reloader. It validates the active
demo session name/status/owner token and checks the real database marker before
serving. It reuses bank_cli.py's native MySQL adapter and parser. All financial
mutations call existing public procedures; there is no direct financial-table DML.
No browser input can select a database, SQL statement, shell command or cleanup
operation. Start/Stop remain explicit PowerShell commands.

Security boundaries include exact Host/Origin validation, an in-memory random
CSRF token and POST/JSON for operations, a16KB body limit, argument validation,
safe hex text literals, escaped DOM content, a strict static-file allowlist,
frame denial, no-store/nosniff headers and CSP. The visible NON-SECURITY DEMO banner
correctly identifies the privileged administrative connection. These measures
are local application safeguards, not fresh least-privilege role certification.

## Files added/modified for this delivery

| Path | Purpose |
|---|---|
| demo/dashboard.py | Fixed HTTP API, validated owned session, native SQL adapter, real metadata/effects/invariants, historical evidence loader |
| demo/start_dashboard.ps1 | Windows foreground launcher; rejects cleaned/invalid sessions; configurable local port |
| demo/web/index.html | Coherent application shell, persistent warning, guide/result panels |
| demo/web/style.css | Offline responsive layout, navy sidebar, cards/tables/charts/badges |
| demo/web/app.js | Twelve views, forms, actual-ID propagation, guided flow, live/captured result presentation |
| demo/DASHBOARD_GUIDE.md | Exact startup/stop, professor script, safety, evidence packaging and focused tests |
| demo/README.md | Added dashboard entry; CLI instructions retained |
| README.md | Added dashboard and academic-report links; existing A/B content retained |
| tests/dashboard/test_dashboard.py | Nine fast HTTP/session/input-boundary tests |
| tests/dashboard/live_dashboard.py |32-check real HTTP/MySQL workflow; no independent SQL interface |
| tests/dashboard/browser_smoke.cjs | Installed Edge navigation/form/mobile/XSS-escape checks and actual screenshots |
| docs/FINAL_PROJECT_REPORT.md | Complete30-section academic Markdown report, approximately5083 words, actual screenshots/references/commands/limitations |
| evidence/reviews/final-dashboard/ | New test artifacts, actual screenshots, invariant/cleanup records and this report |

Earlier CLI additions remain in the worktree; this list identifies the dashboard
extension rather than attributing every pre-existing untracked file to this task.

## Features actually exercised

- **Overview:** live customer/account counts, Active/Frozen totals, Completed
  transactions, flags/open cases, total balance, activity, profile risk and type
  distributions. Charts are driven by MySQL rows, not seeded display constants.
- **Customers/Accounts:** real registration and opening forms; example.invalid and
  SYN- validation; actual returned customer/account IDs propagate to later forms.
- **Banking:** deposit, withdrawal, transfer, history and statements. The result
  panel shows actual native output, before/after balances and effect counts.
  Native business errors remain visible; D4 Failed rows are explicitly explained.
- **Fraud:** actual latest matched-rule scores/levels, transaction data, catalog
  parameters/weights, account profile and expandable JSON. Online6000 performs a
  real public deposit; the UI shows observed values rather than assuming100.
  Normal trusted-device comparison and stable reevaluation are clearly captured
  prior evidence, avoiding hidden fixture DML.
- **Review:** live flag queue, status/risk filters and real UnderReview/Confirmed/
  Dismissed procedure calls, labeled as administrative walkthrough actions.
- **ACID:** bounded existing transfer mode1; expected5016 and full before/after
  equality are required for the rollback result. Live six-invariant action.
- **Concurrency:** prior native four-level reader results, actual1213/1205,
  scheduling-probe explanation, retry log and post-experiment invariants; no HTTP
  endpoint launches a stress workload.
- **Audit:** actual session USER(), operation/entity/time and expandable old/new
  JSON with watermark and DBA-tampering limits.
- **Performance:** six actual CSV groups, grouped bars, sample counts, row counts,
  environment/hardware, before/after EXPLAIN and current live index inventory.
  Captured Optimized evidence is distinct from the current Baseline demo DB.
- **Security/Architecture:** source-grounded permission matrix and live identity;
  actual installed sixteen tables, FK edges, routines, three views, triggers/order,
  indexes and durability settings. No role-switching login illusion.
- **Verification/Guide:** historical counts loaded from evidence rather than
  assigned as live results; current reconciliation; twelve-step Previous/Next
  professor flow with sensible seeded/returned selections.

Approved helper untrusted+20/digital+10 and transaction-local HIGH_ACCOUNT_RISK
remain unchanged. Helper30 versus catalog-evaluated risk is explicitly explained.
No unsupported automatic location/time-anomaly signal was added.

## Commands actually executed

Repository/source/report inspection and branch/status checks preceded coding.
Local dependency inspection found Python3.12.14, native MySQL8.4.11 and no Flask.
Syntax/import and JavaScript checks preceded live tests:

```powershell
& $env:BANK_PYTHON_BIN -m py_compile demo/dashboard.py tests/dashboard/live_dashboard.py
node --check demo/web/app.js
& $env:BANK_PYTHON_BIN -m unittest discover -s tests/dashboard -p 'test_*.py'
powershell -NoProfile -File demo/start_demo.ps1 -SessionFile demo/out/dashboard-verification-20261020.json
powershell -NoProfile -File demo/start_dashboard.ps1 -SessionFile demo/out/dashboard-verification-20261020.json
& $env:BANK_PYTHON_BIN tests/dashboard/live_dashboard.py --evidence-dir evidence/reviews/final-dashboard/http-workflow-20261020-1
node tests/dashboard/browser_smoke.cjs evidence/reviews/final-dashboard/browser-20261020-1
node tests/dashboard/browser_smoke.cjs evidence/reviews/final-dashboard/browser-20261020-2
```

Browser QA used the existing Playwright package through NODE_PATH and installed
Microsoft Edge. The in-app browser failed to initialize, and the downloaded
Playwright Chromium executable was absent. No browser/package was downloaded;
installed Edge was available. All reported captures are from that real browser.

After all browser mutations: stopped **only the local dashboard** via Ctrl+C;
ownership-checked final reconciliation through the existing isolated wrapper;
explicit `start_demo.ps1 -Action Stop` for the exact session; queried the exact
three generated schema names and found zero. Finally executed the launcher with
the cleaned record and confirmed native exit1/refusal before database access.
No MySQL server process was stopped.

## Actual outcomes

Populations overlap; do not sum them into a unique-test total.

| Test population | PASS | FAIL | Evidence |
|---|---:|---:|---|
| Dashboard HTTP/session safety units | 9 | 0 | unit-results.txt |
| Real native-MySQL HTTP workflow | 32 | 0 | http-workflow-20261020-1/results.json |
| Initial Edge visual/navigation workflow | 20 | 0 | browser-20261020-1/results.json |
| Extended Edge registration/opening/ID workflow | 23 | 0 | browser-20261020-2/results.json |
| Final six invariants after browser mutations | 6 | 0 | final-invariants.txt |
| Actual cleaned-session launcher refusal | 1 | 0 | cleaned-session-refusal.txt; expected native exit1 |
| Owned schema cleanup | 3 | 0 | cleanup.txt, remaining=0 |

The live HTTP runner opened20000, deposited100, withdrew25 and transferred50,
asserting20025.00. Actual statement output included that running balance. Invalid
fractional money was rejected before SQL; an excessive withdrawal returned native
5004 with HTTP422. An Online6000 deposit generated real flags with observed score100.
An actual flag moved UnderReview→Confirmed through the public procedure.
The5016 rollback returned identical balance/ledger/audit/flag/risk snapshots.
Metadata showed sixteen real A+B tables, three views and audit-before-fraud order.

Edge then exercised actual HTML forms, not just API calls: registration, opening
and customer/account ID propagation; deposit; guide navigation; all twelve views;
six live invariant rows; stored markup escaped as literal text; mobile width390
without horizontal page overflow. There were **zero uncaught JavaScript errors**.
The later risk-classification label/JSON-detail presentation changes passed the
final JavaScript syntax check; no database policy changed.

### Final six invariant results

| Invariant | Violations | Status |
|---|---:|---|
| I1 ledger/current balance | 0 | PASS |
| I1b balance_after chain | 0 | PASS |
| I2 paired transfers | 0 | PASS |
| I3 minimum/nonnegative/closed balance | 0 | PASS |
| I4 watermark-aware audit completeness | 0 | PASS |
| I5 newest Completed balance_after | 0 | PASS |

Prior632/688 SQL,41 CLI and25 ERROR1222 passes are preserved and explicitly
historical in the UI/report. The expensive full suite was not rerun for unchanged
production SQL. This delivery does not imply new restricted-login certification.

## Screenshots and visual review

Actual PNG captures are under `browser-20261020-2/`:

- 01-overview.png
- banking-operation.png
- fraud.png
- audit.png
- performance.png
- architecture.png
- verification.png
- mobile-overview.png

The live overview screenshot was visually inspected. It shows real DB statistics,
the warning/identity, twelve-section sidebar, navy/blue/teal design, actual charts
and recent ledger. Screenshots are embedded in the academic report, with exact
recapture instructions. No invented screenshot or generated mockup is included.

## Performance and security limits retained

Historical timing means (µs): recent activity759.35→1226.40; fraud queue
926.05→1159.10; approvals827.00→673.30. Each query/profile had20 samples and2 warmups
on10 Accounts/39 Transactions/132 flags/1 approval. Charts state mixed results,
tiny data, warm cache, profile order and protocol overhead; no general speedup
claim. No indexes were installed by HTTP, and no new performance grid was run.

Customer ownership/staff branch rules remain in the database. This dashboard uses
privileged administrative access and does not impersonate a Manager by selecting
an employee ID. No new users/roles/grants were authorized or created. Fresh native
restricted-login certification remains pending a separately approved plan.
Auditor/Manager view/grant limitations are explained instead of broadened.

## Known limitations / optional work

- Complete Markdown report is delivered. Optional DOCX conversion is deferred;
  fill institutional/student title placeholders before submission.
- The app is loopback-only, single administrative walkthrough, not a production
  authenticated banking website. Standard-library HTTP is not public deployment.
- No fresh restricted-login, crash/restart/PITR or full performance experiment.
- Normal trusted-device and reevaluation comparisons use labeled existing
  evidence; no new hidden direct financial fixture writes were added.
- Recent transaction/flag/audit tables have display caps; overview totals are
  actual uncapped aggregate queries. Historical evidence must accompany the
  packaged checkout; absent files are labeled unavailable.
- Ordinary HTTP actions are serialized. Real concurrency evidence is from prior
  native sessions, not simultaneous dashboard requests.

## Exact startup and stop instructions

Set BANK_MYSQL_CNF to an external private option file, BANK_MYSQL_BIN to native
mysql, BANK_PYTHON_BIN to a local Python3.10+ executable and PYTHONUTF8=1. No
Codex-specific executable path is required by project source.

```powershell
powershell -NoProfile -File demo/start_demo.ps1 -SessionFile demo/out/dashboard-session.json
powershell -NoProfile -File demo/start_dashboard.ps1 -SessionFile demo/out/dashboard-session.json
# Open http://127.0.0.1:5000
# When finished, Ctrl+C stops the dashboard process only; then:
powershell -NoProfile -File demo/start_demo.ps1 -Action Stop -SessionFile demo/out/dashboard-session.json
```

Use a fresh session filename for another run; never overwrite/adopt an existing
database. The test session `dashboard-verification-20261020.json` is now cleaned
and correctly refuses startup. The documented default dashboard-session.json is
available for the evaluator's fresh start. Detailed professor instructions are
in `demo/DASHBOARD_GUIDE.md`.

## Cleanup and final state

Owned target `bank_a_ci_demo_095d068cb3cf_main` and its matching scratch/lab names
were owner-checked and dropped. Exact-name metadata query returned0. The web server
and test browsers are stopped; nothing is left running intentionally. Historical
evidence and all production SQL are preserved. Worktree changes remain for review.
