# Review 1 corrections — Member A

IMPLEMENTED textual correction list. Binary DOCX/PPTX edits and exact slide/page numbers: NEEDS MANUAL VERIFICATION because no original Review 1 DOCX or PPTX exists in this checkout. No older Review1 binary was used as schema authority. Apply the changes to the corresponding section/title below, then record actual page/slide numbers; none are invented here.

| Document section / slide to locate | Exact correction |
|---|---|
| Data dictionary / Transactions / transaction schema slide | Add nullable device_id INT and location_id INT. Include transfer_group_id CHAR(36) nullable and UNIQUE(transfer_group_id, transaction_type). Devices/Locations FKs are conditional cross-module constraints, not hard-coded in the table file. Credit legs and Failed rows carry NULL context. |
| Data dictionary / Customers / customer slide | Add is_active BOOLEAN NOT NULL DEFAULT TRUE. Preserve id_proof_type ENUM(Aadhaar,PAN,Passport,DrivingLicense,VoterID); proofs in demonstration data are synthetic. |
| Fraud_Flags / fraud data model slide | Replace rule_ENUM with rule_id INT NOT NULL FK Fraud_Rules(rule_id); add evidence JSON NULL and UNIQUE(transaction_id,rule_id). Keep risk_score DECIMAL(5,2) checked 0..100 and reviewed_by nullable Employee FK. |
| Audit_Log / audit design slide | Use db_session_user VARCHAR(100) NOT NULL = USER(), never CURRENT_USER() in trigger bodies. Add actor_type, actor_employee_id, actor_customer_id and exactly-one-actor CHECK; old_value/new_value JSON, table_name/record_pk with no dynamic FK; performed_at DATETIME DEFAULT CURRENT_TIMESTAMP. DEFINER context does not identify the connecting actor. |
| Functional requirement FR4 / close-account slide | Default close is rejected when balance<>0 OR an Active loan references the account as disbursement_account_id (D2). Explicit settle=1 posts a final Withdrawal and sets balance=0,status=Closed atomically; it does not override the Active-loan restriction. |
| Functional requirement FR1 / customer lifecycle slide | An inactive customer cannot open an account; customer deactivation is rejected while any non-Closed account exists (A11). |
| ER diagram / loan relationship slide | Remove “Accounts secures Loans.” Customers borrows Loans through Loans.customer_id. Loans.disbursement_account_id optionally references Accounts; routed disbursement is a Deposit. An unrouted loan has NULL disbursement account. |
| ER transfer / transaction pair slide | One logical transfer has two Completed rows linked by transfer_group_id, mirrored related_account_id, opposite TransferOut/TransferIn types and equal amounts. Reference numbers remain individually unique. |
| ER overview / Phase 1 entities slide | Remove Card, CustomerAccount, TransactionType, TransactionLog and FraudAlert. Use the final nine A tables plus real B interface entities. Single-owner Accounts references Customers directly. |
| ACID / transaction implementation slide | Two sequential SELECT FOR UPDATE reads lock LEAST then GREATEST before money movement; no preliminary existence reads acquiring S locks. Deliberate naive mode 3 is lab-only. Release removes hooks and rejects nonzero mode with 5017. |
| Audit coverage / recovery slide | Coverage begins at AUDIT_TRIGGERS_INSTALLED watermark (D5). DBA can remove triggers or TRUNCATE/DROP audit data. Dump restoration does not magically regenerate historical audit rows. Real crash/PITR demonstrations remain manual where evidence says NOT YET RUN. |

The replacement textual ER is docs/er/er_core.mmd, generated from information_schema for 15 core/interface entities and 25 FK relationships. Account_Risk_Profile is a B-owned extension outside this core/interface figure. Tests compare every represented FK to the Integrated database and report standalone differences instead of treating stubs as equivalent. A separate final-schema figure may add B's Account_Risk_Profile relationship.

Do not update a slide to claim runtime fraud/RBAC/benchmark completion until the missing B source and its actual tests are available. No binary “updated copy” was generated in this task.
