# 2026-09-27 — T19 Claude resume

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`); the fix round by a second implementer agent of the same kind, which took the pull request over from its author; the correction after the re-measure by a third
**Branch:** `feature/t19-claude-resume` · **Pull request:** #73 into `dev` (a regular packet)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D23; C1, C2, C3; Q8; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t19-claude-resume.md` and the brief reviews `brief-review-t19-t21.md` (T19-1 to T19-11) and `brief-review-t19-claude-resume.md` (T19b-1 to T19b-9)
- `Implementation/Waves/00006-fixes/evidence/claude-resume-q8.txt` — Q8, Claude Code 2.1.283
- [[Sessions/2026-09-26 — T21 Claude exit]] — the layout's handling of Claude's terminal, whose *Limits* named T19's hand-off
- [[Sessions/2026-09-26 — T14 Input draft]] — the drafts' per-directory file and the run-start clean-up (I2), which T19 follows
- PR #73's three reviews — attack (findings A1 to A10), test integrity (I1 to I8), records (R1 to R12) — answered by the fix round below

## Context

**Goal:** T19, under D23: each session aineo starts gets an id of its own, kept per working directory, and the next start there resumes it.

The user's request, 2026-09-26, as D23 records it: “I want the plugin to remmeber the last session that was opened, and when reopening to load the session”, then “the claude session...”. Asked which conversation to pick up, the user chose "aineo's own last one", over "The most recent one (Recommended)" (`--continue`) and over asking each time, accepting that after a `/clear` or `/resume` inside Claude aineo reopens the older one. Then: "the last one, but it must be per project, someone working in a different folder/project, will have the last session executed on that folder." Asked which session aineo resumes in a folder, the user chose "aineo's own last one there (Recommended)", described as: "The last session aineo itself started in that folder. A conversation you ran in a plain terminal in the same folder is ignored. A folder where aineo never started one gets a new session." — over the folder's last conversation by anyone, and over aineo's own with the folder's last as a fallback.

## What was done

- **`lua/aineo/claude/session_ids.lua`** (new, inside the Claude home): `new_session_id()` — 16 bytes of `vim.uv.random`, version nibble 4, variant `10`, lower-case `8-4-4-4-12` (RFC 9562 §5.4); `kept_session_id()` — the id kept for a directory, or nil when the file is missing, unreadable (a directory), or holds anything but that form; `keep_session_id()` — written to `<file>.<pid>.cut`, then renamed over the kept file, mode 0600, raising an error naming the file on failure; its directory is made with the retry the report records use (the fix round, A2). The file is `<state>/aineo/claude-sessions/<sha256 of the directory>.txt`.
- **`lua/aineo/claude/init.lua`**: `start_session()` starts on `kept_or_new_session()` — `--resume <kept>` or `--session-id <new>` before the other arguments, so `--allowedTools` stays last — and keeps a new id once the job has started (a warning when it cannot, the session starting all the same). Settings gain `state_directory` (required) and `on_terminal_replaced` (optional). SR3: a session's `on_exit` checks `found_no_conversation()` — a resume, exit code 1, the terminal still valid, and `No conversation found with session ID: <id>` on its terminal, the lines and the message compared with every white space removed (the fix round, A1); then a scheduled callback — once the command-line window has closed, when it is open (A3) — starts a new session on a new id in its place (`start_new_session_in_place()`, through `start_in_place()`, the path `start_session()` takes after an exit: `replace_terminal()` and the keep), unless `v:exiting` is set or another start has taken the ended session's place meanwhile (A6); it keeps a user in Normal mode there (A4), tells a start that fails once as an error (A3), and hands the new terminal to `on_terminal_replaced`.
- **`lua/aineo/layout/init.lua`**: one entry point, `follow_claude_terminal(terminal)`, which makes `terminal` the layout's `state.buffers.claude` (validated as an existing buffer).
- **`plugin/aineo.lua`**, inside `started_claude_terminal()` only: `state_directory = kept_places().state_directory` and an `on_terminal_replaced` that sets `claude_terminal` and calls `follow_claude_terminal()`.
- **`tests/helpers/fake_claude.lua`**: under `AINEO_FAKE_CLAUDE_CONVERSATIONS` (a directory), `--resume` of an id with no conversation file draws nothing for 900 ms, prints the message broken at its terminal's width as Claude Code 2.1.283 breaks it, and exits 1 510 ms later, deaf to keys meanwhile (the fix round, A1 and I8; the packet's fake printed the message as one line at once and exited 1.4 s later); Enter received under a session id creates its conversation file (Q8 B and F). Unset, the flags are recorded and nothing more.
- **`tests/helpers/claude_session.lua`**: `stand_in_settings()` gains `state_directory = stdpath('state')`; `start_again()` takes overrides; `start_again_noting_replacements()`; `start_arguments()`; and, in the fix round, `start_again_after_next_exit()`.
- **`Makefile`**: `make test` and `make test_file` also remove `.tests/state/nvim/aineo/claude-sessions` at the start of a run (the leak remedy's point 4).
- **`doc/aineo.txt`**: `Claude's session ~` (`*aineo-claude-session*`) above `Input's draft ~`, and the fourth addition in `*aineo-report*`; in the fix round, the requirements' version line, the actions' restart sentence and the `claude.cmd` entry (below).
- **Tests**: `tests/test_claude_resume.lua` (new), `tests/test_entry_claude_resume.lua` (new), `tests/test_claude.lua` (the flags pin: `--session-id` added, `#arguments == 9`, its own state directory; two malformed-setting rows), `tests/test_layout.lua` (one case).

## How SR3 is told, and what it gets wrong

Chosen: exit code 1 **and** the message with the kept id on the failed terminal, read at the job's `on_exit`, the terminal's lines and the message both compared with every white space removed. The text is tier 2 — observable, undocumented, Claude Code 2.1.283 — and pinned by the fake, which states that version.

**A false record, corrected by the fix round.** This note said that "a terminal row keeps the blank it ends on — measured at 39 columns … — so the joined rows give the message back at any width", and commit `2a50708` removed the white-space stripping on that ground. That was true of a line the terminal soft-wraps, which is what the fake then printed; it is false of Claude Code 2.1.283. The orchestrator measured the real CLI on 2026-09-27, in a headless Neovim 0.12.5 terminal, in a scratch folder under the user's leave for Q8: at 39 and at 60 columns Claude Code breaks the message itself, and the terminal holds `No conversation found with session ID:` on one row, with no blank at its end, and the id alone on the next; at 78 columns it is one row; it exits 1 after 1.5 to 2.3 s, and the rows are the same at `on_exit` and after a `vim.schedule`. So the packet's match never fired at the 60 columns Claude's column has by default, and every start after an untyped session failed there. The brief's "The terminal wraps the message at the window's width" was the brief's claim, measured with a stand-in rather than the real CLI — the orchestrator's error, not the author's. The attack review found it from the 2.1.283 binary (the message goes through its own renderer, which breaks lines itself).

What it gets wrong:
- **A later Claude Code that words the message otherwise, or exits with another code**: the fallback never happens. Every start in that directory then resumes the same id and fails the same way; `\o` shows the exit each time. The user's way out is to remove the folder `aineo/claude-sessions/` under `stdpath('state')`, which the help names and, since the fix round, gives as the way out (A9); it makes every directory start a new session. No start is lost silently: the exit is on screen.
- **A failure that looks like this one**: that text, with this id, on the terminal of a resume that exits 1 — printed by a `claude.cmd` wrapper, or shown by Claude Code's own screen as a pasted prompt or as a resumed transcript that quotes it (plausible for anyone debugging aineo inside aineo); aineo would then start a new session and forget the old id. With white space removed, a text that differs from the message only in its blanks matches too. The exit of 1 is still needed. **Corrected by the correction (the re-measure's finding 4):** this said "only a `claude.cmd` wrapper could".
- **Output not yet in the terminal at `on_exit`**: the brief review measured the message present at `on_exit` 8 of 8 runs, and the orchestrator's width runs saw it there too; a Claude Code that printed it and exited within Neovim's terminal refresh would be taken for another exit. While Neovim quits, the terminal is not refreshed, and the packet's probe saw the buffer empty at `VimLeavePre`.
- **A terminal wiped before `on_exit`** (a user's `TermClose` autocommand): nothing can be read, so it counts as another exit — no fallback, no error.

## Unit list (stated before the first test)

The packet's slicing, simplest first; the Claude home before the composition root, the layout's half of the hand-off before the composition root's (the brief's order, to see the `\c` test red):

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

