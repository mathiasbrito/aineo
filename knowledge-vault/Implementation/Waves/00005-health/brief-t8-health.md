**Your role: implement.** Your worktree starts from `main`, whose `.claude/` is stale: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md` — you are dispatched as that specialist; its *What bites here* binds you, *Configuration is not initialization* (unknown keys to the health check, not the hot path) and *Annotations are the docstrings; vimdoc is the manual* among it — and `.claude/agents/neovim-claude-code-integrator.md` › *Tests*.

You are dispatched by the orchestrator to implement **one packet** of the aineo v1 plan: T8, the health check and the help — the last task before the user's MVP review. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*:

> T8 — Health (C7) and `doc/aineo.txt`

It rests on:
- **C7:** "Health: `claude` and its version, the server socket, prefix-mapping conflicts, why autostart did or did not run", at `lua/aineo/health.lua`;
- **R3:** the user's `maplocalleader` is `\`; "C7 reports conflicts";
- the plan's **Done means**: "`:checkhealth aineo` passes; … vimdoc documents every command";
- **D1**, **D3**, **D13**, **D15** and the plan's **v1 commands** line, for what the help documents.

Read those rows in the plan, not this summary of them. Two items the earlier packets left to T8 also bind you:
- **MR73:** unknown configuration keys are silent when aineo opens, and the health check reports them (T7's reading 11);
- **MR38:** an earlier `VimLeavePre` handler that raises makes Neovim 0.11.6 skip aineo's stop of Claude, and a hung Claude then outlives the editor; the health check and the help name it (the attack review of PR #11, A5).

### The behaviours — the orchestrator's reading of C7, one test each; the seams are yours

- **HB1 The check.** `:checkhealth aineo` runs `require('aineo.health').check()`, built on `vim.health.start`, `ok`, `warn`, `error` and `info` (`:h health-dev`, Neovim 0.11.6). It starts nothing and changes nothing: no Claude session, no layout, no mapping. `health.lua` composes nothing and starts no home's work; it reads the configuration, the editor's state and HB5's record.
- **HB2 Claude and its version.** From the resolved configuration:
  - `claude.cmd`'s **first word** not executable (`executable()`) → an error naming it, with the advice to install Claude Code or set `claude.cmd`. The Claude home's own check, `ensure_executable()`, is local to it, so the health check makes its own, with the same wording (`claude.cmd: '<word>' is not executable`);
  - executable → run **`claude.cmd` whole, with `--version` appended**, as a list, never through a shell, bounded in time (your bound, stated), and report the output as `ok`. The whole command, not the first word: a wrapper such as `{ 'npx', '-y', '@anthropic-ai/claude-code' }` or `{ 'env', 'X=1', 'claude' }` would otherwise report the wrapper's version (the brief review's finding 1).
  - *Measured by the orchestrator* (`evidence/claude-version.txt`): `claude --version` printed exactly `2.1.282 (Claude Code)` on stdout, exit 0, in 20 ms. The version aineo's measurements were made on — 2.1.281 for waves 2–4 — is worth an `info` line, not a failure.
  - A `--version` that fails, prints nothing or runs past the bound → a warning. *Measured by the brief review* (Neovim 0.11.6, `lua/vim/_system.lua`): `SystemObj:wait(t)` kills at `t`, waits up to `t` more for the pipes, and can return `nil` — `vim.system({ 'sh', '-c', 'sleep 3 & sleep 3' }):wait(500)` returned `nil` after 1005 ms — so a `nil` result is the timeout's warning, never an index into `nil`.
  - **In the suites the real `claude` never runs:** the suites put a stand-in first on `PATH` that exits 127 (`scripts/minimal_init.lua`, `tests/helpers/entry_guard/claude`). Test the executable case with **a script under `tests/helpers/health*`** that prints a version of its own and records its argv. Not with the fake: its `claude.cmd` is `{ <nvim>, '--clean', '-l', 'tests/helpers/fake_claude.lua' }`, so `--version` runs the fake, which exits 1 over a pipe (`fake_claude.lua` puts its terminal in raw mode unconditionally) — *measured by the brief review*. In an HB5 editor running the fake, the version line is therefore a warning, and the test says so.
- **HB3 The server socket.** `v:servername` non-empty → `ok` naming it; empty → an error, since the relay reports into the editor at that address (C5).
- **HB4 Prefix-mapping conflicts (C7, R3).** For each of `<prefix>s`, `o`, `r`, `i` and `c` with the resolved prefix:
  - aineo's mapping in place → `ok`;
  - a user's global mapping holding the key sequence (T7 left it to the user) → a warning naming what it runs;
  - the **effective** local leader equal to the prefix → a warning that a filetype plugin's `<LocalLeader>` mapping would shadow aineo's keys in that buffer (R3). The effective local leader is `vim.g.maplocalleader`, or `\` when it is unset or empty (`:h <LocalLeader>`: "just like <Leader>, except that it uses ‘maplocalleader’"; `:h <Leader>`: "If ‘g:mapleader’ is not set or empty, a backslash is used" — *measured by the brief review*: with it unset, `nnoremap <buffer> <LocalLeader>s …` maps `\s`); compare both normalised with `nvim_replace_termcodes`, and test it unset and set. In the user's own editor this line always warns — the user's configuration sets `maplocalleader` to `\` (R3) — so the plan's "`:checkhealth aineo` passes" means no error, warnings allowed;
  - the prefix a string and `<prefix>s` (or another key) mapped by neither aineo nor the user — after a `setup({ prefix = … })` run after `VimEnter`, which remaps nothing (MR71), or after the user unmapped it → a warning;
  - `prefix = false` → `info`, nothing mapped.
- **HB5 Why the autostart did or did not run (C7).**
  - T7 records no reason today (`plugin/aineo.lua`, `start_up()`), and some of its inputs exist only at startup: stdin read, `v:argv`, a session a plugin restored. Record the decision and its reason **in an editor variable of aineo's own, `vim.g.aineo_<name>`** — you may change `plugin/aineo.lua` for that and nothing else. Not in a module and not in an autocommand: *measured by the brief review*, `require('aineo.health')` from the plugin fails T1's pin *loads the configuration alone in a headless start*, and an added autocommand fails *defines :Aineo, … the StdinReadPost autocommand alone* (`tests/test_plugin.lua`, the two pins stay as they are); the modularity table also has no `plugin` → `health` edge. Not inside `vim.g.aineo` either, where `resolve_config` would return it as an unknown key and HB6 would warn about aineo's own record.
  - The check reports one reason, and when several hold, the first in the code's own order: `autostart = false`; no UI attached (headless); a file argument; stdin read; a startup task (`-c`, `-S`, `-e`, `-s`, `-E`, `+cmd`); `$AINEO_CHILD` (inside aineo's own Claude terminal); a restored session. Besides: it ran; sourced after `VimEnter`; a wrong setting; **decided to open but the open raised** — for example `claude.cmd` not executable — which is not "it ran"; and **no record at all** (`vim.g.loaded_aineo` set before startup, or `--noplugin`: `:checkhealth aineo` still finds `lua/aineo/health.lua` by name) → an `info` line saying so.
- **HB6 The configuration.** A wrong value → an error naming the setting (what `resolve_config` raises); unknown keys → a warning naming each (MR73).
- **HB7 MR38.** An `info` line saying that aineo stops Claude from its own `VimLeavePre` handler, and that a handler registered earlier which raises makes Neovim skip it. Name the limit; do not try to detect it.

### The help — `doc/aineo.txt`

- A vimdoc file in Neovim's help format: a first line with the tag `*aineo.txt*`, `textwidth` 78, and the modeline `vim:tw=78:ts=8:ft=help:norl:`. `neovim-lua-developer.md` › *Annotations are the docstrings; vimdoc is the manual* binds it.
- **It documents every command, mapping and setting** the plan and T7 name, each with its own tag:
  - `:Aineo` and each of `send`, `open`, `report`, `input`, `claude`;
  - the five `<Plug>(aineo-…)` mappings;
  - the prefix keys;
  - the D13 settings (`prefix`, `autostart`, `claude.cmd`, `layout.report_height`) through `vim.g.aineo` and `setup()`.
- **It also documents:** the layout; Send (D14 during a turn); the report tool and C6's format; `:checkhealth aineo`; the autostart and when it does not run (D3, D15); and a *Limits* section that names MR38 and the 80-column line (MR78).
- **It states behaviour as it is on `dev`,** each fact from the code or the session notes, never from the plan's wishes. Where the MVP list holds a reading the user has not confirmed yet, it documents what the code does.
- **Tests:** `:helptags` over a copy of `doc/` generated under `.tests/`, never in the checkout — `.gitignore` does not cover `doc/tags` — gives no error (E154, duplicate tags); `:help aineo` opens the file; every subcommand, `<Plug>` name and setting has a tag.

### Facts, checked against `origin/dev`

`<scratchpad>` is the orchestrating session's scratch directory, which the dispatch message names; paths under `evidence/` are in `knowledge-vault/Implementation/Waves/00005-health/`.

- `origin/dev` at dispatch is `a9e2d4e` (PR #19, agent documentation only, on `201873b`) followed by this wave's knowledge commits (vault only), so its code is `201873b`'s: waves 1–4 landed.
- `lua/aineo/health.lua` and `doc/` do not exist yet. `.claude/skills/modularity/SKILL.md` §1 names `lua/aineo/health.lua` "the `:checkhealth aineo` entry (C7) — a file Neovim looks up by name, not a home", and its direction table lets it require any home's entry point.
- The homes' interfaces are read in their docstrings on `201873b`:
  - `aineo.config`: `resolve_config` returns the configuration and the unknown keys.
  - `aineo.claude`: `start_session`, `session_status`, `write_to_session`, and the not-executable line `claude.cmd: '<word>' is not executable`.
  - `aineo.mcp`, `aineo.report`, `aineo.layout`, `aineo.send`.
  - The composition in `plugin/aineo.lua`.
- **The suites** (the root `CLAUDE.md` since PR #19): `make test` isolates every Neovim under `.tests/`, puts a `claude` that exits 127 first on `PATH` (a `claude` run by name; an absolute `claude.cmd` passes it), removes `AINEO_CHILD`, and presets `vim.g.aineo = { autostart = false }` in every Neovim that loads the suites' init, unless a test sets `vim.g.aineo` with `--cmd` — **a test that sets it for any key replaces the preset whole**, so aineo's default `autostart = true` applies unless it says otherwise. A health test of the autostart reason runs a start that autostarts, or refuses, through T7's interactive-editor helper (`tests/helpers/entry_editor.lua`), with `claude.cmd` naming the fake.
- The real `claude` never runs in your packet: not in a test, not in a measurement.

### Baseline

`make test` on `201873b`: **613 cases, `Fails (0)`, exit 0**, 431 s — `evidence/baseline.txt`; `.claude/hooks/test-hooks.sh`: **105 passed**.

Read first:
- the plan's *Architecture* (C1–C7, the v1 commands line), *Decisions* (D1, D3, D13, D14, D15) and *Risks* (R3, R4);
- `knowledge-vault/Projects/aineo.md`;
- `knowledge-vault/Review/2026-09-24 — v1 MVP readings review.md` — what the code does where the plan is silent, which the help must match;
- the T7 session note's *Readings* and *Limits*.

## Boundary

- **Branch:** `feature/t8-health` from `origin/dev`.
- **Model:** `opus` (D9).
- **Resources:** `impl_t8_health`.
- **You may touch:**
  - `lua/aineo/health.lua` (new) and `doc/aineo.txt` (new);
  - `plugin/aineo.lua` — for HB5's record only;
  - `tests/test_health.lua` and `tests/test_doc.lua` (new);
  - new files under `tests/helpers/` whose names begin with `health`, and new modes in `tests/helpers/fake_claude.lua`, the existing ones unchanged;
  - new fixtures under `tests/fixtures/health/`;
  - the session note below.
- **Pins that count what you add, and stay as they are:** `tests/test_plugin.lua` › *loads the configuration alone in a headless start* and *defines :Aineo, … the StdinReadPost autocommand alone* (finding 2 of the brief review).
- **Documentation your change must keep true:** `plugin/aineo.lua`'s header docstring and MR70 of the MVP list ("`VimEnter` loads `aineo.config` alone") — true with an editor-variable record; there is no README.
- **You must not touch:** the homes (`lua/aineo/*/`), `lua/aineo/init.lua`, `scripts/`, the `Makefile`, T1–T7's existing tests, the plan note (marks held: a `## Task lines` section in your note), the project note, and never `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude` or `.gitignore`. A need there is a spec conflict for your report.
- **Session note:** `knowledge-vault/Sessions/2026-09-25 — T8 health and help.md` — this exact filename.
- **Scratch prefix:** `t8-`.

## What was decided already

- **The health check reads, it never starts** (HB1) — the orchestrator's reading of C7: a check that started Claude would be the autostart by another door.
- **Unknown keys go to the health check** (MR73), per `neovim-lua-developer.md`: not the hot path.
- **MR38 is named, not detected** (HB7).

## Verification mutants — the orchestrator runs these on your final head

- **M24:** the version check skipped — an executable `claude.cmd` is reported `ok` without running `--version` → the version test fails.
- **M25:** the autostart reason not recorded → the HB5 test fails.
- **M26:** unknown keys not reported → the HB6 test fails.
- **M27:** one subcommand's tag removed from `doc/aineo.txt` → the help test fails.

## Readings

Every choice where the rows and this brief are silent goes to a *Readings for the MVP review* section of your session note, each named once, with the same list in the pull request body and your report. That includes the version bound, which lines are warnings and which are errors, and what HB5 calls each reason.

## Budget

Medium: one health file, one help file, a record in `plugin/aineo.lua`, and their tests. If it is larger, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t8-report-packet.md`. Open the pull request into `dev` before you report, with every verification claim a reviewer can re-measure. **Keep your context small:** test and mutant output go to files, and you read back the summary line and the failing names. Run each mutant against a copy of its test file narrowed to the group it targets, under `.tests/`, and re-run each survivor on the whole suite.
