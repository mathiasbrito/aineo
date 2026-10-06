# A buffer name a loaded buffer holds cannot be taken, and an unloaded namesake is wiped

**Tags:** #neovim #buffers #sessions #trap
**Discovered:** [[Sessions/2026-10-05 — T24 Panes]] (the author's probe for mutant MP5, the attack review of PR #105, finding 1, and its records review)
**Applies to:** [[Projects/aineo]]

## The insight

In Neovim 0.12.5, `nvim_buf_set_name(buffer, name)` raises E95 ("Buffer with this name already exists") while another **loaded** buffer holds `name`. When that other buffer is **unloaded**, for example by `:bdelete`, the rename succeeds and Neovim wipes the old buffer. The cause is Neovim's rename, `setfname()` (`src/nvim/buffer.c`, v0.12.5): it refuses a name another buffer holds while that buffer has a memline (`b_ml.ml_mfp`), that is while it is loaded, or while a window shows it, and wipes a namesake that has neither (`close_buffer(…, DOBUF_WIPE, …)`). Session files recreate buffers under their saved names. A plugin that names its scratch buffers therefore frees the name before it takes it: it wipes the namesake, or unnames it with `:0file` when the user changed its text.

## Example

T24 gave the changes pane two placeholders, `aineo://changes-files` and `aineo://changes-commits`, which the composition root makes on the first open of the layout, and anew on a later open once one is wiped or unloaded (`changes_pane()`).

- **The trap** (the attack review of PR #105, finding 1). Open the layout, press `\pc`, run `:mksession! S.vim`, then start `nvim -S S.vim` and run `:Aineo open`. The restored editor holds a buffer under each name. Every door that opens the layout then fails with `aineo: E95: Buffer with this name already exists`, after Claude Code has started in a terminal no window shows.
- **The rename rule**, measured with `nvim --clean` on 0.12.5 by the records review of PR #105, after the author's probe for MP5. With an unloaded namesake the rename succeeds and the old buffer is no longer valid. With a loaded one it fails with E95. The author removed an explicit wipe of an unloaded namesake for this reason (`5523b0d` on `dev`; `9e2ca50` on the PR's branch).
- **The fix** (`3b5504a`; `85723de` on the branch). `placeholder_buffer()` calls `free_buffer_name()` first (`plugin/aineo.lua`). It wipes a namesake, or keeps a modified one unnamed (`:0file`), as the Report's `free_report_buffer_name()` already did (`lua/aineo/report/buffer.lua`).
- **What it cannot fix.** A session script sourced twice raises E95 from its own `file aineo://…` line, for the Report's name too (T24's re-measure, R8c and R8d). That error comes from the session script, so no plugin code runs early enough to prevent it.

## Why it matters

Any buffer a plugin names (`aineo://report`, `aineo://input`, the changes pane's buffers, and the ones T25 makes) can meet a namesake that a session, another plugin or the user created. Before every `nvim_buf_set_name()`, check who holds the name. A buffer `:bdelete` left behind is a separate trap: [[Learnings/A deleted scratch buffer written to again blocks quitting]].
