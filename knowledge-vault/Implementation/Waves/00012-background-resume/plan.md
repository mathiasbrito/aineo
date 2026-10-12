---
wave: 00012
status: planned
rolling: false
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for the user
planned_at: 2026-10-12
base: 1dc3186
claimed_by:
claimed_at:
landed_at:
pull_requests:
---

# Wave 12 — a start that resumes a background session

**Planned by:** the orchestrator's planning agent, 2026-10-12. **Base:** `dev` `1dc3186` (wave 11 landed).
**Ask:** the user's fix request of 2026-10-12 (verbatim below).
**Composition from:** [[Planning/aineo — v1 agent console]] › D23, D36–D38, D42, D45, D49, D51, D53, C3, R2 and the proposed D54 and T48 this plan writes; [[Implementation/Waves/00011-names-and-sessions/plan]] for the form and for T46, whose `claude agents --json` reader this packet reuses; [[Projects/aineo]].

**One packet, T48, held for the user's answer U1.** The cause is established up to how the folder's kept session came to run in the background service, which only the user's manual checks can tell (M9–M11); the fix the plan recommends does not depend on that answer. The brief is written for this plan's recommendations; an answer that differs is a dated amendment before dispatch.

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

## Proposed D54 — written into the plan note with the request's decided parts only

The row's decision column, as written into [[Planning/aineo — v1 agent console]]; its reasoning column quotes the request. What is undecided is named as open, for U1 and U2.

> **D54** — A start of Claude Code that would resume the folder's kept session (D23, D38) does not open that session in aineo's terminal while it runs in Claude Code's background service, where Claude Code 2.1.296 attaches aineo's terminal to it and the session's content does not show. Open, and not part of this row until the user answers them (wave 12's plan, *Questions for the user*): what the start does instead — recommended, a new session with the background one left untouched, found by a `claude agents --json` run before each start that resumes (U1); and whether aineo's quit changes (U2) (amends D23 and D38; touches C3)

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T48 | T48 | `neovim-claude-code-integrator` / sonnet | `lua/aineo/claude/init.lua` (the start: `start_session()`, `start_in_place()`, `launch()`, `kept_or_new_session()`), `lua/aineo/claude/agents.lua` (a predicate on a listed session, if needed); `tests/helpers/fake_claude.lua` (its `agents --json` answer: a delay, if a case needs one), `tests/helpers/claude_session.lua` (`wait_for_starts()` counts Claude Code's starts, not the list's runs); a new `tests/test_claude_background_resume.lua`, `tests/test_entry_sessions.lua` and `tests/test_claude_agents.lua` where a helper's change moves them; `doc/aineo.txt` › *aineo-claude-session* and *aineo-limits* (*Stopping Claude Code on quit*, *The session list*) | no | no | U1 (the user's) | own |

**Rule 1, dependencies.** T48 rests on T46's reader, merged. ✓
**Rule 2, files.** One packet. ✓
**Rule 3, schema.** None. ✓
**Rule 4, dependencies.** None. ✓
**Rule 5, decisions.** U1 before dispatch; O1–O5 are the orchestrator's. ✓ once answered.
**Rule 6, task lines.** One packet: it marks its own line. ✓

