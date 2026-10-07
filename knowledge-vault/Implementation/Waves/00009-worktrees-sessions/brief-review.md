# Brief review — wave 9 (`00009-worktrees-sessions`)

**Reviewer:** `reviewer`, dimension **brief**, Opus. **Head:** `origin/knowledge/w9-plan-amended` `ed83367` (PR #132), on `origin/dev` `f98bd9d`, checked out detached. `git diff --stat f98bd9d ed83367 -- lua plugin tests scripts doc Makefile` prints nothing, so every code fact was read at `f98bd9d`. **Resource:** `review_brief_w9`.

**Subject:** `plan.md`; the five briefs; `evidence/w9-probes.txt` and `evidence/w9-real-claude-sessions.txt`; the proposal note; the v1 plan note's rows D31–D41, T35–T39 and the dated notes on D17, D19, D23, C6, C11 and C15. I also read the drafter's and the amender's reports, but only to see where to look.

**Question:** would an implementer acting on any of these briefs be misled by anything in it?

**How I checked:**
- **Line references.** I opened every path, symbol and line range the briefs cite at `f98bd9d` (a helper that prints line ranges, plus `grep`).
- **Counts.** I counted each test file's cases with mini.test's own `collect()`, without running them. The total is **60 files, 1929 cases**, the plan's baseline.
- **The planning probes.** I re-ran A1, A2, A3, B1 and B3 from `evidence/w9-probes.txt` on Neovim 0.12.5 and git 2.50.1, under the evidence's own runner (every XDG directory and `CLAUDE_CONFIG_DIR` in scratch, git hermetic).
- **New probes.** I wrote three for this review:
  - `t35-probe`: a fake `claude` that runs the `--settings` `SessionStart` hook the way Claude Code does — `sh -c`, the JSON on stdin, its own session — inside a terminal of a listening editor, with a second editor beside it.
  - `t38` and `t38b`: worktree listings in fixture repositories.
- **Help merges.** I merged worst-case edits of the stage-1 help fences with `git merge-file`.
- **What I did not run:** the real `claude`. Nothing under `~/.claude` was read or written. I ran no whole suite and no test file.

---

## Verdicts

| Brief | Verdict |
|---|---|
| T35 | **Dispatch after these corrections.** T35-1, T35-2 and T35-3 are required. |
| T36 | **Dispatch after these corrections.** T36-1 and T36-2 are required. |
| T37 | **Dispatch after these corrections.** T37-1 and T37-2 are required. |
| T38 | **Not as written.** Dispatch after T38-1 to T38-5, at its stage-2 amendment. |
| T39 | **Not as written.** Dispatch after T39-1 to T39-5, at its stage-2 amendment. |

The single most important correction is **T35-1 / T39-2: T19's fallback.** After it, Claude Code runs on a new id, but no home is ever told that id. Reports, the changes pane's base and marks, and Input's draft go on being kept under a dead session. D38 names exactly this case.

---

## T35 — `brief-t35-session-switch.md`

**T35-1 — MISSING (high): the new session id of T19's fallback reaches no home.**
- **The code.** When a resume finds no conversation, `start_new_session_in_place()` starts a new id through `start_in_place()`. It then hands `settings.on_terminal_replaced` the terminal and nothing else (`lua/aineo/claude/init.lua:319–333`, `345–355`). The composition root's handler only re-points the terminal (`plugin/aineo.lua:222–225`).
- **What the brief builds.**
  - A2: the followed id is "from each start, the id aineo started Claude Code on" (brief:27). So the fallback's new id becomes the followed one silently.
  - The receiver: "a `SessionStart` whose id is the one the session follows does nothing more" (brief:23). So the new Claude Code's `SessionStart(startup, Y)` calls nothing back either.
- **The scenario, which D38 names: "a `/clear` session in which nothing was sent falls back to a new session".**
  1. `/clear`, then exit without sending anything. X, the `/clear` session, is kept for the directory.
  2. The next start resumes X. T39 tells the three homes X.
  3. Claude Code prints "No conversation found" and exits. The fallback starts Y and keeps Y.
  4. Every report, the changes pane's base and marks, and Input's draft stay under X.
  5. The start after that resumes Y, with an empty Report, an empty draft and a new base.
- **Correction:**
  - T35: when a start replaces the session followed — the fallback included — call `on_session_switched(Y, 'startup', X)`, or say in the brief that the composition root must ask "which session" from `on_terminal_replaced`.
  - T35's test list: the fake with `AINEO_FAKE_CLAUDE_CONVERSATIONS` finding no conversation, then the new id followed and told.
  - T39 likewise (T39-2).

**T35-2 — MISSING (medium-high): the hook's command is one shell string, and every word in it must be quoted.**
- **What the brief says.** The relay is "run as aineo's MCP server is run — `<v:progpath> --headless --clean --cmd 'set noloadplugins' -l <relay> <editor address>`" (brief:21).
- **Why that shape cannot be copied.** The MCP server is given as `command` and an `args` array (`lua/aineo/mcp/init.lua:28–35`). A command hook has only a `command` string, which a shell runs.
- **Measured (`t35-probe`):**
  - **S5n.** A program path and a relay path holding a space and a `'`, joined with spaces: `hook_code = 127, hook_stderr = "/bin/sh: <here>/dir: No such file or directory"`. Nothing was notified, and no switch would ever be heard.
  - **S5.** The same paths, each word POSIX-quoted (`'…'`, with `'` written `'\''`): the editor got `{ "SessionStart", "…08", "startup" }`.
- **Correction:** say that the hook's `command` is a single string run by a shell, and that every word is quoted. Add a test with a program path and a relay path that each hold a space and a quote.

**T35-3 — MISSING (medium): the fake must hand the hook the `NVIM` it inherited, and the relay test for mutant 5 must set `NVIM` itself.**
- **Why.** The fake is an `nvim -l` process, and it has a server of its own. `vim.system()` sets `NVIM` to the spawning Neovim's `v:servername` (`$VIMRUNTIME/lua/vim/_core/system.lua:271–274`, `base_env()`).
- **Measured (`t35-probe`):**
  - **S1b.** A fake that spawns the hook with no `env` gave the hook `relay_env_nvim = "/tmp/nvim.<user>/…/nvim.72950.0"`, the fake's own server, not the editor's. M3 (the hook inherits Claude Code's `$NVIM`) is then not modelled.
  - **S1c.** Under that fake, mutant 5 (the address read from `$NVIM`) notified the fake itself: `A saw {}  B saw {}`. The mutant "dies" for a reason that has nothing to do with the property.
  - **S2m.** Only with the fake passing `env = { NVIM = <inherited> }`, and the hook's `NVIM` set to another editor, does the mutant show its real failure: `A saw {}  B saw { "SessionStart", … }`.
  - A relay spawned straight from a test file's Neovim likewise sees that Neovim's own address (root `CLAUDE.md`).
- **Correction:**
  - The fake runs each hook with `env = { NVIM = os.getenv('NVIM') }`, as Claude Code passes its environment through (M3).
  - Add two tests: "a relay run where `$NVIM` names another editor, or is unset, tells the editor on its command line".

**T35-4 — CONFIRMED (medium): A1's last sentence turns background forks into switches.**
- **A1 says:** "A `SessionStart` with a new id and no `SessionEnd` before it is still a switch".
- **The documentation the evidence quotes** lists `fork` as the source of "`--fork-session` with `--resume` or `--continue`, **the `/fork` background copy**, `/branch`, or **a conversation you move to the background**" (`w9-probes.txt`, D-docs, SessionStart matchers).
- **What was measured.** M1 measured `/branch` only. Whether a background copy fires `SessionStart(fork, <new id>)` in the foreground process, with no `SessionEnd`, while the terminal stays on its own session, was not measured. Under A1 it would flip every pane to a session the terminal is not on. Subagents were not measured either.
- **Correction:**
  - List `/fork`, background moves and subagents under T35's *Not measured*.
  - The orchestrator should decide whether a switch needs the followed id's `SessionEnd` first. M1 found it before every real switch.
  - Report the choice with A1.

**T35-5 — CONFIRMED (low-medium): mutant 6 predicts something that cannot happen.**
- **The mutant's prediction:** "a malformed `session_id` is kept and the next start passes it to `--resume`" (plan:169).
- **Why it cannot.** `kept_session_id()` refuses a kept file that holds anything but a well-formed id (`lua/aineo/claude/session_ids.lua:82–99`). So the next start makes a new session; it never passes the malformed id.
- **What the mutant really does:** it follows the malformed id (the callback fires), and it overwrites the good kept id.
- **Correction:** reword the observable to "the callback fires with it, and the next start no longer resumes the session kept before".

**T35-6 — CONFIRMED (low): mutant 4 is not a literal edit, and no test in the brief exercises it.**
- **The mutant:** "`--settings` left out when `claude.cmd` names a wrapper (any argument order change)" (plan:167). It names no edit, and no test in the list uses a wrapper.
- **Correction:** "`--settings` placed after `--allowedTools`". The brief's first test ("before `--allowedTools`") kills it.

**T35-7 — MISSING (low-medium): a help paragraph this packet makes false lies outside its fences.**
- **The paragraph.** `doc/aineo.txt:680–691`, the first paragraph of *aineo-report*: "aineo starts Claude Code with four additions of its own". `--settings` is a fifth.
- **Why nobody can fix it.** It is in neither of T35's fences, and T36 owns only lines 841–846 of that section.
- **Correction:** give T35 lines 680–691 as a third fence. They are 150 lines from T36's paragraph. Name too the requirements line, `doc/aineo.txt:46–49`, which says which Claude Code versions the behaviour was measured on; M1–M8 used 2.1.292.

**T35-8 — MISSING (low): the brief does not say how "an exited Claude Code's late hook" is to be recognised (brief:26).**
- **Why it matters.** The notification carries the event, the id and the source, and nothing that names which Claude Code sent it. After a restart, a late `SessionStart` from the old process cannot be told from the new one's.
- **Correction:** name the means, for example a per-start token on the relay's command line (the terminal's job id), dropped when it is not the running start's.

**T35-9 — CONFIRMED (low): a citation points at evidence that does not hold the claim.**
- **The claim:** "Claude Code adds a SessionStart hook's stdout to Claude's context (D-docs)" (brief:21).
- **The evidence:** the D-docs section of `w9-probes.txt` quotes no such sentence (`grep -n -i 'stdout\|context'` finds none in D-docs).
- **Correction:** add the quote to the evidence, or cite the hooks page itself.

**T35-10 — MISSING (low): the relay's behaviour when its editor cannot be reached is not specified.**
- **Measured (S7).** A relay whose editor is gone exits 1 with `E5113: … connection failed: connection refused` and a stack trace on stderr. That is what an exit-time `SessionEnd` can meet.
- **Correction:** say that an editor the relay cannot reach makes it exit 0, quietly.

**T35-11 — MISSING (low): the brief says only a *managed* `disableAllHooks` silences aineo's hooks.**
- **What the brief says:** "under a managed `disableAllHooks`".
- **What D-docs quotes:** "the `disableAllHooks` setting can't disable managed hooks from outside managed settings". That reads as: a `disableAllHooks` the user sets turns off every non-managed hook, aineo's `--settings` hooks presumably included. Not measured.
- **Correction:** the LIMITS text should say "a `disableAllHooks` in any of your settings".

**T35-12 — CONFIRMED (low): two small inaccuracies.**
- "`aineo.claude` keeps requiring `aineo.config` and `aineo.mcp` alone" (brief:85). It requires neither today (`lua/aineo/claude/init.lua:4–8`); "at most" is meant.
- "(for T39 and the health check)" (brief:27) names a consumer that no packet builds: `lua/aineo/health.lua` reads no session and is in no boundary.

**T35-13 — MISSING (low): the fake's line leaves two things unsaid.**
- It gives the `SessionStart` sources but not the `SessionEnd` reasons: `clear` for `/clear`, `resume` for both `/resume` and `/branch`.
- Only the exit by keys was measured to send `prompt_input_exit`. The fake should send nothing on a hangup or at its lifetime's end.

**REFUTED for T35 — checked and found true:**
- **Line references:** every one is right at `f98bd9d` — `Settings` 14–21, `CHILD_ENVIRONMENT` 26, `session` 32, `validate_settings` 112–128, `kept_or_new_session` 174–180, `session_arguments` 187–189, `keep_session_id` 196–202, `launch` 238–259 (244, 251, 254), `start_in_place` 357–370, `start_session` 423–429, `session_status` 441–452, the status-line functions 474–476 and 484–486; `session_name.lua` (173 lines, 91–100, 110–118, 165–171); `session_ids.lua` 13–14, 78–80, 89, 177; `arguments.lua` 30–43; `mcp/relay.lua` (21 lines); `plugin/aineo.lua` 211–234 and 218; `fake_claude.lua` `MODES` 95–112.
- **`--settings`** appears nowhere under `lua`, `plugin` or `tests`.
- **Counts:** `tests/test_claude.lua` 114, `tests/test_claude_resume.lua` 49, `tests/test_entry_claude_resume.lua` 11, `tests/test_mcp_relay.lua` 30.
- **B1 reproduced:** the editor saw the notification 17–21 ms after the relay's spawn, and the relay ended in 18–22 ms. `--remote-expr` took 9–12 ms. (The first re-run failed: see W-3.)
- **The relay by argument is safe in every case asked:**
  - **Started by a terminal's child (S1):** the editor got the event; stdin is a pipe; `AINEO_CHILD=1`; stdout is empty.
  - **`$NVIM` naming another editor (S2):** A was told, B was not.
  - **`$NVIM` unset (S3):** A was told.
  - **Two editors at once (S4):** each saw only its own id.
  - **An editor started with `NVIM=/outer/…` (S8):** its terminal child sees the editor's own address.
  - **A notification to a Neovim without aineo (S9):** nothing raised there, `v:errmsg` empty.
- **A notification returns at once from a busy editor (S6):** 21 ms, where a request took 1949 ms.
- **The fake's event order** matches the evidence, and so does the reading of M1–M8: `SessionEnd`, then `SessionStart` about 0.1 s later, on `/clear`, `/resume` and `/branch`; `SessionStart(compact)` alone; the stale id in the MCP server; nothing at all in an untrusted folder; `/resume` waiting for the hook.

---

## T36 — `brief-t36-report-sessions.md`

**T36-1 — MISSING (medium): the brief never says its entry points may be called before the homes have their environment, or before Input is kept.**
- **The order on the first `:Aineo open`.** `started_claude_terminal()`, where T39 will tell the homes the session, runs before `give_report_environment()`: line 290 evaluates `started_claude_terminal(config)` as an argument of `arrangement()`, whose first line (273) gives the environment. It runs before `keep_input_draft()` (291) too, which gives the draft home its environment (182–184) and hands it Input.
- **What each home does then.** The report home raises without an environment (`lua/aineo/report/init.lua:64–69`). The draft home indexes `environment` in `draft_file()`'s callers (`lua/aineo/draft/init.lua:160`, `278`).
- **Correction:**
  - State that both follow entry points accept a session before `set_*_environment()` and before `keep_draft()`: the session is kept, `keep_draft()` restores that session's draft, and the moves run when the environment arrives. Add one test each, including "told a session before Input is kept, `keep_draft()` restores that session's draft".
  - Or have T39 give the environments first (T39-3).

**T36-2 — MISSING (medium): textlock.**
- **Why it applies.** The swap of Input's text and of the Report's lines is a buffer change made from T35's scheduled callback. The Learning *A scheduled callback can run under textlock, where Neovim refuses a buffer change with E565* names "a report rendered into the Report, a draft restored into Input" as where it applies again. T37's brief cites it; T36's does not.
- **Correction:** cite it, say what a refused swap does (try again at `SafeState`, as `scratch.write_text()` does), and test one hold.

**T36-3 — CONFIRMED (low-medium): mutant 2 survives unless a test plants a directory file.**
- **The mutant:** "The directory's records moved on every start instead of the first: a second session's records replaced" (plan:175).
- **Why it survives the listed test.** The brief's own guard is "When both exist, neither is touched". And after the first move the directory's file is gone. So the test "a later follow of another session moves nothing" passes for the mutant unless it re-creates the directory's file before the later follow.
- **Correction:** say so in the test, and reword the mutant: "a directory file present at a later follow is moved into the second session". The same holds for the draft's A6 analogue.

**T36-4 — CONFIRMED (low): one count is stale.**
- The brief says `tests/test_report_buffer.lua` went "from 67 cases to 97 at its packet's push". At `f98bd9d` it has **101**: T34's fix round added 4 (T34's session note:133), and collection counts 101.
- **Correction:** 101.

