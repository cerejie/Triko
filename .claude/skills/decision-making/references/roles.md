# Role simulation

Each role is a separate lens with its own mandate. Run a role by asking its questions *as that role*, against the option currently in the lead. Each role ends with a one-line verdict: **support**, **support with a condition**, or **oppose, because…**.

A role that agrees without adding a new consideration has not run.

---

## 1. The User (highest weight)

**Mandate:** Make the decision from inside the user's actual life, not an idealized one.

**Ask, in the first person:**
- What do I actually want, as opposed to what I said I want?
- What am I really optimizing: money, time, growth, safety, freedom, status, or peace of mind?
- What can I realistically afford in money, time, energy and attention right now?
- What constraints am I under that an outsider would miss?
- Which outcome would I personally regret the most?
- Does this option fit the life I actually live, or the life I wish I lived?

**Output:** The option the user would choose, and the one or two facts about them that drive that choice.

**Failure mode:** Projecting Claude's own values onto the user, or inventing circumstances. Use only facts the user stated or that are recorded, and label everything else as an assumption.

---

## 2. Strategic Advisor

**Mandate:** Look beyond the immediate decision.

**Ask:**
- What happens after this choice? What does it make easier and harder next?
- What are the second-order effects, the third-order effects, and the effects on other people?
- Does this option keep future choices open or close them off?
- Does it scale if things go well, and does it stay contained if they go badly?
- How does it position the user one to three years from now?

**Output:** The option that leaves the user in the strongest position later.

**Failure mode:** Giving up a sure near-term need for a speculative long-term edge. Strategy that the user cannot survive long enough to benefit from is not strategy.

---

## 3. Financial Analyst

**Mandate:** Measure what the decision really costs and returns.

**Ask:**
- What is the direct cost, and what are the hidden costs: time, maintenance, switching, learning, taxes and fees?
- Are any costs recurring, and is there lock-in?
- What is the expected return, and over what period?
- What else could this money or time buy?
- What does it do to cash flow month by month?
- What is the worst-case exposure, and could the user survive it?

**Output:** The financially soundest option, and the worst-case figure.

**Failure mode:** Defaulting to the cheapest option. Cheap and low-value loses to expensive and high-value. Watch for the opposite mistake too: never justify a cost with a return that is only hoped for.

---

## 4. Risk Manager

**Mandate:** Find out how this decision fails.

**Ask:**
- What are the main ways it could fail, and how likely is each one, roughly?
- How bad is the outcome if it fails, and can it be recovered from?
- Is the decision reversible? What would undoing it cost?
- What external dependencies does it rely on: people, markets, vendors, approvals?
- Does it concentrate risk, with everything resting on one bet, one client or one person?
- **Premortem:** It is a year from now and this decision failed. What is the most likely story of how that happened?

**Output:** The biggest risk, and the safeguard that reduces it most.

**Failure mode:** Treating every risk as disqualifying. Every option carries risk, so compare risk across options, not against zero.

---

## 5. Skeptic / Devil's Advocate

**Mandate:** Try to prove the current recommendation wrong.

**Ask:**
- Which assumption, if false, collapses this recommendation?
- What am I not seeing, or what have I not been told?
- Make the strongest honest case for the opposite choice. Is it actually better?
- Am I rationalizing what the user, or I, already wanted?
- Would a smart person who disagrees find this reasoning convincing?

**Output:** The strongest counter-argument, and a judgement on whether it changes the decision materially.

**Failure mode:** A token objection that is easy to dismiss. If the counter-argument is easy to dismiss, it is not the strongest one, so look again.

---

## 6. Future Self

**Mandate:** Judge the decision from three points in the future.

**Ask:**
- **In 1 month:** How do I feel about it? Is the near-term pain or pleasure still dominant?
- **In 1 year:** Which choice am I glad I made? What has compounded?
- **In 5 years:** Which choice would I regret not making? What did it make me become?
- Am I trading something that compounds, such as skills, health, relationships or capital, for something that doesn't?

**Output:** The option that minimizes long-run regret, and any case where the short-term and long-term answers differ.

**Failure mode:** Romanticizing the long term so much that real constraints today get ignored. The user's future self also remembers bills that went unpaid.

---

## 7. Practical Operator (gatekeeper)

**Mandate:** Ignore theoretical perfection and ask whether the user can actually execute this.

**Ask:**
- Can this user, with their current time, skills and resources, actually carry this out?
- What are the concrete steps, and which one is the hardest?
- How much time does it take, and does that fit the time the user really has?
- What is most likely to stall it halfway?
- What is the simplest version that still gets most of the value?

**Output:** Whether the option can be carried out, and the simplest workable version of it.

**Failure mode:** Making it too easy to reject an option. "Hard" is not the same as "can't be done". Name what would make the option doable before ruling it out.

---

## 8. Emotional / Human Perspective

**Mandate:** Account for the person, not just the spreadsheet.

**Ask:**
- What does each option do to stress, motivation and confidence?
- How does it affect the user's relationships and the people who depend on them?
- Is there an emotional attachment or aversion at play, and is it informative or distorting?
- Which option lets the user sleep at night?
- Will the user actually stick with this option, or abandon it because it feels bad?

**Output:** The human cost or benefit of each option, and whether emotion is acting here as a signal or as noise.

**Failure mode:** Either ignoring emotion, which produces plans nobody follows, or letting it override everything. A plan the user hates will fail, and a plan built only to feel good can also fail.

---

## Combining the verdicts

1. **Gate.** Drop any option the Practical Operator judges impossible for this user, unless a simpler variant makes it possible.
2. **Weight.** The User's role carries the most weight. Strategic, Financial, Risk and Future Self are each weighted by how relevant they are to this decision, using the calibration signals in SKILL.md. Emotional/Human counts as an input of normal weight.
3. **Resolve conflicts.** When roles disagree, the conflict is usually the real trade-off. Name it, for example: "This is upside (Strategic) versus survival (Financial)." Settle it by the user's stated priority. If the user's priorities don't settle it, ask.
4. **Let the Skeptic force a revision.** If the Skeptic's argument changes the decision materially, revise the pick and run the roles again. The Skeptic does not pick the winner itself.
5. **Check for consensus that came too easily.** If all the roles agree immediately, rerun the Skeptic and the Risk Manager harder before trusting the result.
