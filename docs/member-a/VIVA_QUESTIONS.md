# Viva questions — Member A and B interfaces

Answers use the frozen SPEC/decisions and inspected schema. B runtime answers are contracts, not claims that missing code ran.

## Five on B

1. **What does B contribute?** Seven schema tables are present: Devices, Locations, Fraud_Rules, Account_Risk_Profile, DB_User_Map, Transaction_Approvals, Fraud_Ground_Truth. SPEC additionally assigns fraud scoring/evaluation, fraud trigger, views/RBAC/indexes/benchmarks and EXP-11..15 to B; those runtime sources are absent here.
2. **Does fraud block a transaction?** D7 specifies detective flags, not transaction blocking. Actual evaluator behavior cannot be demonstrated until B supplies it.
3. **Why must the fraud trigger follow A's audit?** A14 requires FOLLOWS trg_transactions_ai_audit, creating a deterministic AFTER INSERT sequence. Both audit and flag rows belong to the surrounding transaction and roll back with a failed transfer.
4. **How does A identify a B device's owner?** The BEFORE INSERT guard compares Devices.customer_id to the transaction account's customer; mismatch is 5014. Missing references retain native FK failure. Credit-leg device/location are NULL by A5.
5. **What may B roles execute?** Only their least-privilege subset of the public procedure allowlist. Never grant sp_internal_*: they assume an owning public transaction and trusted validation context. The real B role policy/tests are not present; A restricted-user tests do not substitute for them.

## Ten on A

1. **How is ACID implemented?** InnoDB row locks and transactional updates/ledger/audit writes supply atomicity/consistency/isolation; durable commits depend on redo/binlog flush settings. The measured flush/sync values were 1/1. Process-crash survival was not executed by the agent.
2. **Can RR prevent every lost update?** No. A stale application read followed by absolute SET balance=old-amount can overwrite newer work. Use relative updates and locking reads; the historical real-session lab distinguishes snapshot isolation from application read-modify-write correctness.
3. **1213 versus 1205?** 1213 means a deadlock victim; 1205 means a lock-wait timeout, which need not have a cycle. The public handler rolls back the whole transaction for either; retry repeats the whole call and logs after rollback. Synthetic test errors demonstrate control flow only; real graph evidence is in EXP-10.
4. **USER() versus CURRENT_USER()?** USER() names the connecting session; CURRENT_USER() inside DEFINER code names its definer. The resolver checks exact DB_User_Map login, then user-part fallback; conflicting mappings return System. Restricted-user tests capture this distinction.
5. **Why did ordered locking previously deadlock?** Preliminary EXISTS reads acquired shared account locks, allowing S-to-X conversion cycles before ordered locking. The corrected helper validates existence via the same ordered exclusive reads. LEAST/GREATEST ordering remains unchanged in release.
6. **Why do fraud flags vanish after rollback?** They are transactional writes in the original transaction (A14). This is accepted detective semantics. Eligible Failed ledger rows are separate post-rollback transactions; 1213/1205 and lab errors do not get Failed rows.
7. **Why make the ledger immutable?** UPDATE/DELETE would silently rewrite the evidence used by balances/statements/reconciliation. Guards raise 5012; Audit_Log guards raise 5013. Privileged DDL remains an explicit limitation.
8. **Why post opening deposits?** A2 makes stored balance equal net Completed credits/debits from the first account state. Opening balance without a matching ledger row breaks I1/I1b. Amount>0 means zero opening deposits cannot be represented under this frozen schema.
9. **What is D5's audit watermark?** A database-scoped record of account/transaction/loan/audit maxima at trigger installation. I4 checks coverage after it; reinstating triggers cannot reconstruct the earlier gap. EXP-17 intentionally demonstrates that limit.
10. **What are the PITR steps?** Consistent full dump with binlog coordinates; record workload state and pre-error transaction boundary; restore only scratch; replay start-to-stop binlog positions; compare all table counts/checksums and six invariants. SQL text dumps can change opaque JSON representation; native Audit_Log checksum mismatch is reported separately. Local binlog ACLs blocked replay here; dump-only recovery and its timings were measured.
