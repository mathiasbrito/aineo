# 2026-10-16 — T77 Command-line window flakes

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `bugfix/t77-cmdwin-flakes` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D10, D26, D28, D29
- [[Sessions/2026-10-15 — T71 Changes flakes]] › *Open threads* (the keys cases that stub a failing read)
- [[Sessions/2026-10-15 — T75 Tab activity homes]] (its fix round measured the command-line window cases failing on the unchanged code)

Test-only (D28): the command-line window cases of the panes suite, and the keys cases of the changes suite that type a key and read the child before the key has run. A374, the premise that these are load flakes with a lost `<C-c>`, is the orchestrator's assumption, not the user's decision. No production code changed. Measured on Neovim 0.12.5.

## Task lines

- [X] T77 Harden the command-line window cases of the panes suite and the changes keys race (test-only, D28) — done on `bugfix/t77-cmdwin-flakes`: the three sites (five cases) that closed the window with `<C-c><Esc>` close it with the typed command `:quit<CR>` and wait for it to be closed, and wait for aineo's refusal to be told before reading it; three keys cases wait for the state their keys produce (the cursor; the second read begun) or call the mapping (the two `HEAD names no commit` cases); reviewed once (records and test integrity), merged as PR #235; one count corrected below.

## The cause

A `<C-c>` that reaches a child while it is in a loop that checks for an interrupt is taken as the interrupt and is lost, with the keys typed before it. Measured in a child with a `\g` mapping that busies it for 400 ms, then `q:`, `\g`, `<C-c>`, `<Esc>` as the case types them, 1.2 s later:

| What the mapping does for 400 ms | The command-line window |
|---|---|
| `vim.wait(400, …)` | still open (`getcmdwintype()` is `:`) |
| scheduled `vim.wait(400, …)` | still open |
| `:sleep 400m` | still open; the child raises `Keyboard interrupt` |
| a spin on `vim.uv.hrtime()` (no check for an interrupt) | closed |
| nothing | closed |

A request sent to the same child is served inside such a loop, before the keys typed earlier are read. So a case that types keys and then reads the child (`child.v.errmsg` in `child.type_keys()`, `child.lua_get(…)`) reads it before the keys have run when the child is busy.

The failing run of the unchanged panes file showed the window list `terminal`, `""`, `aineo://report`, `aineo://changes-commits` where the changes pane belonged: the `""` window is the command-line window left open.

### Per case