**T36-5 — MISSING (low): one of the planning's readings is missing from the plan's list.**
- "Two Neovims following one session share its draft" is marked as the planning's reading in the brief (lines 39 and 130), but it is not among the plan's *Assumptions to report to the user*.
- **Correction:** add it as A7.

**T36-6 — MISSING (low): A6 does not name what it costs.**
- With A6's "when both exist, neither is touched", a directory draft written after the first move is never shown again. An older aineo running in another editor could write one.
- **Correction:** name this in A6.

**REFUTED for T36 — checked and found true:**
- **Line references:** every one is right — `records.lua` 15, 21, 30–37, 170, 215; `report/init.lua` 15–18, 25, 51–57, 209–217, 226–232, 244–254, 267–280, 292–298; `draft/init.lua` (424 lines) 11, 26–29, 63, 71, 78–85, 159–174, 181–198, 277–285, 291–296, 303–308, 328–338, 348–350, 381–422; `plugin/aineo.lua` 148–152, 159–171, 180–187; `tests/test_entry_report.lua:109`; `tests/test_report_buffer.lua` 942 and 968; `doc/aineo.txt` 327, 328, 329–362 and 841–846.
- **The file names cannot collide.** A working directory is absolute, so it starts with `/`, and a session id does not. The SHA-256 names of the two kinds therefore never meet.
- **T36 alone leaves the T14 draft cases true** (`tests/test_draft.lua` 41 cases, `tests/test_entry_draft.lua` 17), and D17's saving and restoring as well. Nothing calls the new entry points until T39. (My brief said "T13's draft cases"; T13 is the Neovim 0.12 task, and the draft cases are T14's, which is what I read.)
- **B2 and M5 are read correctly.**

