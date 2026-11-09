-- =====================================================================
-- MIT 8103 Advanced Database Systems - Portfolio 1
-- LagosLink Deliveries (simulated): sample data for the 8 tables
-- Run AFTER 01_create_tables.sql, in the Query Tool on logistics_db.
--
-- All names, phone numbers, plates and addresses are MADE UP.
--
-- We type the ID numbers ourselves (1, 2, 3...) so the links are easy
-- to read: e.g. a delivery with customer_id 1 belongs to customer 1.
-- At the end, setval() tells each ID counter to carry on after the
-- highest number, so new rows added later get the next free number.
--
-- pgAdmin runs this whole file as ONE transaction: if any line fails,
-- nothing is saved, so you can fix it and run it again safely.
-- =====================================================================


-- 1. Hubs (3)
INSERT INTO hubs (hub_id, hub_name, address, phone) VALUES
 (1, 'Ikeja Hub', '12 Obafemi Awolowo Way, Ikeja, Lagos', '0801 000 1001'),
 (2, 'Yaba Hub',  '45 Herbert Macaulay Way, Yaba, Lagos', '0801 000 1002'),
 (3, 'Lekki Hub', '8 Admiralty Way, Lekki Phase 1, Lagos', '0801 000 1003');


-- 2. Customers (8): businesses and individuals
INSERT INTO customers (customer_id, full_name, phone, email, customer_type) VALUES
 (1, 'Ada Stores',        '0801 000 0101', 'orders@adastores.example',   'Business'),
 (2, 'Musa Bello',        '0801 000 0102', 'musa.bello@example.com',     'Individual'),
 (3, 'Chika Foods',       '0801 000 0103', 'dispatch@chikafoods.example','Business'),
 (4, 'Funke Adeyemi',     '0801 000 0104', NULL,                         'Individual'),
 (5, 'Okon Pharmacy',     '0801 000 0105', 'okon.pharmacy@example.com',  'Business'),
 (6, 'Ibrahim Yusuf',     '0801 000 0106', 'i.yusuf@example.com',        'Individual'),
 (7, 'Zainab Fashion Hub','0801 000 0107', 'hello@zainabfashion.example','Business'),
 (8, 'Tolu Ogunleye',     '0801 000 0108', NULL,                         'Individual');


-- 3. Drivers (9): three per hub
INSERT INTO drivers (driver_id, hub_id, full_name, phone, licence_number, status) VALUES
 (1, 1, 'Tunde Bakare',    '0802 000 0201', 'LAG-DRV-0001', 'Available'),
 (2, 1, 'Femi Adeleke',    '0802 000 0202', 'LAG-DRV-0002', 'On delivery'),
 (3, 1, 'Kelechi Obi',     '0802 000 0203', 'LAG-DRV-0003', 'Off duty'),
 (4, 2, 'Ngozi Eze',       '0802 000 0204', 'LAG-DRV-0004', 'On delivery'),
 (5, 2, 'Sola Ojo',        '0802 000 0205', 'LAG-DRV-0005', 'Available'),
 (6, 2, 'Emeka Nwosu',     '0802 000 0206', 'LAG-DRV-0006', 'Available'),
 (7, 3, 'Bola Ahmed',      '0802 000 0207', 'LAG-DRV-0007', 'On delivery'),
 (8, 3, 'Grace Okafor',    '0802 000 0208', 'LAG-DRV-0008', 'Available'),
 (9, 3, 'Yemi Alade',      '0802 000 0209', 'LAG-DRV-0009', 'Off duty');


-- 4. Vehicles (9): one per driver for drivers 1-8, plus a spare van with no driver
INSERT INTO vehicles (vehicle_id, driver_id, plate_number, vehicle_type, capacity_kg) VALUES
 (1, 1,    'LND 101 AA', 'Motorbike', 150.0),
 (2, 2,    'LND 102 AA', 'Van',       1200.0),
 (3, 3,    'LND 103 AA', 'Motorbike', 150.0),
 (4, 4,    'KJA 201 BB', 'Motorbike', 150.0),
 (5, 5,    'KJA 202 BB', 'Van',       1000.0),
 (6, 6,    'KJA 203 BB', 'Motorbike', 120.0),
 (7, 7,    'LSD 301 CC', 'Van',       1200.0),
 (8, 8,    'LSD 302 CC', 'Motorbike', 150.0),
 (9, NULL, 'LSD 303 CC', 'Van',       1500.0);   -- spare van: no driver yet


