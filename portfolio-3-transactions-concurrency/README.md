# Portfolio 3: Transactions and Concurrency

**Case study:** LagosLink Deliveries (simulated), the same database as [Portfolio 1](../portfolio-1-database-design/README.md) and [Portfolio 2](../portfolio-2-query-optimisation/README.md).

**Tools:** PostgreSQL 18 and pgAdmin 4. Two Query Tool tabs were used as two separate database connections, to act as two dispatchers working at the same time. **Database:** `logistics_db`.

## Files in this folder

| File | What it is |
|---|---|
| [`01_commit_rollback.sql`](01_commit_rollback.sql) | Part 1 (one connection): COMMIT, ROLLBACK, and an error that cancels a whole transaction |
| [`02_window_A.sql`](02_window_A.sql) | Parts 2 and 3: the steps run by Dispatcher A, in the first Query Tool |
| [`03_window_B.sql`](03_window_B.sql) | Parts 2 and 3: the steps run by Dispatcher B, in a second Query Tool |
| [`screenshots/`](screenshots/) | 29 screenshots, numbered in the order the steps were run |

**How to repeat it:** each step in the files is labelled (for example `STEP A1`, `STEP B2`). Highlight one step and click Execute, following the step numbers in order and switching between the two Query Tool tabs.

## 1. Transactions and ACID

A **transaction** is a group of changes that must all succeed or all fail together. `BEGIN` starts the group, `COMMIT` saves every change permanently, and `ROLLBACK` cancels every change.

In LagosLink, assigning a delivery to a driver changes three tables at once: `deliveries` (the driver and status), `delivery_status_updates` (a new history row) and `drivers` (the driver becomes "On delivery"). If only some of these changes were saved, the data would disagree.

Transactions guarantee four properties (**ACID**):

| Property | Meaning | Shown in |
|---|---|---|
| **Atomicity** | All or nothing | Part 1, exercise 3 |
| **Consistency** | Constraints from Portfolio 1 are never broken | Part 1, exercise 3 (the CHECK rule stopped a bad status) |
| **Isolation** | Concurrent users don't see each other's unfinished work | Part 2 |
| **Durability** | Committed data stays saved | Part 1, exercise 1 (the change was still there in later queries) |

## 2. Part 1: COMMIT, ROLLBACK and an error (one connection)

### Exercise 1: COMMIT

Delivery 12 was assigned to driver 8 (Grace Okafor). Three changes were made inside one transaction and committed together.

| | status | driver_id | Grace's status | history rows |
|---|---|---|---|---|
| Before | Requested | (empty) | Available | 1 |
| After COMMIT | Assigned | 8 | On delivery | 2 |

Evidence: [before](screenshots/01_ex1_before.png), [COMMIT](screenshots/02_ex1_commit.png), [after](screenshots/03_ex1_after_commit.png).

### Exercise 2: ROLLBACK

A clerk marked delivery 11's cash payment as received, then learned the cash had not been collected.

| Moment | payment_status | paid_at |
|---|---|---|
| Inside the transaction, after the UPDATE | Successful | 2026-11-10 01:46:06 |
| After ROLLBACK | Pending | (empty) |

The change was visible only inside the open transaction, and ROLLBACK removed it completely. Evidence: [inside](screenshots/04_ex2_inside_transaction.png), [after ROLLBACK](screenshots/05_ex2_after_rollback.png).

### Exercise 3: an error cancels the whole transaction (atomicity)

A transaction added a "Picked up" history row for delivery 12 (which succeeded), then tried to set the delivery's status to `'Picked-up'`, which is not an allowed value. The CHECK constraint `deliveries_status_check` rejected it. After ROLLBACK, the status was still `Assigned` and there were **0** "Picked up" history rows: the row that had been inserted successfully was undone too.

Evidence: [error](screenshots/06_ex3_error.png), [ROLLBACK](screenshots/07_ex3_rollback.png), [check](screenshots/08_ex3_check.png).

**Aborted transactions:** on the first attempt, the whole script was run at once. When exercise 3 failed, PostgreSQL marked the transaction as aborted and refused every later command (`current transaction is aborted, commands ignored until end of transaction block`) until a ROLLBACK was issued ([screenshot](screenshots/09_aborted_transaction_refuses_commands.png)). This is atomicity in practice: after an error, nothing more can be added to the transaction, so it can only be cancelled as a whole.

## 3. Part 2: Isolation (two connections)

A test delivery, 90001, was created with a fee of ₦3,000. Dispatcher A and Dispatcher B then read and changed it from two separate connections.

| Step | Dispatcher A | Dispatcher B | B saw |
|---|---|---|---|
| A1 | `BEGIN`; changes the fee to 5,000 (not committed) | | |
| B2 | | reads the fee | **3,000** |
| A3 | `COMMIT` | | |
| B4 | | reads the fee | **5,000** |
| B5 | | `BEGIN ISOLATION LEVEL REPEATABLE READ`; reads | 5,000 |
| A6 | changes the fee to 4,500 (committed at once) | | |
| B7 | | reads again, same transaction | **still 5,000** |
| B8 | | `COMMIT`; reads | **4,500** |

