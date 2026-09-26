# 2026-09-26 — T14 Input draft

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t14-input-draft` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D17; C11, C2, C4, C6; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t14-input-draft.md` with the amendment of 2026-09-26, the brief reviews `brief-review-t14-input-draft.md` and `brief-review-t14-amendment.md`, the evidence `nofile-quit.txt` and `baseline-7af0d47.txt`
- [[Review/2026-09-24 — v1 MVP readings review]], where the readings below go

## Context

**Goal:** T14. Input is a `nofile` scratch buffer, and Neovim quits over its text without a word. The user called that "completly undesired behavior" and chose, on 2026-09-25, "Keep it as a draft" (D17): saved per working directory beside the Reports shortly after each change and at quit, restored into an empty Input when aineo opens there, cleared with Input when Send clears it; two editors in one folder share one draft, the last change winning.

## What was done

- **`lua/aineo/draft/init.lua`, a new home (C11).** Its entry point is two functions: `set_draft_environment({ state_directory, working_directory, files? })` and `keep_draft(buffer)`. It requires no aineo home.
  - The draft is `<state>/aineo/drafts/<sha256 of the working directory>.txt`: the buffer's lines, each ending in a newline, and nothing once the buffer is empty.
  - Changes are seen through `nvim_buf_attach`'s `on_lines`. A non-empty change is saved `SAVE_DELAY_MS` (1000 ms) later. A change that empties the buffer empties the draft at once.
  - A change still pending is saved at the buffer's `BufUnload`, and nothing else is written then. A restore happens before the buffer is attached, so it is no change.
  - The draft is restored only into an empty buffer that is not kept already. `on_detach`, which fires when `:bdelete` or a wipe drops the text, ends the keeping.
  - Writes follow three patterns copied from `lua/aineo/report/records.lua`: a temporary file named `<draft>.<pid>.cut`, renamed over the draft and following a symlink through `fs_realpath`; `0600`; and `mkdir()` tried again after a race. The file writes (`write_file`, `make_directory`) are a declared dependency, `aineo.draft.Files`, that no production caller overrides.
  - A failed read or write is a `WARN` starting `aineo: `, once per editor for each. Nothing raises.
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

Every mutant is its literal edit, applied from a pristine copy and run alone against the branch's final tree: M1, M7, M9–M21 in one batch, and M2–M6, M8, P1–P5, S1 and S2 re-run there after first runs on earlier trees (`.claude/local/orchestrator/t14-final-mutants.py`). Every kill below is an assertion (`Left`/`Right`, `Failed expectation`) unless it says otherwise. Mutants of `lua/aineo/draft/init.lua` ran against `tests/test_draft.lua` (22 cases, about 6 s) and mutants of `plugin/aineo.lua` against `tests/test_entry_draft.lua`. Each whole file costs seconds, and the output names every killing case, so each kill is attributed by name rather than by a narrowed group. M17 is the exception: see its row.

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

**Equivalent, not run:** the draft's environment taken with its own `stdpath('state')` and `getcwd()`, in place of `kept_places()`, on a state where no `:cd` runs between the report's environment and the draft's. On that state it is equivalent, because both are taken in the same tick of the first open. `kept_places()` guarantees they stay the same should that ever change.

## Decisions & reasoning

- **The quit hook is the buffer-local `BufUnload`, not `VimLeavePre`.**
  - Measured with `.claude/local/orchestrator/t14-probe/unload.lua` on 0.12.5 and 0.11.6:
    - `BufUnload` fires, with the buffer still loaded and its lines readable, before `VimLeavePre` at `:qa!`.
    - At `:bdelete`, `on_detach` fires first, then `BufUnload`, with the lines still readable.
    - A Vimscript `throw` in an earlier `BufUnload` or `BufWinLeave` handler skipped both the draft's save and `VimLeavePre`. A Lua error in an earlier `BufUnload` handler skipped nothing.
  - So aineo's own `VimLeavePre` stop, of up to 11.8 s, never runs before the save, and the order of `VimLeavePre` handlers does not matter.
  - The same handler saves a pending change when `:bdelete` or a wipe drops Input's text.
  - The limit is in the help: a `BufWinLeave` handler, or a `BufUnload` handler run before aineo's, that throws.
- **The delay is 1000 ms, one delayed save per change.** That saves every change within a second, so a crash loses at most that last second. No throttle: it would only cut the number of writes during continuous typing, and only a timing-dependent count could tell the two apart (YAGNI).
- **The draft file is text, each line ending in a newline** (`writefile()`'s format), and empty once Input is empty. The empty file is what Send leaves.
- **The file writes are a declared dependency, `aineo.draft.Files`, as plain dependency inversion.** A torn write is red only through an injected failure (ID5). `make_directory` is in the dependency too, so that the retry is red through an injected race.
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

## Readings for the MVP review

**The orchestrator's readings of D17, which the user is to confirm:**
- ID1: an Input that becomes empty empties the draft at once.
- ID2: at quit, a pending change only, and a restore is not a change.
- ID3: the draft is restored only into a new or emptied Input: the first open, or after a wipe or `:bdelete`.
- ID5: the three patterns are copied from `lua/aineo/report/records.lua`, not imported. The report home is outside this boundary, and its records are internal to it.

**The implementer's own:**
- The save delay, 1000 ms, one delayed save per change.
- The draft's file layout: `<state>/aineo/drafts/<sha256>.txt`, lines each ending in a newline.
- The quit hook, `BufUnload` on Input.
- `mkdir()`'s `Vim:` dropped from the warning.

## Task lines

This wave holds its marks. The line to mark:
- `T14` — done in PR (this branch). The draft home is C11, `lua/aineo/draft/`. It saves 1 s after each change, empties at once, saves a pending change at `BufUnload`, and restores only into a new or emptied Input.

## Limits

- **An earlier handler can skip the quit save.** A `BufWinLeave` handler, or a `BufUnload` handler run before aineo's, that throws a Vim exception at quit skips the quit save. The draft then holds what the delayed save kept: at most the last second's typing is lost. The help says so.
- **A NUL byte in Input comes back as a line break.** `nvim_buf_get_lines` hands NUL over as `\n`, and the draft joins lines with `\n`, so the restore splits there. Not measured further.
- **A restore is undoable.** `u` in a freshly restored Input takes the restored text out, and then empties the draft at once; `Ctrl-R` brings both back. D20 (wave 7) adds undo after Send and may want to decide this.
- **A draft for every working directory is kept, never removed.** An emptied Input leaves an empty file, as the Reports leave theirs.

## Open threads

- **A spec conflict, for an `ai/` branch.** The `modularity` skill's tables (`.claude/skills/modularity/SKILL.md` §1) name the homes and the direction between them, and have no row for `lua/aineo/draft/`. The home requires no aineo home, and `plugin/aineo.lua` may require any home's entry point, so no edge is missing. But the module table needs `lua/aineo/draft/` (C11), and the direction table needs "`aineo.draft` may require no aineo home". `.claude/` is outside this packet.
- **`keep_draft()` on a buffer the user made `nomodifiable`:** its restore would raise E21 out of `open()`. Not tested, and not guarded.

## Commits

*Recorded after the merge.*
