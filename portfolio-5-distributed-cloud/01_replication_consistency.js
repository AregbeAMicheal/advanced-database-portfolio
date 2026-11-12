// =====================================================================
// MIT 8103 Advanced Database Systems - Portfolio 5: Distributed & Cloud
// LagosLink Deliveries on MongoDB Atlas (free cluster AregbeAM)
// Run in the Compass _MONGOSH shell with "use logistics_db" active,
// AFTER Portfolio 4's data is loaded. Paste ONE step at a time.
// =====================================================================

// STEP 1. Replication: the cluster is a REPLICA SET of 3 servers (nodes).
//         Every write goes to the primary and is copied to the secondaries.
var h = db.hello();
({ replica_set: h.setName, nodes: h.hosts, primary: h.primary, connected_to: h.me, connected_to_primary: h.isWritablePrimary })


// STEP 2. Which copy answers a read? By default reads go to the PRIMARY;
//         readPref('secondary') sends the same query to a SECONDARY copy.
var who = (e) => e.serverInfo.host + ':' + e.serverInfo.port;
({ default_read_answered_by: who(db.deliveries.find({ _id: 9 }).explain()),
   secondary_read_answered_by: who(db.deliveries.find({ _id: 9 }).readPref('secondary').explain()) })


// STEP 3. Consistency vs speed: write concern w:1 (primary only) compared
//         with w:'majority' (acknowledged only after 2 of the 3 nodes have it)
db.consistency_test.drop();
var t0 = Date.now();
for (var i = 0; i < 20; i++) db.consistency_test.insertOne({ n: i, mode: 'w1', at: new Date() }, { writeConcern: { w: 1 } });
var w1 = Date.now() - t0;
t0 = Date.now();
for (var i = 0; i < 20; i++) db.consistency_test.insertOne({ n: i, mode: 'majority', at: new Date() }, { writeConcern: { w: 'majority', wtimeout: 5000 } });
var wm = Date.now() - t0;
({ writes_each: 20, w1_avg_ms: Math.round(w1 / 20), majority_avg_ms: Math.round(wm / 20), rows_saved: db.consistency_test.countDocuments() })


// STEP 4. A payment must never be lost: confirm it with w:'majority',
//         then read it back with readConcern 'majority' (only data that a
//         majority of nodes hold, so it cannot be rolled back after a failover)
db.consistency_test.insertOne(
  { type: 'payment', delivery_id: 12, amount: 3500, method: 'Card', status: 'Successful', at: new Date() },
  { writeConcern: { w: 'majority', wtimeout: 5000 } })
db.consistency_test.find({ type: 'payment' }).readConcern('majority')


// STEP 5. Clean up the test collection
db.consistency_test.drop()