**Count correction (the records review, finding 2).** The text of this note, the commit message and the pull request first said "the five places" and "the 7 command-line window cases". The original file has three code sites that typed `<C-c><Esc>` (the lines of the refused-switch case, of the parametrised set and of `refuse_switch_with_report_shown_by_hand()`); five is the number of cases that run them (the first, the parametrised set's two, and the two that call the helper). Seven is the whole parametrised set, with its two `by winfixbuf` cases, which never open the window; so the rows below that read "the 7 command-line window cases", "7 cases" and "5 of 7" mean seven cases of which five type into the window, and the two `by winfixbuf` cases cannot fail. The right wording is three sites, five cases.

1. `tests/test_entry_panes.lua`, the three sites (five cases) that typed `q:`, `\g` and then `<C-c>`, `<Esc>`: *a switch refused in the command-line window › leaves the column as it was…*; *a switch to the changes pane, refused* (parametrised, `in the command-line window`) with its two cases; and `refuse_switch_with_report_shown_by_hand()`, used by two cases, which did not wait for the window to close at all. Fix: `press_g_in_a_command_line_window()` types `q:` and `\g` and waits for aineo to have told the refusal (the case that asserts `told` reads it after that, no longer before it); `close_the_command_line_window()` types `:quit<CR>`, which is text and not an interrupt, and waits for `getcmdwintype()` to be empty. Every wait is bounded by `claude_session.PATIENCE_MS` and asserted, where the old wait ended silently.
2. `tests/test_changes_keys.lua` › *h and l › stay Vim's own in › the buffer*: typed `l`, `l`, `h`, then read the cursor once. Fix: `expect_cursor()`, which waits for the cursor as `expect_lines()` waits for lines, then asserts.
3. `tests/test_changes_keys.lua` › *h › then l on the same file before the first is read…*: pressed `l`, then called `_G.pending.previous`, which the `l` key had not yet made. Fix: wait for it.
4. `tests/test_changes_keys.lua` › *h › on a file under a commit, when HEAD names no commit…* and *…under Landed, when HEAD names no commit…*: relied on `child.type_keys()` raising the told error (`MiniTest.expect.error`), which `type_keys()` reads before the key has run when the child is busy (`Observed no error`). Fix: `call_files_mapping_on_line()`, the helper T71 added, and an assertion on `v:errmsg` after the call, which keeps the ERROR level pinned (the assertion of the neighbouring *dev names no commit* case does not).

An instrumented run of the keys file (every ERROR told, per case) shows four cases tell one: those three and *a diff that cannot be read* (T71). No other keys case can have a told error raised by `type_keys()`.

## What each file did before and after

Each run in a copy of the checkout of its own (the fixtures live beside the helpers, so same-file runs in one checkout delete one another's repositories: 8 runs at once in one checkout failed on `unable to get current working directory`), 20 busy loops beside them.

**Natural load**, 8 files at once. The original file's rate is low and the sample does not separate the two; the modelled child below does.

| File | Original | Final |
|---|---|---|
| panes, the 7 command-line window cases | 1 of 96, 1 of 320 (load not recorded), then 0 of 320 (load about 215) | 0 of 320 (load about 215); 0 of 640 more on the state before the last edit |
| panes, whole file (100 cases) | 0 of 24, 0 of 32 | 0 of 32 |
| keys, whole file (29 cases) | 0 of 80, 0 of 64 | 0 of 64 |
| keys, the 3 `names no commit` cases | 0 of 320 | not run again |

**A modelled child** (a copy of the file with the child made busy; the same copy of the original and of the final file, 5 runs each, runs failed / cases failed):

| Model | Original | Final |
|---|---|---|
| panes (7 cases): every notification is followed by a scheduled `vim.wait(300)` | 5 of 5 / 20 | 0 of 5 / 0 |
| panes: every notification told 200 ms late | 5 of 5 / 10 | 0 of 5 / 0 |
| panes: a timer keeps the child in `vim.wait(15)` for 15 of every 20 ms | 5 of 5 / 12 | 0 of 5 / 0 |
| panes, whole file: the same timer | 1 run, 2 of 100 | 0 of 2 runs, 0 of 100 |
| keys (29 cases): the same timer | 5 of 5 / 27 (the cursor case ×3, the second-read case, the two `HEAD names no commit` cases) | 0 of 5 / 0 |

Final files, run alone on the tree pushed: `tests/test_entry_panes.lua` 100 cases, `Fails (0)`; `tests/test_changes_keys.lua` 29 cases, `Fails (0)`. `make lint`: 0 errors. No helper changed, so no other file is affected; the case counts are unchanged.

## Mutants

Each from a fresh copy of the final file, run on the narrowed or whole copy named, with the model named. "Assertion" is a `Failed expectation for equality`.

| Literal edit | Model | Result |
|---|---|---|
| `close_the_command_line_window`: `child.type_keys(':quit<CR>')` → `child.type_keys('<C-c>', '<Esc>')` | scheduled wait after each notification; and the timer | 5 of 7 cases fail, assertion; the same on both |
| `press_g_in_a_command_line_window`: `return #entry.messages(child) > told_before` → `return true` | notifications told 200 ms late | 2 of 7 fail, assertion |
| `close_the_command_line_window`: `return child.fn.getcmdwintype() == ''` → `return true` | scheduled wait after each notification | 4 of 7 fail, assertion |
| `expect_cursor`: `return vim.deep_equal(child.lua_get('vim.api.nvim_win_get_cursor(0)'), expected)` → `return true` | the timer | 3 of 29 fail, assertion |
| the second-read wait: `return child.lua_get('_G.pending.previous ~= nil')` → `return true` | the timer | 1 of 29 fails by a crash (`attempt to call field 'previous' (a nil value)`), not an assertion: the wait guards a call |
| production, in a copy: the `vim.log.levels.ERROR` of `tell_diff_unreadable` → `WARN` | none | both `HEAD names no commit` cases fail, assertion (`v:errmsg` is empty) |

A condition kept in an earlier draft of `close_the_command_line_window`, `and child.fn.mode() == 'n'`, survived under every model tried (the scheduled wait, the late notification, the timer, a wait after `CmdwinLeave`, a wait on `ModeChanged n:c`) and was removed. A probe records a state with the window gone and the mode still `c` while `:quit` runs, but no poll reached it.

## Open threads

- The sample of the original file's natural failure is small (2 runs of 736); the lost `<C-c>` as its cause rests on the extra `""` window in the failing run and on the model, not on a recorded keystroke.
- *Lines listing no file › do nothing and say nothing* reads `shown` and `told` right after the key; on a busy child the key may not have run, and the zeros are then read before it (not measured here, not a failure that was seen).
- `<C-c>` is typed elsewhere in the suite (`tests/test_health.lua`, `tests/test_claude_resume.lua`, `tests/test_draft.lua`) to interrupt on purpose; those were not examined.

## Commits

- PR #235, `bugfix/t77-cmdwin-flakes`, head `9ffc007` (1 commit), merged by rebase into `dev` as `4b8c7c4` (Close the command-line window by a typed command and wait for keys (T77)). No fix round: A375 left the review's two low findings (a second wait helper in the panes file where `git_repo.wait_until` exists; the counts in the commit message and the pull request) as pushed. The count is corrected in this note by the knowledge pass.
- Released in v0.2.41 (PR #237, `main` `8a1f46e`), with T75 and T76; the release carries no production change from this packet.
