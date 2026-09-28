# Neovim 0.12 shows a terminal's exit line as an extmark, not as buffer text

**Tags:** #neovim #neovim-0.12 #terminal #measured
**Discovered:** [[Sessions/2026-09-25 — T13 Neovim 0.12]] (PR #31) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

When a terminal job ends, Neovim 0.11.6 writes `[Process exited N]` into the terminal buffer's text. Neovim 0.12.5 does not. A default `TermClose` autocommand of the group `nvim.terminal` shows it as overlay virtual text, on an extmark in the namespace `nvim.terminal.exitmsg`. Code or a test that looks for the line with `nvim_buf_get_lines()` finds it on 0.11 and never on 0.12. One that reads the namespace finds nothing on 0.11, which has no such namespace.

## Example

T13's implementer measured it on both versions for PR #31, with a probe run as `nvim --clean --headless -l <probe>`. The probe started a terminal job `sh -c 'exit 3'`, waited for its end and 500 ms more, then looked in the buffer's text and in the namespace. The probe is in T13's session note, *Measurements this rests on*.

- **0.12.5:** `in_text = false`, and `virtual_texts = { "[Process exited 3]" }` in `nvim.terminal.exitmsg`.
- **0.11.6:** `in_text = true`, and the namespace does not exist.

On 0.12.5 at `dev` `9af91a6`, the case *session_status() › leaves the terminal showing Neovim's exit line* failed for this reason: the part `[Process exited 3]` was not in the buffer's text (`Implementation/Waves/00006-fixes/evidence/baseline-0.12.5.txt`). T13 now reads the line where each version puts it (`tests/test_claude.lua`, `39d9cb0` on `dev`). Its mutant M8 cleared the `TermClose` autocommands of `nvim.terminal`:
- on 0.12.5 it killed the case;
- on 0.11.6 it survived, because there Neovim writes the line itself.

**Why.** `runtime/lua/vim/_core/defaults.lua` at `v0.12.5`, lines 593–638, holds the autocommand:
- It creates the namespace `nvim.terminal.exitmsg`.
- It defines a `TermClose` autocommand in the group `nvim.terminal`, with `nested = true`.
- It places `virt_text = { { msg } }` with `virt_text_pos = 'overlay'` on the row given by the event's `data.pos`.
- `msg` is `[Process exited %d]`, from `v:event.status`. A buffer with no channel (`nvim_open_term()`) gets `[Terminal closed]`.
- When `TermClose` comes before the buffer is a terminal, the autocommand waits and places the mark at `TermOpen`.

0.11.6's `runtime/lua/vim/_defaults.lua` has no such autocommand. Its one `TermClose` autocommand in `nvim.terminal` (lines 518–532) deletes the buffer of a shell that exited 0. Both files were read by this knowledge pass (2026-09-28), in the two releases' own runtimes.

## Why it matters

Anything that reads a terminal's end from its text must look in both places, or branch on the version. That covers a plugin that tells the user why a job ended, and a test that waits for the line.
- On 0.12 the line is an autocommand's, so a user can remove it: `:autocmd! nvim.terminal TermClose` does, and the same command on 0.11 leaves the line in place (M8). There it removes only the autocommand that deletes the buffer of a shell that exited 0.
- **Limits:**
  - measured on 0.11.6 and 0.12.5 only; 0.12.0–0.12.4 were not measured;
  - measured for a job that exits by itself with a code; a job ended by a signal was not measured.
