# Member A isolated integration tooling

Normal entry points retain their banking database defaults. To validate without touching either banking database, use the opt-in owner-scoped regression:

```powershell
$env:BANK_MYSQL_CNF = 'C:/path with spaces/private.cnf'
$env:BANK_MYSQL_BIN = 'C:/Program Files/MySQL/MySQL Server 8.4/bin/mysql.exe'
powershell -NoProfile -File tests/run_regression.ps1 -IsolatedPrefix bank_a_ci_unique_run -VerifyOptimized
```

Choose a fresh prefix matching `bank_a_ci_[a-z0-9_]{1,32}`. The runner refuses existing names, creates exactly `<prefix>_main`, `<prefix>_scratch`, and `<prefix>_lab`, records a random owner marker, and removes only its own marked databases in finally. Cleanup errors remain failures. Run sequentially: existing A restricted-login tests reserve fixed temporary usernames and refuse collisions rather than replacing them.

Children inherit BANK_TEST_ISOLATED_PREFIX, BANK_TEST_OWNER_TOKEN and BANK_TEST_EVIDENCE_DIR. mysql_common refuses protected database targets, rewrites bank_lab references after expanding SOURCE, and rejects protected names/global changes in the expanded SQL. The original helper schema/object files and banking procedures are unchanged. Scratch-only audit-toggle guards are mapped to the isolated scratch database, retaining the fraud-trigger dependency check. Nested destructive detector/release tests use that scratch target, never the development target. Evidence goes into a fresh timestamp/GUID regression directory; legacy evidence is not rewritten. These environment variables are an internal run context, not credentials; ordinarily let the top-level runner set and restore them.

The normal CLI mysql client does not perform this namespace mapping. Do not source expanded isolated test SQL with a banking default schema. Tests use Invoke-BankMysql; paths with spaces and original stderr remain supported.

## Test modes and acceptance

`tests/run_tests.ps1 -Mode Auto|Standalone|Integrated` defaults to Auto, detecting the installed real B schema by Account_Risk_Profile. An explicit mode must agree with the installed schema. `tests/component_tests.csv` lists B runtime-only tests omitted in Standalone; omissions emit SKIP, never PASS. Integrated executes them unchanged, including failures. Register future B component-only test files in this manifest; common interface/constraint tests still run in both modes.

`tests/runtime_acceptance.ps1` distinguishes installed routines/views, MISSING SPEC interfaces, failing behavior, and unverified restricted-role acceptance. Trigger order and real transfer rollback are tested independently of object presence. No global B roles are automatically installed: B's current script hardcodes bank_txn and cannot safely deploy isolated role grants. Its public EXECUTE omissions and prior review's role/view defects remain acceptance blockers. The top-level report exits nonzero on failures or missing/blocked acceptance work.

## Index profiles and Workbench

- Baseline is the default. `build/run_all.sql` and the Standalone entry install no B performance indexes. B0 validation independently checks FK-only support rather than trusting a newly captured snapshot alone.
- `build/rebuild.ps1 -Mode Integrated -IndexProfile Optimized` selects `build/run_all_optimized.sql`, which sources the baseline entry and then B's unchanged index file. Optimized is refused in Standalone. It records EV-INDEX-OPTIMIZED separately, never relabels it EV-B0.
- `-VerifyOptimized` in regression explicitly rebuilds its scratch target after release tests, checks the seven installed B indexes and invariants; no benchmark runs. Without the switch the release target is retained as before, unless isolated cleanup removes it.
- Workbench's ordered list includes mode/owner annotations. Run real B files only for Integrated, stubs only for Standalone. The CLI nested entry `build/run_all.sql` is an ordering entry, not another file to execute inside Workbench after installing all objects. For Optimized execute the B index file last; skip it for Baseline. CLI SOURCE includes are not Workbench SQL.

## Quick profile

```powershell
powershell -NoProfile -File experiments/run_all_auto.ps1 -Database <owned-isolated-main> -Quick
```

The regression invokes this with its inherited context. Quick requires two Active seeded accounts and development procedures. It performs three mode-1 atomicity probes and two concurrent native sessions with five opposite-direction mode-2 transfers each, then all six invariants. Sessions have short lock waits and a 45-second session deadline; timeout cleanup kills only connections opened by this driver. Quick has no rebuild/install/uninstall, service operation, global change, throughput, matrix generation, or legacy full-driver dispatch. It writes a fresh evidence/quick timestamp/GUID directory. It is a bounded integration smoke profile, not fresh certification of every EXP-01..10 anomaly demonstration. Unknown/incompatible arguments fail before dispatch; isolated aggregate execution without Quick is refused. Historical experiment evidence remains untouched.

Known B behavior failures are not fixed or waived by this tooling. See the PR7 review and current measured delivery report before claiming acceptance.
