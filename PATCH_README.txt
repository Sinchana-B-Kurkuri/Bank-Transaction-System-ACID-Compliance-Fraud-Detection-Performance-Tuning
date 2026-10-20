DBS project missing-feature implementation patch
=================================================
Copy the files and folders in this archive into the root of your existing repository,
preserving relative paths. Modified files are README.md, build/file_order.txt, and
build/run_all.sql. The remaining files are additions.

Included:
- fn_fraud_score and sp_evaluate_fraud
- completed-transaction fraud trigger and idempotent synthetic fraud rule seed
- customer-scoped reporting views and manual least-privilege MySQL role/grant script
- workload-driven indexes and EXPLAIN comparison protocol
- automated smoke tests for score behavior and installed fraud/security objects

Important:
- The archive is a patch, not a claim that tests passed. This environment has no MySQL
  client/server or PowerShell, so runtime SQL and full regression tests could not be run.
- Apply to a clean working tree on a new feature branch; review diffs before committing.
- security/01_roles_and_grants.sql is manual and targets bank_txn by default.
- Scoring is an educational heuristic, not a production fraud detection system.
- Performance gains must be measured; no speedup claims are included.
- Run the repository's normal rebuild and test suite after applying, then fix any
  version/schema-specific issues before opening a PR.