---

## T37 — `brief-t37-changes-sessions.md`

**T37-1 — MISSING (medium): the test that kills mutant 4 is not in the list.**
- **Why it matters.** T39 will call `begin_session()` and then the new follow entry point at once, at every start. `find` is asynchronous (`lua/aineo/changes/init.lua:249–269`, `356`). So the follow will always arrive before the repository is found. That ordering is the only one that kills mutant 4 ("the kept file written before the repository is found: a base of nil kept").
- **Correction:** add "a follow that comes before `begin_session()`'s look has found the repository keeps the base `HEAD` names once it is found, never nil".

**T37-2 — CONFIRMED (medium): A5 does not say whether the replacement base is written over the kept record.**
- **What it says.** A5: "the session takes `HEAD` then, as an unseen one does". Unseen sessions' bases "are kept from then on".
- **The scenario.**
  1. The user `:cd`s to repository B and restarts Claude Code.
  2. D38 resumes B's session.
  3. T39 tells the changes home, which still holds repository A, that session.
  4. A5 takes A's `HEAD`, and "kept from then on" writes it over the session's record of B.
  5. Later, an editor in B follows that session. It finds a top level that is not B's, so the base is not used: the session's base is lost.
- **Correction:** A5 should say the replacement base is held in memory and the kept record is left as it is. If not, it is a choice to report to the user.

