# Triko — Locked Queue Rules

**Status:** Approved 2026-10-07. Source of truth for the queue engine (M2/M3).
Where this file differs from [TRIKO_BUILD_REFERENCE.md](../TRIKO_BUILD_REFERENCE.md), this file wins.

Markers:
- **[ASSUMPTION]** — engine detail chosen as the safest reading; not yet explicitly confirmed.
- **[OPEN]** — needs a product decision before the milestone named.

---

## 1. Server authority

The backend computes and enforces everything below. The client only displays server results.
No rule in this file may be implemented only in React Native.

## 2. Lanes

A route queue has three ordered lanes:

| # | Lane | Who | Order |
|---|------|-----|-------|
| 1 | **ACTIVE** | Drivers currently serving the turno | By activation time |
| 2 | **PRIORITY** | Reserved drivers who have returned; resumed suspended drivers | FIFO by `priority_sequence` (when the reservation was granted) |
| 3 | **NORMAL WAITING** | Everyone else waiting | FIFO by `join_sequence` |

Outside the lanes (no position): reserved drivers who are **away**, and **suspended** drivers.
The operator screen shows them in their own sections.

When an active slot is free, the next eligible driver is the head of PRIORITY, otherwise the head of NORMAL WAITING.
No one ever displaces a driver who is already ACTIVE.

## 3. Position concepts

Never use one ambiguous "position".

| Concept | Meaning | Example (capacity 3) |
|---|---|---|
| `overall_position` | Visible order including active: active drivers 1..A, then PRIORITY, then NORMAL WAITING | Leo = #8 |
| `waiting_position` | 1-based place among PRIORITY + NORMAL WAITING. `1` = NEXT IN LINE | Leo = 5 |
| `waiting_ahead` | `waiting_position − 1` (active drivers are not counted) | Leo = 4 AHEAD |
| `reservation_priority` | 1-based rank among active reservations (away + returned), FIFO | Carlo = RESERVED #1 |
| `active_slot` | 1..A for active drivers, else null | Juan = 1 |

All of these come from one server function, `queue_effective_order(route_id)`.
`queue_entries.current_rank` is only a cache.

Worked example:

```
ACTIVE            #1 Juan   #2 Pedro   #3 Mark
RESERVED (away)   Carlo                         ← no position
PRIORITY          #4 Ben    (returned)          waiting_position 1 = NEXT IN LINE
NORMAL WAITING    #5 Rico   #6 Jun   #7 Leo     Leo: waiting_position 4, 3 AHEAD
```

The driver UI shows mostly `waiting_position` / `waiting_ahead` / NEXT IN LINE.
The operator UI shows the full `overall_position` order.

## 4. Entry states

| State | Lane | Notes |
|---|---|---|
| `waiting` | NORMAL WAITING | |
| `active` | ACTIVE | |
| `reserved` | none (away) | Has an active `queue_reservations` row |
| `priority` | PRIORITY | Reserved and returned, or resumed from suspension |
| `suspended` | none | Temporary; can be resumed |
| `completed` | terminal | Turn served |
| `cancelled` | terminal | Ends this participation; driver must rejoin for a new place |
| `removed` | terminal | Correction only (duplicate, wrong driver, test). Admin/correction action, not in the normal operator menu |

Terminal entries are never deleted.

## 5. Commands and allowed transitions

| Command | From → To | Rule |
|---|---|---|
| `join_queue` | — → `waiting` | See §9 |
| `activate_queue_entry` | `waiting`/`priority` → `active` | Only when active count < capacity, only for the **next eligible** driver (waiting_position 1), and the operator confirms the driver is present. **[ASSUMPTION]** Activation is never automatic. |
| `complete_queue_entry` | `active` → `completed` | Operator confirms the driver departed. Never time-based. |
| `reserve_queue_entry` | `waiting` → `reserved` | Absent decision. Creates a reservation with the next `priority_sequence`. |
| `move_queue_entry_to_last` | `waiting` → `waiting` | New `join_sequence` = next sequence |
| `cancel_queue_entry` | any non-terminal → `cancelled` | Cancels any active reservation |
| `return_reserved_driver` | `reserved` → `priority` | Operator confirms the driver is physically present. Keeps the original `priority_sequence`. |
| `mark_priority_absent` | `priority` → `reserved` | Due but absent again. Keeps the original `priority_sequence` (§5.2 rule 1). |
| `suspend_queue_entry` | `active` → `suspended` | The active slot is freed immediately |
| `resume_queue_entry` | `suspended` → `priority` | Gets a priority entry (new `priority_sequence` at the end of the PRIORITY lane). Never takes a slot from an active driver. |
| `transfer_queue_entry` | `waiting` → see §7 | |
| `remove_queue_entry` | any non-terminal → `removed` | Correction only |
| `change_queue_capacity` | — | See §8 |
| `open_queue` / `close_queue` | — | See §10 |
| `enable_qr` / `disable_qr` / `generate_qr_session` | — | See §9 |
| `undo_queue_event` | — | See §6 |

