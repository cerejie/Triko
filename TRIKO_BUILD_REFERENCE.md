# TRIKO — Complete Product & Engineering Build Reference

**Project:** Triko  
**Purpose:** Digital queueing / turno management system for tricycle drivers and operators  
**Primary platform:** Android  
**Initial distribution:** Direct APK  
**Future distribution:** Google Play Store  
**Primary backend:** Supabase / PostgreSQL  
**Primary mobile stack:** React Native + Expo + TypeScript  
**Document status:** Implementation reference / source of truth for product, UX, architecture, and engineering  
**Target context:** Community initiative; initially free for drivers and operators  
**Initial scale:** ~10–50 drivers, ~5–10 routes, ~15–30 drivers per route, 1 operator managing ~3–4 routes; expected to grow later

---

# 1. Product Vision

## 1.1 The problem

Traditional tricycle terminals use a physical "turno" / queue.

Example:

- 15 tricycles are assigned to the Kidapawan → Magpet route.
- Only 3 tricycles are allowed to occupy the active turno at one time.
- The remaining 12 drivers physically wait nearby so they can be next when the active tricycles leave.
- Drivers may spend hours waiting even though they could be elsewhere finding passengers or doing other useful work.
- When they are far away from their turno, they risk missing their place.
- Operators currently control the queue manually.

## 1.2 Triko's solution

Triko digitizes the existing physical queue without trying to replace the operator's authority.

The driver can leave the terminal while preserving the right to his/her place in the queue.

The app tells the driver:

- Current queue position.
- Number of drivers ahead.
- Whether the driver is approaching the active turno.
- When the driver needs to return.
- When the driver becomes next.
- Important queue movement notifications.

The operator remains the final authority over the queue.

## 1.3 Core product statement

> **Triko lets drivers leave the terminal without losing awareness of their turno.**

The app should feel like a digital answer to:

> "Asa na akong turno?"

The ideal response is immediately understandable:

> "#8 — 4 ahead — alert at #6."

---

# 2. Product Philosophy

Triko is NOT a generic admin/SaaS application.

The primary users may:

- Have low technical literacy.
- Have limited ability/willingness to read long text.
- Use low-cost Android phones.
- Use older/slow phones.
- Have weak or intermittent mobile data.
- Be unfamiliar with complex app navigation.

Therefore:

## 2.1 UX principles

1. **Simple before powerful.**
2. **Visual before textual.**
3. **One screen before many screens.**
4. **One decision before many decisions.**
5. **Large numbers and clear status.**
6. **Very little typing for drivers.**
7. **Never expose technical concepts to users.**
8. **Operator has power; driver has simplicity.**
9. **Server is the source of truth.**
10. **Offline driver experience must remain useful.**
11. **Every destructive/high-impact operator action must be deliberate and reversible.**
12. **Fast startup and low memory usage are mandatory.**

---

# 3. Locked Business Rules

These rules are part of the product specification and should not be changed casually during implementation.

## 3.1 Queue capacity

Each route has a configurable active turno capacity.

Example:

- Route: Kidapawan → Magpet
- Capacity: 3

Capacity is NOT globally fixed.

The operator may change it.

## 3.2 Active queue

If capacity is 3:

```text
1. Driver A — ACTIVE
2. Driver B — ACTIVE
3. Driver C — ACTIVE
4. Driver D — WAITING
5. Driver E — WAITING
```

When the active drivers leave and are confirmed completed:

```text
4. Driver D → ACTIVE
5. Driver E → WAITING
```

## 3.3 Leaving the queue

A driver must be physically leaving the terminal and the operator confirms the departure/completion.

The app must NOT automatically assume that a driver left just because time passed.

The operator is authoritative.

## 3.4 Driver absent when reaching the active position

When a driver is due for turno but is absent, the operator must choose an action.

The app should present:

```text
Driver #4 is absent.

[ RESERVE ]
[ MOVE TO LAST ]
[ CANCEL ]
```

### RESERVE

The driver keeps priority entitlement.

Example:

```text
RESERVED #1
Carlo
```

The next available waiting driver temporarily occupies the active spot.

When Carlo returns, Carlo receives the reserved priority.

### MOVE TO LAST

The driver loses the current queue spot and is moved to the end.

### CANCEL

The operator cancels/removes the current queue participation according to the business rules.

Every high-impact action requires confirmation.

## 3.5 Reserved priority

A reservation remains valid until the driver actually uses the reserved turn.

Reservations persist across time and across the daily boundary when applicable.

If multiple drivers are reserved:

```text
Reserved #1 — Carlo
Reserved #2 — Ben
Reserved #3 — Rico
```

Reservation priority is FIFO based on when the reservation was granted.

A reserved driver keeps his/her reserved priority.

## 3.6 Reservation does not permanently occupy an active slot

If Carlo is RESERVED #1, the next available driver can temporarily fill the active slot.

The queue must be able to represent:

- Active drivers.
- Waiting drivers.
- Reserved-priority drivers.

These are logically different states.

## 3.7 Driver returns after reservation

When a reserved driver returns and the operator confirms the driver is physically present, the operator can activate the reserved driver according to the reserved priority.

The system must preserve the reservation history.

## 3.8 Temporary absence

A driver may leave while still waiting.

If the driver reaches the point where he/she should become active but is absent, the operator makes the decision:

- Reserve.
- Move to last.
- Cancel.

There is no automatic penalty.

## 3.9 Voluntary transfer

A driver can voluntarily transfer the current queue entitlement/spot to another registered driver.

Rule:

- A driver may transfer only once.
- If a driver receives a transferred position, that recipient cannot transfer the received entitlement onward.
- The system must record the original holder, recipient, operator confirmation, timestamp, and resulting queue entitlement.
- Transfer must be explicit and confirmed.

The exact UI wording should use simple language such as:

> Transfer my turn to ___?

## 3.10 Active driver cancellation

An active driver can be cancelled.

The operator may then replace the active slot as allowed by the queue rules.

## 3.11 Active driver cannot be replaced by another driver

A different driver cannot simply "take over" an active driver's identity/turn.

If something happens to the active driver:

> Suspend his/her turn.

The driver assignment is not silently transferred to another driver.

## 3.12 Driver identity

Primary app identity is the individual DRIVER.

The tricycle number is an important identifier, but it is not the database identity.

Example:

```text
Driver: Pedro
Tricycle: TRI-123
```

Another driver may rarely use the same tricycle:

```text
Driver: Juan
Tricycle: TRI-123
```

The system must maintain a correct history.

## 3.13 One driver belongs to one route queue

A driver may not belong to multiple active queues simultaneously.

## 3.14 Multiple routes

There are multiple routes.

Example:

```text
Kidapawan → Magpet
Kidapawan → Matalam
Kidapawan → Makilala
Kidapawan → Poblacion
```

Each route has its own queue.

## 3.15 Operators

One operator may manage multiple route queues.

Example:

```text
Operator A
 ├── Route A
 ├── Route B
 ├── Route C
 └── Route D
```

Later, more operators can be added with assigned routes.

Initial deployment may have only one operator.

## 3.16 Two operators should not simultaneously mutate the same route queue

For the current operating model, keep queue mutation authority simple.

A route should have one active controlling operator at a time unless a later version intentionally introduces concurrency controls.

If concurrent operator access is ever introduced, the backend must use transactional operations and optimistic/concurrency safeguards.

## 3.17 Queue operating day

The queue starts at:

> 4:00 AM

The queue may remain open across the day.

Queue status:

```text
🟢 OPEN
🔴 CLOSED
```

The queue does NOT reset simply because the clock reaches midnight.

The last position continues into the next day.

Example:

```text
October 6:
Position #18

October 7:
The next position/order continues from the existing queue state.
```

The implementation must not assume every calendar day is a fresh FIFO reset.

