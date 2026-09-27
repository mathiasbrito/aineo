**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`, since you are dispatched as the integrator and bound by both.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T19 | Claude resumes aineo's own last session in the working directory (D23): each session aineo starts gets an id of its own, kept per working directory, and the next start there resumes it | T14, Q8 | active |

It rests on **D23** (read it whole, with the user's words), **C3** (the Claude session), **Q8**, measured on 2026-09-26 (`knowledge-vault/Implementation/Waves/00006-fixes/evidence/claude-resume-q8.txt`), and D10.

### The behaviours — SR1 to SR4 tested, each test seen red first; SR5 is an invariant

- **SR1 — a new session gets an id of its own.** When aineo starts Claude Code in a working directory for which it keeps no session, it starts it with `--session-id <id>`, `<id>` a new random version-4 UUID, and keeps that id for that directory. The directory is the one Claude Code starts in (`settings.cwd`). The id is kept under the editor's state directory, in `aineo/`, one per directory, named by the directory's SHA-256 as the Reports and the draft are (`lua/aineo/report/records.lua:24–35`, `lua/aineo/draft/init.lua:83`), with an extension other than `.jsonl`: `tests/test_entry_report.lua:83` and `:108` pin every `*.jsonl` under a case's state directory.
  - **The id** is made from `vim.uv.random(16)` and written `8-4-4-4-12` in lower-case hex, version nibble 4, variant `10xx`. `math.random` is not seeded: every Neovim draws the same sequence (the brief review measured it on both versions). A test pins the form on the recorded argument, and two editors started afresh in two directories get two different ids. `make lint` refuses the global `bit`: use `require('bit')`, or arithmetic.
- **SR2 — the next start there resumes it.** When aineo starts Claude Code in a directory whose session it keeps — a new Neovim there, or `\o` after Claude Code has exited — it starts it with `--resume <kept id>`, and the kept id stays. Only an id of the form SR1 pins is resumed: a kept file that holds anything else — empty, cut short, malformed — counts as no session (SR1), and is replaced. Write the id whole or not at all, as the draft home writes its file. `--mcp-config`, `--append-system-prompt` and `--allowedTools` are given as today, and `--allowedTools` stays last (`lua/aineo/claude/arguments.lua`, its docstring says why).
- **SR3 — a kept session Claude Code no longer has.** Q8 measured, on 2.1.283:
  - `--resume` of an id Claude Code never had (A) exits 1 after 2.1 s, and of the id of a session ended before any message (G) after 1.4 s, one run each, on the Q8 driver's 120×40 pseudo-terminal, printing `No conversation found with session ID: <id>` before any screen of its own;
  - a session in which nothing was typed leaves no conversation (F), so SR1's id is such an id whenever the user never typed;
  - **not measured:** an id whose conversation existed and is gone. SR3 assumes the same exit; name it in your note's *Limits*.

  Then aineo starts a new session in its place, by SR1: a new id, kept in place of the old one, its terminal taking the failed one's place in every window that showed it, as `start_session()` does today (`replace_terminal()`). It does so once per start. **Any other exit shows as today** — its exit on screen, `\o` restarts it — and the kept id stays. The user rejected falling back to the folder's last conversation (D23's options not chosen); the new session is the orchestrator's reading (below).
  - **The new terminal reaches everything that held the failed one** (the first brief review's T19-1). Today `replace_terminal()` runs only inside a `start_session()` the composition root called, and the composition root then hands the returned buffer on. SR3's fallback replaces the terminal from Claude Code's exit, behind the composition root's back. Make the composition root and the layout follow the new terminal: through a callback in the settings `started_claude_terminal()` passes, and a named entry point of the layout home for a new Claude terminal. Routing the fallback through `\o`'s path (`layout.open()`) instead moves the user to the layout's tab and reopens windows they closed; it is not wanted. The seam is yours under `tdd`.
  - **What goes wrong without the hand-off,** measured on `0a6b5bd` with a simulated fallback (this brief's review, both versions): the first `\c` repairs both holders, since T21's `M.focus()` reopens the layout when its buffer is wiped (`layout/init.lua:822`) and `start_session()` returns the running replacement. Until a `\c`, the layout and the composition root hold the wiped terminal:
    - a file opened in Claude's window stays there, hiding the new terminal, because `redirect()` gives up on a wiped buffer (`:325`), without an error;
    - the new terminal entered any other way (a window command, then `i`) loses EX1 and EX2: Terminal mode stays at its exit, the next key wipes it, and Claude's window stays on an empty buffer;
    - `i` on the ended replacement is not refused;
    - if the replacement exits before any focus, `\c` starts another Claude Code (a third) instead of showing its exit.
  - **Test, after the fallback, before any `\c`:**
    - a file opened in Claude's window moves to the file column;
    - the new terminal entered with a window command and `i` returns to Normal mode as its process ends (EX1), and is closed by a wipe as EX2 says;
    - `i` on the ended replacement is refused;
    - the replacement exits, then `\c` shows its exit in Normal mode and starts nothing.

    And `\c` enters Terminal mode in the new terminal. That test is green before any hand-off, since `\c` repairs both holders; it turns red only when the layout follows and the composition root does not. Build the layout's half first to see it red.
  - How aineo tells SR3's exit from another is yours under `tdd` and the integrator's *Three tiers of surface*: the message's text is tier 2, observable and undocumented, measured on 2.1.283; the exit code 1 alone cannot tell it apart (a used `--session-id` exits 1 too). The brief review measured that the message is in the terminal buffer at `TermClose` and at the job's `on_exit`, 8 of 8 runs on both versions, and that `TermClose` fires first. **The terminal wraps the message at the window's width** (measured at 40 and 60 columns: Claude's column is half the screen, 60 columns on a 120-column screen, and a third, 39, while the file column is open; the message wraps on any screen narrower than 150 columns, but not in the entry suites' 240-column child — a test of the wrap narrows it): match across its rows, or on its prefix only. Pin what you rely on with the fake, naming the version. Say in your note what you chose and what it gets wrong: a failure that looks like this one, and this one when it looks like another.
- **SR4 — per directory.** Two directories keep two sessions. A directory's kept session is never resumed in another: `:cd` elsewhere, then `\o` after an exit, resumes that directory's session or starts one of its own.
- **SR5 — nothing else changes (an invariant).** Readiness, Send, the stop on quit, the MCP server and its tool, the report instructions, `:checkhealth aineo` (which runs `claude --version` and starts no session), and every existing case of the suite: green, with the argument pins updated only by the two new words.

### The orchestrator's readings, for your note's *Readings for the MVP review*

- SR3's new session in place of one Claude Code no longer has — D23 says only that a directory with none gets a new one;
- the id is kept from the moment the session starts, whether or not anything is typed;
- a directory's kept id is never removed, as the drafts are not (MR125);
- two editors in one directory resume the same session: Q8 measured two Claude Codes started on one id at once, neither refused, with no message sent to either (a limit);
- SR3's fallback is visible: the user sees "No conversation found with session ID: …" for 1–2 s at every start that follows an untyped session, before the new one replaces it;
- Claude's session follows the directory Claude Code starts in (`settings.cwd`), while the Reports and the draft stay with the editor's first working directory (`kept_places()`): after a `:cd` the two can differ;
- after SR3's fallback the user is in Normal mode in the new terminal, even when they were typing in the one that failed (T21's EX1 at its exit); `\c` puts them in the new prompt;
- D23's own: a session switched inside Claude (`/clear`, `/resume`) is not followed.

### Facts, checked against `origin/dev` (the code `origin/dev` holds once PR #64 (T21) merges: the tree `0a6b5bd`)

- **The Claude home, `lua/aineo/claude/init.lua`:** `aineo.claude.Settings` (lines 12–17); `launch()` (line 154) builds the command from `settings.cmd` and `arguments.claude_arguments(settings)` (line 157); `start_session()` (line 200) starts one Claude Code at a time and, once the last has exited, a new one whose terminal replaces the old (`replace_terminal()`, lines 71–79); `session_status()` (line 224) reads `'exited'` with the exit code.
- **The composition root, `plugin/aineo.lua`:** `started_claude_terminal()` (line 116) passes `start_session()` its settings (lines 119–125), `cwd = vim.fn.getcwd()`; `kept_places()` (line 63) holds the state directory the Reports and the draft use, `vim.fn.stdpath('state')`. A home is given its state directory by the composition root, not reaching for it (`modularity`; the draft home's `set_draft_environment()` is the pattern).
- **Who holds Claude's terminal** (at the tree `0a6b5bd`):
  - the composition root's `claude_terminal` (`plugin/aineo.lua:107`), set by `started_claude_terminal()` (line 116, at line 119), read by `current_claude_terminal()` (lines 135–140) and by T20's `can_type_to_claude()` (lines 199–202);
  - the layout's `state.buffers.claude`, set by `build()` (line 511) and `M.open()` (line 790), read by `redirect()` (line 319), `redirect_when_file()` (line 348), `reopen_closed_windows()` (line 522), `show_buffers()` (line 556), T21's exit and wipe handlers (lines 579, 590, 617, 648), and `M.focus()`'s check (line 822), the reader that repairs both holders on the next `\c`;
  - `replace_terminal()` (`lua/aineo/claude/init.lua:71–79`) puts a new terminal in the windows that showed the old one, then wipes the old. T21's wipe handler then finds Claude's window showing a terminal that is neither the wiped one nor an empty buffer, and leaves it; but `state.buffers.claude` still names the wiped one, so T21's `M.focus()` treats Claude's window as gone and reopens the layout around `current_claude_terminal()`, whose `claude_terminal` is also stale; `start_session()` returns the running replacement, and both holders are repaired. Only once the replacement has exited does that `\c` start another Claude Code (measured, this brief's review).
- **The flags pin:** `tests/test_claude.lua:175–185`, "passes no flag beyond the servers, the instructions and the tools", pins the flag set and `#arguments == 7`.
- **The fake `claude`, `tests/helpers/fake_claude.lua`:** records its arguments, working directory and chosen variables as the first line of its record; its screens and key answers follow `AINEO_FAKE_CLAUDE_MODE`; the modes that exit by themselves exit with `AINEO_FAKE_CLAUDE_EXIT_CODE`. It knows nothing of session ids today. Teach it the measured behaviour you rely on (SR3), with the version, as its other behaviours are documented.
- **The suites' state:** every child of `make test` shares `.tests/state` (`Makefile:38`), and every child runs in the checkout's directory. `make test` and `make test_file` empty the drafts there at the start of each run (`Makefile:72`, `:79`, `:86`), because a draft an earlier run left came back in the next run (T14). A kept id is worse: every start writes one, so from the first case that starts Claude Code through `plugin/aineo.lua`, every later case of the run would start with `--resume`. Those cases live in `tests/test_entry*.lua`, outside your boundary. So:
  1. the fake's default treats `--session-id` and `--resume` as inert: it records them and nothing more;
  2. it models SR3 only under a variable that T19's own cases set;
  3. each of T19's cases has a state directory of its own (`stand_in_settings()` in `tests/helpers/claude_session.lua`, or `vim.env.XDG_STATE_HOME` set to a `fixture.directory(…)` for cases through the plugin);
  4. the `Makefile` also removes the kept ids at the start of a run.

  Every other case then runs with a leaked `--resume` and stays green: `tests/test_entry.lua:109`, `:121` and `:133` read the words after their own flag, `#arguments == 7` is pinned only in `tests/test_claude.lua:184`, which you update, and `--allowedTools` stays last.
