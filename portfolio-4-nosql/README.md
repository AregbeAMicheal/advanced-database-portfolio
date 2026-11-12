# Portfolio 4: NoSQL and Advanced Data Models

**Case study:** LagosLink Deliveries (simulated), the same business as [Portfolios 1 to 3](../README.md), now modelled in a **document database**.

**Tools:** MongoDB Atlas (free cloud cluster `AregbeAM`), MongoDB Compass and its built-in `mongosh` shell. **Database:** `logistics_db`.

## Files in this folder

| File | What it is |
|---|---|
| [`01_load_lagoslink.js`](01_load_lagoslink.js) | Creates the collections, the validation rules and the indexes, and loads the data |
| [`02_queries.js`](02_queries.js) | Seven queries that show how the model is used |
| [`screenshots/`](screenshots/) | The output of each step, from Compass connected to Atlas |

**How to repeat it:** in the Compass shell, run `use logistics_db`, paste `01_load_lagoslink.js` once, then paste each query from `02_queries.js` one at a time. The loader uses a fixed random seed, so it produces the same data every time.

## 1. Why a document model suits LagosLink

The relational design from Portfolio 1 is normalised: a delivery's details, its tracking history and its payments live in three tables and are joined when needed. That avoids repeated data, but the most frequent operation in a delivery business is reading **one parcel with everything about it**: the customer's tracking page, the driver's app and the support desk all do this thousands of times a day.

A document database stores data in the shape the application reads it:

- **One read, no joins:** a delivery document holds its customer details, hub, status history and payments, so tracking a parcel is a single lookup (Q1).
- **Atomic updates without a transaction:** changing the status and adding the history entry happen in one single-document update (Q2). In PostgreSQL this needed a multi-table transaction (Portfolio 3).
- **Flexible structure:** a delivery can carry extra fields (for example a note, a proof-of-delivery photo link, or a cash-on-delivery amount) without changing a table definition.
- **Built-in geospatial queries:** GeoJSON locations and a `2dsphere` index find the nearest available driver to a pickup point (Q4).
- **Scales out:** documents that are read together are stored together, which suits replication and sharding across servers (Portfolio 5).

## 2. The data model

Three collections:

| Collection | One document is… | Count |
|---|---|---|
| `hubs` | a hub, with its GeoJSON location | 3 |
| `drivers` | a driver, with their current GeoJSON location, vehicle and status | 9 |
| `deliveries` | a delivery, with embedded customer, hub, status history and payments | 2,012 (12 from Portfolio 1 + 2,000 simulated) |

An example delivery document (delivery 9, before Q2):

```json
{
  "_id": 9,
  "customer": { "customer_id": 3, "name": "Chika Foods", "phone": "0801 000 0103", "type": "Business" },
  "hub": { "hub_id": 2, "name": "Yaba Hub" },
  "driver_id": 4,
  "pickup": "3 Commercial Ave, Yaba",
  "dropoff": "30 Ogba Road, Ogba",
  "parcel_weight_kg": 8.5,
  "fee": 4000,
  "status": "In transit",
  "requested_at": "2026-11-09T09:00+01:00",
  "promised_by": "2026-11-09T13:00+01:00",
  "status_history": [
    { "status": "Requested",  "at": "2026-11-09T09:00+01:00" },
    { "status": "Assigned",   "at": "2026-11-09T09:05+01:00" },
    { "status": "Picked up",  "at": "2026-11-09T09:40+01:00" },
    { "status": "In transit", "at": "2026-11-09T09:45+01:00" }
  ],
  "payments": [ { "amount": 4000, "method": "Bank transfer", "status": "Successful", "paid_at": "2026-11-09T09:02+01:00" } ]
}
```

### Embedding or referencing

| Data | Decision | Reason |
|---|---|---|
| Status history | **Embedded** array | Always read with its delivery; bounded (at most a handful of stages); never read on its own |
| Payments | **Embedded** array | Belong to one delivery; usually one or two attempts |
| Customer name and phone | **Embedded** as a snapshot | The tracking page and receipts need them; keeps the details as they were when the delivery was booked |
| Hub name | **Embedded** with `hub_id` | Read with every delivery; changes very rarely |
| Driver | **Referenced** (`driver_id`) | A driver's status and location change many times a day; copying them into every delivery would leave thousands of out-of-date copies. Joined with `$lookup` when needed (Q5) |
| GPS history | **Not embedded** | It grows without limit. Only the current position is kept on the driver; a long history would belong in a separate (time-series) collection |

### Rules and indexes

- **JSON Schema validator** on `deliveries`: required fields, `status` limited to the 7 stages, `fee` must be a non-negative number, and each history entry must have a valid status and a time. This plays the role of Portfolio 1's `CHECK` and `NOT NULL` constraints (Q6).
- **`2dsphere` index** on `drivers.location` for nearest-driver searches (Q4).
- **Compound index** `{ "customer.customer_id": 1, requested_at: -1 }` for a customer's history, newest first (Q7).

