CREATE TABLE Locations (
    location_id INT AUTO_INCREMENT,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50),
    country VARCHAR(50) NOT NULL,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,

    CONSTRAINT pk_locations
        PRIMARY KEY (location_id),

    CONSTRAINT chk_locations_latitude
        CHECK (latitude BETWEEN -90 AND 90),

    CONSTRAINT chk_locations_longitude
        CHECK (longitude BETWEEN -180 AND 180)
);