# bwipeout of a running terminal shows the next buffer before BufWipeout

**Tags:** #neovim #terminal #autocommands #buffers #measured
**Discovered:** [[Sessions/2026-09-26 — T21 Claude exit]] (the attack review of PR #64, A1) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

Take a terminal buffer shown in the current window, with no other listed buffer to show there. `:bwipeout!` of it puts a new empty, unnamed, listed buffer in that window, and the order of events depends on whether the terminal's job still runs.

- **A running terminal:** the new buffer comes first. The order is `BufEnter` and `BufWinEnter` of the new buffer, then `TermClose`, `BufUnload` and `BufWipeout` of the terminal, and the window already shows the new buffer.
- **An ended terminal:** the order is reversed. `BufUnload` and `BufWipeout` of the terminal come first, with the window still showing it, then `BufEnter` and `BufWinEnter` of the new buffer.

A `BufWipeout` handler that asks "does this window show the wiped buffer?" gets yes for an ended terminal and no for a running one.

## Example

- **T21's packet (PR #64)** closed Claude's window at `BufWipeout` only when the window showed the wiped terminal. It rested on a trace of an *ended* terminal: `BufWipeout:2`, then `BufEnter:4` and `BufWinEnter:4`, on both versions.
- **The attack review of PR #64** (at `70a43c7`, on 0.12.5 and 0.11.6, A1) traced a *running* one, wiped with `:bwipeout!` from Claude's window: `BufWinEnter buf=4 (Claude's window shows 4)`, `TermClose buf=2`, `BufUnload buf=2`, `BufWipeout buf=2 (Claude's window shows 4)`.
  - So the guard never matched, and the window stayed on the empty buffer.
  - The next `\c` then moved to that buffer and started nothing.
  - `:bdelete!`, and a Terminal-mode mapping running `bwipeout!`, did the same.
- **The fix round** closes the window in either case (fixA; `3371260` on `dev`). The window must show the wiped terminal or an unnamed, empty buffer at the wipe, and still an unnamed, empty buffer when the scheduled close runs.
- **This pass, in bare Neovim** (2026-09-28, `probe-bwipeout.lua` in `Implementation/Waves/00006-fixes/evidence/learnings-probes.txt`).
  - The setup: two windows, one showing an unlisted `nofile` buffer and the current one showing a listed terminal. The terminal runs `cat`, or `sh -c 'exit 0'` waited out first.
  - Each event is logged with the buffer the window shows at that moment.
  - The output is identical on 0.12.5 and 0.11.6:

  ```
  running terminal: BufEnter(buf 3; the window shows buf 3) -> BufWinEnter(buf 3; the window shows buf 3) -> TermClose(buf term; the window shows buf 3) -> BufUnload(buf term; the window shows buf 3) -> BufWipeout(buf term; the window shows buf 3)
  running terminal: afterwards the window shows buf 3, name "", listed true
  ended terminal: BufUnload(buf term; the window shows term) -> BufWipeout(buf term; the window shows term) -> BufEnter(buf 5; the window shows buf 5) -> BufWinEnter(buf 5; the window shows buf 5)
  ended terminal: afterwards the window shows buf 5, name "", listed true
  ```

**Why.** Not traced in Neovim's source. For the running terminal, `TermClose` fires inside the wipe, after the window has changed buffer: wiping a running terminal ends its job.

## Why it matters

A `BufWipeout` or `BufDelete` handler for terminal buffers must accept both orders:
- look for the wiped buffer **or** an unnamed, empty one in the window;
- check again when any scheduled action runs, since the same command line may already have put something else there (T21's A2: `:bwipeout! | edit <file>`).

The empty buffer appears only in the case above. In other cases Neovim closes the terminal's window instead (the brief review of PR #62, on `617e4a5`, both versions):
- the wipe runs from another window or another tab;
- a file buffer is listed.

The exception is a window Neovim cannot close, such as its last one (T21's session note, *Limits*).

**Limits:**
- measured on 0.11.6 and 0.12.5;
- measured with the wipe run from the terminal's own window.
