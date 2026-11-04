-- Definer view: invokers receive only the mapped customer's rows; no base-table grants required.
CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_customer_account_summary AS
SELECT a.account_id,a.account_number,a.account_type_id,a.status,a.opened_date,
       a.balance,c.customer_id,c.full_name
FROM Accounts a JOIN Customers c ON c.customer_id=a.customer_id
WHERE c.customer_id=fn_resolved_customer_id(USER());
