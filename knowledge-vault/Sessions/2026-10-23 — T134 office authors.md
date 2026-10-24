# 2026-10-23 — T134 office authors

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t134-office-authors-cli` (from `feature/t123-office-authors`) · **Pull request:** into `feature/t123-office-authors` (number recorded after the merge)

A regular packet of the office screensaver (T123; D26 applies): the commands and the health report for the authors of office packs, and a fix to a test that swapped under load.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T134's row in §6, §3 (*The folder*, *Reading a pack*), *Health*, D108, A564, A586.8
- `lua/aineo/office_pack/state_list.lua`, `lua/aineo/office_pack/starter.lua`, `lua/aineo/office/preview.lua`, `lua/aineo/entry/office_authoring.lua`
- `tests/test_office_pack_state_list.lua`, `test_office_pack_start.lua`, `test_office_preview.lua`, `test_entry_office_authors.lua`, `test_entry_office_preview.lua`, `test_health.lua`, `test_claude_permission_hook.lua`

## Task lines

- [X] T134 For authors, and health (D108, A564, A586.8): `:Aineo office states [name]`, `preview [name]`, `new <name>`; the health section
- [X] A586's open thread: `test_claude_permission_hook` "reaches the copy whose start has its token" matches tokens to starts by session id

## What was done

1. **`states`** — `office_pack.describe_states(pack)` (`state_list.lua`) tells a pack in lines: its name, author and `about`; a line for each of the four parents and the 24 states (number, name, and either `draws <activity>: <about>` or `falls back to <state>, which draws <activity>: <about>`, following the vocabulary's chain to the first state the pack maps); then the triggers in the order they are tried (a Lua pattern told as one). The command opens the lines in a read-only scratch window under the others (`entry/office_authoring.lua`); a pack not found is an error and no window opens (the default pack is never listed under another name).
2. **`new`** — `office_pack.start_from_default({ name, folders, into })` (`starter.lua`) copies the default pack's files into `<stdpath('config')>/aineo-office/<name>/`, writes the new name into its `pack.lua`, removes a copy that fails, and refuses a name that is not a pack's name, a name any pack on the folders has (the default among them: a copy named `default` would shadow the pack every pack falls back to), and a folder that exists (left as it is).
3. **`preview`** — `office.preview(pack?)` on `aineo.office` shows the pack (the first the settings name when none is given; one not found is an error, not the default) with the 24 states acted out in turn (`office/preview.lua`): the main agent in the state, the companions a few states need (a subagent arriving, subagents at work, everyone idle for the random life) and the details the pieces show (tasks, web clue, test verdict, report). The state and its number are named on the first row (`preview 3/24 · thinking`), nine seconds each, starting over after the last. It takes the place of the office that shows, follows no transcript, watches no file, closes as the office does. `preview_seconds_per_state` is an office option so the tests run through the states on a clock of their own. The routine that puts text over a picture row moved from `cards.lua` to `text.lua` for it.
4. **The command surface** — one table of words in `plugin/aineo.lua` (`check`, `states`, `preview`, `new`) gives the dispatch and the completion (packs found after `check`, `states`, `preview`; nothing after `new`; `new` needs a name); the usage message and the `desc` name them.
5. **Health** — the Office section lists the packs found on 'runtimepath', each with its folder and problem count, the packs `office.pack` names first, with the command that lists the problems; a warning for a pack `office.pack` names and that is not found, and for each `office.pieces` file that cannot be used, with its line. The check now loads `aineo.office_pack` and `aineo.office_states`.
6. **The test fix** — `start_two_copies` finds each copy's start by the `--session-id` it was given, not by the order the fake recorded the starts.
7. **Help** — `:Aineo-office-states`, `:Aineo-office-preview`, `:Aineo-office-new`, the overview and the packs chapter, and the Office paragraph of the health chapter. The chapters of §4 stay T136's.

## Reported, not chosen

- **The plan's Health paragraph also lists the permission hook in aineo's settings and the Claude Code version.** The brief names the packs found and their problems, so these two are not in the section; the permission hook is already warned of by the Claude section when it cannot be added. They are for a later packet if the user wants them.
- **`new` refuses every name a pack on 'runtimepath' has**, not only an existing folder in the configuration directory (the brief says "refuses an existing folder"): a copy named like a pack that is installed elsewhere would hide it, and a copy named `default` would hide the pack all packs fall back to.
- **`new` leaves `author = 'aineo'`** in the copy, since the art is aineo's; the author edits it.
- **`states` opens a split under the other windows** of the current tab page; the aineo layout is not touched.
- **`preview` takes an office option, `preview_seconds_per_state`,** that no caller but the tests sets.

## Tests

Test first for each unit; the red of each is its missing function or command (assertion failures or the missing-function error, not a crash of the harness).

| File | Cases | Red |
|---|---|---|
| `test_office_pack_state_list` | 9 | 7 of the first 7 (`describe_states` was not there); the case for an author left out was red on `by ` with nothing after it; the case for a Lua pattern trigger arrived green (code written ahead of its test), killed by mutant S3 |
| `test_office_pack_start` | 8 | 8 (`start_from_default` was not there) |
| `test_entry_office_authors` | 12 | 12 (the commands fell through to the usage message); the missing name for `new` was also red on a precedence mistake in the first version of the dispatch, which the case caught |
| `test_office_preview` | 14 | 14 (`preview` was not there) |
| `test_entry_office_preview` | 4 | 4 (the command was not wired) |
| `test_health` | 6 (5 new or changed, the loaded-homes case changed) | 6 |
| `test_claude_permission_hook` | 1 | red when the copies are started in reverse order with the old helper (the wait reached the other copy); green with the new helper in both orders |

## Mutants

Each a literal edit on a pristine copy of the file named, run on the test files that exercise the code it breaks, restored after.

| Mutant | Literal edit | File run | Killed by |
|---|---|---|---|
| S1 `states` missing a fallback line | `state_list.lua`: the loop `for _, state in ipairs(office_states.vocabulary()) do table.insert(lines, state_line(pack, state)) end` guarded by `if pack.states[state.name] then … end` | `test_office_pack_state_list` | 4 cases: the 24-and-4 lines case by an equality on the line's type; the three cases of numbers and fallbacks by indexing the missing line (nil index, crash) |
| P1 `preview` skipping a state | `preview.lua`: `if state.number then` → `if state.number and state.name ~= 'planning' then` | `test_office_preview` | 3 assertions (the order of the 24 states, `on_the_web` where `background_job` is wanted; the wrap-around, `1/23` for `24/24`; the number of scenes, `1/23` for `1/24`) and 1 crash (the scene of the test verdict is not there) |
| N1 `new` overwriting an existing folder | `starter.lua`: `if vim.uv.fs_lstat(directory) then` → `if false then` | `test_office_pack_start` | equality, "refuses a folder that exists" |
| N2 `new` keeping the default's name | `starter.lua`: `lines[index] = ("  name = '%s',"):format(name)` → `lines[index] = line` | `test_office_pack_start` | equality, "gives the copy its own name" |
| N3 `new` taking a name a pack has | `starter.lua`: `if found.name == name then` → `if false then` | `test_office_pack_start` | equality, two cases (a pack elsewhere, `default`) |
| H1 health not counting a broken pack | `health.lua`: `report_office_pack(name, directories[name], is_chosen, #own)` → `…, 0)` | `test_health` | equality, two cases |
| P2 `preview` following the transcript | `office/init.lua`, `start_running`: `if open.preview then` → `if false then` (`function start_running(open)` and the line after it, the only place that string occurs) | `test_office_preview` | 1 assertion, "follows no transcript and watches no file" |

## Fix round (A603, review346)

Each unit test first, seen failing before the change (the cases marked *pin* arrived green and are killed by the mutant named).

1. **Case** — `start_from_default` compares names ignoring case and names the pack found (`Default` is refused where the disk ignores case). Red: `refuses a name that differs from a pack's only in case`.
2. **A failed copy** — the copy runs under `pcall`; a returned failure or a raised error removes the folder and the refusal says why (`cannot make the copy: …`); copied files get mode 0644; a link in the default pack (art or `pack.lua`) is refused with `cannot copy <file>: it is a link, and a pack is made of files`. Red (a raised E482/E484/E17 and a half-made folder): the read-only source, the linked art file, the linked `pack.lua`, the raising `pack.lua`. The docstring says what the code does.
3. **`about` and `author`** — the loader keeps each only when it is text with no control character (`head_text`), else `''`. Red: a number, a line break, a list; the command with a number lists the pack and leaves one buffer, no more. *Pin* (arrived green): plain text is kept.
4. **Preview before closing** — `show_over` takes a `before_opening` step that the preview uses to close the office that shows; a pack that is not found leaves it as it is. Red: `leaves the office that shows as it is when the pack to preview is not found`.
5. **M3 and M5 pinned** — the `office.pieces` health case asserts the default pack's OK line; `counts the idle time again after a preview that could not show` (*pin*, arrived green).
6. **Health once** — each pack is listed and checked once when `office.pack` names it twice. Red: two lines.
7. **Help** — the copy's writable files, the refusals, the removal, the restart for a configuration directory made after startup, and that a failed preview leaves the office that shows.

Finding 7 of the review (a configuration directory that did not exist at startup) is documented, not fixed (A603).

| Mutant | Literal edit | File run | Killed by |
|---|---|---|---|
| M3 | `health.lua`: `is_chosen, #own)` → `is_chosen, #problems)` | `test_health` | 1 assertion, the `office.pieces` case |
| M4 | `starter.lua`: `    vim.fn.delete(directory, 'rf')` → `    local _ = directory` | `test_office_pack_start` | 3 assertions (linked art, linked `pack.lua`, raising copy: a folder remains) |
| M5 | `office/init.lua`: in `office.preview`, `settle()` → `local _ = settle` | `test_office_preview` | 1 assertion (0 waits pending, 1 wanted) |

## Open threads

- The permission hook and Claude Code version lines of the plan's Health paragraph (above).
- The authors' guide chapters (`aineo-office-states`, `-commands`, `-packs` …) and the README sections are T136's.

## Commits

Pull request #351 merged into `feature/t123-office-authors`; that branch reached `dev` through pull request #355. Each commit below is as it stands on `dev` (a rebase merge replays under new hashes).
Released as v0.2.74 (pull request #356, `main` at `2874493e`).

- `ee9981ec` Tell what a pack draws for each state, and its triggers
- `50afba5f` Start a pack of one's own from the default pack
- `f845075c` Add :Aineo office states and :Aineo office new
- `2068c5ca` Move putting text over a picture row to the office's text
- `47d69398` Add :Aineo office preview, a show of every state of a pack
- `4d5804c6` Count the office packs and their problems in the health check
- `c08f109f` Match permission-wait tokens to starts by session id
- `5e57b14b` Document the commands and the health report for pack authors
- `9b4b89b6` Record T134: the plan row and the session note
- `6d11021c` Refuse a case variant of a pack's name, and keep a failed copy tidy
- `34ead136` Keep a pack's about and author only when they are plain text
- `8fcda55f` Check the pack before a preview closes the office that shows
- `ca93fa63` Tell a pack once in health, and pin the pieces case
- `470cf6b1` Document the refusals of `office new` and the failed preview
- `de3bada1` Record the fix round of T134 in its session note
- `221b44f8` Name the shipped packs in the tests of T134 after the merge of T135
