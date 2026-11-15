# 2026-11-15 — T184 walkthrough record

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t184-walkthrough-record` (from `dev` at 66a00320) · **Pull request:** into `dev` (number recorded after the merge)

T184 (A750, D161): `\Vq` ends the code walkthrough as `\vq` does, then asks the tab's Claude Code for a record of the whole walkthrough as an HTML file and a PDF at a path aineo chooses, and tells the user when that turn ends what was written. A small-fix wave (D30): the test files the change touches, `make lint`, no whole suite.

## Links

- [[Projects/aineo]]
- [[Sessions/2026-11-14 — T182 q closes the file column]] — the previous change on `dev`

## What it does

- **Key.** `\Vq` (`<Plug>(aineo-walk-record)`, no `:Aineo` word, as `\vq` has none), in the Walkthrough section of the cheatsheet. With no step shown it says `aineo: no walkthrough step is shown in this tab`, as `\vq` does, and sends nothing.
- **Ending.** The bands are cleared at once, as `\vq` clears them. The instruction replaces `End the walkthrough`: one message is sent, not two (a second would only replace the first while it waits).
- **Path.** `<folder>/<walkthrough.record_folder>/<YYYY-MM-DD>-<slug>.pdf` (`aineo.entry.walkthrough_record_path`): `<folder>` is the folder the tab's Claude Code started in; a relative `record_folder` is under it, an absolute one is used as it is (`~` and variables expanded, `..` resolved); the slug is the first six words of the plan's title, lowercase ASCII letters and digits joined by `-`, at most 60 characters, `walkthrough` when there is no plan or no such word; `-2`, `-3`… after the slug while the PDF or the HTML of that name exists.
- **Instruction** (`aineo.entry.walkthrough_record_instruction`, a fixed text): the walkthrough is over; write the record as HTML at the path with `.html`, then the PDF from it with the first of headless Chrome or Chromium, pandoc, typst that is installed (keep the HTML and say so when none is); first page the plan (title, summary, what it covers, the steps with their files); then one section per step in the plan's order with its title, its explanation and the code its bands marked (file path, line numbers, monospace block); steps not reached are included and marked as not shown; make the folder; write no other file; call neither `walkthrough_step` nor `walkthrough_plan`; reply with the path.
- **Delivery.** Through `walkthrough_moves`' `send_or_hold()`, so a busy agent gets it when its turn ends. A message there is now `{ text, name, on_sent? }`: the user is told a held message by its `name` (`Write the walkthrough record`), not by the instruction's text.
- **Notice.** `aineo.entry.walkthrough_record` notes the PDF's path when the instruction is sent, and when the agent is seen working and then idle again (`on_busy_change`) checks it once: the PDF exists, INFO naming it; else the HTML exists, WARN naming it and saying no PDF tool was found; else WARN naming the path. It reads files and starts nothing. An agent never seen working (terminal title off) gets no notice.
- **Setting.** `walkthrough.record_folder`, default `'walkthroughs'`, a non-empty string.

## Decisions

- **The slug comes from the plan's title, not its summary.** The brief says summary; the summary is up to 4096 characters of prose and the title is what names the walkthrough, so a file name from the title reads as one. The title is read before the bands are cleared, since clearing forgets the plan.
- **The instruction is sent in place of `End the walkthrough`,** not after it.
- **The turn that sent a held instruction is not the turn that wrote the record:** the notice waits for the agent to be seen working after the instruction went.

## Tests

- `tests/test_entry_walkthrough_record_path.lua` (new), `tests/test_entry_walkthrough_record_instruction.lua` (new): the slug, the path rules, the instruction's text.
- `tests/test_entry_walkthrough_record.lua` (new, child Neovim with the fake `claude`): the key sends the instruction with the path, clears the bands, sends nothing else, names the record for the plan sent last, honours a relative and an absolute `record_folder`, counts up when the name is taken, sends nothing with no step shown, waits while the agent works, and the three notices, none early, once, not for the turn that sent a held instruction.
- `tests/test_config.lua`: the setting, from either source, and its refusals.
- Changed because the key list grew: `tests/test_keys.lua` (Walkthrough section), `tests/test_plugin.lua` (the mappings), `tests/test_health.lua` (the key lines and the two walkthrough lines of the explain section), `tests/test_doc.lua` (tags).

## Mutants

Each run on the test file named, the source restored after. All killed.

| Mutant | Killed by |
|---|---|
| slug keeps every word | `test_entry_walkthrough_record_path.lua` (six words at most) |
| an absolute `record_folder` joined under the folder | the same (absolute as it is) |
| a name with only its HTML counts as free | the same (HTML counts as taken) |
| the counter starts at `-3` instead of `-2` | the same |
| the cut slug keeps a trailing dash | the same |
| the instruction drops "marked as not shown", or the PDF tools | `test_entry_walkthrough_record_instruction.lua` |
| an empty `record_folder` accepted | `test_config.lua` |
| the HTML-only notice as information | `test_entry_walkthrough_record.lua` |
| the notice at the first idle, not after the agent was seen working | `test_entry_walkthrough_record.lua`, only once the case of a tab the moves follow first was added (the first listener registered ignores the delivering edge by its order; the other needs the guard) |
| the notice at every turn | the same (told once) |
| the plan read after the bands are cleared | the same (the path names the plan) |
| a held instruction announced by its text | the same |
| the bands not cleared | the same |
| `on_sent` never called | the same (no notice) |

## Open threads

- An agent never seen working (the terminal title off) gets no notice at the end of the record's turn; the moves' 10 s fallback is not used. Say so in the help (done) and decide whether a timer is wanted.
- The slug reads the plan's title; a walkthrough of several plans in one session is named for the last plan sent.
