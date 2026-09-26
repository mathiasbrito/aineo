# 2026-09-26 — T14 Input draft

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t14-input-draft` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D17; C11, C2, C4, C6; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t14-input-draft.md` with the amendment of 2026-09-26, the brief reviews `brief-review-t14-input-draft.md` and `brief-review-t14-amendment.md`, the evidence `nofile-quit.txt` and `baseline-7af0d47.txt`
- [[Review/2026-09-24 — v1 MVP readings review]], which holds the orchestrator's readings as MR105–MR108; the implementer's below go there

## Context

**Goal:** T14. Input is a `nofile` scratch buffer, and Neovim quits over its text without a word. The user called that "completly undesired behavior" and chose, on 2026-09-25, "Keep it as a draft" (D17): saved per working directory beside the Reports shortly after each change and at quit, restored into an empty Input when aineo opens there, cleared with Input when Send clears it; two editors in one folder share one draft, the last change winning.

## What was done

- **`lua/aineo/draft/init.lua`, a new home (C11).** Its entry point is two functions: `set_draft_environment({ state_directory, working_directory, files? })` and `keep_draft(buffer)`. It requires no aineo home.
  - The draft is `<state>/aineo/drafts/<sha256 of the working directory>.txt`: the buffer's lines, each ending in a newline, and nothing once the buffer is empty.
  - Changes are seen through `nvim_buf_attach`'s `on_lines`. A non-empty change is saved `SAVE_DELAY_MS` (1000 ms) later. A change that empties the buffer empties the draft at once.
  - A change still pending is saved at the buffer's `BufUnload`, and nothing else is written then; since the fix round, first at `QuitPre` too. A restore happens before the buffer is attached, so it is no change; since the fix round, it is not undoable either.
  - The draft is restored only into an empty buffer that is not kept already. `on_detach`, which fires when `:bdelete`, `:edit!` or a wipe drops the text, ends the keeping; since the fix round, a buffer-local `BufWinEnter` hands the buffer over again the next time a window shows it.
  - Writes follow three patterns copied from `lua/aineo/report/records.lua`: a temporary file named `<draft>.<pid>.cut`, renamed over the draft and following a symlink through `fs_realpath`; `0600`; and `mkdir()` tried again after a race. The file writes (`write_file`, `make_directory`) are a declared dependency, `aineo.draft.Files`, that no production caller overrides.
  - A failed read or write is a `WARN` starting `aineo: `, once per editor for each. Nothing raises: since the fix round, a draft that cannot be put into Input (an Input that is not `'modifiable'`, as `nvim -M` makes it) is a read failure too, and no longer raises `nvim_buf_set_lines()`'s `Buffer is not 'modifiable'` out of `open()`.
- **`plugin/aineo.lua`:**
  - `kept_places()` takes `stdpath('state')` and `getcwd()` once, and both the report home and the draft home get them from it. So the Reports and the draft are kept for the same working directory.
  - `keep_input_draft()` gives the draft home its environment the first time, and hands it `layout.input_buffer()`. `open()` calls it after `layout.open()`. `focus()` calls it only when its arrangement callback ran, which is when the layout opened.
  - Nothing is required at startup.
- **`tests/test_draft.lua`** (22 cases) drives the home directly in a child. **`tests/test_entry_draft.lua`** (12 cases) drives it through `:Aineo open`, `\i`, `\r`, `\c`, `\s`, `\o`, `:Aineo send` and the autostart. Every case that writes or restores a draft has a state directory of its own.
- **`doc/aineo.txt`, inside `*aineo-layout*` only:**
  - the Input bullet points at the new subsection;
  - a new subsection, `Input's draft ~` `*aineo-draft*`, says where the draft is kept and when, when it is restored and cleared, ID6's sharing, and the quit-handler limit.

  T16's wrap paragraph is untouched; an unchanged blank line separates it from the bullet's hunk.

## Unit list and red/green

The slicing, stated before the first test:

1. ID1: a change is saved shortly after, under the state directory, for the working directory.
2. ID1: a change that empties the buffer empties the draft at once.
3. ID3: the draft is restored into an empty buffer handed over the first time.
4. ID3: it is not restored into a buffer that holds text.
5. ID3: it is not restored into a buffer handed over again, emptied by a change.
6. ID3: it is restored into a buffer handed over again once `:bdelete` dropped its text.
7. ID2: quitting saves a change the delay has not saved yet.
8. ID2: quitting after a restore writes nothing.
9. ID2: quitting after the delay has saved writes nothing; after `:bdelete`, it keeps the saved draft.
10. ID5: `0600`.
11. ID5: a write that fails after truncating leaves the previous draft.
12. ID5: a symlinked draft is written through.
13. ID5: a `mkdir()` that loses a race is tried again.
14. ID6: two editors, the last change winning though the older editor quits last; they never share a temporary file.
15. ID7: an unreadable draft warns once and raises nothing, on both read paths.
16. ID7: an unwritable draft warns once and raises nothing into typing, nor at quit.
17. ID2: the quit writes the draft alone; a buffer handed over again after `:bdelete` is watched once.
18. Entry: `:Aineo open` restores; so do the first `\i`, `\r` and `\c` on a closed layout.
19. ID4: `:Aineo send` from another window empties the draft at once, read before any quit.
20. ID3 in the entry: after a Send, `\o`, `\i`, `\r` or `\c` restores nothing, not even a draft another editor wrote since. A wiped Input gets its text back.
21. ID7 in the entry: an unreadable draft on `:Aineo open` gives one `WARN` and no `ERROR`.
22. The autostart restores the draft.
23. ID8, the invariant: the frozen pins in `tests/test_plugin.lua` still kill both startup mutants.

