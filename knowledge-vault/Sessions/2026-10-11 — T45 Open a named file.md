# 2026-10-11 — T45 Open a named file

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet, A123)
**Branch:** `feature/t45-open-file` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D7, D19, D34, D46, D47, C9, C15, T45
- [[Implementation/Waves/00011-names-and-sessions/plan]] and [[Implementation/Waves/00011-names-and-sessions/brief-t45-open-file]] (its *Amendment — 2026-10-11, at dispatch: T43 and T44 merged*). **A112** (U1, O5: the user did not name the key, so T45 is the `gf` fix), **A118** (after T44), **A122** (`gf` alone), **A123** (Sonnet) and **A126** (the dispatch amendment written by the implementer, as A124 did for T44) are the orchestrator's assumptions, never the user's decisions; **proposed D50** is the row the packet builds, proposed, not recorded.
- Rests on: [[Sessions/2026-10-11 — T43 Changes filter]] (the entries the files window lists), [[Sessions/2026-10-11 — T44 Full-context diffs]] (the diff buffers, which map `F` only)

## What was done

**The changes home (C15), `lua/aineo/changes/`:**
- `open_file.lua` (new): `open_listed_file(entry, top)` opens the working tree's file an entry of the files window lists, `top` joined with the entry's `change.path` — the path git gave, never the text under the cursor — through `nvim_cmd({ cmd = 'edit', args = { path }, magic = { file = false, bar = false } })`, so no character of a name is a wildcard, a modifier or the end of the command. An entry of another worktree opens nothing and warns once, `aineo: the changes pane opens no other worktree's file` (D34). A path no longer in the working tree (`fs_lstat` fails) opens nothing and warns once, `aineo: <path as the files window shows it> is gone from the working tree` (A3, `lines.quoted_path()`).
- `init.lua`: `open_file_at_cursor()` reads the entry under the cursor with `pages.entry_at()` and does nothing on a line that lists none; `map_open_file()` maps `gf` in Normal mode, buffer-local, on the files buffer, called where `M.pane_buffers()` makes that buffer, so a buffer made anew is mapped again. The commits buffer and the diff buffers are not mapped.

**`doc/aineo.txt`** — *aineo-changes*: a paragraph after the one on Enter: what `gf` opens and where, the commit filter (A2), the two refusals, the lines that list no file, that it is a buffer-local Normal-mode map with no `<Plug>`, and that Enter and `gf` take a file's name from the list itself, whatever characters it holds, so a name that fails to open is a fault to report. `tests/test_doc.lua` stays green. The existing sentence "no key opens another worktree's file" stays true.

**The brief** — its *Amendment — 2026-10-11, at dispatch* (A126): line numbers moved (`open_entry()` 1173, `pane_buffer()` 1208, the `<CR>` map 1221); the entries carry `filter` (T43); the filter's line lists no entry; the diff buffers map `F` only (T44); no spec conflict.

## Decisions and departures from the brief

- **`nvim_cmd` with the file and bar magic off**, not `vim.cmd.edit(fnameescape(path))`: a line break in a name cannot cross a command line, and the case with one passes (measured). Rejected: `vim.fn.bufadd` + `nvim_win_set_buf` (does not read as `:edit` does).
- **`fs_lstat`, not `fs_stat`**, tells whether the file is there: a link is a file of the working tree whether or not its target exists, as the files window lists it.
- **The guard for a line that lists no file lives in `init.lua`**, beside `open_entry()`'s, and `open_file.lua` takes an entry that lists one.
- **No guard on `session.repository`**: an entry that lists a file exists only once the session found its repository, which it never loses.
- Only the brief's files were touched, and `tests/test_entry_changes.lua` for the layout cases.

## Unit list (stated before the first test)