A future version may introduce formal queue sessions/day partitions, but historical continuity must be preserved.

## 3.18 Queue close

When the operator closes a queue:

```text
Queue:
🔴 CLOSED
```

Drivers cannot newly join the closed queue.

The app should communicate closure clearly.

## 3.19 Operator vs automatic rules

The app must provide automatic safe mechanics, but the operator remains the final decision maker.

Example:

```text
#4 absent

[ RESERVE ]
[ MOVE TO LAST ]
[ CANCEL ]
```

Do NOT auto-reserve or auto-move an absent driver.

---

# 4. Driver Experience

The driver app must be intentionally simple.

## 4.1 Driver's primary question

Every time the app opens, answer:

> **Where am I in the queue?**

## 4.2 Target comprehension

A driver should understand the important state within approximately 3–5 seconds without needing training.

They should immediately see:

- Huge current position.
- Number ahead.
- Current status.
- Next important notification threshold.
- Whether they need to return.

## 4.3 Driver home screen concept

```text
TRIKO

TRI-123

        #8

    4 AHEAD

   🟡 WAITING

  NEXT ALERT
      #6

────────────────────

       QUEUE

       🔔 ALERTS
```

Avoid large paragraphs.

## 4.4 Status design

Use:

- Icon
- Text
- Position

Never use color alone.

Examples:

```text
🟢 ACTIVE
🟡 WAITING
🔵 RESERVED
⏸ SUSPENDED
✅ COMPLETED
🔴 CLOSED
```

## 4.5 Driver navigation

Keep it minimal:

```text
🏠 HOME
☷ QUEUE
🔔 ALERTS
```

No complicated nested menu.

## 4.6 Driver should type very little

Avoid:

- Long forms.
- Free-text queue actions.
- Manual position entry.
- Complex settings.

The ideal driver flow should involve mostly:

- Open.
- View.
- Scan.
- Confirm.
- Read/hear notification.

---

# 5. Operator Experience

The operator receives more functionality, but it should remain simple.

## 5.1 Operator primary screen

The first screen should be the queue control screen.

Example:

```text
MAGPET

ACTIVE 3 / 3

🟢 TRI-101
   Juan

🟢 TRI-205
   Pedro

🟢 TRI-317
   Mark

WAITING

4  TRI-411  Carlo
5  TRI-522  Ben
6  TRI-631  Rico
7  TRI-704  Jun
8  TRI-811  Leo

[ + ADD ]
```

## 5.2 Operator driver detail actions

Tap a driver:

```text
CARLO
TRI-411

#4

[ ACTIVATE ]
[ RESERVE ]
[ MOVE TO LAST ]
[ SUSPEND ]
[ TRANSFER ]
```

Only show actions valid for the driver's current state.

## 5.3 Confirm dangerous actions

Confirm:

- Reserve.
- Move to last.
- Cancel.
- Suspend.
- Transfer.
- Remove.
- Close queue.

Do not require confirmation for every tiny action.

## 5.4 Undo

Every high-impact operator action should create a temporary undo opportunity:

```text
✅ Carlo reserved.

[ UNDO ]
```

Undo should be easy and immediate.

There should still be an audit/event history for older actions.

---

# 6. Low-Literacy UX Requirements

## 6.1 Do not rely on long text

Prefer:

```text
#8
4 AHEAD
WAITING
```

over:

> You are currently number 8 in the queue and there are 4 drivers ahead of you.

## 6.2 Local language

The initial product should support a locally appropriate language.

Recommended first language direction:

- Cebuano/Bisaya-first wording for the local deployment.
- English as a secondary/internal fallback.

Do not use formal machine translations.

Ask local drivers/operators for natural phrasing.

Examples should sound like actual local speech.

Possible presentation:

```text
#4

Duol na imong turno.
```

```text
#2

Balik na sa terminal.
```

```text
#1

Ikaw na ang sunod.
```

The exact production copy must be validated with real users.

## 6.3 Audio / vibration

Consider:

- Vibration for important queue alerts.
- Short notification sound.
- Optional spoken Bisaya notification for the most important states.

Potential states:

- #10
- #8
- #6
- #4
- #2
- #1 / next in line

Audio should be optional.

Do not add continuous audio or unnecessary announcements.

---

# 7. Notification Rules

Drivers only need important queue movement notifications.

## 7.1 Notification thresholds

Notify when the driver's position reaches:

```text
#10
#8
#6
#4
#2
#1 / NEXT IN LINE
```

Do not notify every single movement.

Example:

```text
#20 → no alert
#15 → no alert
#10 → alert
#9 → no alert
#8 → alert
#7 → no alert
#6 → alert
#5 → no alert
#4 → alert
#3 → no alert
#2 → alert
#1 → alert
```

## 7.2 Notification content

Prefer large/simple content:

### #10

```text
🔔 TRIKO

#10

10th spot reached.
```

### #8

```text
🔔 TRIKO

#8

Duol na imong turno.
```

### #4

```text
⚠️ TRIKO

#4

Duol na kaayo.

Andam na.
```

### #2

```text
⚠️ TRIKO

#2

Balik na sa terminal.
```

### #1

```text
🚨 TRIKO

#1

Ikaw na ang sunod.

RETURN TO TERMINAL
```

The exact copy should be localized and user-tested.

---

# 8. Offline Strategy

Offline support is a core requirement.

## 8.1 Driver offline behavior

Drivers may have:

- No data.
- Weak signal.
- No Wi-Fi.
- Intermittent mobile connectivity.

The app must continue to show the last known state from local storage.

Example:

```text
TRIKO

#8

4 AHEAD

🟡 WAITING

⚠ OFFLINE

Last updated:
10:41 AM
```

Do NOT pretend that offline data is live.

## 8.2 Local database

Use SQLite on device.

Recommended:

- Expo SQLite.

Expo's current SQLite documentation states that the database persists across app restarts. Official docs: https://docs.expo.dev/versions/latest/sdk/sqlite/

## 8.3 When connection returns

```text
Internet restored
        ↓
Connect to Supabase
        ↓
Fetch authoritative state
        ↓
Compare version/state
        ↓
Update local SQLite
        ↓
Refresh UI
```

Never allow stale local queue state to overwrite server state.

## 8.4 Driver offline writes

Prefer READ-ONLY offline mode.

The driver should not be able to mutate authoritative queue state while disconnected.

Driver offline actions, if any, should be local-only and non-authoritative.

---

# 9. Operator Offline Behavior

The operator can continue viewing cached data.

But queue-changing mutations should require an online connection.

Disable or block:

- Activate.
- Reserve.
- Move to last.
- Cancel.
- Suspend.
- Transfer.
- Close/open queue if it changes server state.

Display:

```text
⚠ OFFLINE

Queue changes are unavailable.

Reconnect to continue.
```

Reason:

The server must remain the source of truth and the project initially has only one authoritative operator per route.

Do not build complex multi-master offline queue mutation in MVP.

---

# 10. Notification Delivery Architecture

## 10.1 Primary channel

Push notification through FCM/Expo Notifications.

Expo's notification system builds on Android's native notification infrastructure. Official docs: https://docs.expo.dev/push-notifications/what-you-need-to-know/

## 10.2 Secondary fallback

SMS only for important events when the driver cannot receive push notifications.

Important:

> SMS is not free merely because the gateway software is open source. The SIM/network still charges for cellular SMS according to the carrier/plan.

## 10.3 Open-source SMS option

Investigate TextBee:

- Open-source SMS gateway.
- Can use an Android phone as an SMS gateway.
- Provides REST API.
- Supports self-hosting.

Official repository: https://github.com/textbee/textbee

Architecture:

