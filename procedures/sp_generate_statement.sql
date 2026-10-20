DELIMITER $$

DROP PROCEDURE IF EXISTS sp_generate_statement$$

CREATE PROCEDURE sp_generate_statement(
    IN p_account_id INT,
    IN p_from DATE,
    IN p_to DATE
)
READS SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE v_open DECIMAL(14,2) DEFAULT 0;
    DECLARE v_actor VARCHAR(10);
    DECLARE v_employee_id INT DEFAULT NULL;
    DECLARE v_customer_id INT DEFAULT NULL;

    -- Validate the requested statement period.
    IF p_from IS NULL
       OR p_to IS NULL
       OR p_from > p_to
       OR DATEDIFF(p_to, p_from) + 1 > 366 THEN
        SIGNAL SQLSTATE '45000'
            SET MYSQL_ERRNO = 5018,
                MESSAGE_TEXT =
                    'E_INVALID_ARGUMENT: invalid statement date range';
    END IF;

    -- Validate that the account exists.
    IF p_account_id IS NULL
       OR NOT EXISTS (
            SELECT 1
            FROM Accounts
            WHERE account_id = p_account_id
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MYSQL_ERRNO = 5002,
                MESSAGE_TEXT =
                    'E_ACCOUNT_NOT_FOUND: account does not exist';
    END IF;

    -- Resolve the caller using the project's actor resolver.
    CALL sp_resolve_actor(
        USER(),
        v_actor,
        v_employee_id,
        v_customer_id
    );

    -- Customers may only request statements for their own accounts.
    IF v_actor = 'Customer'
       AND NOT EXISTS (
            SELECT 1
            FROM Accounts a
            WHERE a.account_id = p_account_id
              AND a.customer_id = v_customer_id
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MYSQL_ERRNO = 5010,
                MESSAGE_TEXT =
                    'E_NOT_AUTHORIZED: account does not belong to customer';
    END IF;

    -- Match the activity view policy: active Tellers/Managers, own branch only.
    IF v_actor = 'Employee'
       AND NOT EXISTS (
            SELECT 1
            FROM Employees e
            JOIN Accounts a ON a.branch_id = e.branch_id
            WHERE e.employee_id = v_employee_id
              AND e.is_active = TRUE
              AND e.role IN ('Teller', 'Manager')
              AND a.account_id = p_account_id
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MYSQL_ERRNO = 5010,
                MESSAGE_TEXT =
                    'E_NOT_AUTHORIZED: active same-branch staff required';
    END IF;

    -- Preserve A1/A17: unmapped trusted administrative workflows resolve to System.
    -- Application roles must always be provisioned with an explicit DB_User_Map row.
    IF v_actor IS NULL
       OR v_actor NOT IN ('Customer', 'Employee', 'System') THEN
        SIGNAL SQLSTATE '45000'
            SET MYSQL_ERRNO = 5010,
                MESSAGE_TEXT =
                    'E_NOT_AUTHORIZED: caller is not authorized';
    END IF;

    -- Opening balance: latest completed transaction before the period.
    SET v_open = COALESCE(
        (
            SELECT t.balance_after
            FROM Transactions t
            WHERE t.account_id = p_account_id
              AND t.status = 'Completed'
              AND t.transaction_timestamp < p_from
            ORDER BY t.transaction_id DESC
            LIMIT 1
        ),
        0
    );

    -- Statement header.
    SELECT
        p_account_id AS account_id,
        p_from AS period_start,
        v_open AS opening_balance;

    -- Completed transactions and running balance for the period.
    SELECT
        t.transaction_id,
        t.transaction_timestamp AS timestamp,
        t.transaction_type AS type,
        t.amount,
        t.balance_after,
        t.related_account_id,
        t.reference_no,
        v_open
        + SUM(
            CASE
                WHEN t.transaction_type IN (
                    'Deposit',
                    'TransferIn',
                    'InterestCredit'
                ) THEN t.amount
                ELSE -t.amount
            END
        ) OVER (
            ORDER BY t.transaction_id
            ROWS UNBOUNDED PRECEDING
        ) AS running_balance
    FROM Transactions t
    WHERE t.account_id = p_account_id
      AND t.status = 'Completed'
      AND t.transaction_timestamp >= p_from
      AND t.transaction_timestamp < DATE_ADD(p_to, INTERVAL 1 DAY)
    ORDER BY t.transaction_id;
END$$

DELIMITER ;
