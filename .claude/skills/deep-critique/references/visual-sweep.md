# Visual sweep — look at the pixels, every surface

Mandatory for any scope with a UI. Code reading and numeric probes cannot see composition
defects: a control that wrapped onto its own row, a menu on the wrong side, a placeholder dash,
an unlabeled date. Those overflow nothing, throw nothing and pass every build and every
`scrollWidth` check. Only a human-style look at a rendered screenshot catches them.

## 1. Inventory first — from code, not from memory

Before rendering anything, list every surface the scope can reach. Derive it, do not recall it:

| Surface | Where to enumerate it |
|---|---|
| Pages | route trees (every entry, every role that can open it) |
| Modals / dialogs | modal-key registry + every `open…Modal` / `openConfirm` call site |
| Sheets / drawers | every sheet component + every place a row, card or button opens one (row detail sheets, branch picker, filter sheet, account panels) |
| Menus / popovers | row action menus (per row state: pending, approved, overdue, paid…), header menus, filter popovers, selects |
| States | loading, empty, error, refreshing, offline/pending, locked/read-only, overdue |
| Variants | every role × phone (390) / tablet portrait (820) / tablet landscape (1180) / desktop (1440) × light / dark |

Write the inventory as a table. It is the coverage contract: each row ends with a screenshot path
or "not reached — why". A surface not in the table was not reviewed; never imply otherwise.

Row-dependent surfaces need one record per state — a detail sheet for an unpaid, a partly paid, an
overdue and a paid record show different action sets, and the footer layout differs with them.

## 2. Render and capture

Triko (Expo, Android): run a development build on an emulator or device against the local
Supabase stack, then `adb exec-out screencap -p > <scratch>/<role>-<screen>-<state>.png` per
inventory row. States worth one row each: online, `⚠ OFFLINE` with cached data, empty queue,
NEXT IN LINE, reserved, suspended, operator confirm dialog, Undo toast.

Use the project's harness if it has one; else a headless browser against the dev server. Save one
screenshot per inventory row. Open each sheet, modal and menu — a list screenshot does not review
the sheet it opens.

## 3. Look — every screenshot, against this checklist

Open each image and read it the way a designer would. A numeric probe passing is not a look.

**Action groups**
- Primary action plus overflow (⋮) share one row: primary fills, overflow sits trailing (right in
  LTR), same height. An overflow or icon button alone on its own row is a defect.
- Button heights and radii match within a row; full-width buttons do not sit beside fixed ones of
  a different height.
- One primary per surface; destructive actions separated, never adjacent to the primary.
- Nothing orphaned by wrapping: a single chip, button or word dropped onto a new line.

**Content**
- No placeholder values shown as data: "—", "undefined", "null", "NaN", "Invalid Date", "₱NaN",
  empty brackets. A row with nothing to say is hidden, not dashed.
- Every value has a meaning the reader can name: a bare date next to a status chip ("Overdue")
  must say what date it is (due, created, paid).
- No duplicated fact on the same surface (same amount or date shown twice with no new meaning).
- Truncation is deliberate (ellipsis on names, wrap on amounts), never clipped mid-glyph.

**Layout**
- Alignment: labels share a column, values share an edge, numbers right-aligned.
- Spacing rhythm consistent between sibling blocks; no block flush against a panel edge.
- Sheet: drag handle, title, close, safe-area padding, footer pinned; content not hidden under it.
- Card-in-card, double borders, shadows stacking.
- Light and dark both: contrast, no element that vanishes in one theme.

## 4. Report

Each composition defect is a `UI` or `MOB` finding with the screenshot path as evidence, the
surface's inventory row, and the source location of the shared component that produced it — a
defect in a shared primitive (sheet footer, detail section) is one finding naming every surface
it affects, not one per screen.
