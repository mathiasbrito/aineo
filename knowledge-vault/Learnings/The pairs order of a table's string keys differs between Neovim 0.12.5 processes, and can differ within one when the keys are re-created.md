# The pairs order of a table's string keys differs between Neovim 0.12.5 processes, and can differ within one when the keys are re-created

**Tags:** #neovim #luajit #testing #timing #measured
**Discovered:** [[Sessions/2026-10-04 — T29 Timing cases]] (the re-measure of PR #97, finding 1) · [[Sessions/2026-09-26 — Wave 6 retrospective]] (the closing pass, and the records review of PR #101, finding 1)
**Applies to:** [[Projects/aineo]]

## The insight

On Neovim 0.12.5, `pairs()` can visit the same string keys of a table built the same way in a different order from one Neovim process to the next. Within one process the order can change too, when the key strings are made again after the old ones were collected. LuaJIT places a string key by the ID it gave the string when it interned it, and it draws those IDs from a random start in each process. So code whose cost depends on that order can take a different time on the same input in another process. No step of aineo's Report is such code (see *Limits*).

## Example

- **The probe.** `rm-pairs-order.lua` fills a table with twelve string keys in a fixed order and prints the order `pairs()` visits them in. Each run was a fresh `nvim --clean --headless -i NONE -l` started from a mini.test case under `make test_file` ([[Attachments/learnings-probes-2026-10-05.txt]]):
  - PR #97's re-measure, 2026-10-05, four Neovims: three orders;
  - wave 6's closing knowledge pass, the same day, eight Neovims: six orders;
  - the records review of PR #101, the same day, two runs of eight Neovims: six orders, then seven.
- **A rotation, until an ID is redrawn.** Keys interned one after another come out as a rotation of their interning order, since their IDs are consecutive. Most orders seen are rotations of `alpha … mu`. When LuaJIT redraws its next ID between two of the keys, the rotation breaks: the review's second run printed `lambda alpha beta gamma delta epsilon zeta eta theta iota kappa mu`.
- **Interning order, not insertion order.** A script whose constants are parsed `mu … alpha` and inserted `alpha … mu`, run in the standalone `luajit`, printed only rotations of the parse order in the review's eight runs. Its re-run for this correction printed seven rotations of the parse order in eight, and one broken by a redraw.
- **Within one process, only while the keys live.** The closing pass built the table five times in one Neovim from the constants in `KEYS`, which the chunk keeps alive: one order five times, in each of two Neovims. Built from key strings made at run time and collected between builds, in one `luajit` process, the same twelve names gave four orders in five builds (the review) and five in five (this correction's re-run).
- **What it did to a test.** T29's re-measure built INT, a Report drawing whose cost is chosen per process by a `vim.uv.random` coin, to stand for a drawing whose cost varies from process to process. Two times over the 2 s bound in about half of its processes, it passed a bound judged on the fastest of three fresh processes 8 of 8 times, where a single attempt killed it 3 of 4 (the re-measure's rows, quoted in [[Attachments/learnings-probes-2026-10-05.txt]]; the T29 note, *Decisions & reasoning*). The re-measure gave the `pairs()` order as the reason such a drawing is not hypothetical. INT's variation came from its coin, not from `pairs()`. See [[Learnings/A wall-time bound over the best of several fresh processes misses a slowdown only some processes show]].

**Why.** LuaJIT 2.1 places a string key in a table's hash part by the string's ID, not by its hash: `#define hashstr(t, s) hashmask(t, (s)->sid)`, that is `sid & hmask`, under "String IDs are generated when a string is interned" (`src/lj_tab.h:41–42`).
- `lj_str_alloc` gives the IDs in interning order, `s->sid = g->str.id++` (`src/lj_str.c:265–296`).
- Under `LUAJIT_SECURITY_STRID 1`, the default (`src/lj_arch.h:758–761`), it redraws `g->str.id` from the state's PRNG after a random number of strings below 2^8.
- The PRNG is seeded from the operating system's entropy when the state is created (`lj_prng_seed_secure`, `src/lj_state.c:257`). So each process starts its IDs somewhere else.
- `next` walks the hash part from its first slot upward (`lj_tab_next`, `src/lj_tab.c:616`). What moves from process to process is the slot of the first-interned key, and with it where the cycle of keys appears to start.
- The seeded string hash, `g->str.seed` (`src/lj_str.c:367`), serves LuaJIT's interning table, not a Lua table's slots.

This was read in LuaJIT's `v2.1` source at `c6ffc141` (committed 2026-09-08T08:43:01Z), the commit the host's version stamp `2.1.1788856981` names. The standalone `luajit` of that version shows the same variation without Neovim, so the order comes from LuaJIT, not from Neovim.

## Why it matters

- **A timing measured in one process is one draw.** Code whose cost depends on a `pairs()` order can cost more or less in the next Neovim on the same input. A timing case that starts fresh processes sees that spread; one that reuses a process does not.
- **Never rely on a `pairs()` order, across processes or within one.** The order holds within a process only while the key strings stay interned. A test that compares two walks over keys built at run time can fail in one process, and a test that compares orders across processes can fail between them. Sort the keys when the order matters.
- **Limits:**
  - measured on 0.12.5 only, on macOS arm64; 0.11.6 was not run (D29);
  - twelve short string keys; integer keys in a table's array part are not covered;
  - the Neovim probes ran under `--clean`, so no plugin or config shaped the process;
  - the mechanism was read for LuaJIT `v2.1` at `c6ffc141` with its default `LUAJIT_SECURITY_STRID 1`; a LuaJIT built with another setting was not looked at;
  - no step of the Report walks a `pairs()` order whose cost depends on it. Its two `pairs()` loops, `lua/aineo/report/colours.lua:51` (the default links) and `lua/aineo/report/links.lua:61` (three brackets), cost the same in any order; `paths.lua` and `init.lua` have none. The order is a possible source of per-process variation, not one seen in aineo.
