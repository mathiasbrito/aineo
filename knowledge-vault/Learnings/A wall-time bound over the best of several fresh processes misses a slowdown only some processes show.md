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
- **The fix, measured.** The re-measure's second-fastest of three killed INT in 3 of 8 runs, exactly those with two or three slow children, the single attempt's rate; the correct drawing passed 5 of 5. A home per attempt killed WARM in the narrowed case and in the whole file.
- **Adopted** by T29's correction (`tests/helpers/timed_attempts.lua`, `7d762c5` on `dev`): INT killed 5 of 8, exactly its runs with two slow children; WARM killed 2 of 2; the correct drawing passed 10 of 10, narrowed and in each whole file (T29's note, *The correction*).
- **Is per-process variation real?** On Neovim 0.12.5 it is: `pairs()` visits the same string keys in a different order in each process ([[Learnings/pairs visits the same string keys in a different order in each Neovim 0.12.5 process]]).

**Why.** The minimum of N draws hides any cost that varies between draws: it passes once a single draw is fast. A step over the bound in a fraction p of processes passes the fastest of three unless all three are slow, with probability 1 − p³. For p = ½ that is 7 in 8, near INT's 8 of 8. The second-fastest fails when two of three are slow, with probability 3p² − 2p³: ½ for p = ½, the single attempt's own rate. Host noise that slows one attempt still passes under the second-fastest, as long as it does not hit two attempts. A home shared between attempts makes them not independent: the first leaves state that the others find.

## Why it matters

- **Any timing case that retries to beat noise** — a performance pin, a benchmark gate in CI — trades away the slowdowns that vary from process to process. A middle attempt keeps the noise tolerance and keeps those slowdowns at the single attempt's rate, for one more attempt.
- **Retries are only independent if their state is.** A home, a cache directory or a temporary file shared between attempts lets the first attempt warm the rest.
- **The reading changes.** "Within 2 s" becomes "the second-fastest of three fresh processes within 2 s". The user accepted that reading for RP4 on 2026-10-05 (MR212 in [[Review/2026-09-24 — v1 MVP readings review]]).
- **Limits:**
  - measured on 0.12.5 only, on one host (Apple M1 Max), one Neovim at a time;
  - INT and WARM are built mutants, not slowdowns seen in aineo;
  - not measured inside five whole suites run at once, the one condition in which the old single attempt failed every run (the user skipped that run on 2026-10-05);
  - a crash of the child is a failure, not a slow attempt; the helper does not retry it.
