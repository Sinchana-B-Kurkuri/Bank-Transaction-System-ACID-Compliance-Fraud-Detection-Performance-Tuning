# Measured deadlock comparison

DB-only first-lock pause in mode 3; source snapshot retained in instrumentation.sql. Raw: C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-10\20261018-223416-983

| Mode | Deadlocks delta | Committed retry rows | Successful calls |
|---|---:|---:|---:|
| 3 | 43 | 43 | 94 / 100 |
| 2 | 0 | 0 | 100 / 100 |