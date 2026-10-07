# Performance audit

Rule: **measured or clearly-caused problem → likely cause → expected impact → proportionate fix.**
Never "optimize" without a cause. A `useMemo` on a cheap value, a cache in front of a fast query,
or a CDN for a ten-user internal tool are findings *against* premature optimization, not for it.

Use evidence the project already produces: build output sizes, bundle analyzer output if present,
Lighthouse/Web Vitals reports, query plans in migrations, logs. If none exist, reason from code and
mark impact as estimated.

## Frontend
- **Bundle:** initial JS size (budget ~170 KB gz for a mobile-first app is a common JUDGMENT
  benchmark); large dependencies for small uses (moment, lodash whole, chart libs on every route,
  icon packs imported wholesale); duplicate copies of one library.
- **Splitting:** routes lazy-loaded? Heavy modals/charts/editors loaded on demand? Admin-only code
  shipped to every user?
- **Rendering:** components re-rendering on every keystroke because state sits too high; context
  providers with unstable values; lists without stable keys; expensive work in render;
  effects that fetch in loops; layout thrash (read-then-write DOM in loops).
- **Lists:** long lists rendered fully (virtualize past ~200 rows) or paged server-side.
- **Network:** request waterfalls (sequential fetches that could be parallel or joined); the same
  data fetched by several components without a shared cache; no request de-duplication;
  over-fetching columns; polling where realtime or focus-refetch would do; no `stale` window.
- **Assets:** images without dimensions (layout shift), wrong formats/sizes, no lazy loading
  below the fold; web fonts blocking text (no `font-display`), too many weights.
- **Memory:** listeners, intervals, subscriptions, observers not cleaned up; caches that grow
  without bound.

## Backend and data
- **N+1:** a query per row in a loop, per-item API calls from the client, ORM lazy loads in lists.
- **Indexes:** every foreign key and every column used in `WHERE`, `ORDER BY`, `JOIN` on large
  tables; composite index order matches the query; no index on low-cardinality booleans alone.
- **Queries:** `SELECT *`; unbounded results (no limit/pagination); counting with `count(*)` on
  every page view of a huge table; functions in `WHERE` defeating indexes; `OFFSET` paging deep
  into large tables (keyset paging as JUDGMENT).
- **Transactions:** long transactions holding locks; work outside a transaction that must be atomic.
- **Connections:** pooling for serverless; connection per request.
- **Caching:** what is cached, how invalidated, can stale data cause a wrong business decision.
- **Serialization:** huge payloads, nested includes, base64 blobs in JSON.
- **Concurrency:** hot rows (counters, stock levels) updated without atomic operations.

## Mobile specifics
- Startup: time to first meaningful screen on a mid/low-end phone over slow 4G; app shell cached?
- First interaction: main thread blocked by hydration or big synchronous work.
- Scrolling: jank from heavy rows, box-shadows/blur on many elements, non-passive listeners.
- Animation: animating layout properties instead of `transform`/`opacity`; ignoring
  `prefers-reduced-motion`.
- Slow/intermittent networks: skeletons vs spinners, timeouts, retries, optimistic UI.

## Scale — realistic, not theoretical
Ask what breaks at 10 / 100 / 1,000 / 10,000 / 100,000 users **or rows**, and stop at the
order of magnitude the product will plausibly reach. Name the first real bottleneck (often a
missing index, an unpaged list or a client-side aggregate), not a distributed-systems redesign.

## Reporting
State the cause with evidence, the expected gain ("removes ~400 KB from the login route",
"turns 50 sequential requests into 1"), and how to measure before/after.
