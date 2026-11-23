# 2026-11-23 — T190 a project whose worktree was removed is closed

**Author:** the user, with Claude — implementer agent (Sonnet 5.5)
**Branch:** `bugfix/t190-drop-removed-worktrees` (from `origin/dev` at 0dae0628)

## Links

[[Projects/aineo]] — D30 (a small fix: the test files it touches), the projects of a tab (`lua/aineo/entry/projects.lua`).

## Why

A session with many subagents, each in a git worktree, reported work in other repositories and edited files in them, so each repository joined the tab as a project. When a subagent finished and its worktree folder was removed, the project stayed: its tab, its watch and its kept entry, and the changes pane under it said `The last refresh failed: fatal: cannot change to '<worktree>/<subfolder>': No such file or directory`.

## Root cause

The holder is the tab's project list (`entry/projects.lua`, `state.list`, `state.homes`) and its kept file (`aineo.projects`' `keep()`). A project is the repository a file's checkout belongs to, keyed by its common git directory, with `top` the checkout's top level where it was first met (`projects/checkouts.lua`). Nothing ever asked whether `top` still existed: only `take_live_checkout()` replaced a gone `top`, and only when the same repository was met again at another checkout.

The subfolder comes from a repository nested in the worktree (or a submodule checked out there): `git rev-parse --show-toplevel` run in it gives the subfolder, and its common directory goes with the worktree, so no other checkout of that repository is ever met and the project is stuck on a folder that is gone. The project's home runs git with that folder as its directory, and git says the line above.

Measured before the change: a worktree joined as a project, then `git worktree remove`: the tab stayed and the files window showed the line. The session home's other-worktree sections (`git worktree list`'s `prunable` and a missing directory are left out), its Reported section (`reports.still_listed()`, a deleted branch included) already drop what is gone; nothing there changed.

## What changed

- `lua/aineo/entry/projects.lua`: `close_project()` (the closing `X` did, now shared); `close_project_if_gone()`, which closes a held project other than the session's when `vim.uv.fs_stat(top)` finds nothing and tells the user once (`aineo: <name> closed: its worktree was removed`); `recount()` calls it when a count cannot be read — the read that already happens when a project is shown, joins, is edited, or its repository changes — so no timer or poll was added; `rebuild()` leaves out of the list, and from what is kept, a kept project whose folder is gone, saying nothing.
- `README.md`, `doc/aineo.txt`: the projects' description says so.
- `tests/test_entry_projects_gone.lua` (8 cases).

## Decisions

- **Dropping at once vs. re-topping (`take_live_checkout()`).** Detection is only where a read of a project fails (or at a restore), so a project whose worktree went and whose repository is met again at another checkout *before* anything reads it is re-topped, base kept, as before (`test_entry_projects_report.lua`'s retop case still passes). Once a read has failed the project is closed and its base is gone with it; a later report of the repository's main checkout joins it anew from `HEAD`. Chosen over re-topping automatically to the main checkout on detection, which would leave a tab for a repository the user never asked to follow again.
- The per-project base and saves files of a closed project stay, as `X` leaves them; no new deletion API.
- The session's own project is never closed, whatever its folder.
- A quiet restore: a gone kept project is left out with no notice.

## Tests

Red, seen: the seven cases that need the new behaviour failed with the project's tab still in the line. Arrived green: the session's own project (nothing closed it yet; killer: removing its guard) and, after correcting its own expectation, `stays a tab while its folder is there` (killer: dropping the folder check).

| Mutant (literal edit) | Result |
|---|---|
| `is_held_with_folder_gone`: `and not vim.uv.fs_stat(held.top)` → `and false` | killed, 5 cases, assertions |
| same: `and not vim.uv.fs_stat(held.top)` → removed (always gone) | killed, 8 cases |
| same: `state.session_project.key ~= key and` removed | killed twice: an assertion on the tab line (its count lost), then a Lua error in a scheduled callback (`let_go` of the session's home) — ratio 1 assertion : 1 crash |
| `rebuild`: restore filter `fs_stat(project.top) ~= nil` → `true` | killed by assertion (a notice at restore) |
| `rebuild`: `keep_projects(state)` after the filter removed | killed by assertion (2 kept, 1 expected) |
| `recount`: `close_project_if_gone(tab, state, key)` removed | killed, 5 cases |
| `close_project_if_gone`: the `tellers` notice removed | killed by assertion |

## Open

- Whether a closed project's per-project base file should be deleted.
- A project nobody reads (not chosen, no edits, no repository change) is closed when it is next read, not when its folder goes.

## Commits

recorded after the merge