The fix round's slicing, each behaviour red first on `57a740e`'s code:

15. A1 — the fake breaks the message at its terminal's width as 2.1.283 does; the fallback is taken at 39 and 60 columns.
16. I8 — the fake prints the message after 900 ms and exits 510 ms later; the quit case still pins the `v:exiting` guard.
17. A2 — the kept ids' directory is made although another editor makes it, or its parent, at the same moment.
18. A6 — a start that lands between the exit and the fallback's callback wins; the fallback starts nothing behind it.
19. A3 — a fallback while the command-line window is open waits until it closes, then starts and shows in Claude's window.
20. A3 — a fallback whose start fails tells the user once, as an error, with no traceback.
21. A4 — a user in Normal mode elsewhere stays in it under a `TermOpen` `startinsert`; the Insert-mode control.
22. The reviews' pins of correct code: M12's input, the message check's two conditions (P4, P13), the four kept-file rows (P7 to P10), the whole-or-nothing write (P11, P12), the entry helper's fallback check (I1), no equality two empty lists satisfy (I2), the `:cd` case (I7), the kept file read only once it exists (R1).

## Red and green

**The packet** (at its head `57a740e`): 37 cases added or changed — 23 in `tests/test_claude_resume.lua`, 10 in `tests/test_entry_claude_resume.lua`, 1 in `tests/test_layout.lua`, and in `tests/test_claude.lua` the flags pin changed and two malformed-setting rows added. Each once:

**Seen red (15 tests, 18 cases)**, each on its own run before its code. **Corrected by the fix round (I2, the orchestrator's decision 31):** these reds were true at the intermediate states they were run on, but 5 of the 18 are green on `8386aed`'s code, where no session word is passed at all — *resumes the kept session once Claude Code has exited*, *resumes the session an earlier editor kept in the directory*, *starts no new session as Neovim quits*, entry *resumes, in a new Neovim*, and entry *moves a file opened in Claude's window to the file column* — because they compared two lists that were both empty, or sat behind a helper that never checked the fallback happened. The fix round strengthened them (below).
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

**Arrived green (19 cases: 18 new, and the changed flags pin)**, each with its killer, all run (Mutants, below):
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
- Entry: *keeps the session's id under the editor's state directory* — spent by unit 9; M23, which killed it **only by a crash** (`E484` reading a file M23 kept elsewhere), so the packet had no assertion kill for it (R1); the fix round's pin gives it one. *follows :cd, each directory resuming its own session* — spent by `cwd = getcwd()` and unit 3; M30.
- Entry, once both halves of the hand-off were in: *returns Normal mode as the new session's process ends, entered by a window command and i*, *closes Claude's window as the new session's ended terminal is wiped from it*, *refuses Terminal mode in the new session's ended terminal* — M25, M26, M28; *shows the new session's exit on \c, starting nothing* — M26; *leaves the user in the tab they moved to before it* — M27.

**The fix round** — 17 cases added to `tests/test_claude_resume.lua` (40 there now); 16 existing cases strengthened — 7 entry cases by I1 (the helper's six and the tab case), 7 by I2 (six unit, one entry), the `:cd` case by I7 and the state-directory case by R1 — and the two width cases renamed; the entry file's count unchanged at 10. The reds below were run against the round's tests with `lua/` and `plugin/` checked out from the named commit, on Neovim 0.12.5 and 0.11.6, each by assertion on both:

*Seen red on `57a740e`'s code* (10 cases, the same on both versions):
- *keeps the session id when another editor makes its directory at the same moment*, levels `{0}`, `{1}`, `{1, 0}` (A2) — `Left: {}`, `Right: { "<the first start's id>" }`: the id was not kept.
- *is told by a message Claude Code breaks at its terminal's width*, at 39 and 60 (A1; the packet's two width cases, renamed, red once the fake broke the message) — `Failed expectation for one new session id`, `Words: {}`.
- *shows the new session's terminal in every window that showed it* (A1; an existing case whose `vsplit` makes Claude's window 40 columns wide) — `Left: false`, `Right: true`: the failed terminal was never wiped.
- *yields to a session started between the exit and its place being taken* (A6) — `Left: { "<checkout>", {} }`, `Right: { "<…>/resume-refused-gap-elsewhere", { "<the id with a conversation>" } }`: the fallback's new session in the first directory replaced the resume started in the other.
- *starts the new session once the command-line window has closed* (A3) — `Left: { ":", "vim.schedule callback: …init.lua:136: E11: Invalid in command-line window; …" }` (0.11.6: `Error executing vim.schedule lua callback: …`), `Right: { ":", "" }`.
- *tells the user once, as an error, when its new session cannot start* (A3) — `v:errmsg` held `vim.schedule callback: jobstart() cannot run …/nvim` and its traceback, for `""`.
- *leaves a user in Normal mode in a window of their own, whose config enters Insert mode as a terminal opens* (A4) — `Left: { "i", 1002, { "dd" } }`, `Right: { "n", 1002, { "" } }`. Its first form split the child's 80 columns, and on `57a740e`'s code it then failed only on A1's missed match; with the child 160 columns wide it is red for A4's own reason (commit `149b939`).

