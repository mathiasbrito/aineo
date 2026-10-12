---
wave: 00012
status: planned
rolling: false
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for the user
planned_at: 2026-10-12
base: 0fa0116
claimed_by:
claimed_at:
landed_at:
pull_requests:
---

# Wave 12 — a start that resumes a background session

**Planned by:** the orchestrator's planning agent, 2026-10-12. **Base:** `dev` `1dc3186` (wave 11 landed).
**Ask:** the user's fix request of 2026-10-12 (verbatim below).
**Composition from:** [[Planning/aineo — v1 agent console]] › D23, D36–D38, D42, D45, D49, D51, D53, C3, R2 and the proposed D54 and T48 this plan writes; [[Implementation/Waves/00011-names-and-sessions/plan]] for the form and for T46, whose `claude agents --json` reader this packet reuses; [[Projects/aineo]].

**Revised a third time 2026-10-12, with the user's reproduction and answer** (*Round 4*). The fault reproduced with a busy session running in the background service. The user chose: when the folder's kept session runs in the background service, aineo asks at start whether to attach to it or start a new one. The list now runs before the start, since its answer chooses the command. T48 has two parts: part 1 can be dispatched now, and part 2, the attach, waits for the user's check M16. Rounds 1–3 below are kept as they were written.

**Revised again 2026-10-12 with the user's M11 and the orchestrator's rulings A164–A166** (*Round 3*). With an idle, small background session, aineo's start resumed it and its content showed, so the reported fault does not reproduce. It stays an open thread, with the user's check M15 for the next time it happens. T48 is re-scoped to the warning for a kept session open in another interactive Claude Code; a background session is resumed as today. Nothing holds the dispatch.

**Revised 2026-10-12 with the user's round-1 answers** (*The user's answers — round 1*, *Round 2*). The user rejected every U1 option: aineo always resumes the folder's session, warns when it runs in another interactive Claude Code, and resumes a background one so that its content shows. U2: the quit stays as it is until M9 and M10. T48 is re-planned as the display fix. Its brief is rewritten for (ii), a redraw, and held for the user's check M11. The round-1 text below is kept as it was written.

**One packet, T48, held for the user's answer U1** *(round 1)*. The cause is established up to how the folder's kept session came to run in the background service, which only the user's manual checks can tell (M9–M11); the fix the plan recommends does not depend on that answer. The brief is written for this plan's recommendations; an answer that differs is a dated amendment before dispatch.

## The user's request — 2026-10-12, verbatim

The session's name and id are replaced by placeholders: this repository is public. The session is a background session of the folder.

> [fix] When quiting a session with :qa!, after opening nvim in the same folder I get "Opening "[name] (3)", running in the background ([id])", and the content of the session do not appear in the claude window. I have to do /resume then pick the session, only then it will appear.

The orchestrator's notes, facts only: the session named is a background session of the folder, running and idle (the user's M7 of wave 11 listed it with `kind: background`, a `pid` and `status: idle`); M7 also listed an ended background session of the same folder, with no `pid`.

## What is established

From `origin/dev` `1dc3186`, read, and from Claude Code 2.1.296's documentation and changelog, read and never run (`evidence/w12-docs.txt`, blocks D1–D8).

- **E1 — aineo resumes the kept id without looking where it runs.** `start_session()` (`lua/aineo/claude/init.lua` 560) starts on `kept_or_new_session()` (196): the id kept for the working directory, resumed with `--resume <id>` (`session_arguments()`, 209), else a new id with `--session-id`. Nothing asks whether that session is running elsewhere.
- **E2 — Claude Code opens a running background session on a resume.** Since 2.1.285, `claude --resume` and `/resume` of a session that runs in the background service "open that session instead of refusing" (D8, the 2.1.285 line; D1). From a shell, `--resume` "runs `claude attach` on that session in the same terminal instead of loading the transcript itself"; from inside a session, `/resume` moves the current conversation to the background, attaches, and prints `Opening "<title>", running in the background (<id>)` — the line the user saw (D1). The page also says a command line holding flags that configure the session, `--settings` named among them, makes Claude Code refuse and exit 1 instead (D1). aineo always passes `--settings` (D36). The user's report shows a session that kept running, since `/resume` could be typed into it afterwards, so on the user's machine the start did not exit 1 as the page says. The page and the report disagree; M11 tells what aineo's window showed.
- **E3 — an attached terminal is not aineo's session.** An attached session renders in fullscreen mode, "because a background session has no terminal scrollback to append to" (D2). It runs in the background service's process, with the flags *it* was started with. aineo's report instructions (`--append-system-prompt`) and `--allowedTools` are not among the flags that carry over to a background session, and `--settings` (aineo's session hooks) is among them (D4). In an attached terminal, `Ctrl+C` "cancels a running response" of the background session, and a double press on an empty prompt detaches (D2). So aineo's quit (`stop.lua`: Ctrl-C, then a double Ctrl-C) interrupts that background session's turn when it is busy, then detaches. That is harm the request does not name.
- **E4 — how a conversation enters the background service in 2.1.296** (D2, D3): `←` on an empty prompt of a foreground session; `/background` or `/bg`; the `Background work is running` dialog that exiting shows "instead of quitting immediately" when subagents, background shell commands, workflows or monitors still run, whose `Move to background and exit` backgrounds it; `/resume` of a running background session from inside a session, which moves the *current* one; clicking a `/fork` copy's name. **None of the pages read says what a hang-up does,** nor what the dialog does on more Ctrl-C or on a hang-up. At an idle prompt with no background work, a double `Ctrl+C` exits (D7).
- **E5 — the folder's kept id changes in three places only.** (1) a start on a new id keeps it (`start_in_place()`); (2) a switch Claude Code makes in aineo's terminal, told by the session hooks, is followed and kept (`follow_switch()`, 607; D38); (3) the hook relay's deliverer, when its editor cannot be reached, keeps the switch it carries for the working directory (`lua/aineo/claude/hook_relay.lua` 228–235). Since `--settings` carries over to a background session (D4), a background process born from aineo's terminal still runs aineo's hook relay, with the start token and the address of an editor that may have quit. A switch made in it after that editor quit (a `/clear`, a `/resume`) is kept by path (3).
- **E6 — the name ends in `(3)`.** "If a background session on the list already has the conversation's name, Claude Code numbers the new row's name, such as `my-session (2)`" (D3). The row was therefore made by moving a conversation to the background while two rows of that name were listed. A conversation of that name has been moved to the background at least three times, or forked.

