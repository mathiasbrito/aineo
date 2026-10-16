# 2026-10-16 — T80 Always show the tab line

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t80-always-show-tabline` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Sessions/2026-10-16 — T79 README]] (the README whose settings table and tab-line text this packet edits)
- `doc/aineo.txt` — *aineo-tabs*, *aineo-tab_title*, *aineo-config-tabs.always_show*, *aineo-config-claude.hide_multiplexer*, *aineo-limits*, the Tab line section of *aineo-health*

A small fix in the user's prompt-driven waves (D30). The user's words, 2026-10-16: "can we configure nvim to always show the tabs?" and, told that aineo leaves `'showtabline'` alone, "make aineo to always show it." Recorded as the user's decision; the knowledge pass gives it a D-number. It supersedes A364 (wave 17's O11 (a)).

Assumptions the brief gave: A387 (`tabs.always_show`, boolean, default `true`; `'showtabline'` set to `2` when aineo's first tab opens, whoever draws the tab line; `false` leaves it), A388 (set once, never set back), and A389 (added while the packet ran: with `claude.hide_multiplexer = false` inside tmux, Claude Code's mouse-selection copy is wrapped for tmux, and Neovim 0.12.5's terminal prints `52;c;<text>` in Claude's window; the help, LIMITS and the health warning say so).

## Task lines

- [X] T80 aineo always shows the tab line — done on `feature/t80-always-show-tabline`: `tabs.always_show` (boolean, default `true`) in `SETTINGS`; `aineo.tabs`' `show_tabline_once()` sets `'showtabline'` to `2` the first time the entry holds a tab and never again, called from `hold_tab()` in `lua/aineo/entry/opening.lua`; the Tab line section of `:checkhealth aineo` says whether aineo shows the line and what `'showtabline'` is; help and README updated; A389's OSC 52 sentence added to the help, LIMITS, the README and the health warning for `TMUX`.

## What was done, and why

- **Where it lives.** The tabs home owns the once-flag and reads `tabs.always_show` the way it already reads `tabs.padding` (`vim.g.aineo` and `setup()`'s options, the defaults when the value is wrong, so a redraw never raises and health reports the error). `draw_tabline()` is unchanged and still never touches `'showtabline'`. The composition root's body (`lua/aineo/entry/opening.lua`, `hold_tab()`) calls `show_tabline_once()` after `draw_tabline()`: every first tab — the autostart, `\o`, `\T` with no tab — is held through it. `lua/aineo/entry/` is in the brief's boundary.
- **Once means once per editor.** The flag is set at the first call whatever the setting says, so `tabs.always_show` turned on later does not set the option at a later tab, and a user's `'showtabline'` is kept across a second `\T`. Nothing sets it back when aineo's tabs close.
- **Health.** Three wordings, from the setting and the option: shown (`'showtabline'` is 2), will be set when the first tab opens (it is N now — before the open, or changed by the user after it), left as the user has it (`false`). None while the configuration is wrong, since the Configuration section reports that. The line sits second in the section, so later indexes in `tests/test_health.lua` moved by one.
- **A389.** `side_effect` on the `TMUX` row of health's `SILENT_TITLE_VARIABLES` adds ", and a copy made in the Claude window prints 52;c;<text> there" to that warning; `STY` and `ZELLIJ` rows are unchanged because the investigation measured the tmux form only (the screen form printed nothing).

## Unit list, red and green

1. Config: `tabs.always_show` default and sources — red: the three defaults tests, from `tabs.always_show` absent; the sources test; green by the row.
2. Config: a non-boolean is refused — red ×3 (`1`, `'true'`, `{}`): the message did not match.
3. Tabs: `show_tabline_once()` — red ×5 (attempt to call a nil field). Of those, the false, setup-over-global and wrong-value cases are green by nature after the function exists (the default path is the one that changed state); mutants below kill each.
4. Entry: first open shows the line (`\o`, with the user's own `'tabline'`, autostart) — red ×3; `false` ×2 and "keeps a value set after the first open" arrived green (spent: nothing set the option yet); mutants kill each.
5. Health: three wordings plus the wrong-config silence — red ×4 for the new wordings (and the three whole-section tests and four index tests that moved); the wrong-config case arrived green (spent by the `nil` guard being the first thing written).
6. A389 in health's `TMUX` row — red: the `TMUX` row only.
7. Docs: `tests/test_doc.lua` was red for the missing tag *aineo-config-tabs.always_show*, then red for a tag line that was not 78 columns wide; green after both.

One flake: `tests/test_health.lua | Claude Code | leaves the editor free to wait when Ctrl-C ends a check of a command that writes without end` failed once while other runs were in flight and passed on the next three runs; not touched by this packet.

## Mutants

Each is the literal edit, applied to the final tree, run on the files named, restored from a copy.

| # | Edit | Run on | Result |
|---|---|---|---|
| M1 | `lua/aineo/tabs/init.lua`: delete the line `  tabline_shown_once = true` | `tests/test_tabs.lua`; `tests/test_entry_tabs.lua` | killed by assertion: `keeps a 'showtabline' set after the first call`; `keeps a 'showtabline' the user set after the first open` |
| M2 | `lua/aineo/tabs/init.lua`: `if tabs_settings().always_show then` → `if true then` | `tests/test_tabs.lua`; `tests/test_entry_tabs.lua`; `tests/test_entry_startup.lua` | killed by assertion: the two `false`/setup cases; the `false` case in each entry file |
| M3 | `lua/aineo/tabs/init.lua`: `vim.o.showtabline = 2` → `vim.o.showtabline = 1` | `tests/test_tabs.lua` | killed by assertion: `sets 'showtabline' to 2 by default`; the wrong-value case |
| M5 | `lua/aineo/entry/opening.lua`: delete the line `  tabs.show_tabline_once()` | `tests/test_entry_tabs.lua`; `tests/test_entry_startup.lua` | killed by assertion: first-tab ×2; autostart ×1 |
| M6 | `lua/aineo/tabs/init.lua`: fallback `return config.resolve_config(nil, nil).tabs` → `return { padding = 2, always_show = false }` | `tests/test_tabs.lua` | killed by assertion: `shows the line by default when tabs.always_show is wrong` |
| M9 | `lua/aineo/config/init.lua`: `default = true` → `default = false` on `tabs.always_show` | `tests/test_config.lua`; `tests/test_tabs.lua` | killed by assertion: 6 and 2 failures |
| M4 | `lua/aineo/health.lua`: `elseif showtabline == 2 then` → `elseif true then` | `tests/test_health.lua` | killed by assertion: 5 failures, among them `says aineo sets 'showtabline' once…` |
| M10 | `lua/aineo/health.lua`: `if not resolved_config.tabs.always_show then` → `if resolved_config.tabs.always_show then` | `tests/test_health.lua` | killed by assertion: 7 failures |
| M7 | `lua/aineo/health.lua`: delete the guard `if resolved_config == nil then return end` | `tests/test_health.lua` | killed: `says nothing of tabs.always_show while the configuration is wrong` fails on the section's content (the check raised, and the section held its error); one more case fails behind it |
| M8 | `lua/aineo/health.lua`: delete the `side_effect = …` line of the `TMUX` row | `tests/test_health.lua` | killed by assertion: the `TMUX` row of `warns, naming the variable…` |

No survivor.

## Decisions

- Called from `hold_tab()`, not from `draw_tabline()`: the latter is documented, tested and idempotent without touching the option, and its callers (health's tests, the highlight tests) stay as they are.
- A389's sentence is under `TMUX` only (the evidence measured tmux's form; screen's printed nothing).

## Open threads

- The whole suite was not run (D30); the orchestrator decides.
- The wording of the OSC 52 sentence rests on the investigation's measurements on Claude Code 2.1.301 and Neovim 0.12.5; a later Claude Code may change the copy.

## Commits

*Recorded after the merge.*