**T37-3 — CONFIRMED (low): mutant 5 names the wrong clause.**
- "(D19's clause kept)" names the clause D41 supersedes.
- **Correction:** "(`begin_session()`'s first-call rule kept)".

**REFUTED for T37 — checked and found true:**
- **Line references:** every one is right — `init.lua` 16–19, 22–36, 39, 233–240, 249–269, 312–320, 328–357, 541, 558; `plugin/aineo.lua` 227–232; `git/init.lua` 40, 53, 65; `comparison_base()` 157–168; `tests/test_entry_changes.lua` 102; `tests/test_changes.lua` 2069; `doc/aineo.txt` 140–146 and 1007–1008.
- **Counts:** `tests/test_changes.lua` 120, `tests/test_entry_changes.lua` 12, `tests/test_entry_panes.lua` 86, `tests/test_git_watch.lua` 33.
- **The hand-off to T38 is real.** T38 is dispatched only after T37 merges, with an amendment that gives the moved lines.

---

## T38 — `brief-t38-changes-worktrees.md`

**T38-1 — CONFIRMED (high): the brief contradicts itself on the editor's own heading, and contradicts D33.**
- **What the brief says.**
  - Line 17: "The editor's own … first, as today, **under its own heading**".
  - Line 19: "a user with no other worktree **sees a heading above today's list**".
  - Line 19 again: "(Whether the editor's own section has a heading when it is the only worktree is **the implementer's to propose**…)".
