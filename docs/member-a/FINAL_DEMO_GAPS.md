# Final demo gap analysis

Inspected on 2026-10-20 at 8298f855f2020f01a518eaa53425fa66af629962,
branch feature/final-demo. PR9 and PR11 are present in history.

- Implemented: integrated sixteen-table schema, banking public APIs, ordered
  locking/retry, nine audit triggers, guards, real fraud evaluation and five rule
  seeds, seven fraud functions, identity-filtered views, preview-first RBAC,
  B0/explicit Optimized profiles, safe owned-database regression and bounded Quick.
- Missing: a runnable user-facing application and a reusable demo lifecycle.
  Add a standard-library Python CLI using native mysql and existing public APIs;
  add a PowerShell ownership-checked launcher and executable walkthrough tests.
- Security limit: no newly authorized restricted accounts. Default administrative
  demonstration must say NON-SECURITY DEMO. Restricted mode must use actual
  authenticated grants/USER()/CURRENT_ROLE(), not an assumed menu identity.
- Existing interface limits: customer summary filters customers only (manager
  SELECT does not turn it into an all-account view); staff activity is branch
  filtered; auditor has no mutation APIs and no statement EXECUTE. Display these
  limits rather than extending privileges. Teller account summaries can be
  derived only from visible completed activity.
- Fraud limits: active rules cover amount, device trust, digital channel,
  transaction-local accumulated risk and velocity. Distance/odd-hour helpers
  exist, but there are no active location/time-change rules. Do not invent them.
  The approved helper probe is30; evaluator adds matched catalog weights, so its
  final per-rule/profile scores are a distinct quantity.
- Performance: existing tiny data supports plan/latency smoke measurements only,
  not claims of production speedup. Measure unchanged query shapes before/after
  the existing seven indexes; retain all samples and environment.
- Recovery/crash and full performance grids remain outside this safe task.
  Existing historical evidence will not be rewritten. No production SQL policy,
  table, routine, guard, audit trigger or index definition needs replacement.
