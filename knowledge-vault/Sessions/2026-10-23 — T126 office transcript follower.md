# 2026-10-23 — T126 office transcript follower

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t126-office-transcript` · **Pull request:** into `feature/t123-office`

A regular packet of the office screensaver (T123; D26 applies). The skeleton's follower read one file that existed. This packet makes `aineo.transcript` the whole state source of the plan's §2: every signal, a file that is not there yet, cut or replaced, a tail with no whole line, a poll where no file event can be made, and the session's subagents.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T126's row in §6, §2 (*Following a transcript*, *The states and their signals*), OF1–OF11, OR1, OR2; D107–D111, A569, A573, A575, A576
- [[Sessions/2026-10-22 — T124 office walking skeleton]] — the skeleton this builds on; its attack review (A576 items 4 and 10) is half of this packet
- `lua/aineo/transcript/`, `lua/aineo/entry/office.lua`, `doc/aineo.txt`
- `tests/test_transcript_signals.lua`, `tests/test_transcript_follow.lua`, `tests/test_transcript_subagents.lua`, `tests/test_entry_office.lua`, `tests/test_office.lua`, `tests/helpers/fake_transcript.lua`, `tests/fixtures/transcripts/`

## Task lines

- [X] T126 The transcript follower (C17; D109, D111, A569, A573, A576): every signal of §2, the tail rebuild, fs event with a poll fallback, partial lines, lines split mid-character, over-long lines, truncation and replacement, the subagents folder and each meta; a transcript created after the office shows (A576 item 4) and lines after a truncation or a replace-by-rename (item 10)

## What was done

- **The codec** (`signals.lua`, `timestamp.lua`). Signals gained `prompt`, `thinking`, `interrupted`, `compacted`, `background_done` and `at` (seconds since 1970 from the line's `timestamp`); a null or another JSON type reads as absent. A prompt is a user line whose text opens with neither `<` nor `[` and is not a compaction's summary. A subagent's transcript has no line that times its turns (OF11), so its turn ends with the `text` block whose stop reason is `end_turn`; the `thinking` block before it carries the same reason and does not end it; the main agent's turn still ends with `turn_duration`.
- **`watching.lua`.** One place for "tell me the path may have changed": a file event where the path exists and the system can make one; every 500 ms otherwise (a missing path, no events); it watches again when another file takes the path. Measured on macOS (Neovim 0.12.5, 2026-10-23): a watch on a missing file fails with `ENOENT`; after a rename over the watched file one `rename` event arrives and then nothing, whatever is written to the new file; a watch on a folder reports creations, meta rewrites and appends to the files in it.
- **`file_follower.lua`.** One file by byte offset: waits for a file that is not there (the lines it is made with are news, not a replay); reads again from the tail a file shorter than the offset or with another identity (device and inode); doubles a tail with no whole line from 256 KiB to 4 MiB and then follows from the end; skips and counts a line of a MiB or more in a replay as it is live; delivers nothing once stopped, even from its own callback.
- **`subagents.lua`.** `<session id>/subagents/`: a subagent arrives with `agent-<id>.jsonl` (replayed if it was there when the follower started) and leaves, after the last lines it wrote, when its meta says `finished` or `stoppedByUser`. One over at the start is not heard of; a meta that is missing, not a regular file, too long or not JSON means it runs. At most 64 are followed at once.
- **Entry.** When no file of the session's id exists in any folder of `projects/`, the entry hands the office the path Claude Code will make in the folder named after the directory the editor started in (OF1's rule). T128 supersedes it with `transcript_path`.
- **Help.** What the office reads, and what it waits for, in the office chapter.

## Fixtures

`tests/fixtures/transcripts/session-2.1.308.jsonl` (175 lines, 16 turns), `subagent-explore-2.1.308.jsonl` (21 lines) and its `.meta.json`: recorded once with the user's leave on Claude Code 2.1.308 (Haiku, 2026-10-22), scrubbed by scrubber v2, each `.jsonl` opening with its `fixture-header` line. The hook inputs belong to T128. The recording holds no notice of a finished background task in a readable form (the scrubber replaced the text, so line 97 reads as a prompt) and no `compact_boundary` line: those two signals are pinned by lines built from the shapes the plan measured (OF8, OF9), and the test says so by building them in the test.

## Tests

Cases: `test_transcript_signals` 55, `test_transcript_follow` 24, `test_transcript_subagents` 14, `test_entry_office` 15. The rows of the account below name each test once.

**Red first** (the message that proved the red):

| Test | Red |
|---|---|
| signals: gives a tool call the time of its line | `nil` for `at` |
| signals: reads the user's prompt as a prompt | `{}` for a prompt |
| signals: no prompt for a notice or bracket (4), for a compaction summary (1) | a prompt was given (5) |
| signals: background done, thinking, interrupted, compacted | `{}` each (4) |
| signals: the answer that stops a subagent | `{}` for the end of turn |
| follow: waits for a file that is not there yet | "there is no transcript file to follow" |
| follow: a file cut and written again | `{}` for `{ 'rewritten', 'and_after' }` |
| follow: a last line longer than the tail window; the lines before a last line too long | `{}` for the calls (2) |
| follow: nothing more once stopped from its own callback | the rest of the pass was delivered (`two`, `three`); the version that counts opens arrived green, killed by D3a |
| subagents: arrives as a replay; arrives later, none a replay | `{}` for `subagent_started` (2) |
| subagents: a meta that is a named pipe | **a hang**: the editor was held 60 s, until killed |
| subagents: more than the office follows | 65 arrivals for 64 |
| subagents: stopped from the callback that heard an arrival | the subagent's `prompt` followed |
| entry: the transcript written after the office showed | the mutant `return nil` in place of the folder rule (the first run failed too, for another reason: an earlier case's file of the same session id shadowed it; the case now removes them) |

**Arrived green, and the mutant that kills each** (the code was written with the unit's first test, or the test pins a guard): timestamp's negatives and leap day (C1, C9); a user text that is not an interruption (C2); the null stop reason, the thought that carries `end_turn`, the main agent's end (C3a, C3b, C4); the recordings' counts (C9, C4); a file replaced by a longer one (W1, F8); a folder not there yet and the poll without events (W2); a whole line and a cut one (D1c); the tail's bytes (D4); stopped holds no handle (W4, D3c); a last line over 4 MiB (F5); the subagents that are over, not drawn, or leaving (D2, S2–S5), two apart (S10), the entries that are not transcripts (S11, red against its mutant), and the two cases added after the first mutant run (F9, S11).

## Mutants

Each literal edit run alone from a pristine copy on the test files that exercise it; the kind is read from the output. Run on the tree that is pushed.

| # | Literal edit | Run on | Result |
|---|---|---|---|
| D1 | `file_follower.lua`: `offset = offset + consumed` → `offset = offset` | `test_transcript_follow` | killed by a hang (the pass asks again while bytes remain, so the Neovim spun until SIGKILL at 150 s) |
| D1b | same → `offset = offset + (consumed == #text and consumed or 0)` (the offset not advanced after a partial line) | same | killed by a hang, as D1 |
| D1c | same → `offset = offset + #text` (advanced past the partial line) | same | killed, assertion (3) |
| D2 | `subagents.lua`: `if running[id] and is_over(meta_path(id)) then` → `if false then` (a subagent kept after its meta says finished) | `test_transcript_subagents` | killed, assertion (4) |
| D3a | `file_follower.lua`: the `if stopped then return false end` of a pass removed | `test_transcript_follow` | killed, assertion (1) |
| D3b | `stop`: `stopped = true` removed | same | killed, assertion (1) |
| D3c | `stop`: `watch.stop()` removed | same | killed, assertion (2) |
| D4 | `local TAIL_BYTES = 256 * 1024` → `1024 * 1024 * 1024` (the tail rebuild reads the whole file) | same | killed, assertion (3) |
| F4 | `MAX_TAIL_BYTES` → `256 * 1024` | same | killed, assertion (2) |
| F5 | the give-up `offset = stat.size` → `offset = 0` | same | killed, assertion |
| F6 | the `#line < MAX_LINE_BYTES and` of a replay removed | same | killed, assertion |
| F7 | the identity compare of a changed file removed (size only) | same | killed, assertion |
| F8 | the size compare removed (identity only) | same | killed, assertion |
| F9 | the `if stopped` between the signals of a line removed | same | **survived**; the case "none of the other calls of a line" added; killed, assertion |
| W1 | `watching.lua`: the re-arm on another identity → `if false then` | same | killed, assertion |
| W2 | the poll after a failed event removed | same | killed, assertion (3) |
| W3 | `settle_soon()` removed | same | killed, assertion (11) |
| W4 | `stop` leaves the event handle open | same | killed, assertion (2) |
| S2 | `subagents.lua`: `leave` does not stop its follower | `test_transcript_subagents` | killed, assertion (4) |
| S3 | `leave` does not read to the end first | same | killed, assertion (2) |
| S4 | a subagent over at the start is drawn | same | killed, assertion (2) |
| S5 | `stoppedByUser` ignored | same | killed, assertion (2) |
| S6 | the regular-file check of the meta removed | same | killed by a hang (150 s) |
| S7 | the cap of 64 removed | same | killed, assertion |
| S8a, S8b | the replay of a subagent present at the start off; its `replayed` mark off | same | killed, assertion (2; 1) |
| S9 | the stop check after the arrival's signal removed | same | killed, assertion |
| S10 | `stop` does not stop the subagents | same | killed, assertion (2) |
| S11 | the folder or link filter (`entry_type == 'file'`) removed | same | **survived**; the case added; killed, assertion |
| C1 | `timestamp.lua`: the digits glued to the seconds accepted | `test_transcript_signals` | killed, assertion |
| C2 | an interruption for any text | same | killed, assertion |
| C3a, C3b | the end of a subagent's turn for any stop reason; for any block | same | killed, assertion (1; 2) |
| C4 | the main agent's turn also ends with its text | same | killed, assertion (3) |
| C5 | a compaction's summary is a prompt | same | killed, assertion |
| C6 | the notice of a finished task not read | same | killed, assertion |
| C7, C8 | `<` not excluded from prompts; `[` not excluded | same | killed, assertion (2; 1) |
| C9 | `signal.at = nil` | same | killed, assertion (11) |
| E1 | `entry/office.lua`: the folder rule's path → `return nil` | `test_entry_office` | killed, assertion |

## Reported, not chosen

- **"The entry starts the office without one"** (the dispatch, A576 item 4). Read as: the entry hands the office the path the file will have. Without the session's `transcript_path` (T128) the only path is OF1's folder rule, with the editor's starting directory; the existing file in any folder still wins. A session resumed from another directory waits on the wrong path until T128.
- **A T124 test changed.** "Runs one timer, the frames’, and one watch" now counts two timers: the half-second look for the subagents folder, which does not exist until the first subagent and cannot be an event. Not watched through the project folder (not measured on Linux, where libuv's inotify watch is not recursive) nor through the transcript's events (none come while the main agent waits on a foreground subagent).
- **The follower's contract widened, beyond the plan's interface.** `follow()` returns only the follower (a missing file is waited for, so there is no `nil, problem`); `at` is on every signal a line gives; `subagent_started` and `subagent_finished` carry no `call`; a file read again after a cut or a replacement marks what it holds as replayed.
- **Added as attack hardening, not in the plan:** the cap of 64 followed subagents, and the regular-file check of the meta.

## Open threads

- Measured on macOS only: the replacement by rename and the folder watch. On Linux (inotify) the same logic should hold (the watch is made again on another identity) but is not measured.
- Subagents of subagents (`spawnDepth` above 1): where Claude Code writes their files is not measured; the follower reads only the one folder.
- A file cut and grown past its old size between two looks, with its identity kept, is read from the old offset.
- The folder rule for long paths (OR2) is not measured.

## Commits

*Recorded after the merge.*
