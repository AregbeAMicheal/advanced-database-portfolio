# Portfolio 5: Distributed and Cloud Database Exercise

**Case study:** LagosLink Deliveries (simulated). The MongoDB data from [Portfolio 4](../portfolio-4-nosql/README.md), hosted in the cloud on MongoDB Atlas.

**Tools:** MongoDB Atlas (free cluster `AregbeAM`, AWS), MongoDB Compass and its `mongosh` shell. **Database:** `logistics_db`.

## Files in this folder

| File | What it is |
|---|---|
| [`01_replication_consistency.js`](01_replication_consistency.js) | Four steps that show replication, reading from different copies, and write/read consistency settings |
| [`screenshots/`](screenshots/) | Atlas configuration and the output of each step |

**How to repeat it:** in the Compass shell connected to Atlas, run `use logistics_db`, then paste each step from the script one at a time.

## 1. Cloud deployment

LagosLink's document database runs on **MongoDB Atlas**, a database-as-a-service. Atlas provisioned the servers on AWS and handles replication, software updates, monitoring and network security; the application only needs a connection string.

| Setting | Value | Why it matters |
|---|---|---|
| Cluster | `AregbeAM`, tier **Free (M0)**, MongoDB 8 | Enough for development and this exercise (512 MB storage, shared resources) |
| Provider and region | AWS, Paris (`eu-west-3`) | All three copies of the data are in one region |
| Topology | **Replica set of 3 nodes** (Atlas shows "Replica Set - 3 nodes") | Three copies of the data; the cluster survives the loss of one server |
| Access control | Database user `lagoslink_user` with a password | Applications log in with their own credentials, separate from the Atlas website login |
| Network access | IP access list containing only my own addresses, each a single `/32` entry (a second one was added when my internet connection's address changed) | Only my computer's address can connect; every other address is refused |
| Encryption in transit | TLS (the `mongodb+srv://` connection string) | Data is encrypted between the application and the cluster |

Evidence: [Atlas cluster overview](screenshots/01_atlas_cluster_overview.png), [cluster details: AWS Paris, replica set of 3 nodes](screenshots/01b_atlas_cluster_replica_set_3_nodes.png), [IP access list](screenshots/02_atlas_ip_access_list.png).

## 2. Replication

`db.hello()` reports the replica set the connection belongs to (step 1):

- **Replica set name:** `atlas-wm9buy-shard-0`
- **Nodes:** 3 (`ac-k86um4c-shard-00-00`, `ac-k86um4c-shard-00-01`, `ac-k86um4c-shard-00-02`, all `.sgghxe0.mongodb.net:27017`)
- **Primary:** `ac-k86um4c-shard-00-01` (my shell was connected to this node, and `isWritablePrimary` was `true`)

Every write goes to the **primary**, which records it in its operation log (oplog). The two **secondaries** copy the oplog and apply the same changes, so all three nodes hold the same data a moment later.

Step 2 ran the same query twice. A normal read was answered by the primary (`ac-k86um4c-shard-00-01`); with `readPref('secondary')`, the identical query was answered by a secondary (`ac-k86um4c-shard-00-02`). This shows that the data really exists on more than one server and that reads can be spread across copies.

Evidence: [step 1](screenshots/03_step1_replica_set.png), [step 2](screenshots/04_step2_primary_vs_secondary.png).

## 3. Consistency

MongoDB lets each operation choose how much safety it needs:

| Setting | Meaning | Use in LagosLink |
|---|---|---|
| Write concern `w: 1` | Acknowledged when the primary has the write | Low-value, high-volume data such as GPS points |
| Write concern `w: "majority"` | Acknowledged only after 2 of the 3 nodes have the write | Payments, delivery confirmations: anything that must never be lost |
| Read concern `"majority"` | Returns only data held by a majority of nodes, so it cannot be rolled back after a failover | Reading back payments and financial reports |
| Read preference `secondary` | Reads from a copy, which may be slightly behind the primary | Dashboards and analytics that can accept a few seconds of delay |

Step 3 wrote 20 documents with each write concern: `w: 1` averaged **152 ms** per write and `w: "majority"` also averaged **152 ms** (40 documents saved). From my computer, almost all of each write's time is the network trip from Lagos to the AWS Paris region and back, and the extra wait for a second node inside the same data centre was too small to show at this scale. So, here, the safer setting cost nothing noticeable. Inside a data centre, the extra wait for a second node is a larger share of the total. Step 4 saved a ₦3,500 card payment for delivery 12 with `w: "majority"` and read it back with read concern `"majority"`: the payment was returned with status `Successful`, so it was already held by a majority of nodes. The test collection was then dropped (step 5).

**Consistency trade-off (CAP):** in a network partition, a replica set keeps accepting writes only on the side that still has a majority of nodes, so it chooses consistency over availability for writes. Reads from secondaries are **eventually consistent**: they may briefly return older data. LagosLink should read a customer's own just-confirmed payment from the primary, and use secondaries only where slight delays are acceptable.

Evidence: [step 3](screenshots/05_step3_write_concern.png), [step 4](screenshots/06_step4_majority_payment.png).

## 4. Availability and failover

If the primary fails, the two secondaries hold an **election** and one becomes the new primary, typically within seconds. MongoDB drivers rediscover the new primary automatically, and **retryable writes** resend a write that was interrupted by the failover. Writes made with `w: "majority"` survive the failover because they already exist on at least two nodes.

Atlas can trigger a test failover ("Test Resilience"), but only on dedicated tiers (M10 and above), so it could not be run on the free cluster. For LagosLink in production, a dedicated cluster with nodes in **more than one region** would keep the service available even if an entire AWS region went down.

## 5. Sharding design (not run)

Sharding splits one collection across several replica sets ("shards") so that storage and writes scale horizontally. The free tier cannot be sharded, so this is a design for when LagosLink grows beyond Lagos.

| Option | Shard key | Advantages | Disadvantages |
|---|---|---|---|
| A | `{ "hub.hub_id": 1, _id: 1 }` | A hub's deliveries are stored together, so hub reports read one shard. Can be combined with **zone sharding** to keep each city's data in a nearby region | A very busy hub can become a "hot" shard |
| B | `{ _id: "hashed" }` | Spreads writes evenly across all shards | Hub reports must ask every shard ("scatter-gather") |

**Recommendation:** option A, with zones per city (Lagos, Abuja, Port Harcourt). Most queries (tracking, hub reports) include the hub, data stays close to its users, and if one hub grows too large the key can be refined. The command would be:

```js
sh.shardCollection("logistics_db.deliveries", { "hub.hub_id": 1, _id: 1 })
```

## 6. Recommendations for LagosLink

1. Move from the free tier to a dedicated cluster before going live, and enable automated **backups** (not available on the free tier).
2. Use `w: "majority"` for payments and delivery confirmations; `w: 1` is acceptable for GPS points.
3. Send analytics and dashboards to secondaries, keeping the primary free for operational writes.
4. Restrict network access to the application servers' addresses, and give each application its own least-privilege database user.
5. Plan zone sharding by city as the business expands.

## 7. My observations

> What struck me most was that the “safe” write setting cost nothing: 152 ms for w: 1 and 152 ms for w: "majority", because almost all the time was the trip from Lagos to Paris, not the extra wait for a second server. The readPref('secondary') test made replication feel real, since the same parcel came back from server 00-02 instead of 00-01, proving the data truly lives in more than one place. For LagosLink’s payments I would always use "majority": a payment that disappears after a server failure costs far more in customer trust than a few milliseconds of waiting.

