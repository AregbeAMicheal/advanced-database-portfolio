// =====================================================================
// MIT 8103 Advanced Database Systems - Portfolio 4: NoSQL (MongoDB)
// LagosLink Deliveries (simulated) - PART 1: create and load the data
//
// Where to run: MongoDB Compass > your Atlas connection > the "_MONGOSH"
// shell at the bottom. First type   use logistics_db   and press Enter.
// Then paste this whole block and press Enter. It is safe to re-run:
// it deletes and re-creates the three LagosLink collections only.
//
// Data model (document database):
//   hubs       - 3 hubs, each with a GeoJSON location
//   drivers    - drivers, each with a GeoJSON current location (for $geoNear)
//   deliveries - one document per delivery, with the customer, hub,
//                status history and payments EMBEDDED inside it, and the
//                driver stored as a REFERENCE (driver_id)
// All names, phones and places are made up. GeoJSON is [longitude, latitude].
// =====================================================================
(function () {
  const t = (s) => new Date(s + ':00+01:00');            // Lagos time
  const STAGES = ['Requested', 'Assigned', 'Picked up', 'In transit', 'Delivered', 'Failed', 'Cancelled'];

  ['deliveries', 'drivers', 'hubs'].forEach((c) => db.getCollection(c).drop());

  // The deliveries collection enforces rules with a JSON Schema validator
  db.createCollection('deliveries', {
    validationLevel: 'strict',
    validationAction: 'error',
    validator: { $jsonSchema: {
      bsonType: 'object',
      required: ['customer', 'hub', 'status', 'fee', 'requested_at', 'promised_by', 'status_history'],
      properties: {
        customer: { bsonType: 'object', required: ['customer_id', 'name', 'phone'] },
        hub: { bsonType: 'object', required: ['hub_id', 'name'] },
        status: { enum: STAGES, description: 'must be one of the 7 delivery stages' },
        fee: { bsonType: ['int', 'long', 'double', 'decimal'], minimum: 0 },
        status_history: { bsonType: 'array', items: { bsonType: 'object', required: ['status', 'at'],
          properties: { status: { enum: STAGES } } } },
        payments: { bsonType: 'array' }
      }
    } }
  });

  // ---- hubs ----------------------------------------------------------
  const hubs = [
    { _id: 1, name: 'Ikeja Hub', address: '12 Obafemi Awolowo Way, Ikeja', location: { type: 'Point', coordinates: [3.3515, 6.6018] } },
    { _id: 2, name: 'Yaba Hub', address: '45 Herbert Macaulay Way, Yaba', location: { type: 'Point', coordinates: [3.3711, 6.5095] } },
    { _id: 3, name: 'Lekki Hub', address: '8 Admiralty Way, Lekki Phase 1', location: { type: 'Point', coordinates: [3.4723, 6.4474] } }
  ];
  db.hubs.insertMany(hubs);
  const hubRef = (id) => ({ hub_id: id, name: hubs[id - 1].name });

  // ---- drivers (current position = where the driver's phone last reported)
  const pt = (lng, lat) => ({ type: 'Point', coordinates: [lng, lat] });
  db.drivers.insertMany([
    { _id: 1, name: 'Tunde Bakare', hub_id: 1, phone: '0802 000 0201', vehicle: 'Motorbike', status: 'Available', location: pt(3.3490, 6.5960) },
    { _id: 2, name: 'Femi Adeleke', hub_id: 1, phone: '0802 000 0202', vehicle: 'Van', status: 'On delivery', location: pt(3.3570, 6.5860) },
    { _id: 3, name: 'Kelechi Obi', hub_id: 1, phone: '0802 000 0203', vehicle: 'Motorbike', status: 'Off duty', location: pt(3.3515, 6.6018) },
    { _id: 4, name: 'Ngozi Eze', hub_id: 2, phone: '0802 000 0204', vehicle: 'Motorbike', status: 'On delivery', location: pt(3.3672, 6.5711) },
    { _id: 5, name: 'Sola Ojo', hub_id: 2, phone: '0802 000 0205', vehicle: 'Van', status: 'Available', location: pt(3.3760, 6.5150) },
    { _id: 6, name: 'Emeka Nwosu', hub_id: 2, phone: '0802 000 0206', vehicle: 'Motorbike', status: 'Available', location: pt(3.3550, 6.4990) },
    { _id: 7, name: 'Bola Ahmed', hub_id: 3, phone: '0802 000 0207', vehicle: 'Van', status: 'On delivery', location: pt(3.5337, 6.4481) },
    { _id: 8, name: 'Grace Okafor', hub_id: 3, phone: '0802 000 0208', vehicle: 'Motorbike', status: 'Available', location: pt(3.4900, 6.4400) },
    { _id: 9, name: 'Yemi Alade', hub_id: 3, phone: '0802 000 0209', vehicle: 'Motorbike', status: 'Off duty', location: pt(3.4723, 6.4474) }
  ]);

  // ---- customers (embedded into each delivery as a snapshot) -----------
  const C = {
    1: { customer_id: 1, name: 'Ada Stores', phone: '0801 000 0101', type: 'Business' },
    2: { customer_id: 2, name: 'Musa Bello', phone: '0801 000 0102', type: 'Individual' },
    3: { customer_id: 3, name: 'Chika Foods', phone: '0801 000 0103', type: 'Business' },
    4: { customer_id: 4, name: 'Funke Adeyemi', phone: '0801 000 0104', type: 'Individual' },
    5: { customer_id: 5, name: 'Okon Pharmacy', phone: '0801 000 0105', type: 'Business' },
    6: { customer_id: 6, name: 'Ibrahim Yusuf', phone: '0801 000 0106', type: 'Individual' },
    7: { customer_id: 7, name: 'Zainab Fashion Hub', phone: '0801 000 0107', type: 'Business' },
    8: { customer_id: 8, name: 'Tolu Ogunleye', phone: '0801 000 0108', type: 'Individual' }
  };
  const H = (pairs) => pairs.map(([status, at, note]) => (note ? { status, at: t(at), note } : { status, at: t(at) }));

  // ---- the 12 deliveries from Portfolio 1, as documents -----------------
  const d = (id, cust, hub, driver, from, to, kg, fee, status, req, prom, history, payments) => ({
    _id: id, customer: C[cust], hub: hubRef(hub), driver_id: driver, pickup: from, dropoff: to,
    parcel_weight_kg: kg, fee, status, requested_at: t(req), promised_by: t(prom),
    status_history: H(history), payments
  });
  const day = (dd) => '2026-11-' + dd + 'T';
  const paid = (amount, method, at) => ({ amount, method, status: 'Successful', paid_at: t(at) });
  db.deliveries.insertMany([
    d(1, 1, 1, 1, '10 Allen Avenue, Ikeja', '22 Opebi Road, Ikeja', 2.5, 2500, 'Delivered', day('02') + '09:00', day('02') + '13:00',
      [['Requested', day('02') + '09:00'], ['Assigned', day('02') + '09:10'], ['Picked up', day('02') + '09:40'], ['In transit', day('02') + '09:45'], ['Delivered', day('02') + '10:30', 'Handed to recipient']],
      [paid(2500, 'Card', day('02') + '09:01')]),
    d(2, 1, 1, 2, '10 Allen Avenue, Ikeja', '5 Toyin Street, Ikeja', 40, 6000, 'Delivered', day('02') + '10:30', day('02') + '16:30',
      [['Requested', day('02') + '10:30'], ['Assigned', day('02') + '10:50', 'Van needed: 40 kg'], ['Picked up', day('02') + '12:00'], ['In transit', day('02') + '12:10'], ['Delivered', day('02') + '17:20', 'Late: heavy traffic on Ikorodu Road']],
      [paid(6000, 'Bank transfer', day('02') + '10:35')]),
    d(3, 3, 2, 4, '3 Commercial Ave, Yaba', '14 Ojuelegba Road, Surulere', 5, 3000, 'Delivered', day('03') + '08:15', day('03') + '11:15',
      [['Requested', day('03') + '08:15'], ['Assigned', day('03') + '08:20'], ['Picked up', day('03') + '08:50'], ['In transit', day('03') + '08:55'], ['Delivered', day('03') + '10:05']],
      [paid(3000, 'Wallet', day('03') + '08:16')]),
    d(4, 2, 2, 5, '27 Akoka Road, Yaba', '9 Adeola Odeku, Victoria Island', 1.2, 3500, 'Delivered', day('03') + '12:00', day('03') + '15:00',
      [['Requested', day('03') + '12:00'], ['Assigned', day('03') + '12:05'], ['Picked up', day('03') + '12:40'], ['In transit', day('03') + '12:45'], ['Delivered', day('03') + '14:20']],
      [{ amount: 3500, method: 'Card', status: 'Failed' }, paid(3500, 'Bank transfer', day('03') + '12:03')]),
    d(5, 5, 3, 7, '6 Admiralty Road, Lekki', '18 Ajah Market Road, Ajah', 12, 4500, 'Delivered', day('04') + '09:45', day('04') + '12:45',
      [['Requested', day('04') + '09:45'], ['Assigned', day('04') + '09:55'], ['Picked up', day('04') + '10:30'], ['In transit', day('04') + '10:35'], ['Delivered', day('04') + '12:10']],
      [paid(4500, 'Card', day('04') + '09:46')]),
    d(6, 7, 3, 8, '2 Fola Osibo Road, Lekki', '40 Bourdillon Road, Ikoyi', 3, 4000, 'Failed', day('04') + '14:00', day('04') + '18:00',
      [['Requested', day('04') + '14:00'], ['Assigned', day('04') + '14:10'], ['Picked up', day('04') + '14:45'], ['In transit', day('04') + '14:50'], ['Failed', day('04') + '16:30', 'Recipient not at home']],
      [paid(4000, 'Cash', day('04') + '14:01')]),
    d(7, 4, 1, null, '15 Obafemi Awolowo Way, Ikeja', '7 Ikorodu Road, Maryland', 0.8, 2000, 'Cancelled', day('05') + '10:00', day('05') + '14:00',
      [['Requested', day('05') + '10:00'], ['Cancelled', day('05') + '10:20', 'Customer cancelled before pickup']],
      [{ amount: 2000, method: 'Card', status: 'Reversed', paid_at: t(day('05') + '10:01') }]),
    d(8, 6, 2, 6, '11 Herbert Macaulay Way, Yaba', '21 Western Avenue, Surulere', 2, 2500, 'Delivered', day('06') + '11:00', day('06') + '14:00',
      [['Requested', day('06') + '11:00'], ['Assigned', day('06') + '11:05'], ['Picked up', day('06') + '11:35'], ['In transit', day('06') + '11:40'], ['Delivered', day('06') + '12:50']],
      [paid(2500, 'Wallet', day('06') + '11:01')]),
    d(9, 3, 2, 4, '3 Commercial Ave, Yaba', '30 Ogba Road, Ogba', 8.5, 4000, 'In transit', day('09') + '09:00', day('09') + '13:00',
      [['Requested', day('09') + '09:00'], ['Assigned', day('09') + '09:05'], ['Picked up', day('09') + '09:40'], ['In transit', day('09') + '09:45']],
      [paid(4000, 'Bank transfer', day('09') + '09:02')]),
    d(10, 1, 1, 2, '10 Allen Avenue, Ikeja', '4 Isaac John Street, GRA Ikeja', 25, 5500, 'Picked up', day('09') + '10:00', day('09') + '15:00',
      [['Requested', day('09') + '10:00'], ['Assigned', day('09') + '10:15', 'Van needed: 25 kg'], ['Picked up', day('09') + '11:00']],
      [paid(5500, 'Card', day('09') + '10:01')]),
    d(11, 5, 3, 7, '6 Admiralty Road, Lekki', '12 Chevron Drive, Lekki', 4, 3000, 'Assigned', day('09') + '11:30', day('09') + '15:30',
      [['Requested', day('09') + '11:30'], ['Assigned', day('09') + '11:40']],
      [{ amount: 3000, method: 'Cash', status: 'Pending' }]),
    d(12, 8, 3, null, '9 Admiralty Way, Lekki', '33 Ozumba Mbadiwe Ave, Victoria Island', 1.5, 3500, 'Requested', day('09') + '12:15', day('09') + '17:15',
      [['Requested', day('09') + '12:15']],
      [{ amount: 3500, method: 'Card', status: 'Pending' }])
  ]);

  // ---- 2,000 more simulated delivered/failed/cancelled orders (May-Oct 2026)
  // A fixed-seed generator makes the "random" data identical on every run.
  let seed = 20261110;
  const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  const pick = (arr) => arr[Math.floor(rnd() * arr.length)];
  const driversByHub = { 1: [1, 2, 3], 2: [4, 5, 6], 3: [7, 8, 9] };
  const bulk = [];
  for (let i = 1; i <= 2000; i++) {
    const hub = 1 + Math.floor(rnd() * 3);
    const req = new Date(Date.UTC(2026, 4, 1, 6, 0) + Math.floor(rnd() * 183 * 24 * 60) * 60000);
    const prom = new Date(req.getTime() + 4 * 3600000);
    const r = rnd();
    const status = r < 0.88 ? 'Delivered' : r < 0.94 ? 'Failed' : 'Cancelled';
    const fee = 1500 + Math.floor(rnd() * 10) * 500;
    const m = (mins) => new Date(req.getTime() + mins * 60000);
    const history = [{ status: 'Requested', at: req }];
    if (status !== 'Cancelled') {
      const travel = 40 + Math.floor(rnd() * 260);           // 40 to 300 minutes on the road
      history.push({ status: 'Assigned', at: m(10) }, { status: 'Picked up', at: m(35) },
        { status: 'In transit', at: m(40) }, { status, at: m(40 + travel) });
    } else {
      history.push({ status: 'Cancelled', at: m(15) });
    }
    bulk.push({
      _id: 1000 + i, customer: C[1 + Math.floor(rnd() * 8)], hub: hubRef(hub),
      driver_id: status === 'Cancelled' ? null : pick(driversByHub[hub]),
      pickup: 'Pickup address ' + i, dropoff: 'Drop-off address ' + i,
      parcel_weight_kg: Math.round((0.5 + rnd() * 30) * 10) / 10, fee, status,
      requested_at: req, promised_by: prom, status_history: history,
      payments: [{ amount: fee, method: pick(['Card', 'Bank transfer', 'Cash', 'Wallet']),
        status: status === 'Cancelled' ? 'Reversed' : 'Successful', paid_at: m(1) }]
    });
  }
  db.deliveries.insertMany(bulk);

  // Indexes: geospatial for "nearest driver", and one for a customer's history
  db.drivers.createIndex({ location: '2dsphere' });
  db.deliveries.createIndex({ 'customer.customer_id': 1, requested_at: -1 });

  print('hubs:       ' + db.hubs.countDocuments());
  print('drivers:    ' + db.drivers.countDocuments());
  print('deliveries: ' + db.deliveries.countDocuments());
})();