- **No dirty reads (B2):** PostgreSQL's default level, **READ COMMITTED**, only shows committed data. B could not see A's unfinished change, so B could never act on a value that might still be rolled back.
- **READ COMMITTED (B4):** once A committed, B's next query saw the new value. Each statement sees the data committed before it started.
- **REPEATABLE READ (B7):** B's transaction used one snapshot taken at its first query, so B saw 5,000 even after A committed 4,500. This prevents a **non-repeatable read**, which matters for a report that must add up, such as a daily revenue summary.
- **B8:** after B committed, a new snapshot showed the latest value.

Evidence: screenshots [10](screenshots/10_iso_A0_create_delivery.png) to [18](screenshots/18_iso_B8_after_commit_4500.png).

## 4. Part 3: A concurrency problem, the lost update

Both dispatchers checked delivery 90001 at the same time and saw it was free. Each then assigned it to a different driver.

| Step | Dispatcher A | Dispatcher B | Result |
|---|---|---|---|
| A9 | `BEGIN`; reads 90001: Requested, no driver | | |
| B10 | | `BEGIN`; reads 90001: Requested, no driver | |
| A11 | assigns driver 5 (Sola); `COMMIT` | | driver 5 |
| B12 | | assigns driver 6 (Emeka); `COMMIT` | **driver 6** |

B's update silently overwrote A's. No error was raised, so neither dispatcher knew. In real operations, Sola would drive to a pickup that had already been given to Emeka. This is a **lost update**. READ COMMITTED does not prevent it, because each dispatcher's decision was based on a value that had already changed by the time they wrote.

Evidence: screenshots [19](screenshots/19_lost_A9_sees_free.png) to [22](screenshots/22_lost_B12_overwrites_emeka.png).

## 5. The control mechanism: a row lock with `SELECT ... FOR UPDATE`

The same scenario was repeated, but each dispatcher read the delivery with `SELECT ... FOR UPDATE`, which locks the row for the rest of the transaction.

| Step | Dispatcher A | Dispatcher B | Result |
|---|---|---|---|
| A13 | resets 90001 to free | | |
| A14 | `BEGIN`; `SELECT ... FOR UPDATE`: free, **row locked** | | |
| B15 | | `BEGIN`; `SELECT ... FOR UPDATE` | **B waits** |
| A16 | assigns driver 5; `COMMIT` (lock released) | | |
| B15 (continued) | | the wait ends; B reads: **Assigned, driver 5** | |
| B17 | | sees the job is taken; `ROLLBACK` | |
| A18 | final check | | **driver 5** |

Dispatcher B's query waited for about **62 seconds** ("Waiting for the query to complete"), until A committed. B then saw the up-to-date row, already assigned to driver 5, and cancelled instead of overwriting it. Sola's assignment was not lost.

Evidence: screenshots [23](screenshots/23_lock_A13_reset.png) to [29](screenshots/29_lock_A18_final.png); the waiting state is in [25](screenshots/25_lock_B15_waiting.png).

## 6. Analysis

- **Why the lock works:** `FOR UPDATE` turns "check, then change" into one protected step. While A holds the lock, nobody else can lock or update that row, so decisions are always based on current data.
- **The cost of locking:** waiting. B waited 62 seconds here only because the demonstration paused between steps. In a real application the transaction should last milliseconds: lock, update and commit straight away, never waiting for a person in between. A `lock_timeout` can stop a session from waiting forever.
- **Deadlocks:** if two transactions lock rows in opposite orders, each can wait for the other. PostgreSQL detects this and cancels one of them. Locking rows in a consistent order (for example, always the delivery first, then the driver) avoids it.
- **Alternatives (not tested here):**
  - *Optimistic concurrency:* a conditional update such as `UPDATE deliveries SET driver_id = 6 ... WHERE delivery_id = 90001 AND driver_id IS NULL`. If another dispatcher got there first, it reports `UPDATE 0`, and the application tells the user the job is taken. No waiting, but the application must check the result.
  - *SERIALIZABLE isolation:* PostgreSQL detects conflicting transactions and fails one with a serialization error, which the application must retry.
  - *`FOR UPDATE SKIP LOCKED`:* useful for an automatic dispatch queue. Each dispatcher takes the next job that nobody else has locked, instead of waiting.
- **Recommendation for LagosLink:** assign drivers inside one short transaction that locks the delivery (`FOR UPDATE`), updates `deliveries`, inserts the `delivery_status_updates` row and updates the driver's status, then commits. This also keeps `deliveries.status` and its history in step, the controlled denormalisation described in Portfolio 1.

