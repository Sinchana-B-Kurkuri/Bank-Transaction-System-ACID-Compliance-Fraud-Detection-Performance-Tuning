CREATE TABLE Branches (
 branch_id INT AUTO_INCREMENT, branch_name VARCHAR(100) NOT NULL,
 ifsc_code VARCHAR(15) NOT NULL, address VARCHAR(200) NOT NULL,
 city VARCHAR(50) NOT NULL, state VARCHAR(50) NOT NULL, phone VARCHAR(20) NOT NULL,
 CONSTRAINT pk_branches PRIMARY KEY (branch_id), CONSTRAINT uq_branches_ifsc UNIQUE (ifsc_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