```text
Supabase
   ↓
Notification Service
   ↓
SMS Adapter
   ↓
TextBee
   ↓
Dedicated Android gateway phone
   ↓
SIM
   ↓
Driver SMS
```

Do not make TextBee a hard-coded dependency in the core application.

Create an SMS provider abstraction so it can be replaced later.

## 10.4 Do not implement SMS first

MVP priority:

1. Queue engine.
2. Realtime.
3. Push.
4. Offline cache.
5. Real-world testing.
6. SMS fallback.

---

# 11. QR Queue Joining

Two driver-registration mechanisms exist.

## 11.1 Operator assignment

Operator directly assigns/registers the driver in the queue.

## 11.2 QR join

Driver scans QR.

Operator controls whether QR joining is enabled.

## 11.3 QR can be disabled dynamically

If operator disables QR:

```text
QR JOIN:
OFF
```

An old QR scan must not allow queue registration.

## 11.4 QR activation time

The operator should define when QR joining becomes active for the queue session.

This prevents drivers from scanning excessively early and gaining an unfair first position.

Example:

```text
Route:
Kidapawan → Magpet

Queue opens:
4:00 AM

QR Join Opens:
5:30 AM
```

## 11.5 QR should be session-specific

Prefer dynamic/session QR rather than a permanent QR.

The QR should contain an opaque, short-lived/session-bound token.

Do not embed sensitive driver or queue information directly in the QR.

## 11.6 QR can be displayed on operator phone

No printer required.

Operator:

```text
[ SHOW QR ]
```

Driver scans operator screen.

This supports both:

- Printed QR at terminal.
- Operator-phone QR.

---

# 12. Identity and Authentication

## 12.1 Driver

Use simple username + PIN.

Recommended primary identifier shown to drivers:

> Tricycle number.

Example:

```text
TRI-123
PIN: ****
```

## 12.2 Do not use tricycle number as the database primary key

Use internal UUIDs.

Example:

```text
driver_id = UUID
tricycle_number = TRI-123
```

This is necessary because:

- Different drivers can occasionally operate the same tricycle.
- Driver history must remain correct.
- Driver identity is the real queue participant.

## 12.3 Driver registration

Prefer controlled account creation rather than open public registration.

Suggested:

```text
Operator/admin creates driver
        ↓
Driver receives:
- Driver identity
- Tricycle number
- Temporary/simple PIN
        ↓
Driver logs in
        ↓
Driver may change PIN
```

Do not let an unauthenticated stranger create a fake queue participant.

---

# 13. Roles

Minimum roles:

## DRIVER

Can:

- View own queue.
- View queue.
- View own notifications.
- View own status.
- Scan valid queue QR.
- View current route.
- See offline cached state.

Cannot:

- Reorder queue.
- Reserve themselves.
- Move themselves to last.
- Change capacity.
- Modify operators.
- Manage other drivers.

## OPERATOR

Can:

- Manage assigned routes.
- View queues.
- Add drivers.
- Assign drivers.
- Activate drivers.
- Confirm driver departure.
- Reserve.
- Move to last.
- Cancel.
- Suspend.
- Transfer.
- Undo eligible actions.
- Manage QR joining.
- Open/close queue.
- Change capacity.
- View history.

## FUTURE ADMIN/SUPERADMIN

May manage:

- Operators.
- Associations.
- Routes.
- System configuration.
- Driver approvals.
- Audit logs.

Do not overbuild this for MVP if unnecessary.

---

# 14. Recommended Data Model

Use PostgreSQL relational modeling.

Suggested core tables:

```text
profiles
drivers
tricycles
routes
operator_route_assignments
queue_state
queue_entries
queue_reservations
queue_transfers
queue_events
notification_events
device_tokens
queue_qr_sessions
```

---

# 15. Table Design

## 15.1 profiles

Represents authenticated users.

Suggested columns:

```text
id UUID PRIMARY KEY
role TEXT / ENUM
display_name TEXT
phone_number TEXT
is_active BOOLEAN
created_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

Roles:

```text
driver
operator
admin (future)
```

## 15.2 drivers

```text
id UUID PRIMARY KEY
profile_id UUID UNIQUE
driver_code TEXT UNIQUE
current_tricycle_id UUID NULL
current_route_id UUID NULL
is_active BOOLEAN
created_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

## 15.3 tricycles

```text
id UUID PRIMARY KEY
tricycle_number TEXT UNIQUE
is_active BOOLEAN
created_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

## 15.4 routes

```text
id UUID PRIMARY KEY
name TEXT
origin TEXT
destination TEXT
queue_capacity INTEGER
queue_status TEXT
queue_start_time TIME
qr_enabled BOOLEAN
qr_start_time TIME
created_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

Potential status:

```text
open
closed
```

## 15.5 operator_route_assignments

```text
id UUID PRIMARY KEY
operator_id UUID
route_id UUID
is_active BOOLEAN
created_at TIMESTAMPTZ
```

Rule:

One operator can manage many routes.

## 15.6 queue_state

One authoritative row per route.

Possible columns:

```text
route_id UUID PRIMARY KEY
queue_sequence BIGINT
queue_version BIGINT
last_event_id UUID
updated_at TIMESTAMPTZ
```

The queue version is useful for synchronization and stale-write protection.

## 15.7 queue_entries

Represents driver participation in the queue.

Suggested:

```text
id UUID PRIMARY KEY
route_id UUID
driver_id UUID
join_sequence BIGINT
current_status TEXT
current_rank INTEGER NULL
transfer_origin_entry_id UUID NULL
transfer_used BOOLEAN DEFAULT FALSE
joined_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

Possible statuses:

```text
waiting
active
reserved
suspended
completed
cancelled
removed
```

Do not treat `current_rank` as the ultimate source of truth if rank can be derived. It can be a cached/materialized field for performance.

## 15.8 queue_reservations

```text
id UUID PRIMARY KEY
queue_entry_id UUID
priority_sequence BIGINT
created_by UUID
reserved_at TIMESTAMPTZ
used_at TIMESTAMPTZ NULL
cancelled_at TIMESTAMPTZ NULL
status TEXT
```

Status:

```text
active
used
cancelled
```

The `priority_sequence` determines FIFO reserved priority.

## 15.9 queue_transfers

```text
id UUID PRIMARY KEY
source_entry_id UUID
source_driver_id UUID
target_driver_id UUID
created_by UUID
created_at TIMESTAMPTZ
```

Also preserve:

```text
source queue position/entitlement
resulting entitlement
```

Rule enforcement:

- Source driver may transfer at most once according to business rules.
- A driver receiving a transferred entitlement cannot transfer it again.

## 15.10 queue_events

CRITICAL TABLE.

```text
id UUID PRIMARY KEY
route_id UUID
queue_entry_id UUID NULL
event_type TEXT
performed_by UUID
old_state JSONB NULL
new_state JSONB NULL
reason TEXT NULL
created_at TIMESTAMPTZ
```

Potential events:

```text
QUEUE_JOINED
QUEUE_ACTIVATED
DRIVER_LEFT
DRIVER_ABSENT
DRIVER_RESERVED
DRIVER_MOVED_TO_LAST
DRIVER_CANCELLED
DRIVER_SUSPENDED
DRIVER_RETURNED
DRIVER_TRANSFERRED
QUEUE_CAPACITY_CHANGED
QUEUE_OPENED
QUEUE_CLOSED
QR_ENABLED
QR_DISABLED
UNDO_PERFORMED
```

This is both:

- Audit log.
- Debugging source.
- Notification trigger source.
- Historical record.

## 15.11 notification_events

```text
id UUID PRIMARY KEY
driver_id UUID
queue_entry_id UUID
route_id UUID
notification_type TEXT
threshold INTEGER NULL
channel TEXT
status TEXT
created_at TIMESTAMPTZ
sent_at TIMESTAMPTZ NULL
failed_at TIMESTAMPTZ NULL
provider_message_id TEXT NULL
```

Notification types:

```text
QUEUE_THRESHOLD
NEXT_IN_LINE
```

Channels:

```text
push
sms
```

Status:

```text
pending
sent
failed
skipped
```

## 15.12 device_tokens

```text
id UUID PRIMARY KEY
user_id UUID
device_id TEXT
push_token TEXT
platform TEXT
is_active BOOLEAN
last_seen_at TIMESTAMPTZ
created_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

