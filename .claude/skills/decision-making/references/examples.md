# Worked examples

Each example shows brief internal notes, which stay in thinking and are never printed, and then the reply. The facts about the user come from the prompt; anything beyond them is labelled as an assumption.

---

## 1. Simple: a purchase

**User:** "Keyboard: the ₱2,200 one or the ₱4,500 one? I type about 8 hours a day for work."

**Internal (compressed):** This is easy to reverse, cheap relative to a working income, and short-horizon, so it is Simple. The User role: this is the tool they touch most. The Operator: no execution issue. The Skeptic: is the more expensive board actually better to type on, or only priced higher? The decision turns on that, and on whether money is tight this month (unknown). The do-nothing option is weak if their current keyboard is fine but uncomfortable; also unknown.

**Reply:**
> Get the ₱4,500 one, provided it's noticeably nicer to type on (try it in a store or read typing-feel reviews, not spec sheets). At 8 hours a day, the extra ₱2,300 works out to about ₱9 per working day over a year, for the tool you use most. What would change my answer: if cash is tight this month, the ₱2,200 board is perfectly adequate, and you can upgrade later because keyboards resell well.

---

## 2. Moderate: a technology decision

**User:** "Our data layer is a hand-rolled query and mutation store with an offline write queue. Should we migrate to TanStack Query now, before we add three new modules, or after?"

**Internal:**
- *Real decision:* not "now or after" but "should the next three modules be built on the old layer or the new one?". Each module built on the old layer is one more to migrate later.
- *Options:* (A) migrate everything now, (B) migrate after the three modules, (C) do nothing for now, (D) adopt TanStack incrementally, starting the new modules on it while old modules move when touched.
- *Criteria:* migration cost, delivery speed for the modules, keeping the offline queue working, consistency of the codebase.
- *Roles:*
  - Risk: the offline write queue is the dangerous part. If it breaks, offline mode breaks.
  - Operator: a big-bang migration stalls feature work.
  - Strategic: building three modules on the old layer increases future debt.
  - Skeptic: two patterns coexisting confuses contributors.
- *Reversibility:* partial; the incremental path keeps it cheap to undo.
- *Information value:* high, because whether the offline queue can survive the switch is unknown and could flip the decision. A one-day spike settles it cheaply.

**Reply:**
> ## Decision
> **Recommended action:** Run a one-day spike that moves one existing module to TanStack Query, *including an offline mutation*. If the spike works, build the three new modules on TanStack and migrate old modules only when you touch them.
>
> ## Why
> - Building three more modules on the old layer means three more to migrate later. Waiting increases the cost of the migration.
> - A big-bang migration now stalls feature delivery. The incremental path doesn't.
> - The one real unknown is whether the offline write queue survives the switch. The spike answers that before you commit.
>
> ## The strongest argument against it
> Two data patterns will coexist for a while, which is real friction for anyone reading the code. That is worth accepting, because the alternatives are a stalled roadmap (migrating everything now) or more debt (migrating after).
>
> ## What could change my decision
> - The spike shows the offline queue can't be preserved cleanly → build the three modules on the existing layer, and plan the migration as its own project.
> - The three modules are needed within days, not weeks → ship them on the old layer. Delivery wins.
>
> ## Practical next step
> Pick the smallest module that has an offline mutation, and time-box the spike to one day.

---

## 3. High-stakes: a career move with a missing variable

**User:** "I got an offer abroad at 2.5× my salary. My side business is just starting to make money, around ₱40k a month. Take it?"

**Internal:**
- *Tier:* hard to reverse (relocation, and possibly the business), years-long consequences, affects family (unknown), so High-stakes.
- *Real decision:* "Do I trade a guaranteed income jump for the risk of stalling a business that is gaining momentum, and can I keep both?"
- *Unknowns that flip the answer:*
  - Can the business run without the user there in person?
  - Is its revenue growing or flat?
  - Do they have dependents or a partner? Not stated, so ask rather than assume.
- *Roles:*
  - Financial: 2.5× income is concrete. ₱40k a month from the business is real but early.
  - Future Self (5 years): regret is possible either way.
  - Risk: a business left untended at an early stage often stalls. A job offer may not come again.
  - Operator: running a business remotely requires a person on the ground.
- *Decision:* conditional, because information value is high and the facts can be gathered within the offer window.

**Reply:**
> ## Decision
> **Recommended action:** Don't decide yet. Spend this week answering one question: *can the business run for 12 months with someone else handling the day-to-day?* If it can, take the offer. If it can't, the answer depends on whether the business's revenue is still growing.
>
> ## Why
> Based on what you've told me, this isn't really job versus business. The real question is whether you can keep both. The 2.5× salary is certain income. The ₱40k a month is real but early, and early businesses often stall when the founder leaves. If someone can run it day to day, you get the income *and* keep the business, which beats either option alone.
>
> ## The strongest argument against it
> Momentum is fragile, and the moment a business starts to work is often the moment it most needs its founder. If revenue is growing month over month, leaving now could cost you more than the salary gap is worth over five years.
>
> ## What could change my decision
> - Someone you trust can run operations for 12 months → **take the offer**.
> - No one can, and revenue is growing more than 10% a month → **decline**, or negotiate a later start date.
> - No one can, and revenue is flat → **take the offer**. The salary gives you capital to restart properly later.
>
> ## Confidence
> Low until the question about running the business is answered, then moderate.
>
> ## Key assumptions
> - The offer window allows a week to decide (assumed).
> - The ₱40k a month is profit, not revenue (assumed; please confirm).
> - No family constraint makes relocating hard (unknown; this could override everything above).
>
> ## Practical next step
> Ask the employer what the latest start date is. Then write down every task the business needs from you each week, and mark which ones only you can do.

---

## 4. Doing nothing wins

**User:** "My phone is 3 years old and works fine, but the new model has a much better camera. Upgrade?"

**Internal:** This is partly reversible (resale loses value) and the cost is noticeable, so Moderate-light. Do-nothing: the phone works, and the main benefit of upgrading is the camera. The Skeptic asks whether they actually photograph enough for that to matter (unknown). FOMO signal: "the new model". Framing inversion: if they had asked "should I keep my working phone?", I would say yes.

**Reply:**
> Keep your current phone. It works fine, so the only real gain is the camera, and that's worth paying for only if you photograph often enough to notice the difference. Waiting costs you nothing and keeps the money free. Phones also get cheaper after launch, and your battery will tell you when it's really time. What would change this: if photos matter to your work or a side business, upgrade, because then it's a tool rather than a want.

---

## 5. The user has already decided

**User:** "I'm quitting next month to go full-time on my startup. I have 3 months of savings. Tell me this makes sense."

**Internal:** This asks for validation, so stress-test it instead. Three months of runway is short. The Risk Manager: most early ventures take longer than planned to reach income (optimism bias). The Skeptic: the plan is not wrong in itself, but the runway is the weak point. Respect that the decision is theirs, and add the safeguards that make it survivable rather than overriding it.

**Reply:**
> The direction can make sense. The runway is what worries me. Three months is short, because most ventures take longer than planned to reach income. If you hit month three without enough revenue, you'll be making the next decision under pressure.
>
> I'd keep the plan and change two things:
> 1. **Extend the runway before you quit.** Aim for 6+ months, either by saving another month or two or by lining up part-time or freelance income for the first quarter.
> 2. **Set your stop rule now.** For example: "if revenue is under ₱X by month 4, I take contract work while continuing the startup part-time." Deciding this while you're calm beats deciding it while you're desperate.
>
> What would change my view: if you already have paying customers or a committed client, three months may be enough. Is that the case?
