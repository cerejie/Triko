---
name: checkpoint
description: "Write or resume a roadmap file so a long task survives a context clear or a new chat with no re-exploration. Invoked explicitly when the user types /checkpoint or asks to save progress before clearing. Do not auto-invoke on ordinary prompts — the one exception is a session opening with an unfinished .claude/state/ROADMAP.md on disk, where you read it before doing anything else."
---

# /checkpoint — carry the work across a context boundary

Two modes. Pick by whether `.claude/state/ROADMAP.md` already exists.

---

## Mode A — Write a checkpoint

### When to run it

- The user asks (checkpoint, save progress, "I'm going to clear").
- Context is genuinely close to its limit — a compaction warning, or a session that has run many edits across many files and is slowing down.
- A large multi-session task reaches a natural milestone.

### When NOT to run it

Not after every task. Not after every file edit. Not "just in case" at the end of a normal exchange. A checkpoint on a short session costs tokens and buys nothing — that is exactly the waste this skill exists to prevent.

### What to write

`.claude/state/ROADMAP.md`, overwriting the previous one:

```markdown
# ROADMAP — <task name>
Updated: <YYYY-MM-DD>

## Goal
<one or two lines: what "done" means>

## Decisions locked
- <question> -> <answer the user gave>

## Path map
- <role>: <exact/path> (src/…, app/…, supabase/…)
(every file already located — so the next session never searches again)

## Done
- [x] <milestone, with the paths it touched>

## Next
1. <the immediate next action, specific enough to start cold>
2. <then this>

## Open
- <question still waiting on the user>

## State
Branch: <branch> · Uncommitted: <yes/no> · Last check: <command + result>
```

Write from what you already know. **Do not re-read files, re-run checks, or re-explore to fill this in** — a checkpoint that costs a full exploration has defeated itself.

Then tell the user in one line that it is safe to clear.

---

## Mode B — Resume from a checkpoint

1. Read `.claude/state/ROADMAP.md` — first, and by itself.
2. Trust its path map. Do not re-derive paths, do not re-explore the tree, do not re-ask a question listed under *Decisions locked*.
3. Confirm reality cheaply: `git status --short`. Nothing more.
4. Continue at `Next` item 1. State in one line where you are picking up.
5. Delete the file when the goal is met, so a stale roadmap never misleads a later session.

---

## Keeping context small in the first place

The best checkpoint is the one never needed. Prefer, in order: locate precisely (the path map in `../build/references/pathfind.md`) → read ranges not files → never re-read → keep replies short. Clearing is a last resort, not a routine.

`.claude/state/` is local working state. It is safe to add to `.gitignore` — mention that once, do not add it silently.