A driver may have more than one device.

## 15.13 queue_qr_sessions

```text
id UUID PRIMARY KEY
route_id UUID
session_token TEXT UNIQUE
starts_at TIMESTAMPTZ
expires_at TIMESTAMPTZ
is_active BOOLEAN
created_by UUID
created_at TIMESTAMPTZ
```

---

# 16. Queue State Machine

This is one of the most important architectural pieces.

The backend should own queue state transitions.

Do not put the real business rules exclusively in React Native.

## 16.1 Main states

```text
WAITING
ACTIVE
RESERVED
SUSPENDED
COMPLETED
CANCELLED
```

## 16.2 Example transitions

### Normal flow

```text
WAITING
   ↓
ACTIVE
   ↓
COMPLETED
```

### Absent flow

```text
WAITING
   ↓
ABSENT decision
   ├── RESERVED
   ├── MOVE TO LAST → WAITING
   └── CANCELLED
```

### Reserved flow

```text
RESERVED
   ↓
DRIVER RETURNS
   ↓
ACTIVE
   ↓
COMPLETED
```

### Suspension flow

```text
ACTIVE
   ↓
SUSPENDED
```

## 16.3 Operator decision model

When #4 is absent:

```text
Server tells client:

driver #4 absent and eligible for decision.

Options:
RESERVE
MOVE_TO_LAST
CANCEL
```

Operator chooses one.

The backend validates the transition.

---

# 17. Queue Ordering Model

Do not rely exclusively on a simple integer `position`.

Use an immutable/monotonic ordering concept such as:

```text
join_sequence BIGINT
```

and separate reservation priority.

Possible conceptual ordering:

```text
reserved priority
        ↓
active slot order
        ↓
normal waiting queue order
```

The exact query/order strategy must be designed carefully so reserved entries do not corrupt normal FIFO ordering.

Recommended approach:

- Treat reservations as a separate priority lane.
- Treat active slots as a controlled set.
- Treat normal waiting drivers as FIFO.
- Recompute/display effective rank server-side.

---

# 18. Example Queue Algorithm

Conceptual only; production implementation must be transaction-safe.

```text
1. Load route queue state.
2. Lock relevant route/queue rows.
3. Determine active capacity.
4. Determine active drivers.
5. Determine reserved priorities.
6. Determine waiting drivers by queue sequence.
7. Apply operator-requested state transition.
8. Validate transfer/reservation/suspension rules.
9. Update queue entry states.
10. Record queue event.
11. Increment queue_version.
12. Determine changed driver ranks.
13. Determine notification thresholds crossed.
14. Commit transaction.
15. Broadcast updated route state.
16. Create notification jobs.
```

The critical rule:

> Queue mutation, audit event creation, and authoritative rank calculation should happen inside a controlled backend transaction.

---

# 19. Server-side RPC / Function Design

Prefer explicit backend commands rather than allowing clients to directly update sensitive queue fields.

Possible RPC/function commands:

```text
join_queue(...)
activate_queue_entry(...)
confirm_driver_left(...)
mark_driver_absent(...)
reserve_queue_entry(...)
move_queue_entry_to_last(...)
cancel_queue_entry(...)
suspend_queue_entry(...)
transfer_queue_entry(...)
return_reserved_driver(...)
change_queue_capacity(...)
open_queue(...)
close_queue(...)
enable_qr(...)
disable_qr(...)
generate_qr_session(...)
undo_queue_event(...)
```

The UI should call these commands.

The UI should not be allowed to execute arbitrary:

```text
UPDATE queue_entries SET current_rank = ...
```

from the client.

---

# 20. Supabase Architecture

Use:

```text
Supabase
├── PostgreSQL
├── Auth
├── Realtime
├── Edge Functions
└── Storage (only if eventually needed)
```

## 20.1 PostgreSQL

Primary source of truth for queue state, relationships, and audit.

## 20.2 Supabase Auth

Authentication service.

For driver/operator authorization, use application roles linked to the authenticated user.

## 20.3 Supabase Realtime

Use Realtime Broadcast for low-latency synchronization/event delivery.

Supabase's current documentation describes Broadcast as a low-latency mechanism for sending messages between clients and from databases. Official docs: https://supabase.com/docs/guides/realtime/broadcast

Supabase's current Free Realtime limits include 200 concurrent connections and 100 messages/second. These are far above the initial 10–50-driver target, though limits should be rechecked when scaling. Official docs: https://supabase.com/docs/guides/realtime/limits

## 20.4 Prefer private topics

Use route-specific private channels.

Conceptual:

```text
queue:route:<route-id>
```

Drivers may subscribe only to their route.

Operators may subscribe to their assigned routes.

Never broadcast sensitive system data publicly.

---

# 21. Realtime Strategy

Do not send full queue snapshots every second.

Instead:

```text
Operator action
      ↓
Database transaction
      ↓
Queue state changes
      ↓
Broadcast event
```

Possible broadcast events:

```text
queue.updated
queue.position_changed
queue.driver_activated
queue.driver_reserved
queue.driver_moved
queue.capacity_changed
queue.status_changed
```

For simplicity, an MVP can broadcast a compact route-state payload or a version invalidation event.

Example:

```json
{
  "type": "queue.updated",
  "routeId": "...",
  "queueVersion": 1827
}
```

Driver then fetches authoritative state.

This is often safer than trying to make the client reconstruct all queue logic from tiny event fragments.

---

# 22. Realtime Client Strategy

Driver:

1. Load SQLite cache.
2. Render immediately.
3. Authenticate.
4. Connect to route channel.
5. Receive update notification.
6. Fetch authoritative state.
7. Replace local cache.
8. Render updated state.

Operator:

1. Load cache.
2. Connect to route channels.
3. Fetch latest.
4. Subscribe to changes.
5. Execute mutations through RPC/backend functions.
6. Update local cache after successful server result.

---

# 23. Local SQLite Schema

Keep the local DB small.

Suggested:

```text
local_user
local_route
local_queue_snapshot
local_queue_entries
local_notifications
local_sync_metadata
```

## 23.1 sync metadata

```text
route_id
last_server_version
last_synced_at
connection_state
```

## 23.2 queue snapshot

Store enough data to render:

- Position.
- Driver.
- Tricycle number.
- Status.
- User's own state.
- Capacity.
- Route.
- Queue status.
- Last updated time.

---

# 24. Offline Safety

Never allow:

```text
offline local position
     ↓
overwrite server
```

Instead:

```text
offline local position
     ↓
DISPLAY ONLY
```

When online:

```text
server state
     ↓
replace local state
```

Server always wins.

---

# 25. App Performance Requirements

Triko must run smoothly on low-end Android devices.

## 25.1 Performance goals

Target:

- Fast app startup.
- Immediate cached UI.
- Minimal JS work.
- Minimal network calls.
- Low memory usage.
- No unnecessary polling.
- Smooth queue updates.
- Small APK/resource footprint.

## 25.2 Technical rules

Use:

- React Native + Expo.
- TypeScript.
- Zustand.
- SQLite.
- `FlatList` for lists.
- Memoized queue row components.
- Selective Zustand subscriptions.
- Reanimated only where useful.
- Lightweight custom components.

Avoid:

