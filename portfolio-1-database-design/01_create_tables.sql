-- =====================================================================
-- MIT 8103 Advanced Database Systems - Portfolio 1
-- LagosLink Deliveries (simulated): creates the 8 tables
-- Database: logistics_db   |   DBMS: PostgreSQL 18   |   Tool: pgAdmin 4
-- Student: Aregbe Abiodun Micheal (2026/A/MIT/0502)
--
-- How to run: open the Query Tool on logistics_db, paste this file, click Execute.
-- Run it on an empty database (it does not delete existing tables).
--
-- Order matters: a table with a FOREIGN KEY can only be created after the
-- table it points to. So hubs and customers (no foreign keys) come first.
-- =====================================================================


-- 1. hubs: the three LagosLink hubs (Ikeja, Yaba, Lekki)
CREATE TABLE hubs (
    hub_id   SERIAL PRIMARY KEY,                 -- unique ID, filled in automatically
    hub_name VARCHAR(50)  NOT NULL UNIQUE,       -- required, no two hubs with one name
    address  VARCHAR(200) NOT NULL,
    phone    VARCHAR(20)                         -- optional
);


-- 2. customers: people and businesses who send parcels
CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    phone         VARCHAR(20)  NOT NULL UNIQUE,  -- one customer is not registered twice
    email         VARCHAR(100) UNIQUE,           -- optional, but no two the same
    customer_type VARCHAR(20)  NOT NULL
                  CHECK (customer_type IN ('Individual', 'Business')),
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- 3. drivers: riders and van drivers; each works from one hub (one-to-many)
CREATE TABLE drivers (
    driver_id      SERIAL PRIMARY KEY,
    hub_id         INT          NOT NULL REFERENCES hubs (hub_id),   -- foreign key
    full_name      VARCHAR(100) NOT NULL,
    phone          VARCHAR(20)  NOT NULL UNIQUE,
    licence_number VARCHAR(30)  NOT NULL UNIQUE,
    status         VARCHAR(20)  NOT NULL DEFAULT 'Off duty'
                   CHECK (status IN ('Available', 'On delivery', 'Off duty'))
);


-- 4. vehicles: one driver uses one vehicle (one-to-one = foreign key + UNIQUE)
CREATE TABLE vehicles (
    vehicle_id   SERIAL PRIMARY KEY,
    driver_id    INT          UNIQUE REFERENCES drivers (driver_id), -- optional: spare vehicles
    plate_number VARCHAR(15)  NOT NULL UNIQUE,
    vehicle_type VARCHAR(20)  NOT NULL CHECK (vehicle_type IN ('Motorbike', 'Van')),
    capacity_kg  NUMERIC(6,1) NOT NULL CHECK (capacity_kg > 0)
);


-- 5. deliveries: one row per delivery order; links to customers, hubs and drivers
CREATE TABLE deliveries (
    delivery_id      SERIAL PRIMARY KEY,
    customer_id      INT           NOT NULL REFERENCES customers (customer_id),
    hub_id           INT           NOT NULL REFERENCES hubs (hub_id),
    driver_id        INT           REFERENCES drivers (driver_id),  -- empty until assigned
    pickup_address   VARCHAR(200)  NOT NULL,
    dropoff_address  VARCHAR(200)  NOT NULL,
    recipient_name   VARCHAR(100)  NOT NULL,
    recipient_phone  VARCHAR(20)   NOT NULL,
    parcel_weight_kg NUMERIC(6,2)  NOT NULL CHECK (parcel_weight_kg > 0),
    delivery_fee     NUMERIC(10,2) NOT NULL CHECK (delivery_fee >= 0),  -- naira
    status           VARCHAR(20)   NOT NULL DEFAULT 'Requested'
                     CHECK (status IN ('Requested', 'Assigned', 'Picked up',
                                       'In transit', 'Delivered', 'Failed', 'Cancelled')),
    requested_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    promised_by      TIMESTAMP     NOT NULL,
    CHECK (promised_by > requested_at)          -- rule comparing two columns
);


-- 6. delivery_status_updates: tracking history, one row per change of stage
CREATE TABLE delivery_status_updates (
    update_id   SERIAL PRIMARY KEY,
    delivery_id INT         NOT NULL REFERENCES deliveries (delivery_id),
    status      VARCHAR(20) NOT NULL
                CHECK (status IN ('Requested', 'Assigned', 'Picked up',
                                  'In transit', 'Delivered', 'Failed', 'Cancelled')),
    updated_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    note        VARCHAR(200)
);


-- 7. payments: payment attempts for a delivery (a failed try, then a successful one)
CREATE TABLE payments (
    payment_id     SERIAL PRIMARY KEY,
    delivery_id    INT           NOT NULL REFERENCES deliveries (delivery_id),
    amount         NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    method         VARCHAR(20)   NOT NULL
                   CHECK (method IN ('Card', 'Bank transfer', 'Cash', 'Wallet')),
    payment_status VARCHAR(20)   NOT NULL DEFAULT 'Pending'
                   CHECK (payment_status IN ('Pending', 'Successful', 'Failed', 'Reversed')),
    paid_at        TIMESTAMP                       -- empty until the money arrives
);


-- 8. driver_locations: GPS points from drivers' phones (grows fast, so BIGSERIAL)
CREATE TABLE driver_locations (
    location_id BIGSERIAL PRIMARY KEY,
    driver_id   INT          NOT NULL REFERENCES drivers (driver_id),
    latitude    NUMERIC(9,6) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude   NUMERIC(9,6) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    recorded_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);