## How the folder's next resume came to name a background session — hypotheses

Any of these leaves a kept id that E1 resumes and E2 attaches to. Which one happened is not established.

- **H1 — it was aineo's own session in that folder, later moved to the background.** It was started or resumed in aineo's terminal there (D23, D38), and then moved to the background (E4) by one of the following:
  - (a) **aineo's quit.** With background work running, the double Ctrl-C meets the `Background work is running` dialog, and aineo then hangs the terminal up (`jobstop()`, `lua/aineo/claude/stop.lua` 71–81). What Claude Code does then is not documented. E6 fits a quit repeated several times: **M9**, **M10**.
  - (b) `←` or `/bg` typed in aineo's terminal.
  - (c) a `/resume` from aineo's terminal to another running background session, which moves the current one out.
- **H2 — a switch to it was followed.** In aineo's terminal the user resumed it with `/resume` while it was running in the background. Claude Code attached, and if its hooks told aineo a `SessionEnd` and then a `SessionStart` of that id, D38 kept it. `\S` cannot be the cause: it refuses a session running elsewhere (D49's R3).
- **H3 — a background process's relay kept it.** Through E5's path (3): a background process carrying aineo's hooks switched session after its editor had quit.

Whichever it was, every later start in the folder resumes the same id and attaches again (E2). Whether that attach fires aineo's hooks, and so re-keeps the id, is not known. Nothing in aineo ever un-keeps it.

## What aineo should do when the session it would resume runs elsewhere

The options, each for the start (the quit follows):

- **(A) Look first, then start a new session.** Before a start that would resume, aineo runs `claude.cmd` followed by `agents --json --cwd <folder> --all` through T46's reader (`lua/aineo/claude/agents.lua`, `list_sessions()`, 277; bounded at 5 s, 1 MiB, killed when Neovim quits). If the kept id is listed as a background session whose process runs (`pid` or `status` present, the reader's `running`), aineo starts a new session (`--session-id`) instead, keeps that one for the folder as D23 keeps a new one, and says so in one line. The background session is not touched, attached, stopped or forked. If the list fails, times out or cannot be read, aineo resumes as today. **Cost:** a second `claude` run at every start that resumes, which is nearly every start. Claude Code's window comes up later by however long that run takes; the time on the user's machine is not measured, and it is capped at 5 s. Whether `claude agents --json` starts Claude Code's background service is not measured (A131), and now it would run at every start. A `claude.cmd` holding `--add-dir` or `--mcp-config` before `agents` fails every list (wave 11's `evidence/w11-probes.txt`, P8), so it always resumes as today. The fake's record and the suites' start helpers must tell the list's run from Claude Code's (*Facts* in the brief).
- **(B) Look first, then fork.** As (A), but `--resume <id> --fork-session`: a copy of the conversation with aineo's flags, the content shown (D1: "Add `--fork-session` to resume a copy of the conversation instead"). The cost of (A), and two copies of one conversation now act in the same folder, each unaware of the other.
- **(C) Look first, then take it over.** As (A), but `claude stop <id>` and then `--resume`, which is the page's own way to "continue the conversation itself in a session of your own, with your flags applied" (D1). The content is shown with aineo's hooks and report. But it stops whatever runs in that session — a turn, subagents, background commands — and it does so behind the user's back, in the background service the user may be using elsewhere.
- **(D) Recognise the attach and leave it.** Start as today. aineo reads `running in the background` on the new terminal, as it reads `No conversation found` at exit (`found_no_conversation()`, 236), then hangs the attach up and starts a new session in its place. That needs no second run. But aineo has attached for a moment — "When you attach, Claude posts a short recap" (D2), which is a turn in the background session. And it rests on a message whose wording only the user's report shows.
- **(E) Turn agent view off in aineo's Claude Code** (`CLAUDE_CODE_DISABLE_AGENT_VIEW` in its environment, D6). A resume of a running background session then exits 1 with a message (D1), which aineo could read as in (D) and replace with a new session. And nothing started in aineo's terminal can go into the background service — not by `←`, `/bg` or the exit dialog. That also takes those features away from the user inside aineo, and the page's "turn off background agents and agent view entirely" does not say how much more it turns off.

**Recommended: (A).** It never touches a session running elsewhere, which is the principle the user chose for `\S` in D49's R3: "Nothing is moved behind your back". It reuses a reader that is built and reviewed, and when anything about the list goes wrong it falls back to today's behaviour. Its cost is the second run at each start that resumes, and a start later by that run's time. U1 puts it to the user.

**The quit.** Nothing in the pages read says that a quit moves a session to the background. The one documented path is the exit dialog with background work running (E4), and what aineo's hang-up does while that dialog shows is unmeasured. Under (A), whatever the quit does, the next start begins a new session instead of attaching, and says so. The plan recommends no change to the quit in T48 (U2). If M9 shows the quit moves a session with background work into the background service, the user decides between keeping that work running there and a quit that ends it. Ending it would change R2 and C3's "clean stop on quit".

