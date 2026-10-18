CREATE TABLE Customers (
 customer_id INT AUTO_INCREMENT, full_name VARCHAR(100) NOT NULL, dob DATE NOT NULL,
 gender VARCHAR(15) NULL, email VARCHAR(100) NOT NULL, phone VARCHAR(20) NOT NULL,
 address VARCHAR(200) NOT NULL, id_proof_number VARCHAR(30) NOT NULL,
 id_proof_type ENUM('Aadhaar','PAN','Passport','DrivingLicense','VoterID') NOT NULL,
 kyc_status ENUM('Pending','Verified','Rejected') NOT NULL DEFAULT 'Pending',
 is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT pk_customers PRIMARY KEY(customer_id), CONSTRAINT uq_customers_email UNIQUE(email),
 CONSTRAINT uq_customers_phone UNIQUE(phone), CONSTRAINT uq_customers_id_proof UNIQUE(id_proof_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
