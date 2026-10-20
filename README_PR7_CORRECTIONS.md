# PR #7 corrective patch (review-driven)

This is a corrective patch for `PR7_REVIEW_2026-10-20.md`, based on the supplied current project ZIP.

## Included changes
- Adds the seven required fraud function interfaces: distance, amount z-score, rolling transaction count, odd-hour predicate, account age, transaction risk score, and risk level.
- Adds identity helper functions that mirror `sp_resolve_actor` precedence (exact full login, explicit bare user, unanimous host variants; conflicting mappings resolve to NULL) and updates views to use `SQL SECURITY DEFINER` so view-only grants can work without base-table SELECT.
- Restores role provisioning and the public procedure grant lists while excluding private `sp_internal_*` helpers. Installation now defaults to a complete preview; apply requires explicit approval. See security/README.md.
- Makes evaluator scoring transaction-local and repeatable; uses `param_json` for configured amount/risk/window/count thresholds. Account profile is not fed into the base score, avoiding feedback drift. Member A approved retaining HIGH_ACCOUNT_RISK's transaction-local score comparison before that rule's weight is added (2026-10-20).
- Member A approved +20 untrusted on 2026-10-20. The score assertion is30 for `(100,'Online',FALSE,0)` (10 digital +20 untrusted). fn_fraud_score delegates to fn_txn_risk_score so helper and evaluator use the same heuristic. All seven required functions now have runner-compatible behavioral/signature tests.
- Moves the optional secondary indexes out of the default integrated build; baseline B0 is now the default. Adds an optimized-profile measurement protocol.
- Reorders reference seed before the fraud trigger, and corrects B ownership labels in file order.

## Important limits / required review
Current measured results and remaining authorization limits are recorded under evidence/reviews/PR9-final-fixes/. Safe acceptance uses actual A+B sources in fresh ownership-verified disposable schemas. Member A explicitly approved isolated suffixed-role/login testing on2026-10-20; those actual native tests and cleanup passed. Standard-role deployment still requires separate authorization; preview alone is not proof of effective privileges. The RBAC installer never assigns roles to real users automatically.
The seven function signatures were absent from the supplied SPEC beyond their names; the signatures in this patch are explicit implementation assumptions and must be checked with A against the original feature blueprint before merge.
Employee statement access now follows the approved active same-branch Teller/Manager policy, with5010 rejections. Customer statements require ownership. Trusted-System behavior, signatures and result sets are preserved. Existing employee activity views remain unchanged.
The patch addresses B-owned issues only. A-owned nested test-runner isolation, Quick orchestration, and remaining regression infrastructure are not included.
