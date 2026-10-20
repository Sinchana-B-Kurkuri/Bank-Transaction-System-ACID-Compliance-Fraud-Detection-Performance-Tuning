# A+B merge conflict resolution — 2026-10-20

**Verdict: READY TO COMMIT MERGE**, subject to the user reviewing these staged resolutions. This is a merge-resolution verdict, not certification of deployed restricted-role privileges. No commit, push, branch switch or merge completion was performed.

## Exact revision and merge state

- Branch: `feature/A-integration-docs`.
- Existing HEAD: `690e26db983605b935bdb969bd94649e7ce29bf0`.
- Existing MERGE_HEAD and freshly fetched `origin/develop`: `f59c5205e83e3d4df69e72591ac231a2a8b8c91f`.
- The merge was already in progress when this task began. HEAD remains unchanged; MERGE_HEAD remains present.
- Five conflicted paths were reconciled by hunk, then staged. `git ls-files -u` is empty. The related test-discovery manifest correction is staged too. Existing unrelated staged incoming files were retained unchanged; see `index-preservation.txt`.
- Base/ours/theirs copies are preserved in `versions/`; initial status/index/parents are recorded alongside this report. Historical tracked and untracked evidence was not edited or removed.

## Conflicts and exact resolutions

| Path | Resolution |
|---|---|
| README.md | Combined A's build/test/experiment/runbook material with develop's safe PR9 verification instructions. Removed obsolete current claims that B's runtime was missing. Distinguished component availability, actor-map authorization tests, and pending deployed-role certification. Explained safe disposable runners, protected default targets, and Baseline versus explicit Optimized. |
| build/run_all.sql | Retained the complete real B tables, seven fraud functions, identity helpers, evaluator, rule seed, ordered fraud trigger and views. Retained A procedures, guards, audit installation, seeds and explicit baseline profile. No B performance indexes or RBAC grants are silently installed. |
| build/file_order.txt | Reconciled the complete dependency list with every active SOURCE in all three entry scripts. Corrected B ownership/mode annotations. Kept Standalone stubs mutually exclusive with real B tables; documented manual preview-only RBAC and explicit Optimized indexes. |
| docs/decisions.md | Retained both historical A status material and current PR9 decisions; labeled historical status rather than rewriting history. Preserved approved +20 untrusted/+10 digital scoring and transaction-local HIGH_ACCOUNT_RISK. Added current merge/test-scope clarification. |
| docs/interfaces.md | Preserved A's public signatures, generated-contract provenance, safe isolated context, private-routine rules, release and loader contracts; combined B runtime/identity/view/scoring/statement corrections. Removed obsolete present-tense missing-runtime claims. |
| tests/component_tests.csv | Added `tests/functions/04_fraud_spec_functions.sql,Integrated,B`. This newly merged real-B test must run in Integrated mode and must not run against Standalone, which intentionally has no B functions. No assertion was removed or weakened. |

No banking procedure, function, schema-table definition, audit/guard/fraud trigger, view, security implementation or B index definition was edited during resolution. Those runtime paths are byte-identical to MERGE_HEAD according to `git diff --name-only MERGE_HEAD -- functions procedures triggers schema/01_tables views security indexes`. Corrected ordered locking and approved authorization/scoring semantics are preserved.

## Final dependency order

1. Helper schema, A core tables 01–09, real B tables 10–16 (Standalone uses its separate stand-in file instead).
2. Core FKs, then conditional cross-module FKs.
3. A functions and B's seven fraud functions; B identity functions; legacy fraud helper after the scoring function it delegates to.
4. Actor resolver; internal A authorization/ledger/transfer helpers; public A routines and B fraud evaluator.
5. Six guards; nine audit triggers; audit installation watermark.
6. A reference seed, B fraud-rule seed; B AFTER INSERT fraud trigger **FOLLOWS trg_transactions_ai_audit**; tiny customer/account seed. Thus opening deposits exercise the real fraud path.
7. Three B views after their identity dependencies.
8. RBAC is a separate reviewed manual installer, preview-only by default. Actual role/user/grant deployment needs separate approval.
9. `run_all_optimized.sql` explicitly sources the baseline entry and then B's seven performance indexes. Baseline never includes them.

The actual order is recorded in `build/file_order.txt`. Static checks found 82 existing ordered Integrated SOURCE targets, 60 Standalone targets and two Optimized entry targets. Expanded object checks found no duplicate CREATE object names (79 Integrated/Optimized, 66 Standalone).

## Commands actually executed

Repository inspection included `git status`, `git ls-files -u/--stage`, HEAD/MERGE_HEAD/remote resolution, history, conflict-stage reads, source/test/script inspection and `git fetch origin develop`. Fetch was retried with filesystem approval after the initial FETCH_HEAD permission denial.