**Not in T48:** E3's harm when the user attaches aineo's terminal by hand — a `/resume` of a running background session, or agent view — and then quits. aineo's Ctrl-C then interrupts that session's turn. It is an open thread for the user (M11's last step measures it).

## D54 — written into the plan note

**Round 1** proposed a D54 holding only the request's decided part. **Round 2** rewrote it with the user's U1 and U2 answers, and **round 3** trimmed it to those decided parts once M11 was in. **Round 4** rewrites it with the user's answer after the reproduction, which replaces the background half of U1. The row is not merged, so it is replaced, not superseded. Its decision column, as written into [[Planning/aineo — v1 agent console]]; its reasoning column quotes the request, the answers, M11 and the new answer.

> **D54** — A start of Claude Code resumes the session kept for the working directory (D23, D38). When that session is open in another interactive Claude Code, aineo tells the user so and resumes it all the same. When it runs in Claude Code's background service, aineo asks at start, in a one-line choice, whether to attach to the running session or to start a new one. aineo's quit of its own session does not change until the user's checks M9 and M10 are in. The quit of a terminal attached to a background session changes only once the user has checked `Ctrl+Z` (U3) (confirms D23 and D38 for a session running elsewhere; touches C3)

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T48 part 1 *(round 4)* | T48 | `neovim-claude-code-integrator` / sonnet | `lua/aineo/claude/init.lua` (the list before a start that would resume, the start that waits for it, the warning), `lua/aineo/claude/agents.lua` (`pid` and the short `id` kept on a listed session); `tests/helpers/claude_session.lua` (a start is Claude Code's run, not the list's); a new `tests/test_claude_resume_elsewhere.lua`, and the suites the helper's change or the waiting start moves; `doc/aineo.txt` › *aineo-claude-session* and *aineo-limits* (*The session list*) | no | no | O11–O17, the orchestrator's | own |
| T48 part 2 *(round 4)* | T48 | `neovim-claude-code-integrator` / sonnet | part 1's files, plus `lua/aineo/claude/stop.lua` (the detach), `lua/aineo/claude/session_name.lua` (the mark), `lua/aineo/claude/arguments.lua` if the attach command is built there, `tests/helpers/fake_claude.lua` (`attach`); `doc/aineo.txt` › *Stopping Claude Code on quit* | no | no | **M16**, the user's | own |
| ~~T48 (round 3)~~ | T48 | `neovim-claude-code-integrator` / sonnet | *(round 3, replaced by round 4)* `lua/aineo/claude/init.lua` (the list beside a start that resumes, and its warning), `lua/aineo/claude/agents.lua` (`pid` and `startedAt` kept on a listed session, and the predicate of A165); `tests/helpers/claude_session.lua` (`wait_for_starts()` counts Claude Code's starts, not the list's runs); a new `tests/test_claude_resume_elsewhere.lua`, `tests/test_entry_sessions.lua` and `tests/test_claude_agents.lua` where the helper's change moves them; `doc/aineo.txt` › *aineo-claude-session* and *aineo-limits* (*Stopping Claude Code on quit*, *The session list*) | no | no | none: A164–A166 | own |

**Rule 1, dependencies.** T48 rests on T46's reader, merged. ✓ *(round 4)* Part 2 rests on part 1, merged.
**Rule 2, files.** One packet. ✓ *(round 4)* Two parts of one task, one after the other, on one branch name each. ✓
**Rule 3, schema.** None. ✓
**Rule 4, dependencies.** None. ✓
**Rule 5, decisions.** *(round 3)* U1 and U2 are answered, M11 is in, and A164–A166 rule the rest. U3 does not hold T48. ✓ *(round 4)* The user's answer decides the behaviour; O11–O17 are the orchestrator's to rule before part 1 is dispatched. M16 holds part 2. ✓
**Rule 6, task lines.** One packet: it marks its own line. ✓

**Class: regular.** It changes what a start does (D23, D38, proposed D54). Its home is `lua/aineo/claude/` and it starts a process, both of which §3 of the orchestrate skill keeps from a small fix (D30's waves included).

## Host and reviewers

| packet | implementer | reviews | session note | resource | branch |
|---|---|---|---|---|---|
| T48 part 1 | `neovim-claude-code-integrator`, model sonnet | attack by `neovim-claude-code-reviewer` (Opus); tests and records together by one `records-reviewer` (Sonnet); one fix round; the orchestrator's own check | `Sessions/<date> — T48 Resume elsewhere.md` *(round 3; `T48 Background resume.md` before)* | `impl_t48_background_resume` | `bugfix/t48-background-resume` |
| T48 part 2 *(round 4)* | the same | the same | `Sessions/<date> — T48 Attach.md` | `impl_t48_attach` | `bugfix/t48-attach` |

D26: the whole suite once before each push. The start path is exercised by most entry suites, and the helper change moves every suite that counts starts.

## Decisions for the orchestrator — round 1, as written

Numbered once, here. Written for (A), which the user's U1 answer rejected (*The user's answers — round 1*). They are kept as they were written, and not ruled.

- **O1 — What counts as running elsewhere at a start.**
  - (a) A listed entry whose `sessionId` is the kept id, whose `kind` is `background`, and whose process runs (`pid` or `status` present). An `interactive` entry — the session open in another terminal or another aineo Neovim — keeps today's resume: D38 and D42 already provide for two Neovims on one session.
  - (b) Any running entry of that id, interactive included.
- **O2 — How the start waits for the list.**
  - (a) The editor never waits. `start_session()` makes and returns the terminal buffer at once, as today, and Claude Code is launched in it when the list has answered (or failed, or timed out). `session_status()` is `'starting'` meanwhile, and nothing that raises today raises later: the settings, the executable and the command are checked before the list runs.
  - (b) A blocking wait, bounded at 2 s. That is simpler, but the editor freezes for up to that long at each start that resumes.
- **O3 — A list that fails, times out, prints too much or is not JSON.**
  - (a) Resume as today, and tell nothing: a `claude.cmd` that cannot list would warn at every start.
  - (b) Resume, and warn once per Neovim.
- **O4 — What the new session takes from the background one.**
  - (a) Nothing. The background session lives, so its Report records, Input draft and changes base stay its own (D39–D41). D45's hand-over is for a session that is dead. The new session is not told as a replacement (`on_terminal_replaced` is not called), and the panes follow it once it is ready, as at any start.
  - (b) A D45 hand-over.
- **O5 — The line the user is told.**
  - (a) One warning of at most 60 characters, as `SETTINGS_UNREAD_WARNING` is limited (`init.lua` 254) so that it holds no 80-column start at a hit-enter prompt. For example `aineo: kept session runs in background; started a new one` (57). The help says how to reach the background session: `claude attach <id>`, or agent view.
  - (b) Two lines, naming the session.

## Questions for the user — round 1, as written

Only what changes a D row, or needs the user's own measurement. Each recommendation is (a).

**U1 — when the folder's session is running in Claude Code's background service, what does aineo's start do?** (proposed D54)
- (a) It starts a new session in aineo's window and tells you, leaving the background one alone. You find that one with `claude attach <id>` or in agent view, and `\S` lists it as running elsewhere. To know, aineo runs `claude agents --json` before each start that resumes, so Claude's window comes up later by however long that takes (at most 5 s). If the list fails, the start resumes as today. Recommended.
- (b) The same check, but it opens a copy of the conversation (`--fork-session`), so you see the content. Two copies of the conversation then work in the same folder.
- (c) The same check, but it stops the background session (`claude stop`) and resumes it in aineo's window, with aineo's report and hooks. Whatever that session was running stops.
- (d) No change at start. A later wave measures why the attached session's content does not show (M11), and fixes the display.

**U2 — aineo's quit.** Claude Code's documentation says a session with background work running (subagents, background commands, workflows, monitors) shows a `Background work is running` dialog on exit, whose `Move to background and exit` moves it to the background service. aineo's quit presses Ctrl-C and then hangs the terminal up, and what that does to such a session is not documented.
- (a) No change in T48. Measure first (M9, M10). If the quit does move such a session to the background, its work goes on there, and under U1 (a) the next start begins a new session and tells you. Recommended.
- (b) After M9: if it does move it, change the quit so the session stays aineo's, and the work it was running ends. That changes R2 and C3's "clean stop on quit", and would be planned in a later wave.

## The user's answers — round 1, 2026-10-12

Verbatim, from the orchestrator's record of the `AskUserQuestion` on this plan's U1 and U2. The question was worded more briefly than this plan's U1, and offered only its options (a)–(c).

- **U1** — Q: "The cause: aineo resumes this folder's recorded session without checking where it runs. When that session lives in Claude Code's background service, Claude attaches to it instead of resuming it in aineo. That's the 'Opening … running in the background' line. When this folder's recorded session is running in the background service, what should aineo's start do?" (options: start a new session; open a copy with --fork-session; stop it and resume here) — A: "none of this solution are desired, it must resume the session, if it is running in another claude-code session warn, if it is running in the background, resume."
- **U2** — Q: "We don't know yet whether aineo's own quit (:qa!) can push a session into the background service. … Should T48 also change the quit?" — A: "Not yet; you check first (Recommended)" (option text: "T48 fixes the start only. You run two short checks in a scratch folder (M9: quit while a background Bash runs; M10: quit while idle), and we change the quit only if they show it backgrounds a session.")
- Already in the request: "I have to do /resume then pick the session, only then it will appear." This is the user's own observation that a `/resume` typed into Claude Code shows the background session's content.

What follows from them:

- **U1 → the user's decision, recorded in D54.** aineo always resumes the folder's kept session (D23, D38 stand).
  - When that session runs in another interactive Claude Code, aineo warns and resumes it all the same.
  - When it runs in the background service, aineo resumes it so that its content shows.
  - (A)–(C), the options offered, are rejected. (D) and (E) were not offered, but both end in a new session, which the answer rules out too. The fault left to fix is the display: after the start's `--resume`, the background session's content does not show.
- **U2 → the user's decision.** T48 changes the start only. The quit stays as it is until M9 and M10 are in.
- O1–O5 were written for (A) and fall with it. They are kept as they were written, and not ruled.

## Round 2 — making a background session's content show in aineo's terminal

**Evidence.** The user's report: a command-line `--resume` printed the `Opening …` line and showed nothing, and a `/resume` typed into that window, picking the session, showed its content. Beyond the report there is this:

- Claude Code's documentation says an attached session always renders in fullscreen mode (D2). For fullscreen it says: "If the display looks garbled or partially blank, press `Ctrl+L` to redraw the screen. The redraw keeps the conversation and your input in place" (D9). It also names `CLAUDE_CODE_ALT_SCREEN_FULL_REPAINT=1`, which repaints every cell on every frame (D9). `Ctrl+L` is "Redraw the screen … Use this to recover if the display becomes garbled or partially blank" (D10).
- aineo's own start documents a size problem (`start_session()`'s docstring, `lua/aineo/claude/init.lua`). A terminal has the rows of a hidden window — 5 — until a window shows it, "though a size it reads as it starts can still be 5 rows". A fullscreen view first drawn for 5 rows, and drawn only in the cells that change afterwards (D9, *Stale or misplaced text on screen*), would leave the window blank. This is a hypothesis, not a measurement.
- What the window held before the user's `/resume` is not known:
  - **(α)** It was the background session itself, attached but not drawn. The docs say a `/resume` typed in an attached session "prints the `claude attach` command to run instead" (D1), which the user's observation contradicts.
  - **(β)** It was a fresh, empty session that Claude Code started after printing the line. Then the typed `/resume` moved that empty session to the background and attached the window (D1). That fits the observation.

  M11 tells which.