-- 5. Deliveries (12) in different stages
INSERT INTO deliveries (delivery_id, customer_id, hub_id, driver_id, pickup_address, dropoff_address,
                        recipient_name, recipient_phone, parcel_weight_kg, delivery_fee, status,
                        requested_at, promised_by) VALUES
 (1,  1, 1, 1,    '10 Allen Avenue, Ikeja',      '22 Opebi Road, Ikeja',          'Kemi Lawal',     '0803 000 0301', 2.50,  2500.00, 'Delivered',  '2026-11-02 09:00', '2026-11-02 13:00'),
 (2,  1, 1, 2,    '10 Allen Avenue, Ikeja',      '5 Toyin Street, Ikeja',         'Dayo Bello',     '0803 000 0302', 40.00, 6000.00, 'Delivered',  '2026-11-02 10:30', '2026-11-02 16:30'),
 (3,  3, 2, 4,    '3 Commercial Ave, Yaba',      '14 Ojuelegba Road, Surulere',   'Uche Okeke',     '0803 000 0303', 5.00,  3000.00, 'Delivered',  '2026-11-03 08:15', '2026-11-03 11:15'),
 (4,  2, 2, 5,    '27 Akoka Road, Yaba',         '9 Adeola Odeku, Victoria Island','Musa Bello',    '0801 000 0102', 1.20,  3500.00, 'Delivered',  '2026-11-03 12:00', '2026-11-03 15:00'),
 (5,  5, 3, 7,    '6 Admiralty Road, Lekki',     '18 Ajah Market Road, Ajah',     'Halima Musa',    '0803 000 0305', 12.00, 4500.00, 'Delivered',  '2026-11-04 09:45', '2026-11-04 12:45'),
 (6,  7, 3, 8,    '2 Fola Osibo Road, Lekki',    '40 Bourdillon Road, Ikoyi',     'Ronke Ade',      '0803 000 0306', 3.00,  4000.00, 'Failed',     '2026-11-04 14:00', '2026-11-04 18:00'),
 (7,  4, 1, NULL, '15 Obafemi Awolowo Way, Ikeja','7 Ikorodu Road, Maryland',     'Bisi Adeyemi',   '0803 000 0307', 0.80,  2000.00, 'Cancelled',  '2026-11-05 10:00', '2026-11-05 14:00'),
 (8,  6, 2, 6,    '11 Herbert Macaulay Way, Yaba','21 Western Avenue, Surulere',  'Aisha Yusuf',    '0803 000 0308', 2.00,  2500.00, 'Delivered',  '2026-11-06 11:00', '2026-11-06 14:00'),
 (9,  3, 2, 4,    '3 Commercial Ave, Yaba',      '30 Ogba Road, Ogba',            'Peter Okafor',   '0803 000 0309', 8.50,  4000.00, 'In transit', '2026-11-09 09:00', '2026-11-09 13:00'),
 (10, 1, 1, 2,    '10 Allen Avenue, Ikeja',      '4 Isaac John Street, GRA Ikeja','Nneka Obi',      '0803 000 0310', 25.00, 5500.00, 'Picked up',  '2026-11-09 10:00', '2026-11-09 15:00'),
 (11, 5, 3, 7,    '6 Admiralty Road, Lekki',     '12 Chevron Drive, Lekki',       'Kunle Ajayi',    '0803 000 0311', 4.00,  3000.00, 'Assigned',   '2026-11-09 11:30', '2026-11-09 15:30'),
 (12, 8, 3, NULL, '9 Admiralty Way, Lekki',      '33 Ozumba Mbadiwe Ave, VI',     'Tolu Ogunleye',  '0801 000 0108', 1.50,  3500.00, 'Requested',  '2026-11-09 12:15', '2026-11-09 17:15');


-- 6. Delivery status updates: the tracking history of each delivery
INSERT INTO delivery_status_updates (delivery_id, status, updated_at, note) VALUES
 (1, 'Requested',  '2026-11-02 09:00', NULL),
 (1, 'Assigned',   '2026-11-02 09:10', NULL),
 (1, 'Picked up',  '2026-11-02 09:40', NULL),
 (1, 'In transit', '2026-11-02 09:45', NULL),
 (1, 'Delivered',  '2026-11-02 10:30', 'Handed to recipient'),
 (2, 'Requested',  '2026-11-02 10:30', NULL),
 (2, 'Assigned',   '2026-11-02 10:50', 'Van needed: 40 kg'),
 (2, 'Picked up',  '2026-11-02 12:00', NULL),
 (2, 'In transit', '2026-11-02 12:10', NULL),
 (2, 'Delivered',  '2026-11-02 17:20', 'Late: heavy traffic on Ikorodu Road'),
 (3, 'Requested',  '2026-11-03 08:15', NULL),
 (3, 'Assigned',   '2026-11-03 08:20', NULL),
 (3, 'Picked up',  '2026-11-03 08:50', NULL),
 (3, 'In transit', '2026-11-03 08:55', NULL),
 (3, 'Delivered',  '2026-11-03 10:05', NULL),
 (4, 'Requested',  '2026-11-03 12:00', NULL),
 (4, 'Assigned',   '2026-11-03 12:05', NULL),
 (4, 'Picked up',  '2026-11-03 12:40', NULL),
 (4, 'In transit', '2026-11-03 12:45', NULL),
 (4, 'Delivered',  '2026-11-03 14:20', NULL),
 (5, 'Requested',  '2026-11-04 09:45', NULL),
 (5, 'Assigned',   '2026-11-04 09:55', NULL),
 (5, 'Picked up',  '2026-11-04 10:30', NULL),
 (5, 'In transit', '2026-11-04 10:35', NULL),
 (5, 'Delivered',  '2026-11-04 12:10', NULL),
 (6, 'Requested',  '2026-11-04 14:00', NULL),
 (6, 'Assigned',   '2026-11-04 14:10', NULL),
 (6, 'Picked up',  '2026-11-04 14:45', NULL),
 (6, 'In transit', '2026-11-04 14:50', NULL),
 (6, 'Failed',     '2026-11-04 16:30', 'Recipient not at home'),
 (7, 'Requested',  '2026-11-05 10:00', NULL),
 (7, 'Cancelled',  '2026-11-05 10:20', 'Customer cancelled before pickup'),
 (8, 'Requested',  '2026-11-06 11:00', NULL),
 (8, 'Assigned',   '2026-11-06 11:05', NULL),
 (8, 'Picked up',  '2026-11-06 11:35', NULL),
 (8, 'In transit', '2026-11-06 11:40', NULL),
 (8, 'Delivered',  '2026-11-06 12:50', NULL),
 (9, 'Requested',  '2026-11-09 09:00', NULL),
 (9, 'Assigned',   '2026-11-09 09:05', NULL),
 (9, 'Picked up',  '2026-11-09 09:40', NULL),
 (9, 'In transit', '2026-11-09 09:45', NULL),
 (10, 'Requested', '2026-11-09 10:00', NULL),
 (10, 'Assigned',  '2026-11-09 10:15', 'Van needed: 25 kg'),
 (10, 'Picked up', '2026-11-09 11:00', NULL),
 (11, 'Requested', '2026-11-09 11:30', NULL),
 (11, 'Assigned',  '2026-11-09 11:40', NULL),
 (12, 'Requested', '2026-11-09 12:15', NULL);