*Seen red on `8386aed`'s code* — the strengthened cases (I1, I2), which passed there before:
- entry, the five *after a resume with no conversation, before any \c* cases, and *\c enters Terminal mode …* and *leaves the user in the tab …* — `Left: 2`, `Right: 3` at the helper's, or the tab case's, new `eq(#wait_for_starts(fake, 3), 3)`;
- unit, *resumes the kept session once Claude Code has exited*, *resumes the session an earlier editor kept in the directory*, *keeps the session id it resumes*, *keeps the new session's id in place …*, *is not taken for a resume that exits 1 another way …*, *starts no new session as Neovim quits* — `Failed expectation for one new session id`, `Words: {}`;
- entry, *resumes, in a new Neovim, …* and *follows :cd, …* — `Left: 0`, `Right: 1`.

*Arrived green* (pins of correct code, green on `57a740e`'s code as on the round's), each with its killer, run on both versions (Mutants):
- *leaves a user typing in Insert mode in a window of their own typing there* — the attack review's control, by nature; F7.
- *is not taken for a resume that exits 1 showing the message for another id* — M12.
- *is not taken for a resume that shows the message for its own id and exits 0* — P4.
- *is not taken for a new session that shows the message for its own id and exits 1* — P13.
- *counts a kept file that holds no session id as none …*, the rows `'<id>\n'`, `'x<id>'`, the version-1 id, the variant-0 id — P7, P8, P9, P10.
- *keeps the id it could not resume whole when the new id's write is cut short* — P11.
- *leaves no file of its own beside a kept file it cannot replace* — P12.
- Strengthened: *follows :cd, …* — P6; *keeps the session's id under the editor's state directory* — M23; *starts no new session as Neovim quits*, restructured for the fake's new timing — M17r.

## Mutants

Each mutant is its literal edit, applied to the file, run against a copy of its test file narrowed to the group that tests the unit, then restored. The packet's M1–M10b and M22 were measured at `a3a740f`, the last commit before the rebase onto `dev` at `8386aed`; its others at `0c205f9`, whose code and narrowed test groups are the same as `a3a740f`'s. **Every packet mutant and red run was on Neovim 0.12.5, and their loads were not recorded (R5).** The fix round's runs are on both versions, each log headed with the sha, the tree's changes, `nvim --version` and `uptime`. Kinds read from the output.

**The packet's**, `old → new`, in the code as it stood then (`\n` a line end):

| # | Literal edit | Group | Result |
|---|---|---|---|
| M1 | `session_ids.lua`: `  bytes[7] = with_high_nibble(bytes[7], 4)\n` → `` | resume › `start_session()` | killed, assertion, 7 of 7 runs over three passes (the version nibble is 4 by chance 1 in 16) |
| M2 | `session_ids.lua`: `  bytes[9] = with_variant_bits(bytes[9])\n` → `` | same | killed, assertion, 7 of 7 runs over three passes (the variant is right by chance 1 in 4) |
| M3 | `session_ids.lua`: `string.rep('%02x', SESSION_ID_BYTES)` → `string.rep('%02X', SESSION_ID_BYTES)` | same | killed, assertion (11) |
| M4 | `session_ids.lua`: `  local random, failure = vim.uv.random(SESSION_ID_BYTES)\n` → `  local random, failure = string.char(unpack(vim.tbl_map(function()\n    return math.random(0, 255)\n  end, vim.fn.range(SESSION_ID_BYTES)))), nil\n` | same | killed, assertion: *two editors … two ids* |
| M5 | `session_ids.lua`: `  if not is_session_id(kept) then\n    return nil\n  end\n` → `` | same | killed, assertion: the 4 malformed rows |
| M6 | `session_ids.lua`: ` and text:find(SESSION_ID_PATTERN) ~= nil and text == text:lower()\n` → ` and text:find(SESSION_ID_PATTERN) ~= nil\n` | same | killed, assertion: the upper-case row |
| M7 | `session_ids.lua`: `    vim.fn.sha256(working_directory) .. '.txt'\n` → `    vim.fn.sha256('') .. '.txt'\n` | same | killed, assertion (2): per directory; the file-mode case |
| M8 | `init.lua`: `  if not choice.resumed then\n    keep_session_id(settings, choice.id)\n  end\n` → `  keep_session_id(settings, choice.resumed and session_ids.new_session_id() or choice.id)\n` | same | killed, assertion: *keeps the session id it resumes* |
| M9 | `session_ids.lua`: `local OWNER_ONLY = tonumber('600', 8)` → `local OWNER_ONLY = tonumber('644', 8)` | same | killed, assertion: the file mode |
| M10a | `init.lua`: `  local kept, failure =\n    pcall(session_ids.keep_session_id, settings.state_directory, settings.cwd, id)\n  if not kept then\n    vim.notify('aineo: ' .. failure, vim.log.levels.WARN)\n  end\n` → `  session_ids.keep_session_id(settings.state_directory, settings.cwd, id)\n` | same | killed, assertion (2), after the cases wrapped the start in `expect.no_error`; before that, 2 crashes |
| M10b | `init.lua`: `    vim.notify('aineo: ' .. failure, vim.log.levels.WARN)\n` → `` | same | killed, assertion: *cannot keep …, and says so* |
| M11 | `init.lua`: `  local screen = table.concat(vim.api.nvim_buf_get_lines(ended.buffer, 0, -1, false))\n` → `  do\n    return true\n  end\n  local screen = …` (the same line) | resume › *a resume with no conversation* | killed, assertion: *exits 1 another way* |
| M12 | `init.lua`: `  return screen:find(NO_CONVERSATION .. ended.choice.id, 1, true) ~= nil\n` → `  return screen:find(NO_CONVERSATION, 1, true) ~= nil\n` | same, then the whole suite at `0c205f9`, 1110 cases | survived both. **Not equivalent**, as this note, the pull request and commit `57a740e` said it was: a resumed session with a conversation that shows the message for another id and exits 1 separates it, and the fake builds that input (the attack review's `attack-m12` case and the test-integrity review's echo case); the fix round's case kills it (M12, below) |
| M13 | `init.lua`: `  local screen = table.concat(vim.api.nvim_buf_get_lines(ended.buffer, 0, -1, false))\n` → `  local screen = table.concat(vim.api.nvim_buf_get_lines(ended.buffer, 0, -1, false), '\\n')\n` | same | killed, assertion (3): both wraps, the windows case. On the fix round's match a `'\n'` separator is white space, removed before the match: the edit is equivalent there by construction |
| M14 | `init.lua`: `      start_in_place(settings, { id = session_ids.new_session_id(), resumed = false })\n` → `… resumed = true })\n` | same | killed, assertion (4) |
| M15 | `init.lua`: `    local terminal =\n      start_in_place(settings, { id = session_ids.new_session_id(), resumed = false })\n    if settings.on_terminal_replaced then\n      settings.on_terminal_replaced(terminal)\n    end\n` → `` | same | killed, assertion (6) |
| M16 | `init.lua`: `    if settings.on_terminal_replaced then\n      settings.on_terminal_replaced(terminal)\n    end\n` → `` | same | killed, assertion |
| M17 | `init.lua`: `    if vim.v.exiting ~= vim.NIL then\n      return\n    end\n` → `` | same | killed, assertion, 4 of 4 runs on the final test (2 of 4 before it waited for the message) |
| M18 | `init.lua`: `    or not vim.api.nvim_buf_is_valid(ended.buffer)\n` → `` | same | killed, assertion (`v:errmsg`) |
| M19 | `init.lua`: `  if not choice.resumed then\n    keep_session_id(settings, choice.id)\n  end\n` → `  if not choice.resumed and not (previous and previous.choice.resumed) then\n    keep_session_id(settings, choice.id)\n  end\n` | same | killed, assertion |
| M20 | `init.lua`: `  vim.validate('settings.state_directory', settings.state_directory, 'string')\n` → `` | `test_claude.lua` › malformed | killed, assertion |
| M21 | `init.lua`: `  vim.validate('settings.on_terminal_replaced', settings.on_terminal_replaced, 'function', true)\n` → `` | same | killed, assertion |
| M22 | `init.lua`: `  vim.list_extend(command, session_arguments(choice))\n  vim.list_extend(command, arguments.claude_arguments(settings))\n` → the two lines swapped | resume › `start_session()` | killed, assertion: *keeps --allowedTools last* |
| M23 | `plugin/aineo.lua`: `    state_directory = kept_places().state_directory,\n    on_terminal_replaced` → `    state_directory = vim.fn.stdpath('cache'),\n    on_terminal_replaced` | entry › *Claude's session* | killed, 2 assertions and 1 crash (`E484` reading the file where it is not): the crash on *keeps the session's id under the editor's state directory*, the assertions on the other two cases; how many assertions depends on ids an earlier M23 run left in `.tests/cache` (R1). The fix round's pin re-runs it (below) |
| M24 | `plugin/aineo.lua`: `      claude_terminal = terminal\n` → `` (the layout alone follows) | entry › after a resume | killed, assertion: `\c` → `nt` |
| M25 | `plugin/aineo.lua`: `      require('aineo.layout').follow_claude_terminal(terminal)\n` → `` (the root alone) | same | killed, assertion (4) |
| M26 | `plugin/aineo.lua`: `      claude_terminal = terminal\n      require('aineo.layout').follow_claude_terminal(terminal)\n` → `` (no hand-off) | same | killed, assertion (5) |
| M27 | `plugin/aineo.lua`: `      require('aineo.layout').follow_claude_terminal(terminal)\n` → `      require('aineo.layout').open({\n        claude = terminal,\n        report = require('aineo.report').report_buffer(),\n        report_height = config.layout.report_height,\n      })\n` | same | killed, assertion: the tab |
| M28 | `layout/init.lua`: `  state.buffers.claude = terminal\n` → `` | same | killed, assertion (4) |
| M29 | `layout/init.lua`: `  vim.validate('terminal', terminal, is_buffer, false, 'a buffer')\n` → `` | `test_layout.lua` › `follow_claude_terminal()` | killed, assertion |
| M30 | `plugin/aineo.lua`: `    cwd = vim.fn.getcwd(),\n` → `    cwd = kept_places().working_directory,\n` | entry › *Claude's session* | killed, assertion: `:cd` |
| M31 | `init.lua`: `  vim.list_extend(command, session_arguments(choice))\n` → `` | `test_claude.lua` › the flags pin | killed, assertion |