Native MySQL used the external `BANK_MYSQL_CNF` option file and `BANK_MYSQL_BIN` executable, including paths containing spaces. No credential content was copied into evidence or repository files.

```powershell
powershell -NoProfile -File tests/regression/pr9_acceptance.ps1
powershell -NoProfile -File tests/regression/error1222_seed.ps1
powershell -NoProfile -File evidence/reviews/A-B-merge-resolution/verify-isolated.ps1
```

The evidence-only isolated driver and its nested commands were inspected before execution. It created collision-checked `bank_a_ci_merge_26fc3f114d08_{main,scratch,lab}` schemas, configured the existing ownership-token context and executed:

```powershell
# $ownedMain and $ownedScratch are the above fresh owned names, never protected targets.
powershell -NoProfile -File build/release_strip_lab_hook.ps1
powershell -NoProfile -File build/rebuild.ps1 -Database $ownedMain -Mode Standalone -WithSeed -IndexProfile Baseline
powershell -NoProfile -File build/rebuild.ps1 -Database $ownedMain -Mode Integrated -WithSeed -IndexProfile Baseline
powershell -NoProfile -File tests/runtime_acceptance.ps1 -Database $ownedMain -Mode Integrated
powershell -NoProfile -File experiments/run_all_auto.ps1 -Database $ownedMain -Quick
powershell -NoProfile -File build/rebuild.ps1 -Database $ownedScratch -Mode Integrated -WithSeed -IndexProfile Optimized
```

For each mode it ran every numbered SQL test in schema/functions/triggers/procedures/invariants/integration, respecting the component manifest; used the existing constraint-fixture convention of temporarily suspending only the ledger UPDATE guard and restoring it in finally; and ran these vetted PS scripts:

- `tests/schema/{03_source_order,04_mysql_wrapper,05_isolated_context,06_quick_arguments}.ps1`.
- `tests/integration/07_real_b_schema.ps1`.
- `tests/procedures/{14_statement_resultsets,17_statement_after_interest}.ps1`.
- `tests/p6_static.ps1` with each mode's measured B0 snapshot.
- All six reconciliation invariants after each mode, after Quick and on Optimized.
- Three native EXPLAIN queries from `benchmarks/01_query_plan_comparison.sql`; no timing/throughput experiment.

Also executed source-marker and expanded duplicate-object scans, signature generation `-Check`, runtime-preservation diff checks, `git diff --check`, `git diff --cached --check`, and the scoped staged-file whitespace check. Only the six explicitly listed resolution/tooling files were git-added, after an initial index.lock permission denial and an approved retry. There was no merge --continue or commit.

## Actual results — locally tested

These populations overlap; do not add them into a unique-test total. Raw per-file counts and exit codes are preserved.

| Executed population | PASS | FAIL | Result |
|---|---:|---:|---|
| PR9 real Integrated numbered SQL suite | 688 | 0 | 0 SQL-error files; 0 files without TEST output |
| PR9 additional focused acceptance assertions | 58 | 0 | Includes native RBAC preview/prepare-only checks; restricted login tests explicitly pending |
| Independent ERROR 1222 tiny-seed regression | 25 | 0 | Real seed→open account→fraud trigger→evaluator path succeeds; cleanup succeeds |
| A actual Standalone build: numbered SQL assertions | 632 | 0 | Three Integrated-only B runtime files explicitly skipped, not counted as PASS |
| Standalone vetted PS/static/final-invariant assertions | 186 | 0 | Includes source order 144, wrapper 5 and final invariants 6 |
| A actual Integrated build: numbered SQL assertions | 688 | 0 | Real B tables/functions/triggers/views, not stubs |
| Integrated vetted PS/static/final-invariant assertions | 195 | 0 | Includes real-B-schema 10, source order 144, wrapper 5, final invariants 6 |
| Bounded Quick | 10 | 0 | Three real injected-rollback probes; two actual concurrent sessions; six invariants |
| Post-Quick invariants | 6 | 0 | Each has zero violations |
| Optimized invariants | 6 | 0 | Each has zero violations |
| Evidence-driver stage/cleanup checks | 98 | 0 | Aggregate stage checks, not an additional independent test population |
| Additional final static checks | 5 | 0 | Three duplicate inventories, markers, runtime preservation |

The generic runtime acceptance script exited **2**, not 0: `ACCEPTANCE_FAIL=0`, `MISSING_OR_BLOCKED=2`. Its fresh target intentionally had zero role grants, and its generic EXECUTE-contract check remained blocked. These were preserved as pending checks, not converted into completed security acceptance. The separate PR9 runner did verify actual RBAC installer preview compilation, repeatability, native PREPARE syntax, explicit public-only grants, installed DEFINER targets and unchanged privileges, without executing any grant.

### Functionality observed

