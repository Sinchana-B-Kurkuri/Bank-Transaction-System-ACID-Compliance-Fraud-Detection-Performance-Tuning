DELIMITER $$

DROP PROCEDURE IF EXISTS sp_install_role_procedure_grants$$

CREATE PROCEDURE sp_install_role_procedure_grants(
    IN p_db VARCHAR(64),
    IN p_role VARCHAR(64),
    IN p_csv TEXT
)
SQL SECURITY INVOKER
BEGIN
    DECLARE v_rest TEXT DEFAULT p_csv;
    DECLARE v_proc VARCHAR(64);
    DECLARE v_pos INT;
    DECLARE v_sql TEXT;

    IF p_db IS NULL OR p_role NOT IN (
        'bank_customer_role',
        'bank_teller_role',
        'bank_manager_role'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid RBAC target or role';
    END IF;

    grant_loop: LOOP
        SET v_pos = LOCATE(',', v_rest);

        IF v_pos = 0 THEN
            SET v_proc = TRIM(v_rest);
        ELSE
            SET v_proc = TRIM(SUBSTRING(v_rest, 1, v_pos - 1));
        END IF;

        IF v_proc = '' THEN
            LEAVE grant_loop;
        END IF;

        SET @rbac_grant_sql = CONCAT(
            'GRANT EXECUTE ON PROCEDURE `',
            REPLACE(p_db, '`', '``'),
            '`.`',
            REPLACE(v_proc, '`', '``'),
            '` TO ''',
            REPLACE(p_role, '''', ''''''),
            ''''
        );

        PREPARE rbac_grant_stmt FROM @rbac_grant_sql;
        EXECUTE rbac_grant_stmt;
        DEALLOCATE PREPARE rbac_grant_stmt;

        IF v_pos = 0 THEN
            LEAVE grant_loop;
        END IF;

        SET v_rest = SUBSTRING(v_rest, v_pos + 1);
    END LOOP;
END$$

DELIMITER ;