# Anti-bias checks

Run these checks against two things: the user's framing of the decision, and Claude's own reasoning about it. The goal is not to remove emotion. It is to notice when a bias is quietly deciding the outcome.

## Two checks that always run

1. **Framing inversion.** Would I recommend the same thing if the user had argued for the opposite option, using the same facts? If not, I am anchored on their framing. Re-derive the recommendation from the facts alone.
2. **Sunk cost.** Remove every reason that amounts to "because it's already been spent, built or started". If the recommendation changes, the sunk cost was what decided it.

## Bias table

| Bias | How it shows up | Check | Correction |
|---|---|---|---|
| **Confirmation bias** | Every point that supports the option is noted, while the points against it are waved away | Did I search for disconfirming evidence as hard as I searched for supporting evidence? | Ask the Skeptic to make the strongest case for the opposite option |
| **Anchoring** | The first number, option or framing mentioned sets the range of the analysis | Would my answer change if a different option or price had been mentioned first? | Re-derive the answer from first principles, and compare against outside reference points |
| **Sunk cost** | "We've already invested so much" | Would I choose this if I were starting fresh today? | Decide only on future costs and benefits |
| **Status-quo bias** | Staying put wins by default, with its costs never counted | Have I priced the cost of doing nothing as carefully as the cost of changing? | List what inaction costs explicitly, including problems that compound |
| **Loss aversion** | A possible loss is weighted far above an equal gain | Would I accept this bet if the gain and the loss were the same size? | Compare expected values, then adjust only for whether the user can survive the loss |
| **Overconfidence** | Narrow estimates, no plan B, "this will definitely work" | What is the base rate for this kind of plan succeeding? | Widen the estimates, run a premortem and add a fallback |
| **Optimism bias** | Best-case timelines and revenue are treated as the base case | Is the base case the most likely case, or the hoped-for one? | Use base and worst cases for the decision, and treat the best case as upside |
| **FOMO** | Urgency created by other people's actions or by limited-time framing | Would this still be a good decision if the deadline were removed? | Separate real scarcity from manufactured urgency |
| **Emotional reasoning** | "It feels right" or "it feels wrong" stands in for analysis | Is the feeling telling me about a real risk or value, or is it noise? | Turn the feeling into a specific claim, then check that claim |
| **Availability bias** | A vivid recent story, such as a friend's failure or a viral success, dominates | Is this one memorable case, or the typical outcome? | Look for base rates or broader evidence |
| **Social pressure** | "Everyone is doing it" or "what will people think" | Would I choose this if nobody ever found out? | Weigh other people's opinions only where they have real consequences |
| **Identity-based decision** | "I'm the kind of person who…" decides the outcome | Is this choice serving my goals, or protecting a self-image? | Re-check the option against stated goals, not identity |
| **Agreeableness (Claude-specific)** | Claude drifts toward whatever the user seems to want | Did my recommendation move after I learned what the user preferred? | Run the framing-inversion check again |
| **Complexity bias (Claude-specific)** | The analysis is more elaborate than the decision deserves | Does the depth match the calibrated tier? | Cut the reply down to the tier's output format |

## Signals in the user's message

Phrases like these suggest a bias may be driving the request. Check for it gently; do not lecture.

- "I've already…", "after all the time I put in…" → sunk cost
- "Everyone says…", "all my friends…" → social pressure
- "Before it's too late", "only today", "it's selling out" → FOMO
- "I just know…", "my gut says…" → possibly emotional reasoning; the gut can carry real information, so test it
- "It'll definitely…", "there's no way it fails" → overconfidence or optimism bias
- "I don't want to lose…" → possibly loss aversion
- A long list of reasons for one option and nothing against it → confirmation bias, possibly a decision already made; see the "already decided" edge case in SKILL.md
