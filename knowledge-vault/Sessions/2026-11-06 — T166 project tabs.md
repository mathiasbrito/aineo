# 2026-11-06 — T166 project tabs

**Author:** the repository's maintainer, with Claude — implementer agent
**Branch:** `feature/t166-project-tabs` (from `dev` at 7e6037b5) · **Pull request:** into `dev`

T166: when a Claude Code session works in a repository other than the one it started in, that repository joins the tab as a project with a changes pane of its own, and a walkthrough may show any file of it (the user, 2026-11-06, in the D142 row).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D142 row (A709–A711 inside it) and the T166 row
- [[Sessions/2026-11-05 — T164 walkthrough pane]] — the walkthrough pane this extends
- `lua/aineo/projects/`, `lua/aineo/entry/projects.lua`, `lua/aineo/entry/tellers.lua`, `lua/aineo/changes/copy.lua`, `lua/aineo/layout/init.lua`, `lua/aineo/mcp/`, `doc/aineo.txt`, `README.md`

## Task lines

- [X] T166 Project tabs in the changes pane (D142, A709–A711): see the T166 row in the plan note.

## What was built

- `aineo.projects` (new home, requires no other): the list (`new_list`, cap 8), the line of tabs (`tab_line`), the kept list per session (`keep`, `read_kept`, `move_kept`, `followed_id`), the lookup of the checkout of a file or folder with a memo per folder (`new_checkouts`), the edit a signal tells of (`edited_path`), and the colours.
- `aineo.entry.projects` (composition root, per tab): the homes of the projects, the follower of the session's transcript (a second follower beside the office's: the office follows only while it runs), `<Tab>`/`<S-Tab>`/`X`, the routing of reports, the folders and names the walkthrough needs, the notice, the counts. `aineo.entry.tellers` takes `teller_for()` out of `editors.lua`; `aineo.entry.office` exports `transcript_for_session()` and `following_since()`.
- The changes home gained `base_words` (the Against line says `first touched`), `count_session_work()`, `stop_watching()`, `on_repository_change()`; the layout gained `replace_changes_pane()`.
- A710: the rule in `announce_work`'s description and in the instructions (one constant, `aineo.mcp.work`'s `OTHER_REPOSITORY_RULE`). A711: the refusal, both tools' descriptions and the server instructions; `<project>: <path>` in the plan's pane.

## Decisions (the implementer's, within A709–A711)

