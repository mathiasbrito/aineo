# 2026-10-20 — T101 run pane opens on an agent run

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t101-run-shows-pane` · **Pull request:** into `dev`

When the agent's `run` tool starts a process, the run pane is now shown in the tab page the user is in, the cursor staying where it is. A D30 small fix of wave 21.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D91, T101 (A514, the orchestrator's ruling), D85 (the run tools; A476 left the pane out of view)
- `lua/aineo/entry/run_pane.lua` — `start_in_stack()`, `show_stack_in_current_tab()`
- `doc/aineo.txt` — the run tools section (`aineo-run-tools`)

## Task lines

- [X] T101 The run pane opens when the agent runs a command (C2, C12; D91, A514, D85): `start_in_stack()` shows the run pane through the tab's `show_pane('run')` when the calling tab's tab page is the current one, the cursor staying where it is; another tab page keeps its layout; the answer to the agent, the docstrings and the help say that the pane is shown.

## The user's words

"[improvement] could the run panel open when the agents runs a command approved by the user?" (2026-10-20)

## What was done

- `refresh_shown_stack()` showed the run pane again only when it was already shown. It is now `show_stack_in_current_tab()`: it shows the pane whichever pane was shown, when `tab.is_current()`, through `tab.show_pane('run')`, and tells an error once through `errors.run`. A calling tab in another tab page is left as it is. `run_stop` and `follow_processes()` are untouched.
- The answer to the agent reads `Started "<name>" in the run pane, which is now shown, the cursor staying where it is.` The MCP tool description (`lua/aineo/mcp/run_tools.lua`) and the README did not say where the pane stays and are unchanged.

## Red and green

- Red, by the intended failure (the windows were still the agent pane's, the answer still said the old words): `starts the process in the first tab’s stack, shows the run pane, and tells the user once` (renamed from `…leaves the run pane unshown…`), `shows the run pane over the agent pane, the cursor staying in the window it was in`, `shows the run pane over the changes pane`, and `run | starts the command in the stack, named by its first word, and answers at once` (test_entry_run_tools.lua).
- Green by nature: `leaves the layout of a tab the user is not in as it is` — the old code left that layout too; killed by the mutant `always` below.
- The cursor case puts the cursor in Claude's window first: Input's window, where the cursor starts, is one the run pane replaces, so no window-identity pin could hold there.

## Mutants (test_entry_run_calls.lua, 8 cases; all assertion failures)

| Edit to `run_pane.lua` | Result |
|---|---|
| `tab.show_pane('run')` → `local _ = 0` in `show_stack_in_current_tab()` | killed by 4 (the three windows pins and `adds the process to the stack at the bottom…`) |
| `tab.show_pane('run')` → `tab.focus_pane('run')` | killed by `…the cursor staying in the window it was in` |
| `if not tab.is_current() then` → `if false then` | killed by `leaves the layout of a tab the user is not in as it is` |

## Open threads

- The answer to the agent says the pane is shown also when the calling tab is in another tab page, where it is not; the run tools do not know the tab page the user is in.

## Commits

Recorded after the merge.
