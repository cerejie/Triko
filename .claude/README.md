# .claude — Triko skill pack

Adapted from the TARTAR pack for Expo + Supabase. `/build` runs everything else itself.

| Skill | When it runs |
|---|---|
| **build** | Any implementation prompt (auto via CLAUDE.md) or `/build`. Locate → decide → plan → wait for approval → implement → verify → report, ending with a suggested commit message and a next-conversation prompt. |
| **commit** | Suggest mode after every change (message only); commit mode on `/commit` or when asked. Format: `Type: Title` + `-` bullets. |
| **decision-making** | Choosing between non-trivial alternatives, or when asked "X or Y?". |
| **deep-critique** | Read-only audits: "critique / audit / review / is this production-ready". |
| **checkpoint** | `/checkpoint` writes `.claude/state/ROADMAP.md`; a session opening with an unfinished one resumes from it. |

References under `skills/build/references/`: `conventions.md` (SQL, pgTAP, TS naming, error keys), `architecture.md` (layer ownership), `queue-command-recipe.md` (command order + test skeleton), `stack.md`, `verification.md`, `plan.md`, `pathfind.md`, `lean.md`.

Not ported (web-only or deferred): `shadcn`, `tartar-shadcn`, `autopilot`, the Playwright visual sweep.

`.claude/state/` is local working state — safe to add to `.gitignore`.
