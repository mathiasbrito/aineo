**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Agreed and amended, 2026-10-07.** The user answered the converge round on 2026-10-07: P6, P7 and P8 are their recommended options, now D36, D37 and D38 in the v1 plan note (*Amendment — 2026-10-07*, below). Wave 8's T33 merged (PR #129), and every fact below was read again at `dev` `f98bd9d`. The orchestrator measured M1–M8 with the real Claude Code the same day, with the user's leave (`evidence/w9-real-claude-sessions.txt`); the behaviour below is shaped by them, and where that goes past the user's answers it is the orchestrator's assumption (A1–A4), to report to the user. Still before dispatch: the brief review, and wave 8's finish (the user's go: "when wave 8 finishes start right streight wave 9").

## Objective

The task, verbatim from the task list:

> | T35 | aineo learns of a session switch inside Claude Code (C3; D36, D37, D38): Claude Code is started with a `SessionStart` hook whose relay tells the editor the session's id and how it started; the claude home says which session Claude Code is on and calls back when it changes, and keeps that session for the working directory as the one resumed next | T19, wave 8's T33, M1–M8 | planned — wave 9 |

It rests on: D36 (how aineo learns of a switch), D37 (what counts as one) and D38 (which session resumes next), agreed 2026-10-07; C3 (the Claude session) and C5 (the MCP relay, the model for this relay); D23 (aineo's session id per working directory), whose last sentence D38 supersedes; D25 and T19 (the fallback when a resume finds no conversation); D11 (aineo answers no prompt and raises no permission); D26 and D29 (how the suite runs); wave 8's T33, whose `lua/aineo/claude/session_name.lua` keeps the session's name on the terminal from its title. The proposals P6, P7 and P8, with their alternatives.

### The behaviour (D36, D37, D38)

What Claude Code does was measured on 2026-10-07 with Claude Code 2.1.292 (`evidence/w9-real-claude-sessions.txt`, M1–M8). Where this section goes past the user's answers it says so: assumptions A1–A3 are the orchestrator's, reported to the user (`plan.md` › *Assumptions to report to the user*).

- **The hooks (D36; A1).** Every start of Claude Code that `start_session()` makes also passes `--settings` with an inline JSON object whose `hooks` key holds two entries, `SessionStart` and `SessionEnd`: each a `type: "command"` hook with no matcher, so that it runs for every source and every reason, a short `timeout` in seconds, and as its command the relay below. aineo adds no other settings key: no `disableAllHooks`, no `statusLine`, nothing a user's settings would lose. M2 measured that a `--settings` hook is added to the hooks already configured, not put in their place, so no plugin-directory fallback is built.
- **What Claude Code sends (M1).** `SessionStart`'s `source` is `startup`, `clear`, `resume`, `fork` (for `/branch`) or `compact`. Every switch — `/clear`, an in-session `/resume`, `/branch` — is `SessionEnd` with the old id (`reason` `clear`, or `resume` for both `/resume` and `/branch`), then `SessionStart` with the new id, about 0.1 s later. `/compact` sends `SessionStart` (`compact`) with the same id and no `SessionEnd`. Exit sends `SessionEnd` (`prompt_input_exit`). In every hook `CLAUDE_CODE_SESSION_ID` equals stdin's `session_id` (M3).
- **The relay (A3).** A Lua file in the claude home, run as aineo's MCP server is run — `<v:progpath> --headless --clean --cmd 'set noloadplugins' -l <relay> <editor address>` (`lua/aineo/mcp/init.lua` › `mcp_servers()` for the shape and the reason for `noloadplugins`) — that reads the hook's JSON from stdin and sends the editor **one RPC notification**, never a request, naming the event (`SessionStart` or `SessionEnd`), the `session_id`, and the `source` or `reason`, then exits. **It returns at once:** M8 measured that `/resume` waits for the `SessionStart` hook (a hook sleeping 2 s held the resumed screen 2.3 s), so the relay does nothing Claude Code waits on beyond writing the notification, and every bit of work happens in the editor, scheduled after it. The editor's address is written on its command line by aineo, not read from `$NVIM`, though M3 measured that the hook inherits `$NVIM` and `AINEO_CHILD`. A JSON it cannot read, or one without a string `session_id`, sends nothing. It never writes to stdout: Claude Code adds a SessionStart hook's stdout to Claude's context (D-docs).
- **The receiver (D37; A1).** The claude home exposes one function the relay's notification calls. It takes the event, the id and the source or reason, checks the id (below), and works from a scheduled callback, never inside the RPC handler:
  - a `SessionStart` whose id is the one the session follows does nothing more (`compact`, or the start's own `startup` or `resume`);
  - a `SessionStart` with another id is a switch: it makes that id the session's, keeps it for the session's working directory as `keep_session_id()` keeps a new one today (D38), and calls the `on_session_switched(id, source)` callback the composition root gives in `aineo.claude.Settings` (a new optional field beside `on_terminal_replaced`), telling it also the session left and, when a `SessionEnd` of it came first, why (A1). A `SessionStart` with a new id and no `SessionEnd` before it is still a switch;
  - a `SessionEnd` of the followed id marks that session ending and calls nothing back: a `SessionEnd` alone, as at exit, changes nothing shown, since the process's end is followed as today;
  - it does nothing once Neovim is quitting (`v:exiting`), nor for a session that is no longer the one running (a notification from an exited Claude Code's late hook).
- **Which session aineo says it is on (A2).** `aineo.claude` gains a way to ask for the id the session follows now (for T39 and the health check): from each start, the id aineo started Claude Code on (`--session-id` or `--resume`), without waiting for a hook to name it, since in a folder not yet trusted no hook runs at all (M7); then each switch's. Nil before any start.
- **The id's check (M4).** Claude Code's ids are lower-case version-4 UUIDs, which today's kept-id check (`SESSION_ID_PATTERN`) accepts. Keep the check as it is; a `session_id` it refuses is neither followed nor kept.
- **Where hooks do not run** — before the trust dialog is answered (M7: no hook, no MCP server, no title until then; what follows a "Yes" was not seen), under a managed `allowManagedHooksOnly`, under a managed `disableAllHooks` — aineo hears of no switch and behaves as D23 does today, on the session it started. The help says so, in the LIMITS subsection.
- **The MCP server is never asked (A4).** M5 measured one MCP server for Claude Code's whole life, whose `CLAUDE_CODE_SESSION_ID` goes stale after a switch. Nothing here reads a session id from it or its environment.
- **The fake `claude`** learns to run the `SessionStart` and `SessionEnd` hooks of the `--settings` it is given, with the JSON M1 recorded on their stdin, when a test tells it to: `SessionStart` at its start (`startup` for `--session-id`, `resume` for `--resume`); on keys standing for `/clear`, an in-session `/resume <id>` and `/branch`, `SessionEnd` of the old id then `SessionStart` of the new (`clear`, `resume`, `fork`); on a key standing for `/compact`, `SessionStart` (`compact`) alone; and `SessionEnd` (`prompt_input_exit`) as it exits. What it runs is recorded, as everything it does is.

### Facts, checked against `origin/dev` `f98bd9d` (wave 8 merged)

- `lua/aineo/claude/init.lua` (507 lines; it requires `aineo.claude.arguments`, `.readiness`, `.session_name`, `.session_ids` and `.stop`):
  - `aineo.claude.Settings`, lines 14–21: `cmd`, `cwd`, `mcp_servers`, `allowed_tools`, `instructions`, `on_terminal_replaced?`, `state_directory`;
  - `CHILD_ENVIRONMENT`, line 26 (`AINEO_CHILD = '1'`); the one `session`, line 32, `{ buffer, job, choice, ready, exit_code }`;
  - `validate_settings()`, lines 112–128;
  - `kept_or_new_session()`, lines 174–180; `session_arguments()`, lines 187–189 (`--resume <id>` or `--session-id <id>`);
  - `keep_session_id()`, lines 196–202, which warns and raises nothing;
  - `launch()`, lines 238–259: the command is `cmd`, then the session's words, then `arguments.claude_arguments(settings)`; since T33 it also keeps the session's name and folder on the terminal (`session_name.keep_name_and_folder()`, line 244) and forgets the name at exit (line 254); `env = CHILD_ENVIRONMENT`, line 251;
  - `start_in_place`, lines 357–370, keeps a new session's id (`if not choice.resumed`, lines 366–368);
  - `M.start_session()`, lines 423–429; `M.session_status()`, lines 441–452; T33's `M.session_statusline()`, lines 474–476, and `M.session_statusline_format()`, lines 484–486.
- `lua/aineo/claude/session_name.lua` (T33, 173 lines): the session's name follows Claude Code's terminal title through a dictionary watcher on `b:term_title` (`watch_title()`, lines 110–118; `keep_name()`, lines 91–100), kept as `b:aineo_session_name`, with `b:aineo_session_folder` (`M.keep_name_and_folder()`, lines 165–171). M6 measured that the title follows a switch, so this packet adds nothing to it.
- `lua/aineo/claude/session_ids.lua`: `SESSION_ID_PATTERN`, lines 13–14, requires `4` as the version digit and `[89ab]` as the variant, lower case; `is_session_id()`, lines 78–80; `M.kept_session_id()`, line 89; `M.keep_session_id()`, line 177, replacing the file through a temporary file and a rename.
- `lua/aineo/claude/arguments.lua` › `M.claude_arguments()`, lines 30–43: `--mcp-config <json>`, `--append-system-prompt <text>`, `--allowedTools` last, "where no word of aineo's own follows it". `--settings` must go before `--allowedTools`.
- `lua/aineo/mcp/init.lua` › `M.mcp_servers()`: the MCP relay's command, `editor_program` with `--headless --clean --cmd 'set noloadplugins' -l <relay>`, the editor's address in its environment. `lua/aineo/mcp/relay.lua` (21 lines) is the model of a relay script.
- `plugin/aineo.lua` › `started_claude_terminal()`, lines 211–234: it builds the settings with `vim.v.servername` and `vim.v.progpath` (line 218) — the two values the relay's command needs.
- `tests/helpers/fake_claude.lua`: modes at lines 95–112 (`MODES`); `AINEO_FAKE_CLAUDE_CONVERSATIONS` answers `--resume` and `--session-id` as Claude Code 2.1.283 did (lines 25–35). It parses its arguments itself; it knows nothing of `--settings` today.
- `git grep -n -- '--settings' origin/dev -- lua plugin tests` prints nothing: aineo passes no `--settings` today (B4).
- **B1** (`evidence/w9-probes.txt`): the relay's shape reached an idle editor 18–21 ms after its spawn, by `vim.rpcnotify()` over `sockconnect('pipe', <address>, { rpc = true })`, and ended in 19–22 ms; a terminal job's child and grandchild see `$NVIM`.
- **D-docs** (same file), quoted: SessionStart's sources `startup`, `resume` ("`--resume`, `--continue`, or `/resume`"), `clear`, `compact`, `fork`; every hook's input has `session_id`; "When you switch conversations with `/resume` inside a session, the switch waits for the hooks to finish"; hooks are held back until the workspace trust dialog is accepted; `--settings` is "an inline JSON string", above user, project and local settings.
- **M1–M8** (`evidence/w9-real-claude-sessions.txt`, the orchestrator's, 2026-10-07, Claude Code 2.1.292), as the behaviour above cites them: the sources and the `SessionEnd`–`SessionStart` pair of every switch (M1); a `--settings` hook added to the hooks already configured (M2, measured against the project's hooks; a hook in the user's own `settings.json` was not measured apart); `CLAUDE_CODE_SESSION_ID` equal to stdin's `session_id`, `$NVIM` and `AINEO_CHILD` inherited (M3); lower-case version-4 ids (M4); one MCP server whose session id goes stale (M5); the title following the session (M6); nothing running before trust (M7); `/resume` waiting for the hook (M8).
- [[Learnings/An RPC request to a Neovim at a hit-enter prompt waits until it is answered]]: why the relay notifies.

**Not measured:** what Claude Code does once a folder's trust dialog is answered "Yes" (M7 left it unanswered); a hook in the user's own `settings.json` beside aineo's (M2 used the project's). Never run the real `claude` yourself.

### Baseline

At `f98bd9d`, Neovim 0.12.5: 1929 cases in 60 groups, `Fails (0)` — T33's last whole-suite run, on code identical to `f98bd9d`'s (`plan.md` › *Baseline*). Since the first brief (`9b8707f`: `tests/test_claude.lua` 74), T33 brought `tests/test_claude.lua` to 114 cases (T33's session note) and added `tests/test_entry_claude_name.lua` and `tests/test_layout_claude_name.lua`; `tests/test_claude_resume.lua` (49), `tests/test_entry_claude_resume.lua` (11) and `tests/test_mcp_relay.lua` (30) are files wave 8 did not change. The dispatch message pastes the counts on the `dev` you start from.

Read first: the v1 plan note's C3, C5, D11, D23, D25, T19, and D36–D38; [[Planning/aineo — worktrees and session switches]] › P6–P8 and its outcome; `plan.md` › *Measured with the real Claude Code* and *Assumptions to report to the user* (A1–A4); `evidence/w9-real-claude-sessions.txt`; `Sessions/2026-10-07 — T33 Claude window name.md`; `knowledge-vault/Projects/aineo.md`; `Sessions/2026-09-27 — T19 Claude resume.md`; [[Learnings/Claude Code's interactive CLI in a Neovim terminal]]; `plan.md` and `evidence/w9-probes.txt` in this folder (B1, B4, D-docs).

## Boundary

- **Branch:** `feature/t35-session-switch` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t35_session_switch` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/claude/`: `init.lua`, `arguments.lua`, `session_ids.lua` (M4 leaves its check as it is), and one new file for the relay; not `session_name.lua`, which is T33's and needs nothing (M6);
  - `plugin/aineo.lua`: `started_claude_terminal()` alone — handing the claude home what the relay's command needs. **Not** what a switch does to the panes, which is T39's, and not the autostart;
  - `tests/helpers/fake_claude.lua` (running the `--settings` hooks), and `tests/helpers/claude_session.lua` where the suites need a way to make the fake switch — both shared helpers: run every test file that requires either;
  - `tests/test_claude.lua`, `tests/test_claude_resume.lua`, and a new `tests/test_claude_switch.lua`;
  - `doc/aineo.txt`, inside the two fences below;
  - your session note.
- **You must not touch:** every other file under `lua/`, `plugin/`, `scripts/` and `tests/` — `lua/aineo/mcp/` included (its relay is a model, not a home to share), `tests/test_doc.lua` (run it, do not edit it); T36's files (`lua/aineo/report/`, `lua/aineo/draft/`, `tests/test_report*.lua`, `tests/test_draft*.lua`) and T37's (`lua/aineo/changes/`, `tests/test_changes*.lua`); the plan notes, the project note and the task list — the wave holds its marks: write a `## Task lines` section in your session note, one paragraph for T35 in the closed rows' style; and `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - Yours: *aineo-claude-session*, from `Claude's session ~` to `same session.` (lines 271–325 at `f98bd9d`). Since T33 it holds the status line's paragraph, from `*b:aineo_session_name* *b:aineo_session_folder*` to `See |aineo-limits| for what can replace it.`, which is T33's and stays as it is. Its last paragraph, `aineo resumes the session it started, not one you switch to inside Claude` … `same session.` (lines 322–325), says the opposite of D38 and is rewritten. And a new LIMITS subsection, inserted after the paragraph of `Stopping Claude Code on quit ~` that ends `aineo cannot detect this.` (line 952) and before `The 80-column start ~` (line 954): where hooks do not run — before the trust dialog is answered, under managed hook policies — and what was not seen (a folder's first "Yes").
  - T36 owns *aineo-report*'s last paragraph (`Reports are kept per working directory, under` … `the working directory of its own moment.`) and *aineo-draft*'s body (`What you write in Input is kept as a draft, one per working directory,` … `you type there.`), which begins four lines after your fence ends: leave the empty line, `Input's draft ~` and its tag between them as they are. T37 owns *aineo-changes*'s first paragraph and one LIMITS item (`- A restart of Claude Code in another working directory keeps the first` … `repository and its base.`).
  - Before you push, merge your copy with each of their branches that exists (`git merge-tree --write-tree <your head> origin/feature/t36-report-sessions`, and the same for `origin/feature/t37-changes-sessions`), run `make test_file FILE=tests/test_doc.lua` on each merged tree, and report both results.
- **Session note:** `knowledge-vault/Sessions/<date> — T35 Session switch.md`, `<date>` as the dispatch message gives it, with a `## Task lines` section.
- **Scratch prefix:** `t35-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5, the newest release, only; never the real `claude`. While you work, the test files you touch and those of the baseline table; the whole suite once before each push; mutants on the files that exercise their code. Stop what you start, by pid.
- **Modularity:** `aineo.claude` keeps requiring `aineo.config` and `aineo.mcp` alone (`.claude/skills/modularity/SKILL.md`, the direction table). The relay reaches the editor through RPC, never through a `require` of another home.

## The tests

Each behaviour gets one test, seen failing first:
- `start_session()` passes `--settings` with a `SessionStart` and a `SessionEnd` command hook, before `--allowedTools`, on a new session and on a resumed one; nothing else in the JSON;
- the relay, given a hook's JSON on stdin and an editor's address, notifies that editor of the event, the id and the source or reason, and writes nothing on stdout; given JSON it cannot read, it notifies nothing and exits;
- the relay notifies, never requests, and returns at once: an editor held at a hit-enter prompt does not hold the relay past its bound;
- the session followed is the started id from the start, with no hook run at all (A2);
- a `SessionStart` with the followed id calls nothing back; one with a new id calls `on_session_switched` once, naming the session left, and keeps the id for the directory, so the next start resumes it;
- a `SessionEnd` alone calls nothing back (A1);
- an id that fails the check is neither followed nor kept;
- nothing is called back while Neovim quits, nor for a Claude Code that has exited;
- through the fake: `/clear`, an in-session `/resume` and `/branch` each reach the callback with `clear`, `resume` and `fork`; `/compact` reaches nothing;
- the help's new paragraph and LIMITS subsection, through `tests/test_doc.lua`'s pins.

The verification runs the plan's eight mutants for T35 (`plan.md` › *Verification mutants*). Name in your report the test that kills each.

## What was decided already

- The user's request, 2026-10-06 (`plan.md` › *Ask*), and the user's answers to P6–P8, D36–D38, which the amendment gives.
- The orchestrator's assumptions A1–A4 from the measurements, to be reported to the user; build them as written.
- D11: aineo answers no prompt and raises no permission. The hook adds no `permissions` key.

## Budget

Large for its risk, medium in code: a settings argument, a relay of about the MCP relay's size, a receiver, a fake that runs two hooks, about twelve cases and a help paragraph. If it grows past that, stop at a green, reviewed, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t35-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran and the whole suite's counts.

## Amendment — 2026-10-07: the user's answers, the measurements, and the facts at `f98bd9d`

**The user's answers.** The orchestrator put P1–P11 to the user as a table, each with its options and its recommendation, and M, R and S for the wave. The user answered, verbatim: "p10 must be one per session, why, because it is used to catalog changes and notes that goes to the prompt with \s, other than that all your recommendations are fine, so when wave 8 finishes start right streight wave 9." So P6, P7 and P8 are (a), now D36, D37 and D38 in the v1 plan note; M is (a). The brief's body, written with those options, stands; its "awaits the converge round" markers are gone.

**The measurements** (`evidence/w9-real-claude-sessions.txt`, the orchestrator's, 2026-10-07). They defeat no row, and reshape this brief, in the body above:
- M1: a switch is `SessionEnd` of the old id, then `SessionStart` of the new, about 0.1 s apart; `fork` is `/branch`'s source; `/compact` is `SessionStart` alone with the same id. So the fake runs both hooks in that order, and the tests cover `/branch` and `/compact`.
- M2: `--settings` adds to the hooks already configured. The plugin-directory fallback is dropped from this packet.
- M3: the hook sees `CLAUDE_CODE_SESSION_ID` equal to its stdin's `session_id`, and inherits `$NVIM` and `AINEO_CHILD`. The relay still takes the address from its command line.
- M4: lower-case version-4 UUIDs. The id check stays; "a widened id check" is gone from the budget.
- M5: the MCP server is never asked for a session (A4).
- M6: the title follows the session; T33's status line needs nothing.
- M7: nothing runs before trust, so the followed session is the started id from the start (A2).
- M8: `/resume` waits for the hook, so the relay returns at once (A3).

**The orchestrator's assumptions, to report to the user** (`plan.md` › *Assumptions to report to the user*): A1, `SessionEnd` relayed beside `SessionStart`, the switch still decided at `SessionStart`; A2, the started id followed until a hook names another; A3, a hook that only notifies and exits; A4, no session id read from the MCP server. Build them as the body says.

**Facts that moved since `9b8707f`** (the body gives them at `f98bd9d`): in `lua/aineo/claude/init.lua`, every line number moved by one to nine lines with T33's `session_name` require and its status-line functions (`Settings` 13–20 → 14–21, `launch()` 236–255 → 238–259, `start_in_place` 353–366 → 357–370, `M.start_session()` 414–420 → 423–429, `M.session_status()` 432–444 → 441–452); `lua/aineo/claude/session_name.lua` is new; `session_ids.lua`, `arguments.lua`, `lua/aineo/mcp/`, `plugin/aineo.lua` › `started_claude_terminal()` (211–234, `vim.v.progpath` at 218) and `tests/helpers/fake_claude.lua` (`MODES` 95–112) did not move. T33 did not change `started_claude_terminal()`; it changed `arrangement()`. The help's fence now holds T33's status-line paragraph, quoted in *Boundary*. The baseline is 1929 cases at `f98bd9d`.

**Mutants:** the plan's T35 list gains 7 (a `SessionEnd` taken as the switch) and 8 (the followed session left unset until a hook names it).