- **What D33 says** (and P3 (a)): "shows the editor's own worktree first, **as today**, then a section per other worktree: a heading line …". The heading belongs to the other worktrees.
- **What a heading on the editor's own section would break.**
  - `tests/test_entry_panes.lua:178–201`, which pins the exact lines `{ 'No files changed on this session' }` and `{ 'No commits on this session' }`. That file is outside T38's boundary.
  - T39's new suite, which checks the pane's lines at the same time (T39-5).
- **Correction:**
  - Per D33, the editor's own section is today's lines, with no heading; only other worktrees get one.
  - If a heading for the own section is wanted when others exist, name it as an assumption and give T38 that test file.

**T38-2 — MISSING (medium-high): a bare main repository is not mentioned.**
- **Measured (t38, t38b).** With a bare main, the list's first entry is `worktree <t38>/bare.git` followed by `bare`, with no `HEAD`. `git status` and `rev-parse --show-toplevel` there fail with "fatal: this operation must be run in a work tree" (128). `aineo.git.find_repository()` answers `not_a_repository` with the same words.
- **What the brief would produce.** Its field list (A1, brief:27) omits `bare`. Its *Failures* rule ("git's words under its heading") would give every bare-clone user a section that always fails.
- **Correction:** leave out an entry marked `bare`, as a named assumption reported to the user, with a test. A linked worktree of a bare repository works: `find_repository` gives `common_directory = <t38>/bare.git`.

**T38-3 — MISSING (medium): a locked worktree whose directory is gone is never `prunable`.**
- **Measured (t38, t38b).** Such a worktree is listed `locked` (`worktree <t38>/wt-locked-gone … locked`). `git worktree prune -n -v` keeps it. Every read fails with "fatal: cannot change to '<t38>/wt-locked-gone': No such file or directory" (128).
- **Why it matters.** D31's "(its directory gone)" treats prunable as meaning the directory is gone. And Claude Code locks every worktree its agents use (A1b).
- **Correction:** say what such a worktree shows — left out like a prunable one when its directory does not exist, or git's words under its heading — as a named assumption, with a test.