1. Keys `<Tab>`, `<S-Tab>`, `X` (free in the pane).
2. A signal the follower replays from the transcript's tail as it starts joins nothing: the kept list holds what joined, and a closed project must stay closed when the session is resumed (seen red by the resume case).
3. `NotebookEdit`'s path is `notebook_path` in Claude Code's tool; the spec says `file_path`: both are read.
4. Each joining has its own kept base (`followed_id` carries the joining's time), so a project closed and joined again begins at `HEAD` again.
5. A report that would be the ninth project is refused with words for the agent; an edit that would be the ninth is told once.
6. The persistence of the list is its own small module (`aineo.projects.kept`) rather than `aineo.changes.kept`, which would have needed a wider surface; its file-writing mirrors `changes.kept`'s. A follow-up could share them.
7. The home's `on_repository_change()` also fires when the repository is found and when a session's base is taken, so a joined project's count appears without a watch.

## Spec conflicts and edges to raise

- `aineo.projects` is a new home: `.claude/skills/modularity` §1 lists homes and the direction table by hand, so the table needs a row (`aineo.projects`: no aineo home; `aineo.entry` may require it) on an `ai/` branch. Not done here (`.claude/` is outside the packet).
- The brief says `aineo.changes.new(label)`; `new()` takes no label (it counts its own), and it is used as it is.

## Seen red / arrived green

Pure units (`edits`, `list`, `tab_line`, `kept`, `checkouts`) and the home, layout and entry cases each first ran against a missing function or module (reds are "attempt to call a nil value" or a failed expectation). Honest account: `aineo.entry.projects` and its wiring were written before the entry cases that pin them, so those cases arrived green and were pinned by mutants; the A710/A711 cases (texts, refusal, `<project>: <path>`, Enter) were each seen red first. Cases seen red by name: `tests/test_mcp.lua` (three), `tests/test_mcp_announce.lua` (two), `tests/test_entry_walkthrough.lua` and `tests/test_entry_walkthrough_pane.lua` (the refusal), `tests/test_entry_projects_walkthrough.lua` (names, Enter on the second repository's file), `tests/test_changes_project_home.lua` (found, session base), `tests/test_entry_projects_join.lua` (colours, replayed), `tests/test_entry_projects_session.lua` (resume).

## Mutants (each run on the file that covers it, restored after)

| Edit | Killed by |
|---|---|
| `list.lua`: `#held >= M.MOST` → `>` | assertion, test_projects_list (2) |
| `tab_line.lua`: `FEWEST_FOR_A_LINE = 2` → `1` | assertion, test_projects_tab_line |
| `edits.lua`: `NotebookEdit` entry removed | assertion, test_projects_edits (2) |
| `kept.lua`: the joining left out of `followed_id` | assertion, test_projects_kept |
| `entry/projects.lua`: replayed signals joined | assertion, test_entry_projects_join |
| `entry/projects.lua`: `left.stop_watching()` removed | assertion, test_entry_projects_pane |
| `entry/projects.lua`: `home.let_go()` removed from closing | assertion, test_entry_projects_session |
| `entry/projects.lua`: every report to the session's home | assertion, test_entry_projects_report (5) |
| `walkthrough_plan.lua`: `<project>: ` dropped | assertion, test_entry_projects_walkthrough (2) |
| `mcp/work.lua`: other-repository rule left out of the description | assertion, test_mcp_relay |
| `copy.lua`: no tell when the repository is found | assertion, test_changes_project_home |
| `layout/init.lua`: no `show_buffers_of` in `replace_changes_pane()` | assertion, test_layout_changes_swap (2) |

## Open threads

- Counts of a project not shown are read after an edit the transcript shows (700 ms) and when its home hears of a change; an edit made through a shell command leaves its count as it was until the project is shown.
- The tests' Edit/Write/NotebookEdit lines are the recorded `Bash` line of the 2.1.308 recording with the tool's name and input replaced; no recording of an `Edit` call exists yet.

## Fix round — review404 (A712)

All sixteen rulings, each test first. Seen red before its code: the order of edits (`test_entry_projects_join`, with `find_repository` delayed for the first repository), the hidden-pane line of tabs, the single-project count reads, the checkouts memo and `lookup_checkout` (`test_projects_checkouts`), the report cases (no branch, gone folder, folder inside a checkout, main checkout replacing a gone worktree, a step after the worktree is gone), the refusal and tool texts, `retop` and `names`, the pending-showing watch and the `move`/`copy` of kept session files (`test_changes_project_home`), the poller (`test_transcript_poll`), and the `<project>: <path>` names. Written after their code, so pinned by mutant instead (each killed by assertion): `session_continued` (11), the hand-over of an unfollowed session (12), `fork_of` in `tab.lua` (16), `poll_ms` (6), `:Aineo diff close` and `\g` on the chosen home (7), `shown = false` in `stop_watching()` (10, two cases), the tab line's name (13), the hidden-pane bar (5), the single-project guard (6), `take_live_checkout` (2), serial edits (1), the report to a held project (4).

Finding 1: `tests/test_entry_projects_pane.lua` run five times after it, 5 of 5 green.

Decisions within A712, none ruled on by the user: a poller shared by the file's and the subagents' watches (`aineo.transcript.watching`'s `new_poller()`, `poll_ms` on `follow()`), the office's followers unchanged; the checkout lookup for a report is `lookup_checkout()` (the folder must exist and be the top of the checkout it is in); a refused ninth project in a report is words for the agent; the follower's restart on `session_continued` re-resolves the continuation as the office does; `aineo.changes` gains `move_kept_session()` and `copy_kept_session()` for sessions no home follows; a fork is told by `on_session_switched`'s source `fork`; `BASE_WAIT_MS` is 3000 (was 4000) so the two waits add to 4.5 s.

Not re-run: the 16-minute whole suite is run once on the tree pushed (see the pull request).

## Second fix round — remeasure404 (A713)

All rulings applied. Seen red before their code: 16.3 (an edit stamped long before the follow joined), N1 (a fork named for another session carried into an unrelated one), 16.1 (a `continued-in` line naming the session carries), N2 (a replaced checkout kept the wrong base), N3 (the first lookup carried; the case that pinned a slow `true` became "a slow second lookup cannot lose the project"), the folder inside a checkout (refused, top needed), N6 (a report with no branch is taken with a note), N7 and the enclosing project in `lookup_checkout` (`test_projects_checkouts`), the `note` answer in `test_mcp_announce`, `retop_kept_session` (`test_changes_project_home`), N5 (a diff of a project not shown is closed). Arrived green: the case that a session with no fork or continuation named carries nothing (by nature), and the 0.6 s git case (the stub delays `find_repository` only, so the old code already managed it; the reviewer's shim delayed every git run). N4: the three kept-file cases now use ids of their own, and the `do return nil end` mutant of `copy_kept()` fails the copy case.

Mutants run (all killed by assertion): `copy_kept()` made a no-op, `found[directory]` answered before `afresh`, `fork_of` kept after any follow (the stale case needed a "followed later still carries" case, added), `found = found or false` removed, the kept-base retop removed, the stamp filter removed, the `continued_in` carry removed, `close_shown_diff` trying the chosen home only.

Decisions: a taken announcement may carry a note (`{ note = ... }` from the editor, `ok. <note>` as the tool's non-error answer); the refusal for a folder inside a checkout names the top; 16.2 means no copy of the session's own base at a fork. Not run: the whole suite (the orchestrator runs it on the head).

## Commits

*Recorded after the merge.*
