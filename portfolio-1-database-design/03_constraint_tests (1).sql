-- =====================================================================
-- MIT 8103 Advanced Database Systems - Portfolio 1
-- LagosLink Deliveries: testing the keys and constraints
-- Run AFTER 01_create_tables.sql and 02_sample_data.sql.
--
-- Every test below tries to put BAD data in on purpose.
-- Each one SHOULD FAIL with a red ERROR. The error proves the rule works.
-- Because they fail, none of them changes your data.
--
-- How to run: highlight ONE test (from INSERT/UPDATE/DELETE down to its ;)
-- and click Execute. pgAdmin runs only the highlighted part.
-- Screenshot the error in the Messages tab for each test.
-- =====================================================================


-- TEST 1 - PRIMARY KEY: two hubs cannot share ID 1
INSERT INTO hubs (hub_id, hub_name, address)
VALUES (1, 'Second Ikeja Hub', '1 Test Street, Ikeja');
-- Expected: ERROR: duplicate key value violates unique constraint "hubs_pkey"


-- TEST 2 - FOREIGN KEY: a delivery for customer 999, who does not exist
INSERT INTO deliveries (customer_id, hub_id, pickup_address, dropoff_address,
                        recipient_name, recipient_phone, parcel_weight_kg,
                        delivery_fee, promised_by)
VALUES (999, 1, '10 Allen Avenue, Ikeja', '22 Opebi Road, Ikeja',
        'Test Person', '0803 000 0399', 2.00, 2500.00, CURRENT_TIMESTAMP + INTERVAL '4 hours');
-- Expected: ERROR: insert or update on table "deliveries" violates foreign key
--           constraint "deliveries_customer_id_fkey"
--           DETAIL: Key (customer_id)=(999) is not present in table "customers".


-- TEST 3 - FOREIGN KEY (other direction): delete a customer who still has deliveries
DELETE FROM customers WHERE customer_id = 1;
-- Expected: ERROR: update or delete on table "customers" violates foreign key
--           constraint "deliveries_customer_id_fkey" on table "deliveries"


-- TEST 4 - NOT NULL: a customer with no name
INSERT INTO customers (full_name, phone, customer_type)
VALUES (NULL, '0801 000 0199', 'Individual');
-- Expected: ERROR: null value in column "full_name" of relation "customers"
--           violates not-null constraint


-- TEST 5 - UNIQUE: a new driver using Tunde's licence number
INSERT INTO drivers (hub_id, full_name, phone, licence_number)
VALUES (1, 'Copy Driver', '0802 000 0299', 'LAG-DRV-0001');
-- Expected: ERROR: duplicate key value violates unique constraint
--           "drivers_licence_number_key"


-- TEST 6 - ONE-TO-ONE (UNIQUE foreign key): give Tunde (driver 1) a second vehicle
UPDATE vehicles SET driver_id = 1 WHERE vehicle_id = 9;
-- Expected: ERROR: duplicate key value violates unique constraint
--           "vehicles_driver_id_key"


-- TEST 7 - CHECK (allowed words): a delivery status that is not in the list
UPDATE deliveries SET status = 'Lost' WHERE delivery_id = 9;
-- Expected: ERROR: new row for relation "deliveries" violates check constraint
--           "deliveries_status_check"


-- TEST 8 - CHECK (two columns): a deadline before the booking time
UPDATE deliveries SET promised_by = '2026-11-01 08:00' WHERE delivery_id = 1;
-- Expected: ERROR: new row for relation "deliveries" violates check constraint
--           "deliveries_check"
