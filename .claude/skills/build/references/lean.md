# Lean — minimum tokens, same correctness

Cost comes from three places, in this order: **files read that never mattered**, **commands run that proved nothing**, and **words written that nobody needed**. Attack them in that order.

## Reading

- Locate before reading. the path map in `pathfind.md` turns a question into a path; a directory listing turns it into a bill.
- Read a range (`sed -n '40,90p'`), not a file. Read the whole file only when rewriting it or when it is under ~80 lines.
- Never read a file twice in one session. If you need it again, you needed to remember it.
- Never re-read a file after editing it — a failed edit raises an error, so silence is confirmation.
- Never open a file "for context". Open it to answer a specific question you can state.
- Never touch `node_modules/`, `dist/`, `.history/`, `graphify-out/cache/`, lockfiles, or `*.tsbuildinfo`.
- Prefer symbol tools over file reads when they are available: a symbol body is a fraction of its file.

## Searching

- Scope every grep to a directory with an `--include`. Root-level greps are the single most expensive mistake available.
- `-l` to find the file, then `-n` to find the line. Two narrow searches beat one wide one.
- Search for declarations, not for words that also appear in prose.

## Running commands

- Batch independent commands into one call.
- One verification command per task, chosen by the ladder in `verification.md`. If it passes, stop.
- No dev servers, no `--watch`, no previews. They block, and their output carries no verdict.
- No exploratory scripts to confirm what reading the code would confirm.
- Two failures of the same command means stop guessing and read the code.

## Sub-agents

Do not spawn one unless the user asks. A sub-agent starts cold and re-derives context that already exists here — the most expensive way to answer a question you could answer directly.

## Replying

- Answer first. No preamble, no restating the request, no announcing what you are about to do.
- Under ten lines unless more was asked for. Prose, not nested bullet trees.
- Never paste back code you just wrote — the user has the diff. Cite `path.ts:42` instead.
- Never list options you are not recommending.
- No progress narration for work that already finished.
- Say what changed, what was assumed, what is unfinished. Stop.

## Session hygiene

- Cache resolved paths and decisions in working memory; do not re-derive them.
- Clearing context is a last resort, not a routine — and never without `/checkpoint` first.
- Do not run graphify, re-index, or regenerate any derived artefact on your own initiative. Only when the user asks.

## What lean is not

Lean is not skipping the task, delivering half the scope, or guessing to avoid a read. Correctness first — always. The savings come from not reading what was never relevant, not from being less careful about what is.
