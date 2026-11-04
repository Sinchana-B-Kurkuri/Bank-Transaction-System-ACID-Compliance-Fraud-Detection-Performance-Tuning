# Member A invariant checks

sp_reconcile_balances is read-only and returns six invariant summaries (I1, I1b, I2, I3, I4, I5), then up to 100 offender keys. I1b checks each completed ledger row against its predecessor by transaction_id. I2 and I4 remain global when an account filter is supplied. I4 uses the latest DATABASE()-scoped audit-install watermark; absent maxima default to zero.

The same summaries are exposed in the session-only @reconcile_results JSON array so the SQL runner can emit TEST lines without changing the two-result-set public contract. No account, transaction, or audit data is modified by reconciliation. A caller needing a consistent snapshot during concurrent traffic can call it within their own read-only transaction.

The scratch-only procedure test injects a positive balance discrepancy, observes I1 and I5 failures, saves the actual diagnostics, and rebuilds scratch in finally. Production-schema corruption is never used as a test fixture.
