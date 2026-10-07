---
name: build
description: "The single entry point for implementation work in Triko — queue engine SQL, migrations, pgTAP tests, Edge Functions, Expo screens, features, fixes, refactors. Load this automatically whenever a prompt asks for implementation work in this codebase, whether or not the user types /build. It runs the whole pipeline itself (locate, decide, plan, implement, verify, report) and loads whatever references it needs without the user naming them."
---

# /build

You are running the pipeline. Follow it in order. Do not narrate the steps back to the user.

## Always-on rules

1. **The mobile client is never the authority for queue state.** Position, waiting position, priority, eligibility, thresholds, transfer legality — all in SQL. Never in `src/` or `app/`.
2. **Never invent a queue rule.** [docs/queue-rules.md](../../../docs/queue-rules.md) overrides [TRIKO_BUILD_REFERENCE.md](../../../TRIKO_BUILD_REFERENCE.md). Undefined → safest existing rule + an **[ASSUMPTION]**/**[OPEN]** line in `docs/queue-rules.md`, and say so.
3. **Plan before any file change** (global rule): numbered plan of exact files and what changes, then wait for explicit approval. A trivial one-line fix may proceed after stating the line. If the approved plan proves wrong, stop and re-plan.
4. **Business rules are tested in pgTAP** (`supabase/tests/*.test.sql`) before any screen uses them. This is required, not optional.
5. **Reuse before creating.** Grep for an existing helper (`private.*`, `src/lib/*`, `Triko*` component) first.
6. **No `any`.** `unknown` + narrowing. `import type` for type-only imports.
7. **Minimal diff.** No drive-by refactors, no reformatting untouched lines.
8. **Install mobile packages with `npx expo install`**, and justify every new package. Never hand-edit `android/`/`ios/`.
9. **Never commit, push, branch, or run `db push` against a remote** unless asked. `npm run db:reset` on the local stack is fine.
10. **Read ranges, not files.** Never re-read a file you just edited.
11. **Do not spawn sub-agents** unless the user asks.
12. **Never run graphify** unless the user types `/graphify`.
13. **Reply in under ten lines** plus the plan/commit block; cite `path:line`, no code dumps.

Detail on token discipline: `references/lean.md`.

## Step 1 — Locate

| Need | Path |
|---|---|
| Schema, enums, tables | `supabase/migrations/0001_core.sql` |
| RLS policies, `private.*` auth helpers | `supabase/migrations/0002_rls.sql` |
| Queue ordering, positions, mutation helpers | `supabase/migrations/0003_*.sql` |
| Entry commands (join, activate, reserve, transfer…) | `supabase/migrations/0004_*.sql` |
| Route commands, undo, read RPCs | `supabase/migrations/0005_*.sql` |
| New schema / function change | new `supabase/migrations/NNNN_<name>.sql` (`npm run db:new -- <name>`) — never edit an applied migration |
| Business-rule tests | `supabase/tests/NNN_<topic>.test.sql` |
| Local seed (fixed UUIDs) | `supabase/seed/seed.sql` |
| Edge Functions (login, driver-admin, notifications, qr) | `supabase/functions/<name>/index.ts` |
| Routes / screens | `app/(auth)/`, `app/(driver)/`, `app/(operator)/` |
| Feature logic (hooks, stores, RPC calls) | `src/features/<feature>/` |
| UI primitives | `src/design-system/Triko<Name>.tsx` |
| Supabase / SQLite / notifications / connectivity clients | `src/lib/<client>.ts` |
| Copy (Cebuano first, English fallback) | `src/i18n/` |
| Product rules | `docs/queue-rules.md` |

Unresolved → `references/pathfind.md`. Budget: ≤6 reads for a feature, ≤3 for a fix.

## Step 2 — Classify

- **Small** — one-line or ≤3 files, one layer, no migration, no dependency, no route change → still state the change (rule 3), then step 5.
- **Large** — anything else → step 3.

## Step 3 — Decide

To the user via `AskUserQuestion` (≤3 questions, ≤4 options, recommended first): queue rules and state transitions · permissions/RLS · notification behavior · destructive database work · new dependency · breaking a public RPC shape · two designs with genuine trade-offs. Everything else: decide, state in one line. For a non-trivial pick between alternatives, run the `decision-making` skill silently and state the verdict.

## Step 4 — Plan

Read `references/plan.md`. Numbered plan, exact paths, build order, biggest risk. **Stop and wait for approval.**

## Step 5 — Implement

Read `references/conventions.md` unless the change is confined to a file already read this session. Also, only when it applies (max two references per task):

- `references/queue-command-recipe.md` — any queue command, RPC, or pgTAP test.
- `references/architecture.md` — unsure which layer owns the logic.
- `references/stack.md` — Expo, expo-sqlite, Zustand, supabase-js, Supabase CLI.

## Step 6 — Verify

One command, the cheapest that covers the change (`references/verification.md`):

- Docs / copy only → nothing.
- SQL migration or test → `npm run db:reset` then `npm run db:test`.
- TypeScript → `npm run typecheck`.
- Dependency / `app.json` / Expo config → `npm run doctor`.

Two failures of the same command → stop and read the code.

## Step 7 — Report

Under ten lines: what changed (clickable paths), assumptions made, what is left. End with a suggested commit message — `../commit/SKILL.md`, suggest mode.

## Step 8 — Commit

Only if the user asked. Follow `../commit/SKILL.md`, commit mode.

## If the session runs long

Say in one line that `/checkpoint` would preserve the state. Do not checkpoint on your own.
