# 2026-10-25 — T136 office authors guide

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t136-office-authors-guide` (from `origin/dev` at 360a8a59) · **Pull request:** into `dev` (number recorded after the merge)

T136, the pack authors' guide: a documentation packet with one test change (`tests/test_doc.lua`), a regular packet; the whole suite does not run, since no code changed (the dispatch: `test_doc` and `make lint`).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — §4 (the documentation for mod makers), §6 row T136; A608 (sharing), D113, A616, A617, D119
- [[Learnings/A Claude Code subagent transcript has no line that times its turn, so a reader ends its turn on the text that stops it]]
- `doc/aineo.txt` — *aineo-office* and the sections after it; `README.md` — *The office*

## What was done

The help chapter *THE OFFICE* already documented the pack format field by field and the commands. What it lacked, against §4 and the dispatch, was written, and what was stale was fixed:

- **States** (`*aineo-office-states*`): the 24 states and four parents, each with its signal, how long it lasts, the state it falls back to, the dwell, what a replayed line does not bring, and the command classes. Read from `office_states` (`vocabulary`, `calls`, `record`, `timing`, `display`) and `transcript.signals`, not from the plan's table.
- **Pack authoring**: `based_on` and what a pack lays over its base (a table read from `office_pack.loader`), the files of a pack, `pack.lua`'s fields with defaults and a skeleton, characters, poses (`*aineo-office-poses*`, new: every pose field, `like`, `rises`, `holding`, `screen`), effects as a field table with an example, the art areas and what draws into each, the floor plan with a worked expansion of the repeated blocks and a legend example, triggers with their matching rules, bounds and examples, and the check's own output, taken from a deliberately broken pack.
- **Activities split into tagged sections**, their text kept and completed: activities, steps (the step kinds, `for_seconds`), spots (what the engine uses: `door`, `desk`, `beside_desk`; what it knows without a legend), desks (T146, A617), random life and games (table tennis), things and the mess chain (D113), the cat (its behaviours with their weights, `even_if_taken`, the chain cap), what each state plays.
- **Worked examples**: the tiny pack, complete with every file; the default pack (the room, the legend, pieces with sizes, what each state plays, the random life); the space-station pack as the second (what it reuses from the default, the trigger with two Lua patterns and why); *Making a pack*, with a hand-written pack of 22 lines that is `based_on` the default; *Sharing your pack* (A608); the limits in one place (*Limits*).
- **Fixed**: the paragraph under *Checking a pack*, which said the office "shows when you ask for it, not by itself" and "does not pause for a tab page" (both false since T132 and T140), is now *The session it acts out*, without those sentences.
- **README**: *The office* (what it is, packs, *Make your own pack*, *Sharing your pack* with the lazy.nvim spec, the known packs `default` and `space_station`), the settings table and example gain `office.pack` and `office.pieces` (the README listed neither), the health check and *More* mention the office.

## Decisions

- **The examples are the pack format's own.** The tiny pack and the 22-line pack in the help were extracted from the help text by a script, written to a scratch pack folder and run through `:Aineo office check`: both have no problem. The sample of problems in *Checking a pack* is the wording of a broken pack's real check, abridged (the help says so). The step table's `for_seconds` says "from 0" because the pair is accepted from 0 (`{ 0, 0 }`, the default pack's) while a single number must be above 0.
- **Tables of the default pack are preformatted blocks**, not tab tables: the 78-column test counts a tab to the next stop and the tables are wide.
- **A pack made by `:Aineo office new` is a full copy** (`based_on = false`); the help says so, and shows the by-hand `based_on = 'default'` pack for a small one.
- **No `*aineo-office-commands*` or `*aineo-office-config*` tags**, which §4's list names: the commands and the settings already have their tags (`:Aineo-office-*`, `aineo-config-office.*`), which `test_doc` already requires for every subcommand and setting.

## Spec conflicts and findings (reported, not changed)

- **State 24, `leaving`, for the main agent.** §2 of the plan says the main agent leaves when its session ended or switched. `session_ended` is a signal kind of the tracker, and nothing in `lua/aineo` sends it (`grep -rn session_ended lua/aineo`): the main agent never plays `leaving`; on a session switch the office drops its tracker. The help says `leaving` is a subagent's.
- **`for_seconds` message.** The check says "a number above 0, or two numbers, the shortest and the longest" for a pair, which is accepted from 0 to 0 (`schema.lua`, `seconds`). The help says what the code accepts.
- **Format follow-ups of A597** (no way to change one field of an inherited activity, a pose as another's with pieces swapped, ...) are still open; the help says an activity is replaced whole.
- `mcp__aineo__announce_work` answered "not taken" for this worktree; the call was not repeated.

## Tests

- `tests/test_doc.lua`: 16 tags added to the list every help tag must have (and `aineo-office-live`, `aineo-office-hooks`, which the help had and the list lacked). **Seen red** against the help at `HEAD`, 16 failures, each `no help: Vim:E149: No help for <tag>`: `aineo-office-states`, `-session`, `-poses`, `-steps`, `-spots`, `-desks`, `-random-life`, `-things`, `-cat`, `-pack-states`, `-tiny`, `-default`, `-space-station`, `-making`, `-sharing`, `-limits`. **Green** with the new help: `tests/test_doc.lua` 144 cases, `Fails (0)`. `-live` and `-hooks` arrived green: the tags existed; the mutant that kills them is deleting the tag, as below.
- The same file's *fits in 78 columns* case caught 55 lines of the first draft; all were reflowed.
- Mutants, each applied to a copy of the final help and restored (`cmp` clean): (1) removing the tag `*aineo-office-limits*` from its line: killed by an assertion, `has the tag … { "aineo-office-limits" }`; (2) appending 68 characters to the line `A tool call whose result is an error, other than a test run's. Lasts 3`: killed by an assertion, `fits in 78 columns`.
- `make lint`: `stylua --check` and `selene` over `lua plugin scripts tests`, 0 errors, 0 warnings.
- Not run: the whole suite (no code changed; the dispatch says so).

## Fix round (review368, A622)

Nine statements made true to the code, docs only: (1) `arriving` for the main agent comes only from `:Aineo office reset` (`office/init.lua`, `follows_from_now`), not from a session switch; (2) `needs_permission` ends at the next line that is not a tool call's start (`record.lua`, `M.hear`); (3) the `:Aineo office states tiny` sample says it is wrapped and cut to fit; (4) the problems sample says it is abridged; (5) a `when` with no field and a `follow` name other than `someone_walking` are not told by the check (code unchanged; tightening it is the candidate T149); (6) the subagent is like the agent only when no pack it is based on has one; (7) the board's `plan` window as `whiteboard.lua` draws it; (8) decimal numbers only in `pack.lua`; (9) the 20-line pack is 22 lines (the commit message of the first round keeps "20-line").

## Open threads

- A test that pins the help's tiny pack and the 22-line pack against `:Aineo office check` would keep them true when the format changes; this packet checked them by hand with a script (kept out of the repository). Worth a small test packet.
- The by-state table of the default pack and the weights of its random life are copied from `aineo-office/default/pack.lua`; they drift when the pack does.
- State 24 for the main agent (above): decide whether `session_ended` is to be sent, or the plan's row amended.

## Commits

*Recorded after the merge.*
