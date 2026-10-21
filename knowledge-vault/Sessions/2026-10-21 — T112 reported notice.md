# 2026-10-21 — T112 reported notice

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t112-reported-notice` · **Pull request:** into `dev`

A small fix after PR #307 merged (A537; D30: no whole suite before the push). The one-time notice that Claude Code started work in a worktree now names the branches the report gave, not the `HEAD` listed at that moment.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D100, A537 (the orchestrator's rulings), T112; A534, A536 (what T111 built)
- [[Sessions/2026-10-21 — T111 reported tree]] — the tree whose notice this changes
- `lua/aineo/changes/copy.lua` (`take_waiting()`), `scope.lua` (`started_work()`), `lines.lua` (`reported_worktree_heading()`)
- `doc/aineo.txt` — `aineo-changes-reported`
- `tests/test_changes_announce.lua`, `tests/test_claude_session_record.lua`, `tests/helpers/claude_session.lua`

## Task lines

- [X] T112 The notice of reported work started in a worktree names the branches reported (C15; D100, A537): `scope.started_work(top, branches)` and `lines.reported_worktree_heading()` name the worktree by its folder and the reported branches, joined by “, ”, in place of the listed `HEAD`; the help says so; a case for a record's last line that is valid JSON but not yet ended by its newline, killing by assertion the mutant that reads it; the entry helpers already read the record through `claude_session.record()` (T108), so that half of A537 changed no helper — done, PR to follow

## What was done

- **The notice.** `take_waiting()` told the user with the worktree as git listed it, so a worktree read while it was being made, listed detached for an instant, was told as `(detached)` and the test “a report git does not list yet | is added once a read lists it” depended on the timing. It now hands `scope.started_work()` the worktree's folder and the names of the branches of the node the report made, joined by “, ” and each quoted as a path is (`lines.quoted_path()`). `lines.reported_worktree_heading()` builds the heading; `worktree_heading()` stays for the rows and the picks, which show the listed `HEAD`. The help's sentence names `<branches>`.
- **The reader.** `tests/helpers/entry_tabs.lua` has no reader of the fake's record of its own: `start_arguments_in_tab()` calls `claude_session.record()`, which reads complete lines only since T108 (`4cd39f0`), and no other helper decodes the record. The one case of `test_claude_session_record.lua` failed a mutant by a crash (the decode of a cut line raises); a second case, a last line that is whole JSON without its newline, fails the same mutant by an assertion.

## Decisions

- A537, read from the brief's spec file. Where the report names several branches, the notice names the branches of the node the reports made (an agent's call replaces its set, a hook's adds), in the order reported.

## What was seen red

- `test_changes_announce` | a reported worktree | is told with the branch the report gave while git lists it detached: the first run found the user told nothing yet (the case then waits for the telling); the second found the notice `Worktree agent-1 (detached)` where `Worktree agent-1 (feature/a)` was expected.

## What arrived green, and why

- `test_changes_announce` | a reported worktree | is told with every branch the report gave, joined by a comma: pins the join the first case's code already did; killed by the mutant that names the first branch alone.
- `test_claude_session_record` | leaves out a last line that is valid JSON but not yet ended by its newline: pins code T108 wrote; killed by the mutant that decodes the whole text.

## Mutants

| Edit | Run on | Killed by |
|---|---|---|
| `copy.lua`: `reported_names = { worktree.branch or 'detached' }` after the names are taken (the listed `HEAD` again) | `test_changes_announce` | assertion, 2 cases (the detached case; the join case) |
| `claude_session.lua`: `local complete = text:match('^(.*)\n') or ''` → `local complete = text` | `test_claude_session_record` | the old case by a crash (decode error); the new case by an assertion (`{ pid = 43 }` extra) |
| `lines.lua`: `table.concat(names, ', ')` → `names[1]` | `test_changes_announce` | assertion, the join case |

## Runs

- `test_changes_announce` 46 cases, `test_claude_session_record` 2, `test_doc` 82, `make lint`: green on the tree pushed.
- `test_entry_tabs_routing` (the only other file that asserts the notice) failed one of its `Send` cases in 4 of 12 whole-file runs on this tree. Its `Send` group alone, narrowed, failed 3 of 16 runs on this tree and on `dev`'s head in the proportion 2 of 8 on `dev` and 3 of 8 here, on a host with a load average near 5. The failing cases wait for the first tab's paste to reach the fake and do not touch reported work; the case is a flake of the loaded host, not of this change. No file requires a helper this change edits (`claude_session.lua` is unchanged).

## Open threads

- The `Send` cases of `test_entry_tabs_routing` flake under host load (above); no change here.
- **Commits** — recorded after the merge.
