-- Row-scoped view: only the customer mapped to the current DB login can see these rows.
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_customer_account_summary AS
SELECT a.account_id,a.account_number,a.account_type_id,a.status,a.opened_date,
       a.balance, c.customer_id,c.full_name
FROM Accounts a JOIN Customers c ON c.customer_id=a.customer_id
WHERE c.customer_id = (
  SELECT m.customer_id FROM DB_User_Map m
  WHERE m.actor_type='Customer'
    AND m.db_login IN (USER(), SUBSTRING_INDEX(USER(),'@',1))
  ORDER BY (m.db_login=USER()) DESC LIMIT 1
);
