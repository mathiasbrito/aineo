# 2026-09-25 — T8 health and help

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t8-health` · **Pull request:** into `dev` (number in the PR body's thread)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C5, C7; D1, D3, D13, D14, D15; R3, R4)
- [[Implementation/Waves/00005-health/plan]], its brief `brief-t8-health.md`, its brief review `brief-review.md`, and the evidence `claude-version.txt`, `baseline.txt`
- [[Review/2026-09-24 — v1 MVP readings review]] — MR38 and MR73, left to T8; the readings the help had to match
- [[Sessions/2026-09-25 — T7 entry point]] — the composition root this records in

## Context

**Goal:** T8 — "Health (C7) and `doc/aineo.txt`", the last task before the user's MVP review. C7: "Health: `claude` and its version, the server socket, prefix-mapping conflicts, why autostart did or did not run". The plan's *Done means*: "`:checkhealth aineo` passes; … vimdoc documents every command".

## What was done

**`lua/aineo/health.lua`** — `:checkhealth aineo`, requiring `aineo.config` alone. Six sections:

- *Configuration* — ok, or an error naming the wrong setting (the Lua position stripped), and one warning per unknown key, sorted (MR73).
- *Claude Code* — an error when `claude.cmd`'s first word is not executable, in the Claude home's words (`claude.cmd: '<word>' is not executable`); else `claude.cmd` whole with `--version` appended, as a list through `vim.system()`, killed after 3 s: ok with the first line of its output, or a warning when it cannot start (`vim.system()` raised), runs past the bound (exit 124, or `wait()` returning `nil` when a child holds the pipes), exits non-zero (stderr's first line as advice) or prints nothing. An info line names 2.1.281, the version aineo was measured on. With a wrong configuration: "not checked".
- *Server socket* — `v:servername`, or an error when empty.
- *Prefix mappings* — per key ok (runs `<Plug>(aineo-…)`), a warning naming what a user's global mapping runs (its keys, or a Lua function by its description), or a warning when nothing maps it; a warning when the effective local leader (`maplocalleader`, or `\` when unset or empty) equals the prefix, compared through `nvim_replace_termcodes()`; `prefix = false` is info; "not checked" with a wrong configuration.
- *Autostart* — the record's reason in words (below); "no record" when there is none or it is not aineo's.
- *Limits* — MR38 named, not detected (HB7).

**`plugin/aineo.lua`** (HB5's record only) — `vim.g.aineo_startup = { reason, failure }`. The five conditions of a bare start became one ordered list, each named by its reason (`no-ui`, `file-argument`, `stdin`, `startup-task`, `inside-claude`), so the first that holds is recorded; `start_up()` records `wrong-setting` (and re-raises the same error, which `run()` tells as before), `autostart-off`, or the not-bare reason; the deferred open records `session-restored`, `opened` or `open-failed` with the line the user was told; a late source records `sourced-late`. `run()` now returns whether the action succeeded and the line it told. No module is required and no autocommand added: T1's two pins pass unchanged.

**`doc/aineo.txt`** — every command, `<Plug>` mapping, prefix key and D13 setting with its own tag; the layout, Send (D14 and R4), the report tool and C6's format, the autostart (D3, D15, MR67, MR72, MR76), the health check, and *Limits* (MR38, MR78, R4). Written from the homes' docstrings and the MVP readings, not from the plan's wishes.

**Tests** — `tests/test_health.lua` (40 cases: 7 in interactive editors through T7's `entry_editor`, 33 headless), `tests/test_doc.lua` (35: `:helptags` over a copy under `.tests/`, `:help aineo`, 31 tags, 78 columns, the first line and the modeline). Helpers `tests/helpers/health.lua` (runs the check, reads a section and its advice) and `tests/helpers/health_claude` (a stand-in `claude.cmd` with modes, recording its argv); fixture `tests/fixtures/health/claude_without_interpreter`.

## Decisions & reasoning

- **The record is an editor variable** (brief, HB5; brief review finding 2): a module or an autocommand would break T1's pins, and a key in `vim.g.aineo` would be reported unknown by MR73's own check.
- **The whole `claude.cmd` runs with `--version`**, never the first word alone (brief review finding 1): pinned by the stand-in's recorded argv (`wrapped words --version`).
- **`vim.system()` is wrapped in `pcall`**: an executable file whose interpreter is missing passes `executable()` and makes `vim.system()` raise `ENOENT` (measured with the fixture); unwrapped, the whole check fails.
- **Advice ends on its `:help` tag**: `vim.health` links `:help <word>` up to the next space, so `(:help x)` becomes the broken link `|x)|` (measured).

## Readings for the MVP review

1. **The version bound is 3 s**: `claude.cmd --version` is killed at 3 s; when a child it started holds its output open, `wait()` waits up to 3 s more (6 s in all) and the warning is the same.
2. **Errors** only where aineo cannot work: a wrong setting, a `claude.cmd` that is not executable, an empty `v:servername`. **Warnings**: unknown keys; `--version` that cannot start, runs past the bound, exits non-zero or prints nothing; a prefix key mapped by the user or by nobody; the local leader equal to the prefix (always shown in the user's editor, R3); the autostart's `wrong-setting` and `open-failed`. **Info**: the measured-on version, "not checked" under a wrong configuration, `prefix = false`, every D3 reason, a late load, no record, MR38. "Passes" means no error.
3. **HB5's reasons**, in the code's order: `wrong-setting` (the configuration is resolved first), `autostart-off`, `no-ui`, `file-argument`, `stdin`, `startup-task`, `inside-claude`, then, in the deferred open, `session-restored`, `opened`, `open-failed`; and `sourced-late`. Their health lines are in `AUTOSTART_FINDINGS`.
4. **Between `VimEnter` and the deferred open** (two scheduled callbacks) nothing is recorded yet: a check run there reads "no record".
5. **A record aineo did not write** — not a table, or an unknown reason — reads as "no record".
6. **The version shown** is the first non-blank line of stdout, trimmed; on failure the advice is stderr's first line, none when stderr is blank.
7. **A prefix key counts as aineo's** when its global mapping's `rhs` is `<Plug>(aineo-<subcommand>)` — a user's own mapping to aineo's `<Plug>` reads ok too.
8. **The local-leader check** is equality of the whole prefix with the effective local leader, not overlap (`,` against `,,` is not reported).
9. **The measured-on version line** always shows, 2.1.281, whatever `--version` printed.
10. **Help tags**: `:Aineo-<sub>`, `<Plug>(aineo-<sub>)`, `aineo-\s` … `aineo-\c`, `g:aineo`, `aineo.setup()`, `aineo-config-<setting>`, `g:aineo_startup`, and a tag per section. The install line is `{ 'mathiasbrito/aineo', lazy = false }` (the remote's name).
11. **`run()` in `plugin/aineo.lua` returns its outcome** — whether the action ran and the line told — so the deferred open can record `open-failed`; its callers that ignore it are unchanged.

## Spec conflicts and widenings

- **`plugin/aineo.lua` beyond a one-line record**: the brief allows it "for HB5's record only". The record needed the reason of the refusal, so `is_bare_interactive_start()` became the ordered `NOT_BARE_INTERACTIVE` list, and `run()` returns its outcome for `open-failed`. Both serve the record alone; behaviour is otherwise unchanged (the whole suite green, T7's startup cases included).
- **`.gitignore` does not cover `doc/tags`** (the brief says so): the suites generate tags under `.tests/` only, but a plugin manager that runs `:helptags` in a clone — lazy.nvim does, in `~/Development/Personal/aineo-dev` — leaves an untracked `doc/tags` there. Harmless for `git pull --ff-only`; an `ai/` change if it should be ignored.

## Red, green and mutants

**Seen red, 36** — each for the intended reason, read from the run: the configuration valid (`{}`, no check), wrong (check raised), unknown keys (ok line alone); Claude Code measured-on (`false`), not executable, whole command with `--version`, failing, failing silently (advice present), silent, past 3 s ("printed nothing"), output held (check raised), cannot run (check raised), wrong configuration (check raised); socket ok (`{}`), socket empty (ok with an empty address); prefix in place (`{}`), wrong configuration (raised), a user's mapping (no warning), Lua function with and without a description (first red for the wrong reason — `'\o'` in the Lua chunk is an escape, so nothing was mapped; fixed to `'\\o'`, then red with `runs 'nil'`; these two were written together), unmapped (`{}`), local leader unset (`nil`), `prefix = false` (raised); autostart no record (`{}`), off, headless, wrong setting, late load, opened, open failed, session restored, and the four not-bare rows added one at a time (each "no record"); Limits (`{}`).

**Arrived green, 39** — each killed by an assertion, run:
- local leader empty — the `''` branch was written with the unset case; K1.
- local leader set equal to the prefix — reading `maplocalleader` was forced by the tests that set it to `,`; K2.
- a record aineo did not write — the guard came with the first HB5 unit; A1 (the test sets `42`: with a string, indexing does not raise and the mutant would be equivalent).
- the check starts nothing — green by nature; N1.
- the 35 help tests — the help was written before them: H1–H4, and one tag removal per tag (31, M27 among them).

**Mutants** — each its literal edit, against a copy of `tests/test_health.lua` narrowed to its group under `.tests/` (or `tests/test_doc.lua`, which is one group), all on the final `health.lua`, `plugin/aineo.lua` and `aineo.txt`; every kill an assertion (`Left/Right`):

| id | edit | killed by |
|---|---|---|
| M24 | `check_claude_version(command)` → `vim.health.ok('claude.cmd --version: ' .. program)` | 7 Claude Code cases |
| M25 | `vim.g.aineo_startup = { reason = reason, failure = failure }` → `return` | 11 autostart cases |
| M26 | the unknown-key `vim.health.warn(…)` → `return resolved_config` | unknown keys |
| M27 | the `*:Aineo-send*` line → empty | tag `:Aineo-send` |
| V1 | `vim.list_extend(vim.list_slice(command), { '--version' })` → `{ command[1], '--version' }` | whole command |
| V2 | `VERSION_BOUND_MS = 3000` → `8000` | both past-3 s cases |
| V3 | `result == nil or result.code == TIMED_OUT` → `result.code == TIMED_OUT` | output held |
| V4 | `pcall(vim.system, …)` → `true, vim.system(…)` | cannot run |
| V5 | `if result.code ~= 0 then` → `if false then` | failing, failing silently |
| V6 | `if version == nil then` → `if false then` | silent |
| V7 | `first_line`'s `return nil` → `return ''` | failing silently, silent |
| V8 | `if vim.fn.executable(program) == 0 then` → `if false then` | not executable |
| V9 | the "not checked" info → `return` | Claude Code, wrong configuration |
| C1 | `gsub('^.-%.lua:%d+: ', '')` → `gsub('^$', '')` | wrong value |
| S1 | `if vim.v.servername == '' then` → `if false then` | socket empty |
| K1 | `configured == nil or configured == ''` → `configured == nil` | local leader empty |
| K2 | `typed_keys(local_leader())` → `typed_keys('\\')` | in place, user mapping, local leader set |
| K3 | `elseif mapping.rhs == plug_mapping then` → `elseif true then` | the three user-mapping cases |
| K4 | `if mapping.desc then` → `if false then` | Lua function with a description |
| K5 | `if resolved_config.prefix == false then` → `if false then` | `prefix = false` |
| K6 | the unmapped warning → `return vim.health.info(…)` | unmapped |
| A1 | `type(record) == 'table' and AUTOSTART_FINDINGS[record.reason]` → `AUTOSTART_FINDINGS[record.reason]` | no record, record not aineo's |
| A2 | `reason = 'no-ui',` → `reason = 'file-argument',` | headless |
| A3 | `record_startup('open-failed', failure)` → `record_startup('open-failed')` | open failed |
| A4 | `record_startup('session-restored')` removed | session restored |
| A5 | `record_startup('sourced-late')` removed | late load |
| A6 | `record_startup('wrong-setting')` removed | wrong setting |
| N1 | `require('aineo.claude').session_status()` added first in `M.check()` | starts nothing |
| L1 | `name_limits()` removed | Limits |
| H1 | a second `*aineo-send*` added | `:helptags` error (E154) |
| H2 | `*aineo*` removed from the introduction's heading | `:help aineo` |
| H3 | a line made 79+ columns | 78 columns |
| H4 | the modeline removed | first and last line |
| T-… | each of the 31 `*tag*` removed, one at a time | that tag's case |

No survivor.

## Limits

- The real `claude` never ran — not in a test, not in a probe. `claude.cmd --version` was run only against the stand-in, the no-interpreter fixture, the suites' guard and the fake.
- In an editor running the fake, the Claude Code line is a warning: `--version` runs the fake, which exits 1 over a pipe. The HB5 tests assert the Autostart section only.
- The past-3 s cases take 3 s and 6 s; the stand-in's `holding` mode leaves a `sleep 7` for up to 7 s after its case.

## Open threads

- `.gitignore` and `doc/tags` (above) — the orchestrator's `ai/` call.
- The key ↔ subcommand table (`s o r i c`) is kept twice, in `plugin/aineo.lua` and `lua/aineo/health.lua`, since the composition root exports nothing; a change to one needs the other.

## Task lines

- [X] T8 — Health (C7) and `doc/aineo.txt` — `lua/aineo/health.lua` (configuration with unknown keys, Claude Code and its version, server socket, prefix conflicts with the local leader, the autostart's recorded reason, MR38 named); HB5's record `vim.g.aineo_startup` in `plugin/aineo.lua`; `doc/aineo.txt` with a tag per command, mapping, key and setting. Readings 1–11 above for the MVP review.

## Commits

*Recorded after the merge.*
