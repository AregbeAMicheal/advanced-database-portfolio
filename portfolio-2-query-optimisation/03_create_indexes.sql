-- =====================================================================
-- MIT 8103 - Portfolio 2: indexes for the three queries
-- Run this whole file once, then run the 3 queries in 02_queries.sql again.
--
-- An index is like the index at the back of a textbook: instead of reading
-- every page (a Sequential Scan), the database jumps straight to the rows
-- it needs (an Index Scan).
--
-- Note: PostgreSQL automatically indexes PRIMARY KEY and UNIQUE columns,
-- but NOT foreign key columns. The three columns below are foreign keys
-- that our queries search on, so they need indexes added by hand.
-- =====================================================================

-- Q1: find one delivery's history, already sorted by time
CREATE INDEX idx_status_updates_delivery_time
    ON delivery_status_updates (delivery_id, updated_at);

-- Q2: find one customer's deliveries, already sorted newest first
CREATE INDEX idx_deliveries_customer_requested
    ON deliveries (customer_id, requested_at DESC);

-- Q3: find one driver's latest GPS point
CREATE INDEX idx_driver_locations_driver_time
    ON driver_locations (driver_id, recorded_at DESC);

ANALYZE;

-- The cost of indexes: they take disk space (and slow down inserts a little)
SELECT indexrelname AS index_name,
       relname      AS table_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE indexrelname LIKE 'idx_%'
ORDER BY indexrelname;