**T38-4 — CONFIRMED (medium): mutant 5 predicts the wrong failure, and A1 is misread.**
- **The mutant:** "The list parsed without `-z`: a path with a space splits" (plan:198).
- **What was measured.** Without `-z`, git 2.50.1 prints whole a path holding a space, `é`, a tab, `"` or `\` (A1's own output, `worktree <a1>/wt é`; t38: `worktree <t38>/wt with space`, `wt "quote" back\slash`, the tab). Only a newline splits the line: `worktree <t38>/wt` / `newline`.
- **What follows.**
  - The listed test, "a path with a space whole", does not kill the mutant.
  - A1's "with `-z` … so a path with a space or `é` reads whole" (plan:53, brief:27) misleads: without `-z` they read whole too.
- **Correction:** test, and mutate, with a path holding a newline, and reword A1.

**T38-5 — MISSING (medium): the brief does not say to keep the changes home's interface.**
- **Why it matters.** T38 may rewrite `lua/aineo/changes/init.lua` while T39, at the same time, calls `begin_session()`, T37's follow entry point, `refresh_shown_pane()` and `pane_buffers()`.
- **Correction:** add to *Boundary*: keep `aineo.changes`' interface as T37 leaves it.

**T38-6 — MISSING (low-medium): a shared helper changes under another packet's new suite.**
- T39's new suite may require `tests/helpers/git_repo.lua` while T38 changes it.
- **Correction:** additions only; no existing function changes.

**T38-7 — MISSING (low): facts the brief can give, now measured (t38).**
- **No shared history.** `merge-base` of unrelated histories prints nothing and exits 1.
- **An unborn worktree** is listed with `HEAD 0000000000000000000000000000000000000000`, and `merge-base HEAD …` fails with "fatal: Not a valid object name HEAD" (128).
- **No upstream.** `dev@{upstream}` fails with "no upstream configured" (128); in a detached worktree, `HEAD@{upstream}` fails with "HEAD does not point to a branch" (128).
- **Paths.** The list and `--show-toplevel` both give resolved paths, so match the editor's own worktree by `find_repository().top`, not by `getcwd()`.

**T38-8 — MISSING (low): a help paragraph this packet makes incomplete.**
- `doc/aineo.txt:104–107` (*aineo-panes*: "listing the session's changed files and its commits") lies outside T38's fences.

**REFUTED for T38 — checked and found true:**
- **Line references:** every one is right — `git/init.lua` 1–18, 40, 53, 65, 79, 91, 114; `repository.lua` 8–13, 54–86, 95, 157–168; `process.lua` 13; `lines.lua` 73, 90, 160, 169, 221, 254, 288, 298, 326; `pages.lua` 10, 60, 88; `colours.lua` 8, 55; `init.lua` 132, 144, 158, 365–370, 478; `doc/aineo.txt` 148–206 and 994–1021.
- **The planning probes reproduce:**
  - **A1:** the fields; a locked, a detached and a prunable worktree; the list the same from any worktree; 18–20 ms.
  - **A2:** the merge base with `origin/dev` lists the agent's two commits only.
  - **A3:** `main = 4`, `nested = 4` under the writer; a `failed` call on removal.
- **The `-z` parse holds** for a space, a tab, a quote, a backslash and a newline.
- **Counts:** the git suites 33, 9, 9, 5 and 17; `tests/test_layout_diffs.lua` 10.

---

## T39 — `brief-t39-panes-follow-switch.md`

**T39-1 — MISSING (high): a test file this packet breaks belongs to neither stage-2 packet.**
- **The case.** `tests/test_entry_panes.lua:601–619` writes the directory's draft through `own_draft()` (565–575) and waits for `read_draft(draft) == 'then run the tests\n'` in the directory's file.
- **Why T39 breaks it.** With the draft kept per session, and the directory's draft moved at the first start (A6), the typed text goes to the session's file. The case then fails.
- **Why nobody can fix it.** The file is in neither T39's boundary nor T38's.
- **Correction:** give `tests/test_entry_panes.lua` (that case) to T39, with T38-1 corrected so that T38 does not need the file.

**T39-2 — MISSING (high): T19's fallback (T35-1).**
- The composition root must tell all three homes the new id when `on_terminal_replaced` fires (`plugin/aineo.lua:222–225`), with an entry test.

**T39-3 — MISSING (medium): the order at the first start (T36-1).**
- "At every start … the composition root tells … the draft home" (brief:17). But at the first `:Aineo open` the session starts before `give_report_environment()` and before `keep_input_draft()`.
- **Correction:** say which goes first.

**T39-4 — CONFIRMED (medium): mutants 3 and 4 are not T39's code.**
- **Mutant 3** (`v:exiting`) is guarded by T35's receiver ("it does nothing once Neovim is quitting", T35 brief:26; tested there).
- **Mutant 4** (a `SessionStart` of the same id) is T35's ("a `SessionStart` whose id is the one the session follows does nothing more"), and T36's and T37's ("following the session already followed changes nothing").
- **Why that matters.** No edit to `plugin/aineo.lua` produces either unless T39 duplicates those guards.
- **Correction:** replace them with mutants of T39's own wiring:
  - `on_terminal_replaced` not wired;
  - the draft home told after `keep_draft()` at the first start;
  - the changes home told before `begin_session()`;
  - the homes told only at the first start, not at every start.

**T39-5 — CONFIRMED (medium): T39's new suite would pin lines T38 is changing at the same time.**
- T39's tests check the changes pane ("its base in the changes pane", "a base of `HEAD` then"), while T38 changes that pane's lines in the same stage: headings and sections.
- **Correction:** assert the editor's own entries by content, not the whole buffer. Or, if T38-1 is corrected as D33 says, state that the editor's own lines stay exactly today's.

**T39-6 — MISSING (low-medium): textlock (as T36-2).**
- The swap is called from the switch's scheduled callback.

**T39-7 — MISSING (low): a LIMITS item becomes stale outside every fence.**
- `doc/aineo.txt:1033–1035` (*LIMITS › Claude's window name*: "Not measured, and so not known to show: a title Claude Code generates from your first prompt, …, the title after `--resume`").
- M6 measured the first-turn title and the in-session `/resume` title.
- **Correction:** give that item to T39, or name it as left as it is.

**REFUTED for T39 — checked and found true:**
- **Line references:** every one is right — `plugin/aineo.lua` 148–152, 159–171, 180–187, 211–234 (227–232), 256–260, 272–281 (279), 288–292, 305–315, 325–338; `changes/init.lua:541`.
- **Counts:** the entry suites 11, 4, 17, 12 and 86, and T33's `tests/test_entry_claude_name.lua` exists (11).
- **Every entry point T39 calls is promised by a stage-1 brief:**
  - T35: the `on_session_switched` field and "which session";
  - T36: the report home's and the draft home's follow;
  - T37: the changes home's follow.
- **M6 and M7 are read correctly.**

---

## The whole wave

**W-1 — CONFIRMED (medium): the two open pull requests conflict.**
- `git merge-tree --write-tree origin/knowledge/w8-landed origin/knowledge/w9-plan-amended` reports a conflict in `knowledge-vault/Planning/aineo — v1 agent console.md`, in three hunks:
  - the C6 row;
  - the C14 and C15 rows;
  - the task rows T32–T34 against T32–T39.
- Both pull requests touch only the vault. Whichever merges second must keep both sides; #132 holds the briefs, which merge before dispatch.

**W-2 — CONFIRMED (low-medium): every brief lists a help test that cannot be seen failing first.**
- **What the briefs say.** Each brief's "Each behaviour gets one test, seen failing first" includes "the help's … through `tests/test_doc.lua`".
- **What `tests/test_doc.lua` pins.** It pins the tags, the 78-column width and the help file's shape (`tests/test_doc.lua:59–208`), and no text. So no help paragraph can be seen failing there, and no packet may edit that file.
- **Correction:** move the help out of the red-first list: "`tests/test_doc.lua` stays green on the merged trees".

**W-3 — CONFIRMED (low): the B1 probe fails from a deep directory.**
- **What happened.** My first re-run of B1 failed: `E5113: … connection failed: connection refused`. Its socket path was 112 bytes, past macOS's 104-byte `sun_path`. From a 94-byte path it reproduces. No process was left behind.
- **Why it matters for T35.** Any T35 test that opens its own `--listen` socket under `.tests/` in an agent worktree meets the same limit. mini.test's own child addresses are short.

**W-4 — MISSING (low): one slot is unfilled.**
- Each brief's session-note `<date>` is left for the dispatch message (`plan.md`, *Host and reviewers*). The topics differ, so no two filenames can collide. Every other slot of `packet-brief.md` is filled: role, objective, task rows verbatim (checked: all five identical to the plan note's rows), rests on, facts, baseline, read first, branch, class, model, resources, may and must not touch, the section exception with its merge instruction, scratch prefix, what was decided, budget, report.

**REFUTED for the wave — checked and found true:**
- **The help fences,** read again at `f98bd9d`:
  - T37: lines 140–146 and 1007–1008.
  - T38: lines 148–206 and 994–1021.
  - T35: lines 271–325, plus a new subsection inserted between 952 and 954.
  - T36: lines 329–362 and 841–846.
  - Three unchanged lines (326–328) separate T35's fence from T36's draft body.
- **The stage-1 help merges cleanly.** Worst-case edits — every fenced line rewritten, with lines added at T35's two insertion points — merge with `git merge-file`: T35 with T36, 0 conflicts; then with T37, 0 conflicts.
- **The baseline:** 60 files and 1929 cases by collection; T33's note:232 holds the green run; `git diff --stat 8cb3cc9 f98bd9d -- lua plugin tests scripts doc Makefile` is empty.
- **Every vault note the briefs cite exists.**
- **P10's letters.** The swap is explained wherever a letter appears: `plan.md:32`, `:38`, `:140`; the proposal's outcome (:30, :36) and its tables' notes (:42); D40's reason column; the amendments of T36 and T39. The places that keep the proposal's own letters — `plan.md:40` "under P10 (a)", the proposal's C11 row — are consistent with the note that explains them. I found nothing that misleads.

---

## The D rows and the assumptions

| Row | Verdict | Note |
|---|---|---|
| D31 | **holds** | As P1 (a). Its "(its directory gone)" is the user's text; T38 must name the bare entry and the locked-but-gone worktree (T38-2, T38-3). |
| D32 | **holds** | As P2 (a): "else with the editor's `HEAD`" equals "when that worktree is detached". |
| D33 | **holds** | As P3 (a). T38's brief contradicts it (T38-1). |
| D34 | **holds** | As P4 (a). |
| D35 | **holds** | As P5 (a), with its measured costs. |
| D36 | **reword** | The reason column's "a `--settings` hook is added to the hooks already configured, so the plugin-directory fallback is not used" lacks M2's scope: it was measured against the project's hooks; the user's own were not measured apart, though P6 (g)'s condition names the user's hooks. Also, "holds its hooks and no other settings key" and "managed … `disableAllHooks`" go past P6 (a)'s text: mark them as the planning's, and drop "managed" before `disableAllHooks` (T35-11). |
| D37 | **holds** | As P7 (a). The `fork` sources that may not be switches belong in T35's *Not measured* and in A1 (T35-4). |
| D38 | **reword (precision)** | "still refuses anything that is not a UUID": the check refuses anything but a lower-case version-4 UUID. Say "accepts the lower-case version-4 UUIDs Claude Code makes (M4) and refuses everything else". |
| D39 | **holds** | As P9 (a) with (i), plus M5. |
| D40 | **holds** | As P10's per-session option, with the user's reason; the letter swap explained. |
| D41 | **holds** | As P11 (a). |
| Dated notes on D17, D19, D23, C6, C11, C15 | **hold** | Each names its superseding row and its packets. |

| Assumption | Verdict | Note |
|---|---|---|
| A1 | **reword** | Its last sentence makes background `fork` sessions switches (T35-4). Name that case, or require the followed id's `SessionEnd` first, and report it. |
| A2 | **holds, incomplete** | Add that the fallback start's new id is followed and told to the homes (T35-1, T39-2). |
| A3 | **holds** | Re-measured: 21 ms for a notification against 1949 ms for a request, against a busy editor (S6). |
| A4 | **holds** | |
| A5 | **reword** | Say the replacement base is not written over the kept record (T37-2). |
| A6 | **holds as a reading; reword** | Name the order at the first start — the follow comes before `keep_draft()` and before the environment (T36-1) — and the cost of "when both exist" (T36-6). |
| **Missing** | add | A7: two Neovims share one session's draft (T36-5). A8: the `bare` entry left out (T38-2). A9: a locked worktree whose directory is gone (T38-3). |

---

## The six rules, recomputed from the briefs

| Rule | Stage 1: T35, T36, T37 | Stage 2: T38, T39 |
|---|---|---|
| **1. Dependencies** | Wave 8's code is merged at `f98bd9d` (PRs #127–#129). Its knowledge pass, #131, is still open, and the user's go waits for it. ✓ | T38 after T37 (it shares `lua/aineo/changes/` and *aineo-changes*); T39 after T35, T36 and T37. Both are real hand-offs. ✓ |
| **2. Files** | Disjoint (lists below). `plugin/aineo.lua` is T35's alone (`started_claude_terminal()`). The shared helpers `claude_session.lua` and `fake_claude.lua` are T35's alone. `doc/aineo.txt` is shared under the section exception and merges cleanly (0 conflicts). ✓ | Disjoint by path. ✗ `tests/test_entry_panes.lua` is needed by T39 (601–619) and by T38 if it adds a heading, and belongs to neither (T39-1, T38-1). ✗ T39's new suite pins the pane lines T38 changes (T39-5). ✗ (minor) `git_repo.lua` is shared with T39's new suite (T38-6). |
| **3. Schema** | None. Separate state folders: `claude-sessions/`, `reports/` and `drafts/`, and T37's new folder. ✓ | None. ✓ |
| **4. Dependency change** | None. ✓ | None. ✓ |
| **5. No undecided decision** | D31–D41 are answered. ✗ Left open: the fallback id (T35-1); background forks (T35-4); whether A5 writes over the kept record (T37-2). | ✗ T38 leaves the editor's own heading to the implementer, against D33 (T38-1). ✗ The bare entry and the locked-but-gone worktree are left unsaid (T38-2, T38-3). |
| **6. Task lines** | T35–T39 are adjacent rows (plan note 175–179, gap 0). Every packet holds its mark and writes `## Task lines`. ✓ | Same. ✓ |

