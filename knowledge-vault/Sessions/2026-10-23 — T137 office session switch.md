# 2026-10-23 — T137 office session switch

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t137-office-session-switch` · **Pull request:** into `feature/t123-office-authors`

A bug the user found in the released office (D112, A598): after a resume that starts a new session the office is stuck with no activity. Two causes were found and both are fixed: the tab's session switch never reached the office, and a resumed session's conversation can go on in another session's file that no hook names.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T137's row in §6, D112, A598 (extended here), A569 and C17 (the follower reads the tail)
- `lua/aineo/office/init.lua`, `lua/aineo/entry/office.lua`, `lua/aineo/entry/tab.lua`, `lua/aineo/transcript/` (`continuation.lua`, `follower.lua`, `signals.lua`, `init.lua`), `doc/aineo.txt`
- `tests/test_office_session_switch.lua`, `tests/test_entry_office_hooks.lua`, `tests/test_entry_office_life.lua`, `tests/test_transcript_continued.lua`, `tests/test_transcript_follow.lua`, `tests/helpers/office_stand_in.lua`, `tests/fixtures/transcripts/session-continued-shape-2.1.309.jsonl`

## Task lines

- [X] T137 The office follows a session switch (D112, A598): `session_changed()` on the office, told by the entry on every switch of the tab's session and when the transcript named for the tab's session changes; the transcript follower goes on in the session a `continued-in` line names

## The cause

1. **The switch.** `aineo.office` asked `options.transcript()` only when it started following (each show, each return to the tab page). `on_session_switched` of the tab did not tell the office, and a `SessionStart` hook that named the new session's path after the switch did not either, so a following office kept reading the old session's file. Confirmed in the code and by the first test, which failed because `session_changed` did not exist.
2. **The continuation (A598 extended).** The coordinator measured, on Claude Code 2.1.309, a tab started with `claude --resume X`: the hook named X and X's file, and Claude Code wrote the conversation to another file Y that no hook named. Measured here, read only, in structure only (key names, counts, offsets; no content copied):
   - X's transcript holds two lines of type `continued-in`, compact JSON of the keys `type`, `timestamp`, `sessionId`, `continuedInSessionId`. The last names Y. It is 0.73 MiB before the end of a 44 MiB file, so the follower's 256 KiB tail never holds it; the earlier one is 38 MiB back.
   - Y's file was born about five minutes after that line's stamp: the line precedes the file.
   - Y's lines carry `sessionId` Y; 713 carried-over lines also carry a snake-case `session_id` of X. About a thousand uuids are shared between the two files. The first new line's `parentUuid` is in neither file's uuids, so `parentUuid` links nothing.
   - Both files were still growing minutes apart (scheduled-task lines), so another Claude Code process may still write X.
   - The coordinator named `message` and `ephemeral` as line kinds of Y. Measured: no line has either as its `type`; `message` is a field of user and assistant lines and `ephemeral` the type inside a `cacheControl` field. The shape fixture carries a `cacheControl` and the other kinds listed there (`mode`, `permission-mode`, `atis-latch`, `bridge-session`, `api-request`, `api-request-blob`, `cost-state`, `last-prompt`), and the codec test pins that none gives a signal but the prompt.

## What was done

- **`office.session_changed()`** (`aineo.office`): forgets the permission waits kept, and, when the office runs (its frame timer exists), stops its follower and tracker and starts them again on the transcript `options.transcript()` names now; a hidden or paused office starts nothing and follows the new one when it next starts. The old follower's lines go to the old tracker, which nothing draws.
- **The entry** (`aineo.entry.office`, `aineo.entry.tab`): `session_changed(tab)` is called first in the tab's `on_session_switched`, whatever the panes do with the switch; `note_transcript()` compares the tab's transcript before and after storing the hook's path and tells the office when it changed. A hook for a session the tab does not run changes nothing, so no session check is needed.
- **The codec** (`transcript/signals.lua`): a `continued-in` line of the main transcript gives `session_continued` with the session, only when the session is a UUID (the name becomes a file name beside the transcript).
- **The search** (`transcript/continuation.lua`): from the end of the file back, 1 MiB at a time with 4 KiB read past each window, at most 8 MiB, for the last line holding `"continuedInSessionId"` that decodes as a `continued-in` line of a UUID; the chain is followed 8 hops at most, none twice. The last file need not exist: the follower waits for it.
- **The follower** (`transcript/follower.lua`) follows the resolved file and its subagents folder.
- **Live** (`aineo.office`): a `session_continued` signal that is news (not replayed) has the office follow again, scheduled; a replayed one is ignored, since the follower is on the file it names already.
- **Help**: a paragraph in `aineo-office` on the switch, the continuation and the 8 MiB.

## Tests, in the order they were written

Each unit was seen failing before its code, except where said.

| Unit | Red evidence | Mutants killed |
|---|---|---|
| `session_changed()` follows the new transcript | `attempt to call field 'session_changed' (a nil value)` | see the table below |
| Agents leave, waits forgotten, hidden, paused, one timer and one watch, a file written later, the old file's later lines | written after the minimal body that already held them; the mutants below are their red | see below |
| Entry: a switch is told | `Left: 0 Right: 1` | EM1 |
| Entry: a path named after the switch is told again, not twice, not for another session | `Left: 1 Right: 2` (two cases) | EM3, EM4 |
| Entry end to end (`/resume` shown, hidden, path told afterwards) | written after the wiring | EM1, EM4 |
| Codec: `continued-in` | `Left: {} Right: { { agent = "main", kind = "session_continued", … } }` | C1a, C1b |
| Follower follows the continuation | `Left: { "session_continued" } Right: { "prompt", … }` | C2g, C2h |
| Search: last of two, chain, loop, beyond the tail, at every window edge (9 distances), beyond 8 MiB, byte bounds, text that only holds the field, a cut line, a hostile name | written with the search | C2a–C2f, C2i |
| Live continuation | first wait `false` (nothing reacted) | O0, O1 |

## Mutants (the literal edits)

Each run against the test file named, one at a time, from the final tree; every kill is an assertion failure (the loop case bounds its asks, so a mutant fails and does not hang).

| Mutant | Literal edit | File run | Failing cases |
|---|---|---|---|
| M1 waits not forgotten | delete `waits_kept = {}` in `session_changed` | `test_office_session_switch` | 1 |
| M2 tracker kept | `local kept = open.tracker` before and `open.tracker = kept` after the restart | same | 4 |
| M3 paused office restarted | `if open and open.timer then` → `if open then` | same | 1 |
| M4 old follower kept | delete `stop_running(open)` in `session_changed` | same | 1 |
| M5 running office not re-followed | the restart → `open.tracker = nil` | same | 5 |
| O0 live continuation not acted on | `vim.schedule(office.session_changed)` → `local _ = office.session_changed` | same | 1 |
| O1 replayed continuation acted on | drop the `if not signal.replayed then` guard | same | 1 |
| EM1 switch not told | delete `offices.session_changed(tab)` in `on_session_switched` | `test_entry_office_hooks` / `test_entry_office_life` | 4 / 1 |
| EM3 unchanged path told | `if transcript_of(tab) ~= before then` → `if true then` | `test_entry_office_hooks` | 2 |
| EM4 note not told | delete `M.session_changed(tab)` in `note_transcript` | hooks / life | 2 / 1 |
| C1a subagent line read | drop `agent ~= M.MAIN_AGENT or` | `test_transcript_continued` | 1 |
| C1b no id pattern | drop `or not session:match(SESSION_ID_PATTERN)` | same | 6 |
| C2a one hop | `MOST_HOPS = 1` | same | 1 |
| C2b no visited check | `if not next_path or visited[next_path]` → `if not next_path` | same | 1 |
| C2c first mark | `last_found_before(window, MARK, before)` → `window:find(MARK, 1, true)` | same | 1 |
| C2e no overlap | `OVERLAP_BYTES = 0` | same | 1 |
| C2f 80 MiB searched | `MOST_BYTES_SEARCHED = 80 * 1024 * 1024` | same | 2 |
| C2i 4 MiB window | `WINDOW_BYTES = 4 * 1024 * 1024` | same | 1 |
| C2g follows `options.path` | `path = path,` → `path = options.path,` in `follow_file` | same / hooks e2e | 15 / 1 |
| C2h subagents of `options.path` | `subagents_folder(path)` → `subagents_folder(options.path)` | same | 1 |

## Reported, not chosen

- **The follower now reads more than the tail when it starts.** A569 and C17 say it reads the last 256 KiB. The search for a `continued-in` line reads up to 8 MiB back (typical transcripts are smaller, so it reads the file). The test that pinned "no more than 256 KiB read" now pins the replay to the tail (`#signals` within the tail's lines), and a new case bounds the search (bytes and the size of one read). The plan's rows are not edited here.
- **The coordinator's heuristic was not built.** It asked to follow a newer `.jsonl` of the folder whose lines reference the session id. The `continued-in` line is written by Claude Code for exactly this and names the file; a newer sibling that mentions the session could be another tab's fork. Rejected on that ground.
- **Another process may still write X.** In the measured pair both files grew minutes apart; with a `continued-in` line in X the office follows Y whatever process writes X.
- **A continuation that never gets a file** leaves the office waiting on Y.
- **Entry cases that look for the agent at the file cabinet do not tell a followed file from an idle wander** (the agents wander: T130), so the entry case for the continuation counts the signals the tracker takes instead.
- **The cases share a state directory**, so the session a start last followed is kept across cases of a file: each case that switches uses a session of its own.
- `announce_work` answered `not taken` for this worktree; the work went on.

## Open threads

- A check on the user's host that a tab started on the resumed session now follows Y.
- Plan C17/A569 text to say the start reads up to 8 MiB.

## Commits

*Recorded after the merge.*
