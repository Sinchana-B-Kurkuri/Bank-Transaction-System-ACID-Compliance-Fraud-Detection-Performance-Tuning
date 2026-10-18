CREATE TABLE Audit_Log (
 audit_id BIGINT AUTO_INCREMENT, table_name VARCHAR(50) NOT NULL, record_pk VARCHAR(50) NOT NULL,
 action_type ENUM('INSERT','UPDATE','DELETE') NOT NULL, old_value JSON NULL, new_value JSON NULL,
 db_session_user VARCHAR(100) NOT NULL, actor_type ENUM('Customer','Employee','System') NOT NULL,
 actor_employee_id INT NULL, actor_customer_id INT NULL, performed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT pk_audit_log PRIMARY KEY(audit_id),
 CONSTRAINT chk_audit_log_actor CHECK(
 (actor_type='Employee' AND actor_employee_id IS NOT NULL AND actor_customer_id IS NULL) OR
 (actor_type='Customer' AND actor_customer_id IS NOT NULL AND actor_employee_id IS NULL) OR
 (actor_type='System' AND actor_employee_id IS NULL AND actor_customer_id IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
