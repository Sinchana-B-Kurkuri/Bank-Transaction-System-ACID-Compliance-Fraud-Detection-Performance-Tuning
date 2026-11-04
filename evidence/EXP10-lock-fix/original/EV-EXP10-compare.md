# Measured deadlock comparison

DB-only first-lock pause in mode 3; shipping source unchanged. Raw: C:\Users\sinch\Desktop\DBS\DBS Project\Bank-Transaction-System-ACID-Compliance-Fraud-Detection-Performance-Tuning\evidence\raw\EXP-10\20261018-221245-928

| Mode | Deadlocks delta | Committed retry rows | Successful calls |
|---|---:|---:|---:|
| 3 | 54 | 54 | 97 / 100 |
| 2 | 9 | 9 | 100 / 100 |