# Prompt 4 delivery — 2026-10-18

Branch: `feature/A-concurrency-lab`; HEAD unchanged at `4f7855a`. No commit, push, merge, branch creation or branch switch was performed.

IMPLEMENTED and LOCALLY TESTED with real native MySQL sessions on MySQL 8.4.11 and Windows PowerShell. Baseline regression: **707 PASS / 0 FAIL**. Final complete regression: **731 PASS / 0 FAIL** (24 new checks: 18 EXP-02 rejections and six reconciliation checks). The final explicit Standalone -WithSeed rebuild completed in **4.34 seconds**.

The ordered-locking prevention hypothesis was **not met**: the final isolated comparison measured nine deadlocks in mode 2. All 100 mode-2 calls eventually succeeded through retries and every invariant passed. This is a retained concurrency finding, not a claim of deadlock-free operation.

## Files created / changed

- `experiments/README.md`: EXP-01..17 index, owners, execution and evidence rules.
- `experiments/_template/`: README, runnable setup/session A/session B/teardown SQL, unmeasured results template.
- `experiments/lib/Common.ps1`: UTF-8 MySQL invocation, quoted Windows paths, independent hidden processes, live connection-ID capture, bounded waits and owned-connection cleanup, evidence helpers.
- `experiments/lib/Run-Experiment.ps1`: shared measured schedules for EXP-01/04/05/06/07/09.
- `experiments/lib/MySqlSlapConnection.ps1`: in-memory option-file compatibility adapter; passwords only in the child process environment.
- `experiments/lab_objects/`: install/uninstall and 100 idempotent LAB accounts, each with a 1,000,000.00 opening Deposit; unsafe and atomic transfers, random/stress/retry/atomicity helpers.
- Nine `experiments/EXP-*/` folders: README, setup, session A/B, teardown, measured RESULTS, native drivers; EXP-08 has matrix and throughput drivers.
- `experiments/run_all_auto.ps1`: ordered orchestration, failure capture, summary, cleanup and evidence-validated `-ResumeThroughput`.
- `tests/integration/03_exp02.sql` and `04_after_experiments.sql`: regression integration.
- `build/mysql_common.ps1`: one-line extension honoring BANK_MYSQL_BIN; original fallback behavior retained. A real override using the executable path with spaces was tested in `evidence/EV-P4-CLIENT-OVERRIDE.txt`.
- `docs/member-a/PROMPT4_DELIVERY.md` (this report), measured evidence and a complete file manifest in `evidence/EV-P4-FILES.txt`.

No schema, function, procedure, trigger, SPEC, public-interface, or Member B source file was changed. Existing regression tests regenerate some historic Prompt 3 evidence; new outputs were copied to `evidence/p4-regression-derived/`, then the original tracked evidence was restored from HEAD. Requests to B: **none**.

## Commands run and actual results

All ordinary mysql invocations used BANK_MYSQL_CNF pointing to the user-provided existing option file; no credential file was copied or created.

| Command | Actual result / evidence |
|---|---|
| `powershell -NoProfile -File tests/run_tests.ps1 -Database bank_txn` before changes | 707 PASS, 0 FAIL; `evidence/p4-baseline.txt` |
| `powershell -NoProfile -File experiments/run_all_auto.ps1` | All SQL/isolation/stress/deadlock schedules completed; stopped cleanly when the first Quick hardware query was denied. Original failure retained in `EV-P4-AUTO-initial-failure.txt`. |
| `powershell -NoProfile -File experiments/run_all_auto.ps1 -ResumeThroughput` | Verified nine prior completed runs, regenerated matrix, ran Quick successfully, uninstalled lab objects; `EV-P4-AUTO-resume.txt`. |
| Individual `run_auto.ps1` drivers for EXP-01/02/04/05/06/07/10 | Executed against rebuilt seeded databases, primarily bank_txn_scratch; independent native session SQL/stdout/stderr retained. |
| `powershell -NoProfile -File experiments/EXP-09_stress/run_stress.ps1 -Parallel 20` and `-Parallel 50` | Real 20/50-session runs, 50 iterations each; 1,000/2,500 successful transfers, zero worker errors. |
| `powershell -NoProfile -File experiments/EXP-08_isolation_matrix/build_matrix.ps1` | 16 measured anomaly cells; RR/phantom and SERIALIZABLE blocking differences flagged. |
| `powershell -NoProfile -File experiments/EXP-08_isolation_matrix/run_throughput.ps1 -Quick` | Four settings, 500 queries each, one iteration; successful actual calls and metrics retained. |
| `powershell -NoProfile -File experiments/EXP-08_isolation_matrix/run_throughput.ps1 -Queries 200` | Full 16-setting grid, three iterations; 9,600 successful transfers; `EV-EXP08-Full-throughput.csv`. |
| `powershell -NoProfile -File build/rebuild.ps1 -Database bank_txn -Mode Standalone -WithSeed` | Exit 0, 4.34 seconds; `EV-P4-REBUILD.txt`. |
| `powershell -NoProfile -File tests/run_tests.ps1 -Database bank_txn` after implementation | **731 PASS, 0 FAIL**; `EV-P4-REGRESSION.txt`, `evidence/test-runs/20261018-220849-430.txt`. |
| Final EXP-10 and EXP-01 repeats after driver hardening | Genuine 1213/1205, retry counts and prevention finding; 200 injected failures with zero partial transfers; `EV-EXP10-final-driver.txt`, `EV-EXP01-final-driver.txt`. |
| Lab uninstall, routine inventory, probe-marker query, globals and reconciliation | Zero lab routines in both databases, zero temporary probe markers, globals restored, six invariants PASS; `EV-P4-FINAL-CLEANUP.txt`, `EV-P4-FINAL-INVARIANTS.txt`. |

