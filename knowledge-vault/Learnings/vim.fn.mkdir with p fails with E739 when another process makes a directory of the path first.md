# vim.fn.mkdir with p fails with E739 when another process makes a directory of the path first

**Tags:** #neovim #filesystem #race #measured
**Discovered:** [[Sessions/2026-10-07 — T37 Changes per session]] (PR #136's attack review, finding 3, and its records review, finding 2); first met in [[Sessions/2026-09-24 — T5 report channel]]'s finding 10
**Applies to:** [[Projects/aineo]]

## The insight

`vim.fn.mkdir(path, 'p')` is not safe against a second process making the same directories at the same moment. It checks a level, finds it missing, and when another process makes that level before its own `mkdir` does, it raises `E739: Cannot create directory …: file already exists` — for any level of the path, the leaf or a parent. Retrying solves it: try again, at most once per level of the path, since each lost race means one more level exists.

## Example

- **T5** met it first: two editors writing their first report raced on the state directory, and the records home retries `mkdir()` (`Sessions/2026-09-24 — T5 report channel`, finding 10). The claude home's `session_ids.lua`, the records and the draft copied the retry.
- **T37's** `lua/aineo/changes/kept.lua` copied the write pattern without it. The records review ran four Neovims at once, each keeping a session in 200 fresh state directories: 125 and 164 of 800 keeps failed; with the retry, 0 of 1600. The warning then silenced every later failure for the editor's life, and the session's base went unkept. The fix round added the loop (`e26bfaf` on `dev`), and the correction pinned two lost races in a row (X6, `eae959d`).
- **This pass** (`probe-mkdir.lua` in [[Attachments/learnings-probes-2026-10-08.txt]]), Neovim 0.12.5: four processes each making `<root>/<n>/aineo/<own leaf>` for 200 values of `n`: 366 and 350 of 800 failed when tried once, the messages naming a parent (`…/aineo`) or the root; 0 of 800, twice, with one retry per level.

**Why.** Measured, not read from Neovim's source. The failures name every level — the leaf, a parent, the root — which fits a `p` walk that checks each level and then makes it, so another process can make it between the two; that reading is this pass's, not traced in the code.

## Why it matters

- Every home that makes a folder under `stdpath('state')` or another shared directory, where two Neovims can start together. The four copies in aineo (claude, report, draft, changes) cannot share one helper without a new kernel home, which the modularity table does not have; a fifth copy must take the loop too.
- **Limits:** measured on macOS; the loop is bounded by the path's depth, which holds while no process removes the directories it makes.
