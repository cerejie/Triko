# Planning — design before code

Produces a plan, not code. Readable in ten seconds, specific enough to implement without further exploration.

## Steps

1. **Locate** touch points with the map in `../SKILL.md` (or `pathfind.md`). Do not read what you will not modify.
2. **Place** each piece of logic using `architecture.md`.
3. **Surface decisions** (`../SKILL.md` step 3) before planning — an unanswered decision invalidates the plan.
4. **Write the plan** — numbered, exact paths, `+` new / `~` modified, in build order.
5. **Stop.** Wait for explicit approval.

## Format

```
Goal: <one line>

1. + supabase/migrations/0006_<name>.sql     <what it adds>
2. + supabase/tests/013_<topic>.test.sql     <rules covered>
3. ~ docs/queue-rules.md                     <assumption recorded>

Verify: npm run db:reset && npm run db:test
Risk:   <the single biggest risk>
Open:   <question still needing the user>
```

No prose paragraphs, no restating the request, no options you are not recommending.

## Trade-offs

Two genuinely viable approaches → one sentence each plus a recommendation. Never a menu without a pick.