- Large UI frameworks.
- Heavy image assets.
- Video backgrounds.
- Excessive blur.
- Constant background animation.
- Polling every second.
- Large bundled JSON.
- Excessive dependencies.
- Rendering the entire application from one giant global Zustand selector.

## 25.3 Startup

Preferred flow:

```text
App starts
   ↓
Load SQLite
   ↓
Render immediately
   ↓
Network sync in background
   ↓
Replace stale data
```

Do not show a blank loading screen while waiting for the network.

---

# 26. Recommended Mobile Stack

## Core

```text
React Native
Expo
TypeScript
```

## Navigation

```text
Expo Router
```

## State

```text
Zustand
```

## Local persistence

```text
expo-sqlite
```

Expo currently documents `expo-sqlite` as a persisted SQLite database layer for Expo apps:
https://docs.expo.dev/versions/latest/sdk/sqlite/

## Notifications

```text
expo-notifications
FCM / Android push infrastructure
```

## Camera/QR

Use an Expo-compatible camera/barcode scanning package appropriate to the current Expo SDK.

## Animation

```text
react-native-reanimated
```

Use sparingly.

## Styling

Prefer a small custom design system.

Possible:

```text
NativeWind
```

or a lightweight StyleSheet-based system.

Do NOT introduce a huge component framework merely to speed up development.

---

# 27. UI Design System

Triko should look premium but remain extremely simple.

## 27.1 Design direction

Think:

- Native mobile.
- Apple-like clarity.
- Material 3 interaction principles.
- Linear-style spacing.
- High contrast.
- Large typography.
- Soft cards.
- Minimal ornament.

## 27.2 Avoid

- Excessive gradients.
- Glassmorphism everywhere.
- Neon UI.
- Busy dashboards.
- Too many colors.
- Decorative illustrations that reduce performance.
- Tiny text.

## 27.3 Components

Create a small reusable design system:

```text
TrikoScreen
TrikoHeader
TrikoButton
TrikoIconButton
TrikoCard
TrikoQueuePosition
TrikoStatusBadge
TrikoQueueRow
TrikoConfirmationDialog
TrikoBottomSheet
TrikoEmptyState
TrikoOfflineBanner
TrikoNotificationCard
TrikoNumberDisplay
```

---

# 28. Driver Screens

Minimum driver screens:

## 28.1 Login

```text
TRIKO

Tricycle Number
[ TRI-123 ]

PIN
[ **** ]

[ LOGIN ]
```

No unnecessary registration flow.

## 28.2 Home

Main information:

```text
TRI-123

#8

4 AHEAD

🟡 WAITING

NEXT ALERT
#6
```

## 28.3 Queue

Shows nearby queue context.

Do not overwhelm with 100 rows.

Prioritize:

- User.
- Active queue.
- Nearby positions.
- Optionally full queue.

Example:

```text
ACTIVE

#1 TRI-101
#2 TRI-205
#3 TRI-317

WAITING

#4 TRI-411
#5 TRI-522
#6 TRI-631
#7 TRI-704
#8 YOU
```

## 28.4 Alerts

List important notifications.

## 28.5 Profile

Minimal.

Show:

- Name.
- Tricycle.
- Route.
- Notification settings.
- PIN change.
- Language.

---

# 29. Operator Screens

Minimum:

## 29.1 Route selector

If operator manages multiple routes:

```text
MY ROUTES

Kidapawan → Magpet
Kidapawan → Matalam
Kidapawan → Makilala
Kidapawan → Poblacion
```

## 29.2 Queue control

Main operational screen.

## 29.3 Driver search/select

Very simple search:

- Tricycle number.
- Driver name.

## 29.4 QR screen

```text
QR JOIN
ON

Starts:
5:30 AM

[ SHOW QR ]

[ DISABLE QR ]
```

## 29.5 Queue settings

- Capacity.
- Open/close.
- QR start time.
- QR enabled/disabled.

## 29.6 History

Simple audit timeline.

---

# 30. Operator Error Protection

Actions must be human-friendly.

Example:

```text
Move TRI-411 to last?

Current:
#4

New:
Last

[ CANCEL ] [ MOVE ]
```

After execution:

```text
Moved TRI-411 to last.

[ UNDO ]
```

History:

```text
10:34 AM
Operator Benjie

TRI-411
#4 → LAST

[ DETAILS ]
```

---

# 31. Audit / Event Sourcing Principles

Do not rely only on the latest state.

Keep event history.

Example:

```text
10:20
Juan joined queue

10:24
Juan became #8

10:31
Juan became #6

10:40
Juan marked absent

10:41
Juan reserved

11:05
Juan returned

11:06
Juan activated

11:50
Juan completed
```

This makes disputes and support much easier.

The event log should be append-only except for clearly defined administrative corrections.

Do not physically delete historical events casually.

---

# 32. Undo Architecture

Undo should be modeled as a new event, not destructive database erasure.

Example:

Original:

```text
DRIVER_RESERVED
```

Undo:

```text
UNDO_DRIVER_RESERVED
```

The event log retains both.

The queue state is restored through a transaction.

This is safer and auditable.

---

# 33. Security

Even though the app is a community initiative, do not skip basic security.

## 33.1 Server-side authorization

Never trust:

```text
role = operator
```

from the client.

Use authenticated user identity + database policy.

## 33.2 Row Level Security

Use Supabase RLS.

Drivers should only read:

- Their own profile.
- Their assigned route.
- Their route queue data.
- Their own notifications.

Operators should only manage:

- Their assigned routes.
- Drivers/queue participants allowed within those routes.

## 33.3 Sensitive keys

Never embed:

- Supabase secret/service-role key.
- SMS provider secret.
- TextBee API key.

in the mobile app.

Public client key only.

Sensitive operations run server-side.

## 33.4 PIN storage

Never store plain-text PINs.

Use secure authentication methods or properly hashed credentials.

If implementing custom PIN authentication, do not invent your own cryptographic password system. Prefer Supabase Auth or a secure server-side credential flow.

## 33.5 QR token security

QR tokens must:

- Be random.
- Be scoped to a route/session.
- Have activation/expiration.
- Be invalidated when disabled.
- Not contain sensitive data.

---

# 34. Database Integrity Requirements

Use foreign keys.

Use unique constraints where required.

Examples:

```text
tricycle_number UNIQUE
driver profile link UNIQUE
route/operator assignment constraints
```

Use transactions for queue mutations.

Prevent:

- Duplicate driver in same queue.
- Duplicate active participation.
- Multiple reserved priority values.
- Invalid transfer chains.
- Invalid route assignments.
- Cross-route queue mutation by unauthorized operators.

---

# 35. QR Abuse Prevention

Scenario:

A driver scans QR at 2:00 AM even though joining starts at 5:30 AM.

The backend must reject:

```text
Queue join not yet open.
```

Scenario:

Driver scans QR twice.

Backend should return:

```text
Already in this queue.
```

Scenario:

Driver scans a QR from yesterday.

Backend should reject:

```text
QR session expired.
```

Scenario:

QR disabled by operator.

Reject even if token is technically valid.

---

# 36. Driver Queue Join Rules

When a driver attempts to join:

Server checks:

1. Authenticated.
2. Driver account active.
3. Driver already not in another active route queue.
4. Route queue is open.
5. QR mode is active if joining by QR.
6. Current time is within QR window.
7. Driver is eligible.
8. Driver is not already participating in this queue.
9. Capacity/queue rules allow joining.
10. Assign next valid queue sequence.

Then transaction:

```text
create queue entry
record QUEUE_JOINED
update queue state/version
determine notification state
commit
```

---

# 37. Queue Continuity Across Days

Because the last position continues to the next day:

Do not blindly:

```text
DELETE queue
RESET positions
```

at midnight.

Instead preserve order.

The implementation should distinguish:

- Calendar date.
- Queue operating session.
- Driver participation lifecycle.
- Position sequence.

