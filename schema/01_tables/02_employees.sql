CREATE TABLE Employees (
 employee_id INT AUTO_INCREMENT, branch_id INT NOT NULL, full_name VARCHAR(100) NOT NULL,
 role ENUM('Teller','Manager','DBA') NOT NULL, email VARCHAR(100) NOT NULL,
 hire_date DATE NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE,
 CONSTRAINT pk_employees PRIMARY KEY(employee_id), CONSTRAINT uq_employees_email UNIQUE(email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
