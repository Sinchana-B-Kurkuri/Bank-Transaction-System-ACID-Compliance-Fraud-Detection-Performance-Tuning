-- Customer identity follows sp_resolve_actor precedence. Employees see only their own branch.
CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_transaction_activity AS
SELECT t.transaction_id,t.account_id,t.related_account_id,t.transaction_type,
       t.amount,t.balance_after,t.channel,t.status,t.transaction_timestamp,
       t.reference_no,t.transfer_group_id
FROM Transactions t
JOIN Accounts a ON a.account_id=t.account_id
LEFT JOIN Employees e ON e.employee_id=fn_resolved_employee_id(USER()) AND e.is_active=TRUE
WHERE
  (fn_resolved_customer_id(USER()) IS NOT NULL
   AND a.customer_id=fn_resolved_customer_id(USER()))
  OR
  (fn_resolved_employee_id(USER()) IS NOT NULL
   AND e.branch_id=a.branch_id);
