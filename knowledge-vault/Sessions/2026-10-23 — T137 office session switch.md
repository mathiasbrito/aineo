# 2026-10-23 — T137 office session switch

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t137-office-session-switch-linear` · **Pull request:** into `feature/t123-office-authors` (supersedes the first, which followed the last `continued-in` line)

A bug the user found in the released office (D112, A598): after a resume that starts a new session the office is stuck with no activity. Three causes were found; the second is the one the user's own tab showed.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T137's row in §6, D112, A598, A604, A605 (withdrawn), A607, A569 and C17 (the follower reads the tail)
- `lua/aineo/office/init.lua`, `lua/aineo/entry/office.lua`, `lua/aineo/entry/tab.lua`, `lua/aineo/transcript/` (`continuation.lua`, `follower.lua`, `signals.lua`), `doc/aineo.txt`
- `tests/test_office_session_switch.lua`, `tests/test_entry_office_hooks.lua`, `tests/test_entry_office_life.lua`, `tests/test_transcript_continued.lua`, `tests/test_transcript_follow.lua`, `tests/test_entry_office.lua`, `tests/helpers/office_stand_in.lua`, `tests/helpers/office_child.lua`, `tests/fixtures/transcripts/session-continued-shape-2.1.309.jsonl`

## Task lines

- [X] T137 The office follows a session switch (D112, A598, A607): the office acts out the session the tab's panes follow and is told when it changes; the follower goes on in the tab's own continuation, the first `continued-in` line stamped after the tab began following the session

## The causes

1. **The switch.** `aineo.office` asked `options.transcript()` only when it started following. A switch of the tab's session, or a `SessionStart` hook naming the new session's path afterwards, never reached it.
2. **The session the office followed was not the one the tab shows.** The office followed `tab.session_id()`, the session of the tab's own Claude Code. A tab that claims a session (`:Aineo claim`, or a background session attached) has panes that follow the claimed session (`tab.panes_session()`) while its own Claude Code idles. Measured read-only, structure only, on the user's host: the tab's editor entries hold the own session (`own = true`) and the claimed one (`own = false`); the own session's transcript was last written two hours before, the claimed one minutes before, with 90 subagent files. The follower run headless on the claimed transcript reads it correctly (112 signals replayed, 3 agents, 2 subagents started); nothing was appended in the 30 seconds watched, so live arrival there is not measured. The user's frozen agent at the whiteboard with no subagents is the idle own session.
3. **A continuation no hook named.** A `continued-in` line in a transcript names the session a Claude Code went on in. Every Claude Code that resumes a session writes one (14 lines in the user's transcript), so the last line, or the file written last, is not the tab's: the last line named a side resume that had stopped, the live conversation was named by the second-to-last. The first rule of this task (the last line) was wrong and was replaced (A607).

## Measured

- A `continued-in` line is compact JSON of the keys `type`, `timestamp`, `sessionId`, `continuedInSessionId`; in a 44 MiB transcript the last was 0.73 MiB before the end, the previous 38 MiB back; the target's file was born about five minutes after its line.
- On the user's host a continuation target is a background fork (`--session-id Y --fork-session --resume X`) under a background host started with the tab's hook settings; its `SessionStart` hook reaches aineo with the tab's start token and names Y. `aineo.claude` already treats a `SessionStart` of another session from another process, with the token of a running start, as a switch at once, so the tab moves to Y and the office follows the panes (a case pins it).
- A resumed tab (`claude --resume X`) was alive and X and the fork's file were both written within a minute of each other, so X is not dead there; the writes cannot be attributed to a process by `lsof`.
- `message` and `ephemeral` are not line kinds: `message` is a field of user and assistant lines and `ephemeral` the type inside a `cacheControl` field. The shape fixture has the line kinds measured and the codec test pins that none but the prompt gives a signal.

## What was done

- **`office.session_changed()`**: forgets the permission waits, stops the follower and tracker of a running office and starts them on the transcript asked for now; a hidden or paused office starts nothing.
- **The entry**: the transcript is that of `tab.panes_session()`, own session when the panes follow none yet; `set_panes_session()` in `tab.lua` is the one place that sets it and tells the office when it changed (a switch the panes do not follow, a claim held or an unconfirmed start, changes nothing the office shows). A hook that changes the transcript path of the session shown tells it too.
- **The anchor**: the entry notes when the tab began following its session — its Claude Code about to start, its session switched — and hands it with the path; before the first start there is none and the follower looks for no continuation. (The moment the office is made was noted too until its mutant survived: the start's covers it.)
- **The search** (`transcript/continuation.lua`): with an anchor, the first `continued-in` line of the file stamped at or after it (10 seconds of slack), then that file's first such line, 8 hops at most, none twice; the last file need not exist. Without an anchor or a line, the transcript itself. One forward pass over each 1 MiB window (the review measured the quadratic search at 7.4 s for 7000 lines holding the field); the last 8 MiB of each file at most.
- **The follower**: follows the file found and its subagents folder; after the tail replay it searches once more and tells a line written meanwhile as news; names the sessions of its chain.
- **The office**: a `session_continued` signal that is news makes it follow again; a replayed one is ignored (the follower is on the file it names, and a loop would restart without end); it keeps the sessions of the chain it followed (`follows_session()`).
- **Permission waits** are accepted for the session the tab runs, the one its panes follow and any session of the chain the office follows.
- **Help**: the paragraph in `aineo-office`.

## Tests, in the order they were written

| Unit | Red evidence | Mutants |
|---|---|---|
| `session_changed()` follows the new transcript | `attempt to call field 'session_changed' (a nil value)` | M1–M5 |
| Claimed session acted out, shown or not yet | `{prompt, tool_started, tool_finished, turn_ended}` where `{prompt, tool_started}` | E1–E3 |
| First line stamped after the anchor, not the last; lines before it, no anchor, slack | 5 failed (the last line was followed; a replayed line shows where it should not follow) | C2d–C2g |
| Linear search with a few thousand one-key lines | red by time (7000 lines holding the field, under 1 s asked) | C2k |
| Race: a line written between the search and the replay | red: one search, no news | C3c |
| Anchor at a start and at a switch | `Left: nil Right: 1767225600` and one more | E7, E8 |
| Chain sessions named, kept, waits accepted | `Left: nil`, `follows_session` missing, `Left: {} Right: { "permission_asked" }` | X2, C2l, E9–E11 |
| Fork hook with the tab's token | green by nature: the machinery of `aineo.claude` already switches | — |

The first round's cases (switch told, a path told afterwards, the codec, the window edges, the byte bounds) are kept. Three cases of the first round were changed: the last-line case and the chain case follow the new rule; the entry end-to-end case writes its transcripts in a folder of its own, since the cases of a file share the session id and appended to one file; the counts of `session_changed` are deltas, since the panes' first follow counts.

## Mutants (the literal edits)

Each run against the test file named, one at a time, from the final tree (the hooks-file mutants and the survivors were run again after the last edit); every kill is an assertion failure (the loop case bounds its asks, so a mutant fails and does not hang).

| Mutant | Literal edit | File run | Failing cases |
|---|---|---|---|
| M1 waits not forgotten | `waits_kept = {} ⏎     local open = showing` → `local open = showing` | `test_office_session_switch` | 1 |
| M2 tracker kept | `stop_running(open) ⏎       start_running(open) ⏎     end ⏎   end ⏎  ⏎   --- Closes the office and stops` → `local kept = open.tracker ⏎       stop_running(open) ⏎       start_running(open) ⏎       open.tracker = kept ⏎` | `test_office_session_switch` | 4 |
| M3 paused office restarted | `if open and open.timer then ⏎       stop_running(open)` → `if open then ⏎       stop_running(open)` | `test_office_session_switch` | 1 |
| M4 old follower kept | `if open and open.timer then ⏎       stop_running(open) ⏎       start_running(open)` → `if open and open.timer then ⏎       start_running(open)` | `test_office_session_switch` | 1 |
| M5 running office not re-followed | `if open and open.timer then ⏎       stop_running(open) ⏎       start_running(open) ⏎     end` → `if open and open.timer then ⏎       open.tracker = nil ⏎     end` | `test_office_session_switch` | 5 |
| O0 live continuation not acted on | `vim.schedule(office.session_changed)` → `local _ = office.session_changed` | `test_office_session_switch` | 1 |
| O1 replayed continuation acted on | `if not signal.replayed then ⏎             vim.schedule(office.session_changed) ⏎           end` → `vim.schedule(office.session_changed)` | `test_office_session_switch` | 1 |
| X1 office hands no anchor to the follower | `since = since,` → `(deleted)` | `test_office_session_switch` | 2 |
| X2 chain sessions not kept | `followed_sessions[session] = true` → `(deleted)` | `test_office_session_switch` | 1 |
| E1 transcript of the own session only | `local session_id = tab.panes_session() or tab.session_id()` → `local session_id = tab.session_id()` | `test_entry_office_hooks` | 2 |
| E2 panes change never told | `if changed then ⏎       offices.session_changed(tab) ⏎     end` → `(deleted)` | `test_entry_office_hooks` | 6 |
| E3 panes change always told | `local changed = panes_session ~= id` → `local changed = true` | `test_entry_office_hooks` | 1 |
| E4 unchanged hook path told | `if transcript_of(tab) ~= before then` → `if true then` | `test_entry_office_hooks` | 2 |
| E5 hook path not told | `M.session_changed(tab) ⏎   end ⏎ end ⏎  ⏎ --- When, in seconds` → `end ⏎ end ⏎  ⏎ --- When, in seconds` | `test_entry_office_hooks` | 2 |
| E7 no anchor at a switch | `on_session_switched = function(id, source, left) ⏎         offices.began_following(tab)` → `on_session_switched = function(id, source, left)` | `test_entry_office_hooks` | 1 |
| E8 no anchor at a start | `local replacement = replacement_callbacks(working_directory) ⏎     offices.began_following(tab)` → `local replacement = replacement_callbacks(working_directory)` | `test_entry_office_hooks` | 3 |
| E9 wait of the chain refused | `(is_of_the_tab or office.follows_session(session_id))` → `is_of_the_tab` | `test_entry_office_hooks` | 1 |
| E10 wait of the panes refused | `or session_id == tab.panes_session()` → `(deleted)` | `test_entry_office_hooks` | 1 |
| E11 wait of any session accepted | `(is_of_the_tab or office.follows_session(session_id))` → `true` | `test_entry_office_hooks` | 2 |
| C1a subagent line read | `if agent ~= M.MAIN_AGENT or not session or` → `if not session or` | `test_transcript_continued` | 1 |
| C1b no id pattern | `or not session:match(SESSION_ID_PATTERN) then` → `then` | `test_transcript_continued` | 6 |
| C2a one hop | `local MOST_HOPS = 8` → `local MOST_HOPS = 1` | `test_transcript_continued` | 3 |
| C2b 1000 hops | `local MOST_HOPS = 8` → `local MOST_HOPS = 1000` | `test_transcript_continued` | 1 |
| C2c no visited check | `if not next_path or visited[next_path] then` → `if not next_path then` | `test_transcript_continued` | 1 |
| C2d last qualifying line | `for _, mark in ipairs(marks_in(path)) do ⏎     if mark.stamp` → `for _, mark in ipairs(vim.fn.reverse(marks_in(path))) do ⏎     if mark.stamp` | `test_transcript_continued` | 2 |
| C2e no stamp check | `if mark.stamp and mark.stamp >= since - SLACK_SECONDS then` → `if true then` | `test_transcript_continued` | 3 |
| C2f no slack | `local SLACK_SECONDS = 10` → `local SLACK_SECONDS = 0` | `test_transcript_continued` | 1 |
| C2g slack of 100 s | `local SLACK_SECONDS = 10` → `local SLACK_SECONDS = 100` | `test_transcript_continued` | 3 |
| C2h no overlap | `local OVERLAP_BYTES = 4096` → `local OVERLAP_BYTES = 0` | `test_transcript_continued` | 1 |
| C2i 80 MiB searched | `local MOST_BYTES_SEARCHED = 8 * 1024 * 1024` → `local MOST_BYTES_SEARCHED = 80 * 1024 * 1024` | `test_transcript_continued` | 2 |
| C2j 4 MiB window | `local WINDOW_BYTES = 1024 * 1024` → `local WINDOW_BYTES = 4 * 1024 * 1024` | `test_transcript_continued` | 1 |
| C2k mark that is no continued-in line ends the search | `mark_at = window:find(MARK, line_start, true) ⏎   end ⏎   return marks` → `mark_at = nil ⏎   end ⏎   return marks` | `test_transcript_continued` | 1 |
| C2l sessions of the chain not named | `table.insert(sessions, session)` → `(deleted)` | `test_transcript_continued` | 1 |
| C3a follows options.path | `path = path, ⏎     agent = signals.MAIN_AGENT,` → `path = options.path, ⏎     agent = signals.MAIN_AGENT,` | `test_transcript_continued` | 21 |
| C3b subagents of options.path | `folder = subagents_folder(path),` → `folder = subagents_folder(options.path),` | `test_transcript_continued` | 1 |
| C3c no search again after the tail replay | `if resolved_again ~= path then` → `if false then` | `test_transcript_continued` | 1 |
| E6 anchor at the office | (the line `began_following_at[tab] = began_following_at[tab] or os.time()` in `office_of`) | `test_entry_office_hooks` | survived: the start's anchor covered it, so the line was removed |

## Reported, not chosen

- **The follower reads more than the tail when it starts.** A569 and C17 say the last 256 KiB. The search reads up to 8 MiB back of each file of the chain, twice (before and after the replay). The narrowed case in `test_transcript_follow` pins the replay to the tail and a case in `test_transcript_continued` bounds the search by bytes and by the size of one read. The plan text is not edited here.
- **Slack of 10 seconds.** The tab's own resume writes its line as its Claude Code starts; the anchor is noted just before it starts. Another process's resume within 10 seconds before the anchor could be taken for the tab's.
- **Permission waits of a claimed session do not arrive.** The claimed session's process carries its own start token, not this tab's.
- **Unmeasured:** whether `claude --resume X` resolves to the latest continuation; live arrival of lines in the claimed session's transcript through the follower (nothing was written during the 30 seconds watched).
- **A continuation whose file never appears** leaves the office waiting on it.
- **Entry cases that look for the agent at the file cabinet do not tell a followed file from an idle wander** (T130); the entry cases count the signals the tracker takes instead.
- `announce_work` answered `not taken` for this worktree; the work went on.

## Open threads

- A check on the user's host that the claimed tab now shows the claimed session's agents and subagents.
- Plan C17/A569 text to say the start reads up to 8 MiB.

## Commits

*Recorded after the merge.*