A future system may introduce explicit "operating sessions" while keeping the same logical queue.

---

# 38. Queue Session Concept

Even with cross-day continuity, a `queue_session` concept can be useful.

Conceptually:

```text
Queue
  ↓
Operating sessions
  ↓
Events
  ↓
Entries
```

But do not make sessions force a reset.

Session boundaries should be operational metadata, not automatic FIFO destruction.

---

# 39. State vs Derived Position

Important:

`current_rank` should be treated as a display/derived state, not the ultimate business truth.

The deeper state is:

- Queue sequence.
- Reservation sequence.
- Active status.
- Transfer entitlement.
- Suspension status.
- Completion status.

Position should be computed or updated transactionally.

This reduces corruption.

---

# 40. Notification Engine

Do not send notifications directly from the mobile app.

Backend determines threshold crossing.

## 40.1 Algorithm

```text
old_position = 11
new_position = 10

thresholds = [10, 8, 6, 4, 2, 1]

if old_position > threshold and new_position <= threshold:
    create notification
```

For each threshold:

```text
10
8
6
4
2
1
```

Do not send duplicate notifications for the same threshold.

Track:

```text
driver
queue participation
threshold
notification status
```

## 40.2 Special case: jumps

If position jumps:

```text
#12 → #8
```

The system should determine whether #10 and #8 should both generate alerts.

Recommended product behavior:

- Send only the new most relevant threshold.
- Avoid spam.

For example:

```text
#12 → #8

Send:
#8 — Duol na imong turno.

Do not send:
#10
```

The notification engine should have deterministic rules.

---

# 41. Offline Push Reality

A completely offline phone cannot receive a network push in real time.

Therefore:

```text
NO INTERNET
=
NO REALTIME PUSH
```

Do not pretend otherwise.

For a driver without internet:

- Last known state remains visible.
- SMS can be used as fallback if available.
- When connectivity returns, sync immediately.
- Missed in-app alerts can be displayed based on server-side notification history.

---

# 42. Missed Notifications

When driver reconnects:

```text
Last seen:
#10

Current:
#4
```

The app should not necessarily replay six notifications.

Instead show a concise summary:

```text
QUEUE UPDATED

You are now #4.

You missed 2 important
queue updates while offline.
```

Then show notification history if needed.

---

# 43. Connection State

Use clear states:

```text
🟢 LIVE
⚠ SYNCING
⚫ OFFLINE
```

The user must always know whether the queue is live.

Avoid technical terms like:

> WebSocket disconnected.

Say:

> Offline.

---

# 44. App Startup Strategy

Driver:

```text
Launch
↓
Load cached state immediately
↓
Render
↓
Authenticate/session check
↓
Connect
↓
Sync
```

Operator:

Same, but operator actions remain disabled until authoritative online state is established.

---

# 45. Error UX

Never expose:

```text
PostgrestException
PGRST116
Network request failed
UUID validation error
```

Instead:

```text
Something went wrong.

Please try again.
```

For offline:

```text
You are offline.

The queue changes are temporarily unavailable.
```

For stale state:

```text
Updating queue...
```

---

# 46. Accessibility / Readability

Use:

- Large type.
- Strong contrast.
- Clear iconography.
- Generous touch targets.
- Avoid tiny labels.
- Avoid dense tables on driver side.

Buttons should be easy to tap.

Do not make important actions dependent on tiny icons.

---

# 47. Driver Onboarding

The driver should not need a tutorial video.

First login:

```text
WELCOME TO TRIKO

Your tricycle:
TRI-123

Your position:
#8

When your position gets:
#10
#8
#6
#4
#2
#1

Triko will alert you.
```

One screen.

Optional short visual walkthrough.

Do not force multiple onboarding screens.

---

# 48. Operator Onboarding

Operator gets a short first-run setup:

```text
1. Create/select route
2. Set capacity
3. Set queue start
4. Set QR join start
5. Add drivers
6. Open queue
```

Then land directly on Queue Control.

---

# 49. Operator Daily Flow

Suggested:

```text
4:00 AM
Open queue

↓
Set/verify capacity

↓
Enable QR at configured time

↓
Drivers join

↓
Queue grows

↓
Active drivers leave

↓
Operator confirms departure

↓
Next waiting drivers become active

↓
Absent driver:
Reserve / Move Last / Cancel

↓
Continue

↓
Close queue when terminal closes
```

This is the operational heart of Triko.

---

# 50. Driver Daily Flow

```text
Log in
↓
View queue
↓
Wait / leave terminal
↓
Find passengers / stroll
↓
Receive #10 alert
↓
Continue
↓
Receive #8 alert
↓
Continue
↓
Receive #6 alert
↓
Prepare
↓
Receive #4 alert
↓
Return toward terminal
↓
Receive #2 alert
↓
Return
↓
Receive #1 alert
↓
Wait for operator
↓
Turno active
↓
Complete trip
```

---

# 51. MVP Scope

Do NOT overbuild.

## Must have

### Driver

- Login.
- Home.
- Queue position.
- Queue list.
- Notifications.
- Offline cached view.
- Push notifications.
- QR join.
- Status display.

### Operator

- Login.
- Route selection.
- Queue control.
- Add/assign driver.
- Activate.
- Complete/confirm leave.
- Absent decision.
- Reserve.
- Move to last.
- Cancel.
- Suspend.
- Transfer.
- Undo.
- Queue capacity.
- Open/close queue.
- QR enable/disable.
- QR activation time.
- Basic history.

### Backend

- Supabase Auth.
- PostgreSQL.
- RLS.
- Queue transaction functions/RPC.
- Realtime.
- Notification events.
- Device token management.
- Audit events.

## Later

- SMS fallback.
- Analytics.
- Automatic estimated waiting time.
- Advanced reports.
- Superadmin.
- Multiple associations.
- Play Store release.
- Advanced admin dashboard.
- Route performance analytics.

---

# 52. Do Not Build in MVP

Avoid:

- GPS driver tracking.
- Live map.
- Complex geofencing.
- Payments.
- In-app chat.
- Passenger booking.
- Driver ratings.
- Ads.
- Social features.
- Complex analytics.
- AI queue predictions.
- Automatic absence decisions.
- Multi-operator simultaneous mutation of one route.
- Full offline operator mutation/merge.

The problem is queue visibility and management.

Stay focused.

---

# 53. Project Structure

Suggested React Native project:

```text
triko/
├── app/
│   ├── _layout.tsx
│   ├── index.tsx
│   │
│   ├── (auth)/
│   │   ├── login.tsx
│   │   └── ...
│   │
│   ├── (driver)/
│   │   ├── _layout.tsx
│   │   ├── home.tsx
│   │   ├── queue.tsx
│   │   ├── alerts.tsx
│   │   └── profile.tsx
│   │
│   └── (operator)/
│       ├── _layout.tsx
│       ├── routes.tsx
│       ├── queue.tsx
│       ├── driver.tsx
│       ├── qr.tsx
│       ├── history.tsx
│       └── settings.tsx
│
├── src/
│   ├── components/
│   ├── design-system/
│   ├── features/
│   │   ├── auth/
│   │   ├── driver/
│   │   ├── operator/
│   │   ├── queue/
│   │   ├── notifications/
│   │   └── qr/
│   │
│   ├── hooks/
│   ├── lib/
│   │   ├── supabase.ts
│   │   ├── sqlite.ts
│   │   ├── notifications.ts
│   │   └── connectivity.ts
│   │
│   ├── store/
│   ├── types/
│   ├── utils/
│   └── constants/
│
├── supabase/
│   ├── migrations/
│   ├── functions/
│   │   ├── notifications/
│   │   ├── qr/
│   │   └── sms/
│   └── seed/
│
├── assets/
└── package.json
```

