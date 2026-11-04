CREATE TABLE Loans (
 loan_id INT AUTO_INCREMENT, customer_id INT NOT NULL, disbursement_account_id INT NULL,
 principal_amount DECIMAL(14,2) NOT NULL, interest_rate DECIMAL(5,2) NOT NULL,
 tenure_months INT NOT NULL, status ENUM('Active','Closed','Defaulted') NOT NULL, disbursed_date DATE NOT NULL,
 CONSTRAINT pk_loans PRIMARY KEY(loan_id), CONSTRAINT chk_loans_principal CHECK(principal_amount>0),
 CONSTRAINT chk_loans_tenure CHECK(tenure_months>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
