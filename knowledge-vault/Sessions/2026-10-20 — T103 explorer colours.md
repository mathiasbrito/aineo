# 2026-10-20 — T103 explorer colours

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t103-explorer-colours` · **Pull request:** into `dev`

The explorer shows in more colours: a changed file's mark and name in the changes pane's group for its kind of change, folders, the `•` of a folder holding a change, and ignored entries dimmed. A small fix of wave 21 under D30.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D93 (the user's request), A519 (the orchestrator's ruling), T103; D92, A515 (the explorer); C12
- `lua/aineo/explorer/tree.lua` — the spans; `lua/aineo/explorer/home.lua` — the extmarks and the groups
- `lua/aineo/changes/init.lua` — `kind_groups`, `define_colours`; `lua/aineo/entry/explorer.lua` — hands them over
- `doc/aineo.txt` — `aineo-explorer`, the `hl-AineoExplorer*` tags

## Task lines

- [X] T103 Explorer colours (C12; D93, A519, D30): the pure renderer returns each entry's colours as spans (`aineo.explorer.Span`: byte columns and a role); the home draws them as extmarks in its namespace; `AineoExplorerFolder`, `AineoExplorerChanged`, `AineoExplorerIgnored` are default links; the changes home's entry point exposes `kind_groups` and `define_colours`, which the composition root hands to the explorer; the help lists each group with a tag.

## What was done

- **The spans** (`tree.lua`): `render()` returns `spans` beside `lines` and `entries`, by line. A span is a byte range and a role: one of the six kinds of change, `folder`, `changed_folder`, `ignored`. A file with a mark has one span from its mark to the end of its line; a folder has its sign, its mark when it has one (its own kind, or `changed_folder` for the `•`) and its name; an ignored entry has one span over the whole line and none for its mark. A line with no colour has no key. The ignored flag is the entry's own, read from the data the tree already holds; git is not run again.
- **The extmarks** (`home.lua`): each span is an `hl_group` extmark with a column range in the explorer's namespace, the group chosen by role from the explorer's own table and the change groups it was handed. The header and the followed line keep their line highlights, drawn after the spans.
- **The groups**: `AineoExplorerFolder` (`Directory`), `AineoExplorerChanged` (`AineoChangesModified`), `AineoExplorerIgnored` (`Comment`) join the two existing groups in the default-link table. The explorer asks for the changes pane's groups to be defined as it is made, so a tab whose changes pane has not written a list yet still shows file colours.
- **The seam**: `aineo.changes` exposes `kind_groups` and `define_colours` (its own `colours` file stays private); `entry/explorer.lua` hands both to `aineo.explorer.new()` as `change_groups` and `define_change_groups`. The explorer still requires no aineo home.
- **The help**: one paragraph on the colours, and a tag for each of the three new groups beside the two existing ones.

## Decisions taken inside the packet

- A role, not a group name, is what the pure renderer returns: the renderer then needs no knowledge of group names, and the home is the one place that maps a role to a group.
- The `•` of a folder is its own role (`changed_folder`) so that `AineoExplorerChanged` can be coloured apart from a file's modified mark.
- A folder with its own mark (an untracked nested repository) shows the mark in the kind's group and the name in the folder's.

## Red and green

Seen red for the intended reason (`spans` absent, `nil` against the expected table): the 8 tests of `tests/test_explorer_tree.lua` *the colours* (one of them parametrised over the six marks), all failing on `nil` spans; `tests/test_entry_explorer.lua` *the colours / show a changed file in its change's group…* (no extmarks).

Arrived green, because the code was written in the unit before the test, each with the mutant that kills it (all run, all assertion kills):

| Test | Killer |
|---|---|
| entry *show an entry git ignores whole in the ignored group…* | M2-home |
| entry *are each linked to its default* | M3b |
| entry *keep a group the user coloured before…* | M4 |
| entry *are each linked to its default again once a colour scheme clears them* | M3b, M4 |
| entry *ask for the groups … to be defined, once…* | M5 (survived the first round of tests; this test was added for it) |

## Mutants

Each run alone, from the file's text kept in memory and restored in the same call, on a copy of the test file narrowed to *the colours*; the failing cases read "Failed expectation for equality" (assertions, not crashes).

| Mutant (literal edit) | File | Killed by |
|---|---|---|
| M1 `is_folder and columns.mark_end or columns.name_end` → `columns.mark_end` (a file's name not coloured) | `tree.lua` | tree *span a changed file's mark and name…*; entry *show a changed file in its change's group…* |
| M2-tree `if entry.ignored then` → `if entry.ignored and false then` (ignored not dimmed) | `tree.lua` | tree *span an entry git ignores whole…* |
| M2-home `ignored = 'AineoExplorerIgnored',` removed from `ROLE_GROUPS` | `home.lua` | entry *show an entry git ignores whole…* |
| M3a `folder = 'AineoExplorerFolder',` removed from `ROLE_GROUPS` (folder group dropped) | `home.lua` | entry *show a changed file…*, *show an entry git ignores whole…* |
| M3b `AineoExplorerFolder = 'Directory',` removed from `HIGHLIGHTS` | `home.lua` | entry *are each linked to its default*, *…again once a colour scheme clears them* |
| M4 `{ link = link, default = true }` → `{ link = link }` | `home.lua` | entry *keep a group the user coloured…*, *…again once a colour scheme clears them* |
| M5 `settings.define_change_groups()` removed | `home.lua` | entry *ask for the groups … to be defined…* |
| M6 `change_groups = require('aineo.changes').kind_groups,` → `change_groups = {},` | `entry/explorer.lua` | entry *show a changed file in its change's group…* |

## Suites

D30: no whole suite. Run: `tests/test_explorer_tree.lua` (33 cases), `tests/test_entry_explorer.lua` (43), `tests/test_entry_explorer_pick.lua` (9), `tests/test_layout_explorer.lua`, `tests/test_doc.lua` (80), all with `Fails (0)`. `make lint`: 0 errors, 0 warnings.

## Open threads

- A group a user coloured before aineo first defined it loses its default link when a colour scheme clears highlights (`:highlight clear` gives an empty group, not aineo's link); this is the behaviour of every group the plugin defines, the two existing explorer groups included, and is unchanged.

## Commits

*Recorded after the merge.*
