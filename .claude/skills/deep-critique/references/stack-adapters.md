# Stack adapters — detect first, then apply what fits

Detect the stack from manifests, lockfiles and config before applying any of this. Load only the
sections that match. If the stack is not listed, apply the general lenses and the closest
analogue, and say so in the Coverage line. Never fault a project for not using a stack it doesn't
use.

| Signal | Stack |
|---|---|
| `package.json` with `react`, `next`, `vue`, `nuxt`, `@angular/core`, `svelte`, `solid-js` | JS frontend framework |
| `vite.config.*`, `next.config.*`, `angular.json`, `nuxt.config.*`, `svelte.config.*` | Build/meta-framework |
| `manifest.webmanifest` / `manifest.json`, `sw.js`, `vite-plugin-pwa`, `workbox`, `next-pwa` | PWA → mobile-pwa.md mandatory |
| `express`, `fastify`, `nestjs`, `hono`, `koa` | Node backend |
| `*.csproj`, `*.sln`, `Program.cs` | .NET |
| `pyproject.toml`, `requirements.txt` with `django`, `fastapi`, `flask` | Python backend |
| `Gemfile` with `rails` · `composer.json` with `laravel` · `go.mod` · `Cargo.toml` · `pom.xml`/`build.gradle` | Rails · Laravel · Go · Rust · JVM |
| `supabase/`, `@supabase/supabase-js` · `firebase.json`, `firestore.rules` | BaaS |
| `migrations/`, `schema.prisma`, `drizzle.config.*`, `*.sql` | Database layer |
| `pubspec.yaml` · `android/` + `ios/` with React Native/Expo · `capacitor.config.*` | Native/hybrid mobile |
| `electron`, `tauri.conf.json` | Desktop |

## React (and Next.js)
- State placement: server state in a query cache (React Query/SWR/RTK Query) vs copied into
  `useState`/global stores; derived state stored; context with unstable values re-rendering trees.
- Effects: data fetching in `useEffect` without cancellation; effects syncing state to state;
  missing/incorrect dependencies (or lint rule disabled); effects as event handlers.
- Keys: index keys on reorderable lists. Components defined inside components.
- Memoization: missing where measured, cargo-culted where not.
- Forms: uncontrolled vs controlled chosen deliberately; validation schema shared with the server
  where possible.
- Next.js: server vs client components boundary (secrets or heavy libs in client components);
  `"use client"` at the top of large trees; server actions authorize the caller; caching and
  revalidation understood; `NEXT_PUBLIC_` exposure.

## Vue / Nuxt
- Reactivity pitfalls (destructuring reactive objects, losing reactivity), watchers doing what
  computed should, Pinia stores holding server data without invalidation, `v-html`.
- Nuxt: server routes authorize; `useFetch` keys and caching; runtime config public vs private.

## Angular
- Subscriptions not unsubscribed (prefer `async` pipe / `takeUntilDestroyed`), change detection
  strategy, heavy logic in templates, services as god objects, `bypassSecurityTrust*`.

## Svelte / Solid
- Store misuse, reactive statements with side effects, SSR/CSR boundary leaks.

## Node backends (Express, Fastify, Nest, Hono)
- Validation middleware on every route (zod/joi/class-validator); async errors reaching the error
  handler; auth middleware applied per route vs globally with gaps; `helmet`/CORS config;
  blocking sync calls on the event loop; unbounded body size.

## .NET
- Async all the way (no `.Result`/`.Wait()`), `DbContext` lifetime, EF Core N+1 and tracking,
  `[Authorize]` and policy coverage, model binding over-posting, exception middleware leaking
  details, configuration/secrets via user-secrets/Key Vault.

## Python (Django / FastAPI / Flask)
- Django: ORM N+1 (`select_related`/`prefetch_related`), permission classes on every view,
  `DEBUG=False` in prod, raw SQL. FastAPI: Pydantic validation at the edge, dependency-injected
  auth on every router, sync DB calls in async routes.

## Rails / Laravel
- Strong params / mass assignment, N+1 (bullet-style), authorization (Pundit/Policies) on every
  action, callbacks with hidden side effects.

## Go / Rust / JVM
- Error handling discipline, context cancellation/timeouts, goroutine/thread leaks, connection
  pools, input validation at handlers.

## Supabase
- RLS enabled on **every** table in exposed schemas; policies per operation with `WITH CHECK`;
  `SECURITY DEFINER` functions set `search_path` and check the caller's role; `EXECUTE` grants on
  functions reviewed (default grants to `anon`/`authenticated`); service-role key never in the
  client; storage bucket policies; edge functions verify JWT or a shared secret; Realtime
  channels respect RLS; explicit column lists, `.range()` paging, errors checked on every call.

## Firebase
- Firestore/Storage rules deny by default, validate shape and ownership; no admin SDK in the
  client; Cloud Functions verify auth context; indexes for queries.

## PostgreSQL / ORMs (Prisma, Drizzle, TypeORM, Sequelize)
- Constraints and indexes per architecture-and-code.md § 3; migrations generated and reviewed;
  raw query escape hatches parameterized; transactions around multi-write operations.

## Tailwind / CSS systems / component libraries
- Tokens defined once (CSS variables/theme) and used everywhere; arbitrary values (`[13px]`,
  hex in classes) as drift; class strings duplicated across files; dark variants complete.
- shadcn/ui and similar generated libraries: judge composition and wrapping, not the generated
  source; check the project's own rules about editing generated folders.

## Native / hybrid mobile (React Native, Expo, Flutter, Capacitor)
- Platform conventions per OS, safe areas, keyboard avoiding, list virtualization (FlatList /
  ListView builders), image caching, permissions flow, secure storage for tokens (Keychain /
  Keystore, not AsyncStorage), deep links, OTA update safety, app-store review constraints.

### Triko specifics (Expo SDK 57 + Supabase)
- Queue state is written only by `SECURITY DEFINER` command functions; any client `UPDATE`/
  `INSERT` path to `queue_*` tables, or any rule (position, threshold, eligibility) computed in
  `src/` instead of SQL, is a finding.
- Every command: `queue_state` row lock → validation → one `queue_events` row → `queue_version`
  +1 → notification diff, in one transaction. Check the pgTAP suite (`supabase/tests/`) covers it.
- Packages installed with `npx expo install`; no UI framework; `FlatList` + memoized rows;
  selective Zustand selectors; SQLite cache rendered before network; no polling.
- Only the publishable key and `EXPO_PUBLIC_*` vars in the app; `sb_secret_` only in Edge Function
  secrets.

## Desktop (Electron / Tauri)
- `contextIsolation` on, `nodeIntegration` off, IPC surface minimal and validated, CSP, auto-update
  signing; desktop conventions (menus, shortcuts, window state). Skip the PWA audit.

## APIs only / backend only
- Skip UI lenses; deepen security, API, database, performance, observability.
