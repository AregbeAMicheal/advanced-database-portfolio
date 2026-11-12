// =====================================================================
// MIT 8103 - Portfolio 4: NoSQL queries on LagosLink (MongoDB)
// Run AFTER 01_load_lagoslink.js, in the Compass _MONGOSH shell, with
// "use logistics_db" active. Paste ONE query at a time, press Enter,
// and take a screenshot of the result.
// =====================================================================

// Q1. Track a parcel: ONE read returns the delivery and its full history
//     (in PostgreSQL this needed deliveries JOIN delivery_status_updates)
db.deliveries.findOne(
  { _id: 9 },
  { 'customer.name': 1, 'hub.name': 1, status: 1, promised_by: 1, status_history: 1, payments: 1 }
)


// Q2. Move parcel 9 to "Delivered": status and history change in ONE atomic
//     single-document update (no multi-table transaction needed)
db.deliveries.updateOne(
  { _id: 9, status: 'In transit' },
  { $set: { status: 'Delivered' },
    $push: { status_history: { status: 'Delivered', at: new Date(), note: 'Handed to recipient' } } }
)
db.deliveries.findOne({ _id: 9 }, { status: 1, status_history: { $slice: -2 } })


// Q3. Operations report: deliveries, revenue and on-time rate per hub
//     (aggregation pipeline; "delivered at" = last entry of the history)
db.deliveries.aggregate([
  { $match: { status: 'Delivered' } },
  { $addFields: { delivered_at: { $last: '$status_history.at' } } },
  { $group: {
      _id: '$hub.name',
      deliveries: { $sum: 1 },
      revenue_naira: { $sum: '$fee' },
      on_time: { $sum: { $cond: [{ $lte: ['$delivered_at', '$promised_by'] }, 1, 0] } } } },
  { $project: { _id: 0, hub: '$_id', deliveries: 1, revenue_naira: 1,
      on_time_pct: { $round: [{ $multiply: [{ $divide: ['$on_time', '$deliveries'] }, 100] }, 1] } } },
  { $sort: { revenue_naira: -1 } }
])


// Q4. Match a request: the 3 nearest AVAILABLE drivers to a pickup at
//     27 Akoka Road, Yaba (uses the 2dsphere index on drivers.location)
db.drivers.aggregate([
  { $geoNear: {
      near: { type: 'Point', coordinates: [3.3920, 6.5200] },
      distanceField: 'distance_m',
      query: { status: 'Available' },
      spherical: true } },
  { $limit: 3 },
  { $project: { _id: 0, name: 1, vehicle: 1, hub_id: 1,
      distance_km: { $round: [{ $divide: ['$distance_m', 1000] }, 2] } } }
])


// Q5. Referencing: join the driver's details into a delivery with $lookup
//     (drivers are referenced, not embedded, because their status and
//      location change many times a day)
db.deliveries.aggregate([
  { $match: { _id: 10 } },
  { $lookup: { from: 'drivers', localField: 'driver_id', foreignField: '_id', as: 'driver' } },
  { $project: { status: 1, 'customer.name': 1,
      'driver.name': 1, 'driver.phone': 1, 'driver.vehicle': 1, 'driver.status': 1 } }
])


// Q6. Schema validation: a delivery with an invalid status is REJECTED
//     (expect: MongoServerError: Document failed validation)
db.deliveries.insertOne({
  customer: { customer_id: 2, name: 'Musa Bello', phone: '0801 000 0102' },
  hub: { hub_id: 2, name: 'Yaba Hub' },
  status: 'Lost', fee: 3000,
  requested_at: new Date(), promised_by: new Date(Date.now() + 4 * 3600000),
  status_history: [{ status: 'Requested', at: new Date() }]
})


// Q7. Index evidence: the customer-history query uses the index (IXSCAN, 5 docs read)
//     compared with forcing a full collection scan (COLLSCAN, every document read)
var withIndex = db.deliveries.find({ 'customer.customer_id': 3 }).sort({ requested_at: -1 }).limit(5).explain('executionStats').executionStats;
var fullScan = db.deliveries.find({ 'customer.customer_id': 3 }).sort({ requested_at: -1 }).limit(5).hint({ $natural: 1 }).explain('executionStats').executionStats;
var stages = (s) => { var c = []; while (s) { c.push(s.stage + (s.indexName ? ' (' + s.indexName + ')' : '')); s = s.inputStage; } return c.join(' <- '); };
({ with_index: { plan: stages(withIndex.executionStages), docs_examined: withIndex.totalDocsExamined, returned: withIndex.nReturned, ms: withIndex.executionTimeMillis },
   full_scan:  { plan: stages(fullScan.executionStages), docs_examined: fullScan.totalDocsExamined, returned: fullScan.nReturned, ms: fullScan.executionTimeMillis } })
