-- =====================================================================
-- MIT 8103 Advanced Database Systems - Portfolio 2
-- LagosLink Deliveries: generate a LARGE amount of simulated data
-- Run on logistics_db AFTER Portfolio 1's 01 and 02 scripts.
--
-- Why: with only 12 deliveries every query is instant, so indexes make no
-- visible difference. With 50,000 deliveries the difference is clear.
-- generate_series(1, N) produces the numbers 1..N, one row each; random()
-- picks values. setseed() makes the "random" data the same every time.
-- Takes a few seconds. Run it ONCE.
-- =====================================================================

SELECT setseed(0.42);

-- 492 more customers (total 500)
INSERT INTO customers (full_name, phone, email, customer_type)
SELECT 'Customer ' || g,
       '0809 ' || lpad(g::text, 7, '0'),
       'customer' || g || '@example.com',
       CASE WHEN random() < 0.4 THEN 'Business' ELSE 'Individual' END
FROM generate_series(1, 492) AS g;

-- 21 more drivers (total 30), spread across the 3 hubs
INSERT INTO drivers (hub_id, full_name, phone, licence_number, status)
SELECT 1 + (g % 3), 'Driver ' || g, '0808 ' || lpad(g::text, 7, '0'),
       'LAG-DRV-' || lpad((100 + g)::text, 4, '0'), 'Available'
FROM generate_series(1, 21) AS g;

-- 50,000 deliveries between May and November 2026
WITH c AS (SELECT array_agg(customer_id) AS ids FROM customers),
     d AS (SELECT array_agg(driver_id)   AS ids FROM drivers),
     g AS (SELECT n, random() AS r,
                  timestamp '2026-05-01 07:00' + random() * interval '190 days' AS t
           FROM generate_series(1, 50000) AS n)
INSERT INTO deliveries (customer_id, hub_id, driver_id, pickup_address, dropoff_address,
                        recipient_name, recipient_phone, parcel_weight_kg, delivery_fee,
                        status, requested_at, promised_by)
SELECT c.ids[1 + floor(random() * array_length(c.ids, 1))::int],
       1 + floor(random() * 3)::int,
       CASE WHEN g.r < 0.90 THEN d.ids[1 + floor(random() * array_length(d.ids, 1))::int] END,
       'Pickup address ' || g.n, 'Drop-off address ' || g.n,
       'Recipient ' || g.n, '0807 ' || lpad(g.n::text, 7, '0'),
       round((0.5 + random() * 30)::numeric, 2),
       (1500 + floor(random() * 10) * 500)::numeric,
       CASE WHEN g.r < 0.85 THEN 'Delivered'
            WHEN g.r < 0.90 THEN 'Failed'
            ELSE 'Cancelled' END,
       g.t, g.t + interval '4 hours'
FROM g, c, d;

-- Status history for the new deliveries (one row per stage)
INSERT INTO delivery_status_updates (delivery_id, status, updated_at)
SELECT dl.delivery_id, s.status, dl.requested_at + s.mins * interval '1 minute'
FROM deliveries dl
CROSS JOIN LATERAL (VALUES ('Requested', 0), ('Assigned', 10), ('Picked up', 40),
                           ('In transit', 45), ('Delivered', 150)) AS s(status, mins)
WHERE dl.delivery_id > 12 AND dl.status = 'Delivered'
UNION ALL
SELECT dl.delivery_id, s.status, dl.requested_at + s.mins * interval '1 minute'
FROM deliveries dl
CROSS JOIN LATERAL (VALUES ('Requested', 0), ('Assigned', 10), ('Picked up', 40),
                           ('In transit', 45), ('Failed', 160)) AS s(status, mins)
WHERE dl.delivery_id > 12 AND dl.status = 'Failed'
UNION ALL
SELECT dl.delivery_id, s.status, dl.requested_at + s.mins * interval '1 minute'
FROM deliveries dl
CROSS JOIN LATERAL (VALUES ('Requested', 0), ('Cancelled', 20)) AS s(status, mins)
WHERE dl.delivery_id > 12 AND dl.status = 'Cancelled';

-- One payment per new delivery
INSERT INTO payments (delivery_id, amount, method, payment_status, paid_at)
SELECT delivery_id, delivery_fee,
       (ARRAY['Card', 'Bank transfer', 'Cash', 'Wallet'])[1 + floor(random() * 4)::int],
       CASE WHEN status = 'Cancelled' THEN 'Reversed' ELSE 'Successful' END,
       requested_at + interval '1 minute'
FROM deliveries WHERE delivery_id > 12;

-- 200,000 GPS points: each of the 30 drivers reports every 10 seconds
WITH d AS (SELECT array_agg(driver_id ORDER BY driver_id) AS ids FROM drivers)
INSERT INTO driver_locations (driver_id, latitude, longitude, recorded_at)
SELECT d.ids[1 + (g % 30)],
       round((6.40 + random() * 0.30)::numeric, 6),
       round((3.20 + random() * 0.40)::numeric, 6),
       timestamp '2026-11-01 06:00' + g * interval '10 seconds'
FROM generate_series(1, 200000) AS g, d;

-- Update the planner's statistics so it knows how big the tables are now
ANALYZE;

-- Check: rows per table (appears in Data Output)
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'drivers',                 COUNT(*) FROM drivers
UNION ALL SELECT 'deliveries',              COUNT(*) FROM deliveries
UNION ALL SELECT 'delivery_status_updates', COUNT(*) FROM delivery_status_updates
UNION ALL SELECT 'payments',                COUNT(*) FROM payments
UNION ALL SELECT 'driver_locations',        COUNT(*) FROM driver_locations;
