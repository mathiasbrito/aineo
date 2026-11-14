# 2026-11-14 — T181 the explorer's width as a share of the screen

**Author:** the user, with Claude — implementer agent (Sonnet 5.5)
**Branch:** `bugfix/t181-explorer-width-share` (from `origin/dev` at e34b58b7)

## Links

[[Projects/aineo]] — A747 and D157 as the brief holds them; D30 (small fix: the test files touched, no whole suite before a push; the orchestrator runs it).

## Why

The user: the explorer's default width is too shrunk; a third of the screen was the first idea. The orchestrator's recommendation, accepted: `layout.explorer_width` also takes a share of the screen, the default is a quarter with a floor of 40 columns, and a whole count still works.

## What changed

- `config/init.lua`: `layout.explorer_width` takes a whole number of at least 1 (columns) or a number strictly between 0 and 1 (a share); anything else is refused naming both forms. The default is `1 / 4`.
- `layout/init.lua`: the layout keeps the setting as handed and resolves it at each use (`explorer_cells()`): a count as is, a share as `max(40, floor(columns * share))` of the screen's width now. Every place that sized the column from the setting calls it: `set_column_widths()` (so a resize, `VimResized`, re-resolves it), `size_focused_columns()` (the file focus) and the end of a full zoom. The arrangement's and `set_explorer_column()`'s validation accepts a share.
- `README.md`, `doc/aineo.txt`: both forms, the default, the floor.

## What the other paths do with a share

There is no hand-resize path for the explorer column: nothing stores the window's own width back into `state.explorer_width`, and every pass that sizes the columns (a resize, a new arrangement, a window opening or closing, the file focus, the end of a zoom) sets the explorer's window to the setting again. A share is therefore re-resolved at each of those passes, as a count is re-applied. A handed arrangement keeps the setting it was handed last when it carries none, a count or a share. `set_explorer_column()` records the setting, and a share is compared as the setting, so a change from `1/4` to `1/3` resizes the column, while the same share does nothing.

## Decided

- The share is resolved in the layout, not in the configuration: the layout alone knows when the screen is resized, and the configuration stays a plain value (`1 / 4` in `resolve_config()`).
- The floor of 40 applies to the share only, as asked: a count of 20 is 20.
- A narrow screen (under 160 columns) therefore shows a 40-column explorer by default, as before.

## Tests

- Red first: `tests/test_config.lua` (a share accepted, `1` taken as one column, `0`, `-0.2`, `1.5`, `40.5`, strings, booleans and infinity refused with the two-form text, the default `1 / 4`); `tests/test_layout_explorer_width_share.lua` (60 at 240 columns, 40 at 120, rounding down, a count literal, a resize from 240 to 200 giving 50, the same during the file focus, after a full zoom, by `set_explorer_column()`, and the arrangement's refusal); `tests/test_entry_explorer_column.lua` (the default, a count and a share at 240 columns through the entry, a share kept across a resize).
- Existing tests: `tests/test_config.lua`'s `DEFAULTS` and its default-width case now say `1 / 4`; the entry suites run at 240 columns, where the default is 60 and not 40, so the cases that asserted a 40-wide default explorer were updated (listed in the pull request).

## Open threads

None.