The first commit's blank-stripping match had a mutant (`screen:find(message)` without stripping) that survived both wrap cases, because the fake then printed one line the terminal soft-wrapped; the second commit removed the stripping on a probe of that soft wrap. The fix round restored it (A1).

The fix round did not re-run M1–M10b, M19–M22 and M24–M31: the lines they edit are unchanged since `0c205f9`. M11 and M13–M17 edit lines the round rewrote; the round's re-takes of them are below.

**The fix round's**, on the round's code (`149b939`), each against its narrowed group — *S*, the resume file's `start_session()` group; *R*, its *a resume with no conversation* group; *ES*, the entry file's *Claude's session* group — run on Neovim 0.12.5 and 0.11.6:

| # | Literal edit | Group | 0.12.5 | 0.11.6 |
|---|---|---|---|---|
| F1 | `init.lua`: `  local screen = table.concat(vim.api.nvim_buf_get_lines(ended.buffer, 0, -1, false)):gsub('%s', '')\n  local message = (NO_CONVERSATION .. ended.choice.id):gsub('%s', '')\n  return screen:find(message, 1, true) ~= nil\n` → `  local screen = table.concat(vim.api.nvim_buf_get_lines(ended.buffer, 0, -1, false))\n  return screen:find(NO_CONVERSATION .. ended.choice.id, 1, true) ~= nil\n` (A1 undone) | R | killed, assertion (3): the widths 39 and 60, the windows case | the same |
| F2 | `session_ids.lua`: `  while not made and tries_left > 0 do\n    tries_left = tries_left - 1\n    made, failure = pcall(vim.fn.mkdir, path, 'p')\n  end\n` → `` (A2 undone) | S | killed, assertion (3): the three `LOSE_MKDIR_RACES` rows | the same |
| F3 | `init.lua`: `    if vim.v.exiting ~= vim.NIL or session ~= ended then\n` → `    if vim.v.exiting ~= vim.NIL then\n` (A6 undone) | R | killed, assertion: *yields to a session started between …* | the same |
| F4 | `init.lua`: the `if vim.fn.getcmdwintype() ~= '' then … return\n    end\n` block of `schedule_outside_command_line_window()` → `` (A3's wait undone) | R | killed, assertion: *… once the command-line window has closed* | the same |
| F5 | `init.lua`: `    pcall(start_in_place, settings, { id = session_ids.new_session_id(), resumed = false })\n` → `    true, start_in_place(settings, { id = session_ids.new_session_id(), resumed = false })\n` (A3's `pcall` undone) | R | killed, assertion: *tells the user once, as an error, …* | the same |
| F6 | `init.lua`: `  if in_normal_mode then\n    vim.cmd.stopinsert()\n  end\n` → `` (A4 undone) | R | killed, assertion: *leaves a user in Normal mode …* | the same |
| F7 | `init.lua`: `  if in_normal_mode then\n    vim.cmd.stopinsert()\n  end\n` → `  vim.cmd.stopinsert()\n` | R | killed, assertion: the Insert-mode control | the same |
| F8 | `init.lua`: `    vim.notify('aineo: ' .. tostring(terminal), vim.log.levels.ERROR)\n` → `` | R | killed, assertion: *tells the user once, as an error, …* | the same |
| M12 | `init.lua`: `  local message = (NO_CONVERSATION .. ended.choice.id):gsub('%s', '')\n` → `  local message = NO_CONVERSATION:gsub('%s', '')\n` (the packet's M12, re-taken on the round's match) | R | killed, assertion: *is not taken for a resume that exits 1 showing the message for another id* | the same |
| P4 | `init.lua`: `    or ended.exit_code ~= 1\n` → `` (the test-integrity review's) | R | killed, assertion: *… its own id and exits 0* | the same |
| P13 | `init.lua`: `    not ended.choice.resumed\n    or ended.exit_code ~= 1\n` → `    ended.exit_code ~= 1\n` (the test-integrity review's) | R | killed, assertion: *… a new session that shows the message for its own id and exits 1* | the same |
| P6 | `init.lua`: `local function kept_or_new_session(settings)\n  local kept = session_ids.kept_session_id(settings.state_directory, settings.cwd)\n` → `local first_directory\nlocal function kept_or_new_session(settings)\n  first_directory = first_directory or settings.cwd\n  local kept = session_ids.kept_session_id(settings.state_directory, first_directory)\n`, and `    pcall(session_ids.keep_session_id, settings.state_directory, settings.cwd, id)\n` → `    pcall(session_ids.keep_session_id, settings.state_directory, first_directory or settings.cwd, id)\n` (the test-integrity review's) | ES | killed, assertion: *follows :cd, …* (I7's new line) | the same |
| P7 | `session_ids.lua`: `%x%x%x%x%x%x%x%x%x%x%x%x$'` → `%x%x%x%x%x%x%x%x%x%x%x%x'` | S | killed, assertion: the row `'<id>\n'` | the same |
| P8 | `session_ids.lua`: `  '^%x%x%x%x%x%x%x%x%-` → `  '%x%x%x%x%x%x%x%x%-` | S | killed, assertion: the row `'x<id>'` | the same |
| P9 | `session_ids.lua`: `%-4%x%x%x%-[89ab]` → `%-%x%x%x%x%-[89ab]` | S | killed, assertion: the version-1 row | the same |
| P10 | `session_ids.lua`: `%-4%x%x%x%-[89ab]` → `%-4%x%x%x%-%x` | S | killed, assertion: the variant-0 row | the same |
| P11 | `session_ids.lua`: `  local cut = ('%s.%d.cut'):format(file, vim.uv.os_getpid())\n` → `  local cut = file\n` | R | killed, assertion: *keeps the id it could not resume whole …* | the same |
| P12 | `session_ids.lua`: `  if failure then\n    vim.uv.fs_unlink(cut)\n  end\n` → `` | S | killed, assertion: *leaves no file of its own beside …* | the same |
| P14 | `init.lua`: `local function schedule_outside_command_line_window(callback)\n  vim.schedule(function()\n` → `local function schedule_outside_command_line_window(callback)\n  (function()\n`, and `    callback()\n  end)\nend\n` → `    callback()\n  end)()\nend\n` — the test-integrity review's P14 (the fallback run in `on_exit`, not scheduled), re-taken on the round's structure | R | killed, assertion (2): the command-line window case (`wait_until_wiped` false: run at once from `CmdwinLeave`, the window is still open, so the wait registers itself again and never runs); and the gap case, whose premise — a start between the exit and the fallback — the edit removes | the same |
| M23 | `plugin/aineo.lua`: `    state_directory = kept_places().state_directory,\n    on_terminal_replaced` → `    state_directory = vim.fn.stdpath('cache'),\n    on_terminal_replaced`, with `.tests/cache/nvim/aineo/` removed before and after the run | ES | killed, assertion (2): *keeps the session's id under the editor's state directory* (`Left: 0`, `Right: 1`, R1's new line) and *follows :cd, …*; *resumes, in a new Neovim, …* passes | the same |
| M11r | `init.lua`: `  local screen = table.concat(…):gsub('%s', '')\n` → `  do\n    return true\n  end\n` + that line | R | killed, assertion (2): *exits 1 another way*, *… the message for another id* | not run |
| M13r | `init.lua`: `  local screen = table.concat(vim.api.nvim_buf_get_lines(ended.buffer, 0, -1, false)):gsub('%s', '')\n` → `  local screen = table.concat(vim.api.nvim_buf_get_lines(ended.buffer, 0, -1, false), '\\n'):gsub('%s', '')\n` | R, then the whole suite | **survived** R on both versions, and the whole suite at `149b939` on 0.12.5 (1217 cases, `Fails (0)`, load 87) — **equivalent**: the `'\n'` it adds is white space, which the next call removes on every input | survived R |
| M14r | `init.lua`: `… new_session_id(), resumed = false })\n` → `… new_session_id(), resumed = true })\n` in `start_new_session_in_place()` | R | killed, assertion (6) | not run |
| M15r | `init.lua`: `    start_new_session_in_place(settings)\n` → `` | R | killed, assertion (11) | not run |
| M16r | `init.lua`: `  if settings.on_terminal_replaced then\n    settings.on_terminal_replaced(terminal)\n  end\n` → `` | R | killed, assertion: *hands the new session's terminal to on_terminal_replaced* | not run |
| M17r | `init.lua`: `    if vim.v.exiting ~= vim.NIL or session ~= ended then\n` → `    if session ~= ended then\n` | R | killed, assertion: *starts no new session as Neovim quits*, on the fake's new timing | the same |
| M18 | `init.lua`: `    or not vim.api.nvim_buf_is_valid(ended.buffer)\n` → `` (unchanged since the packet) | R | killed, assertion: *raises no error … TermClose …* | not run |

Every row ran once per version listed, at host loads of 15 to 190 at the runs' starts (each log headed with the sha `149b939`, the tree's changes, `nvim --version` and `uptime`).

## The correction (after the re-measure)

A third implementer agent took PR #73 over for one bounded correction: the re-measure of head `9119a10` (reviewer `neovim-claude-code-reviewer`) confirmed findings 1 to 7, and the orchestrator's brief `orch-correction-t19.md` scoped the correction to 1–5 and 7 (6, the `Makefile` never creating `.tests/state/nvim/`, is the harness's). The fix round's decisions stand, except where the findings refute them.

**Unit list** (stated before the first test): (1) a user in Insert mode's CTRL-O (`niI`) goes on typing; (2) a user in Terminal mode's CTRL-\ CTRL-O (`ntT`) in a terminal of their own goes on typing; (3) under `TermOpen * startinsert`, a user who leaves Visual mode, Select mode or the command line after the fallback is in Normal mode; (4) the same for `q:` left with CTRL-C, CTRL-C; (5) the fallback takes the place of its terminal in a window pinned with `'winfixbuf'`, whose pin stays as the user set it; (6) `\o` after an exit starts in Claude's pinned window; (7) Replace mode and (8) Terminal mode in a terminal of the user's own each go on typing — the branches of `is_typing()` the suite did not hold.

**Adopted fixes**, credited to the re-measure, which built and measured both:
- **FIX-A4b** (findings 1 and 2) as `is_typing()`: no `stopinsert` when the mode matches `^[iRt]`, `^ni` or is `ntT`.
- **FIX-winfixbuf** (finding 3) in `replace_terminal()`: the pin is lifted for the swap alone. One deviation from its literal edit: the pin is read and restored on the window's own value (`nvim_get_option_value`/`nvim_set_option_value` with `scope = 'local'`), since `vim.wo[window]` sets like `:set` and leaves the global value pinned too; the pin case asserts the global value unchanged, and the literal edit is a mutant it kills. `\o` after an exit takes the same path and was broken there too (E1513, a Claude Code left running unshown): pinned in the entry file.
- The docstrings of `replace_terminal()`, `start_new_session_in_place()` and `start_session()` now say what the code does. "Leaves the last session as it was" is corrected rather than made true: it holds for a start that fails before Claude Code has launched; one that fails after — an autocommand of the user's raising as the terminals are swapped — leaves the new Claude Code running as the one session, perhaps unshown, its id perhaps not kept, `on_terminal_replaced` not called.

**Seen red** — 8 cases, each by assertion, on `9119a10`'s code, on 0.12.5 and 0.11.6 alike (written together as the pins of two adopted fixes, each red in its own row of one run):
- *lets a user in a command of Insert mode's CTRL-O go on typing in a window of their own* — `Left: { "i", { "obcne", "two" } }`, `Right: { "i", { "abcone", "two" } }`;
- *lets a user in a command of Terminal mode's CTRL-\ CTRL-O go on typing in a terminal of their own* — `Left: { "t", "bc" }`, `Right: { "t", "abc" }`;
- *leaves a user who leaves a mode in Normal mode in a window of their own, whose config enters Insert mode as a terminal opens*, rows `visual` (`v`), `select` (`gh`), `command-line` (`:`) — each `Left: { "i", { "xone", "two" } }`, `Right: { "n", { "ne", "two" } }`;
- *leaves a user who leaves the command-line window by CTRL-C in Normal mode, whose config enters Insert mode as a terminal opens* — the same;
- *takes the place of its terminal in a window the user pinned with winfixbuf, leaving the pin as the user set it* — `Left: false`, `Right: true` (`wait_until_wiped`);
- entry, *starts on \o after an exit in Claude's window, which the user pinned with winfixbuf* — `Left:` one message, `aineo: E1513: Cannot switch buffer. 'winfixbuf' is enabled`, `Right: {}`.

**Arrived green** — 2 cases, since the round's `mode:sub(1, 1) == 'n'` also left these modes alone; each killed by its mutant on both versions: *leaves a user typing in Replace mode in a window of their own typing there* — `no-R`; *leaves a user typing in Terminal mode in a terminal of their own typing there* — `no-t`.

**Mutants** — each its literal edit to `lua/aineo/claude/init.lua` at `3bddaec`, applied from a pristine copy (each edit matching exactly once), run against its narrowed group, restored and compared byte for byte; one at a time, on 0.12.5 then 0.11.6. Groups: **M** — the ten mode cases of *a resume with no conversation*; **P** — the pin case; **EP** — the entry pin case; **R** — every case of *a resume with no conversation*, 27. All kills are assertions, read from Left/Right.

| # | Literal edit | Group | 0.12.5 | 0.11.6 |
|---|---|---|---|---|
| A4-back (the round's condition put back) | `  local was_typing = is_typing(vim.api.nvim_get_mode().mode)\n` → `  local was_typing = vim.api.nvim_get_mode().mode:sub(1, 1) ~= 'n'\n` | M | killed (6): `niI`, `ntT`, the three left-mode rows, `q:` | the same |
| no-ni | `mode:find('^ni') ~= nil or ` → `` | M | killed: `niI` | the same |
| no-ntT | ` or mode == 'ntT'` → `` | M | killed: `ntT` | the same |
| no-R | `'^[iRt]'` → `'^[it]'` | M | killed: Replace (`{ "n", { "one", "two" } }`) | the same |
| no-t | `'^[iRt]'` → `'^[iR]'` | M | killed: Terminal mode (`{ "t", "bc" }`) | the same |
| winfixbuf-out (FIX-winfixbuf taken out) | `    local pin = { win = window, scope = 'local' }\n    local pinned = vim.api.nvim_get_option_value('winfixbuf', pin)\n    vim.api.nvim_set_option_value('winfixbuf', false, pin)\n    vim.api.nvim_win_set_buf(window, replacement)\n    vim.api.nvim_set_option_value('winfixbuf', pinned, pin)\n` → `    vim.api.nvim_win_set_buf(window, replacement)\n` | P; EP | killed: P `false`; EP the E1513 message | the same |
| winfixbuf-literal (the re-measure's own edit) | the same five lines → `    local pinned = vim.wo[window].winfixbuf\n    vim.wo[window].winfixbuf = false\n    vim.api.nvim_win_set_buf(window, replacement)\n    vim.wo[window].winfixbuf = pinned\n` | P | killed: `{ "terminal", true, true }` (the global value pinned) | the same |
| no-restore | `    vim.api.nvim_set_option_value('winfixbuf', pinned, pin)\n` → `` | P | killed: `{ "terminal", false, false }` | the same |
| P14 (the round's re-take, re-run) | `local function schedule_outside_command_line_window(callback)\n  vim.schedule(function()\n` → `local function schedule_outside_command_line_window(callback)\n  (function()\n`, and `    callback()\n  end)\nend\n` → `    callback()\n  end)()\nend\n` | R | killed (3): the gap case; the command-line window case and the new `q:` CTRL-C case (`wait_until_wiped` false) — both only through the second edit, the re-arm run at once while the window is open | the same |
| P14b (the re-measure's) | `  schedule_outside_command_line_window(function()\n    if vim.v.exiting ~= vim.NIL or session ~= ended then\n      return\n    end\n    start_new_session_in_place(settings)\n  end)\n` → `  local function fallback()\n    if vim.v.exiting ~= vim.NIL or session ~= ended then\n      return\n    end\n    start_new_session_in_place(settings)\n  end\n  if vim.fn.getcmdwintype() ~= '' then\n    schedule_outside_command_line_window(fallback)\n  else\n    fallback()\n  end\n` | R | killed (1), only by the gap case, whose premise the edit removes: `Left: { <checkout>, {} }` | the same |

**The residual, measured** (`.tests/t19c-residual.lua`, a probe, not a case): a fallback that lands on a command line begun from Insert mode's CTRL-O. After `i<C-o>:` then `<Esc>` with a `startinsert` config, `i<C-o>:` then `<Esc>` without one, and `i<C-o>:let g:ran = 1` then `<CR>` without one, the keys `abc` gave `obcne` on the correction's code — the user was back in Normal mode — and `abcone` with the round's condition put back (A4-back-residual), on both versions. The re-measure read it under a `startinsert` config only; it holds without one, and on `<CR>` as on `<Esc>`, so `<C-o>:w<CR>` typed as the fallback lands leaves any user in Normal mode. Recorded as a limit; the re-measure's `ModeChanged` variant, which would close it, was not built.

**Records corrected**: the SR3 lookalike (finding 4), the mode reading (findings 1, 2), the orchestrator's timing reading (finding 7), the P14 thread (finding 5); the help's two sentences (finding 7) — its "a second or two" was the round's decision 16, the orchestrator's, taken from the `w*.txt` elapsed times before the timing runs, and wrong.

## Verification

- **The packet, before the rebase**, at `a3a740f` on `e0582e0` (the tree `0a6b5bd`'s code): `make test` 1110 cases, `Fails (0)`, exit 0, on 0.12.5 (load 75 at the start) and 0.11.6 (load 81), each log headed with `uptime` and `nvim --version`. The baseline 1074 (`evidence/baseline-0a6b5bd.txt`) plus 36 new cases.
- **T17 merged into `dev` during the packet** (PR #68, 2026-09-27 06:22 UTC), so the brief's merge check against `origin/bugfix/t17-report-paths` was superseded: before the merge, `git merge-tree --write-tree` against its head `2598e7d` printed `c5662e6`, no conflict; after it, the branch was rebased onto `dev` at `8386aed` with no conflict.
- **The packet, after the rebase**, at `58d8320`, whose code is the pull request's first head `57a740e`'s (the note was committed after): `make test` 1200 cases, `Fails (0)`, exit 0, on 0.12.5 (load 96) and 0.11.6 (load 29). `dev`'s own count at `8386aed` was not run; 1200 − 36 = 1164. `tests/test_doc.lua` is among them, on the merged help.
- `make lint`: clean. The deep-require check prints only lines inside their own homes; this change adds one, `lua/aineo/claude/init.lua` requiring `aineo.claude.session_ids`.
- The `Makefile` clean-up: a probe file put in `.tests/state/nvim/aineo/claude-sessions/` was gone after `make test_file` (by hand).
- **The fix round**, at `149b939`, whose code, tests and help are the pushed head's (the commit after it changes only this note): `make test` 1217 cases, `Fails (0)`, exit 0, on 0.12.5 (load 90 at the start) and on 0.11.6 (load 41), one after the other, each log headed with the sha, `nvim --version` and `uptime`. 1217 = the packet's 1200 + the round's 17 new cases in `tests/test_claude_resume.lua` (23 → 40); `tests/test_entry_claude_resume.lua` stays at 10. `make lint`: StyLua and selene clean (0 errors, 0 warnings). The deep-require check prints 25 lines, each inside its own home; the round adds none. `tests/test_doc.lua` (36 cases) is among the suite's cases, on the widened help.

- **The correction**, at `3bddaec`, whose code, tests and help are the pushed head's (the note's commit after it changes only this note): `make test` 1227 cases, `Fails (0)`, exit 0, on 0.12.5 (load 32 at the start) and on 0.11.6 (load 36), one after the other, each log headed with the sha, the tree's changes, `nvim --version` and `uptime`. 1227 = the round's 1217 + 9 new cases in `tests/test_claude_resume.lua` (40 → 49) + 1 in `tests/test_entry_claude_resume.lua` (10 → 11). `make lint`: StyLua and selene clean. The deep-require check prints 25 lines, each inside its own home; the correction adds none. `.tests/state/nvim/` was made before the first run (the re-measure's finding 6).

## Decisions & reasoning

1. **The session words go first** (`--resume`/`--session-id` before `--mcp-config`), so `--allowedTools` stays last (`arguments.lua`'s docstring); pinned by "puts the session first and keeps --allowedTools last".
2. **A new id is kept after the job has started**, not before: a start that raises (`claude.cmd` not executable) keeps nothing, as `start_session()`'s docstring promises ("leaves the session as it was").
3. **The fallback is scheduled from `on_exit`**, not run inside it, as the brief review's prototype did; the check reads the terminal inside `on_exit`, while it is valid.
4. **`v:exiting` guards the scheduled start**: measured, a scheduled callback runs inside a `VimLeavePre` handler's `vim.wait()`, and `jobstart()` works there (a headless probe; `v:exiting` read `0`). Before the guard, the quit test saw the fallback run during quit once in three runs, and the guard's mutant was killed 2 of 4 until the test waited for the message (decision 6).
5. **An unreadable kept file counts as none**: a directory where the file should be made `kept_session_id()` raise (`text` nil) — found by a test written for it, fixed.
6. **The packet's fake took 1.4 s to exit**, Q8 G's measured time, with its message at once: a shorter chosen 500 ms let the quit test land after the exit on some runs. The fix round replaced it with the measured timing (decision 12).

The fix round's, each the orchestrator's decision for the round, adopted from the review that built and measured it and credited in the commits:

7. **A1: the message is matched with every white space removed**, on the terminal's lines and on the message alike — the attack review's fix. The fake draws the message as 2.1.283 does at its terminal's width, read with `stty size` when it prints.
8. **A2: the kept ids' directory is made with a retry**, up to once for each directory of its path, as the report records' is — the attack review's fix, pinned as the records' retry is (`LOSE_MKDIR_RACES`).
9. **A6: the fallback yields when `session ~= ended`** — the attack review's fix. Its case starts the gap session in another directory, whose kept session has a conversation: in the same directory the old code's replacement often hung the gap session up before the fake recorded it, and the red was not certain.
10. **A3: the fallback waits for the command-line window to close**, re-scheduled from a once `CmdwinLeave` and checked again then, and **its start runs in `pcall`, with one `vim.notify` at the error level on failure** — the attack review's fix, split into `schedule_outside_command_line_window()` and `start_new_session_in_place()`.
11. **A4: `stopinsert` when the mode was Normal before the start** — the attack review's fix; the Insert-mode control is kept as a case.
12. **I8: the fake prints the message 900 ms after it starts and exits 510 ms later**, the shortest of the orchestrator's three measured runs (message at 0.9 to 1.4 s, exit 510 to 520 ms after it, 60 columns, polled every 10 ms, host load 83 to 152). The quit case registers its `VimLeavePre` wait before the resume and quits as soon as the message is on screen, so that the exit comes as Neovim quits; it says so.
13. **A7: the help says `claude.cmd` must not hold `--continue`, `--resume` or `--session-id`**, with 2.1.283's refusal; the boundary widened to that sentence.
14. **A5: recorded as a limit, not fixed** (the orchestrator's decision).

## Readings for the MVP review

The orchestrator's readings, as the brief gives them:
- SR3's new session in place of one Claude Code no longer has — D23 says only that a directory with none gets a new one;
- the id is kept from the moment the session starts, whether or not anything is typed;
- a directory's kept id is never removed, as the drafts are not (MR125);
- two editors in one directory resume the same session: Q8 measured two Claude Codes started on one id at once, neither refused, with no message sent to either (a limit);
- SR3's fallback is visible: the user sees "No conversation found with session ID: …" for 1–2 s at every start that follows an untyped session, before the new one replaces it (as the orchestrator's timing runs on 2.1.283 measured it: nothing for 0.9–1.4 s, then the message for about half a second; the whole failed start takes 1.4–2.3 s — the help says so since the correction);
- Claude's session follows the directory Claude Code starts in (`settings.cwd`), while the Reports and the draft stay with the editor's first working directory (`kept_places()`): after a `:cd` the two can differ;
- after SR3's fallback the user is in Normal mode in the new terminal, even when they were typing in the one that failed (T21's EX1 at its exit); `\c` puts them in the new prompt;
- D23's own: a session switched inside Claude (`/clear`, `/resume`) is not followed.

The author's:
- **An id that cannot be kept warns once per start** and the session starts on it anyway; the next start then starts another new session.

The fix round's:
- **A fallback while the command-line window is open waits until it closes**; the failed terminal and its message stay on screen meanwhile (decision 10).
- **The fallback keeps a typing user typing, and keeps any other user out of Insert mode** (decision 11, as the correction left it): a user typing in Insert, Replace or Terminal mode, or giving a command from Insert mode's CTRL-O or Terminal mode's CTRL-\ CTRL-O, goes on typing where they are; a user in Normal, Visual or Select mode, on the command line or in the command-line window is out of Insert mode once back in Normal mode, even under a `TermOpen` `startinsert`. One exception, a limit below: a command line begun from Insert mode's CTRL-O ends in Normal mode. **Corrected by the correction (the re-measure's findings 1 and 2):** this said "The fallback leaves the user's mode as it was … one typing in Insert mode elsewhere goes on typing there"; the round's code threw a user out of Insert mode's CTRL-O and Terminal mode's CTRL-\ CTRL-O, and, under a `startinsert` config, left a user in Visual or Select mode or on the command line in Insert mode.
- **A start that lands between Claude Code's exit and the fallback wins**: the fallback then starts nothing, and the start that won falls back by itself if it too finds no conversation (decision 9).
- **A replacement whose failed terminal is in no window starts at 5 rows × 80 columns until it is shown** (A5, the orchestrator's decision 6): Claude's window closed during the second or two before the fallback, or a `TermClose` handler wiping the terminal from a scheduled callback, leaves readiness at `starting`, and Send refuses, until `\c` shows the terminal.

## Task lines

The wave holds its marks (rule 6). The line T19 would take:

- [X] T19 — Claude resumes aineo's own last session in the working directory (D23): each session aineo starts gets an id of its own, kept per working directory under `stdpath('state')/aineo/claude-sessions/`, and the next start there resumes it; a resume Claude Code finds no conversation for is replaced by a new session, handed to the composition root and the layout — regular.

## Limits

- **Not measured: an id whose conversation existed and is gone.** SR3 assumes Claude Code exits as it does for an id it never had (Q8 A, G); if it does otherwise, that exit shows as another exit, and the id stays.
- **`--resume` with `--mcp-config`, `--append-system-prompt` and `--allowedTools` together was not measured** on the real CLI; each is documented, and the fake only records them.
- **Two Claude Codes on one conversation** (two editors in one directory): Q8 E measured both start, neither refused; nothing sent to either.
- **What Claude Code 2.1.283 draws for the message below the id's own width (36 columns) was not measured**, nor what it does with keys in the half second between the message and its exit; the fake gives the id a row of its own there, and is deaf then.
- **A directory where the kept file goes stays unfixed** (R3): it counts as no session, but it cannot be replaced, so every start in that working directory warns and starts a new session, which is never resumed. The pull request's first body said it "is replaced"; it is not.
- **A replacement whose failed terminal is in no window starts at 5 rows × 80 columns** until it is shown (A5; the reading above).
- **A `claude.cmd` holding `--continue` or `--resume` never starts Claude Code** (A7): Claude Code 2.1.283 refuses `--session-id` beside either and exits 1; the help says so, the health check does not.
- **The whole-or-nothing write**: the packet's note said "a cut-short write is not driven"; the fix round drives it, stubbing `vim.uv.fs_write` in the child to write 10 bytes of the new id (I5), and pins that no `.cut` file is left behind a replacement that fails.
- **A fallback on a command line begun from Insert mode's CTRL-O ends in Normal mode** (FIX-A4b's residual, the correction): `i<C-o>:` then `<Esc>` or `<CR>`, with or without a `TermOpen` `startinsert`, leaves the user in Normal mode, their next keys run as commands; the round's code returned them to Insert mode. `nvim_get_mode()` reports such a command line as `c`, like any other. Measured on both versions; the re-measure's `ModeChanged` variant was not built.
- **A start that fails after Claude Code has launched** (an autocommand of the user's raising as the terminals are swapped) is told once, but leaves the new Claude Code running as the one session, perhaps in no window, its id perhaps not kept; `start_new_session_in_place()`'s docstring says so. Not driven by a test.
- **The Makefile clean-up** is verified by hand (a probe file in `claude-sessions/` gone after `make test_file`), not by a test. A mutant that keeps ids elsewhere — M23, under `.tests/cache` — leaks them into later runs; the fix round cleared `.tests/cache/nvim/aineo/` before and after its M23 runs, and the `Makefile` is not changed for a mutant's leak.

## Open threads

- **The `\o` race the author named** — a start landing between Claude Code's exit and the scheduled fallback — is closed by the fix round's decision 9 (A6).
- **The warning a scheduled fallback shows while the user types** (a new id that cannot be kept, told from the fallback's callback) stays open, as the author left it.
- **`:checkhealth aineo` does not warn about session flags in `claude.cmd`** (A7): `lua/aineo/health.lua` is outside T19's boundary.
- **P14**, the fallback run at once rather than scheduled, survived everything the test-integrity review built on the packet's code, where no tested state told the schedule apart. On the round's code the command-line window's wait separates it: run at once from `CmdwinLeave`, the window is still open and the new session never starts, and the round's case kills it by assertion on both versions (the round's mutant table). It is pinned, not open. **Corrected by the correction (the re-measure's finding 5):** the round's P14 changes two things — the first check and the `CmdwinLeave` re-arm both run unscheduled — and the command-line window case kills it only through the second, the re-arm run at once while the window is still open. **P14b**, the review's meaning alone (the first check run directly in `on_exit`, the re-arm left scheduled), is killed only by the gap case, whose premise — a start between the exit and the fallback — the edit removes. So the schedule's only observable effect is the gap that A6's guard covers, and no behaviour the spec asks for pins it. Both are rows of the correction's mutant table, as literal edits.

## Commits

Recorded after the merge, by the orchestrator's knowledge pass. PR #73 merged by rebase on 2026-09-27 (17:33 UTC); `dev` `384c084`, released as `v0.2.9`.

| Branch | `dev` | Subject |
|---|---|---|
| `c1c0f46` | `8819340` | Resume aineo's own last Claude session per working directory |
| `2a50708` | `e4c6370` | Match the no-conversation message on the joined rows as they are |
| `d7b5249` | `d5c6208` | Pin the fallback's refusal while Neovim quits on every run |
| `58d8320` | `09a157c` | Assert that a start on an id it cannot keep raises nothing |
| `57a740e` | `77a286e` | Record T19's session: the Claude session resumed per directory |
| `2568764` | `d173b86` | Match the no-conversation message as Claude Code breaks it |
| `163298a` | `7d0c948` | Say in the help what the resume needs, shows and how to leave it |
| `149b939` | `0bfe605` | Keep the mode cases' message on one row of Claude's window |
| `9119a10` | `77d98f1` | Correct T19's session record after PR #73's reviews |
| `aaacc49` | `ce6d4d4` | Keep typing users typing and take pinned windows in the fallback |
| `8b15194` | `63c8f5f` | Say in the help how long the failed resume shows and what repeats |
| `3bddaec` | `1aab7d9` | Pin the fallback's Replace and Terminal typing on their own |
| `6d5a013` | `384c084` | Record T19's correction after PR #73's re-measure |