**Class: regular.** It changes what a start does (D23, D38, proposed D54). Its home is `lua/aineo/claude/` and it starts a process, both of which §3 of the orchestrate skill keeps from a small fix (D30's waves included).

## Host and reviewers

| packet | implementer | reviews | session note | resource | branch |
|---|---|---|---|---|---|
| T48 | `neovim-claude-code-integrator`, model sonnet | attack by `neovim-claude-code-reviewer` (Opus); tests and records together by one `records-reviewer` (Sonnet); one fix round; the orchestrator's own check | `Sessions/<date> — T48 Background resume.md` | `impl_t48_background_resume` | `bugfix/t48-background-resume` |

D26: the whole suite once before each push. The start path is exercised by most entry suites, and the helper change moves every suite that counts starts.

## Decisions for the orchestrator

Numbered once, here. The recommendation is (a). The brief is written for it.

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

## Questions for the user

Only what changes a D row, or needs the user's own measurement. Each recommendation is (a).

**U1 — when the folder's session is running in Claude Code's background service, what does aineo's start do?** (proposed D54)
- (a) It starts a new session in aineo's window and tells you, leaving the background one alone. You find that one with `claude attach <id>` or in agent view, and `\S` lists it as running elsewhere. To know, aineo runs `claude agents --json` before each start that resumes, so Claude's window comes up later by however long that takes (at most 5 s). If the list fails, the start resumes as today. Recommended.
- (b) The same check, but it opens a copy of the conversation (`--fork-session`), so you see the content. Two copies of the conversation then work in the same folder.
- (c) The same check, but it stops the background session (`claude stop`) and resumes it in aineo's window, with aineo's report and hooks. Whatever that session was running stops.
- (d) No change at start. A later wave measures why the attached session's content does not show (M11), and fixes the display.

**U2 — aineo's quit.** Claude Code's documentation says a session with background work running (subagents, background commands, workflows, monitors) shows a `Background work is running` dialog on exit, whose `Move to background and exit` moves it to the background service. aineo's quit presses Ctrl-C and then hangs the terminal up, and what that does to such a session is not documented.
- (a) No change in T48. Measure first (M9, M10). If the quit does move such a session to the background, its work goes on there, and under U1 (a) the next start begins a new session and tells you. Recommended.
- (b) After M9: if it does move it, change the quit so the session stays aineo's, and the work it was running ends. That changes R2 and C3's "clean stop on quit", and would be planned in a later wave.

## Manual checks — the user's, in a scratch folder you trust, where no session you need runs

None of these touches a session of yours elsewhere. Afterwards, stop only the scratch folder's own background session, by the id `claude agents --json` printed for that folder.

- **M9 — does aineo's quit move a session with background work to the background service?** (H1 (a), U2) Open Neovim with aineo in the scratch folder. In Claude's window type `Start "sleep 900" with the Bash tool in the background, then tell me it runs.` and wait for Claude to say it runs. Then `:qa!`. In a shell, run `claude agents --json --cwd <scratch folder> --all`. Look for an entry with `"kind": "background"`, a `pid`, and a `sessionId` that `:lua print(require('aineo.claude').session_id())` printed before the quit. If there is one, the quit moved the session to the background. If there is none, it did not.
- **M10 — the same with no background work.** Claude idle with nothing running, then `:qa!`, then the same command. A live entry for the session would mean the hang-up alone moves it.
- **M11 — what aineo's window shows on the attach** (U1 (d); E2, E3). Only if M9 left a background session. Open Neovim in the scratch folder again. Look for `Opening "…", running in the background (…)` and note what the window shows below it. Then press `Ctrl+L` in Claude's window, then `<C-w>=`: does the conversation appear? Then type `say hi` and Enter, let it answer, and `:qa!`. In the shell run the same command again: is the session still listed with a `pid`? And in agent view, does its last turn show as interrupted?

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks — `tests/test_claude_background_resume.lua` first — and on the whole suite only when it survives there.

1. The check is skipped: a kept id listed as a running background session is resumed (`--resume <kept>` in the fake's record).
2. `running` is ignored: a background entry of the kept id with neither `pid` nor `status` makes a new session where it should resume.
3. The failure path is inverted: `agents --json` exiting 3 makes a new session where it should resume.
4. An `interactive` running entry of the kept id makes a new session (O1 (a)).
5. The new session is handed the background session's Report records (D45's hand-over called).

## Briefs

- `brief-t48-background-resume.md` — T48, written for U1 (a), U2 (a) and O1–O5 (a). It is dispatched after the user answers U1; M9–M11 do not hold it.

## Landed

Not yet.