**Seen red: 20 cases, each on its assertion**

| Case | Red |
|---|---|
| `a change` › `is saved shortly after, under the state directory, for the working directory` | `Left: nil` |
| `a change` › `that empties the buffer empties the draft at once` | `Left: "Refactor the parser"` |
| `the draft` › `is restored into an empty buffer handed over the first time` | `Left: { "" }` |
| `the draft` › `is not restored into a buffer that holds text` | `Left: { "Refactor the parser" }` |
| `the draft` › `is not restored into a buffer handed over again, emptied by a change` | `Left: { "Another editor wrote this" }` |
| `the draft` › `is restored into a buffer handed over again once :bdelete dropped its text` | `Left: { "" }` |
| `quitting` › `saves a change the delay has not saved yet` | `Left: nil` |
| `quitting` › `after a restore writes nothing` | `Left: "Refactor the parser\n"` |
| `a change` › `is saved to a file only its owner can read and write` | `Left: 420`, `Right: 384` |
| `a change` › `whose write fails after truncating leaves the previous draft` | first `Left: "Rename the lexer\n"`: the injected writes were not used yet. Then, with the writes routed through the dependency straight onto the draft, `Left: ""`: the torn draft, the intended red |
| `a change` › `to a draft that is a symbolic link is saved in the file it leads to, the link kept` | `Left: ""` |
| `a change` › `is saved though making its directory loses a race with another editor` | `Left: nil`. This came after a refactor under green that routed `mkdir()` through the dependency, tried once |
| `a draft that cannot be read` › `is told once as a warning, restores nothing and raises nothing` | `Left: {}` |
| `a draft that cannot be read` › `once opened is told as a warning and restores nothing` | `Left: {}` |
| `a draft that cannot be written` › `is told once as a warning and raises nothing into the typing` | first the read path's `ENOTDIR` warning, a fault in the case's arrangement: it made `drafts` a file before the hand-off. Moved after it, `Left: {}`, the intended red |
| `quitting` › `is watched once for a buffer handed over again once :bdelete dropped its text` | `Left: 2`, `Right: 1` |
| `:Aineo open` › `restores the draft into Input` | `Left: { "" }` |
| `the first \i, \r or \c` › `restores the draft into Input as it opens the layout` + `i`, `r`, `c` | `Left: { "" }`, each of the three |

Unit 2's expectations changed once, while green, when the file format was fixed at unit 3: each line ends in a newline, as `writefile()` writes it. Unit 1's expected text changed with it.

**Arrived green: 14 cases**

The brief asked for one test seen red first for each of ID1–ID7. ID4's test and ID6's two arrived green instead, and the packet's records did not say so (the records review of PR #46, finding 5):
- ID6's were spent by units 8 and 11, which the slicing put first;
- ID4's was spent by unit 2 and by unit 18's hand-off in `open()`.

Each is held by a killing mutant: M1, M3, M4 and M20 for ID6; M7, M8 and P1 for ID4.


Each has its killer, run against the final tree:
- `quitting` › `after the delay has saved the change writes nothing`: spent by unit 8's pending flag. Killed by M1.
- `quitting` › `once :bdelete dropped the text keeps the saved draft`: green by the choice of `BufUnload`, which an unloaded buffer never gets again at quit. Killed by M2.
- `quitting` › `with a change pending writes the draft alone`: spent by unit 11's rename. Killed by M6.
- `two editors in one working directory` › `share one draft, the last change winning though the older editor quits last`: spent by unit 8. Killed by M1 and M3.
- `two editors in one working directory` › `never write through the same file`: spent by unit 11's per-pid name. Killed by M4 and M20.
- `a draft that cannot be written` › `with a change pending lets an editor with a screen quit at once`: spent by unit 16's `pcall`. Killed by M5.
  - Its first form quit a headless child and asserted exit 0. M5 **survived** it: a headless Neovim exits 0 even when an exit handler raises.
  - The form kept runs the editor with a UI (`entry_editor`), where `getout()` holds at a hit-enter prompt after an error. There M5 gives `{ -1 }`.
- `:Aineo send` › `from another window empties the draft with Input, at once`: spent by unit 2 and the hand-off in `open()`. Killed by M7 and M8.
- `after a Send` › `\o, \i, \r or \c restores nothing, …` + `o`, `i`, `r`, `c`: spent by unit 5's `kept` guard, and by `focus()` handing over only when it opened. M9 kills `o` alone. P3, M9 with the focus guard removed too, kills all four.
- `:Aineo open` › `after Input was wiped brings its text back in the new Input`: spent by units 3 and 18. Killed by P4.
- `:Aineo open` › `with a draft it cannot read opens the layout and warns once, reporting no error`: spent by unit 15. Killed by P5.
- `a bare interactive start` › `restores the draft into the Input it opens`: spent by unit 18. Killed by P1.

