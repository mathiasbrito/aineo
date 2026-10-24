# aineo — session attach

## Context
**Project:** [[Projects/aineo]]
**Spec it adds to:** [[Planning/aineo — v1 agent console]] — D54, D62 and T48 (aineo already attaches Claude's window to a background session at a start and from `\S`), D116–D118 and T141–T143 (claims that survive a restart, follow a fork and carry Input). The orchestrator's rulings it rests on, of 2026-10-24: A609 (T144 comes after T141–T143, one packet at a time), A613 (while a claim holds, Send, a Visual Send, `\S` and `:Aineo new` are refused; "sending into a session another process runs comes with T144"), A619 (this pass may start one throwaway background session, on Haiku, with at most two one-line prompts, and never touches the user's own sessions).
**Raised by:** the user's wish to type into a session another process runs from the tab that shows it (A613, told to the user with D116).
**Drafted by:** a measure-and-propose agent (Claude, Opus 5.5, `neovim-claude-code-integrator`), 2026-10-24, for the orchestrator to put to the user. **Status: proposal** — nothing here is decided; the user answers *Questions* (AQ1–AQ6) in a converge round, and only then is a packet planned.
**Task:** T144 (measure `claude attach`, then propose).
**Session:** [[Sessions/2026-10-24 — T144 session attach measured]]

## ID legend
- `D#`, `A#`, `C#`, `T#` — the v1 plan's rows and the orchestrator's rulings, as recorded there
- `AF#` — a fact read in Claude Code's documentation or `--help`, with where it was read
- `AM#` — a fact this pass measured, with the command that showed it
- `AC#` — what aineo does today, read in its code and help
- `AD#` — a design proposed here
- `AR#` — a risk
- `AQ#` — a question only the user can answer, its recommended option first

## The ask

A claim (`:Aineo claim {id}`, and a fork the tab follows, D117) mirrors a session another process runs: the Report, the changes pane, the office and Input's draft follow it, while the tab's terminal runs the tab's own `claude --resume <own id>` with aineo's `--mcp-config`, `--settings` (hooks carrying the start's token) and `--append-system-prompt`. Send, `\S` and `:Aineo new` are refused while the claim holds (A613). The user wants to type into the claimed session from the tab.

## What aineo does today (read in the code, `dev` at c9548524)

- **AC1** — A start that would resume the session kept for the folder lists the sessions first (`claude agents --json`, bounded) and, when that session runs in Claude Code's background service with a short id, runs `claude.cmd attach <short id>` in Claude's window instead of `--resume`, with none of aineo's flags (`aineo.claude`'s `attach_to()`, `arguments.attach_command()`; T48, D54). It tells `aineo: attached to a background session (no Report)` and the status line reads `(attached)`.
- **AC2** — An attached window is stopped with Ctrl+Z alone, then hung up after 4 s (`stop.detach()`, A227); `\N` and `\S` replace it instead of writing a slash command into it (A226); an attach that exits non-zero within 2 s is followed by a resume of the session (A230). `\S` joins a background session by attaching (D62), and the joined session becomes the one kept for the folder.
- **AC3** — A claim never touches the terminal. Reports of the claimed session reach the claiming Neovim through the claims (help *aineo-report-claims*) — from that session's own report server, which a session has only when it was started with aineo's `--mcp-config` (a fork of an aineo tab carries it; AF4). The office follows the claimed session's transcript.
- **AC4** — `tests/helpers/fake_claude.lua` already models `attach <id>`: it records its arguments, draws a ready screen, exits 0 on Ctrl+Z, and can print a line and exit 1 (`AINEO_FAKE_CLAUDE_ATTACH_SAYS`).

## Facts read — Claude Code 2.1.310

Read 2026-10-24: `--help` output on the host, and the documentation pages `https://code.claude.com/docs/en/agent-view.md` and `https://code.claude.com/docs/en/sessions.md`, fetched raw (`curl`), quoted by section.

- **AF1** — `claude attach --help` (exit 0): "Usage: claude attach <id|name> — Open the background session in this terminal. ← returns to agent view, Ctrl+Z drops back to your shell. The session keeps running either way. Part of the session name works in place of the id." `claude --help` lists the commands `agents`, `attach`, `logs`, `respawn`, `rm`, `stop|kill` ("Its conversation is kept: `claude attach <id>` opens it again, `claude --resume` works once it is stopped").
- **AF2** — `claude --help`, `--bg, --background`: "Start the session in the background and return immediately. Prints the id that `claude attach`, `logs`, `stop` and `rm` take … With --resume <session-id>, continues that session in the background under the same ID, or starts a copy and says so when the session is already running."
- **AF3** — `claude agents --help`: `--settings`, `--mcp-config`, `--strict-mcp-config`, `--plugin-dir`, `--add-dir`, `--setting-sources`, `--permission-mode`, `--model` apply "to the agent view and dispatched sessions"; `--json` "Print active sessions (interactive and background) as a JSON array and exit (for scripting; does not require a TTY)"; `--all` adds completed background sessions; `--cwd <path>` scopes to sessions started under a path. agent-view.md, *List sessions as JSON*: fields `cwd`, `kind`, `startedAt` always; `id` (short id) and `state` (`working`, `blocked`, `done`, `failed`, `stopped`) for background sessions; `pid`, `status` (`busy`, `waiting`, `idle`) while the process lives; `waitingFor` (`permission prompt`, `input needed`, …); `sessionId`, `name` when set.
- **AF4** — agent-view.md, *What carries over when you background*: "Configuration flags from the original launch carry through to the backgrounded session, so its MCP servers, settings, and fallback model remain in effect": `--mcp-config`, `--strict-mcp-config`, `--settings`, `--setting-sources`, `--add-dir`, `--plugin-dir`, `--fallback-model`, `--allow-dangerously-skip-permissions`. *What persists across restarts*: the permission mode, model, effort and those flags persist when the supervisor restarts the session's process.
- **AF5** — agent-view.md, *Attach to a session*: attached sessions always render fullscreen; "Press `←` on an empty prompt, or run `/exit`, to detach and return to agent view, whether you opened the session from agent view or with `claude attach <id>` from your shell"; "`Ctrl+Z` also detaches but goes back to where you started instead: … your shell if you ran `claude attach`"; "`Ctrl+C` keeps its standard interrupt behavior while attached: it cancels a running response … Pressing `Ctrl+C` twice on an empty prompt detaches"; "Detaching never stops a background session".
- **AF6** — sessions.md, *Resume a running background session*: "`claude --resume <session>` runs `claude attach` on that session in the same terminal instead of loading the transcript itself", but not when the command line has "Flags that configure the session, such as `--permission-mode`, `--model`, or `--settings`": then "Claude Code sends nothing and exits with status 1 … Add `--fork-session` to resume a copy of the conversation instead. To continue the conversation itself in a session of your own, with your flags applied, run `claude stop <id>` and then repeat the command." Inside a session, `/resume` of such a session moves the current conversation to the background and attaches the terminal to it.
- **AF7** — agent-view.md, *Opening a session says the conversation is already open*: "Two processes can't write to the same transcript."
- **AF8** — agent-view.md, *The supervisor process*: a session finished or waiting for the next message and unattached for about an hour has its process stopped; "the next time you attach or reply, the session resumes where it left off".
- **AF9** — agent-view.md, *Peek and reply*: a reply typed in agent view's peek panel (`Space`) is sent to the session without attaching; a permission prompt cannot be answered from there ("replying doesn't answer it … To answer the dialog, attach"). `claude --help` names no command that sends a prompt to a background session without attaching; `claude --resume <session> "prompt"` sends it and then attaches (AF6).
- **AF10** — agent-view.md, *Dispatch an agent from your shell*: `claude --resume <uuid> --bg "…"`, on 2.1.257 or later, "either continues that session under the same ID, or starts a copy under a new ID and prints a `note:` line". *Manage sessions from the shell*: attaching by name needs 2.1.290; sessions.md: `--resume` attaching to a running background session needs 2.1.285.

## Facts measured — Claude Code 2.1.310, Neovim 0.12.5

How: one headless Neovim (`nvim --clean --headless --listen 127.0.0.1:<port>`), driven over RPC, each `claude` in a terminal of its own tab (`jobstart(cmd, { term = true })`, 120 columns); every `CLAUDE*`, `NVIM`, `NVIM_LOG_FILE` and `AINEO_CHILD` variable inherited from the orchestrating session removed first. The one throwaway session (A619) ran on Haiku in a scratch folder under the worktree's ignored `.tests/`, with a `--settings` whose hooks (`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`, `Stop`, `SessionEnd`) appended the event, the session, two marker variables and the pid of the Claude Code process that ran them to a log. Two prompts were sent, both one line. `<short>` and `<uuid>` stand for its short id and session id. The user's sessions were listed only by `claude agents --json --all`, before and after; the set was the same (46 entries).

- **AM1** — `claude --bg --model haiku --name <name> --settings <hooks> "<prompt 1>"` → exit 0, at once, printing `backgrounded · <short> · <name>` and the four lines `claude agents`, `claude attach <short>`, `claude logs <short>`, `claude stop <short>`. The short id was the first eight hex digits of the session id. The session's process was `claude bg-spare --bg-spare <socket>` — none of the dispatch's flags in its argv.
- **AM2** — Those hooks ran in the background process (`SessionStart` `startup`, `UserPromptSubmit`, `Stop`; their parent pid the background process's). A variable exported in the dispatching shell was empty in every hook: the dispatcher's environment does not reach the session's hooks — flags carry (AF4), the environment does not. (aineo's start token travels inside `--settings` and `--mcp-config`, so it carries.)
- **AM3** — Claude Code's registry entry for the background process (`sessions/<pid>.json`, fields read, values not kept): `pid`, `sessionId`, `cwd`, `startedAt`, `procStart`, `version`, `peerProtocol`, `peerFeatures`, `kind` (`bg`), `entrypoint`, `pidDomain`, `messagingSocketPath`, `name`, `nameSince`, `jobId`, `status`, `updatedAt`, `statusUpdatedAt`, `nameSource`, `bridgeSessionId`. An attaching client wrote no registry entry, made no `claude agents --json` entry, and ran no hook.
- **AM4** — `claude attach <short>` in a Neovim terminal drew the session's own screen, fullscreen: the banner (version, model, folder), the conversation, the rule carrying the session's name, the prompt `❯ `, and the footer `⏵⏵ auto mode on (shift+tab to cycle) · ← 7 agents`. Nothing on it says the terminal is attached. aineo's readiness signal (the prompt glyph with no trust-dialog text) holds on it.
- **AM5** — A second `claude attach <short>` at the same time drew the same screen. Text typed in one terminal showed in the other's input box: **the attached terminals share one input box**. Shift+Tab in one changed the mode shown in both (auto → manual → accept edits → plan → auto).
- **AM6** — A bracketed paste of prompt 2 into the first attached terminal landed unsubmitted, in both; Enter (`\r`) submitted it. The `UserPromptSubmit` hook ran in the background process, without the marker variable the attaching terminal's job had in its environment. The session's transcript grew from 51 to 72 lines: **text typed into an attached terminal is the session's own next turn**.
- **AM7** — In manual mode prompt 2 asked for a Bash call. The permission dialog ("Bash command … Do you want to proceed? 1. Yes / 2. Yes, and always allow access to <folder> from this project / 3. Yes, and switch to auto mode / 4. No") drew identically in both attached terminals (byte-identical screens); `PreToolUse` and `PermissionRequest` ran in the background process; `claude agents --json` read `status` `waiting`, `waitingFor` `permission prompt`, `state` `blocked`. Answering `4` in the second terminal answered it for both ("Interrupted · What should Claude do instead?"); nothing was run. After it, the entry read `status` `idle` with `state` `working` until the stop.
- **AM8** — `claude attach <short> --settings <file>`, `… --mcp-config <file>` and `… --no-such-flag` each attached all the same, and printed `warning: extra arguments ignored: <the words>` (seen on the normal screen once the attach ended); no hook of the given settings ever ran. **`claude attach` takes none of aineo's flags**: an attached terminal runs under whatever the background session was started with.
- **AM9** — Ctrl+Z: the attach exited 0 and the session ran on (the other terminals stayed attached). `←` on the empty prompt: the same process turned into agent view, which lists every session of the user (footer `enter to return · space to reply · ctrl+x to delete · ? for shortcuts`); a double Ctrl-C there exited 0. `/exit` and Enter: agent view too, not an exit. `jobstop()` (SIGHUP): exit 129, the session ran on.
- **AM10** — `claude stop <short>` (exit 0, `stopped <short>`) with two terminals attached: each printed `Resume this session with:`, `claude --resume <uuid>`, `Session <short> has exited.` and **exited 0** — the same code as a detach. `SessionEnd` ran in the background process; its registry entry was removed; the list read `state` `stopped`, no `pid`.
- **AM11** — `claude attach <short>` on the stopped session restarted it: a new background process, the same session id, `SessionStart` with source `resume`, the dispatch's hooks still running and manual mode kept.
- **AM12** — `claude attach deadbeef` (no such session): `No job matching 'deadbeef'. Run 'claude agents' to list running sessions.`, exit 1 after 230 ms.
- **AM13** — `claude --resume <uuid>` with no other flag, on the running session: the process became `claude attach <short>` (`ps`) and drew the session — no registry entry, no `SessionStart`, so no second writer. With `--settings <file>`, and with aineo's own flag set (`--mcp-config <file> --append-system-prompt x --allowedTools Read`): exit 1 after about 1.1 s, nothing sent, printing ``That session is running in the background (<short>). Run `claude attach <short>` to open it, or `claude stop <short>` first to resume it here. Add --fork-session to branch off a copy instead.`` (`--fork-session` was not run: it makes a second session, which A619 does not allow.)
- **AM14** — After the stop: `claude --bg --resume <uuid> --settings <other hooks>`, no prompt → exit 0, `backgrounded · <short> (idle — send a prompt to start)`, the same short id; only the new settings' hooks ran (`SessionStart` `resume`), the old ones did not. **A stopped background session can be continued in the background, in place, under a new set of flags.**
- **AM15** — Clean-up: `claude stop <short>`, `claude rm <short>` (both exit 0); no process of the measurement left; the list's set of sessions equal to the one before.

## What decides the design

1. **Typing into a session another process runs means attaching to it** (AM6, AF9). The only other path, agent view's peek reply, cannot answer a permission prompt, and has no command-line form.
2. **An attached terminal carries nothing of aineo's** (AM8, AM6): its hooks, MCP servers and permission mode are the background session's own. A session that left an aineo tab (`←`, `/fork`, `/background`) carries that tab's hooks and report server, naming that start's token and that editor (AF4, AM2) — stale after the editor restarts; a session Claude Code started elsewhere has none of aineo's.
3. **The only way to give a background session this tab's flags is to stop it and start it again** (AF6, AM13, AM14): in the tab as an interactive session (`--resume` with aineo's flags), or back in the background under the same id (`--bg --resume` with aineo's flags) and then attach. Both end its process, and with it a turn in flight.
4. **One input box per session, whoever is attached** (AM5): aineo's empty-prompt check and paste see what any other attached terminal typed.
5. **Exit 0 means both "detached" and "the session ended"** (AM9, AM10); only the screen tells which (tier 2: `Session <short> has exited.`).
6. **aineo already has the attach** (AC1, AC2, AC4): the command, the stop by Ctrl+Z, the `(attached)` mark, the replacement path for `\N`/`\S`, and a fake that models it. What is new is coupling it to a claim.

## Designs

### AD1 — a claim of a background session attaches the tab's terminal

While a claim holds a session that runs in Claude Code's background service with a short id (`agents.way_to_join()` says `'attach'`), the tab's terminal runs `claude attach <short>`; releasing the claim (`:Aineo claim` without an id, or a claim of another session) detaches it with Ctrl+Z and resumes the tab's own session there.

- **The user sees** Claude Code's own screen of the claimed session in Claude's window, `(attached)` in its status line, and types or sends into it as into any session; the Report, changes pane, office and Input follow it as a claim does now.
- **Send, Visual Send** paste into the attach (AM6 says it lands and submits); `\S` and `:Aineo new` replace the attached terminal as they do after a T48 attach (AC2). A613's refusals stay for a claim that cannot attach — a session open in another interactive Claude Code, or one without a short id.
- **The tab's own Claude Code** must leave the terminal first: stopped as `\S` stops it (T48's replace path) and resumed on release — or refused while it is busy (AQ2).
- **What breaks**: the attach runs none of this tab's hooks or report server (AM8). A fork of this tab, in this editor's lifetime, still reports and hooks here; a fork from before a restart hooks under a token no tab holds (reports still arrive through the claim, AC3); a session Claude Code started elsewhere gives no Report and no permission signal to the office (`ATTACHED_NOTE` already says "(no Report)"). Permissions are answered in the tab's terminal (AM7) — any attached terminal can answer. `←` in Claude's window opens agent view there (AM9; the help's limit of A231 today). A restart: T141 claims again and the start attaches (AC1). The quit: Ctrl+Z (AC2).
- **Cost**: medium. New: the claim ↔ terminal coupling in `aineo.entry`'s tab, the release path back to the own session, lifting A613's refusals for an attached claim, the "session has exited" end (AR3); `aineo.claude` gains a way to attach to a named session on request, near `join_session()`.
- **Tests**: the fake's `attach` gains the session's end (`Session <short> has exited.`, exit 0); claim → attach (no aineo flag on the command), release → Ctrl+Z then `--resume <own>`; Send into an attached claim reaches the fake's input; a non-attachable claim still refuses; the own session busy (AQ2); a restart re-attaches; the end of the session returns the tab to its own (AQ4).

### AD2 — claims stay read-only; `:Aineo attach` opens the claimed session beside them

`:Aineo attach` (and a key) opens `claude attach <short>` of the claimed session in a floating window or a split of the tab; closing it presses Ctrl+Z. The tab's terminal keeps running its own session.

- **The user sees** a second Claude Code screen over or beside the panes and types in it directly; Input and Send stay refused while the claim holds (A613), unless Send is made to target the open float (AQ1 option).
- **What breaks**: two Claude Code screens in one tab, which one Send would reach is unclear; the same hook and Report limits as AD1, but nothing of the tab's terminal changes, so no own-session stop and no release path.
- **Cost**: low — a terminal window and the existing attach command and Ctrl+Z stop; nothing in the claim's state.
- **Tests**: open and close (Ctrl+Z on close, exit tolerated), refusal for a non-attachable claim, a failing attach told once, the float closing when the attach ends.

### AD3 — take the session over: re-home it under this tab's flags

`:Aineo take` on a claimed background session that is idle (`status` `idle`, `state` `done`): `claude stop <short>`, then `claude --bg --resume <uuid>` with this tab's aineo flags (a fresh start token, this editor's report server), then the tab's terminal attaches (AD1's machinery). Variant AD3′: after the stop, resume it in the tab's own terminal with aineo's flags (`--resume <uuid>`), so it becomes the tab's own interactive session and leaves the background service.

