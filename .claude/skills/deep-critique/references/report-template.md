# Severity, finding template, report structure

## Severity — never inflate

| Severity | Use when | Examples |
|---|---|---|
| **Critical** | Security compromise, catastrophic data loss, authorization failure across users, system-wide outage, a core workflow unusable | Unauthenticated read of all customers; service key in the bundle; checkout that can double-charge; employees can escalate to owner |
| **High** | A business workflow fails or misleads, significant security risk with a precondition, serious UX failure on a primary path, major performance problem, architectural risk that blocks change | Stock goes negative under concurrency; primary action hidden on phones; 4 MB initial bundle on a mobile-first app; a role-gated write whose database policy covers INSERT but not UPDATE |
| **Medium** | Real problem worth fixing, not an immediate threat | Missing empty state; inconsistent error format; missing index on a growing table; 36 px inputs on touch |
| **Low** | Minor, limited impact | Inconsistent icon size; a label that could be clearer |
| **Observation** | Not a defect; worth considering | A missing workflow the spec doesn't require; a pattern that will strain at 10× scale |

**Confidence:** High = verified in code or behavior; Medium = strong evidence, one link not
verified; Low = plausible, needs confirmation (usually a hypothesis — keep it ≤ Medium severity).

## Full finding (Medium and above)

```markdown
### [PREFIX-NN] Title that states the problem, not the topic
**Category:** … · **Severity:** … · **Confidence:** … · **Basis:** FACT | RISK | UX PRINCIPLE | JUDGMENT

**What I found** — the concrete issue, one short paragraph.
**Evidence** — exact references: `path/file.ext:line`, function, endpoint, table/policy, config key,
screenshot/viewport/role/theme, command output. Quote the decisive line when short.
**Why it matters** — the consequence.
**User impact** — what a real user experiences.
**Technical impact** — what it costs engineering (bugs, coupling, risk, maintenance).
**Recommended direction** — what should change conceptually; smallest proportionate move first.
**Verification** — how QA or a developer confirms the issue and later the fix.
```

## Compact finding (Low and Observation)

`[UI-07] Low · FACT — Icon sizes mix 16/18/20 px in the app bar (AppBar.tsx:22–40). Pick one size token.`

## Final report structure

Scale it to depth: `quick` uses Summary + top findings + Action plan; `standard` drops empty
sections; `deep` uses all of them. Omit a section rather than filling it with weak material.

```markdown
# Critique: <target> (<depth>)
**Scope & assumptions:** what was audited, what was assumed.
**Coverage:** lenses run · what was verified at runtime vs from code only · what was skipped and why
(e.g. "no device: real keyboard and safe areas unverified"; "host headers not in repo").

## Executive summary
3–6 sentences: overall state, the biggest risks, whether it is fit for its purpose, and the one
thing to do first.

## Critical findings
## High-priority findings
## UX/UI findings
### Desktop · ### Tablet · ### Mobile · ### Native feel
## Architecture findings
## QA findings
## Security findings
## Performance findings
## PWA findings
## Accessibility findings
## Database / API findings
## Technical debt
## Positive findings
Genuine strengths, with evidence — patterns worth keeping and copying. No filler praise.

## Recommended action plan
### Immediate — fix now (Critical, and High with low effort)
### Short term — next
### Medium term — after the critical work
### Long term — architectural and product improvements

## Hypotheses to verify
Suspicions without enough evidence, each with the check that would confirm or dismiss it.
```

A finding appears **once** — in its severity section if Critical/High, otherwise in its category
section. The action plan references IDs; it does not repeat findings.
