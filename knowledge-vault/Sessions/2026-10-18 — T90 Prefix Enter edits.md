# 2026-10-18 — T90 Prefix Enter edits

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t90-prefix-enter` · **Pull request:** into `dev`

The aineo prefix followed by Enter (`\<CR>` by default) opens the file under the cursor in the changes pane's files window for edition, as `<S-CR>` does, so that the key works in a terminal with no setup. A small fix in the user's prompt-driven waves (D30).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D83 (the user's words, A465, A466); D82 (`<S-CR>`, A462–A464); C15, C9
- `doc/aineo.txt` — *aineo-changes-edit*

## Task lines

- [X] T90 The prefix followed by Enter, `\<CR>`, opens a listed file for edition in the changes pane's files window, as `<S-CR>` does (D83; C15, C9; A465, A466): the changes home takes an `edit_file_key` setting and maps it beside `<S-CR>` in the files buffer; `entry/tab.lua` hands it `prefix .. '<CR>'` as the session begins, nothing when the prefix is `false`; the help leads with `\<CR>` and adds iTerm2's key mapping for Shift+Return. Done on `feature/t90-prefix-enter`.

## The user's words

"ok the iTerm trick works, but this is to much muscles, we need something that works out of the box maybe <enter>?"

## Design

- **Where the key is known.** The prefix is read from the resolved configuration in `entry/tab.lua`'s `begin_claude()`, which already hands the changes home its session settings. The key goes in as one more setting, `edit_file_key` (a string written as in a mapping), so `aineo.changes` knows no `prefix`: a home that is given none maps nothing. The only change in `entry/` is that one line.
- **The map.** `map_open_file()` in `changes/copy.lua` maps the key beside `<S-CR>` to the same function, `edit_file_at_cursor()`, in the files buffer alone. It reads the setting when the buffer is made; the composition root begins the session before the layout opens the pane, so the setting is there.
- **Free key.** No `PREFIX_KEYS` entry is `<CR>`, and the map is buffer-local, so the global `\` keys are unchanged and a global `\<CR>` of the user's would lose to it in the files window only.
- **Records.** *aineo-changes-edit* leads with `\<CR>`, says it follows *aineo-config-prefix* and is not mapped with the prefix `false`, keeps the tmux paragraph and adds one sentence for iTerm2. The README names neither key.

## Red and green

**Seen red:** `tests/test_changes_edit_file.lua` — `edit_file_key | opens the file as <S-CR> does …` (the buffer stayed `aineo://changes-files`) and `… is the key the settings name, in the files buffer alone` (no map); `tests/test_entry_changes.lua` — `the prefix and Enter | opens the file for edition in the file column, as <S-CR> does` and `… follows the prefix vim.g.aineo names` (the file's window never showed). The two cases that assert no map (`maps nothing when the settings name none`, `maps nothing, <S-CR> staying, when the prefix is false`) pass before and after by nature; each is killed by a mutant below. `<S-CR>`'s own cases are unchanged and stay green.

## Mutants, as literal edits (each on the test file of its group, on Neovim 0.12.5)

| # | File: edit | Killed by |
|---|---|---|
| M1 | `lua/aineo/entry/tab.lua`: `edit_file_key = config.prefix and config.prefix .. '<CR>' or nil,` → `edit_file_key = '\\<CR>',` | `the prefix and Enter | follows the prefix vim.g.aineo names`, `… maps nothing, <S-CR> staying, when the prefix is false` |
| M2 | `lua/aineo/changes/copy.lua`: `if session and session.settings.edit_file_key then` → `if false then` | `edit_file_key | opens the file as <S-CR> does …`, `edit_file_key | is the key the settings name, in the files buffer alone` |

## Verification

- `make test_file` on `tests/test_changes_edit_file.lua` (22 cases), `tests/test_entry_changes.lua` (41) and `tests/test_doc.lua`, each `Fails (0)`, on Neovim 0.12.5 on the host.
- `make lint`: 0 errors, 0 warnings, 0 parse errors.
- The whole suite did not run (D30): the change reaches the changes home's files-buffer maps and one line of the entry's session settings, and no code shared across homes.

## Limits

- A files buffer made before the session begins holds no `\<CR>` (the map is made when the buffer is); the composition root begins the session first, and the case is not pinned.
- A prefix changed after the editor has started is not followed, as the global prefix keys are not (*aineo-config-prefix*).

## Commits

Recorded after the merge.
