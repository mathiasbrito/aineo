# pairs visits the same string keys in a different order in each Neovim 0.12.5 process

**Tags:** #neovim #luajit #testing #timing #measured
**Discovered:** [[Sessions/2026-10-04 — T29 Timing cases]] (the re-measure of PR #97, finding 1) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

On Neovim 0.12.5, `pairs()` visits the same string keys of a table built the same way in a different order from one Neovim process to the next. So code whose cost depends on that order can take a different time on the same input in each fresh process. One input can draw fast in one Neovim and slow in the next.

## Example

- **The probe.** `rm-pairs-order.lua` fills a table with twelve string keys in a fixed order and prints the order `pairs()` visits them in. Each run was a fresh `nvim --clean --headless -i NONE -l` started from a mini.test case under `make test_file` ([[Attachments/learnings-probes-2026-10-05.txt]]):
  - PR #97's re-measure, 2026-10-05, four Neovims: three orders;
  - wave 6's closing knowledge pass, the same day, eight Neovims: six orders.
- **Within one process the order is stable.** The same table built five times in one Neovim gave one order five times, and the next Neovim gave another, again five times (this pass, in the same file). Every order seen is a rotation of the same cycle of keys, so what moves from process to process is where the walk starts.
- **What it did to a test.** T29's re-measure built INT, a Report drawing whose cost is chosen per process by a coin, to stand for such a drawing. Two times over the 2 s bound in about half of its processes, it passed a bound judged on the fastest of three fresh processes 8 of 8 times, where a single attempt killed it 3 of 4 (the re-measure's rows, quoted in [[Attachments/learnings-probes-2026-10-05.txt]]; the T29 note, *Decisions & reasoning*). The re-measure gave this order as the reason such a drawing is not hypothetical. See [[Learnings/A wall-time bound over the best of several fresh processes misses a slowdown only some processes show]].

**Why.** The same LuaJIT run alone shows the same variation: `luajit` 2.1.1788856981, the version Neovim 0.12.5 links here, printed four orders in five runs of the same script ([[Attachments/learnings-probes-2026-10-05.txt]]). So the order comes from LuaJIT, not from Neovim. That LuaJIT seeds its string hashing anew in each process is the likely mechanism. It was not read from LuaJIT's source, which is not on the host.

## Why it matters

- **A timing measured in one process is one draw.** Code that walks a table with `pairs()` can cost more or less in the next Neovim on the same input. A timing case that starts fresh processes sees that spread; one that reuses a process does not.
- **A test that compares a `pairs()` order across processes is flaky.** Within one process the order is stable. Sort the keys when the order matters.
- **Limits:**
  - measured on 0.12.5 only, on macOS arm64; 0.11.6 was not run (D29);
  - twelve short string keys; integer keys in a table's array part are not covered;
  - the probe ran under `--clean`, so no plugin or config shaped the process.
