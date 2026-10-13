# 2026-10-12 — T55 Pane cursor

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `bugfix/t55-pane-cursor` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D59, D58, D52, D18, C12, T54, T55
- Rests on: [[Sessions/2026-10-12 — T49 Scroll filter]] (the commits window the cursor now lands in)

## What was done

The user, on the `<C-\>` twins (T54): the pane keys show a pane but the cursor often stays where it was, which defeats moving without `<C-w>`. The answer (D59): `\g` lands in the commits window, `\pa` in the Report.

- `aineo.layout` gains `focus_pane(pane, arrangement)` (`lua/aineo/layout/init.lua`): `show_pane()`, then the cursor to the Report's window under the agent pane and to Input's window, which shows the commits, under the changes pane (`PANE_LANDING`). `show_pane()` stays, unchanged; when it raises, the cursor stays.
- `plugin/aineo.lua`: the pane action's `show_pane()` becomes `focus_pane()`, calling the layout's. The changes pane's read on showing stays before it.
- `doc/aineo.txt`: *aineo-panes*, `:Aineo-pane`, the overview of *aineo-mappings* and *aineo-terminal-keys* say where the cursor lands.
- The cursor also moves when the pane was shown already, and from another tab page into the layout's own.

## Unit list

1. `\g`, `<Plug>(aineo-pane-changes)` and `:Aineo pane changes` from Claude's window land in the commits window, the pane hidden before and shown before.
2. `\pa`, `<Plug>(aineo-pane-agent)` and `:Aineo pane agent` land in the Report, the pane hidden before and shown before.
3. `<C-\>g` and `<C-\>pa` from Terminal and Insert mode land there, in Normal mode.
4. `focus_pane()` itself, in the layout's own suite.

## Red and green

**Seen red:** the four entry cases of units 1 and 2 (`left = "terminal"`, `right = "aineo://report"` for the agent pane; the changes pane's likewise). Unit 3 and 4 were written after the code, so they were not seen red; the mutants below kill them.

Three cases that pinned the old behaviour changed: the changes pane key from another tab page (the cursor now moves into the layout's tab page, into the commits window), and the pane key with the layout never opened from a window showing a file (the cursor lands in the Report for `agent`, Input's window for `changes`).

## Mutants

See the table below, run on `tests/test_entry_panes.lua`, `tests/test_layout_panes.lua` and `tests/test_entry_terminal_keys.lua`, each restored in the same call.

| # | Literal edit (`layout/init.lua`, `focus_pane()`) | Result |
|---|---|---|
| 1 | the cursor move wrapped in `if pane ~= 'changes' then … end` (dropped for `changes`) | killed by assertion — 8 in `test_entry_panes.lua`, 1 in `test_layout_panes.lua`, 2 in `test_entry_terminal_keys.lua` (the window name was the Claude terminal's, not `aineo://changes-commits`) |
| 2 | the cursor move wrapped in `if pane ~= 'agent' then … end` (dropped for `agent`) | killed by assertion — 7 in `test_entry_panes.lua`, 1 in `test_layout_panes.lua`, 2 in `test_entry_terminal_keys.lua` |
| 3 | the cursor move placed before `M.show_pane()` | killed in `test_entry_panes.lua` by failures, not by an assertion alone: 91 cases failed, most of them `Invalid channel` once the child had failed on the layout that was not open yet. Survived `test_layout_panes.lua` and `test_entry_terminal_keys.lua`: with the layout open, windows are shown in place by role, so the order cannot be seen there |

## Open points

- The cursor lands in the Report under the agent pane: the user's option text said “\pa would likewise land in the Report”. Input is not chosen.
- The cursor lands in Normal mode in the Report and the commits window, as `\r` does; no Insert mode starts.

## Task lines

- T55 `[X]` (`bugfix/t55-pane-cursor`, into `dev`) — `\g` and `\pa`, `:Aineo pane`, their `<Plug>` mappings and `<C-\>` twins move the cursor into the pane they show (D59). The user's words: “it is fine, but sometimes the cursor do not move to the pane, this was manily to avoid moving through windows with ctrl+w”. Small fix of the user's prompt-driven waves (D30).

## Commits

- PR #187, `bugfix/t55-pane-cursor`, head `3c244aa` (1 commit), merged by rebase into `dev` as `090f6f6`.
- Released in v0.2.28 (PR #188, `main` `1fc653d`).
