-- =====================================================================
-- MIT 8103 - Portfolio 3 (part 2): WINDOW B = Dispatcher B
-- Use together with 02_window_A.sql in another Query Tool.
-- Follow the step numbers in order. Highlight ONE step and click Execute.
-- =====================================================================


-- ===================== PART 1: ISOLATION =====================

-- STEP B2  Read the fee while A's change is NOT committed
--          (expect 3000.00: B cannot see A's uncommitted change - no dirty read)
SELECT delivery_id, delivery_fee FROM deliveries WHERE delivery_id = 90001;

-- (now go to Window A, step A3)

-- STEP B4  Read again after A committed (expect 5000.00)
SELECT delivery_id, delivery_fee FROM deliveries WHERE delivery_id = 90001;

-- STEP B5  Start a REPEATABLE READ transaction and read (expect 5000.00)
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT delivery_id, delivery_fee FROM deliveries WHERE delivery_id = 90001;

-- (now go to Window A, step A6)

-- STEP B7  Read again inside the same transaction
--          (expect STILL 5000.00: REPEATABLE READ keeps one snapshot)
SELECT delivery_id, delivery_fee FROM deliveries WHERE delivery_id = 90001;

-- STEP B8  End the transaction and read again (expect 4500.00)
COMMIT;
SELECT delivery_id, delivery_fee FROM deliveries WHERE delivery_id = 90001;

-- (now go to Window A, step A9)


-- ============ PART 2: CONCURRENCY - THE PROBLEM (lost update) ============

-- STEP B10  Dispatcher B checks the same job at the same time (expect: Requested, no driver)
BEGIN;
SELECT delivery_id, status, driver_id FROM deliveries WHERE delivery_id = 90001;

-- (now go to Window A, step A11)

-- STEP B12  Dispatcher B, who also saw "free", gives the job to Emeka (driver 6)
--           (expect: driver 6 - Sola's assignment has been silently overwritten)
UPDATE deliveries SET driver_id = 6, status = 'Assigned' WHERE delivery_id = 90001;
COMMIT;
SELECT delivery_id, status, driver_id FROM deliveries WHERE delivery_id = 90001;

-- (now go to Window A, steps A13 and A14)


-- ============ PART 3: CONCURRENCY - THE FIX (row lock) ============

-- STEP B15  Try to check AND LOCK the same row
--           (expect: it WAITS - "Waiting for the query to complete" - until A commits,
--            then shows Assigned, driver 5: B sees the job is already taken)
BEGIN;
SELECT delivery_id, status, driver_id FROM deliveries
WHERE delivery_id = 90001 FOR UPDATE;

-- (now go to Window A, step A16)

-- STEP B17  The job is taken, so Dispatcher B cancels and picks another job
ROLLBACK;