**The options.**

- **(i) Type the user's own `/resume`.** Once the start's screen shows Claude Code's `running in the background (` line, and Claude Code is ready with an empty prompt (T46's `prompt_shows_text()`), aineo writes `/resume <kept id>` and Enter as T46 writes a switch: a bracketed paste and `\r` in one write (A133). It does this once per start.
  - It works only under (β). Under (α) the docs say the `/resume` prints a command instead (D1).
  - Under (β), the empty session the start made is moved to the background service, as a row with no conversation in it. Whether Claude Code keeps such a row, at every start in that folder, is M12.
  - D38: aineo follows the id it started on, the kept id. A `SessionStart` of an empty session with no `SessionEnd` of the followed id before it is not a switch (D37's note, A1). A `SessionEnd` of that empty session is not of the followed id. So the typed `/resume` records nothing, and the kept id stays. If Claude Code instead tells a `SessionEnd` of the kept id and then a `SessionStart` of the same id, that is no switch either.
  - Cost: it types into Claude's prompt, with T46's refusals when text shows. If the line's wording changes, nothing is typed.
- **(ii) Redraw.** Keep `--resume`. When the start's screen shows the `running in the background (` line, aineo writes one `Ctrl+L` (`\x0c`) to the terminal once the window has its size. This is the documented recovery for a partially blank fullscreen display (D9, D10).
  - It works only under (α), and only if the content is there but undrawn.
  - It changes no session, types nothing into the prompt, and leaves D38 alone. At an ordinary prompt `Ctrl+L` only redraws.
  - Cost: one byte per start that attaches.
- **(iii) Repaint every frame.** `CLAUDE_CODE_ALT_SCREEN_FULL_REPAINT=1` in Claude Code's environment (`CHILD_ENVIRONMENT`, C3). That is documented for terminals that drop incremental fullscreen updates (D9).
  - Cost: every fullscreen frame of every session in aineo's terminal is sent whole, not only an attached one's.
  - It helps under (α) only if the blank comes from cells left undrawn, and is not a first frame drawn at the wrong size.
- **(iv) Nudge the size.** Resize the terminal by one row and back (`jobresize()`), so that Claude Code gets a `SIGWINCH` and redraws. Works under (α). It has (ii)'s reach with more moving parts, and no documentation behind it.

**The list.** None of (i)–(iv) needs `claude agents --json` to tell a background session: the `Opening …` line on the screen tells it, as `found_no_conversation()` tells a missing conversation from the screen. The warning does need the list, for an interactive session running elsewhere. That list runs beside the start, after Claude Code is launched, so the start does not wait for it. Its cost is a second `claude` run at each start that resumes, off the start's path, and A131's unmeasured question whether it starts the background service. The fake's record and `wait_for_starts()` must tell the list's run from Claude Code's (the brief's *Facts*).

