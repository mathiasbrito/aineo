**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`, since you are dispatched as the integrator and bound by both.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T19 | Claude resumes aineo's own last session in the working directory (D23): each session aineo starts gets an id of its own, kept per working directory, and the next start there resumes it | T14, Q8 | active |

It rests on **D23** (read it whole, with the user's words), **C3** (the Claude session), **Q8**, measured on 2026-09-26 (`knowledge-vault/Implementation/Waves/00006-fixes/evidence/claude-resume-q8.txt`), and D10.

### The behaviours — SR1 to SR4 tested, each test seen red first; SR5 is an invariant

- **SR1 — a new session gets an id of its own.** When aineo starts Claude Code in a working directory for which it keeps no session, it starts it with `--session-id <id>`, `<id>` a new random version-4 UUID, and keeps that id for that directory. The directory is the one Claude Code starts in (`settings.cwd`). The id is kept under the editor's state directory, in `aineo/`, one per directory, named by the directory's SHA-256 as the Reports and the draft are (`lua/aineo/report/records.lua:24–35`, `lua/aineo/draft/init.lua:83`).
- **SR2 — the next start there resumes it.** When aineo starts Claude Code in a directory whose session it keeps — a new Neovim there, or `\o` after Claude Code has exited — it starts it with `--resume <kept id>`, and the kept id stays. `--mcp-config`, `--append-system-prompt` and `--allowedTools` are given as today, and `--allowedTools` stays last (`lua/aineo/claude/arguments.lua`, its docstring says why).
- **SR3 — a kept session Claude Code no longer has.** Q8 measured, on 2.1.283:
  - `--resume` of an id Claude Code does not have prints `No conversation found with session ID: <id>` and exits 1, about 2 s after it starts, before any screen of its own;
  - a session in which nothing was typed leaves no conversation, so SR1's id is such an id when the user never typed.

  Then aineo starts a new session in its place, by SR1: a new id, kept in place of the old one, its terminal taking the failed one's place in every window that showed it, as `start_session()` does today (`replace_terminal()`). It does so once per start. **Any other exit shows as today** — its exit on screen, `\o` restarts it — and the kept id stays.
  - How aineo tells this exit from another is yours under `tdd` and the integrator's *Three tiers of surface*: the message's text and the exit's timing are tier 2, observable and undocumented, measured on 2.1.283. Pin what you rely on with the fake, naming the version. Say in your note what you chose and what it gets wrong: a failure that looks like this one, and this one when it looks like another.
- **SR4 — per directory.** Two directories keep two sessions. A directory's kept session is never resumed in another: `:cd` elsewhere, then `\o` after an exit, resumes that directory's session or starts one of its own.
- **SR5 — nothing else changes (an invariant).** Readiness, Send, the stop on quit, the MCP server and its tool, the report instructions, `:checkhealth aineo` (which runs `claude --version` and starts no session), and every existing case of the suite: green, with the argument pins updated only by the two new words.

### The orchestrator's readings, for your note's *Readings for the MVP review*

- SR3's new session in place of one Claude Code no longer has — D23 says only that a directory with none gets a new one;
- the id is kept from the moment the session starts, whether or not anything is typed;
- a directory's kept id is never removed, as the drafts are not (MR125);
- two editors in one directory resume the same session: Q8 measured two Claude Codes resuming one id at once, neither refused (a limit);
- D23's own: a session switched inside Claude (`/clear`, `/resume`) is not followed.

### Facts, checked against `origin/dev` (the code `origin/dev` holds once PR #58 (T20) merges: the tree `525b22b`)

- **The Claude home, `lua/aineo/claude/init.lua`:** `aineo.claude.Settings` (lines 12–17); `launch()` (line 154) builds the command from `settings.cmd` and `arguments.claude_arguments(settings)` (line 157); `start_session()` (line 200) starts one Claude Code at a time and, once the last has exited, a new one whose terminal replaces the old (`replace_terminal()`, lines 71–81); `session_status()` (line 224) reads `'exited'` with the exit code.
- **The composition root, `plugin/aineo.lua`:** `started_claude_terminal()` (line 116) passes `start_session()` its settings (lines 119–125), `cwd = vim.fn.getcwd()`; `kept_places()` (line 63) holds the state directory the Reports and the draft use, `vim.fn.stdpath('state')`. A home is given its state directory by the composition root, not reaching for it (`modularity`; the draft home's `set_draft_environment()` is the pattern).
- **The flags pin:** `tests/test_claude.lua:174–184`, "passes no flag beyond the servers, the instructions and the tools", pins the flag set and `#arguments == 7`.
- **The fake `claude`, `tests/helpers/fake_claude.lua`:** records its arguments, working directory and chosen variables as the first line of its record; its screens and key answers follow `AINEO_FAKE_CLAUDE_MODE`; the modes that exit by themselves exit with `AINEO_FAKE_CLAUDE_EXIT_CODE`. It knows nothing of session ids today. Teach it the measured behaviour you rely on (SR3), with the version, as its other behaviours are documented.
- **The suites' state:** every child of `make test` shares `.tests/state` (`Makefile:38`), and every child runs in the checkout's directory. `make test` and `make test_file` empty the drafts there at the start of each run (`Makefile:72–79`), because a draft one case left came back in another (T14). A kept session id is the same trap: one case's id would be resumed by the next case that starts Claude Code through `plugin/aineo.lua`. Give every case that starts a session a state directory of its own (`vim.env.XDG_STATE_HOME` set to a `fixture.directory(…)` before the first start, as `tests/test_entry_report.lua` does), or extend the `Makefile`'s clean-up line to the kept ids; say which you chose.
- **Q8's other facts:** `--session-id` of an id already used prints `Error: Session ID <id> is already in use.` and exits 1 at once; `--resume` of an id Claude Code has continues that id, a new exchange appended to the same conversation. `--resume` with `--mcp-config`, `--append-system-prompt` and `--allowedTools` together was not measured; each is documented, and the three took effect interactively in wave 2. Never run the real `claude`: the attack review is told the combination is unmeasured.

