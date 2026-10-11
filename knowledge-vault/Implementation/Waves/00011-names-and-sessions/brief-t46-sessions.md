**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> Written 2026-10-11 for the user's round-2 answers — R1 (b), aineo's own list over `claude agents --json`; R2 (a), the cursor check; R3 (a), a session running elsewhere listed and refused — for D51, for the orchestrator's rulings A114 and A118–A123 (end of this brief), and for O9 (a). It is dispatched only after the MVP review and the user's manual checks M7 and M8 (A114). A dated amendment at the end records M7's and M8's results, O9's ruling, and every fact below re-checked against the `dev` you start from; it wins over the body. **Never run the real `claude`**: the suites run the fake.

## Objective

The task, verbatim from the task list:

> | T46 | `\cs` opens Claude Code's list of sessions (C1, C3; D49): `:Aineo sessions`, `<Plug>(aineo-sessions)` and `\cs`; how the list opens, and what the key does when Claude Code is not ready or its prompt holds text, as the user answers U2 and U3 | — | planned — wave 11, after the MVP review *(2026-10-11: the user's round-2 answers make it aineo's own list over `claude agents --json`, refused on text by the cursor and on a session running elsewhere (D49's note); dispatched after the user's checks M7 and M8, A114)* |

It rests on: **D49** with its dated notes of 2026-10-11 (the request and the user's R1–R3, verbatim); **D51** (a pick that switches is the next resume) with its note; C1 (the entry point: `:Aineo`, `<Plug>`, the prefix mapped only where the user has not mapped it); C3 (the Claude session, its readiness); C4 and `lua/aineo/send/init.lua` (how Send writes to the terminal and refuses); D13 (`claude.cmd`); D36–D38 (a `/resume` is a switch aineo follows and resumes next); D42 (a claim); D26, D29. Design: `plan.md` › *Round 3*.

### The behaviour — one test each, seen failing first

1. `:Aineo sessions`, `<Plug>(aineo-sessions)` and `\cs` (the prefix, then `cs`) do one thing: list the folder's sessions and switch to the one picked, as below.
2. **The list.** aineo runs `claude.cmd` followed by `agents --json --cwd <folder> --all` (O9 (a)), `<folder>` the directory Claude Code started in, asynchronously and bounded in time as the health check bounds `claude.cmd --version`; the editor never waits on it. The entries that carry a `sessionId` are offered in `vim.ui.select`, one row each: the name (or the first eight characters of the id), `interactive` or `background`, and the `status` or `state`.
3. **Marks.** The row of the session aineo's own terminal is on (`session_id()`) is marked as this terminal's; every other row whose entry has a `pid` is marked as running elsewhere (R3 (a)).
4. **A pick of this terminal's row, or of a row running elsewhere,** writes nothing and says why: the first is the session already shown; the second runs in another terminal or in Claude Code's background service, and a switch would pull it away from there (R3 (a)).
5. **A pick of any other row** writes `/resume <sessionId>` and Enter (`\r`) to Claude Code's terminal — when, at the pick, Claude Code is ready and its prompt shows no text (behaviour 7). Claude Code switches, and aineo follows the switch through what exists (D36–D38); D51 makes it the next resume.
6. **Refusals before the list.** Claude Code not ready — never started, starting, a dialog in its window such as the trust dialog, or exited (`session_status()` not `'ready'`) — in Send's words for each state (`lua/aineo/send/init.lua` 33–35), with `no session list` in place of `nothing sent`; a claim of another session (D42), as Send refuses (A120); `claude agents --json` failing, timing out, or printing what is not a JSON array, told in its own words; an empty list. None runs `vim.ui.select`, and none writes anything.
7. **Text shows** (U3 and R2 (a), the user's decisions): unless the input box, read as `readiness.lua` reads it, is one line and the terminal's cursor sits right after `❯ ` on it, the prompt shows text, and the pick writes nothing and says the prompt holds text — clear it, then pick again. The grey example and suggestions Claude Code draws in an empty prompt must not count as text: the fake's `ready` mode replays that screen, cursor included. A draft (`draft` mode, two lines, the cursor at its end) refuses.
8. **The cursor** (A121). After a pick that switches, the cursor goes to Claude's window in Terminal mode, as `\c` leaves it. A refusal leaves it where it was, with the message. If reading the terminal's cursor needs Claude's window in Terminal mode (below), a refusal puts the window and the mode back as they were.
9. `:Aineo sessions` takes no word; completion offers `sessions` after `claude-numbers`. `\cs` is mapped only where the user has no global `\cs` of their own (`map_unless_mapped()`), and the health check reports it with the other prefix keys.

### Facts, checked against `origin/dev` `e6a0295` — re-checked by the amendment

- `plugin/aineo.lua`: `SUBCOMMANDS` 27–28; `focus_claude()` 757; `holds_other_claim()` 263 and `refuses_send_while_claimed()` 831; `ACTIONS` 850; `PREFIX_KEYS` 969 (`claude = 'c'`, so `\c` becomes a prefix of `\cs` and waits `'timeoutlen'`: the cost the user accepted in D49); `map_unless_mapped()` follows it.
- `lua/aineo/claude/init.lua`: `session_status()` 582; `session_id()` 778; `write_to_session(bytes)` 837, which writes whatever the state and raises when no session runs.
- `lua/aineo/health.lua`: `check_claude_version()` 193 runs `claude.cmd` with `--version` appended, within a bound (`run_within_bound()`); the prefix-key table at 303.
- `lua/aineo/claude/readiness.lua` 44–56 reads the input box: a rule, the `❯` line, the lines that begin with two spaces, a rule. The grey text reads as text in the buffer and Lua sees no cell attribute that marks it (`evidence/w11-probes.txt`, P6, P7).
- Claude Code puts the terminal's cursor right after `❯ ` on an empty prompt (`ESC[20;3H` in `tests/fixtures/claude/startup-2.1.281.bytes`) and at the end of a draft (`ESC[20;14H` in `draft-2.1.281.bytes`) (P7). **Not measured: how Lua reads the terminal's cursor.** Measure it first, on the fake: in Terminal mode Neovim is expected to keep the window's cursor on the terminal's, so read it once Claude's window is in Terminal mode — on `ModeChanged` or `TermEnter`, not inside the mapping, since `startinsert` takes effect after the mapping returns. If no reading holds on both recordings, stop at a green, pushed state before behaviour 7 and report a true partial.
- `claude agents --json` (`evidence/w11-probes.txt`, P8; `agent-view.md`, *List sessions as JSON*): fields `cwd`, `kind`, `startedAt` always; `id`, `state` for background sessions; `pid`, `status` while the process is alive; `sessionId`, `name` when set. `--add-dir` or `--mcp-config` placed before `agents` makes it fail with `unknown option`: a `claude.cmd` that holds them is a failed list (behaviour 6). What it prints on the user's machine is M7's, pasted in the amendment.
- `tests/helpers/fake_claude.lua`: modes `ready`, `trust`, `draft`, `exit` among others; every chunk of input is recorded as `{ "received": … }`, in raw mode; `/resume <id>` and Enter switch its session with the hooks when `AINEO_FAKE_CLAUDE_HOOKS` is set. Teach it `agents --json` as `plan.md` › *Round 3* says: record the argv, print the array in the file `AINEO_FAKE_CLAUDE_AGENTS` names (`[]` when unset), exit 0, or exit with `AINEO_FAKE_CLAUDE_AGENTS_EXIT` and print nothing; no screen, no key read. `plan.md` › *How a test proves the key is sent* says how a test uses it.

### Baseline

The suite's counts on the `dev` you start from are pasted by the dispatch message.

Read first: the v1 plan note's C1, C3, C4, D13, D36–D38, D42, **D49**, **D51**; `plan.md` in this folder (*Round 2*, *The user's answers — round 2*, *Round 3*, *The orchestrator's rulings*); `evidence/w11-probes.txt` (P5–P8); `knowledge-vault/Projects/aineo.md`; the session notes of T7, T20, T35 and T39 in `knowledge-vault/Sessions/`.

## Boundary

- **Branch:** `feature/t46-sessions` from `origin/dev`.
- **Class:** regular.
- **Model:** `sonnet` (A123).
- **Resources:** `impl_t46_sessions` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `plugin/aineo.lua` (outside the autostart: `SUBCOMMANDS`, `ACTIONS`, `PREFIX_KEYS`, the new action and its `vim.ui.select`); `lua/aineo/claude/` for the list read from `claude agents --json` and for behaviour 7, in new files there or beside `readiness.lua`, exported through `lua/aineo/claude/init.lua`; `lua/aineo/health.lua` (its prefix-key table); `tests/helpers/fake_claude.lua` (the `agents --json` answer only, its docstring updated); a new `tests/test_entry_sessions.lua` and new or existing `tests/test_claude_*.lua` for the Claude home's parts; the suites that pin the subcommands, the `<Plug>` mappings or the prefix keys, where a pin moves (`tests/test_plugin.lua`, `tests/test_entry.lua`, `tests/test_entry_prefix.lua`, `tests/test_health.lua`); `doc/aineo.txt` — the introduction's paragraph that begins `Every command sits behind one prefix key` and ends `(|aineo-v_\s|).`, section 4 from `4. COMMANDS` to the last line before section 5's rule, and section 5 from `5. MAPPINGS` to the last line before section 6's rule (the paragraph on keys that wait for `'timeoutlen'` names `\c` now); your session note. Correct in the same commit what the change makes false there, and say in your report what you corrected. Run every test file that requires the fake when you change it.
- **You must not touch:** the rest of `lua/aineo/claude/` (`session_status()`, `session_id()` and `write_to_session()` are used as they are), `lua/aineo/changes/`, `lua/aineo/git/`, `lua/aineo/layout/`, `lua/aineo/send/`, the rest of `tests/helpers/`; every other section of `doc/aineo.txt`; `tests/test_doc.lua` (run it); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`, with any packet open when you push. Before you push, merge your copy with its current head (`git merge-tree --write-tree <your head> <its branch>`) and run `make test_file FILE=tests/test_doc.lua` on the merged file; report both results.
- **Session note:** `knowledge-vault/Sessions/<date> — T46 Claude sessions key.md`, `<date>` the dispatch message's.
- **Scratch prefix:** `t46-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5. While you work, the test files you touch and every one that requires the fake, plus `tests/test_doc.lua`; the whole suite (`make test`) once before each push; mutants on their covering files. The fake `claude` only.

## What was decided already

- D49's decided parts and its notes: the key `\cs`, `:Aineo sessions`, `<Plug>(aineo-sessions)`, the cost that `\c` waits `'timeoutlen'`; R1 (b), R2 (a) and R3 (a), the user's decisions of 2026-10-11, quoted there verbatim.
- D51: a pick that switches is the next resume, as D38 does.
- U3, the user's decision: "Refuse when text shows" — the prompt is never cleared by aineo.
- The orchestrator's rulings below, and O9 (a) unless the amendment says otherwise.

## Budget

Medium: one action and its three entry points, a list read from a second `claude` run, its marks and refusals, the text check, the fake's new answer, its help and health lines — about fifteen cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t46-report-packet.md`. Open the pull request into `dev` before you report, with every verification claim a reviewer can re-measure, each test file whose pins moved and why, and the whole suite's counts. The orchestrator's verification runs `plan.md`'s five T46 mutants: name the test that kills each.

## The orchestrator's rulings — 2026-10-11

`plan.md` › *The orchestrator's rulings*. Each is the orchestrator's assumption, to be recorded in the session note and the PR body as such, never as the user's decision:

- **A114 (O8):** T46 goes in after the MVP review, and after the user's M7 and M8.
- **A118 (O1):** T45 after T44 merges; T46 as A114.
- **A119 (O2):** T46 on `neovim-claude-code-integrator`.
- **A120 (O3):** under a claim, `\cs` refuses as Send does.
- **A121 (O4):** after a pick that switches, the cursor goes to Claude's window in Terminal mode; a refusal leaves it where it was, with the message.
- **A123 (O7):** Sonnet implementers; the attack review on Opus; tests and records in one Sonnet `records-reviewer`.
