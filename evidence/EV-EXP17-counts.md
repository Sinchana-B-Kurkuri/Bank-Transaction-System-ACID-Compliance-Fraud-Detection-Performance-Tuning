# EXP-17 expected versus actual

Derivation per operation: ledger legs = single-leg calls + 2 * transfer calls; Accounts UPDATE and Transactions INSERT each equal ledger legs. Opening additionally inserts one Accounts row. Routed loan additionally inserts one Loans row. Zero-count groups are also checked. The plan contains each executed statement once; counts are not inferred from Audit_Log.

| Statement | Table/action | Expected | Actual | Match |
|---|---|---:|---:|---|
| zz_a_audit_teller / open | Transactions / INSERT | 1 | 1 | True |
| zz_a_audit_teller / open | Accounts / UPDATE | 1 | 1 | True |
| zz_a_audit_teller / open | Loans / INSERT | 0 | 0 | True |
| zz_a_audit_teller / open | Accounts / INSERT | 1 | 1 | True |
| zz_a_audit_teller / deposit | Transactions / INSERT | 1 | 1 | True |
| zz_a_audit_teller / deposit | Accounts / UPDATE | 1 | 1 | True |
| zz_a_audit_teller / deposit | Loans / INSERT | 0 | 0 | True |
| zz_a_audit_teller / deposit | Accounts / INSERT | 0 | 0 | True |
| zz_a_audit_teller / withdraw | Transactions / INSERT | 1 | 1 | True |
| zz_a_audit_teller / withdraw | Accounts / UPDATE | 1 | 1 | True |
| zz_a_audit_teller / withdraw | Loans / INSERT | 0 | 0 | True |
| zz_a_audit_teller / withdraw | Accounts / INSERT | 0 | 0 | True |
| zz_a_audit_teller / transfer | Transactions / INSERT | 2 | 2 | True |
| zz_a_audit_teller / transfer | Accounts / UPDATE | 2 | 2 | True |
| zz_a_audit_teller / transfer | Loans / INSERT | 0 | 0 | True |
| zz_a_audit_teller / transfer | Accounts / INSERT | 0 | 0 | True |
| zz_a_audit_teller / loan | Transactions / INSERT | 1 | 1 | True |
| zz_a_audit_teller / loan | Accounts / UPDATE | 1 | 1 | True |
| zz_a_audit_teller / loan | Loans / INSERT | 1 | 1 | True |
| zz_a_audit_teller / loan | Accounts / INSERT | 0 | 0 | True |
| zz_a_audit_customer / open | Transactions / INSERT | 1 | 1 | True |
| zz_a_audit_customer / open | Accounts / UPDATE | 1 | 1 | True |
| zz_a_audit_customer / open | Loans / INSERT | 0 | 0 | True |
| zz_a_audit_customer / open | Accounts / INSERT | 1 | 1 | True |
| zz_a_audit_customer / deposit | Transactions / INSERT | 1 | 1 | True |
| zz_a_audit_customer / deposit | Accounts / UPDATE | 1 | 1 | True |
| zz_a_audit_customer / deposit | Loans / INSERT | 0 | 0 | True |
| zz_a_audit_customer / deposit | Accounts / INSERT | 0 | 0 | True |
| zz_a_audit_customer / withdraw | Transactions / INSERT | 1 | 1 | True |
| zz_a_audit_customer / withdraw | Accounts / UPDATE | 1 | 1 | True |
| zz_a_audit_customer / withdraw | Loans / INSERT | 0 | 0 | True |
| zz_a_audit_customer / withdraw | Accounts / INSERT | 0 | 0 | True |
| zz_a_audit_customer / transfer | Transactions / INSERT | 2 | 2 | True |
| zz_a_audit_customer / transfer | Accounts / UPDATE | 2 | 2 | True |
| zz_a_audit_customer / transfer | Loans / INSERT | 0 | 0 | True |
| zz_a_audit_customer / transfer | Accounts / INSERT | 0 | 0 | True |
| zz_a_audit_customer / loan | Transactions / INSERT | 1 | 1 | True |
| zz_a_audit_customer / loan | Accounts / UPDATE | 1 | 1 | True |
| zz_a_audit_customer / loan | Loans / INSERT | 1 | 1 | True |
| zz_a_audit_customer / loan | Accounts / INSERT | 0 | 0 | True |
| DBA / one single-row statement | Loans / INSERT | 1 | 1 | True |
| DBA / one single-row statement | Loans / UPDATE | 1 | 1 | True |
| DBA / one single-row statement | Loans / DELETE | 1 | 1 | True |
| DBA / one single-row statement | Accounts / UPDATE | 1 | 1 | True |
| DBA / one single-row statement | Transactions / INSERT | 1 | 1 | True |
