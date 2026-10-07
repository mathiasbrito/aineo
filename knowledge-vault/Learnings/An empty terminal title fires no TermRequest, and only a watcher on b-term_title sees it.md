# An empty terminal title fires no TermRequest, and only a watcher on b:term_title sees it

**Tags:** #neovim #terminal #statusline #measured
**Discovered:** [[Sessions/2026-10-07 — T33 Claude window name]] (wave 8's planning probe P3 and its brief review, finding 1.2) · [[Sessions/2026-10-07 — Wave 8 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

A program in a Neovim terminal sets its title with OSC 0 or OSC 2, and Neovim keeps it in the terminal's `b:term_title`. A non-empty title also fires `TermRequest` with the sequence. **An empty title** — the clear a program sends as it exits — empties `b:term_title` and fires **no `TermRequest`**. So code that follows a title through `TermRequest` keeps the last title after it is cleared. A dictionary watcher on the terminal's `b:` dictionary, for the key `term_title`, sees every change, the empty one included.

`TermRequest` also fires for sequences that set no title (OSC 1, OSC 9;4, APC), so it is the wrong signal in both directions; the watcher is the one that matches the variable.

## Example

- **T33** follows Claude Code's title for the name in Claude's window (`lua/aineo/claude/session_name.lua`; `cca919a` on `dev`). It adds the watcher with `dictwatcheradd(b:, 'term_title', …)` from Vimscript, handing it the Lua callback through a buffer variable it removes at once, since Lua cannot hold a reference to a buffer's `b:` dictionary (the packet's reading). The plan's mutant 7, the title followed through `TermRequest` alone, is killed by the case where an empty title must give `Claude Code` again.
- **Claude Code 2.1.292** clears its title at exit, and T33-6 logged no `TermRequest` then ([[Learnings/Claude Code sets its terminal title by OSC 0 and clears it when it exits]]).
- **This pass**, in bare Neovim 0.12.5 (`probe-empty-title.lua` in [[Attachments/learnings-probes-2026-10-07.txt]]): a terminal running `printf '\033]0;One\007'`, then `printf '\033]0;\007'`. The watcher saw the `term://` name, then `One`, then `""`; `TermRequest` fired once, for `One`; `b:term_title` ended `""`.

**And the screen.** The brief review measured that a window-local status line drawing the title redraws by itself on a non-empty title, not on an empty one (finding 1.2). T33 schedules `:redrawstatus!` when the name changes. A mini.test child, which has no user interface, redraws the status line on `:redraw` whatever asked, so a missing redraw can be pinned only in an editor with a user interface (T33's packet, borne out by the test-integrity review of PR #129, finding 7).

## Why it matters

- The clear at exit is exactly the change a window naming the program needs to see.
- `b:term_title` holds the terminal's own `term://` name until the program sets a title, and for the whole session when it sets none; reading it as a title shows `term://…` (MR302).
- **Limits:** measured on 0.12.5. The watcher's callback runs synchronously, while `TermRequest` came only once the probe's `jobwait()` returned. The order of the two for one sequence was not measured otherwise.