Earlier invalid captures were retained and explicitly rejected: EXP-04's scalar-string parsing bug and an overlapping EXP-10/global-counter capture have INVALID.md records. The matrix uses completed corrected data, not those captures.

## Per-experiment status and observations

| Experiment | Deliverable status | Actual observation |
|---|---|---|
| EXP-01 atomicity | LOCALLY TESTED | 200 injected mode-1 failures, **0 partial transfers**; the driver confirmed connection 5405 was in User sleep, then KILLed only that owned connection. Per-account balances, total balance and transaction count unchanged. Before/after Experiment_Log entries and six invariant PASS rows retained. |
| EXP-02 consistency | LOCALLY TESTED | **18 PASS / 0 FAIL**; expected errno and actual errno/message table in `EV-EXP02-1.md`. |
| EXP-04 lost update | LOCALLY TESTED | Naive RU/RC/RR: both debits committed, expected 999700.00, actual 999800.00. SERIALIZABLE aborted one writer (1213), actual 999900.00 matched surviving debit. Both fixes preserved 999700.00 under actual contention; native lock waits were captured. Unsafe cases were discarded by rebuild; fixed cases and final rebuilt state reconciled. |
| EXP-05 dirty read | LOCALLY TESTED | RU observed 1001000.00 before rollback; RC/RR observed 1000000.00; SERIALIZABLE reader returned 1205. |
| EXP-06 nonrepeatable read | LOCALLY TESTED | RU/RC changed; RR stable; SERIALIZABLE blocked the competing deposit until 1205. |
| EXP-07 phantom read | LOCALLY TESTED | RU/RC count changed. RR plain count stayed **3**, locking current read saw **4**. Gap case captured `X,GAP,INSERT_INTENTION WAITING` on baseline FK index `fk_transactions_account_id`; writer returned 1205. SERIALIZABLE blocked insertion. |
| EXP-08 matrix | LOCALLY TESTED | Full four-level × four-anomaly measured matrix in `EV-EXP08-matrix.md`; differences explicitly flagged. |
| EXP-08 throughput | LOCALLY TESTED; client timing needs verification | Quick and full grids executed with real mysqlslap clients; wall-based rates and server mean CALL latency measured. Native reported batch timings disagree with UTC/Stopwatch duration and remain flagged rather than treated as verified per-call latency. |
| EXP-09 stress | LOCALLY TESTED | 20 workers: 1,000/1,000 successes in 5.812 seconds. 50 workers: 2,500/2,500 in 12.022 seconds. Zero worker errors; all six invariants PASS in both runs. |
| EXP-10 create/detect/contrast/handle | LOCALLY TESTED; error-log excerpt NEEDS MANUAL VERIFICATION | Genuine native 1213 and separate 1205 captured. Final naive mode: 54 deadlocks, 54 committed retry rows, 97/100 successes, three exhausted calls. Ordered mode: nine deadlocks/retry rows, 100/100 successes, no exhaustion. Invariants PASS. |
| EXP-10 prevention target | MEASURED — TARGET NOT MET; source correction BLOCKED by allowed-path scope | Ordered locking reduced this run's deadlock count but did not eliminate it. Graph retained in the final run's `mode-2-innodb-status.txt`. |