### Other NoSQL models considered

| Model | Where it would fit in LagosLink |
|---|---|
| **Key-value** (e.g. Redis) | A fast cache of each driver's latest position or a parcel's current status, read many times a second |
| **Column-family** (e.g. Cassandra) | Very large volumes of GPS points written continuously by thousands of drivers |
| **Graph** (e.g. Neo4j) | The road network between hubs and areas, for route planning |

The document model was chosen because the core object, a delivery with its history, is naturally one document.

## 3. Implementation evidence

Loading the data printed `hubs: 3`, `drivers: 9`, `deliveries: 2012` ([screenshot](screenshots/01_data_loaded.png)).

| # | Query | Result | Evidence |
|---|---|---|---|
| Q1 | Track parcel 9: `findOne` with a projection | One document containing the status, the four history entries and the payment. No join | screenshot [part 1](screenshots/02_q1_track_parcel_part1.png), [part 2](screenshots/02_q1_track_parcel_part2.png) |
| Q2 | Mark parcel 9 as delivered: `updateOne` with `$set` and `$push` | Parcel 9's status became `Delivered` and a new history entry (`Delivered`, "Handed to recipient", with the time of the update) was added. Both changed together in one atomic single-document update | [screenshot](screenshots/03_q2_update_status.png) |
| Q3 | Hub report: aggregation pipeline (`$match`, `$addFields`, `$group`, `$project`, `$sort`) | Ikeja Hub 599 deliveries, ₦2,295,000, 61.3% on time; Yaba Hub 611, ₦2,272,000, 62.5%; Lekki Hub 547, ₦2,045,000, 62.5% | [screenshot](screenshots/04_q3_hub_report.png) |
| Q4 | Nearest available drivers to a pickup at 27 Akoka Road, Yaba: `$geoNear` | Sola Ojo 1.86 km (van), Emeka Nwosu 4.71 km, Tunde Bakare 9.71 km. Drivers who are busy or off duty were excluded | [screenshot](screenshots/05_q4_nearest_driver.png) |
| Q5 | Delivery 10 with its driver: `$lookup` | Femi Adeleke, van, "On delivery", joined from `drivers` | [screenshot](screenshots/06_q5_lookup_driver.png) |
| Q6 | Insert a delivery with status "Lost" | Rejected: `Document failed validation`. The count stayed at 2,012, so nothing was saved (the same rule as Portfolio 1, test 7) | [screenshot](screenshots/07_q6_validation_rejected.png) |
| Q7 | A customer's last 5 deliveries, with and without the index | With the index: `IXSCAN`, **5** documents examined. Forced full scan: `COLLSCAN` then `SORT`, **2,012** documents examined. Both took about 1 ms because the collection is small; the number of documents read is the real difference, and it grows with the data | [screenshot](screenshots/08_q7_index_vs_scan.png) |

## 4. Relational (Portfolio 1) compared with document (Portfolio 4)

| Aspect | PostgreSQL design | MongoDB design |
|---|---|---|
| Structure | 8 normalised tables (3NF) | 3 collections; history and payments embedded |
| Tracking a parcel | Join of 3 tables | One document read |
| Updating status and history | Transaction across 2 tables | One atomic single-document update |
| Rules | Column types, keys, `CHECK`, foreign keys | JSON Schema validator; no foreign keys (the application keeps `driver_id` valid) |
| Repeated data | None (each fact stored once) | Customer and hub details copied into deliveries |
| Ad-hoc reporting across entities | Very strong (SQL joins) | Possible with aggregation pipelines and `$lookup`, but less natural |
| Scaling | Mostly vertical | Designed for replication and sharding (Portfolio 5) |

## 5. Trade-offs and limitations

- **Duplication:** if a customer changes their phone number, older deliveries keep the old one. Here that is acceptable, even useful, because a delivery record should show the details as they were at the time. If current details were always needed, the customer would be referenced instead.
- **No foreign keys:** MongoDB will accept a `driver_id` that does not exist; the application must check it. PostgreSQL enforced this automatically (Portfolio 1, test 2).
- **Document size:** a document is limited to 16 MB, which is why unbounded data such as GPS history is not embedded.
- **Multi-document changes:** assigning a driver changes both a delivery and a driver document. MongoDB supports multi-document transactions for this, but single-document updates are simpler and faster, so the model keeps most changes inside one document.
- **The data is simulated**, and the free cluster has a 512 MB limit and shared resources, so timings are not representative of a production system.

## 6. My observations

> What stood out to me is that the queries a delivery company runs most often were the simplest ones here: tracking parcel 9 was a single read and marking it delivered was a single update, where PostgreSQL needed joins and a transaction. The cost shows up elsewhere, because copying customer details into every delivery means old records keep old phone numbers, and nothing stops a driver_id from pointing at a driver who doesn’t exist. Of everything i ran, the nearest-driver query felt closest to real operations: it quietly skipped Ngozi and Femi because they were busy, which is exactly the judgement a dispatcher makes.