1. `gf` opens the file whose name holds a space.
2. Names holding an apostrophe, a tab, a double quote, characters outside ASCII, `%` and `#`, a bar, wildcards, a backslash, a line break, a leading plus.
3. A deleted file opens nothing and says it is gone; named as the files window names it.
4. Another worktree's file opens nothing, not the editor's file of that name, and says so.
5. A line that lists no file (the filter's line, a note, a heading) opens nothing and says nothing.
6. The map is buffer-local: made anew with the buffer; Vim's `gf` stays in any other buffer, the commits buffer and a diff buffer.
7. Through the layout: the file opens in the file column, the files window still lists; with none of the layout's windows open, it opens in the files window.
8. The help.

## Red and green

**Seen red (before the code):** *opens the file whose name holds a space…* (`E447: Can't find file "has" in path`, Vim's own `gf`); *on a deleted file opens nothing and says the file is gone* (the current buffer was the file, not `aineo://changes-files`); *on another worktree’s file opens nothing…* (the editor's `same.txt` was opened); *on a line listing no file opens nothing and says nothing*, 4 cases (a Lua error from the key press: no map guard yet).

**Arrived green, and why:** the ten *opens a file whose name holds…* cases — spent by the first unit's implementation (the path is taken whole), killed by mutants 1 and 6; *on a deleted file names it as the files window does* — the deleted unit's code already quoted the name, killed by mutant 10; the three Vim's-own-`gf` cases and *in the files buffer made anew…* — green by nature of a buffer-local map made with the buffer, killed by mutants 3, 8, 9; the two layout cases in `tests/test_entry_changes.lua` — the layout's redirect already moves a file shown in one of its windows to the file column (D7, C9), and the right column's pane windows count (A1, measured: the files window stays `aineo://changes-files`), killed by mutants 5 and 11.

**Suites (Neovim 0.12.5, on the host, on the tree pushed):** `make test` 2618 cases in 77 groups, `Fails (0)`, exit 0; `tests/test_changes_open_file.lua` 22 cases at the first push (29 after the fix round) and `tests/test_entry_changes.lua` with its two new ones; `make lint` clean. An earlier whole run, taken while the host was busy, ended with `tests/test_claude.lua` stalled (`mini.test made no progress for 10 s`, its Neovim exited 1); that file passes alone (117 cases) and the whole run was taken again.

## Mutants

Each applied to the file named, run on the covering test file, restored in the same call (`.tests/t45-mutate.py`, a scratch script, not committed); the edit is the text before → after, run on the final tree. A kill is read from the output as an assertion (`Failed expectation`, or `expect.no_error` / `expect.error` failing) or an error the product raised.

| # | File | Literal edit | Result |
|---|---|---|---|
| 1 | `changes/open_file.lua` | `local path = vim.fs.joinpath(top, entry.change.path)` → `local path = vim.fs.joinpath(top, vim.fn.expand('<cfile>'))` | killed by assertion, 11 (`test_changes_open_file.lua`: the space case, nine of the ten names, *made anew*); the leading-plus case survives it, because the path is always the top level joined with the name and never begins with `+`, so that case pins nothing about `:edit`'s `+cmd` |
| 2 | `changes/open_file.lua` | `if entry.worktree then` → `if false then` | killed by assertion, 1 — *on another worktree’s file opens nothing…* |
| 3 | `changes/init.lua` | `end, { buffer = buffer, desc = 'aineo: open the file of the entry under the cursor' })` → `end, { desc = 'aineo: open the file of the entry under the cursor' })` (a global map) | killed by assertion, 3 — Vim’s own `gf` in another buffer, the commits buffer, a diff buffer |
| 4 | `changes/open_file.lua` | `if not vim.uv.fs_lstat(path) then` → `if false then` | killed by assertion, 2 — both deleted-file cases |
| 5 | `changes/open_file.lua` | `{ cmd = 'edit', args = { path }, magic = { file = false, bar = false } }` → the same with `, mods = { noautocmd = true } }` (the layout's redirect never sees the file, which stays in the pane's window) | killed by assertion, 1 — `test_entry_changes.lua`, *opens the file in the file column…* |
| 6 | `changes/open_file.lua` | `magic = { file = false, bar = false }` → `magic = { file = true, bar = true }` | killed, 2: *a backslash* by assertion; *a percent sign and a hash* by the Vim error `:edit` raised to the key press. Only `file` is pinned: `bar = true` alone survives and is equivalent, measured (`nvim_cmd` does not split a list argument at a bar over eight names holding `\|`, `"` and a trailing bar). The fix round's rows F5 and F6 below say the same. |
| 7 | `changes/init.lua` | `open_file_at_cursor()`: the `if not entry then return end` removed | killed by assertion, 4 — the lines listing no file (`expect.no_error`) |
| 8 | `changes/init.lua` | after `select_filters_from(buffers.commits)`, `map_open_file(buffers.commits)` added | killed by assertion, 1 — *in the commits buffer stays Vim’s own* |
| 9 | `changes/init.lua` | `map_open_file(buffers.files)` → `if not _G.t45_mapped then _G.t45_mapped = true; map_open_file(buffers.files) end` (mapped once, not when the buffer is made anew) | killed by assertion, 1 — *in the files buffer made anew…* (`expect.no_error`) |
| 10 | `changes/open_file.lua` | `lines.quoted_path(entry.change.path)` → `entry.change.path` | killed by assertion, 1 — *names it as the files window does* |
| 11 | `changes/open_file.lua` | `  vim.api.nvim_cmd({ cmd = 'edit'` → `  vim.cmd('new')` before it (a new window for the file) | killed by assertion, 1 — `test_entry_changes.lua`, *with none of the layout’s windows open…* |

The plan's five (1–5 of *Verification mutants* › T45) are rows 1, 2, 3, 4 and 5 here.

## Fix round (PR #164)

The two reviews of `8c2919f` found no blocking fault. **A127 and A128 are the orchestrator's assumptions under the user's instruction of 2026-10-06, never the user's decision.**

- **A127 (attack 1):** `gf` on a line whose path is a directory — a submodule, a nested repository, a worktree inside the tree — opens nothing and says `aineo: <path as the files window shows it> is a directory, not a file`, as it refuses another worktree's file; without it `:edit` opened netrw on the other worktree's files. The check is `fs_stat` after the `fs_lstat` one, so a link to a directory is refused too and a link whose target is missing opens (it is in the working tree; tests finding 2). The help says so.
- **Attack 2:** `nvim_cmd` is wrapped in `pcall`; a `Keyboard interrupt` (the user abandoning at a swap file's prompt) is dropped, as Vim's own `gf` drops it; any other error is told once with `vim.notify` at ERROR, naming the file.
- **Attack 3:** the awkward names gain a backtick command (asserting no `pwned` file is created, the child's directory being the top level) and a `[x].txt` case beside `x.txt`.
- **Tests 1 and 2:** a case for `gf` under a commit filter (the working tree's file, with its text), and a dangling-symlink case pinning `fs_lstat`.
- **Tests 3, 4, 7:** rows 1 and 6 above now say what was measured (only `file` is pinned; the leading-plus case survives mutant 1). The pushed commit is not amended, so its message's count of cases killed by an error stands as it is.
- **A128 (tests 5):** the help's "Enter takes any name" stands on T43's and the wave 11 probes' evidence; no new case.
- **Tests 6:** the task line below carries the PR number and the mutant mapping.

**Seen red (before the code):** *on a directory’s line…* (`E31` from netrw: the directory was opened); *that :edit refuses is told once…* (`E5108` with the Lua traceback at `open_file.lua`); *that the user abandons at the swap file’s prompt…* (`E5108: … Keyboard interrupt`). **Arrived green:** the backtick name and *[x].txt* (the implementation already took the path whole; killed by F5), the commit-filter case (F7) and the dangling link (F2).

| # | Literal edit (`changes/open_file.lua`) | Result |
|---|---|---|
| F1 | `if target and target.type == 'directory' then` → `if false then` | killed by assertion, 1 — the directory case |
| F2 | `vim.uv.fs_lstat(path)` → `vim.uv.fs_stat(path)` | killed by assertion, 1 — the link whose target is missing |
| F3 | `if not opened and not tostring(failure):find(ABANDONED, 1, true) then` → `if not opened then` | killed by assertion, 1 — the swap-file abandon |
| F4 | `pcall(vim.api.nvim_cmd, …)` → a call that raises | killed by assertion, 2 — the refused edit (the error is not the told one) and the abandon |
| F5 | `magic = { file = false, bar = false }` → `{ file = true, bar = false }` | killed, 4: *a backslash* and *[x].txt* by assertion; *a percent sign and a hash* and *a backtick command* by the Vim error raised to the key press |
| F6 | `magic = { file = false, bar = false }` → `{ file = false, bar = true }` | survives, 29 of 29: equivalent, measured |
| F7 | after the path is built, `if entry.filter and entry.filter.kind == 'commit' then return end` | killed by assertion, 1 — the commit-filter case |

**Suites after the fix round (Neovim 0.12.5, host):** `make test` 2625 cases in 77 groups, `Fails (0)`; `tests/test_changes_open_file.lua` 29 cases; `make lint` clean; `tests/test_doc.lua` green.

## Task lines

- T45 `[X]` (PR #164, into `dev`, wave 11; the plan's five mutants are rows 1–5 of the first table) — `gf` in the changes pane's files window opens the file its line lists, by the path git gave for it, whatever characters it holds, in the file column (D7, C9); a deleted file and another worktree's file open nothing and say why; Vim's `gf` stays in every other buffer. Under A112 and proposed D50 (the orchestrator's assumption, not the user's decision); the help says Enter and `gf` take any name. Regular packet, `feature/t45-open-file`.

## Open threads

- Under a commit filter `gf` opens the working tree's file, not the file at that commit (A2); a user who wants the commit's version has the diff.
- A submodule, a nested repository and a worktree inside the tree are refused as directories (A127, the fix round).

## Commits

Recorded after the merge, by the T45 knowledge pass. PR #164 merged by rebase as `a3b2fef` … `a62588d` (3 commits), now `9a922f7` … `d0055c9` on `dev`; the orchestrator verified the pull request's head `a62588d`, rebased on `dev` `1234fcd`: the whole suite 2625 cases, `Fails (0)`, lint clean, and the mutant for the directory refusal killed by assertion. Released in v0.2.22 (PR #165, `main` `591fa2b`).

| Branch | `dev` | Subject |
|---|---|---|
| `a3b2fef` | `9a922f7` | Open a named file from the files window with gf |
| `8c2919f` | `2fc0e78` | Pin T45's quoting and make its kills assertions; add its session note |
| `a62588d` | `d0055c9` | Refuse a directory in gf, tell a failed edit once, pin the open's edges |

The `Branch` column is the pull request's own commits (`refs/pull/164/head`); the verified head `a62588d` is the last of them. The first commit carries the brief's dispatch amendment (A126).
