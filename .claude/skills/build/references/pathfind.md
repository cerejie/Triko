# Pathfinding — when the map in SKILL.md does not resolve it

1. **Derive first.** Feature `x` → `src/features/x/`, screen → `app/(<role>)/<screen>.tsx`, SQL function `f` → `grep -n "function public.f\|function private.f" supabase/migrations/*.sql`.
2. **Narrow grep, never a tree walk.** `grep -rn "<symbol>" supabase/migrations src app --include=*.sql --include=*.ts --include=*.tsx`. Exclude `node_modules`, `android`, `ios`, `.expo`.
3. **Rules before code.** A behavior question is answered by `docs/queue-rules.md` (section numbers are stable), then `TRIKO_BUILD_REFERENCE.md` (`grep -n "^#" TRIKO_BUILD_REFERENCE.md` for its outline, then read the section range only).
4. **Confirm with one `ls`**, never a recursive `find`.
5. **Record** every resolved path in the checkpoint path map if `/checkpoint` is used, so it is never searched again.