A successful driver exit means the measurement completed and required consistency assertions passed; it does not turn a disproved hypothesis into a PASS.

### Stress counts

Raw `before.txt` / `after.txt` order is Completed rows, Failed rows, global lock_deadlocks, database-scoped committed retry rows.

| Parallel sessions | Completed before → after | Failed before → after | Deadlocks delta | Retry rows delta |
|---|---:|---:|---:|---:|
| 20 | 121 → 2121 | 0 → 0 | 0 | 0 |
| 50 | 121 → 5121 | 0 → 0 | 0 | 0 |

### Full throughput grid

CPU/RAM were actually read via an authorized Get-CimInstance call: Intel Core Ultra 5 125H, 14 cores, 18 logical processors, 16,568,156,160 bytes RAM. The same-day measured JSON and its timestamp are retained. Ordinary sandbox CIM calls were denied; the driver can consume the authorized same-day record without requiring repeated privileged reads.

Three iterations × 200 requested queries per setting. Rates use native-process UTC wall duration, cross-checked with Stopwatch. Mean server CALL time uses before/after performance_schema digest COUNT_STAR and SUM_TIMER_WAIT deltas; sample counts are retained in CSV. The native mysqlslap-reported mean batch time is also retained separately and flagged where inconsistent.

| Isolation | Clients | Successful transfers | Transfers/sec | Deadlocks | Retry rows | Server mean CALL ms |
|---|---:|---:|---:|---:|---:|---:|
| READ-UNCOMMITTED | 5 | 600 | 473.33 | 3 | 3 | 7.321 |
| READ-UNCOMMITTED | 10 | 600 | 456.03 | 11 | 11 | 14.617 |
| READ-UNCOMMITTED | 25 | 600 | 227.51 | 47 | 47 | 60.985 |
| READ-UNCOMMITTED | 50 | 600 | 201.58 | 76 | 76 | 90.524 |
| READ-COMMITTED | 5 | 600 | 461.90 | 4 | 4 | 6.784 |
| READ-COMMITTED | 10 | 600 | 444.19 | 13 | 13 | 11.048 |
| READ-COMMITTED | 25 | 600 | 299.38 | 62 | 62 | 55.896 |
| READ-COMMITTED | 50 | 600 | 226.81 | 100 | 100 | 112.645 |
| REPEATABLE-READ | 5 | 600 | 598.65 | 4 | 4 | 5.268 |
| REPEATABLE-READ | 10 | 600 | 377.36 | 14 | 14 | 13.931 |
| REPEATABLE-READ | 25 | 600 | 362.26 | 48 | 48 | 36.859 |
| REPEATABLE-READ | 50 | 600 | 232.19 | 127 | 127 | 116.746 |
| SERIALIZABLE | 5 | 600 | 495.96 | 5 | 5 | 7.031 |
| SERIALIZABLE | 10 | 600 | 553.42 | 11 | 11 | 10.974 |
| SERIALIZABLE | 25 | 600 | 300.98 | 35 | 35 | 33.563 |
| SERIALIZABLE | 50 | 600 | 187.23 | 96 | 96 | 110.341 |

Total: **9,600 successful transfers**, 656 measured deadlocks recovered by retry; observed wall-based throughput range **187.23–598.65 transfers/sec**. These are local workload measurements, not portable performance guarantees. Hardware/config, raw client outputs and before/after counters: `evidence/raw/EXP-08/20261018-220704-145/`. Latest resumed Quick run: `evidence/raw/EXP-08/20261018-220831-714/`.

## Reproduction details and remaining blockers

