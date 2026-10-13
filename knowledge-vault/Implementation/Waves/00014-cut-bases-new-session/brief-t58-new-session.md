**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md`, and `.claude/agents/neovim-lua-developer.md`, whose Neovim rules bind you too.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> This brief is written for D61 as proposed and for the recommendations O12–O17 of `plan.md` in this folder. If the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body.

## Objective

The task, verbatim from the task list:

> | T58 | A key for a new Claude Code session (C1, C3; D61): `:Aineo new`, `<Plug>(aineo-new)`, `\N` and `<C-\>N`. It starts a new session on a new id once Claude Code has exited, writes `/clear` while Claude Code runs with an empty prompt, and refuses otherwise. With its line in the health check and the help | T46, T54 | planned — wave 14 |

It rests on these rows:

- **D61**: the user's decision that a single key gives a new session after `/exit`. Its letters and behaviour are proposed, the orchestrator's assumptions under the user's "go ahead implement them" of 2026-10-13, quoted whole in `plan.md` › *D60 and D61*.
- D23 and D38: the id kept for the folder. D36 and D37: the switch followed, and `/clear` as a switch. D14: a write during a turn. D40, D41, D45.
- D49, D51, D53 and T46: `\S`'s pasted write, prompt check and refusals.
- D58 and T54: the twins. D25: the exit. D54 and T48 part 1: the start that waits for the list.
- C1, C3, D10, D26, D29.

### The behaviour — one test each, seen failing first

**The entry points (C1)**

1. `:Aineo new` runs the action, and completion offers `new` among the subcommands, after `sessions`. It takes no word: `:Aineo new x` is refused as `:Aineo sessions x` is.
2. `<Plug>(aineo-new)` runs the same action in Normal mode. `\N` is mapped to it as every prefix key is: globally, in Normal mode, unless the user has mapped those keys already.
3. Its twin `<C-\>N` is mapped in Terminal and Insert mode as T54 maps every twin (`LEAVE_MODE`, then the `<Plug>` mapping), under the same skips. `:checkhealth aineo` lists `\N` and `<C-\>N` in its *Prefix mappings* and *Terminal prefix mappings* sections.
4. No existing key changes. `\c`, `\S`, `\o` and every twin act as before, and `\c` still waits for nothing (D53): no aineo key starts with `N`, and `N` begins none.

**No Claude Code running in this editor (O14 (a))** — it has exited, never started, or its terminal was wiped:

5. The action starts a new session on a new id (`--session-id`). It does not resume the kept id, and it runs no list of sessions.
6. The new id is kept for the working directory, so the next `\o` after an `/exit` resumes it.
7. The layout opens, or is restored, around the new terminal, as `\o` does. The new terminal takes the exited one's place in Claude's window, and the cursor goes to Claude's window in Terminal mode, as `\c` leaves it.
8. A start whose session differs from the one followed is told as a switch (`on_session_switched`), so the Report, Input's draft and the changes pane follow the new session (D37's `/clear`: empty, `HEAD` as base). An editor's first start is no switch, as today.

**Claude Code running and ready, with an empty prompt (O15 (a))**

9. The action moves to Claude's window in Terminal mode. It reads the prompt there (`claude.prompt_shows_text()`), and writes a bracketed paste of `/clear` followed by Enter, in one write (`claude.write_to_session()`), as `switch_to_session()` writes `/resume <id>`.
10. The fake's `SessionEnd` and `SessionStart` follow, and aineo follows the switch: a new id followed and kept for the folder, an empty Report. The cursor stays in Claude's window in Terminal mode.

**Refusals (O16 (a))** — nothing is written and nothing is started. One warning begins `aineo: no new session — ` and says why, and the cursor goes back to the window and mode it came from (`return_to()`):

11. The prompt shows text. Tell the user to clear it and press the key again. aineo never clears it.
12. Claude Code is not ready: it is starting, behind a dialog, or in a start that waits for the session list (T48 part 1). Use the words `:Aineo sessions` uses (`NOT_READY`).
13. A claim of another session holds, in any state of Claude Code. Use `refuses_while_claimed()`'s words, with the way out.
14. Claude's window does not enter Terminal mode within the time T46 waits (`TERMINAL_MODE_PATIENCE_MS`).
15. The twin `<C-\>N` pressed in Claude's prompt in Terminal mode and in Insert mode in another buffer gives each of behaviours 5, 9 and 11, as `\N` does.

The help is not in that list. `tests/test_doc.lua` derives the tags the plugin defines and checks that the help holds them (`TAGS_THE_PLUGIN_DEFINES`), so `:Aineo-new`, `<Plug>(aineo-new)`, `aineo-\N` and `aineo-<C-\>N` must exist. Run it.

### Facts, checked against `origin/dev` `7856882`

**`plugin/aineo.lua`.**

- `SUBCOMMANDS` (28), `ACTIONS` (1225), `PREFIX_KEYS` (1345), `LEAVE_MODE` (1362) and `HAS_NO_TWIN` (1366).
- `started_claude_terminal(config)` (608) calls `aineo.claude`'s `start_session()` and `aineo.changes`' `begin_session()`. `open()` (689) opens the layout around it. `focus_claude()` (765) moves to Claude's window and enters Terminal mode when keys would reach Claude Code.
- `refuses_while_claimed()` (874), `refuses_while_not_ready()` (903) and `NOT_READY`. `after_entering_terminal_mode()` (1022), `return_to()` (1060), and `switch_to_session()` (1091) with its `PASTE_START`, `PASTE_END` and `PROMPT_HOLDS_TEXT`.
- These helpers are file-local, and `\S`'s refusals begin `NO_LIST` or `NOT_SWITCHED`. Give `new` its own prefix and reuse the helpers. Do not copy them.

**`lua/aineo/claude/init.lua`.**

- `kept_or_new_session()` (200) gives the kept id, resumed, or a new id. `start_in_place()` (563) starts a choice at once and keeps a new id. `start_session()` (762) starts nothing while a session runs. It runs the list before a resume (`start_after_list()`), and announces a start on a new id at once.
- `aineo.claude.Settings` (17) and `validate_settings()` (134) are where a request for a new session goes. One field, validated as the others are, keeps one entry point. Say in `start_session()`'s docstring what it changes.
- `session_status()` (788) gives `'ready'`, `'starting'` (the list's wait included) or `'exited'`. `prompt_shows_text()` (1050) and `write_to_session()` (1101) are there too.

**`lua/aineo/health.lua`** has its own `PREFIX_KEYS` list (299), which gains `N` for `<Plug>(aineo-new)`. The twins come from it.

**The fake.** `tests/helpers/fake_claude.lua` answers a pasted `/clear` and Enter, in one chunk, with `SessionEnd` (`clear`) and then `SessionStart` of a new id (`clear`), when `AINEO_FAKE_CLAUDE_HOOKS` is set (`switch_session()`, about line 566). No change to it should be needed. If one is, it is an addition, and you run every test file that uses the fake.

**Pins that list the subcommands:** `tests/test_entry.lua` (83) and `tests/test_entry_panes.lua` (1285). They gain `new`.

**Unmeasured.** No suite runs the real Claude Code (D10).

- That Claude Code takes a pasted `/clear` as a command is unmeasured, as T46's pasted `/resume` is (wave 11, *Landed*).
- So is what Claude Code does with `/clear` written during a turn (O17).

Both are the user's checks M1 and M2 after release (`plan.md` › *Checks for the user*), and both belong in LIMITS.

### Baseline

This plan ran no suite. The last whole run on record is T48 part 1's: 3052 cases, `Fails (0)`, on a tree without T55's cases. The dispatch message pastes the counts of the files you run, measured on the `dev` you start from.

Read first:

- the v1 plan note's C1, C3, D23, D25, D36–D38, D49, D53, D58 and **D61**;
- `plan.md` in this folder (O12–O17, *Checks for the user*);
- `Implementation/Waves/00011-names-and-sessions/plan.md` › T46's *Landed* and A133;
- the session notes of T46, T54 and T48 part 1;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t58-new-session` from `origin/dev`.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t58_new_session`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `plugin/aineo.lua`, `lua/aineo/claude/init.lua` and `lua/aineo/health.lua`.
  - A new `tests/test_entry_new_session.lua`, and `tests/test_claude.lua` or `tests/test_claude_resume.lua` for the start on a new id.
  - `tests/test_entry.lua`, `tests/test_entry_panes.lua`, `tests/test_entry_prefix.lua`, `tests/test_entry_terminal_keys.lua` and `tests/test_health.lua`, where a pin moves.
  - `tests/helpers/`, **additions only**. If you add to a helper, run every test file that requires it.
  - In `doc/aineo.txt`:
    - the INTRODUCTION's paragraph on the keys;
    - *aineo-claude-session*;
    - COMMANDS from `*:Aineo-sessions*` to `*:Aineo-pane*`, where the new `:Aineo-new` entry goes;
    - MAPPINGS (the `<Plug>` list and *aineo-keys*), and *aineo-terminal-keys*;
    - HEALTH CHECK's `Prefix mappings ~` and `Terminal prefix mappings ~`;
    - LIMITS › `Session switches ~` and `The session list ~`, or a new LIMITS entry after the latter.
  - Your session note.

  Correct in the same commit what the change makes false there, and say in your report what you corrected.
- **A document shared under rule 2's section exception: `doc/aineo.txt`.** T56 edits it at the same time: *aineo-changes* from `` `gf` on a file listed under a commit `` to `a fault to report.`, and LIMITS › `The changes pane ~`. T57 later edits *aineo-changes*' worktree-base sentences and the same LIMITS entry.
  - Every hunk of yours stays inside your sections.
  - Before you push, merge your copy with T56's current head if it is not merged (`git merge-tree --write-tree <your head> origin/bugfix/t56-commit-file-read`), run `make test_file FILE=tests/test_doc.lua` on the merged file, and report both results.
- **You must not touch:**
  - `lua/aineo/changes/`, `lua/aineo/git/`, `lua/aineo/layout/`, and every other file under `lua/aineo/claude/`;
  - `lua/aineo/config/`, since no setting is added;
  - every other file under `lua/`, `scripts/` and `tests/`, including `tests/test_doc.lua` (run it);
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep the interfaces.** Every export of `aineo.claude` keeps its name, its arguments and its promises. `start_session()` gains one optional setting, and nothing else changes.
- **Session note:** `knowledge-vault/Sessions/<date> — T58 New session key.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t58-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_entry_sessions.lua`, `tests/test_claude_switch.lua` and `tests/test_doc.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.
  - Never run the real `claude`.

## What was decided already

- **The user's decision, 2026-10-13, verbatim:** "go ahead implement them", answering a list that named "the offered single key for a new session after `/exit`" (`plan.md` › *The user's words*). The key is the user's.
- **The rest is the orchestrator's.** D61's letters, command, states and refusals are the orchestrator's assumptions under that answer (O12–O17). Record them in the session note and the pull request as such, never as the user's decisions.
- **Rejected alternatives.** `\n` (its twin is one released Ctrl from `<C-\><C-n>`), `\cn` (it makes `\c` wait again, D53), `\O`, stopping a running Claude Code to start a new process, and clearing the prompt's text. Do not reopen them.
- **What stays as it is.** `\o` keeps resuming the kept session (D23, D38), and T48 part 2 (wave 12) stays held and untouched.

## Budget

Medium: one action over the start and the pasted write that exist, one setting of the start, the key in two lists, and the help, with about fifteen new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

Write it in your definition's shape, to `<scratchpad>/t58-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:

- every verification claim a reviewer can re-measure;
- each test file whose pins moved, and why;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s five T58 mutants. Name the test that kills each.