The "absent decision" (RESERVE / MOVE TO LAST / CANCEL) is offered when the next eligible driver is due for a free slot but is not present.
It is never automatic. There is no automatic penalty.

### 5.1 Action matrix (confirmed 2026-10-07)

The backend rejects any command not listed for the entry's current state.
The UI derives its buttons from this matrix and never shows an invalid action.

| State | Allowed actions |
|---|---|
| `waiting` | ACTIVATE (next eligible only), RESERVE, MOVE TO LAST, CANCEL, TRANSFER |
| `active` | COMPLETE, SUSPEND, CANCEL |
| `reserved` (away) | RETURN (→ `priority`), CANCEL |
| `priority` (returned) | ACTIVATE (next eligible only), ABSENT AGAIN (→ `reserved`), CANCEL |
| `suspended` | RESUME (→ `priority`), CANCEL |
| `completed` / `cancelled` / `removed` | none |

REMOVE (correction only) is valid on any non-terminal state but is not part of the normal operator menu.

### 5.2 Confirmed rules

1. **Absent again keeps priority.** A returned reserved driver (`priority`) who is due but absent again goes back to `reserved` with their **original** `priority_sequence`. No new reservation number is assigned. Carlo stays RESERVED #1.
2. **SUSPEND only from `active`.** A waiting driver's absence is handled by RESERVE / MOVE TO LAST / CANCEL.
3. **TRANSFER only from `waiting`** (normal lane). Never from `active`, `reserved`, `priority`, `suspended` or terminal states. This protects reserved priority.
4. **CLOSED blocks new joins only** (operator ADD and QR join). Every other valid command keeps working on existing entries while CLOSED.
5. **Move to last and transfer start a new notification cycle** (§11).

## 6. Undo

- 30-second window, enforced on the server.
- Only the route's **most recent queue mutation event** can be undone. Any later queue mutation on that route ends its undo eligibility.
- Queue mutations: join, activate, complete, reserve, return, move to last, cancel, suspend, resume, transfer, remove, capacity change, open/close queue, QR enable/disable.
- These do NOT affect undo, because they are not queue events: viewing, realtime sync, notification creation/delivery (push or SMS), app open/close, reading history, reconnecting.
  Notification rows live in `notification_events`, never `queue_events`.
- Undo is recorded as a new `UNDO_*` event. The original event is never erased.
- No recursive undo: an undo event can never itself be undone. Further fixes are new explicit commands.
- Undo restores the pre-event state recorded in the event (`old_state`). The undo itself never sends notifications, because positions only move back.
- **[ASSUMPTION]** Any operator assigned to the route may undo. At MVP there is one controlling operator per route.

## 7. Transfer

`Carlo → Ben`:

1. Carlo's entry must be `waiting`, with `transfer_used = false` and not itself a received transfer.
2. Ben must: be an active Triko driver; be assigned to the same route; have no non-terminal entry in **any** queue. No merging of two positions.
3. Ben gets a **new entry** that inherits Carlo's `join_sequence` (same place). It has `transfer_origin_entry_id` = Carlo's entry and `transfer_used = true`, so Ben can never transfer it on.
4. Carlo **keeps the same entry**, gets a new `join_sequence` at the end of NORMAL WAITING, and is marked `transfer_used = true`.
   He can transfer again only in a future new participation.
5. `queue_transfers` stores source entry/driver, target driver, original position, resulting entitlement, operator, and time. One `DRIVER_TRANSFERRED` event.
6. The limit is once per queue entry, not per lifetime. `Carlo → Ben → Rico` is rejected by the backend.

## 8. Capacity

- Changing capacity never ejects an active driver.
- If active > new capacity, the extra drivers stay active until they complete, are cancelled, or are suspended.
- No activation happens while active count ≥ capacity.
- The operator sees a warning, e.g. "Capacity reduced to 2. 3 drivers are currently active. The extra active driver will remain active until leaving."

## 9. Joining

The server checks, in order:
1. Authenticated
2. Driver account active
3. No non-terminal entry in any route queue
4. Route queue OPEN
5. If joining by QR: QR enabled, token valid for this route, session active and not expired, current time ≥ QR start time
6. Driver assigned to this route **[ASSUMPTION]**
7. Not already in this queue ("Already in this queue.")