- **Q8's other facts:** `--session-id` of an id already used prints `Error: Session ID <id> is already in use.` and exits 1 at once; `--resume` of an id Claude Code has continues that id, a new exchange appended to the same conversation. `--resume` with `--mcp-config`, `--append-system-prompt` and `--allowedTools` together was not measured; each is documented, and the three took effect interactively in wave 2. Never run the real `claude`: the attack review is told the combination is unmeasured.

### Baseline

- `dev` once PR #64 (T21) merges: its code is the tree `0a6b5bd`, which the orchestrator's verification of PR #64 measured: 1074 cases, `Fails (0)`, on 0.12.5 and 0.11.6, and lint clean (`evidence/baseline-0a6b5bd.txt`). If T17 (PR #68) merges before you start, re-measure the baseline on your base.

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
- `knowledge-vault/Sessions/2026-09-26 — T14 Input draft.md` › *Limits* (the drafts emptied at the start of each run, not between cases) and its fix round's I2;
- `knowledge-vault/Sessions/2026-09-26 — T21 Claude exit.md` (the layout's handling of Claude's terminal);
- `knowledge-vault/Implementation/Waves/00006-fixes/brief-review-t19-t21.md` › its T19 findings, which this brief answers.
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t19-claude-resume` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t19_claude_resume`.
- **You may touch:**
  - `lua/aineo/claude/`, a module of its own inside the home for the kept ids if your seam wants one;
  - `plugin/aineo.lua`: `started_claude_terminal()`, the settings it passes, the declaration of `claude_terminal` and its readers `current_claude_terminal()` and `can_type_to_claude()`, and nothing else: not the subcommand, action or key tables (T12 follows you there), not `open()`, `focus()`, `arrangement()`, `kept_places()` (read it, do not change it), `run()` or the autostart's functions;
  - `lua/aineo/layout/`: **one** named entry point that gives the layout a new Claude terminal, with its docstring — nothing else there;
  - `tests/test_layout*.lua` and `tests/test_entry*.lua`: new cases, or new files, for the fallback's hand-off — not `tests/test_entry_report.lua`;
  - `tests/test_claude*.lua`, new cases and the flags pin; a new `tests/test_claude_resume.lua`;
  - `tests/helpers/fake_claude.lua` and `tests/helpers/claude_session.lua`, for the session ids;
  - the `Makefile`, only the clean-up at the start of a run (required: the leak remedy's point 4);
  - `doc/aineo.txt`, **only** a new subsection `Claude's session ~` in `*aineo-layout*`, placed directly above `Input's draft ~`; and, in `*aineo-report*`, the list from `aineo starts Claude Code with three additions of its own:` to `` mcp__aineo__report`. ``, which SR1 and SR2 make false (a fourth addition);
  - your session note.
  - The documentation this change invalidates: the Claude home's docstrings (`start_session()`, `aineo.claude.Settings`), `started_claude_terminal()`'s and `claude_terminal`'s (`plugin/aineo.lua:104–115`), the layout entry point's, and the help. Correct them in the same change and say so in your report. Every list a new module changes — the lint's module patterns, any test that enumerates the source tree or the modules loaded at startup (`tests/test_plugin.lua:8`) — is yours to check.
- **You must not touch:**
  - `plugin/aineo.lua` beyond the lines above (T12 follows you there);
  - `lua/aineo/layout/` beyond the one entry point, `lua/aineo/report/` (T17), `lua/aineo/draft/`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/health.lua`;
  - `tests/test_plugin.lua`'s frozen pins, `scripts/`;
  - `doc/aineo.txt` outside your two ranges;
  - the task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note;
  - the project note, the MVP readings review;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Never run the real `claude`,** and never read or write `~/.claude/`: the suites point `CLAUDE_CONFIG_DIR` into the checkout.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your sections** are the new subsection, from `Claude's session ~` to its last line, directly above `Input's draft ~`, with at least one unchanged line between your hunk and `were opened until \`\o\` restores the layout.`; and the list of Claude Code's additions in `*aineo-report*`, from `aineo starts Claude Code with three additions of its own:` to `` mcp__aineo__report`. ``.
  - **The other packet:** T17 edits `*aineo-report*` too, in its `Links ~` paragraph and its colour groups. Every hunk of yours stays inside your two ranges.
  - **Before you push**, for `origin/bugfix/t17-report-paths` if it exists and is unmerged:
    1. `git fetch origin && git merge-tree --write-tree <your head> origin/bugfix/t17-report-paths`; report any conflict it prints, in any file;
    2. `git show <tree id>:doc/aineo.txt > doc/aineo.txt` and `git show <tree id>:tests/test_doc.lua > tests/test_doc.lua`;
    3. `make test_file FILE=tests/test_doc.lua`, on both versions;
    4. `git checkout HEAD -- doc/aineo.txt tests/test_doc.lua`.

    Report the results.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T19 Claude resume.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored); if the harness refuses to create it, use your worktree's `.tests/` and say so. Prefix every file with `t19-`. Keep all scratch inside your worktree, never in `/tmp`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **The user's request, 2026-09-26, as D23 records it:** “I want the plugin to remmeber the last session that was opened, and when reopening to load the session”, then “the claude session...”.
- **Asked which conversation to pick up**, the user chose "aineo's own last one", over "The most recent one (Recommended)" (`--continue`) and over asking each time, accepting that after a `/clear` or `/resume` inside Claude aineo reopens the older one. Then: "the last one, but it must be per project, someone working in a different folder/project, will have the last session executed on that folder." Asked which session aineo resumes in a folder, the user chose "aineo's own last one there (Recommended)", described as: "The last session aineo itself started in that folder. A conversation you ran in a plain terminal in the same folder is ignored. A folder where aineo never started one gets a new session." — over the folder's last conversation by anyone, and over aineo's own with the folder's last as a fallback. That is D23. So SR3's fallback is a new session, never the folder's last conversation.
- **Q8 was measured by the orchestrator** with the user's leave, on the user's login, in a scratch folder: `evidence/claude-resume-q8.txt`.

## Budget

Medium to large: a kept id per directory, two flags, one fallback and its hand-off to the composition root and the layout, the fake taught the measured behaviour, and the help. If it grows past that, stop at a green, pushed state and report a true partial.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t19-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