-- 7. Payments: delivery 4 had a failed card payment, then a successful bank transfer
INSERT INTO payments (delivery_id, amount, method, payment_status, paid_at) VALUES
 (1,  2500.00, 'Card',          'Successful', '2026-11-02 09:01'),
 (2,  6000.00, 'Bank transfer', 'Successful', '2026-11-02 10:35'),
 (3,  3000.00, 'Wallet',        'Successful', '2026-11-03 08:16'),
 (4,  3500.00, 'Card',          'Failed',     NULL),
 (4,  3500.00, 'Bank transfer', 'Successful', '2026-11-03 12:03'),
 (5,  4500.00, 'Card',          'Successful', '2026-11-04 09:46'),
 (6,  4000.00, 'Cash',          'Successful', '2026-11-04 14:01'),
 (7,  2000.00, 'Card',          'Reversed',   '2026-11-05 10:01'),
 (8,  2500.00, 'Wallet',        'Successful', '2026-11-06 11:01'),
 (9,  4000.00, 'Bank transfer', 'Successful', '2026-11-09 09:02'),
 (10, 5500.00, 'Card',          'Successful', '2026-11-09 10:01'),
 (11, 3000.00, 'Cash',          'Pending',    NULL),
 (12, 3500.00, 'Card',          'Pending',    NULL);


-- 8. Driver locations: recent GPS points for drivers who are out on a delivery
INSERT INTO driver_locations (driver_id, latitude, longitude, recorded_at) VALUES
 (4, 6.509500, 3.371100, '2026-11-09 09:45'),   -- Ngozi leaving Yaba
 (4, 6.548300, 3.367600, '2026-11-09 10:05'),
 (4, 6.571100, 3.367200, '2026-11-09 10:25'),   -- passing Maryland
 (2, 6.601800, 3.351500, '2026-11-09 11:00'),   -- Femi at Ikeja pickup
 (2, 6.586000, 3.357000, '2026-11-09 11:20'),
 (7, 6.469800, 3.585200, '2026-11-09 11:45'),   -- Bola at Lekki Hub
 (7, 6.448100, 3.533700, '2026-11-09 12:00');


-- Tell each ID counter to carry on after the highest number used above
SELECT setval('hubs_hub_id_seq',           (SELECT MAX(hub_id)      FROM hubs));
SELECT setval('customers_customer_id_seq', (SELECT MAX(customer_id) FROM customers));
SELECT setval('drivers_driver_id_seq',     (SELECT MAX(driver_id)   FROM drivers));
SELECT setval('vehicles_vehicle_id_seq',   (SELECT MAX(vehicle_id)  FROM vehicles));
SELECT setval('deliveries_delivery_id_seq',(SELECT MAX(delivery_id) FROM deliveries));


-- Check: how many rows each table now has (this table appears in Data Output)
SELECT 'hubs' AS table_name,  COUNT(*) AS row_count FROM hubs
UNION ALL SELECT 'customers',               COUNT(*) FROM customers
UNION ALL SELECT 'drivers',                 COUNT(*) FROM drivers
UNION ALL SELECT 'vehicles',                COUNT(*) FROM vehicles
UNION ALL SELECT 'deliveries',              COUNT(*) FROM deliveries
UNION ALL SELECT 'delivery_status_updates', COUNT(*) FROM delivery_status_updates
UNION ALL SELECT 'payments',                COUNT(*) FROM payments
UNION ALL SELECT 'driver_locations',        COUNT(*) FROM driver_locations;
