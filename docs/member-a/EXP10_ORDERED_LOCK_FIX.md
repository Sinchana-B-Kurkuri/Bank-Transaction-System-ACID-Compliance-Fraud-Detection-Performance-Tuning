# EXP-10 ordered-lock correction

IMPLEMENTED / LOCALLY TESTED on MySQL 8.4.11, branch feature/A-concurrency-lab. The user explicitly authorized this follow-up correction to Member A procedure files. No B files, public signatures, transaction boundaries or business rules were changed.

## Root cause established from actual locks

The original nine-deadlock run is retained in evidence/raw/EXP-10/20261018-221245-928/. In mode-2-innodb-status.txt, both transactions hold S locks on Accounts PRIMARY records 9 and 10, and both wait to acquire X on record 9 at the first ordered FOR UPDATE. Each transaction's S lock prevents the other's upgrade: an S-to-X conversion cycle. LEAST/GREATEST ordering began too late.

The preliminary NOT EXISTS account expressions in sp_internal_post_transfer acquired those S locks on this measured server. They accessed accounts before the canonical exclusive-lock sequence. Sorting only the later X reads, or merely reordering two preliminary shared reads, cannot prevent this conversion cycle.

A controlled diagnostic paused the archived-original and corrected helpers immediately BEFORE the first exclusive read:
- Original: PRIMARY record 9 and record 10 both S,REC_NOT_GAP GRANTED.
- Corrected: no Accounts record locks at that point; shared-record count zero.

The probe uses an actual sleeping transaction and performance_schema.data_locks filtered by its connection/thread ID. It does not manufacture errors. Raw SQL, native session outputs, state and locks: evidence/raw/EXP-10-lock-diagnosis/20261018-223254-712/. Shipping DDL is restored in finally.

## Exact correction

Only procedures/sp_internal_post_transfer.sql changes runtime business code:
1. Retain the NULL-id check; remove the preliminary NOT EXISTS account reads.
2. Validate existence using the two existing SELECT account_id ... FOR UPDATE reads.
3. Reset a NULL sentinel before each read; a block-local NOT FOUND handler leaves NULL for a missing row, which signals the existing 5002 error.
4. Keep private same-account and threshold checks after successful existence validation, preserving their previous error precedence. Public wrappers retain their original validation.
5. Leave ordered modes 0/1/2 in LEAST/GREATEST order and deliberate naive mode 3 in from/to order. Debit, credit, actor checks, hooks, transaction control, rollback and Failed-row behavior are unchanged.

No transaction control was added to the private helper. The release-strip regression also compiled/loaded the corrected ordered-only release routine successfully.

Tests/procedures/19_transfer_missing_second_lock.sql adds three regression checks: high missing destination, high missing source, and unchanged balances/ledger/audit counts after both 5002 rejections. Both missing ids sort second, covering sentinel reset and NOT FOUND handling after an existing first row.

The EXP-10 driver gained EvidencePrefix to keep corrected comparison files separate and RequireOrderedZero to assert zero ordered deadlocks plus full completion after retaining actual results and restoring DDL/globals. The diagnostic script, procedure README and Member A interface lock contract document the invariant.

## Actual EXP-10 results

All runs used real native MySQL sessions. Corrected runs each rebuilt scratch with the same seed and 100 lab accounts. HANDLE/PREVENT each used two opposing sessions, 50 calls per session, retry limit five, post-debit sleep 0.01 seconds. The existing mode-3-only scheduling probe pauses 0.05 seconds after its first lock; mode 2 does not receive that pause. CREATE used three-second pauses and required a genuine native 1213. CONTRAST required actual 1205. No simulated deadlock error is used as proof.

| Run | Naive deadlocks / retry rows | Naive successes | Naive exhausted | Ordered deadlocks / retry rows | Ordered successes | Ordered exhausted |
|---|---:|---:|---:|---:|---:|---:|
| Original | 54 / 54 | 97/100 | 3 | 9 / 9 | 100/100 | 0 |
| Corrected 1 | 43 / 43 | 94/100 | 6 | **0 / 0** | **100/100** | **0** |
| Corrected 2 | 45 / 45 | 94/100 | 6 | **0 / 0** | **100/100** | **0** |

Thus 200/200 corrected ordered calls completed across two independent runs with zero deadlocks and zero retry rows. Naive native deadlocks remain observable. Its counts vary with scheduling/random backoff; no exact naive count is a requirement.

Raw corrected runs:
- evidence/raw/EXP-10/20261018-223416-983/
- evidence/raw/EXP-10/20261018-223504-859/

Comparison files: evidence/EV-EXP10-corrected-1-compare.md and evidence/EV-EXP10-corrected-2-compare.md. Driver output: evidence/EXP10-lock-fix/corrected-run-1.txt and corrected-run-2.txt.

Commands executed:

    powershell -NoProfile -File experiments/EXP-10_deadlocks/diagnose_ordered_lock.ps1
    powershell -NoProfile -File experiments/EXP-10_deadlocks/run_auto.ps1 -EvidencePrefix EV-EXP10-corrected-1 -RequireOrderedZero
    powershell -NoProfile -File experiments/EXP-10_deadlocks/run_auto.ps1 -EvidencePrefix EV-EXP10-corrected-2 -RequireOrderedZero
    powershell -NoProfile -File tests/run_tests.ps1 -Database bank_txn

Both RequireOrderedZero assertions passed. Complete regression: **734 PASS / 0 FAIL**, including the three new checks. Raw log: evidence/EXP10-lock-fix/regression.txt; runner log: evidence/test-runs/20261018-223534-490.txt.

All six invariants I1, I1b, I2, I3, I4 and I5 passed after each corrected EXP-10 run. Explicit post-regression reconciliation also passed all six on BOTH bank_txn and bank_txn_scratch; logs are invariants-bank_txn.txt and invariants-bank_txn_scratch.txt under evidence/EXP10-lock-fix/.

## Preservation and cleanup

Seven original files, including the original helper, EXP-10 results/comparison and Prompt 4 report, were copied before changes to evidence/EXP10-lock-fix/original/. SHA256.txt and original-preservation.txt verify all seven copies unchanged. The original raw run and EV-EXP10-compare.md remain untouched. Corrected comparisons/raw sessions are separate; current RESULTS.md and Prompt 4 report link both generations.

Regression-generated legacy evidence is saved separately under evidence/EXP10-lock-fix/regression-derived/; original tracked legacy files are restored from HEAD using configured checkout line endings.

Cleanup confirmed zero lab routines in both banking schemas, zero scheduling-probe markers, and globals restored to REPEATABLE-READ / innodb_print_all_deadlocks=0 / innodb_monitor_enable=NULL. See evidence/EXP10-lock-fix/cleanup.txt.

No EXP-08 throughput grid or unrelated experiment was rerun. Existing throughput figures remain historical pre-correction measurements.

## Remaining limitations

- Zero deadlocks is demonstrated for this specified two-account, two-session workload repeated twice, not a proof that every combination of other procedures/locks is deadlock-free. Retry handling remains necessary.
- The server .err excerpt still needs manual verification: performance_schema.error_log returned no matching entries and Windows denied file access. Actual native 1213/1205, lock snapshots and InnoDB graphs were captured.
- Measured builds use Standalone B interface stand-ins; B source/security/fraud objects were not altered or newly validated.