**Recommended: (ii), with (i) in its place if M11 shows (β).** It is documented for exactly this symptom, costs one byte, and moves no session. If M11 shows that `Ctrl+L` does not bring the content, and that the window held a fresh session (β), the brief is amended for (i) before dispatch: O6. M11 holds the dispatch either way. M12 holds it only under (i).

**What an attached session is, under the user's decision.** E3 stands. The session in aineo's window runs in the background service with its own flags. aineo's report instructions and `--allowedTools` do not carry over (D4), so its Report may get nothing, and Claude may ask permission for the report tool. aineo's quit presses Ctrl-C into it, which interrupts a turn in progress (D2) — U3. The help says both.

## Decisions for the orchestrator — round 2

Not ruled; O1–O5 above fall with U1's answer. The recommendation is (a), and the brief is written for it.

- **O6 — The mechanism, after M11.**
  - (a) (ii), `Ctrl+L`, if M11 shows `Ctrl+L` brings the content. Else (i), the typed `/resume`, if M11 shows a fresh session and M12 shows it works.
  - (b) (i) whatever M11 shows: it is what the user did by hand.
  - (c) Both, `Ctrl+L` first and then `/resume` if the screen still shows no conversation. That needs aineo to read "no conversation" off a fullscreen screen, which nothing measures.
- **O7 — What tells the start that it attached.**
  - (a) The screen: Claude Code's `running in the background (` line, read with the white space removed, as `found_no_conversation()` reads its line. It costs no wait, and its wording is the user's report and D1's.
  - (b) The list's answer: the kept id listed as `background` with a `pid`. That is on the list's time, up to 5 s after the start.
- **O8 — When the key is written.**
  - (a) Once per start, after the line, once Claude's window has shown the terminal at its size, and — under (i) — once `session_status()` is `'ready'` and the prompt shows no text. Nothing is written after 10 s, nor once the session has exited or Neovim is quitting.
  - (b) Each time the line is redrawn.
- **O9 — Which entry is "another Claude Code", for the warning.**
  - (a) An entry of the kept id, `kind` `interactive`, with a `pid`, which is not aineo's own Claude Code. aineo's own is the one whose `pid` is the terminal job's (`jobpid()`), or whose `startedAt` is at or after aineo's launch, since a `claude.cmd` that wraps `claude` gives another pid. A list that fails tells nothing.
  - (b) Any running entry of the kept id other than aineo's own, background ones included. The background case already shows itself on the screen.
- **O10 — The warning's text.** (a) One line of at most 60 characters, as `SETTINGS_UNREAD_WARNING` is limited, for example `aineo: this session is also open in another Claude Code` (55). (b) Two lines, naming where.

## Questions for the user — round 2

**U3 — aineo's quit when its window is attached to a background session.** Under your U1 answer, every start in a folder whose session runs in the background attaches aineo's window to it. aineo's quit then presses Ctrl-C into it. Claude Code's documentation says Ctrl-C there "cancels a running response", and a double press on an empty prompt detaches. So a `:qa!` while that session is working interrupts its turn. `Ctrl+Z` detaches without interrupting (D2), but nothing measures it in aineo's terminal.
- (a) Leave the quit as it is in T48, as your U2 answer says. Measure `Ctrl+Z` with M13 beside M9 and M10, and plan any quit change after them, in one later wave. Recommended.
- (b) T48 also makes the quit press `Ctrl+Z` instead of Ctrl-C when the start attached, unmeasured.

## Manual checks — the user's, in a scratch folder you trust, where no session you need runs

None of these touches a session of yours elsewhere. Afterwards, stop only the scratch folder's own background session, by the id `claude agents --json --cwd <scratch folder> --all` printed.

**For U2 (the quit) — hold no dispatch:**

- **M9 — does aineo's quit move a session with background work to the background service?** (H1 (a)) Open Neovim with aineo in the scratch folder. In Claude's window type `Start "sleep 900" with the Bash tool in the background, then tell me it runs.` and wait for Claude to say it runs. Before the quit, `:lua print(require('aineo.claude').session_id())`. Then `:qa!`. In a shell, run `claude agents --json --cwd <scratch folder> --all`. Look for an entry with `"kind": "background"`, a `pid`, and that `sessionId`. If there is one, the quit moved the session to the background; if none, it did not.
- **M10 — the same with no background work.** Claude idle with nothing running, then `:qa!`, then the same command. A live entry for the session would mean the hang-up alone moves it.
- **M13 — `Ctrl+Z` in an attached window** (U3). After M11, with Claude idle, press `Ctrl+Z` in Claude's window. Does that Claude Code exit (the window shows `[Process exited …]`), and does `claude agents --json …` still list the session with a `pid`?

**For T48 — the setup, then the checks that hold its dispatch:**

- **Setup.**
  1. Open Neovim with aineo in the scratch folder, send `say hi`, and wait for the answer.
  2. `:lua print(require('aineo.claude').session_id())`.
  3. On the empty prompt press `←` (twice if Claude Code asks): Claude Code shows `Your conversation moved to the background`.
  4. `:qa!`.
  5. In a shell, check that `claude agents --json --cwd <scratch folder> --all` lists that `sessionId` as `"kind": "background"` with a `pid`.

  M9, if it left a background session, is the same setup.
