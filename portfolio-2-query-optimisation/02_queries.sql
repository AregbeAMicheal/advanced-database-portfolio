-- =====================================================================
-- MIT 8103 - Portfolio 2: three everyday LagosLink queries
-- Run each query TWICE: before 03_create_indexes.sql and after it.
-- Highlight ONE query (from EXPLAIN down to its ;) and click Execute.
--
-- EXPLAIN ANALYZE runs the query and shows its EXECUTION PLAN: the steps
-- the database took, how many rows it read, and the time in milliseconds.
-- =====================================================================


-- Q1. Track a parcel: the full status history of delivery 30000
EXPLAIN ANALYZE
SELECT status, updated_at, note
FROM delivery_status_updates
WHERE delivery_id = 30000
ORDER BY updated_at;


-- Q2. Customer history: all deliveries of customer 250, newest first
EXPLAIN ANALYZE
SELECT delivery_id, status, delivery_fee, requested_at
FROM deliveries
WHERE customer_id = 250
ORDER BY requested_at DESC;


-- Q3. Live tracking: the latest GPS position of driver 7
EXPLAIN ANALYZE
SELECT latitude, longitude, recorded_at
FROM driver_locations
WHERE driver_id = 7
ORDER BY recorded_at DESC
LIMIT 1;