Then, in one transaction: create a `waiting` entry with the next `join_sequence`, record `QUEUE_JOINED`, and bump `queue_version`.

Operator assignment (ADD) skips the QR checks (5) but not the others.

QR tokens are random, opaque, tied to one route and session, have a start and expiry time, and stop working the moment QR is disabled.

## 10. Queue day continuity

- The queue opens at the route's configured start time (default 4:00 AM). OPEN/CLOSED is set by the operator.
- CLOSED blocks new joins only. Existing entries keep their order.
- Nothing resets at midnight or at close/reopen. Sequences keep counting across days.
- Any later "operating session" is metadata only and never resets FIFO.

## 11. Notifications

- Thresholds use `waiting_position`: **10, 8, 6, 4, 2, 1 (= NEXT IN LINE)**.
- For each affected driver, the server compares `old_waiting_position` and `new_waiting_position` inside the mutation transaction.
- A notification is created only if `new < old` (moved forward) **and** a threshold `t` was crossed (`old > t ≥ new`).
- Moving backward (e.g. a reserved driver returns) never notifies.
- On a jump past several thresholds, only the lowest threshold crossed (the most urgent) is sent. Example: 12 → 8 sends 8 only.
- No duplicates **within a cycle**: unique on (driver, queue entry, `notification_cycle`, threshold, type, channel).
  `channel` is included so a later SMS fallback for the same alert is a separate row.
- `queue_entries.notification_cycle` starts at 1. It increases on **MOVE TO LAST** and for the **sender after a TRANSFER**, so every threshold can alert again as they move forward. There is never a permanent "already got #8" rule.
- A transfer recipient gets a new entry (cycle 1) at the inherited place. Their next forward move notifies by the normal crossing rule. Thresholds at or behind their starting place are not sent.
- Entering a lane from outside (join, return, resume, transfer receipt) is not "moving forward" and does not notify by itself.
- The client never decides thresholds.

## 12. Identity and auth

- Identity is the **driver** (UUID). The tricycle is an assignment, and assignments have history.
- Login is **Driver Code + 6-digit PIN** (e.g. `DRV-001`). The internal auth email is `<code lowercased, no dash>@<AUTH_EMAIL_DOMAIN>`, e.g. `drv001@auth.triko.app`. Drivers never see it.
- `AUTH_EMAIL_DOMAIN` comes from config and must be a domain the project controls. **[OPEN — before M4]** Confirm ownership of `triko.app`.
- Login goes through a `login` Edge Function, which handles per-account and per-device throttling, lockout with increasing wait times, and generic error messages.
- Operators add drivers and reset PINs in the app, through the `driver-admin` Edge Function. It checks the operator's route permission, creates the Auth user (email already confirmed), driver and tricycle records, and the route assignment. If anything fails after the Auth user is created, it deletes that Auth user.
- Operator accounts: created by a seed or admin script for the MVP, using the same database role and route-assignment authorization as future accounts.
- Privileged calls use the Supabase **secret key** (`sb_secret_…`), stored only in Edge Function secrets. The APK contains only the publishable key.

## 13. Open questions for later milestones

- **[OPEN — before M5]** Driver home big number: `overall_position` (#8 with "4 AHEAD", as in the reference) or `waiting_position`? Tentatively overall #8 + "4 AHEAD", and NEXT IN LINE replaces the number at waiting position 1.

## 14. Engine assumptions (M3)

Chosen as the safest reading while implementing the queue engine. Confirm or change.

- **[ASSUMPTION]** Undoing a join or a transfer marks the created entry `removed` (correction). It is never deleted. An undone transfer keeps its `queue_transfers` row with `undone_at` set, so the sender may still transfer later.
- **[ASSUMPTION]** Undo never rolls back `queue_sequence` / `priority_sequence` counters. They only increase.
- **[ASSUMPTION]** Undo is refused (`UNDO_NOT_ALLOWED`) if it would give a driver a second live entry, e.g. the driver joined another route after being cancelled.
- **[ASSUMPTION]** An admin may run any operator command on any route. `remove_queue_entry` is available to operators and admins.
- **[ASSUMPTION]** A command that changes nothing (capacity set to the same value, opening an open queue, enabling an enabled QR) is rejected with `INVALID_TRANSITION`, so it never takes the undo slot.
- **[ASSUMPTION]** `open_queue` / `close_queue` / `enable_qr` / `disable_qr` only change route flags. QR session tokens and Realtime broadcast come in later milestones.
- **[OPEN]** §3 worked example: the table says Leo = #8 / waiting 5 / 4 AHEAD, but the diagram gives #7 / waiting 4 / 3 AHEAD. The engine follows the diagram (both are consistent with one extra waiting driver ahead of Leo). Fix the example text.
