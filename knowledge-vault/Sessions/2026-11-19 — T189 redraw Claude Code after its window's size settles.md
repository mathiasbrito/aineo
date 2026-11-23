# 2026-11-19 — T189 Claude Code is sent Ctrl+L after its window's size settles

**Author:** the user, with Claude — implementer agent (Sonnet 5.5)
**Branch:** `bugfix/t189-redraw-claude-after-resize` (from `origin/dev` at b0b3053e)

## Links

[[Projects/aineo]] — T183 (the fresh size of Claude's terminal), D30 (a small fix: the test files it touches).

## Why

The user reported that resizing windows leaves Claude Code's content shrunk, and that Ctrl+L in insert mode fixes it. The pty's size was already right: the fresh size of T183 sends Claude Code a SIGWINCH, and Claude Code then redraws only the frame it is drawing, leaving text it wrote while the window was narrower wrapped narrow. Ctrl+L makes it redraw its whole screen at the size it has.

## What changed

- `lua/aineo/layout/fresh_size.lua`: `give()` takes an optional `after` callback and runs it `AFTER_DELAY_MS` (200) after the final jobresize, so Claude Code has served the resize.
- `lua/aineo/layout/init.lua`: `give_claude_terminal_a_fresh_size()` hands `give()` a callback that sends Claude's terminal one Ctrl+L. At the moment of sending it re-checks that the layout is not zoomed fully, that Claude's window shows Claude's terminal with a live job, that the setting is on, and that Claude Code is ready for input. A run counter (`state.fresh_size_run`) bumped by each request makes a run of overlapping fresh sizes send one Ctrl+L, from the last. The arrangement takes `claude_redraw_on_resize` and `claude_is_ready`, a predicate the layout keeps; with none handed it sends nothing.
- `lua/aineo/config/init.lua`, `lua/aineo/entry/tab.lua`: the setting `layout.claude_redraw_on_resize` (boolean, default `true`), validated like the other layout booleans and handed to the layout in the arrangement.
- `lua/aineo/entry/tab.lua` also hands the layout `claude_is_ready`, which reads `session_status() == 'ready'`, the status the tab already tracks. The first fresh size runs as the layout opens, before Claude Code has put its tty in raw mode, where a Ctrl+L could echo as `^L` or sit in its input (found by the whole-suite run: four cases that record every byte Claude receives).
- `README.md`, `doc/aineo.txt`: the setting is documented; the doc test lists its tag.

## Fix round

The whole suite failed four cases on the first commit, all from the Ctrl+L reaching a Claude where a test records every byte: `test_entry_explorer` (`@` while Claude is not ready), `test_entry_terminal_keys` (a twin sends nothing) and two of `test_entry_walkthrough`. The readiness check removes the first; the three files' open helpers now pass `layout = { claude_redraw_on_resize = false }` (their subject is not a resize), keeping their exact byte assertions.

## Decisions

- The callback sits in `give()` rather than a sibling function: the delay after the final size is a property of the same sequence, and the guards live in the layout, which passes them in.
- The local-variable limit of `make_layout` (200) has no room for another helper, so the guard lookup is nested in the function that uses it.

## Tests

- `tests/test_layout_claude_redraw.lua` (5 cases), a recorder terminal that logs the bytes it reads beside its sizes (`tests/helpers/pty_recorder.lua`: `KEY_RECORDER`, `events()`, `events_during()`): one Ctrl+L after the final size; one for three changes in a run; one when the window changes again mid-gap; none with the setting off, the fresh size kept; none while zoomed fully.
- `tests/test_entry_claude_redraw.lua` (2 cases), through `Aineo open` and `vim.g.aineo`: the Ctrl+L after the panes close, and none with the setting off.
- `tests/test_config.lua`: the default, both sources, the refusal of a non-boolean.
- Readiness: `test_layout_claude_redraw.lua` (no Ctrl+L while not ready, one after a resize once ready, none when no predicate is handed) and `test_entry_claude_redraw.lua` (none while aineo does not read Claude Code as ready; the recorder draws an input box to become ready in the other cases).
- Mutants, all killed: no send; send before the final jobresize; the setting ignored in the layout; the setting not handed over in `entry/tab.lua`; the run check removed; the readiness check removed from the layout; the entry's predicate always true; no predicate treated as ready.

## Open

- Whether the 200 ms between the final size and the Ctrl+L is enough for a Claude Code that is busy rendering; it is `fresh_size.AFTER_DELAY_MS`.
