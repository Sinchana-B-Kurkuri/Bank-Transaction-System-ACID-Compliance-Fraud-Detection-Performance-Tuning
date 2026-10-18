CREATE TABLE Devices (
    device_id INT AUTO_INCREMENT,
    customer_id INT NOT NULL,
    device_fingerprint CHAR(64) NOT NULL,
    device_type VARCHAR(20) NOT NULL,
    first_seen_at DATETIME NOT NULL,
    last_seen_at DATETIME NOT NULL,
    is_trusted BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_devices
        PRIMARY KEY (device_id),

    CONSTRAINT uq_devices_fingerprint
        UNIQUE (device_fingerprint),

    CONSTRAINT fk_devices_customer_id
        FOREIGN KEY (customer_id)
        REFERENCES Customers(customer_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT
);