### Baseline

- `dev` once PR #58 (T20) merges: its code is the tree `525b22b`, which the orchestrator's verification of PR #58 measured: 985 cases, `Fails (0)`, on 0.12.5 and 0.11.6, and lint clean (`evidence/baseline-525b22b.txt`). The other packet of this plan may merge before you start or while you work: if it merges before you start, re-measure the baseline on your base.

- **Run the whole suite on both versions, one at a time.** Under load, `test_send.lua`, the `session_status()` cases of `test_claude.lua`, `tests/test_health.lua:336`, `test_entry*.lua` and `tests/test_mcp_blocked_editor.lua` fail spuriously; re-run a surprising failure alone before you believe it. A whole 0.12.5 run that stops at the 960 s limit is not a result: re-run it, and run the stalled file alone. Check `uptime` before a whole run, and head each log with `nvim --version | head -1`.
  - On the host's 0.12.5: `make test`.
  - On 0.11.6, in this literal form (the worktree guard refuses `PATH=…:$PATH make`):

    ```
    env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test
    ```

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D23, C3, Q8;
- `knowledge-vault/Implementation/Waves/00006-fixes/evidence/claude-resume-q8.txt`;
- `doc/aineo.txt` › `*aineo-layout*` and `*aineo-autostart*`;
- `knowledge-vault/Sessions/2026-09-26 — T14 Input draft.md` › its state-directory lessons;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t19-claude-resume` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t19_claude_resume`.
- **You may touch:**
  - `lua/aineo/claude/`, a module of its own inside the home for the kept ids if your seam wants one;
  - `plugin/aineo.lua`, **only `started_claude_terminal()`**, the settings it passes;
  - `tests/test_claude*.lua`, new cases and the flags pin; a new `tests/test_claude_resume.lua`;
  - `tests/helpers/fake_claude.lua` and `tests/helpers/claude_session.lua`, for the session ids;
  - the `Makefile`, only the clean-up at the start of a run, if you choose it;
  - `doc/aineo.txt`, **only** a new subsection `Claude's session ~` in `*aineo-layout*`, placed directly above `Input's draft ~`;
  - your session note.
  - The documentation this change invalidates: the Claude home's docstrings (`start_session()`, `aineo.claude.Settings`) and the help. Correct them in the same change and say so in your report. Every list a new module changes — the lint's module patterns, any test that enumerates the source tree or the modules loaded at startup (`tests/test_plugin.lua:8`) — is yours to check.
- **You must not touch:**
  - `plugin/aineo.lua` outside `started_claude_terminal()` (T12 follows you there);
  - `lua/aineo/layout/` (T21 runs beside you there), `lua/aineo/report/` (T17), `lua/aineo/draft/`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/health.lua`;
  - `tests/test_plugin.lua`'s frozen pins, `scripts/`;
  - `doc/aineo.txt` outside your subsection;
  - the task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note;
  - the project note, the MVP readings review;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Never run the real `claude`,** and never read or write `~/.claude/`: the suites point `CLAUDE_CONFIG_DIR` into the checkout.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your section** is the new subsection: from `Claude's session ~` to its last line, directly above `Input's draft ~`, with at least one unchanged line between your hunk and `were opened until \`\o\` restores the layout.`.
  - **The other packets:** T21 edits `*aineo-commands*`, from `*:Aineo-claude*` to `an exited Claude Code.`; T17 edits `*aineo-report*`.
  - **Before you push**, for each of `origin/bugfix/t21-claude-exit` and `origin/bugfix/t17-report-paths` that exists and is unmerged:
    1. `git fetch origin && git merge-tree --write-tree <your head> <branch>`; report any conflict it prints, in any file;
    2. `git show <tree id>:doc/aineo.txt > doc/aineo.txt` and `git show <tree id>:tests/test_doc.lua > tests/test_doc.lua`;
    3. `make test_file FILE=tests/test_doc.lua`, on both versions;
    4. `git checkout HEAD -- doc/aineo.txt tests/test_doc.lua`.

    Report the results.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T19 Claude resume.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored); if the harness refuses to create it, use your worktree's `.tests/` and say so. Prefix every file with `t19-`. Keep all scratch inside your worktree, never in `/tmp`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **The user's request, 2026-09-26:** "also I want the plugin to remmeber the last session that was opened, and when reopening to load the session.", then "the claude session...".
- **Asked which conversation to pick up**, the user chose "aineo's own last one", over "The most recent one (Recommended)" (`--continue`) and over asking each time, accepting that after a `/clear` or `/resume` inside Claude aineo reopens the older one. Then: "the last one, but it must be per project, someone working in a different folder/project, will have the last session executed on that folder." Asked which session aineo resumes in a folder, the user chose "aineo's own last one there (Recommended)": "The last session aineo itself started in that folder. A plain-terminal conversation in the same folder is ignored; a folder where aineo never started one gets a new session." That is D23.
- **Q8 was measured by the orchestrator** with the user's leave, on the user's login, in a scratch folder: `evidence/claude-resume-q8.txt`.

## Budget

Medium to large: a kept id per directory, two flags, one fallback, the fake taught the measured behaviour, and the help. If it grows past that, stop at a green, pushed state and report a true partial.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t19-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
