# Verification

Run the cheapest single check that covers the change. Stop when it passes.

| Change | Command |
|---|---|
| Docs, copy, `.claude/` | none |
| SQL migration, seed, pgTAP test | `npm run db:reset` then `npm run db:test` |
| TypeScript in `app/` or `src/` | `npm run typecheck` |
| Dependency, `app.json`, Expo config | `npm run doctor` |
| Edge Function | `npm run typecheck` (Deno types permitting) — otherwise state it is unverified |

## Do not

- Run `npm run lint` on top of a passing typecheck unless lint rules are the point of the change.
- Run `db push`, `db reset --linked`, or anything against a remote project.
- Claim a screen "works" from a typecheck — report UI as compiled, visuals unconfirmed.
- Retry the same failing command a third time; read the code instead.

## Docker

`db:*` needs Docker Desktop. If it is not running, say so and stop — do not try to start it or work around it.
