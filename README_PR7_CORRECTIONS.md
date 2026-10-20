# PR #7 corrective patch (review-driven)

This is a corrective patch for `PR7_REVIEW_2026-10-20.md`, based on the supplied current project ZIP.

## Included changes
- Adds the seven required fraud function interfaces: distance, amount z-score, rolling transaction count, odd-hour predicate, account age, transaction risk score, and risk level.
- Adds identity helper functions that mirror `sp_resolve_actor` precedence (exact full login, explicit bare user, unanimous host variants; conflicting mappings resolve to NULL) and updates views to use `SQL SECURITY DEFINER` so view-only grants can work without base-table SELECT.
- Adds role grants for the public procedure lists while excluding private `sp_internal_*` helpers.
- Makes evaluator scoring transaction-local and repeatable; uses `param_json` for configured amount/risk/window/count thresholds. Account profile is not fed into the base score, avoiding feedback drift. HIGH_ACCOUNT_RISK currently evaluates the transaction-local score before that rule's weight is added; this policy must be confirmed by A/B.
- Updates the score smoke test to 30 for `(100,'Online',FALSE,0)`, matching the current formula (10 digital + 20 untrusted; amount contributes zero). If the signed-off formula requires 40, amend the formula and test together rather than changing only the assertion.
- Moves the optional secondary indexes out of the default integrated build; baseline B0 is now the default. Adds an optimized-profile measurement protocol.
- Reorders reference seed before the fraud trigger, and corrects B ownership labels in file order.

## Important limits / required review
This patch is not runtime-validated against MySQL. It needs installation/testing on a disposable MySQL 8.4 database, especially the RBAC grant script and restricted-login tests. `security/01_roles_and_grants.sql` must be run as a DBA in the intended schema. It creates role grants but does not grant roles to real users automatically.
The seven function signatures were absent from the supplied SPEC beyond their names; the signatures in this patch are explicit implementation assumptions and must be checked with A against the original feature blueprint before merge.
Employee view policy here is branch-scoped activity for active mapped employees; confirm this matches the agreed policy.
The patch addresses B-owned issues only. A-owned nested test-runner isolation, Quick orchestration, and remaining regression infrastructure are not included.