- **M11 — holds the dispatch: what the attached window holds, and whether `Ctrl+L` draws it** (O6).
  1. Open Neovim with aineo in the scratch folder. Wait for the `Opening "…", running in the background (…)` line.
  2. Note what the window shows under the line: nothing; Claude Code's prompt box with an empty conversation; or the conversation.
  3. Run `claude agents --json --cwd <scratch folder> --all` again. Is there now an `interactive` entry with a new `sessionId`? If so, the window holds a fresh session (β). If not, it is attached (α).
  4. Press `Ctrl+L` in Claude's window: does the conversation appear?
  5. If not, run `:vertical resize -5`, then `<C-w>=`: does it appear now?
  6. If it appears, press `\s` on a line in a file buffer: does it reach Claude's prompt? (whether aineo sees the attached view as ready)
- **M12 — holds the dispatch only if O6 comes to (i): the typed `/resume`.**
  1. Repeat the setup and M11's step 1.
  2. In Claude's window type `/resume <the sessionId from the setup>` and Enter: does the conversation appear?
  3. Run `claude agents --json --cwd <scratch folder> --all`: is there a new background entry with no `name`, the empty session moved out?
  4. Repeat steps 1–3 once more: does each start leave one more such entry?
- **M14 — the warning's other Claude Code** (O9; does not hold the dispatch, the fake gives both shapes).
  1. With aineo open in the scratch folder, in a plain terminal in that folder run `claude --resume <aineo's sessionId>`.
  2. Run `claude agents --json --cwd <scratch folder> --all`: are both processes listed, each as `interactive` with its own `pid` and the same `sessionId`?
  3. Then `/exit` the plain terminal's Claude Code.

## Verification mutants — round 2, for (ii) — withdrawn by A164

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks — `tests/test_claude_background_resume.lua` first — and on the whole suite only when it survives there. If the brief is amended for (i), the amendment rewrites 1–3 for the typed `/resume`.

1. The redraw is never written: after the line, the fake receives no `\x0c`.
2. The redraw is written at every start, not only after the line: a plain resume receives `\x0c`.
3. The redraw is written each time the line is redrawn: the fake receives `\x0c` more than once in a start.
4. The interactive-elsewhere warning is dropped: a listed `interactive` entry of the kept id with another `pid` tells nothing.
5. aineo's own entry is not excluded: the warning is told for the entry whose `pid` is aineo's own Claude Code.

The round-1 mutants (for (A)) are withdrawn with it.

## Round 3 — the user's M11, and the orchestrator's rulings

### The user's M11 — 2026-10-12

The user's words are verbatim; the sessions' names are left out, since this repository is public.

- **First run, in a scratch folder.** The user pasted `claude agents --json --cwd .`. It showed two background sessions of the folder, each with a `pid`: one started with "say hi", and one left by a mistaken quit. The user wrote: "after nvim, ]iit reopened the session." Then: "I think I pressed <- but I'm not 100% sure."
- **Second run, with the exact keys:** "I hit <- did qa!, reopened nvim and it resumed the session".

**What it shows.** The setup's background session was idle and small. For it, aineo's start resumed the session as it does today, and the content showed. The reported fault does not reproduce in this case. (ii) and (i) have nothing left to fix that is measured, and M12 is not needed.

The reported case differs from this one, and none of the differences is measured. That session was busy, very large, and running as a background job.

### The orchestrator's rulings — 2026-10-12

Each is the orchestrator's assumption, reported to the user with the wave. None is the user's decision, and none is a D row.

- **A164** — T48 is re-scoped to the part of the user's U1 answer that M11 leaves standing:
  - When the folder's kept session is open in another interactive Claude Code, aineo warns and resumes it all the same.
  - A kept session that runs in the background service is resumed as today; M11 shows that works.
  - The redraw (ii), the typed `/resume` (i), and O6–O8 are dropped.
  - The warning's `claude agents --json` runs beside the start, never before it.
- **A165 (O9 (a))** — "Another interactive Claude Code" is an entry of the kept id whose `kind` is `interactive`, which has a `pid`, and which is not aineo's own Claude Code. aineo's own is the entry whose `pid` is the terminal job's (`jobpid()`), or whose `startedAt` is at or after this start's launch, since a `claude.cmd` that wraps `claude` gives another pid. A list that fails tells nothing.
- **A166 (O10 (a))** — The warning is one line of at most 60 characters, as `SETTINGS_UNREAD_WARNING` is limited. For example `aineo: this session is also open in another Claude Code` (55).

O9 and O10 are ruled by A165 and A166, and O6–O8 fall with A164. U3 stays open, and it does not hold T48. M14 tells the real shape of two interactive processes on one session; it does not hold the dispatch, since the fake gives both shapes.

### Open thread — a background session whose content did not show

The fault the user reported is not reproduced: a start's `--resume` attached to a session running in the background service, and its content did not show until a `/resume` and a pick by hand. It arose with a busy, very large session running as a background job. M11's idle, small session showed its content. Nothing in T48 addresses it.

The next time it happens, the user runs **M15**, before anything else in that window:

1. Note what Claude's window shows under the `Opening "…", running in the background (…)` line: nothing; an empty prompt box; part of the conversation.
2. Note whether the session was busy: Claude Code's spinner, or a turn running elsewhere.
3. In a shell in that folder, run `claude agents --json --cwd . --all`, and keep that session's entry with its name blanked: its `kind`, `state`, `status`, `pid`.
4. In Claude's window press `Ctrl+L`: does the content appear?
5. If not, run `:vertical resize -5`, then `<C-w>=`: does it appear now?
6. Only then use `/resume` and the pick, as before.

What M15 shows decides whether (ii) — the redraw — or (i) — the typed `/resume` — from *Round 2* comes back as a packet of its own.

## Verification mutants — round 3, for the re-scoped T48 — withdrawn by round 4

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks — `tests/test_claude_resume_elsewhere.lua` first — and on the whole suite only when it survives there. The round-1 and round-2 mutants are withdrawn.

1. The warning is dropped: a listed `interactive` entry of the kept id with another `pid` and an earlier `startedAt` tells nothing.
2. The `pid` exclusion is dropped: the entry whose `pid` is aineo's own Claude Code's warns.
3. The `startedAt` exclusion is dropped: an entry of another `pid` started at or after aineo's launch, as a wrapping `claude.cmd` gives, warns.
4. `kind` is ignored: a running `background` entry of the kept id warns.
5. The list runs on a start that does not resume: the fake's record holds an `agents` run beside a `--session-id` start.

## Round 4 — the reproduction, and the user's answer

### The reproduction — 2026-10-12