Use a feature-oriented architecture so queue logic remains isolated.

---

# 54. Recommended Client Modules

## auth

Handles:

- Session.
- Role.
- Login.
- Logout.
- PIN operations.

## queue

Handles:

- Queue display.
- Current state.
- Entry state.
- Sync.
- Realtime.

## operator

Handles operator commands.

## notifications

Handles:

- Push registration.
- Device tokens.
- In-app history.
- Local display.

## qr

Handles:

- Camera.
- QR parsing.
- Join request.

## connectivity

Handles:

- Online/offline status.
- Sync triggers.

---

# 55. Recommended Backend Modules

```text
queue_engine
notification_engine
authorization
qr_service
audit_service
sms_adapter
```

The queue engine must be domain-oriented.

Do not make every screen independently implement queue rules.

---

# 56. Supabase RLS Concept

Driver policies should roughly enforce:

```text
Driver can read own profile.
Driver can read assigned route.
Driver can read queue state of assigned route.
Driver can read his own notifications.
Driver cannot mutate queue ordering.
```

Operator policies:

```text
Operator can read assigned routes.
Operator can mutate queues only for assigned routes.
Operator can manage drivers on assigned routes.
Operator cannot mutate another operator's route unless explicitly assigned.
```

Sensitive mutations should still go through server-side RPC/functions even with RLS.

---

# 57. API / RPC Contract Philosophy

Use commands like:

```text
reserve_driver(entry_id)
```

rather than:

```text
update_entry(entry_id, status="reserved", rank=...)
```

The first encodes a business operation.

The second exposes internals and makes invalid states easier to create.

---

# 58. Testing Strategy

This application needs strong business-rule testing.

## 58.1 Unit tests

Test:

- Queue ordering.
- Active capacity.
- Reservation ordering.
- Transfer rule.
- Transfer cannot happen twice.
- Suspended driver.
- Cancelled driver.
- Cross-day continuity.
- Notification threshold crossing.
- Duplicate notification prevention.

## 58.2 Integration tests

Test:

- Operator mutation → database → realtime.
- Operator mutation → notification event.
- Driver reconnect → latest state.
- QR join.
- Disabled QR.
- Expired QR.
- Unauthorized operator route mutation.

## 58.3 Offline tests

Simulate:

```text
Online
↓
Driver leaves
↓
Internet OFF
↓
Queue changes
↓
Driver receives SMS if configured
↓
Internet returns
↓
Driver syncs
```

Also:

```text
Open app offline
```

must show cached state.

## 58.4 Low-end device tests

Test on actual low-cost/old Android phones.

Measure:

- Startup time.
- Memory use.
- Scroll smoothness.
- Notification delivery.
- Battery impact.
- SQLite performance.
- Reconnect behavior.

Do not test only on a high-end development device.

---

# 59. Real-World Usability Testing

This is mandatory.

Test with actual drivers/operators.

Do not ask:

> "Do you like it?"

Ask:

> "Asa imong turno?"

> "Unsa imong buhaton kung #4 ka?"

> "Unsa pasabot ani?"

> "Kung offline ka, kabalo ba ka nga old data ni?"

> "Unsa imong buhaton kung reserve?"

Watch what they do without helping them.

The app passes only when users can complete tasks without developer coaching.

---

# 60. Pilot Deployment

Start with:

- One operator.
- One route.
- 10–20 drivers.

Do not immediately deploy across 10 routes.

Pilot sequence:

```text
Week / Phase 1
Operator only

↓
Operator + 2 test drivers

↓
5 drivers

↓
10 drivers

↓
Entire route
```

Collect real incidents.

Especially watch:

- QR abuse.
- Driver absent.
- Reservation.
- Transfer.
- Operator mistakes.
- Offline state.
- Notifications.
- Duplicate queue entries.

---

# 61. Critical Edge Cases

The system must explicitly handle:

1. Driver scans QR twice.
2. Driver tries to join another route while already queued.
3. QR disabled after a driver opens scanner.
4. QR expired.
5. Driver has no internet.
6. Operator has no internet.
7. Driver receives stale queue data.
8. Driver reconnects after many queue changes.
9. Operator accidentally performs wrong action.
10. Operator presses Undo.
11. Multiple reserved drivers.
12. Reserved driver returns.
13. Reserved driver transfers.
14. Transferred driver attempts another transfer.
15. Active driver is suspended.
16. Queue capacity changes while queue is active.
17. Queue closes with waiting drivers.
18. Queue reopens.
19. Driver changes tricycle assignment.
20. Same tricycle is driven by another person later.
21. Driver leaves and returns across midnight.
22. Queue continues into next day.
23. Driver logs in on a second phone.
24. Old phone receives push token after replacement.
25. Notification threshold already sent.
26. Position jumps over multiple thresholds.
27. Driver moves to another route.
28. Operator loses access to a route.
29. Operator account becomes inactive.
30. Database/network failure during a queue mutation.

---

# 62. Notification Deduplication

Never let a driver receive:

```text
#8
#8
#8
#8
```

for the same threshold.

Uniqueness concept:

```text
driver_id
queue_entry_id
threshold
notification_type
```

Use a unique constraint or transaction-safe deduplication.

---

# 63. Queue Versioning

Maintain:

```text
queue_version
```

Every successful mutation increments it.

Example:

```text
1827
1828
1829
1830
```

Client stores last known version.

If client has:

```text
version 1827
```

and server is:

```text
1834
```

client knows it needs synchronization.

---

# 64. Server Authority Rule

This rule should be written in the project README/CLAUDE.md:

> **The mobile client is never the authority for queue state.**

Client may:

- Display.
- Request.
- Cache.
- Subscribe.
- Acknowledge.

Server determines:

- Position.
- Priority.
- Eligibility.
- Reservation.
- Transfer legality.
- Activation.
- Suspension.
- Queue state.

---

# 65. Claude Opus Development Guidance

Claude should be instructed to behave as:

- Senior React Native engineer.
- Senior PostgreSQL engineer.
- Product designer.
- UX researcher for low-literacy users.
- Security reviewer.
- Performance engineer.

Before coding a feature, Claude should:

1. Understand business rules.
2. Check state transitions.
3. Check offline implications.
4. Check RLS/security.
5. Check low-end performance.
6. Check UX simplicity.
7. Implement tests.
8. Avoid unnecessary dependencies.

Claude should never silently invent queue rules.

If a rule isn't defined, use the safest existing rule or mark it explicitly for product clarification rather than casually changing queue behavior.

---

# 66. Claude Coding Rules

Recommended instructions:

```text
- TypeScript strict mode.
- Keep components small.
- Keep domain logic out of UI components.
- Keep queue logic in domain/backend functions.
- Never duplicate queue business rules across multiple screens.
- Use server-authoritative operations.
- Use transactions for queue mutations.
- Use RLS.
- Do not expose secret keys.
- Do not add packages without justification.
- Optimize for low-end Android.
- Do not add complex animations unless they help comprehension.
- Do not use heavy UI frameworks unless necessary.
- Always test offline state.
- Always test reconnect state.
- Always test destructive actions and undo.
- Prefer accessible, large controls.
- Avoid long text.
- Do not assume every user is technically literate.
```

---

# 67. Product Design Rules for Claude

Claude should follow:

```text
Driver UI:
- Very few screens.
- Very few decisions.
- Huge queue number.
- Clear state.
- Minimal text.
- Strong icon + text pairing.
- Local-language-ready.
- Offline indicator.
- No unnecessary dashboards.

Operator UI:
- Queue first.
- Route switcher.
- Large tap targets.
- Clear active/waiting separation.
- High-impact actions require confirmation.
- Undo is obvious.
- No hidden important actions.
```

---

# 68. Accessibility for Low-Tech Users