**The file sets.**
- **T35:** `lua/aineo/claude/{init,arguments,session_ids}.lua` and the new relay file; `plugin/aineo.lua`; `tests/helpers/{fake_claude,claude_session}.lua`; `tests/test_claude{,_resume,_switch}.lua`; `doc/aineo.txt` at 271–325 and the new LIMITS subsection.
- **T36:** `lua/aineo/report/{records,init}.lua`; `lua/aineo/draft/`; `tests/test_report{,_buffer,_sessions}.lua`; `tests/test_entry_report.lua` only if its pin must change; `tests/test_draft{,_sessions}.lua`; `doc/aineo.txt` at 329–362 and 841–846.
- **T37:** `lua/aineo/changes/init.lua` and its new file; `tests/test_changes{,_sessions}.lua`; `doc/aineo.txt` at 140–146 and 1007–1008.
- **T38:** `lua/aineo/git/`; `lua/aineo/changes/{init,lines,pages}.lua`; `tests/test_git_worktrees.lua`; `tests/test_changes{,_worktrees}.lua`; `tests/test_entry_changes.lua`; `tests/test_layout_diffs.lua`; `tests/helpers/git_repo.lua`; `doc/aineo.txt` at 148–206 and 994–1021.
- **T39:** `plugin/aineo.lua`; `tests/test_entry_session_switch.lua`; `tests/test_entry_{claude_resume,report,draft}.lua`; `doc/aineo.txt` in T35's paragraph.

