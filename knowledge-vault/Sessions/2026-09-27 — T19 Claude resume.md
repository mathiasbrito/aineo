# 2026-09-27 — T19 Claude resume

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t19-claude-resume` · **Pull request:** into `dev` (a regular packet)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D23; C1, C2, C3; Q8; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t19-claude-resume.md` and the brief reviews `brief-review-t19-t21.md` (T19-1 to T19-11) and `brief-review-t19-claude-resume.md` (T19b-1 to T19b-9)
- `Implementation/Waves/00006-fixes/evidence/claude-resume-q8.txt` — Q8, Claude Code 2.1.283
- [[Sessions/2026-09-26 — T21 Claude exit]] — the layout's handling of Claude's terminal, whose *Limits* named T19's hand-off
- [[Sessions/2026-09-26 — T14 Input draft]] — the drafts' per-directory file and the run-start clean-up (I2), which T19 follows

## Context

**Goal:** T19, under D23: each session aineo starts gets an id of its own, kept per working directory, and the next start there resumes it. The user chose "aineo's own last one there" over the folder's last conversation (`--continue`) and over a fallback to it.

## What was done

- **`lua/aineo/claude/session_ids.lua`** (new, inside the Claude home): `new_session_id()` — 16 bytes of `vim.uv.random`, version nibble 4, variant `10`, lower-case `8-4-4-4-12` (RFC 9562 §5.4); `kept_session_id()` — the id kept for a directory, or nil when the file is missing, unreadable (a directory), or holds anything but that form; `keep_session_id()` — written to `<file>.<pid>.cut`, then renamed over the kept file, mode 0600, raising an error naming the file on failure. The file is `<state>/aineo/claude-sessions/<sha256 of the directory>.txt`.
- **`lua/aineo/claude/init.lua`**: `start_session()` now starts on `kept_or_new_session()` — `--resume <kept>` or `--session-id <new>` before the other arguments, so `--allowedTools` stays last — and keeps a new id once the job has started (a warning when it cannot, the session starting all the same). Settings gain `state_directory` (required) and `on_terminal_replaced` (optional). SR3: a session's `on_exit` checks `found_no_conversation()` — a resume, exit code 1, the terminal still valid, and `No conversation found with session ID: <id>` in its lines joined without a separator; then a scheduled callback starts a new session on a new id in its place (`start_in_place()`, the same path `start_session()` takes after an exit: `replace_terminal()` and the keep), unless `v:exiting` is set, and hands the new terminal to `on_terminal_replaced`.
- **`lua/aineo/layout/init.lua`**: one entry point, `follow_claude_terminal(terminal)`, which makes `terminal` the layout's `state.buffers.claude` (validated as an existing buffer).
- **`plugin/aineo.lua`**, inside `started_claude_terminal()` only: `state_directory = kept_places().state_directory` and an `on_terminal_replaced` that sets `claude_terminal` and calls `follow_claude_terminal()`.
- **`tests/helpers/fake_claude.lua`**: under `AINEO_FAKE_CLAUDE_CONVERSATIONS` (a directory), `--resume` of an id with no conversation file prints Q8's message and exits 1 after 1.4 s (Q8 G's time; A took 2.1 s), drawing no screen; Enter received under a session id creates its conversation file (Q8 B and F). Unset, the flags are recorded and nothing more.
- **`tests/helpers/claude_session.lua`**: `stand_in_settings()` gains `state_directory = stdpath('state')`; `start_again()` takes overrides; `start_again_noting_replacements()`; `start_arguments()`.
- **`Makefile`**: `make test` and `make test_file` also remove `.tests/state/nvim/aineo/claude-sessions` at the start of a run (the leak remedy's point 4).
- **`doc/aineo.txt`**: `Claude's session ~` (`*aineo-claude-session*`) above `Input's draft ~`, and the fourth addition in `*aineo-report*`.
- **Tests**: `tests/test_claude_resume.lua` (new), `tests/test_entry_claude_resume.lua` (new), `tests/test_claude.lua` (the flags pin: `--session-id` added, `#arguments == 9`, its own state directory; two malformed-setting rows), `tests/test_layout.lua` (one case).

## How SR3 is told, and what it gets wrong

Chosen: exit code 1 **and** the message with the kept id on the failed terminal, read at the job's `on_exit`, its lines joined without a separator. A terminal row keeps the blank it ends on — measured at 39 columns, where a row ends on the blank after `ID:`, on 0.12.5 and 0.11.6 (`t19-wrap-probe.lua`) — so the joined rows give the message back at any width. The first commit removed every blank before matching; its mutant survived, and the second commit dropped it. The text is tier 2 — observable, undocumented, Claude Code 2.1.283 — and pinned by the fake, which states that version.

What it gets wrong:
- **A later Claude Code that words the message otherwise, or exits with another code**: the fallback never happens. Every start in that directory then resumes the same id and fails the same way; `\o` shows the exit each time. The user's way out is to remove the kept file (the help names where it lives). No start is lost silently: the exit is on screen.
- **A failure that looks like this one**: another program printing that exact line, with this id, and exiting 1 — only a `claude.cmd` wrapper could; aineo would then start a new session and forget the old id.
- **Output not yet in the terminal at `on_exit`**: the brief review measured the message present at `on_exit` 8 of 8 runs; a Claude Code that printed it and exited within Neovim's terminal refresh would be taken for another exit. While Neovim quits, the terminal is not refreshed, and the probe of this packet saw the buffer empty at `VimLeavePre`.
- **A terminal wiped before `on_exit`** (a user's `TermClose` autocommand): nothing can be read, so it counts as another exit — no fallback, no error.

## Unit list (stated before the first test)

The slicing, simplest first; the Claude home before the composition root, the layout's half of the hand-off before the composition root's (the brief's order, to see the `\c` test red):

1. SR1 — a start where no session is kept passes `--session-id` and a lower-case version-4 UUID.
2. SR2 — the next start there, once Claude Code has exited, passes `--resume` of that id.
3. SR2 — a new editor with the same state directory resumes it (kept on disk, not in memory).
4. SR1 — two editors started afresh in two directories get two ids (`math.random` is not seeded).
5. SR2 — a resumed id stays kept.
6. SR2 — a kept file holding no id (empty, cut short, not an id, upper case) counts as none and is replaced.
7. SR4 — two directories keep two sessions, each resumed in its own.
8. SR1 — an id that cannot be kept: the session starts, the user is warned.
9. Settings: `state_directory` validated; the composition root passes it (entry: a new Neovim resumes).
10. SR3 — a resume Claude Code finds no conversation for is replaced by a new session on a new id; that id is kept; its terminal takes the failed one's windows; `on_terminal_replaced` gets it (validated).
11. SR3 — the message wrapped at 39 and 60 columns; any other exit of a resume keeps the id; no fallback while Neovim quits; no error when a `TermClose` autocommand wipes the terminal.
12. The hand-off, layout half first: a file opened in Claude's window moves to the file column; then `\c` enters Terminal mode (red with the layout half alone); then EX1, EX2, the refusal of `i`, the exit shown on `\c`, the user's tab kept.
13. SR4 through the plugin: `:cd` elsewhere, `\o` starts that directory's own session; back, `\o` resumes the first.
14. Pins found along the way: the file's mode, `--allowedTools` last, the kept file under `stdpath('state')`, a directory standing for the kept file, the layout entry point's validation.

## Red and green

37 cases added or changed: 23 in `tests/test_claude_resume.lua`, 10 in `tests/test_entry_claude_resume.lua`, 1 in `tests/test_layout.lua`, and in `tests/test_claude.lua` the flags pin changed and two malformed-setting rows added. Each once:

**Seen red (15 tests, 18 cases)**, each on its own run before its code:
- *starts Claude Code on a new session id where none is kept* — `Failed expectation for one new session id`, `Words: {}`.
- *resumes the kept session once Claude Code has exited* — `Left: {}`, `Right: { "7a1e88ec-…" }`.
- *resumes the session an earlier editor kept in the directory* — `Left: {}`, `Right: { "e617af83-…" }` (the ids were kept in memory then).
- *counts a kept file that holds no session id as none, and replaces it* — 4 of 4 rows, `Words: {}`.
- *starts Claude Code on a new session id it cannot keep, and says so* — the start raised `E739: Cannot create directory …: file already exists` (an error, not an assertion: the missing behaviour was that the start survives).
- *starts Claude Code on a new session id where a directory stands for the kept file* — `session_ids.lua:79: attempt to index local 'text' (a nil value)` (a defect found by the test; an error, the missing behaviour being that the start survives).
- *names the setting that is malformed … { "state_directory", 1 }* — `Failed expectation for error matching pattern "settings%.state_directory"`, observed `vim/fs:156: attempt to get length of local 's'`.
- *names the setting that is malformed … { "on_terminal_replaced", "a callback" }* — `Observed no error`.
- *resumes, in a new Neovim, the session aineo kept for the directory* (entry) — `Left: nil`, `Right: "exited"`: `:Aineo open` started nothing, the settings lacking `state_directory`.
- *starts a new session on a new id in its place* — first `attempt to index a nil value` (no third start; the test then read `starts[3].argv`), then, with `start_arguments()`, `Failed expectation for one new session id`, `Words: {}`.
- *hands the new session's terminal to on_terminal_replaced* — `Left: {}`, `Right: { 4 }`.
- *starts no new session as Neovim quits* — green on its first two runs, red on the third: `Left: {}`, `Right: { "c5dc1c85-…" }` (the fallback ran during the quit and kept a new id). The guard went in then.
- *raises no error and starts nothing when a TermClose autocommand wipes its terminal* — `v:errmsg` held `Invalid buffer id: 3` from `found_no_conversation()`.
- *moves a file opened in Claude's window to the file column* (entry) — windows `{ file, report, input }` for `{ terminal, file, report, input }`.
- *`\c` enters Terminal mode in the new session's terminal* (entry) — `Left: "nt"`, `Right: "t"`, with the layout's half in and the composition root's not, as the brief review predicted.

**Arrived green (19 cases)**, each with its killer, all run (Mutants, below):
- *gives two editors started afresh in two directories two ids* — spent by unit 1 (`vim.uv.random`); M4.
- *keeps the session id it resumes* — by nature (a resume keeps nothing); M8.
- *keeps a session for each directory …* — spent by unit 3 (the file is named by the directory); M7.
- *keeps the session id in a file only the user can read and write* — pinning code written with unit 8's write; M9.
- *puts the session first and keeps --allowedTools last* — spent by unit 1 (the words go first); M22.
- *passes no flag beyond the session, the servers, the instructions and the tools* — the pin updated with unit 1's code in place; M31.
- *keeps the new session's id in place of the one it could not resume* — spent by unit 10's `start_in_place()`; M19.
- *shows the new session's terminal in every window that showed it* — spent by `start_in_place()`'s `replace_terminal()`; M15, M13.
- *is told by a message its terminal wraps, at a width of 39 / 60* (2 cases) — spent by the joined read; M13.
- *is not taken for a resume that exits 1 another way, whose id stays kept* — by nature (the message check); M11.
- *follow_claude_terminal() refuses a terminal that is not an existing buffer* — pinning code written with the entry point; M29.
- Entry: *keeps the session's id under the editor's state directory* — spent by unit 9; M23. *follows :cd, each directory resuming its own session* — spent by `cwd = getcwd()` and unit 3; M30.
- Entry, once both halves of the hand-off were in: *returns Normal mode as the new session's process ends, entered by a window command and i*, *closes Claude's window as the new session's ended terminal is wiped from it*, *refuses Terminal mode in the new session's ended terminal* — M25, M26, M28; *shows the new session's exit on \c, starting nothing* — M26; *leaves the user in the tab they moved to before it* — M27.

## Mutants

Each mutant is its literal edit (`t19-mutants.py` in the worktree's scratchpad holds every edit verbatim), applied to a copy of the file, run against a copy of its test file narrowed to the group that tests the unit (`make test_file FILE=.tests/t19-n-*.lua`), then restored. M1–M10b and M22 were measured at `a3a740f`, the last commit before the rebase onto `dev` at `8386aed`; the others at `0c205f9`, whose code and narrowed test groups are the same as `a3a740f`'s (that commit changed only the start group's two cases). The rebase changed no file a mutant edits or runs (`git diff --stat a3a740f HEAD` over them is empty). Kinds read from the output.

| # | Literal edit | Narrowed group | Result |
|---|---|---|---|
| M1 | `session_ids.lua`: delete `bytes[7] = with_high_nibble(bytes[7], 4)` | resume › `start_session()` | killed, assertion, 6 of 6 runs over three passes (10–11 cases; the version nibble is 4 by chance 1 in 16) |
| M2 | delete `bytes[9] = with_variant_bits(bytes[9])` | same | killed, assertion, 6 of 6 runs over three passes (7–9 cases; the variant is right by chance 1 in 4) |
| M3 | `'%02x'` → `'%02X'` | same | killed, assertion (11) |
| M4 | `vim.uv.random(SESSION_ID_BYTES)` → 16 bytes of `math.random(0, 255)` | same | killed, assertion: *two editors … two ids* |
| M5 | delete `if not is_session_id(kept) then return nil end` | same | killed, assertion: the 4 malformed rows |
| M6 | `… ~= nil and text == text:lower()` → `… ~= nil` | same | killed, assertion: the upper-case row |
| M7 | `vim.fn.sha256(working_directory)` → `vim.fn.sha256('')` | same | killed, assertion (2): per directory; the file-mode case |
| M8 | the keep in `start_in_place()` → `keep_session_id(settings, choice.resumed and session_ids.new_session_id() or choice.id)` unconditionally | same | killed, assertion: *keeps the session id it resumes* |
| M9 | `OWNER_ONLY = tonumber('600', 8)` → `'644'` | same | killed, assertion: the file mode |
| M10a | `keep_session_id()` in `init.lua` without its `pcall` and warning | same | killed, assertion (2), after the cases wrapped the start in `expect.no_error`; before that, 2 crashes |
| M10b | delete the `vim.notify(…WARN)` | same | killed, assertion: *cannot keep …, and says so* |
| M11 | `found_no_conversation()`: `return true` before reading the terminal | resume › *a resume with no conversation* | killed, assertion: *exits 1 another way* |
| M12 | `screen:find(NO_CONVERSATION .. ended.choice.id, …)` → `screen:find(NO_CONVERSATION, …)` | same, then the **whole suite** | **survived** both: equivalent in every state the suite builds, since the fake names its own id; it matters only for a message naming another id |
| M13 | `table.concat(lines)` → `table.concat(lines, '\n')` | same | killed, assertion (3): both wraps, the windows case |
| M14 | the fallback's choice `resumed = false` → `true` | same | killed, assertion (4) |
| M15 | delete the fallback's start and hand-off | same | killed, assertion (6) |
| M16 | delete the `on_terminal_replaced` call | same | killed, assertion |
| M17 | delete the `v:exiting` guard | same | killed, assertion, 4 of 4 runs on the final test (2 of 4 before it waited for the message) |
| M18 | delete `or not vim.api.nvim_buf_is_valid(ended.buffer)` | same | killed, assertion (`v:errmsg`) |
| M19 | keep only when `not (previous and previous.choice.resumed)` | same | killed, assertion |
| M20 | delete the `state_directory` validation | `test_claude.lua` › malformed | killed, assertion |
| M21 | delete the `on_terminal_replaced` validation | same | killed, assertion |
| M22 | session words after `claude_arguments()` | resume › `start_session()` | killed, assertion: *keeps --allowedTools last* |
| M23 | `plugin`: `state_directory = vim.fn.stdpath('cache')` | entry › *Claude's session* | killed, 2 assertions and 1 crash (`E484` reading the file where it is not) |
| M24 | `plugin`: delete `claude_terminal = terminal` (the layout alone follows) | entry › after a resume | killed, assertion: `\c` → `nt` |
| M25 | `plugin`: delete the `follow_claude_terminal()` call (the root alone) | same | killed, assertion (4) |
| M26 | `plugin`: delete both (no hand-off) | same | killed, assertion (5) |
| M27 | `plugin`: `layout.open({ … })` in place of `follow_claude_terminal()` | same | killed, assertion: the tab |
| M28 | `layout`: delete `state.buffers.claude = terminal` | same | killed, assertion (4) |
| M29 | `layout`: delete the validation | `test_layout.lua` › `follow_claude_terminal()` | killed, assertion |
| M30 | `plugin`: `cwd = kept_places().working_directory` | entry › *Claude's session* | killed, assertion: `:cd` |
| M31 | delete `vim.list_extend(command, session_arguments(choice))` | `test_claude.lua` › the flags pin | killed, assertion |

The first commit's blank-stripping match had a mutant (`screen:find(message)` without stripping) that survived both wrap cases; a probe showed that a terminal row keeps the blank it ends on (39 columns, both versions), and the second commit removed the stripping.

## Verification

- **Before the rebase**, at `a3a740f` on `e0582e0` (the tree `0a6b5bd`'s code): `make test` 1110 cases, `Fails (0)`, exit 0, on 0.12.5 (load 75 at the start) and 0.11.6 (load 81) (`t19-final-0125.log`, `t19-final-0116.log`, each headed with `uptime` and `nvim --version`). The baseline 1074 (`evidence/baseline-0a6b5bd.txt`) plus 36 new cases.
- **T17 merged into `dev` during the packet** (PR #68, 2026-09-27 06:22 UTC), so the brief's merge check against `origin/bugfix/t17-report-paths` was superseded: before the merge, `git merge-tree --write-tree` against its head `2598e7d` printed `c5662e6`, no conflict; after it, the branch was rebased onto `dev` at `8386aed` with no conflict.
- **After the rebase**, at the pull request's head: `make test` 1200 cases, `Fails (0)`, exit 0, on 0.12.5 (load 96) and 0.11.6 (load 29) (`t19-rebased-0125.log`, `t19-rebased-0116.log`). `dev`'s own count at `8386aed` was not run; 1200 − 36 = 1164. `tests/test_doc.lua` is among them, on the merged help.
- `make lint`: clean. The deep-require check prints only lines inside their own homes; this change adds one, `lua/aineo/claude/init.lua` requiring `aineo.claude.session_ids`.
- The `Makefile` clean-up: a probe file put in `.tests/state/nvim/aineo/claude-sessions/` was gone after `make test_file` (by hand).
- The wrap probe (`t19-wrap-probe.lua`, `nvim --clean --headless -l`, both versions): at 39 columns the message's first row is `"No conversation found with session ID: "`, its blank kept.

## Decisions & reasoning

1. **The session words go first** (`--resume`/`--session-id` before `--mcp-config`), so `--allowedTools` stays last (`arguments.lua`'s docstring); pinned by "puts the session first and keeps --allowedTools last".
2. **A new id is kept after the job has started**, not before: a start that raises (`claude.cmd` not executable) keeps nothing, as `start_session()`'s docstring promises ("leaves the session as it was").
3. **The fallback is scheduled from `on_exit`**, not run inside it, as the brief review's prototype did; the check reads the terminal inside `on_exit`, while it is valid.
4. **`v:exiting` guards the scheduled start**: measured, a scheduled callback runs inside a `VimLeavePre` handler's `vim.wait()`, and `jobstart()` works there (a headless probe; `v:exiting` read `0`). Before the guard, the quit test saw the fallback run during quit once in three runs, and the guard's mutant was killed 2 of 4 until the test waited for the message (decision 6).
5. **An unreadable kept file counts as none**: a directory where the file should be made `kept_session_id()` raise (`text` nil) — found by a test written for it, fixed.
6. **The fake's no-conversation exit takes 1.4 s**, Q8 G's measured time: a shorter chosen 500 ms let the quit test land after the exit on some runs (the `v:exiting` mutant killed 2 of 4); with 1.4 s and a wait for the message on screen, 4 of 4.

## Readings for the MVP review

The orchestrator's readings, carried as the brief gives them:
- SR3's new session in place of one Claude Code no longer has — D23 says only that a directory with none gets a new one;
- the id is kept from the moment the session starts, whether or not anything is typed;
- a directory's kept id is never removed, as the drafts are not (MR125);
- two editors in one directory resume the same session (Q8 E; a limit);
- SR3's fallback is visible: "No conversation found with session ID: …" shows for 1–2 s (Claude Code 2.1.283; the fake takes 1.4 s), at every start that follows an untyped session;
- Claude's session follows the directory Claude Code starts in (`settings.cwd`), while the Reports and the draft stay with the editor's first working directory (`kept_places()`);
- after SR3's fallback the user is in Normal mode in the new terminal, even when they were typing in the one that failed; `\c` puts them in the new prompt (the help says so);
- D23's own: a session switched inside Claude (`/clear`, `/resume`) is not followed.

The author's:
- **An id that cannot be kept warns once per start** and the session starts on it anyway; the next start then starts another new session.

## Task lines

The wave holds its marks (rule 6). The line T19 would take:

- [X] T19 — Claude resumes aineo's own last session in the working directory (D23): each session aineo starts gets an id of its own, kept per working directory under `stdpath('state')/aineo/claude-sessions/`, and the next start there resumes it; a resume Claude Code finds no conversation for is replaced by a new session, handed to the composition root and the layout — regular.

## Limits

- **Not measured: an id whose conversation existed and is gone.** SR3 assumes Claude Code exits as it does for an id it never had (Q8 A, G); if it does otherwise, that exit shows as another exit, and the id stays.
- **`--resume` with `--mcp-config`, `--append-system-prompt` and `--allowedTools` together was not measured** on the real CLI; each is documented, and the fake only records them.
- **Two Claude Codes on one conversation** (two editors in one directory): Q8 E measured both start, neither refused; nothing sent to either.
- **The whole-or-nothing write is not driven by a cut-short write**: the Claude home takes no injected file system, so a partial write cannot be provoked; its consequence — a file that holds part of an id — is pinned by the "cut short" row, which counts as no session.
- **The Makefile clean-up** is verified by hand (a probe file in `claude-sessions/` gone after `make test_file`), not by a test.

## Open threads

- The help's wording of the fallback's moment ("shows for a moment") follows the real CLI's 1–2 s; a Claude Code that fails faster shows it less.

## Commits

*Recorded after the merge.*
