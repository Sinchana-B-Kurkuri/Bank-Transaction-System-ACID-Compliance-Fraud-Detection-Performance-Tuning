CREATE TABLE Transaction_Approvals (
    approval_id INT AUTO_INCREMENT,
    requested_by_actor_type ENUM('Customer','Employee') NOT NULL,
    requested_by_employee_id INT NULL,
    requested_by_customer_id INT NULL,
    requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    from_account_id INT NOT NULL,
    to_account_id INT NOT NULL,
    amount DECIMAL(14,2) NOT NULL,
    status ENUM('Requested','Approved','Rejected')
        NOT NULL DEFAULT 'Requested',
    decided_by INT NULL,
    decided_at DATETIME NULL,
    resulting_transfer_group_id CHAR(36) NULL,

    CONSTRAINT pk_transaction_approvals
        PRIMARY KEY (approval_id),

    CONSTRAINT chk_approval_amount CHECK (amount > 0),
    CONSTRAINT chk_approval_different_accounts
        CHECK (from_account_id <> to_account_id),

    CONSTRAINT chk_approval_requester CHECK (
        (requested_by_actor_type = 'Customer'
            AND requested_by_customer_id IS NOT NULL
            AND requested_by_employee_id IS NULL)
        OR
        (requested_by_actor_type = 'Employee'
            AND requested_by_employee_id IS NOT NULL
            AND requested_by_customer_id IS NULL)
    ),

    CONSTRAINT fk_approvals_from_account
        FOREIGN KEY (from_account_id)
        REFERENCES Accounts(account_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,

    CONSTRAINT fk_approvals_to_account
        FOREIGN KEY (to_account_id)
        REFERENCES Accounts(account_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,

    CONSTRAINT fk_approvals_requester_employee
        FOREIGN KEY (requested_by_employee_id)
        REFERENCES Employees(employee_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,

    CONSTRAINT fk_approvals_requester_customer
        FOREIGN KEY (requested_by_customer_id)
        REFERENCES Customers(customer_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,

    CONSTRAINT fk_approvals_decided_by
        FOREIGN KEY (decided_by)
        REFERENCES Employees(employee_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
);