Target:

```text
Few words.
Big numbers.
Big buttons.
High contrast.
Simple icons.
Consistent colors.
Consistent placement.
No confusing gestures.
No long forms.
No deep menus.
```

Do not rely on:

- Color alone.
- Tiny badges.
- Swipe-only important actions.
- Long instructions.

---

# 69. Performance Rules for Low-End Phones

Avoid:

```text
Infinite background work
Aggressive polling
Large images
Video
Heavy gradients
Complex SVG illustrations
Many simultaneous subscriptions
Unnecessary re-renders
Large global state
```

Prefer:

```text
Cached state
Small payloads
Selective subscriptions
FlatList
Memoization
Lazy screens
Small bundles
Simple animations
```

---

# 70. Dependency Philosophy

Every dependency creates:

- Bundle size.
- Maintenance.
- Possible bugs.
- Upgrade cost.
- Native build complexity.

Use as few dependencies as practical.

Before adding a package, ask:

1. Does React Native/Expo already provide it?
2. Is it necessary?
3. Does it hurt low-end performance?
4. Does it create native build complexity?
5. Is it actively maintained?

---

# 71. Recommended Development Sequence

## Phase 1 — Product specification

Create:

- Requirements.
- State transitions.
- Roles.
- Permissions.
- Notification rules.
- Offline behavior.
- Edge cases.

## Phase 2 — UX prototype

Design:

- Driver login.
- Driver home.
- Queue.
- Alerts.
- Operator routes.
- Operator queue.
- Driver actions.
- QR.
- Confirmation/undo.

Test with real users before backend completion.

## Phase 3 — Database

Build:

- Schema.
- Constraints.
- RLS.
- Events.
- Queue transaction functions.

## Phase 4 — Queue engine

Implement and test:

- Join.
- Activate.
- Complete.
- Reserve.
- Move last.
- Cancel.
- Suspend.
- Transfer.
- Undo.
- Capacity.

## Phase 5 — Mobile foundation

Implement:

- Auth.
- Navigation.
- Design system.
- SQLite.
- Connectivity.

## Phase 6 — Driver app

Build first.

## Phase 7 — Operator app

Build second.

## Phase 8 — Realtime

Add:

- Broadcast.
- Sync.
- Versioning.

## Phase 9 — Push notifications

Implement thresholds.

## Phase 10 — Offline behavior

Stress test reconnect and stale cache.

## Phase 11 — QR

Implement secure dynamic session QR.

## Phase 12 — Real-world pilot

One route.

## Phase 13 — SMS fallback

Only after real usage proves the need.

## Phase 14 — Scale / Play Store

After stable pilot.

---

# 72. Definition of Done for MVP

The MVP is not "done" when the app runs.

It is done when:

### Driver

- Can log in.
- Can join.
- Can see position.
- Can leave terminal.
- Can view cached position offline.
- Receives threshold alerts.
- Sees live updates when online.
- Reconnects safely.
- Does not need to understand technical concepts.

### Operator

- Can manage multiple routes.
- Can view queue.
- Can activate/complete drivers.
- Can handle absent drivers.
- Can reserve.
- Can move to last.
- Can cancel.
- Can suspend.
- Can transfer.
- Can undo.
- Can manage capacity.
- Can open/close queue.
- Can control QR.
- Can view history.

### Backend

- Queue mutations are transactional.
- RLS is tested.
- Unauthorized mutations fail.
- Audit history is complete.
- Notification deduplication works.
- Realtime works.
- Offline sync works.
- No secrets are exposed.

### UX

- Real users can understand their position without training.
- Operator can manage a complete turno cycle without developer assistance.
- App remains usable on a low-end Android phone.
- Important states are readable at a glance.

---

# 73. Future Features

Possible future extensions:

## 73.1 Estimated wait time

```text
#8
Estimated:
35–45 min
```

Based on real historical queue movement.

## 73.2 Queue analytics

Operator could see:

- Average turnover time.
- Peak hours.
- Daily queue length.
- Driver wait duration.
- Turno utilization.

## 73.3 Association management

Multiple associations/terminals.

## 73.4 Admin portal

Web dashboard for administrators.

## 73.5 Better SMS integration

Multiple gateways/providers.

## 73.6 Play Store

Automatic updates.

## 73.7 Multi-terminal support

Driver may have terminal/route assignments managed by an association.

Do not build these until the basic queue system is reliable.

---

# 74. Explicit Non-Goals

Triko is not initially:

- A ride-hailing app.
- A passenger booking service.
- A GPS tracking service.
- A payment system.
- A social app.
- A marketplace.
- An advertising platform.

The product is:

> **Queue visibility + operator queue management + notifications.**

Keep the scope disciplined.

---

# 75. Final Architecture

```text
                         ┌─────────────────────┐
                         │       TRIKO         │
                         └──────────┬──────────┘
                                    │
                          React Native + Expo
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
              DRIVER APP                      OPERATOR APP
                    │                               │
                 SQLite                         SQLite
              local cache                    local cache
                    │                               │
                    └───────────────┬───────────────┘
                                    │
                               Supabase
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
         PostgreSQL              Auth                 Realtime
              │                                           │
              │                                      Broadcast
              │                                           │
              └────────────────┬──────────────────────────┘
                               │
                         Queue Engine
                               │
                ┌──────────────┼──────────────┐
                │              │              │
              Audit       Notifications     QR
                │              │              │
                               │
                     ┌─────────┴─────────┐
                     │                   │
                   Push                 SMS
                  / FCM               fallback
                     │                   │
                     │                TextBee/
                     │                future SMS
                     │
                     └──────── DRIVER ────────┘
```

---

# 76. Source of Truth Hierarchy

Use this hierarchy:

```text
1. PostgreSQL authoritative state
2. Backend queue transactions
3. Queue event history
4. Realtime synchronization
5. Local SQLite cache
6. Push/SMS notifications
```

Notifications are not the queue.

SQLite is not the queue.

The client is not the queue.

**PostgreSQL + backend queue engine = truth.**

---

# 77. Final Product Principle

The technology may become sophisticated underneath.

The app should NOT feel sophisticated to the user.

The final experience should be:

### Driver:

> Open Triko → see #8 → go do something else → get alert → return.

### Operator:

> Open route → see queue → tap driver → choose action → confirm → done.

That simplicity is the product's competitive advantage.

---

# 78. Recommended Initial Technology Stack Summary

```text
Mobile:
React Native
Expo
TypeScript
Expo Router
Zustand
expo-sqlite
expo-notifications
Reanimated
Expo-compatible QR/barcode scanning

Backend:
Supabase
PostgreSQL
Supabase Auth
Supabase Realtime
Supabase Edge Functions
PostgreSQL functions/RPC

Notifications:
FCM via Expo Notifications
SMS fallback later

SMS:
TextBee or replaceable SMS gateway adapter

Offline:
SQLite
last-known-state cache
server-authoritative re-sync

Distribution:
Direct APK initially
Google Play later

Design:
Custom lightweight design system
Native mobile feel
Large typography
Low-literacy friendly
Local-language ready
Low-end Android optimized
```

---

# 79. Final Instruction for Implementation

When implementing Triko:

> **Do not start by coding screens.**
>
> First implement and test the domain rules:
>
> - queue ordering
> - active capacity
> - reservation
> - absent driver handling
> - transfer
> - suspension
> - undo
> - queue continuity
> - notification thresholds
> - authorization
>
> Then build the user interface on top of those rules.

The application should be treated as a **queue-management system with a very simple mobile interface**, not as a generic CRUD application.

The most important success metric is not the number of features.

It is:

> **Can an operator with minimal technical literacy manage a real turno without confusion, and can a driver with minimal technical literacy understand exactly when to return?**

If the answer is yes, Triko is solving the correct problem.
