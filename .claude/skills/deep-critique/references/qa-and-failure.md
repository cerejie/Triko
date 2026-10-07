# QA, edge cases, failure experience, testing strategy

The QA question: **how would I break this?** Then: **what does the user see, can they recover,
and could they lose data?**

## 1. Functional correctness
- Trace each core workflow end to end: input → validation → state → request → server rule →
  persistence → response → UI update → cache invalidation. Where can the chain disagree with itself?
- Business rules enforced in one place, or duplicated (client and server disagreeing on a limit,
  a price, a stock count)?
- Invalid states representable: can the UI show "paid" and "pending" at once? Can a record exist
  without a required relation? Are enums/status transitions guarded (voided → completed)?
- Derived values recomputed vs stored and drifting (totals, counts, balances).

## 2. Edge cases — run through the list that applies

| Data | Zero records · one · exactly the page size · thousands · very long text (names, emails, notes, URLs, numbers without spaces) · emoji / RTL / accents · null / missing / empty string · duplicates · negative and zero quantities · max integer / big money values · decimal rounding |
| Time | Timezones and DST · midnight and month/year boundaries · future and past dates · expired tokens, coupons, sessions · clock skew between client and server |
| Interaction | Double-click / double-tap submit · rapid repeated taps · back button mid-flow · refresh mid-form · two tabs open · open on two devices · paste into numeric fields · autofill |
| Network | Slow · offline · drops mid-request · request succeeds but response lost (retry duplicates?) · out-of-order responses (older search result overwrites newer) |
| Concurrency | Two users edit the same record · two cashiers sell the last unit · permission revoked while the user is mid-task · record deleted while open elsewhere |
| Lifecycle | First run with an empty database · account just created/approved/disabled · role changed while signed in · app updated while open |

## 3. Failure experience — for every core screen and write

| Failure | What to check |
|---|---|
| Network failure / timeout | Message in plain language, retry available, input preserved |
| Server 5xx | No raw error, no stack trace, a way forward |
| Validation error | Field-level, specific, announced to screen readers, focus moves to the first error |
| Expired session | Redirect to sign-in **and** come back to where the user was; unsaved input not silently lost |
| Unauthorized (403) | Explains, doesn't show a blank screen or a generic crash |
| Not found / deleted | Clear state, a way back |
| Empty data | Explains why it's empty and the next action (not just "No data") |
| Duplicate submission | Button disabled while pending; server idempotent for money/stock writes |
| Stale data | Refetch on focus/reconnect; conflicts detected rather than last-write-wins on important records |
| Partial failure | Multi-step writes atomic (transaction) or compensated; UI reflects the true state |
| Offline write | Queued with visible "pending", survives reload, replays once, surfaces failures |

For each: **Does the system explain what happened? Can the user recover? Could data be lost or
duplicated?** A failure path with no UI is a finding.

## 4. Reliability and testability
- Error handling: errors swallowed (`catch {}`), logged but not surfaced, or surfaced without
  context. Global error boundary present? Unhandled promise rejections?
- Race conditions: effects without cancellation; stale closures; optimistic updates without
  rollback; state set after unmount.
- Determinism: logic depending on `Date.now()`/random/locale without injection — hard to test.
- Regression risk: shared components and utilities with many dependents and no tests.

## 5. Testing strategy — risk-based, not coverage-based
Inventory what exists (unit, integration, API, component, E2E, security/policy, accessibility,
performance, visual) and map it against risk:

1. List the workflows whose failure costs money, data, trust or access (auth, payments/checkout,
   stock/ledger, permissions, data deletion, sync).
2. Mark each: tested at the right level? (Business rules → unit; DB policies → policy tests
   against a real DB; critical journeys → E2E; contracts → API tests.)
3. Flag: critical untested workflows; tests that assert implementation details (snapshot of
   markup, mocking everything); tests that never fail; flaky waits; no tests for authorization
   denial paths (tests usually only check that the allowed user succeeds).
4. Recommend the **smallest set** of tests that would catch the highest-risk regressions — name
   them concretely ("employee calling void RPC gets 403", "two concurrent checkouts of the last
   unit — one fails cleanly").

No test runner in the project is itself an observation — recommend one only proportionate to the
project's risk and size, and never install it as part of the critique.
