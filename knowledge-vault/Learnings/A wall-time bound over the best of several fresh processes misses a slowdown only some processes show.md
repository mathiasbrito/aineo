# A wall-time bound over the best of several fresh processes misses a slowdown only some processes show

**Tags:** #testing #timing #flaky #measured
**Discovered:** [[Sessions/2026-10-04 — T29 Timing cases]] (the re-measure of PR #97, findings 1 and 4, and its correction) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

A timing case that passes when the fastest of N fresh processes is within the bound tolerates host noise, but it also passes a step that is slow in some processes and fast in others: one fast process is enough. Judge by a middle attempt instead, such as the second-fastest of three. And give each attempt a home of its own, or a step that is slow only on a home's first use is fast in every attempt after the first.

## Example

- **Why T29 took several attempts.** The Report's two timing cases timed their step once, against a 2 s bound, and failed on a busy host with the drawing unchanged (T29's note, *Context*). T29's fix round judged each step by the fastest of up to three fresh child Neovims.
- **What the fastest of three let through** (PR #97's re-measure on 0.12.5, its rows quoted in [[Attachments/learnings-probes-2026-10-05.txt]]):
  - INT, a drawing about twice over the bound in a child that drew a slow coin, about half of them, passed 8 of 8 runs. One attempt alone killed it 3 of 4;
  - WARM, a drawing slow only on the first rendering in a home, passed: every attempt's child inherited the test file's `XDG_*` home, so only the first attempt was slow. One attempt alone killed it in the narrowed case, but not in the whole file, where earlier cases had warmed the home.
- **The fix, measured.** The re-measure's second-fastest of three killed INT in 3 of 8 runs, exactly those with two or three slow children, which at INT's share of about half is the single attempt's rate; the correct drawing passed 5 of 5. A home per attempt killed WARM in the narrowed case and in the whole file.
- **Adopted** by T29's correction (`tests/helpers/timed_attempts.lua`, `7d762c5` on `dev`): INT killed 5 of 8, exactly its runs with two slow children; WARM killed 2 of 2; the correct drawing passed 10 of 10, narrowed and in each whole file (T29's note, *The correction*).
- **Is per-process variation real?** On Neovim 0.12.5 it can be: the order `pairs()` visits a table's string keys in differs between processes ([[Learnings/The pairs order of a table's string keys differs between Neovim 0.12.5 processes, and can differ within one when the keys are re-created]]). No step of aineo's Report has a cost that depends on that order; INT drew its variation from a coin.

**Why.** The minimum of N draws hides any cost that varies between draws: it passes once a single draw is fast. A step over the bound in a fraction p of processes passes the fastest of three unless all three are slow, with probability 1 − p³. For p = ½ that is 7 in 8, near INT's 8 of 8. The second-fastest fails when two of three are slow, with probability 3p² − 2p³. That equals the single attempt's rate, p, only at p = ½. Below it the middle attempt catches less than one attempt does, above it more:

| p, the share of slow processes | single attempt | fastest of 3 | second-fastest of 3 |
|---|---|---|---|
| 0.1 | 0.100 | 0.001 | 0.028 |
| 0.2 | 0.200 | 0.008 | 0.104 |
| 0.3 | 0.300 | 0.027 | 0.216 |
| 0.5 | 0.500 | 0.125 | 0.500 |
| 0.7 | 0.700 | 0.343 | 0.784 |

The same functions, with q the chance that host noise pushes a correct attempt over the bound, give the false-fail rate. The second-fastest tolerates noise in one attempt of three, not two: at q = 0.3 it fails a correct step 21.6% of the time, the fastest of three 2.7%. (The table and the noise figures are the records review of PR #101, finding 4.) A home shared between attempts makes them not independent: the first leaves state that the others find.

## Why it matters

- **Any timing case that retries to beat noise** — a performance pin, a benchmark gate in CI — trades away the slowdowns that vary from process to process. A middle attempt catches a slowdown seen in half the processes as often as one attempt does. It catches one seen in fewer processes less often (3p² − 2p³: 2.8% for p = 0.1, against 10%), and one seen in more processes more often. It tolerates noise in one attempt of three, not two.
- **Retries are only independent if their state is.** A home, a cache directory or a temporary file shared between attempts lets the first attempt warm the rest.
- **The reading changes.** "Within 2 s" becomes "the second-fastest of three fresh processes within 2 s". The user accepted that reading for RP4 on 2026-10-05 (MR212 in [[Review/2026-09-24 — v1 MVP readings review]]).
- **Limits:**
  - measured on 0.12.5 only, on one host (Apple M1 Max), one Neovim at a time;
  - INT and WARM are built mutants, not slowdowns seen in aineo;
  - not measured inside five whole suites run at once, the one condition in which the old single attempt failed every run (the user skipped that run on 2026-10-05);
  - a crash of the child is a failure, not a slow attempt; the helper does not retry it.