**The open pull requests.** #131 and #132 conflict in the v1 plan note (W-1). Neither touches a packet's files.

---

## The verification mutants

| Packet | Mutant | Does a test see it? | In the packet that owns the code? |
|---|---|---|---|
| T35 | 1 | Yes, by time. Measured: 1949 ms against 21 ms. | Yes |
| T35 | 2, 3, 7, 8 | Yes | Yes |
| T35 | 4 | No literal edit; no test in the list (T35-6). | Yes |
| T35 | 5 | Only with `NVIM` set explicitly; under a naive fake it dies for the wrong reason (T35-3). | Yes |
| T35 | 6 | Yes, but its predicted observable is impossible (T35-5). | Yes |
| T36 | 1, 3, 4, 5 | Yes | Yes |
| T36 | 2 | Needs a planted directory file; near-equivalent (T36-3). | Yes |
| T36 | 6, 7, 8 | Yes | Yes |
| T37 | 1, 2, 3, 5 | Yes | Yes |
| T37 | 4 | Needs the follow-before-find test (T37-1). | Yes |
| T38 | 1–4, 6 | Yes. Mutant 2 needs a fixture with an upstream (`git_repo.lua` may grow one). | Yes |
| T38 | 5 | A space does not split; only a newline does (T38-4). | Yes |
| T39 | 1, 2, 5 | Yes | Yes |
| T39 | 3, 4 | — | **No: T35's, T36's and T37's code (T39-4).** |

**Mutants run in this review** (`bs/t35-relay.lua`, `bs/t35-fake.lua`, `bs/t35-probe.lua`), each by its literal edit:

| Literal edit | Run | Result |
|---|---|---|
| `address = os.getenv('NVIM')` in place of `arg[1]` (`RELAY_FROM_NVIM=1`), the hook's `NVIM` naming editor B | S2m | **Killed:** A saw nothing, B saw the event. |
| The same, `NVIM` unset | S3m | **Killed:** the hook exited 1 (`E474` in `sockconnect`), and A saw nothing. |
| The same, under a fake that spawns the hook with `vim.system()`'s default environment | S1c | **Wrong reason:** the notification went to the fake's own server; A and B saw nothing. |
| `vim.rpcrequest` in place of `vim.rpcnotify` (`RELAY_REQUEST=1`), the editor busy for 2 s | S6 | **Killed by time:** 1949 ms against 21 ms. |

**4 mutants run: 3 killed for the right reason, 1 killed for a wrong reason.**

---

## For the other dimensions

- **Attack (T35):** probe the hook command's quoting with the real paths `v:progpath` can hold, and a late hook from an exited Claude Code after a restart.
- **Records (T35, T38, T39):** check the help paragraphs outside the fences: `doc/aineo.txt` 46–49, 104–107, 680–691 and 1033–1035.

## Cleanup

- **Processes.** `ps -axo pid,ppid,command | grep -F agent-a568585bfeb1a322f` prints nothing: no probe process is left. The three probe editors were stopped by pid (A 72946, B 72947, C 73005), and no socket remains under `bs/`.
- **Resources.** `.claude/scripts/prepare-worktree.sh review_brief_w9` printed `AGENT_RESOURCE=review_brief_w9` and created nothing (`prepare_project` is empty).
- **Files.** `make deps` fetched mini.nvim into this worktree's `deps/` only. Scratch is in this worktree's `brief-scratch/` and `bs/`. Nothing was committed or pushed, and the worktree is left in place.