## Mutants

Every mutant is its literal edit, applied from a pristine copy and run alone against the branch's final tree of the packet (`e0929f0`): M1–M14, then M15–M21, in two batches (`t14-home-mutants-1.txt`, `t14-home-mutants-2.txt`), and M2–M6, M8, P1–P5, S1 and S2 re-run there after first runs on earlier trees (`.claude/local/orchestrator/t14-final-mutants.py`). Every kill below is an assertion (`Left`/`Right`, `Failed expectation`) unless it says otherwise. Mutants of `lua/aineo/draft/init.lua` ran against `tests/test_draft.lua` (22 cases, about 6 s), and M7 and M9 against `tests/test_entry_draft.lua` too. M8, P3's first edit, P4 and P5 also edit `lua/aineo/draft/init.lua`, and ran against `tests/test_entry_draft.lua` alone, as did the `plugin/aineo.lua` edits of P1–P3; the fix round re-ran M8, P3's first edit, P4 and P5 against `tests/test_draft.lua` too (*Fix round*). S1 and S2 ran against `tests/test_plugin.lua`. The output names every killing case, so each kill is attributed by name rather than by a narrowed group. M17 is the exception: see its row. (Corrected in the fix round: this paragraph said the home's mutants ran in one batch and that every home mutant ran against `tests/test_draft.lua`, which the records review of PR #46 showed false for M8, P3's first edit, P4 and P5.)

| # | Literal edit | Result |
|---|---|---|
| M1 | `watch.pending = false` removed before `save(draft_of(buffer))` in `save_pending_change` | killed: `quitting` › `after the delay has saved…`, `two editors` › `share one draft…` |
| M2 | the buffer-local `BufUnload` handler replaced by a `VimLeavePre` one, not buffer-local, whose callback is `save(draft_of(buffer))` | killed: `is watched once…` (`Left: 0`), `after a restore…`, `after the delay has saved…`, `once :bdelete dropped the text…` (`Left: "\n"`), `two editors` › `share one draft…` |
| M3 | the `BufUnload` callback `save_pending_change(buffer, watch)` → `save(draft_of(buffer))` | killed: `after a restore…`, `after the delay has saved…`, `two editors` › `share one draft…` |
| M4 | `('%s.%d.cut'):format(target, vim.uv.os_getpid())` → `target .. '.cut'` | killed: `never write through the same file` (`Failed expectation for *no* equality`) |
| M5 | `local saved, failure = pcall(write_draft, text)` → `local saved, failure = true, write_draft(text)` | killed: `raises nothing into the typing` (`Left: false`) and `lets an editor with a screen quit at once` (`Left: { -1 }`) |
| M6 | `vim.uv.fs_rename(cut, target)` → `vim.uv.fs_copyfile(cut, target)` | killed: `with a change pending writes the draft alone` |
| M7 | the `is_empty` branch of `take_in_change` removed (the emptying waits for the delay) | killed: `that empties the buffer empties the draft at once`; against the entry file, `:Aineo send` › `from another window…` (`Left: "hello\n"`) |
| M8 | `nvim_buf_attach`'s `on_lines` replaced by a buffer-local `TextChanged`/`TextChangedI` autocommand calling `take_in_change`, the attach keeping only `on_detach` | killed: `:Aineo send` › `from another window…` (`Left: "hello\n"`) |
| M9 | `if kept[buffer] then return end` removed from `keep_draft` | killed: `the draft` › `is not restored into a buffer handed over again…`; against the entry file, `after a Send` + `o` |
| M10 | `on_detach = function() kept[buffer] = nil end` → `on_detach = function() end` | killed: `is restored into a buffer handed over again once :bdelete…` |
| M11 | `if is_empty(buffer) then restore_draft(buffer) end` → `restore_draft(buffer)` | killed: `is not restored into a buffer that holds text` |
| M12 | `OWNER_ONLY = tonumber('600', 8)` → `tonumber('644', 8)` | killed: `is saved to a file only its owner can read and write` |
| M13 | `local target = vim.uv.fs_realpath(file) or file` → `local target = file` | killed: `to a draft that is a symbolic link…` |
| M14 | `local tries_left = #vim.split(directory, '/', { trimempty = true })` → `local tries_left = 0` | killed: `is saved though making its directory loses a race…` |
| M15 | the restore moved after `nvim_buf_attach` (a restore counted as a change) | killed: `quitting` › `after a restore writes nothing` |
| M16 | `if warned[kind] then return end` removed | killed: both `told once` cases |
| M17 | `if open_error == 'ENOENT' then return nil end` removed (a missing draft warns) | **against the whole file: a hang.** A child whose `vim.notify` is not captured is held at a prompt, and the run was stopped by its pid. **Against a copy narrowed to `a draft that cannot be written` › `…raises nothing into the typing`:** killed, `Cause: … left = "aineo: cannot read Input's draft in …"`. The narrowed group's other case, the screen quit, hangs the same way |
| M18 | the `if not draft then error(…read_failure…) end` branch removed | killed: `once opened is told as a warning and restores nothing` (`Left: {}`) |
| M19 | `vim.api.nvim_clear_autocmds({ group = group, buffer = buffer })` removed | killed: `is watched once…` (`Left: 2`) |
| M20 | `local cut = ('%s.%d.cut'):format(…)` → `local cut = target` | killed: `whose write fails after truncating…` (`Left: ""`), `never write through the same file` |
| M21 | `make_directory_racing(…) or replace_file(…)` → the mkdir's failure ignored, only `replace_file`'s kept | killed: `is told once as a warning and raises nothing into the typing` (the message differs) |
| P1 | `keep_input_draft()` removed from `open()` | killed: 5 cases of `tests/test_entry_draft.lua` (`restores the draft into Input`, `with a draft it cannot read…`, `after Input was wiped…`, `:Aineo send` › `from another window…` (`Left: nil`), `a bare interactive start`) |
| P2 | `if opened then keep_input_draft() end` removed from `focus()` (the hand-off only in `open()`) | killed: the three `the first \i, \r or \c` cases |
| P3 | M9 together with `if opened then keep_input_draft() end` → `keep_input_draft()` | killed: all four `after a Send` cases |
| P4 | `if is_empty(buffer) then restore_draft(buffer) end` → restored only once per editor (`and not environment.restored_once`, then set) | killed: `after Input was wiped brings its text back…` (`Left: { "" }`) |
| P5 | `local read, draft = pcall(read_draft)` → `local read, draft = true, read_draft()` | killed: `with a draft it cannot read opens the layout and warns once, reporting no error` (an `ERROR` notification from `run()` in place of the `WARN`) |
| S1 (ID8) | `require('aineo.draft')` added after `vim.g.loaded_aineo = true` | killed by the frozen `tests/test_plugin.lua`: `is sourced at startup and loads no aineo module` (`Left: { "aineo.draft" }`), `loads the configuration alone in a headless start` |
| S2 (ID8) | `vim.api.nvim_create_autocmd('VimLeavePre', { group = vim.api.nvim_create_augroup('aineo.draft', {}), callback = function() end })` added at the same place | killed by the frozen `defines :Aineo, …, the StdinReadPost autocommand alone` (`left = "aineo.draft VimLeavePre"`) |