- Schema constraints, FK/unique/check errors, all public A signatures and all seven B fraud signatures pass.
- Registration, opening deposits, deposits, withdrawals, both-direction ordered transfers, approvals, loans, review transitions, statements, interest idempotency, business failure rows and actual5016 atomic rollback pass existing real SQL tests.
- Automatic fraud evaluation and audit ordering work together; actual rollback preserves balances, ledger, audit, flags and risk total.
- Approved digital/untrusted scoring remains30; reevaluation stability and configured rule thresholds pass. Runtime repeated-score probe was85.00→85.00 with a stable profile indicator1.
- Customer owner-only statements/views, active employee branch scoping and inactive/foreign-account denial pass privileged actor-map probes. These are authorization-logic tests, not newly authenticated restricted-login proof.
- Baseline core index metadata has36 index-column records and only PK/UNIQUE/FK-required support; no optional indexes. Explicit Optimized installs exactly seven named B indexes. Three EXPLAIN SELECTs execute successfully; no performance claim is made.
- Quick executed two native concurrent sessions, five transfers each, yielding exactly20 completed ledger rows. It did not dispatch full experiments or modify historical evidence.

### Six invariants

| Invariant | Standalone baseline | Integrated baseline | After concurrent Quick | Optimized |
|---|---|---|---|---|
| I1 ledger/current balance | PASS / 0 | PASS / 0 | PASS / 0 | PASS / 0 |
| I1b balance_after chain | PASS / 0 | PASS / 0 | PASS / 0 | PASS / 0 |
| I2 paired transfers | PASS / 0 | PASS / 0 | PASS / 0 | PASS / 0 |
| I3 balance/minimum rules | PASS / 0 | PASS / 0 | PASS / 0 | PASS / 0 |
| I4 audit watermark coverage | PASS / 0 | PASS / 0 | PASS / 0 | PASS / 0 |
| I5 latest ledger balance | PASS / 0 | PASS / 0 | PASS / 0 | PASS / 0 |

## Evidence and cleanup

- This directory: `pr9-console.txt`, `seed-console.txt`, `isolated-console.txt`, `verify-isolated.ps1`, `final-static.txt`, `index-preservation.txt`, `versions/`.
- PR9 raw run: `evidence/reviews/PR9-final-fixes/20261020-182836-678-74b7ba427976448da9b3bd6055244914/`.
- Seed raw run: `evidence/error1222/20261020-182836-895-73a9f93646d94deab656f21c65cfb277/`.
- A mode/build/test output: `isolated-20261020-183227-512-750c8e7d557240c2b7ac9b8062cc8855/`, including `test-populations.csv`, per-file logs, B0 snapshots, invariant result sets, optimized-index inventory and EXPLAIN output.
- Concurrent Quick raw output: `evidence/quick/20261020-183414-255-d27d6ccd/`.
- Both independently generated PR9/1222 databases and all three A owned databases were owner-checked and removed; cleanup queries returned zero remaining schemas. No protected database was used as a target or helper schema. No global variables, users, roles or grants were changed.

## Remaining limitations and manual verification

1. **NEEDS MANUAL VERIFICATION / separate approval:** fresh authenticated customer/teller/manager/auditor privilege behavior. No new account/role deployment was authorized in this task. Existing historical restricted-login evidence is retained but not represented as a new test of this merge. Authorization logic and native RBAC preview passed; actual deployed grants remain uncertified here.
2. **Not run:** full nested regression scripts with fixed global test accounts, crash/restart, PITR, full concurrency/performance grids and runtime release-database procedure tests. Safe SQL coverage and vetted nested scripts were executed instead. Generated release sources passed static stripping checks only.
3. Whole staged `git diff --cached --check` reports eight existing whitespace warnings in incoming historical ERROR1222 evidence under `20261020-171559-210-...`. Those blobs already match MERGE_HEAD and were deliberately preserved. Scoped checks for all six changed resolution files pass. No runtime or merge-conflict failure remains.
4. This verified an uncommitted merge worktree, not a new merge commit. Review/stage any desired new report evidence, then commit the merge manually. Rerun after subsequent source changes.

## Deliverable status

| Deliverable | Status |
|---|---|
| Five conflicts reconciled and staged, no conflict markers/unmerged entries | IMPLEMENTED / LOCALLY TESTED |
| Mode-aware new B function test classification | IMPLEMENTED / LOCALLY TESTED |
| Real A+B SQL integration, seed, signatures, fraud, authorization logic, audit, rollback, B0/Optimized and invariants | LOCALLY TESTED |
| Fresh restricted-login privilege deployment | NEEDS MANUAL VERIFICATION / approval required |
| Historical evidence and unrelated staged incoming files | PRESERVED |
| Merge commit/push | NOT PERFORMED; user review required |