The user quit a session in aineo with `:qa!` and opened Neovim again in the same folder. The session was the user's own long-running session, busy, and running in Claude Code's background service. The user's words, verbatim: "I just quit this exat session with :qa!, I just hit :qa! aftr reopening nvim, I got this". The paste showed `/resume` typed into Claude's window four times. Each answered with the line below and showed nothing more. The session's name and id are replaced by placeholders, since this repository is public:

> `Opening "[name] (3)", running in the background ([id])`

The paste also shows a turn of that session ending with `Interrupted · What should Claude do instead?`, twice. That fits E3: aineo's quit pressing Ctrl-C into a terminal attached to a busy background session. It is not measured.

### The user's answer — 2026-10-12, verbatim

- Q: "When this folder's session is running in Claude Code's background service (like this orchestrator session), what should aineo show in Claude's window at start?" — A: "Ask at start" (option text: "A one-line choice at start: attach to the running session, or start a new one.")
- Then: "also I renamed this session, not sure if this is the cause"

**What follows.** This answer replaces the background half of U1 ("if it is running in the background, resume") and A164's "a background session is resumed as today". The interactive half of U1 stands: warn, and resume all the same. U2 stands: the quit of aineo's own session is unchanged until M9 and M10. U3 stands: the quit of an attached terminal changes only after a check of `Ctrl+Z`. M16 is that check.

### Did the rename cause it? — the answer to the user

No. aineo keeps the session's id for the folder, never its name. It starts Claude Code with `--resume <id>` (`kept_or_new_session()` and `session_arguments()`, `lua/aineo/claude/init.lua`). A rename changes the session's title and nothing else. The `Opening "…" (…)` line names the same id aineo resumes. The `(3)` in the name is Claude Code's own numbering, added when a session moves to the background while rows of the same name are already listed (D3). The cause is where the session runs: in the background service, and busy.

### The design

**1. Knowing before the start.**
- A start that would resume first lists the folder's sessions with T46's reader. `list_sessions()` runs `claude.cmd` followed by `agents --json --cwd <folder> --all`, bounded at 5 s and 1 MiB, and is killed when Neovim quits.
- Claude Code launches only once the list has answered. The list's answer chooses the command.
- A start on a new id lists nothing and launches at once, as today.
- A list that cannot run, fails, times out, prints too much or is not JSON resumes as today, and tells nothing.

