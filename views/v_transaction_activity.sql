-- Row-scoped view for mapped customer logins; do not grant it to untrusted shared accounts.
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_transaction_activity AS
SELECT t.transaction_id,t.account_id,t.related_account_id,t.transaction_type,
       t.amount,t.balance_after,t.channel,t.status,t.transaction_timestamp,
       t.reference_no,t.transfer_group_id
FROM Transactions t
WHERE EXISTS (
  SELECT 1 FROM Accounts a JOIN DB_User_Map m ON m.customer_id=a.customer_id
  WHERE a.account_id=t.account_id AND m.actor_type='Customer'
    AND m.db_login IN (USER(), SUBSTRING_INDEX(USER(),'@',1))
);
