# Architecture, code quality, database, API, observability

Judge architecture against **the project's actual complexity and stated goals**, not against what
is fashionable. A small app with a clear layered structure is not "missing" microservices,
CQRS or DDD. An enterprise system held together by one god module is under-engineered.

## 1. System architecture
- **Boundaries:** domains, layers and modules each with one job? Dependency direction one-way
  (UI → logic → data)? Any layer skipped (UI calling the database directly when the project has a
  service layer)? Circular imports?
- **Coupling / cohesion:** a change to one feature forces edits across many folders? Shared
  "utils" or "common" modules that know about specific features?
- **God objects:** components, services, controllers or stores over a few hundred lines doing
  several jobs; one file every feature imports.
- **Abstractions:** wrappers that add nothing; generic layers with one implementation; factories
  for one product (over-engineering). Or the opposite: the same logic copy-pasted in many places
  (under-engineering). Count the copies — that is the evidence.
- **State:** server state vs client state separated? Server data copied into client stores and
  drifting? Derived state stored instead of computed? Global state for local concerns?
- **Data flow:** one obvious path for reads and for writes, or several ways to do the same thing?
- **Auth architecture:** one place resolves identity and role; every request path goes through it.
- **Config and environments:** typed, validated at startup, no prod values in code; feature flags
  documented.
- **Background work:** jobs, triggers, cron, webhooks, queues — idempotent, retried, observable?
- **Consistency:** does the codebase follow its own documented conventions? Inconsistency with the
  project's rules is FACT-level evidence; inconsistency with *your* rules is preference.

## 2. Code quality
For each issue: **problem → why it matters → evidence → risk → direction.**
- Duplication (with count and locations), dead and unreachable code, commented-out code.
- Functions/components too large or deeply nested; unclear names; magic numbers and strings.
- Error handling: swallowed, overly broad, or inconsistent formats.
- Hidden side effects in getters, renders or constructors; mutation of shared objects.
- Async: missing `await`, unhandled rejections, fire-and-forget writes, race conditions,
  effects without cleanup.
- Type safety: `any`/untyped escape hatches, unchecked casts at trust boundaries (API responses,
  storage, URL params) — validate at the edge.
- Framework misuse (see stack-adapters.md).
- Technical debt: TODO/FIXME/HACK density in critical paths; workarounds whose reason is gone.

## 3. Database
- **Schema:** relationships expressed as foreign keys; `NOT NULL` where the domain requires a
  value; `UNIQUE` where duplicates are impossible in reality; `CHECK` constraints for ranges and
  enums; consistent naming; appropriate types (money as integer cents or `numeric`, never float;
  timestamps with time zone).
- **Normalization:** duplicated facts that can drift; denormalization justified by a measured
  read need and kept in sync by a trigger or transaction.
- **Integrity:** cascading deletes that can wipe history; soft delete applied consistently
  (queries and unique indexes respect it); audit trail for financial/stock changes; ledgers
  append-only.
- **Transactions:** multi-row business operations atomic (a function/RPC or explicit transaction);
  concurrent updates to the same row safe (atomic `UPDATE … SET qty = qty - n WHERE qty >= n`,
  row locks, or optimistic versioning).
- **Indexes:** see performance.md.
- **Migrations:** forward-only and ordered; destructive changes staged (add → backfill → switch →
  drop); no data-dependent migrations without a guard; reversible or with a documented rollback.
- **Access:** policies/permissions per table and per operation (see security.md).

## 4. API
- Predictable naming and HTTP semantics (GET safe, PUT/DELETE idempotent, POST for creation and
  actions); correct status codes (not 200 with an error body).
- One error shape across endpoints, with a machine-readable code and a human message; no leaks.
- Validation of every input server-side; request size limits.
- Pagination, filtering and sorting consistent and bounded; total counts where the UI needs them.
- Idempotency keys for payments/checkouts and retried writes.
- Versioning or a compatibility story once there are external consumers.
- Authorization per endpoint, not per screen.
- RPC / function-style APIs (GraphQL, tRPC, Postgres RPC): same questions — contract, authz,
  validation, error shape, N+1 in resolvers.

## 5. Observability and operations
- Can the team answer "what failed, for whom, when, and why" at 2 AM? Structured logs with
  request/user correlation; error tracking (client and server); health checks; alerts on the
  failures that matter.
- Audit logs for security- and money-relevant actions.
- Deployment: reproducible builds, environment config outside code, preview environments,
  rollback path, migration safety (deploy order between schema and code).
- Client errors reported somewhere, or invisible?