1. **Temporary deadlock scheduling probe — disclosed and removed.** Original mode 3 sleeps after both account locks. To reproducibly create the requested cycle, EXP-10 temporarily adds a mode-3-only pause immediately after the first lock in the database object sp_internal_post_transfer, never its source file. CREATE uses three seconds; HANDLE uses 0.05 seconds. Original DDL is restored in finally, independently of global-variable restoration. Native 1213 and InnoDB graphs are required; no error is fabricated with SIGNAL for the CREATE result.
2. **Ordered-mode finding — BLOCKED source correction.** The retained graph includes one transaction holding an exclusive lock on LAB-0001 while waiting for LAB-0002, and another holding a shared lookup lock on LAB-0002 while waiting for LAB-0001. The pre-lock existence lookups are the primary code-review suspect; that statement-level attribution is an inference from the graph and source. Correcting the shipping routine requires reviewing `procedures/sp_internal_post_transfer.sql`, outside Prompt 4 standing rule 2's allowed paths. No procedure source was changed. A future authorized correction must rerun the concurrency comparison and complete regression. This is an A finding; no B request is needed.
3. **Server error-log excerpt — NEEDS MANUAL VERIFICATION.** performance_schema.error_log returned no matching deadlock entries. Reading `C:\ProgramData\MySQL\MySQL Server 8.4\Data\LAPTOP-TEKJAJEQ.err` was denied in both normal and elevated-tool attempts. Raw reasons, native victim error, lock snapshots and InnoDB graphs were retained. In an Administrator PowerShell with log access, rerun EXP-10 and retain the error-log excerpt. Do not alter service state.
4. **Native mysqlslap timing discrepancy — NEEDS MANUAL VERIFICATION if relying on its reported latency.** Both UTC wall time and Stopwatch agree, but mysqlslap's reported average duration can exceed the whole process duration. CSV timing_note flags this. Wall-based throughput and independently measured server mean CALL times remain available.
5. Screenshots are optional manual supplements. Every experiment README gives two-window offsets and instructions to keep version, timestamps and connection IDs visible.
6. All builds/measurements used Standalone B interface stand-ins. Real B source, security and fraud behavior were not changed or claimed to be benchmarked.

The mysqlslap compatibility failure was fixed without writing credentials: mysqlslap 8.4 rejected the shared option-file default-character-set setting. The native my_print_defaults helper resolves connection settings only in memory; mysqlslap runs with --no-defaults and supported options, with its password only in the child ProcessStartInfo environment. No resolved credential output is logged.

## Final cleanup and ownership

```text
LAB_ROUTINES|bank_txn|0
LAB_ROUTINES|bank_txn_scratch|0
PROBE_MARKERS|0
8.4.11	2026-10-18 22:21:34.844263	REPEATABLE-READ	0	NULL
lock_deadlocks	enabled
```

The globals match the measured baseline: transaction_isolation REPEATABLE-READ, innodb_print_all_deadlocks 0, innodb_monitor_enable NULL, lock_deadlocks metric enabled. No mysqld process or service was stopped, and no OS process was killed. Only the script-owned MySQL connection was KILLed.

Original schema/functions/procedures/triggers/interfaces and all B files remain untouched. The only tracked source edit is the BANK_MYSQL_BIN override in build/mysql_common.ps1. Complete new/changed file inventory and static ownership verification are saved in `EV-P4-FILES.txt` and `EV-P4-OWNERSHIP.txt`.

## Raw run index

| Run | Raw path |
|---|---|
| EXP-01 | `evidence/raw/EXP-01/20261018-221911-398/` |
| EXP-02 | `evidence/raw/EXP-02/20261018-215031-324/` |
| EXP-04 | `evidence/raw/EXP-04/20261018-215039-090/` |
| EXP-05 | `evidence/raw/EXP-05/20261018-215342-152/` |
| EXP-06 | `evidence/raw/EXP-06/20261018-215431-512/` |
| EXP-07 | `evidence/raw/EXP-07/20261018-215504-624/` |
| EXP-10 | `evidence/raw/EXP-10/20261018-221245-928/` |
| EXP-09 / 20 sessions | `evidence/raw/EXP-09/20261018-215543-477/` |
| EXP-09 / 50 sessions | `evidence/raw/EXP-09/20261018-215557-946/` |

## Completion checklist

- [x] Nine experiment folders, manual sessions, setup/teardown and measured results.
- [x] Real independent sessions, raw stdout/stderr, version/time/connection IDs.
- [x] Measured matrix and flagged textbook differences.
- [x] Quick and full throughput grids, hardware/config sheet, before/after counters.
- [x] Genuine deadlock create/detect/contrast/retry captures and ordered-mode comparison.
- [x] Invariants after EXP-01/04/09/10 and final regression: all six PASS.
- [x] Lab routines and temporary probe removed; globals restored.
- [x] No B file modified; no credentials or dumps added.
- [ ] Zero-deadlock ordered-mode prevention hypothesis: **not achieved**; retained finding.
- [ ] Administrator server error-log excerpt: **manual verification required**.
- [ ] Native mysqlslap reported latency consistency: **manual verification required**; independent measurements supplied.
