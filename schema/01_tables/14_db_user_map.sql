CREATE TABLE DB_User_Map (
    db_login VARCHAR(100) NOT NULL,
    actor_type ENUM('Customer','Employee') NOT NULL,
    employee_id INT NULL,
    customer_id INT NULL,

    CONSTRAINT pk_db_user_map PRIMARY KEY (db_login),

    CONSTRAINT chk_db_user_map_actor CHECK (
        (actor_type = 'Employee'
            AND employee_id IS NOT NULL AND customer_id IS NULL)
        OR
        (actor_type = 'Customer'
            AND customer_id IS NOT NULL AND employee_id IS NULL)
    ),

    CONSTRAINT fk_db_user_map_employee
        FOREIGN KEY (employee_id)
        REFERENCES Employees(employee_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,

    CONSTRAINT fk_db_user_map_customer
        FOREIGN KEY (customer_id)
        REFERENCES Customers(customer_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
);