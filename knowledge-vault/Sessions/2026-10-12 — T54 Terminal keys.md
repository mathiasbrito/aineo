# 2026-10-12 — T54 Terminal keys

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t54-terminal-keys` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C1, C7, D58, T54
- Rests on: [[Sessions/2026-10-12 — T50 Worktree filter]] (the head of `dev` this branch starts from)

The orchestrator's rulings this packet is written for are its assumptions under the user's instruction of 2026-10-06, not the user's decisions: **A167** (the setting `terminal_prefix`, default `'<C-\>'`, `false` maps none, read once, a user's own global mapping stays), **A168** (Send has no twin), **A169** (a twin first leaves the mode it was pressed in), **A170** (Neovim's own `<C-\><C-n>` and `<C-\><C-o>` stay unmapped and work; Claude Code is sent none of a twin's keys). The user's request and answers are quoted in D58.

## What was done

Every prefix key whose action makes sense outside Normal mode has a twin: the terminal prefix (`<C-\>` by default) followed by the same letters, mapped globally in Terminal mode and in Insert mode to `<C-\><C-n>` and then the action's `<Plug>` mapping. The twins are `<C-\>o`, `r`, `i`, `c`, `tcn`, `S`, `pa` and `g`.

- `lua/aineo/config/init.lua`: the setting `terminal_prefix` (a non-empty string, or `false`; default `'<C-\>'`), validated as `prefix` is.
- `plugin/aineo.lua`: `map_terminal_prefix()` beside `map_prefix()`, both called by `map_keys()` where the prefix was mapped (the `VimEnter` handler and the late-sourced tick). `map_unless_mapped()` takes the keys typed before the `<Plug>` mapping (`''` for Normal and Visual mode, `LEAVE_MODE` for a twin); `has_global_mapping()` accepts `t` and `i`. `HAS_NO_TWIN` names Send, which acts on a selection or on Normal mode's line (A168); `claim` has no prefix key. Nothing is mapped when `terminal_prefix` is `false`.
- `lua/aineo/health.lua`: a section *Terminal prefix mappings* after *Prefix mappings*: a line per twin and mode (Terminal mode first) — ok when it runs `<C-\><C-n><Plug>(…)`, a warning when it runs something of the user's or nothing — with the same pending lines as the prefix section, one line for `terminal_prefix = false` and one for a wrong configuration. The two sections share `check_key()`.
- `doc/aineo.txt`: the introduction, *aineo-terminal-keys* (the twins, each tagged `aineo-<C-\>i` and so on, Send's absence, Neovim's own `<C-\><C-n>` and `<C-\><C-o>`, the wait for 'timeoutlen' only where a twin is also the start of a longer mapping), *aineo-config-terminal_prefix*, and the health section.

## Decisions

- **The twin's right-hand side is `<C-\><C-n><Plug>(aineo-…)`, not a Lua function.** It is what `:checkhealth` can compare and `maparg()` shows, and Neovim's own keys do the leaving (`:h CTRL-\_CTRL-N`, one for both modes). The `<Plug>` mappings are Normal-mode mappings; `<C-\><C-n>` brings the mode there before they run, and `<C-\>c` enters Terminal mode again as `\c` does (A169). The mapping is not `remap = true`: a user's own mapping of `<C-\><C-n>` does not change what a twin does, and the `<Plug>` is expanded as the `\` keys' is.
- **The health check lists the twins in a section of their own** rather than inside *Prefix mappings*, whose tests pin the position of every line (the leader warnings at line 11). A twin is "beside" the prefix keys by following that section.
- **`check_prefix_key()` now compares what a key runs with `nvim_replace_termcodes()` on both sides**, which a twin's right-hand side needs (`maparg` writes `<C-\><C-N>`). A prefix key mapped to `<plug>(aineo-send)` in other letter case now counts as running aineo's mapping, which it does.
- **The help tags of the twins are `aineo-<C-\>i` and so on**, one for both modes; `tests/test_doc.lua` derives them from the mappings in `t` and `i` (`nvim_get_keymap()` writes `<C-\>` as `<C-Bslash>`, so the test writes it back).

## Unit list

1. the setting `terminal_prefix` (default, kept when `false`, refused when wrong or empty); 2. the twins reach their action from Terminal mode and from Insert mode (the window moved to, the windows restored, the line numbers, the pane, the session list's message); 3. Send has none; 4. `<C-\><C-n>` and `<C-\><C-o>` unaffected; 5. a twin sends Claude Code nothing; 6. the default prefix, a custom one, `false`, a wrong one; 7. a user's own mapping of a twin's keys stays; 8. the health section; 9. the help's tags; 10. `plugin/aineo.lua` defines the twins and nothing else new.

## Red and green

Every case below was seen red for the intended reason before its code.

- `tests/test_config.lua`: 9 of 35 red (the defaults table gained `terminal_prefix`: 5 existing expectations; `false` kept, two wrong values, an empty value: 4 new cases).
- `tests/test_entry_terminal_keys.lua` (new, 76 cases): 51 red when the twins did not exist — the window a twin moves to (5 of 6: `<C-\>c` from Terminal mode stays in Terminal mode in Claude's window with nothing mapped, so that case arrived green by nature), `<C-\>o` (2), `<C-\>tcn` (2), the panes (4), `<C-\>S` (2), the default mapping of each twin in each mode (16), the custom prefix (16), a user's own mapping (3), and "sends Claude Code nothing" (red: `rc` reached Claude's prompt).
- `tests/test_health.lua`: 8 of 100 red, the new section missing.
- `tests/test_doc.lua`: 3 red (the tags `aineo-terminal-keys`, `aineo-<C-\>i`, `aineo-config-terminal_prefix`) and the derived-tags case.
- `tests/test_plugin.lua`: 1 red, then its expected list gained the 16 twins.

Arrived green, and why:

- *Send has no twin* (4 cases, `t`, `i`, `n`, `x`): green by nature of nothing being mapped yet. Killed by mutant 2.
- *`<C-\><C-n>` leaves Terminal mode* and *`<C-\><C-o>` runs one Normal-mode command from Insert mode*, the twins mapped: green by nature, since Neovim's own keys are not mapped by aineo. No mutant of this packet kills them; they pin A170 against a later mapping of `<C-\>` alone, or of a longer sequence that swallows those keys.
- *Maps nothing, and says nothing, when it is false* (16 cases) and *a wrong `terminal_prefix` is told, naming it*: green by nature (the setting existed before the twins were mapped). Killed by mutant 4.
- *The first `<C-\>c` case from Terminal mode*: green by nature (see above); the case "sends Claude Code nothing of its keys" presses `<C-\>c` and `<C-\>r` from Terminal mode and was made to kill a mutant that gives `claude` no twin (mutant 6).

## Mutants

Each is its literal edit in `plugin/aineo.lua`, run one at a time from a copy of the file, restored after, against `tests/test_entry_terminal_keys.lua` (the test file the code is exercised by), on the final tree.

| # | Edit | Result |
|---|---|---|
| 1 | `for _, mode in ipairs({ 't', 'i' }) do` → `for _, mode in ipairs({ 'n' }) do` | killed, 51 assertion failures |
| 2 | `local HAS_NO_TWIN = { send = true }` → `local HAS_NO_TWIN = {}` | killed, 2 (`has no Send among them`, `t` and `i`) |
| 3 | `local LEAVE_MODE = '<C-\\><C-n>'` → `local LEAVE_MODE = ''` | killed, 16 (every twin that must leave the mode; `<C-\>c` from Terminal mode does not fail) |
| 4 | `if terminal_prefix == false then` → `if false then` | killed, 16 assertion failures on "says nothing" (the notification of the Lua error that `false .. key` raises; nothing is mapped, so "maps nothing" itself does not fail) |
| 5 | `if not has_global_mapping(mode, keys) then` → `if true then` in `map_unless_mapped()` | killed, 3 (the user's mapping overwritten) |
| 6 | `local HAS_NO_TWIN = { send = true }` → `local HAS_NO_TWIN = { send = true, claude = true }` | killed by "sends Claude Code nothing of its keys" (`cafter` for `after`), measured on a copy narrowed to that case; it survived the first form of that case, which compared only the letters before `after` |

## Whole suite

`make test` on Neovim 0.12.5 (the host), on the tree pushed after the last edit: 2889 cases in 81 groups, `Fails (0) and Notes (0)`, exit 0. `make lint`: 0 errors, 0 warnings.

## Open threads

- A167 to A170 stand as assumptions until the user confirms them.
- A lone `<C-\>` in Terminal mode followed by a key no twin starts goes to the terminal as before; the help says nothing of it beyond Neovim's own keys.
- A twin in Insert mode leaves the cursor where `<C-\><C-n>` leaves it (Insert mode's cursor is not moved back a column); the actions do not use it.

## Task lines

- T54 `[X]` (`feature/t54-terminal-keys`, into `dev`) — the `<C-\>` twins of the prefix keys in Terminal and Insert mode (C1, C7; D58): `terminal_prefix`, `map_terminal_prefix()`, the health section *Terminal prefix mappings*, the help; the whole suite on Neovim 0.12.5 (host), see the pull request.

## Commits

Recorded after the merge.
