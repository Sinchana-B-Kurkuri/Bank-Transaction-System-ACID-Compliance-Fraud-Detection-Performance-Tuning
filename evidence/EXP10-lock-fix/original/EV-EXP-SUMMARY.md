# Measured experiment summary

Started 2026-10-18T22:08:22.8488644+05:30, database bank_txn_scratch. Raw files contain version/time/connection IDs.

| Experiment | Status | Detail |
|---|---|---|
| EXP-01 | LOCALLY TESTED | Native MySQL run completed; see RESULTS.md/raw output and any explicit capture limitation. |
| EXP-02 | LOCALLY TESTED | Native MySQL run completed; see RESULTS.md/raw output and any explicit capture limitation. |
| EXP-04 | LOCALLY TESTED | Native MySQL run completed; see RESULTS.md/raw output and any explicit capture limitation. |
| EXP-05 | LOCALLY TESTED | Native MySQL run completed; see RESULTS.md/raw output and any explicit capture limitation. |
| EXP-06 | LOCALLY TESTED | Native MySQL run completed; see RESULTS.md/raw output and any explicit capture limitation. |
| EXP-07 | LOCALLY TESTED | Native MySQL run completed; see RESULTS.md/raw output and any explicit capture limitation. |
| EXP-09-20 | LOCALLY TESTED | Native MySQL run completed; see RESULTS.md/raw output and any explicit capture limitation. |
| EXP-09-50 | LOCALLY TESTED | Native MySQL run completed; see RESULTS.md/raw output and any explicit capture limitation. |
| EXP-10 | LOCALLY TESTED / TARGET NOT MET / NEEDS MANUAL VERIFICATION | Native MySQL run completed; see RESULTS.md/raw output and any explicit capture limitation. |
| Resume | IMPLEMENTED | Reusing recorded completed SQL runs; rerunning matrix and Quick throughput, then cleanup. Original failed driver log is retained. |
| EXP-08 matrix | LOCALLY TESTED | Parsed completed raw runs. |
| EXP-08 Quick | LOCALLY TESTED | Measured mysqlslap RC/RR, concurrency 5/25. |

Final isolated repeat: EXP-10 mode 3 = 54 deadlocks, 97/100 successes, 3 exhausted; mode 2 = 9 deadlocks, 100/100 successes, 0 exhausted. Prevention target NOT MET. Final EXP-01 repeat: 200 failures, 0 partial transfers, owned KILL snapshot unchanged. Full throughput: 16 settings, 9600 successful transfers; EV-EXP08-Full-throughput.csv. Complete regression: 731 PASS, 0 FAIL. See docs/member-a/PROMPT4_DELIVERY.md for scope blockers and raw paths.
