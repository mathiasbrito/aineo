# 2026-11-19 — T189 Claude Code is sent Ctrl+L after its window's size settles

**Author:** the user, with Claude — implementer agent (Sonnet 5.5)
**Branch:** `bugfix/t189-redraw-claude-after-resize` (from `origin/dev` at b0b3053e)

## Links

[[Projects/aineo]] — T183 (the fresh size of Claude's terminal), D30 (a small fix: the test files it touches).

## Why

The user reported that resizing windows leaves Claude Code's content shrunk, and that Ctrl+L in insert mode fixes it. The pty's size was already right: the fresh size of T183 sends Claude Code a SIGWINCH, and Claude Code then redraws only the frame it is drawing, leaving text it wrote while the window was narrower wrapped narrow. Ctrl+L makes it redraw its whole screen at the size it has.

## What changed

- `lua/aineo/layout/fresh_size.lua`: `give()` takes an optional `after` callback and runs it `AFTER_DELAY_MS` (200) after the final jobresize, so Claude Code has served the resize.
- `lua/aineo/layout/init.lua`: `give_claude_terminal_a_fresh_size()` hands `give()` a callback that sends Claude's terminal one Ctrl+L. At the moment of sending it re-checks that the layout is not zoomed fully, that Claude's window shows Claude's terminal with a live job, and that the setting is on. A run counter (`state.fresh_size_run`) bumped by each request makes a run of overlapping fresh sizes send one Ctrl+L, from the last. The arrangement takes `claude_redraw_on_resize`.
- `lua/aineo/config/init.lua`, `lua/aineo/entry/tab.lua`: the setting `layout.claude_redraw_on_resize` (boolean, default `true`), validated like the other layout booleans and handed to the layout in the arrangement.
- `README.md`, `doc/aineo.txt`: the setting is documented; the doc test lists its tag.

## Decisions

- The callback sits in `give()` rather than a sibling function: the delay after the final size is a property of the same sequence, and the guards live in the layout, which passes them in.
- The local-variable limit of `make_layout` (200) has no room for another helper, so the guard lookup is nested in the function that uses it.

## Tests

- `tests/test_layout_claude_redraw.lua` (5 cases), a recorder terminal that logs the bytes it reads beside its sizes (`tests/helpers/pty_recorder.lua`: `KEY_RECORDER`, `events()`, `events_during()`): one Ctrl+L after the final size; one for three changes in a run; one when the window changes again mid-gap; none with the setting off, the fresh size kept; none while zoomed fully.
- `tests/test_entry_claude_redraw.lua` (2 cases), through `Aineo open` and `vim.g.aineo`: the Ctrl+L after the panes close, and none with the setting off.
- `tests/test_config.lua`: the default, both sources, the refusal of a non-boolean.
- Mutants, all killed: no send; send before the final jobresize; the setting ignored in the layout; the setting not handed over in `entry/tab.lua`; the run check removed.

## Open

- Whether the 200 ms between the final size and the Ctrl+L is enough for a Claude Code that is busy rendering; it is `fresh_size.AFTER_DELAY_MS`.
