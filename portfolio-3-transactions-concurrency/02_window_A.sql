-- =====================================================================
-- MIT 8103 - Portfolio 3 (part 2): WINDOW A = Dispatcher A
-- Open this file in one Query Tool, and 03_window_B.sql in a SECOND
-- Query Tool. Each Query Tool is a separate connection (a separate user).
-- Follow the step numbers in order: A1, then B2, then A3, ...
-- Highlight ONE step and click Execute. Screenshot each result.
-- =====================================================================

-- STEP A0  Setup: a new delivery for the demonstrations (run once)
INSERT INTO deliveries (delivery_id, customer_id, hub_id, pickup_address, dropoff_address,
                        recipient_name, recipient_phone, parcel_weight_kg, delivery_fee,
                        requested_at, promised_by)
VALUES (90001, 2, 2, '27 Akoka Road, Yaba', '14 Ojuelegba Road, Surulere',
        'Kola Adebayo', '0803 000 0390', 3.00, 3000.00,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '4 hours');


-- ===================== PART 1: ISOLATION =====================

-- STEP A1  Start a transaction and change the fee, but DON'T commit yet
BEGIN;
UPDATE deliveries SET delivery_fee = 5000.00 WHERE delivery_id = 90001;
SELECT delivery_id, delivery_fee FROM deliveries WHERE delivery_id = 90001;

-- (now go to Window B, step B2)

-- STEP A3  Commit the change
COMMIT;

-- (now go to Window B, steps B4 and B5)

-- STEP A6  Change the fee again (a single statement commits straight away)
UPDATE deliveries SET delivery_fee = 4500.00 WHERE delivery_id = 90001;
SELECT delivery_id, delivery_fee FROM deliveries WHERE delivery_id = 90001;

-- (now go to Window B, steps B7 and B8)


-- ============ PART 2: CONCURRENCY - THE PROBLEM (lost update) ============

-- STEP A9  Dispatcher A checks whether the job is free
BEGIN;
SELECT delivery_id, status, driver_id FROM deliveries WHERE delivery_id = 90001;

-- (now go to Window B, step B10)

-- STEP A11  Dispatcher A gives the job to Sola (driver 5) and saves
UPDATE deliveries SET driver_id = 5, status = 'Assigned' WHERE delivery_id = 90001;
COMMIT;

-- (now go to Window B, step B12)


-- ============ PART 3: CONCURRENCY - THE FIX (row lock) ============

-- STEP A13  Reset the job to unassigned
UPDATE deliveries SET driver_id = NULL, status = 'Requested' WHERE delivery_id = 90001;

-- STEP A14  Check AND LOCK the row (FOR UPDATE), then hold the transaction open
BEGIN;
SELECT delivery_id, status, driver_id FROM deliveries
WHERE delivery_id = 90001 FOR UPDATE;

-- (now go to Window B, step B15: it will WAIT)

-- STEP A16  Assign Sola and commit. This releases the lock.
UPDATE deliveries SET driver_id = 5, status = 'Assigned' WHERE delivery_id = 90001;
COMMIT;

-- (now look at Window B: it has stopped waiting. Then do B17.)

-- STEP A18  Final check (expect: Assigned to driver 5)
SELECT delivery_id, status, driver_id FROM deliveries WHERE delivery_id = 90001;
