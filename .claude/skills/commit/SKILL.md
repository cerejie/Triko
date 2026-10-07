---
name: commit
description: "Write a commit message in this repo's house style — title `Type: Short Title Case Summary`, body one-line `-` bullets of important changes only. Two modes: suggest (after every response that changed files, end with a suggested message — no git commands run) and commit (only when the user types /commit or asks to commit). Never commit on your own initiative."
---

# /commit — house-style commit messages

## Two modes

- **Suggest** — after every response that changed files, end with a suggested message in a fenced `txt` block. Never run `git add`/`git commit` for it. Cover every uncommitted change, not only this turn's. If verification is failing, say it is not commit-ready instead.
- **Commit** — only when the user types `/commit` or asks.

## Format

```
<Type>: <Short Title Case Summary>

- <important change, one line>
- <important change, one line>
```

**Type** — one of `Feature`, `Fix`, `BugFix`, `Migration`, `Update`.

**Title** — Title Case, ≤60 characters, no trailing period.

**Body** — `-` bullets only, one line each, important changes only. No prose paragraphs, no file-by-file restatement of the diff.

## Example

```
Migration: Queue Engine Commands And Undo

- Add queue_effective_order with lane, waiting and reservation positions
- Add entry commands enforcing the queue-rules action matrix
- Add 30-second latest-event undo restoring old_state
- Add pgTAP coverage for every command and threshold notification
```

## Rules

- Never commit, push, create a PR, or switch/create a branch unless asked.
- On the default branch (`main`), say so and ask before committing.
- Stage deliberately — the files the task touched, never `git add -A` over a dirty tree.
- Run `git status --short` and `git diff --stat` before writing the message. Nothing else.
- Do not describe changes you did not make; do not omit changes you did.
- Keep the harness `Co-Authored-By` trailer as a trailer after a blank line; it is not part of the body. Pass multi-line messages via a heredoc / `-F` file.