- **The user sees** what AD1 gives, plus everything of aineo: Report tool, hooks with this tab's token, the office's permission signal, `/clear` and `/resume` followed.
- **What breaks**: the stop ends the process; a turn in flight is lost, so the take is refused while the session is busy or waits on a permission (AM7's `waitingFor`). Not measured here: what `--bg --resume` does to work the stopped process carried (AF8 says background commands and subagents carry over to the next process).
- **Cost**: highest — a sequence of three Claude Code commands, each awaited and each with its own failure, on top of AD1.
- **Tests**: the fake must model `stop`, `--bg --resume` printing `backgrounded · <short>`, and a busy session refused.

### Combining them

AD1 and AD3 compose: AD1 for every attachable claim, AD3 later as an explicit command for a session that lacks aineo's flags (or, at a restart, for a fork whose token went stale — D116's case).

## Risks

- **AR1** — Screen text is tier 2 (the integrator's charter): `Session <short> has exited.`, the agent-view footer, the `warning: extra arguments ignored` line. A design that reads them pins each by a recorded fixture with its version.
- **AR2** — `←` on an empty prompt in an attached terminal turns it into agent view, which lists every session and whose `Ctrl+X` stops one (AM9). In AD1 that happens in Claude's window; aineo cannot tell from the process (it keeps running).
- **AR3** — An attach ends with 0 both when detached and when its session ends (AM10); AD1 must decide what the tab does then (AQ4) without a reliable code.
- **AR4** — Version floors: attach by name 2.1.290, `--resume` attaching 2.1.285, `--bg --resume` in place 2.1.257 (AF10). The health check does not check that the installed Claude Code has `claude attach` (T48's open thread).
- **AR5** — Shared input box (AM5): Send while another terminal has text in the session's input appends to it; the empty-prompt check reads the screen, which shows that text, so it refuses as for a draft.

## Questions for the user

1. **AQ1 — Which design?** (a) AD1, a claim of a background session attaches the tab's terminal **(recommended: it is what the user asked, reuses T48, and matches Claude Code's own `/resume` of a running background session, AF6)**; (b) AD2, an attach window beside the read-only claim; (c) AD3 alone; (d) AD1 now and AD3 as a later command.
2. **AQ2 — The tab's own Claude Code when a claim attaches.** (a) Stopped as `\S` stops it, and resumed when the claim is released; refused, with a message, while it is busy **(recommended)**; (b) stopped even when busy; (c) asked each time.
3. **AQ3 — When the attach happens.** (a) At once, on `:Aineo claim {id}` and when the tab follows a fork (D117) **(recommended)**; (b) only on the first Send while the claim holds; (c) only on `:Aineo claim {id}`, never for a fork.
4. **AQ4 — When the attached session ends** (stopped, or its process exited). (a) The tab resumes its own session and the claim ends **(recommended)**; (b) the tab resumes the claimed session as its own, as T141 does for a dead claim at a restart; (c) the window stays on Claude Code's last screen until the user acts.
5. **AQ5 — A claim of a session open in another interactive Claude Code** (no short id; `claude attach` cannot open it). (a) Stays read-only, as today **(recommended)**; (b) offer to take it over (AD3′) once that terminal has exited.
6. **AQ6 — `←` in an attached Claude's window** (agent view opens there, AR2). (a) Accept it as a limit in the help, as today for T48's attaches **(recommended)**; (b) read the screen and return the tab to its session when agent view shows (tier 2, AR1).

## Out of scope

- Building any of it: this note is the proposal T144 asked for; a packet follows the user's answers.
- Answering a permission prompt of a background session from aineo itself: permissions stay the user's (the integrator's charter); the user answers in Claude Code's own screen.
- `--fork-session` of a running background session (AF6): not measured, as it makes a second session.