**Survivor, not run by the packet** (this line said "Equivalent, not run"; the author's report said "measured"; both were false): the draft's environment taken with its own `stdpath('state')` and `getcwd()` in place of `kept_places()` (`plugin/aineo.lua`, E1 in the reviews). No case moved the working directory between the Reports' environment, taken in `arrangement()`, and the hand-off after `layout.open()`. A handler that runs `:cd` while the layout opens separates them: the test-integrity review built one on `BufWinEnter`, the records review one on `WinNew`, and each killed the mutant by assertion. The fix round adopted the first as `:Aineo open` › `keeps the draft for the Reports' working directory though a :cd runs as the layout opens`, which kills E1 (*Fix round*).

## Fix round

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`), a fresh agent taking over from the packet's author. **Reviews worked:** attack F1–F7, test-integrity I1–I8, records R1–R14 of PR #46 at `e0929f0`, and the orchestrator's fourteen decisions on them. The boundary was widened once, by decision 9: the `Makefile`'s start of a run.

**What changed**
- **F1, a write cut short.** `aineo.draft.Files` reaches the descriptor level (`open_file`, `write`, `close`, `make_directory`), so a test injects a short write and a failed close. `write_file` returns `wrote N of M bytes` or the close's failure, and `replace_file` removes the cut file. The attack's measured fix.
- **F2 and R1, an Input that is not `'modifiable'`** (`nvim -M`). The restore runs under `pcall` and fails into the read warning (`cannot put Input's draft in <file> into Input: Buffer is not 'modifiable'`); Input stays kept. The error is `nvim_buf_set_lines()`'s, not E21.
- **I1 and F7, text dropped while Input's window stays** (`:bdelete` with the layout open, `:edit!`). A buffer-local `BufWinEnter` hands the buffer over again the next time a window shows it; the draft comes back (ID3) and later typing is saved. The attack's `on_detach` reschedule was measured and rejected: after `:bdelete` its callback runs before the layout puts Input back into its window, so it found Input unloaded and the integrity's entry pin stayed red (`draft_after_typing = "Refactor the parser\n"`). `focus()`'s `opened` flag stays; its docstring now says "reopened the role's window".
- **F5, `u` after a restore.** The restore runs with `'undolevels'` at -1 and puts the buffer's value back.
- **F4, the quit save skipped by an earlier handler.** A `QuitPre` save, in `aineo.draft`, created at the first `keep_draft()` (ID8 holds: S1 and S2 still killed). It is quiet; a failure leaves the change pending for the `BufUnload` save, which retries and warns. `QuitPre` fires for `:q`, `:qa`, `:qa!`, `:wqa`, `:xa`, `:x`, `ZZ` and `ZQ`, and not for `:cquit` (`t14f-quitpre.sh`, 0.12.5 and 0.11.6).
- **F6, a warning that took a typed key.** In Insert or Replace mode `warn_once` waits for `InsertLeave`.
- **F3, a signal.** No code fix: the help, *Limits* and the PR body now say that a Neovim ended by a signal saves nothing at quit.
- **I2, a draft leaking between runs.** `make test` and `make test_file` remove `.tests/state/nvim/aineo/drafts` before the runner starts.
- **The help** (`*aineo-draft*`): the heading split onto two lines (R4; all 14 `~` headings now captured as `markup.heading.4` on both versions, with the records review's `records46-heading2.lua`), the restore after `:edit!`/`:bdelete`, the undo, the `QuitPre`/`:cquit` account, the signal, and the warning deferred in Insert mode.
- **Records:** R2 (the survivor), R3 (the readings), R5 (ID4 and ID6 arrived green), R6 (which file each mutant ran against), R8 (the task line), R9 (PR #47), the NUL item (false: NUL round-trips), the E21 name, F3 and F4 in *Limits*, and R10 and R11 in the docstrings. Commit messages name `ad638c3`'s "a Lua error does not" (holds only for a typed quit) and `2df010d`'s quote of C6 (the words are the help's `*aineo-report*`, not C6) as wrong.

**Unit list of the round**, in the orchestrator's order: F1 (short write; failed close; no cut file left), F2 (warn and raise nothing; stay kept; `-M` through `:Aineo open`), I1/F7 (`:edit!`; `:bdelete` with the layout open, then `\i`; a wipe), F5 (no undo of the restore; later changes still undoable), F4 (a Lua quit with an earlier failing `BufUnload`; a `:bdelete` of a pending change, for N1), the pins (I3–I7), I2 (the runner), F6 (the Insert-mode warning), then the records.

**Seen red: 11 new cases**, each on its assertion, in the loop, before its fix:

| Case | Red |
|---|---|
| `a change` › `whose write is cut short leaves the previous draft and warns how much was written` | `draft`: `left = "Renam"` |
| `a change` › `whose file fails to close leaves the previous draft` | `Left: "Rename the lexer\n"` |
| `a change` › `whose write is cut short leaves no file beside the draft` | the list held `….txt.<pid>.cut` |
| `a buffer that is not modifiable` › `is told once as a warning that the draft cannot be put in, and raises nothing` | `Left: false` |
| `a buffer that is not modifiable` › `is kept, so a change once it is made modifiable is saved` | `Left: "Refactor the parser\n"` |
| `:Aineo open` › `in a Neovim started with -M opens the layout and warns once, reporting no error` (on `e0929f0`'s home) | `level`: `left = 4, right = 3` |
| `the draft` › `is restored once :edit! dropped the text, and a later change is saved` | `input_after_edit = { "" }`, `draft = "Refactor the parser\n"` |
| `:bdelete of Input` › `while the layout is open brings the draft back and keeps what is typed after it` | `draft_after_typing = "Refactor the parser\n"`, `input_after_focus = { "" }`; red again under the `on_detach` reschedule |
| `the draft` › `put into a buffer is not taken out again by an undo` | `draft = ""`, `input = { "" }` |
| `quitting` › `from Lua saves a change the delay has not saved yet though an earlier BufUnload handler fails` | `Left: nil` |
| `a draft that cannot be written` › `is told once Insert mode is left, not while typing` | `while_typing` held the warning |

**Red on `e0929f0`, on both versions:** the two draft test files of the round's final tree, run against `e0929f0`'s `lua/aineo/draft/init.lua`, fail 12 cases of `tests/test_draft.lua` and 2 of `tests/test_entry_draft.lua` on 0.12.5 and on 0.11.6, each by assertion (`Failed expectation`, 14 of 14). They are the 11 above, and three existing cases whose arrangement moved to the new `Files` seam or the new autocommand: `whose write fails after truncating…`, `is watched once…` and `never write through the same file`.

**Arrived green: 7 new cases**, each killed by assertion by the mutant named:
- `a change` › `to text whose first line is blank is saved` and `the draft` › `is not restored into a buffer whose first line is blank but holds text`: the integrity's `probe_blank.lua`; N6.
- `a change` › `not saved yet is saved when :bdelete drops the text`: the pin of the `BufUnload` save; N1. Needed because `QuitPre` now saves at quit too, so the quit cases no longer separate N1.
- `the draft` › `put into a buffer leaves the changes made after it undoable`: F5b.
- `the draft` › `lets the buffer be wiped, and raises nothing then`: F7b. Its first form asserted `v:errmsg` only, and F7b killed it by a crash (`E517`); the form kept asserts the wipe itself.
- `a draft that cannot be written` › `with a change pending is told as a warning as Neovim quits`: F4b and N1.
- `:Aineo open` › `keeps the draft for the Reports' working directory though a :cd runs as the layout opens`: the integrity's `probe_places.lua`; E1.

**Existing cases the round changed:**
- `quit()` and `change_input_and_quit()` expect `jobwait` to give `{ 0 }` (I4): N10 now killed by `after a restore writes nothing` and `share one draft…` (`Left: { -1 }`).
- `whose write fails after truncating…` asserts its write was tried (I5): V1 now kills it by assertion (`Left: false`).
- `never write through the same file` asserts both editors wrote. A first form, `no_eq(path, nil)`, passed with one writer, since `child.lua_get` gives `vim.NIL` for a missing value; the form kept fails the test mutant that drops the second editor's change (`Left: { "string", "userdata" }`).
- `with a change pending lets an editor with a screen quit at once` is now `…tries the save at quit and lets an editor with a screen quit at once` (I3): it asserts the save was tried, through a counting `make_directory`. Decision 7 expected it red under N1; with `QuitPre` in place it is not (`QuitPre` tries the save too), so N1 is pinned by the `:bdelete` case above. It still kills M5 and the attack's X5′.
- `is watched once…` asserts the buffer's autocommands are one `BufUnload` and one `BufWinEnter`.

**Mutants of the round**, each its literal edit, applied from a pristine copy of the committed tree and run alone on 0.12.5 — the TD rows and the whole-suite runs on `90ef9b3`, the TE rows on `4e18291` or `322e389`, whose `lua/`, `plugin/` and `tests/test_entry_draft.lua` are identical to `90ef9b3`'s — against `tests/test_draft.lua` (TD) or `tests/test_entry_draft.lua` (TE), or a copy narrowed to the groups named; the runner is `.claude/local/orchestrator/t14f-mutants.py`. Every kill is an assertion unless the row says otherwise.

| # | Literal edit | Against | Result |
|---|---|---|---|
| N1 | the buffer-local `BufUnload` autocommand deleted | TD | killed, 3: `not saved yet is saved when :bdelete drops the text` (`Left: nil`), `is watched once…`, `told as a warning as Neovim quits` |
| N2 | `if opened then keep_input_draft() end` → `keep_input_draft()` | TE; the whole suite | **survives both.** Equivalent on every state where Input's window stays: text dropped while it stays is re-kept at `BufWinEnter` before any `\i`, `\r` or `\c` can run, and a focus that finds the window gone sets `opened` |
| N3 | `SAVE_DELAY_MS = 1000` → `4000` | TD; the whole suite | **survives both**, accepted (decision 10): the save is waited for up to 5 s |
| N6 | `is_empty` without its `nvim_buf_line_count(buffer) == 1 and` | TD | killed, 2: the blank-first-line cases |
| N10 | `vim.bo[buffer].buftype = 'acwrite'` after the restore | TD | killed, 2: `after a restore writes nothing`, `share one draft…` (`Left: { -1 }`) |
| E1 | `set_draft_environment(kept_places())` → `set_draft_environment({ state_directory = vim.fn.stdpath('state'), working_directory = vim.fn.getcwd() })` | TE | killed: the `:cd` case (`draft = nil`) |
| V1 | the `vim.defer_fn(…)` block of `take_in_change` deleted | TD | killed, 15; 14 by assertion, `is saved to a file only its owner…` by a crash (`fs_stat` of a missing file), as the integrity measured |
| X5′ | `save_pending_changes_before_quit`'s body → `save_pending_change(buffer, watch)` (it warns) | TD, the screen case | killed (`Left: { -1 }`) |
| X6′ | the `BufWinEnter` re-keep deleted and `on_reload = function() end` added to the attach | TD; TE, `:bdelete of Input` | killed: `:edit!` case, `is watched once…`; the entry `:bdelete` case |
| F1a | the `written < #text` check deleted | TD, `cut short` | killed (`draft = "Renam"`) |
| F1b | the `if not closed then return close_failure end` deleted | TD, `fails to close` | killed |
| F1c | `vim.uv.fs_unlink(cut)` deleted | TD, `cut short` | killed: `…leaves no file beside the draft` |
| F2 | `pcall(vim.api.nvim_buf_set_lines, …)` → `true, vim.api.nvim_buf_set_lines(…)` | TD, `not modifiable`; TE, `-M` | killed, 2; the `-M` case (`level` 4) |
| F5a | `vim.bo[buffer].undolevels = -1` deleted | TD, `undo` | killed (`draft = ""`) |
| F5b | `vim.bo[buffer].undolevels = undolevels` deleted | TD, `undo` | killed (`Left: { "Rename the lexer" }`) |
| F4 | the `QuitPre` autocommand deleted | TD, `quitting` | killed: `from Lua saves…` (`Left: nil`) |
| F4b | `QuitPre`'s save clears `pending` even when it failed | TD, `a draft that cannot be written` | killed: `told as a warning as Neovim quits` (`Left: nil`) |
| F6 | the Insert-mode branch of `warn_once` made `if false then` | TD, `Insert mode` | killed |
| F7 | the `BufWinEnter` re-keep deleted | TD, `the draft` and `watched once`; TE, `:bdelete of Input` | killed, 2; the entry `:bdelete` case |
| F7b | the `BufWinEnter` re-keep made global (its `buffer = buffer` deleted) | TD, `wiped` | killed (`wiped = false`) |
| M8 | `on_lines` → a buffer-local `TextChanged`/`TextChangedI` autocommand (R6) | TD | killed, 8 (the quit and `:bdelete` cases, and `empties the draft at once`) |
| P3, first edit | `if kept[buffer] then return end` deleted (R6) | TD | killed: `is not restored into a buffer handed over again, emptied by a change` |
| P4 | the restore only once per editor (R6) | TD | killed, 2: `:bdelete` and `:edit!` restores |
| P5 | `pcall(read_draft)` → `true, read_draft()` (R6) | TD | killed, 2, **by a crash**: the read cases raise in their arrangement; TE kills it by assertion (below) |
| — | test mutant: `never write through the same file` without the second editor's change | the case | killed (`Left: { "string", "userdata" }`) |

**The packet's own mutants re-run on this tree** (M1–M21, M7e, P1–P5, S1, S2; the author's literal edits, from `t14-home-mutants.py` and `t14-final-mutants.py`): every one killed by assertion. Changes from the packet's table: M2 now also dies by `not saved yet is saved when :bdelete…`; M5 also by the cut-short, Insert-mode and quit-warning cases; M10 also by the `:edit!` case; M11 also by the blank-first-line case; M20 also by the cut-short and close cases; M21 by three cases; P1 by 8 entry cases; P3 still needs both edits for the `\i`, `\r`, `\c` cases (M9 alone kills `\o`); P4 also by the entry `:bdelete` case. M17 was run narrowed to `…raises nothing into the typing` only.

**Limits recorded by the round:** see *Limits* (the signal, `:cquit`, the startup prompt, a draft left mid-run, N3).

**Suites of the round** are in *Verification of the fix round* below.

## Decisions & reasoning

- **The quit hook is the buffer-local `BufUnload`, not `VimLeavePre`.**
  - Measured with `.claude/local/orchestrator/t14-probe/unload.lua` on 0.12.5 and 0.11.6:
    - `BufUnload` fires, with the buffer still loaded and its lines readable, before `VimLeavePre` at `:qa!`.
    - At `:bdelete`, `on_detach` fires first, then `BufUnload`, with the lines still readable.
    - A Vimscript `throw` in an earlier `BufUnload` or `BufWinLeave` handler skipped both the draft's save and `VimLeavePre`. A Lua error in an earlier `BufUnload` handler skipped nothing — for a quit typed at top level, as this probe's `-c` ran it. The attack review of PR #46 (F4) measured that a quit run from Lua (`vim.cmd('qa!')`) is skipped by a Lua error too; the fix round added a `QuitPre` save before it.
  - So aineo's own `VimLeavePre` stop, of up to 11.8 s, never runs before the save, and the order of `VimLeavePre` handlers does not matter.
  - The same handler saves a pending change when `:bdelete` or a wipe drops Input's text.
  - The limit is in the help: a `BufWinLeave` handler, or a `BufUnload` handler run before aineo's, that throws. Since the fix round it holds for `:cquit` alone, which fires no `QuitPre`.
- **The delay is 1000 ms, one delayed save per change.** That saves every change within a second, so a crash loses at most that last second. No throttle: it would only cut the number of writes during continuous typing, and only a timing-dependent count could tell the two apart (YAGNI).
- **The draft file is text, each line ending in a newline** (`writefile()`'s format), and empty once Input is empty. The empty file is what Send leaves.
- **The file writes are a declared dependency, `aineo.draft.Files`, as plain dependency inversion** (since the fix round at the descriptor level: `open_file`, `write`, `close`, `make_directory`, so that a short write and a failed close can be injected). A torn write is red only through an injected failure (ID5). `make_directory` is in the dependency too, so that the retry is red through an injected race.
- **`mkdir()`'s `Vim:` framing is dropped** from the warning, as the entry point drops it from its error lines.

## Verification

Measured on the branch's final tree:
- **0.12.5 (the host's):**
  - `make test`: 842 cases, `Fails (0)`. That is 808 at the base plus 22 in `tests/test_draft.lua` and 12 in `tests/test_entry_draft.lua`.
  - `make lint`: StyLua clean; selene 0 errors, 0 warnings.
- **0.11.6** (`env PATH=<builds>/nvim-0.11.6/…/bin:… make test`): 842 cases, `Fails (0)`.
- `tests/test_draft.lua` was also run alone on 0.11.6 after the home's commit: `Fails (0)`. This includes the libuv text `file already exists` in `E739`.
- The deep-require check prints only lines from before this packet, each inside its own home.
- **The help's merge check** against the open branches that edit it:
  - `git merge-tree --write-tree` of `2df010d` with `origin/feature/t11-report-icon` at `e1a5bea` exited 0, listed no conflict, and gave tree `7e8b39a4`.
  - That tree's `doc/aineo.txt` passed `tests/test_doc.lua` on 0.12.5 and on 0.11.6, `Fails (0)` each.
  - The help was then checked out from `HEAD` again, and passes `test_doc.lua` on both versions.
  - `origin/feature/t12-claude-numbers` does not exist.

### Verification of the fix round

Measured on the round's tested tree (`90ef9b3`; the records commit after it touches only this note):
- **`make test`, 0.12.5:** 860 cases, `Fails (0) and Notes (0)`, exit 0. That is 808 at the base, 37 in `tests/test_draft.lua` and 15 in `tests/test_entry_draft.lua`.
- **`make test`, 0.11.6** (`NVIM v0.11.6`, `env PATH=<builds>/nvim-0.11.6/…/bin:… make test`): 860 cases, `Fails (0) and Notes (0)`, exit 0.
- Both runs used `AINEO_TEST_RUN_LIMIT_MS=2700000`: the host's load average stood between 150 and 270 throughout.
- **`make lint`:** StyLua clean; selene 0 errors, 0 warnings.
- **Deep-require check:** it prints only lines from before this PR, each inside its own home.
- **The help:** `tests/test_doc.lua` 36 cases, `Fails (0)`, on both versions; its 14 `~` headings are all captured as `markup.heading.4` on both (`records46-heading2.lua`).
- **The merge check** with `origin/feature/t11-report-icon` (`b8ef398`): see the PR body; clean, and its merged `doc/aineo.txt` passes `tests/test_doc.lua` on both versions.
- **A trap met on the way:** the first `make test_file` in a fresh worktree failed one case by a notification Neovim gives when `.tests/state/nvim/` does not exist yet (`log: … not accessible`); the second run was green. Not this round's to fix.

## Readings for the MVP review

**The orchestrator's readings of D17**, MR105–MR108 of [[Review/2026-09-24 — v1 MVP readings review]]:
- MR105 (ID1): an Input that becomes empty empties the draft at once. Kept by the user on 2026-09-26.
- MR106 (ID2): at quit, a pending change only, and a restore is not a change. Kept on 2026-09-26.
- MR107 (ID3): the draft is restored only into a new or emptied Input: the first open, or after a wipe or `:bdelete`. Kept on 2026-09-26.
- MR108 (ID5): the three patterns are copied from `lua/aineo/report/records.lua`, not imported. Open, not yet shown to the user.

**The implementer's own, for the user to confirm** (not yet numbered):
- The save delay, 1000 ms, one delayed save per change.
- The draft's file layout: `<state>/aineo/drafts/<sha256>.txt`, lines each ending in a newline.
- The quit hook, `BufUnload` on Input.
- `mkdir()`'s `Vim:` dropped from the warning.
- From the fix round: the draft is restored after `:edit!` and after `:bdelete` of Input, as soon as Input is shown again, with no hand-off from `\o` or `:Aineo open` (decision 3 of the round).
- From the fix round: the restore is not the user's edit, so `u` does not take it out (decision 4 of the round).
- From the fix round: a pending change is saved at `QuitPre` as well as at Input's `BufUnload` (decision 5 of the round).

## Task lines

This wave holds its marks. The line to mark:
- `| T14 | Input keeps unsent text as a draft (D17): saved per working directory beside the Reports shortly after each change and at quit, restored into an empty Input when aineo opens there, cleared with Input when Send clears it | T8 | done — PR #46, wave 6 |` The draft home is C11, `lua/aineo/draft/`. It saves 1 s after each change, empties at once, saves a pending change at `QuitPre` and at Input's `BufUnload`, and restores only into a new or emptied Input.

## Limits

- **An earlier handler can skip the quit save, for `:cquit` alone.** Since the fix round a pending change is saved at `QuitPre` (`:quit`, `:qall`, `:wqall`, `:xall`, `ZZ`, `ZQ`; measured on 0.12.5 and 0.11.6) and again at Input's `BufUnload` when that save failed. `:cquit` fires no `QuitPre`, so it has only the `BufUnload` save, which an earlier `BufWinLeave` or `BufUnload` handler can skip: a Vimscript `throw`, or any error when the quit runs from Lua (the attack review of PR #46, F4). The draft then holds what the delayed save kept. The help says so. (Before the fix round this line said a Lua error does not skip the save; that held only for a typed quit.)
- **A Neovim ended by a signal saves nothing at quit.** Its terminal window closed, `kill`, a killed TUI client: Neovim drops Input's lines before any autocommand can read them (the attack review of PR #46, F3). Like a crash, it loses at most the last second's typing. The help says so. (This line said a NUL byte comes back as a line break; that was false: NUL round-trips, measured by the attack review.)
- **An unreadable draft prompts at startup.** Its one warning names the draft's path twice and spans more than one screen line, so the autostart holds at a hit-enter prompt until a key. It fires only for a draft that exists and cannot be read. (This line said a restore is undoable; since the fix round it is not.)
- **A draft for every working directory is kept, never removed.** An emptied Input leaves an empty file, as the Reports leave theirs.
- **A case that fails mid-run can leave a draft for a later case of the same run.** `make test` and `make test_file` empty the suites' shared `drafts` directory at the start of each run, not between cases; a plugin-level case in another file that opens Input in the checkout's directory can then find it restored.
- **`N3` survives:** a delay of 4000 ms in place of 1000 ms passes, since the save is waited for up to 5 s. A tighter bound would be timing-dependent under load; accepted by the test-integrity review and the orchestrator (decision 10 of the round).

## Open threads

- **A spec conflict, for an `ai/` branch — answered by PR #47 (`ai/modularity-draft-home`),** which adds the two rows. The `modularity` skill's tables (`.claude/skills/modularity/SKILL.md` §1) name the homes and the direction between them, and have no row for `lua/aineo/draft/`. The home requires no aineo home, and `plugin/aineo.lua` may require any home's entry point, so no edge is missing. But the module table needs `lua/aineo/draft/` (C11), and the direction table needs "`aineo.draft` may require no aineo home". `.claude/` is outside this packet.
- **Closed in the fix round: `keep_draft()` on a buffer that is not `'modifiable'`.** Its restore raised `nvim_buf_set_lines()`'s `Buffer is not 'modifiable'` (not "E21", as this line said) out of `open()`, and the autostart recorded `open-failed` under `nvim -M`. It is now a read warning, and the buffer stays kept.
- **For the orchestrator:** `lua/aineo/report/records.lua` writes the Reports with the same unchecked `fs_write` count and `fs_close` result that F1 fixed here.

## Commits

*Recorded after the merge.*