**What the editor shows meanwhile (O13).** `start_session()` still returns the terminal buffer at once. The layout shows it in Claude's window, empty, with the status line it has at any start (`Claude Code — <folder>`). `session_status()` is `'starting'`. Claude Code launches in that same buffer once the list answers. The buffer is then already shown at its window's size, which a start today does not promise (`start_session()`'s docstring, 5 rows). Every error `start_session()` raises today it still raises at once, before the list runs. While the start waits for the list:
- a second `start_session()` returns the same buffer and starts nothing;
- `write_to_session()` raises, as when no session runs;
- a quit has nothing to stop;
- a wiped buffer, or a quit, means nothing is launched when the list answers.

**2. What the list decides.** It looks at the entries of the kept id.
- **Running in the background service:** `kind` is `background`, there is a `pid` or a `status`, and the entry has the short `id` that `claude attach` takes (D5). Then aineo asks (O12):
  - The prompt, at most 60 characters, for example `This folder's session runs in the background` (44).
  - Two items, in the user's order: `Attach to it` and `Start a new session`.
  - Esc, or an empty answer, starts a new session. It is the choice that leaves the background session untouched and gives aineo's own flags.
  - The start at startup (`autostart`) asks too, once the list has answered.
  - A background entry with no short `id` is not asked about. It resumes as today.
- **Open in another interactive Claude Code:** `kind` is `interactive`, with a `pid`. aineo warns with A166's line, then resumes. When the list runs, no Claude Code of this editor is running yet, so every such entry is another one: an editor of the user's, or a plain terminal. A165's own-entry rule falls (O16).
- **Both kinds listed:** the background entry is asked about, and no warning is told.
- **Anything else:** resume as today.

**3. Attach** *(part 2, held for M16)*.
- The terminal's command is `claude.cmd` followed by `attach <short id>`, with none of aineo's flags.
- The attached session runs with the flags it was started with (D4). This start's session hooks, the report server and its instructions, and `--allowedTools` are not given. Switches inside it are not followed. Its Report may get nothing, and Claude may ask permission for tools aineo allows.
- How the panes show it (O14): one line at the attach, at most 60 characters, for example `aineo: attached to a background session (no Report)` (51). Claude's status line reads `<name> (attached) — <folder>` while it runs.
- **Every stop of an attached terminal detaches with `Ctrl+Z` (`\26`) and never presses Ctrl-C.** In an attached terminal Ctrl-C cancels the background session's running turn (D2). `Ctrl+Z` "detaches but goes back to where you started … your shell if you ran `claude attach`" (D2). aineo's quit presses `Ctrl+Z`, waits for the attach to exit, and only then hangs up, as today's stop does after its keys. A wipe hangs up, as today; M16 step 6 measures what a hang-up does to the background session (O15).
- **The kept id stays the background session's (D23, D38, D51).** Nothing in an attached terminal tells this start's hooks of a switch. A `/resume` typed in it only prints a `claude attach` command (D1). `\S` is left as it is. The next start asks again while the session still runs in the background.
- A `←` typed in the attached terminal detaches it to agent view inside aineo's window (D2). That is Claude Code's own behaviour, and aineo leaves it alone.

**4. New.**
- A new session starts as a start with no kept id does: `--session-id` on a new id, kept for the folder (D23). The background session is not touched, attached, stopped or forked.
- aineo tells one line, at most 60 characters, for example `aineo: started a new session; the background one runs on` (56).
- The next start in the folder resumes the new session. The background one is reached with `claude attach` or agent view. `\S` lists it as running elsewhere.

**5. The split (O11).**
- **Part 1, dispatched now:** the list before the start, the start that waits for it, the interactive warning, and the fields the reader keeps (`pid`, the short `id`). A background session is still resumed as today in part 1.
- **Part 2, after M16:** the question, the attach with its stop and mark, and the new session.

So part 1 changes nothing the user sees at a background start, and part 2 changes it all at once.

### Decisions for the orchestrator — round 4

The orchestrator rules each before dispatch. The recommendation is (a), and the brief is written for it.

- **O11 — The split.** (a) Two dispatches, as *The design* 5 says. Part 2 is a dated section of the same brief, on its own branch from `dev` once part 1 has merged. (b) One dispatch, held for M16. Simpler, but the warning and the waiting start wait for the user too.
- **O12 — The question's form.** (a) `vim.ui.select`, as `\S` offers its list. The user's own picker shows it, and the suites can stub it. Cancel means a new session. (b) `confirm()` with the buttons `&Attach` and `&New session`, default New. That is closer to one line in the default UI, but it blocks, and the suites cannot answer it as easily.
- **O13 — What the editor shows meanwhile.** (a) The empty window and the status line, as *The design* 1 says, with no message. The list's time on the user's machine is M16 step 2. (b) A line in the buffer while it waits. A terminal needs an unmodified buffer, so the line must be cleared before Claude Code launches.
- **O14 — How an attached terminal shows.** (a) The one-line note at the attach, and `(attached)` in the status line. (b) The note only.
- **O15 — The stop of an attached terminal.**
  - (a) `Ctrl+Z`, then a wait of the time M16 step 4 measures, rounded up; then the hang-up and its wait, as today. A wipe hangs up as today, unless M16 step 6 shows that a hang-up stops the background session. That would be a later packet.
  - (b) `Ctrl+Z` and its wait, with no hang-up after it.
- **O16 — The warning's rule.** (a) An entry of the kept id, `kind` `interactive`, with a `pid`. The list runs before this editor's Claude Code exists, so no entry is its own. This replaces A165; A166's text stands. (b) Keep A165's `pid` and `startedAt` exclusions as a guard.
- **O17 — Which id `claude attach` is given.** (a) The entry's short `id`, which the docs name as "usable with `claude attach`" (D5). An entry without one is not asked about. (b) The full `sessionId`. Nothing read says `claude attach` takes it.

No question for the user: the answer settles the D row, and what remains is how the behaviour is built.

### Manual check M16 — holds part 2

In a scratch folder you trust, where no session you need runs. Read `<id>` as the short `id` that step 2 prints.

1. In a plain terminal in the scratch folder, run `claude`. Send `say hi` and wait for the answer. On the empty prompt press `←` (twice if asked): Claude Code shows `Your conversation moved to the background`. Press `Ctrl+C` twice to leave agent view.
2. Run `time claude agents --json --cwd . --all`. Note the time it took, and the entry's `id`, `sessionId`, `kind` and `pid`.
3. Run `nvim --clean`, then `:terminal claude attach <id>`, then `i`.
   - Does the conversation show?
   - If not, press `Ctrl+L`. If it still does not show, run `:vertical resize -5`, then `<C-w>=`. Does it show now?
4. Type `say hi again` and Enter: does it answer? Then press `Ctrl+Z`.
   - Does the terminal end with `[Process exited <code>]`? Note the code, and about how long it took.
5. In the plain terminal, run `claude agents --json --cwd . --all`. Is the entry still listed with a `pid`?
6. In Neovim, run `:terminal claude attach <id>` again, then `:bwipe!`. This is the hang-up that wiping aineo's terminal gives. Repeat step 5: is it still running?
7. Optional, a busy session. Attach as in step 3 and send `Run "sleep 30" in Bash, then say done`. While it runs, press `Ctrl+Z`. A few seconds later, step 5: is `status` `busy`? Attach again after 30 s: does the conversation show `done`?
8. Clean up with `claude stop <id>`.

Report steps 2–7 as you saw them, with names and ids left out. Part 2 is planned as written when steps 3, 4 and 5 hold. If step 3 shows nothing, even after `Ctrl+L`, the attach does not render in Neovim's terminal, and part 2 is re-planned.

## Verification mutants — round 4

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks — `tests/test_claude_resume_elsewhere.lua` first — and on the whole suite only when it survives there. Mutants 1–3 are part 1's, and 4–5 are part 2's.

1. **The list after the launch.** Claude Code launches on `--resume` at once, and the list runs beside it: the fake's record holds Claude Code's start before the `agents` run.
2. **A failed list launches nothing.** With `AINEO_FAKE_CLAUDE_AGENTS_EXIT` set, the start stays waiting, and Claude Code never starts.
3. **The warning is dropped.** A listed `interactive` entry of the kept id with a `pid` tells nothing.
4. **Esc attaches.** `vim.ui.select`'s `nil` answer attaches instead of starting a new session.
5. **The attached terminal's quit presses Ctrl-C.** The quit uses `stop_by_keys()` for an attached terminal, so the fake receives `\3` and no `\26`.

## The orchestrator's rulings — 2026-10-12, before dispatch (round 4)

Each is the orchestrator's assumption under the user's instruction of 2026-10-06 ("assume your recommendations and report what they were after you finish"), reported to the user; none is the user's decision. Each takes the recommendation (a).

- **A185 (O11)** — two dispatches: part 1 (the list before the start, the waiting start, the warning, the reader's `pid` and short `id`) now; part 2 (the question, attach, the Ctrl+Z stop, new) after the user's M16, on its own branch.
- **A186 (O12)** — the question is `vim.ui.select`, as `\S` uses; cancel means a new session.
- **A187 (O13)** — while the list runs, Claude's window is empty and the status line is as at any start; no message.
- **A188 (O14)** — an attached terminal shows a one-line note and `(attached)` in the status line.
- **A189 (O15)** — an attached terminal's stop presses Ctrl+Z, waits as long as M16 step 4 measures, then hangs up as today; a wipe hangs up unless M16 step 6 shows that stops the session.
- **A190 (O16)** — the warning's rule is the kept id, kind interactive, with a `pid`; it replaces A165. A166's text stands.
- **A191 (O17)** — `claude attach` is given the entry's short `id`; an entry without one is not asked about.

## Briefs

- `brief-t48-background-resume.md` — T48, rewritten 2026-10-12 for round 4: part 1, dispatched once O11–O17 are ruled, and part 2, held for M16. Its round-3 text, written for A164's re-scope with A165 and A166, is in this pull request's third commit.
- *Round 3, as written:* `brief-t48-background-resume.md` — T48, rewritten 2026-10-12 for round 3: A164's re-scope, with A165 and A166. Nothing holds its dispatch. The round-1 brief, written for (A), and the round-2 brief, written for (ii), were never dispatched; their text is in this pull request's first and second commits.

## Landed

Not yet.
