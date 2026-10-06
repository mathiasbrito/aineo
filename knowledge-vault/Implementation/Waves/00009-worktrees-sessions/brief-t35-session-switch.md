**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Awaits the converge round.** This brief is written with the recommended options of [[Planning/aineo — worktrees and session switches]] › P6 (a), P7 (a) and P8 (a), and before M1–M4, M7 and M8 were measured. It is not dispatched until the user has answered the round, the agreed rows are in the v1 plan note as D36–D38, and the orchestrator has measured M1–M4, M7 and M8 with the user's leave. An answer that differs, and each measurement's result, come as a dated amendment below, reviewed before dispatch. It is also not dispatched before wave 8's T33 has merged (stage 1, after wave 8).

## Objective

The task, verbatim from the task list:

> | T35 | aineo learns of a session switch inside Claude Code (C3; the D rows of [[Planning/aineo — worktrees and session switches]] › P6–P8, once agreed): Claude Code is started with a `SessionStart` hook whose relay tells the editor the session's id and how it started; the claude home says which session Claude Code is on and calls back when it changes, and keeps that session for the working directory as the one resumed next — the behaviour awaits the converge round | T19, wave 8's T33, the round, M1–M4, M7, M8 | planned — wave 9 |

It rests on: C3 (the Claude session) and C5 (the MCP relay, the model for this relay); D23 (aineo's session id per working directory), whose last sentence D38 supersedes once agreed; D25 and T19 (the fallback when a resume finds no conversation); D11 (aineo answers no prompt and raises no permission); D26 and D29 (how the suite runs). The proposals P6, P7 and P8, with their alternatives.

### The behaviour, under the recommended options (awaits the converge round)

- **The hook.** Every start of Claude Code that `start_session()` makes also passes `--settings` with an inline JSON object holding one `hooks.SessionStart` entry: a `type: "command"` hook with no matcher, so that it runs for every source, a short `timeout` (seconds; derive it from M8 and B1, and say how), and as its command the relay below. aineo adds no other settings key: no `disableAllHooks`, no `statusLine`, nothing a user's settings would lose.
- **The relay.** A Lua file in the claude home, run as aineo's MCP server is run — `<v:progpath> --headless --clean --cmd 'set noloadplugins' -l <relay> <editor address>` (`lua/aineo/mcp/init.lua` › `mcp_servers()` for the shape and the reason for `noloadplugins`) — that reads the hook's JSON from stdin and sends the editor **one RPC notification**, never a request, naming the session's `session_id` and its `source`, then exits. The editor's address is written on its command line by aineo, not read from `$NVIM` (B1 measured `$NVIM` in a terminal job's grandchild, but a hook runs "in its own session without a controlling terminal", D-docs, and M3 measures its environment). A JSON it cannot read, or one without a string `session_id`, sends nothing. It never writes to stdout: Claude Code adds a SessionStart hook's stdout to Claude's context (D-docs).
- **The receiver.** The claude home exposes one function the relay's notification calls. It takes the id and the source, checks the id (below), and:
  - when the id is the one the session follows, does nothing more (a `compact`, or the start's own `startup`/`resume`);
  - otherwise makes it the session's id, keeps it for the session's working directory as `keep_session_id()` keeps a new one today (P8 (a)), and calls the `on_session_switched(id, source)` callback the composition root gives in `aineo.claude.Settings` (a new optional field beside `on_terminal_replaced`).
  - It does nothing once Neovim is quitting (`v:exiting`), nor for a session that is no longer the one running (a notification from an exited Claude Code's late hook).
- **Which session aineo says it is on.** `aineo.claude` gains a way to ask for the id the session follows now (for T39 and the health check), nil before any start.
- **The id's check.** Today's kept-id check accepts only the lower-case version-4 form aineo makes. Claude Code's own ids must pass the check that guards `--resume`, or a switched-to id would be refused at the next start; M4 measures their form. A check that widens must still refuse anything that is not a UUID, since the id becomes an argument to `--resume`.
- **Where hooks do not run** — before the trust dialog is answered (M7), under a managed `allowManagedHooksOnly`, under a managed `disableAllHooks` — aineo hears of no switch and behaves as D23 does today. The help says so.
- **The fake `claude`** learns to run the `SessionStart` hooks of the `--settings` it is given, the JSON the documentation gives on its stdin, when a test tells it to: at its start (`startup` for `--session-id`, `resume` for `--resume`), and on keys standing for `/clear` and an in-session `/resume <id>` — a new id, or the given one. What it runs is recorded, as everything it does is.

### Facts, checked against `origin/dev` `9b8707f` (re-checked after T33 merges)

Line numbers were read at `9b8707f`; wave 8's T33 changes `lua/aineo/claude/` and `plugin/aineo.lua`, so the amendment before dispatch gives them again.

- `lua/aineo/claude/init.lua`:
  - `aineo.claude.Settings`, lines 13–20: `cmd`, `cwd`, `mcp_servers`, `allowed_tools`, `instructions`, `on_terminal_replaced?`, `state_directory`;
  - `validate_settings()`, lines 111–127;
  - `kept_or_new_session()`, lines 173–179; `session_arguments()`, lines 186–188 (`--resume <id>` or `--session-id <id>`);
  - `keep_session_id()`, lines 195–201, which warns and raises nothing;
  - `launch()`, lines 236–255: the command is `cmd`, then the session's words, then `arguments.claude_arguments(settings)`; `env = CHILD_ENVIRONMENT` (`AINEO_CHILD = '1'`, line 25);
  - `start_in_place`, lines 353–366, keeps a new session's id (`if not choice.resumed`);
  - `M.start_session()`, lines 414–420; `M.session_status()`, lines 432–444.
- `lua/aineo/claude/session_ids.lua`: `SESSION_ID_PATTERN`, lines 13–14, requires `4` as the version digit and `[89ab]` as the variant, lower case; `is_session_id()`, lines 78–80; `M.kept_session_id()`, line 89; `M.keep_session_id()`, line 177, replacing the file through a temporary file and a rename.
- `lua/aineo/claude/arguments.lua` › `M.claude_arguments()`, lines 30–43: `--mcp-config <json>`, `--append-system-prompt <text>`, `--allowedTools` last, "where no word of aineo's own follows it". `--settings` must go before `--allowedTools`.
- `lua/aineo/mcp/init.lua` › `M.mcp_servers()`: the MCP relay's command, `editor_program` with `--headless --clean --cmd 'set noloadplugins' -l <relay>`, the editor's address in its environment. `lua/aineo/mcp/relay.lua` (21 lines) is the model of a relay script.
- `plugin/aineo.lua` › `started_claude_terminal()`, lines 211–234: it builds the settings with `vim.v.servername` and `vim.v.progpath` (line 218) — the two values the relay's command needs.
- `tests/helpers/fake_claude.lua`: modes at lines 95–112 (`MODES`); `AINEO_FAKE_CLAUDE_CONVERSATIONS` answers `--resume` and `--session-id` as Claude Code 2.1.283 did (lines 25–35). It parses its arguments itself; it knows nothing of `--settings` today.
- `git grep -n -- '--settings' origin/dev -- lua plugin tests` prints nothing: aineo passes no `--settings` today (B4).
- **B1** (`evidence/w9-probes.txt`): the relay's shape reached an idle editor 18–21 ms after its spawn, by `vim.rpcnotify()` over `sockconnect('pipe', <address>, { rpc = true })`, and ended in 19–22 ms; a terminal job's child and grandchild see `$NVIM`.
- **D-docs** (same file), quoted: SessionStart's sources `startup`, `resume` ("`--resume`, `--continue`, or `/resume`"), `clear`, `compact`, `fork`; every hook's input has `session_id`; "When you switch conversations with `/resume` inside a session, the switch waits for the hooks to finish"; hooks are held back until the workspace trust dialog is accepted; `--settings` is "an inline JSON string", above user, project and local settings; whether its `hooks` key adds to the user's hooks or replaces them is M2.
- [[Learnings/An RPC request to a Neovim at a hit-enter prompt waits until it is answered]]: why the relay notifies.

**Not measured** (the orchestrator's, before dispatch, M1–M4, M7, M8; never run the real `claude` yourself): that the hook runs with this input on each source; that `--settings` keeps the user's own hooks; the hook's environment; the form of Claude Code's ids; the hook before trust; how long `/resume` waits.

### Baseline

On `9b8707f`, Neovim 0.12.5: 1807 cases, `Fails (0)` (`Implementation/Waves/00008-small-fixes/evidence/baseline-9b8707f.txt`). Among them: `tests/test_claude.lua` 74, `tests/test_claude_resume.lua` 49, `tests/test_entry_claude_resume.lua` 11, `tests/test_mcp_relay.lua` 30, `tests/test_doc.lua` 44. Wave 8's T33 changes `tests/test_claude.lua`; the dispatch message pastes the counts on the `dev` you start from.

Read first: the v1 plan note's C3, C5, D11, D23, D25, T19, and the D rows the round adds (D36–D38); [[Planning/aineo — worktrees and session switches]] › P6–P8 and *Measurements before dispatch*; `knowledge-vault/Projects/aineo.md`; `Sessions/2026-09-27 — T19 Claude resume.md`; [[Learnings/Claude Code's interactive CLI in a Neovim terminal]]; `plan.md` and `evidence/w9-probes.txt` in this folder (B1, B4, D-docs).

## Boundary

- **Branch:** `feature/t35-session-switch` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t35_session_switch` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/claude/`: `init.lua`, `arguments.lua`, `session_ids.lua`, and one new file for the relay;
  - `plugin/aineo.lua`: `started_claude_terminal()` alone — handing the claude home what the relay's command needs. **Not** what a switch does to the panes, which is T39's, and not the autostart;
  - `tests/helpers/fake_claude.lua` (running a `--settings` hook), and `tests/helpers/claude_session.lua` where the suites need a way to make the fake switch — both shared helpers: run every test file that requires either;
  - `tests/test_claude.lua`, `tests/test_claude_resume.lua`, and a new `tests/test_claude_switch.lua`;
  - `doc/aineo.txt`, inside the two fences below;
  - your session note.
- **You must not touch:** every other file under `lua/`, `plugin/`, `scripts/` and `tests/` — `lua/aineo/mcp/` included (its relay is a model, not a home to share), `tests/test_doc.lua` (run it, do not edit it); T36's files (`lua/aineo/report/`, `lua/aineo/draft/`, `tests/test_report*.lua`, `tests/test_draft.lua`) and T37's (`lua/aineo/changes/`, `tests/test_changes*.lua`); the plan notes, the project note and the task list — the wave holds its marks: write a `## Task lines` section in your session note, one paragraph for T35 in the closed rows' style; and `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - Yours: *aineo-claude-session*, from `Claude's session ~` to `same session.` (as T33 leaves it — the amendment quotes it); its paragraph `aineo resumes the session it started, not one you switch to inside Claude` … `same session.` says the opposite of D38 and is rewritten. And a new LIMITS subsection, inserted after the paragraph of `Stopping Claude Code on quit ~` that ends `aineo cannot detect this.` and before `The 80-column start ~`: where hooks do not run, and what M1–M8 left unmeasured.
  - T36 owns *aineo-report*'s last paragraph (`Reports are kept per working directory, under` … `the working directory of its own moment.`); T37 owns *aineo-changes*'s first paragraph and one LIMITS item (`- A restart of Claude Code in another working directory keeps the first` … `repository and its base.`).
  - Before you push, merge your copy with each of their branches that exists (`git merge-tree --write-tree <your head> origin/feature/t36-report-sessions`, and the same for `origin/feature/t37-changes-sessions`), run `make test_file FILE=tests/test_doc.lua` on each merged tree, and report both results.
- **Session note:** `knowledge-vault/Sessions/<date> — T35 Session switch.md`, `<date>` as the dispatch message gives it, with a `## Task lines` section.
- **Scratch prefix:** `t35-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5, the newest release, only; never the real `claude`. While you work, the test files you touch and those of the baseline table; the whole suite once before each push; mutants on the files that exercise their code. Stop what you start, by pid.
- **Modularity:** `aineo.claude` keeps requiring `aineo.config` and `aineo.mcp` alone (`.claude/skills/modularity/SKILL.md`, the direction table). The relay reaches the editor through RPC, never through a `require` of another home.

## The tests

Each behaviour gets one test, seen failing first:
- `start_session()` passes `--settings` with one `SessionStart` command hook, before `--allowedTools`, on a new session and on a resumed one; nothing else in the JSON;
- the relay, given a SessionStart JSON on stdin and an editor's address, notifies that editor of the id and the source and writes nothing on stdout; given JSON it cannot read, it notifies nothing and exits;
- the relay notifies, never requests: an editor held at a hit-enter prompt does not hold the relay past its bound;
- a `SessionStart` with the followed id calls nothing back; one with a new id calls `on_session_switched(id, source)` once and keeps the id for the directory, so the next start resumes it;
- an id that fails the check is neither followed nor kept;
- nothing is called back while Neovim quits, nor for a Claude Code that has exited;
- through the fake: `/clear` and an in-session `/resume` each reach the callback with `clear` and `resume`;
- the help's new paragraph and LIMITS subsection, through `tests/test_doc.lua`'s pins.

The verification runs the plan's six mutants for T35 (`plan.md` › *Verification mutants*). Name in your report the test that kills each.

## What was decided already

- The user's request, 2026-10-06 (`plan.md` › *Ask*), and the user's answers to P6–P8, which the amendment gives.
- D11: aineo answers no prompt and raises no permission. The hook adds no `permissions` key.

## Budget

Large for its risk, medium in code: a settings argument, a relay of about the MCP relay's size, a receiver, a widened id check, a fake that runs a hook, about ten cases and a help paragraph. If it grows past that, stop at a green, reviewed, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t35-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran and the whole suite's counts.
