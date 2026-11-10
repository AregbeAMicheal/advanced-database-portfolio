-- =====================================================================
-- MIT 8103 Advanced Database Systems - Portfolio 3 (part 1, ONE window)
-- LagosLink Deliveries: COMMIT, ROLLBACK and automatic rollback on error
--
-- A TRANSACTION is a group of changes that must succeed or fail TOGETHER.
--   BEGIN    = start the group
--   COMMIT   = save every change in the group permanently
--   ROLLBACK = cancel every change in the group, as if it never happened
--
-- How to run: highlight ONE step (from its first line down to its last ;)
-- and click Execute. Do the steps in order. Screenshot each result.
-- =====================================================================


-- ---------------------------------------------------------------------
-- EXERCISE 1 - COMMIT: assign delivery 12 to driver Grace Okafor (driver 8)
-- Three tables must change together, or the data would disagree.
-- ---------------------------------------------------------------------

-- STEP 1.1  Look BEFORE (expect: Requested, no driver, Grace Available, 1 history row)
SELECT d.delivery_id, d.status, d.driver_id,
       (SELECT status   FROM drivers WHERE driver_id = 8)                  AS grace_status,
       (SELECT COUNT(*) FROM delivery_status_updates WHERE delivery_id = 12) AS history_rows
FROM deliveries d WHERE d.delivery_id = 12;

-- STEP 1.2  The transaction: all three changes, then COMMIT
BEGIN;
UPDATE deliveries SET driver_id = 8, status = 'Assigned' WHERE delivery_id = 12;
INSERT INTO delivery_status_updates (delivery_id, status, note)
VALUES (12, 'Assigned', 'Assigned to Grace Okafor');
UPDATE drivers SET status = 'On delivery' WHERE driver_id = 8;
COMMIT;

-- STEP 1.3  Look AFTER (expect: Assigned, driver 8, Grace On delivery, 2 history rows)
SELECT d.delivery_id, d.status, d.driver_id,
       (SELECT status   FROM drivers WHERE driver_id = 8)                  AS grace_status,
       (SELECT COUNT(*) FROM delivery_status_updates WHERE delivery_id = 12) AS history_rows
FROM deliveries d WHERE d.delivery_id = 12;


-- ---------------------------------------------------------------------
-- EXERCISE 2 - ROLLBACK: a cash payment recorded by mistake is undone
-- Delivery 11's cash payment is Pending. A clerk marks it Successful,
-- then the driver reports the cash was never collected, so it is cancelled.
-- ---------------------------------------------------------------------

-- STEP 2.1  Look BEFORE (expect: Pending, paid_at empty)
SELECT payment_id, delivery_id, amount, method, payment_status, paid_at
FROM payments WHERE delivery_id = 11;

-- STEP 2.2  Start a transaction, make the change, and look INSIDE it (expect: Successful)
BEGIN;
UPDATE payments SET payment_status = 'Successful', paid_at = CURRENT_TIMESTAMP
WHERE delivery_id = 11;
SELECT payment_id, delivery_id, amount, method, payment_status, paid_at
FROM payments WHERE delivery_id = 11;

-- STEP 2.3  Cancel it with ROLLBACK, then look again (expect: back to Pending, paid_at empty)
ROLLBACK;
SELECT payment_id, delivery_id, amount, method, payment_status, paid_at
FROM payments WHERE delivery_id = 11;


-- ---------------------------------------------------------------------
-- EXERCISE 3 - ERROR: one failed statement undoes the whole transaction
-- Grace picks up delivery 12. The history row is added, but the status
-- update has a typo ('Picked-up' is not an allowed status), so it fails.
-- ---------------------------------------------------------------------

-- STEP 3.1  Run the transaction (expect: a red ERROR on the UPDATE)
BEGIN;
INSERT INTO delivery_status_updates (delivery_id, status, note)
VALUES (12, 'Picked up', 'Parcel collected');
UPDATE deliveries SET status = 'Picked-up' WHERE delivery_id = 12;

-- STEP 3.2  End the failed transaction (a WARNING "no transaction in progress" is fine)
ROLLBACK;

-- STEP 3.3  Check (expect: status still Assigned, and 0 'Picked up' rows:
--           the INSERT that worked was undone too)
SELECT d.status,
       (SELECT COUNT(*) FROM delivery_status_updates
        WHERE delivery_id = 12 AND status = 'Picked up') AS picked_up_rows
FROM deliveries d WHERE d.delivery_id = 12;


-- ---------------------------------------------------------------------
-- OPTIONAL RESET: puts delivery 12 and Grace back to the start of
-- Exercise 1, so the exercises can be demonstrated again.
-- ---------------------------------------------------------------------
BEGIN;
DELETE FROM delivery_status_updates WHERE delivery_id = 12 AND status = 'Assigned';
UPDATE deliveries SET driver_id = NULL, status = 'Requested' WHERE delivery_id = 12;
UPDATE drivers SET status = 'Available' WHERE driver_id = 8;
COMMIT;
