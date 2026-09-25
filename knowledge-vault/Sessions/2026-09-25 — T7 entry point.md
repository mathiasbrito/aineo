# 2026-09-25 — T7 entry point

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t7-entry` · **Pull request:** into `dev` (number in the pull request's own page)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C1–C6; D1, D3, D10, D13, D15; R1, R3)
- [[Implementation/Waves/00004-entry/plan]], its brief `brief-t7-entry.md`, its brief review `brief-review.md`, and the evidence `t7-startup-summary.txt`, `t7-summary.txt`
- [[Sessions/2026-09-24 — T3 layout]], [[Sessions/2026-09-24 — T4 Claude session]], [[Sessions/2026-09-24 — T5 report channel]], [[Sessions/2026-09-24 — T6 Send]] — the homes this wires
- [[Sessions/2026-09-23 — T1 tooling foundation]] — the pins this moves, and the stack overflow EP11 fixes

## Context

**Goal:** T7 — "Entry point (C1): prefix mapping, `<Plug>` mappings, `:Aineo`, autostart". The composition root that wires C2–C6 through their entry points into the console the user sees, the autostart under D3 and D15, and the fake's MCP-client mode that proves the wiring end to end (EP9).

## What was done

**`plugin/aineo.lua`** — the composition root the modularity table names. At sourcing it defines `:Aineo {send|open|report|input|claude}` (completing its argument), the five `<Plug>(aineo-…)` Normal-mode mappings, and the augroup `aineo` with a `StdinReadPost` and a once-only `VimEnter` autocommand; it requires no aineo module. At `VimEnter` it resolves the configuration (`aineo.config`, the only module it loads then), maps `<prefix>s|o|r|i|c` to the `<Plug>` mappings where the user has not mapped the key sequence, and, when `autostart` is true and the start is bare and interactive, opens the layout two scheduled callbacks later. Open builds the arrangement: the report home given the clock, `stdpath('state')` and `getcwd()` once; the Report buffer; `start_session()` with `mcp_servers(v:servername, v:progpath)`, the allowed report tool and the report instructions; then `layout.open()` in the same tick. Focus builds the same arrangement and calls `layout.focus()`. Send calls `send.send()` from a plain function mapping. Every action runs under one wrapper that tells the user a raised error once, as an error notification without the Lua position. Sourced after startup (a lazy loader), it maps the prefix in the next scheduled callback and starts nothing.

**`lua/aineo/config/init.lua`** (EP11) — the plain copy tracks the tables on its path and raises `opts: contains itself`; a table reached twice without a cycle is still copied, and a refused `setup()` keeps the earlier record.

**`scripts/minimal_init.lua`** — the guard against the real `claude`: `tests/helpers/entry_guard/` first on `PATH`, whose `claude` runs nothing and exits 127; `AINEO_CHILD` removed; and `vim.g.aineo = { autostart = false }` when nothing set it before the init (see *Spec conflicts and widenings*).

**Tests** — `tests/test_entry.lua` (25 cases: `:Aineo`, Open, focus, Send, the `<Plug>` mappings), `tests/test_entry_prefix.lua` (27: the prefix and its timing), `tests/test_entry_startup.lua` (18: the autostart and the dashboards, in UI-attached editors), `tests/test_entry_report.lua` (3: EP9 end to end), `tests/test_entry_guard.lua` (4: the guard), 4 new cases in `tests/test_aineo.lua`, and `tests/test_plugin.lua`'s pins moved (4 cases, one net new). Helpers `tests/helpers/entry.lua` (a 240×42 child, notifications kept, `vim.g.aineo` naming the fake, the windows read back), `tests/helpers/entry_editor.lua` (the brief review's terminal route: an interactive `nvim` in a terminal job of a mini.test child, queried over its `--listen` address; a request to a blocked editor raises with its screen instead of waiting for ever) and its init `tests/helpers/entry_editor_init.lua`. The fake gains the mode `mcp-client`: it reads `--mcp-config`, starts the server entry it names with its command, arguments and environment, replays `tests/fixtures/mcp/claude-code-2.1.281.jsonl` (initialize, initialized, tools/list, the report call), records each answer and exits. Fixtures: `tests/fixtures/entry/dashboard/plugin/entry_dashboard.lua` (the stand-in dashboard, its sources cited in its header) and `tests/fixtures/entry/session.vim`.

## Decisions & reasoning

- **When the prefix is mapped (EP3).** lazy.nvim v11.17.5 (`lua/lazy/core/loader.lua`, `M._load`, read raw at commit `85c7ff3`) adds the plugin to `'runtimepath'`, sources its `plugin/` (`M.packadd`, l.359) and only then runs `config`/`setup(opts)` (`M.config`, l.362); for `lazy = false` all of it runs inside `require('lazy').setup()` in the user's init, before `VimEnter`. So the prefix is mapped at `VimEnter` from the configuration as it stands then; a file sourced after startup maps in the next scheduled callback, after the loader's `setup()` in the same tick. Pinned by `setup()` given through `-c` (which runs before `VimEnter`, measured) and by sourcing late then calling `setup()`.
- **Bare and interactive (EP7, D3).** Measured on Neovim 0.11.6 in the terminal route: at `VimEnter` the server's `v:argv` is `nvim --embed` followed by the user's arguments; `-c` and `+` commands have already run; `StdinReadPost` fired first for piped input. The check: a UI attached, `argc()` 0, no `StdinReadPost`, no `-c`, `-S` or `+…` in `v:argv`, no `$AINEO_CHILD`.
- **Dashboards (EP8, D15).** Read raw at cited versions: snacks.nvim v2.31.0 (`e6fd58c`) opens its dashboard at `UIEnter` (`lua/snacks/init.lua`'s events table; `lua/snacks/dashboard.lua`, `M.setup()`), in buffer 1, under `eventignore=all`; alpha-nvim `4ba26e4` at `VimEnter` (nested), in the current buffer, under `eventignore=all` with its `noautocmd` option; dashboard-nvim `f787e34` at `UIEnter`, in a new buffer unless the current one is empty (and, without `setup()`, loads its theme from a cache file asynchronously); mini.starter at the pin at `VimEnter` under `noautocmd`. The open runs two scheduled callbacks after `VimEnter`, after all of those, and the layout replaces the dashboard's window; nothing detects a dashboard.
- **The guard against the real `claude`** is a `PATH` stub rather than a suite-wide `claude.cmd`, so the configuration suites keep reading the real defaults.

## Readings for the MVP review

1. **EP1's message** — `aineo: :Aineo takes one of send, open, report, input, claude`, one `vim.notify` at `ERROR`, for no argument and for any other; `:Aineo send extra` reads as the one argument `send extra` (`nargs = '?'`) and gets the same message. Completion offers the subcommands that begin with what is typed.
2. **EP4's error messages** — every error an action raises (a wrong setting, `start_session()`'s, Send's own raised errors) reaches the user once as `aineo: <the error without its Lua position>`, at `ERROR`: `aineo: layout.report_height: expected a number strictly between 0 and 1, got 2`. Nothing opens. Send's refusals stay its own warnings.
3. **The report environment is given once**, at the first Open or focus: the Report keeps the working directory of that moment for the editor's life, while each new session runs in `getcwd()` as it then is. The state directory is `stdpath('state')` itself; the records land under `<state>/aineo/reports/`.
4. **EP5 starts a session when a focus finds none** — before the first start and after an exit, `\r`, `\i` and `\c` start Claude as `\o` does (R1 applies to them too).
5. **EP7's unnamed starts** — `-c`, `+command` and `-S` (a restored session) refuse the autostart: any argument equal to `-c` or `-S`, or beginning with `+`, counts, also as another option's value (`--cmd +x`); `--cmd` alone does not refuse. `-t tag` and `-q file` do not refuse; their file should become the layout's file column, as `layout.open()`'s docstring says of a file the current window shows — inferred, not measured. An empty `$AINEO_CHILD` counts as unset: `vim.env` read an empty variable handed through `jobstart()` as nil (measured in this packet's startup probe, Neovim 0.11.6).
6. **A wrong setting at startup** — one error notification, no prefix mapping, no autostart.
7. **EP8's moments** — the open waits two scheduled callbacks after `VimEnter`: it follows what `VimEnter` or `UIEnter` autocommands show directly or from one `vim.schedule()` — pinned for each moment with and without autocommands, with autocommands registered after aineo's, and with the real mini.starter registered before. Not covered: a dashboard shown from a timer (`vim.defer_fn`), from two nested schedules, or on a later event; dashboard-nvim's asynchronous theme load without `setup()` (it renders into a buffer the layout has hidden — not measured); a floating dashboard, which the layout keeps (none of the four opens a float at startup, by their sources).
8. **What EP10 lets load** — sourcing loads no aineo module; `VimEnter` loads `aineo.config` alone (a headless start loads exactly that); a late source loads it in the next scheduled callback.
9. **EP3's "mapped already"** — `maparg(keys, 'n') ~= ''` at `VimEnter`: a global mapping, or a buffer-local one in the current buffer; a mapping that only overlaps ours (`\` alone, `\sa`) does not count (C7 reports conflicts, T8); a mapping the user makes after `VimEnter` replaces ours; `setup()` after `VimEnter` remaps nothing; `prefix = ''`, which the configuration accepts, maps `s`, `o`, `r`, `i` and `c` themselves.
10. **A late source never autostarts** — a lazy loader that sources aineo after `VimEnter` gets the prefix, not the autostart, since `StdinReadPost` passed unseen.
11. **Unknown keys are silent at Open**, left to T8's health check.
12. **The suites' default `vim.g.aineo = { autostart = false }`** — every interactive Neovim a suite starts is a bare start; a test of the autostart sets `vim.g.aineo` before the init.
13. **The guard's `claude` exits 127** with a line on stderr.

## Spec conflicts and widenings

- **`scripts/minimal_init.lua` gained a third line beyond the brief's two points** (the guard and `AINEO_CHILD`): the default `autostart = false`. Without it, T5's interactive test editors (`tests/helpers/report_tui.lua`) became bare starts that autostarted, took the Report with `stdpath('state')`, and failed `tests/test_mcp_blocked_editor.lua` (measured: 2 fails in the full run before the line — that suite and the moved T1 pin). T5's helper is outside the packet; the alternative, `autostart = false` in that helper, is the orchestrator's to choose.
- **The root `CLAUDE.md`** lists what `make test` isolates; it does not mention the `PATH` guard, the `AINEO_CHILD` removal or the autostart default. `CLAUDE.md` is not this packet's — a follow-up for an `ai/` pass.
- **`tests/helpers/entry_guard/claude`** is a file inside a new directory whose name begins with `entry`.

## Limits

- lazy.nvim, snacks.nvim, alpha-nvim and dashboard-nvim were read, not run; the stand-ins model them. mini.starter is the real one.
- A full run of the suite leaves nothing behind; one run before the autostart default (`t7-full-3`) left a file `v:null` in the checkout's root, written by `tests/test_mcp_blocked_editor.lua` when its records file was missing — removed; not a T7 artefact once the default is in.
- The real `claude` never ran.

## Red, green and mutants

The unit list, in order: G the guard (the `claude` first on `PATH`, `AINEO_CHILD` removed); EP11; EP1 the command (usage, completion); EP4 Open (the layout, the settings handed to the session, a wrong setting, unknown keys, again, after an exit); EP5 focus; EP6 Send; EP2 the `<Plug>` mappings; EP3 the prefix (default, `vim.g.aineo`, `setup()`, `false`, the user's mapping, a wrong setting, a late source); EP10 the moved pins; EP7 the autostart and each refusal; EP8 the dashboards; EP9 end to end; the suites' autostart default.

**Seen red — 39 cases**, each for the missing behaviour:
- the guard (written together, red together — a deviation from one-at-a-time, recorded): *run the guard as claude* (`Left: ~/.local/bin/claude`), *… in a child whose PATH starts with another claude* (`Left:` the fixture's `claude`), *remove AINEO_CHILD from a child* (`Left: "1" Right: vim.NIL`);
- *refuses options that contain themselves, naming them* — `stack overflow`;
- *`:Aineo` without an argument …* — `E492: Not an editor command: Aineo`; *completes its argument to its five subcommands* — `Left: {}`;
- *`:Aineo open` starts Claude in the layout …* — `Left: { "" }`; *with a wrong setting tells the user once …* — the raw Lua callback error;
- *`:Aineo report, input and claude` move the cursor …* ×3 — `Left: ""` (the first arrange left the cursor in Input, so the input case was not red; the arrange was changed to a new tab and all three were seen red);
- *`:Aineo send` sends Input's text* — `Left: ""`; *`<Plug>(aineo-open)` starts Claude …* — `Left: { "" }`;
- *the prefix is `\` by default* ×5 — `Left: ""`; *is the one setup() records right after the file is sourced late* ×5 — `Left: false`;
- *a bare interactive start opens the layout around a new Claude* — `Left: { "" }`; the refusals *headless*, *file*, *piped-stdin*, *in-aineos-claude*, *command*, *plus-command*, *session* — each `Left: 1 Right: 0`, each red before its condition was written;
- *sourced after a bare interactive start maps the prefix and starts no Claude* — `Left: 1`;
- *a startup dashboard gives way …* ×6 — `Left: 1` (the dashboard's filetype on screen) or the Input window showing the dashboard's buffer;
- *start aineo in no interactive editor whose test left vim.g.aineo unset* — `Left: { "terminal", "aineo://report", "aineo://input" }`.

**Arrived green — 45 cases** (42 new, and T1's three pins as moved: one rewritten, one replaced, one new), each pinning code written ahead of it or behaviour of the homes, with its killer (table below): the three companion EP11 cases (C1, C2, C3); *completes the subcommands that begin with what is typed* (E-complete); *with another argument …* (E-usage-level); Open's *report server* (M21-open), *tools* (E-tools), *instructions* (E-instructions), *working directory* (E-cwd), *unknown key* (E-unknown-warns), *again while Claude runs* (E-no-restore), *after Claude has exited* (E-cached-arrangement); focus *opens the layout … when it is closed* ×3 (E-focus-needs-layout); the `<Plug>` focus cases ×3 (E-plug-focus); `<Plug>(aineo-send)` (E-plug-expr, E-send-unwired); the prefix from `vim.g.aineo` ×5 and from `setup()` ×5 (P1, P2), `false` ×5 (P3), the user's mapping (M20), a wrong setting at startup (P5); T1's moved pins (TP1, TP2, TP3); *autostart-off* (ST-autostart); mini.starter ×2 (M23, ST-autostart); EP9 *shows its report* (M21, F1), *keeps … under the state directory* (E-state-dir, E-report-cwd), *stamps … local time* (E-clock).

**Mutant table** — literal edits in `t7-mutants.py` (the orchestrating session's scratchpad), one at a time, each file restored byte for byte from the pristine copy, each run as `make test_file` on a copy of its test file narrowed to the named groups under `.tests/t7-narrow/`; the kind read from mini.test's output ("Failed expectation" is an assertion). Run on the code head `5e2d6c4`, after the last edit to any file a mutant or its tests touch.

| # | File | Edit (old → new, `⏎` a line break) | Narrowed to | Result |
|---|---|---|---|---|
| M19 | `plugin/aineo.lua` | `return #vim.api.nvim_list_uis() > 0⏎` → `return true⏎` | `tests/test_entry_startup.lua` › a start that is not bare and interactive (8 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| ST-file | `plugin/aineo.lua` | `and vim.fn.argc() == 0⏎` → *(removed)* | `tests/test_entry_startup.lua` › a start that is not bare and interactive (8 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| ST-stdin | `plugin/aineo.lua` | `and not read_stdin⏎` → *(removed)* | `tests/test_entry_startup.lua` › a start that is not bare and interactive (8 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| M22 | `plugin/aineo.lua` | `and vim.env.AINEO_CHILD == nil⏎` → *(removed)* | `tests/test_entry_startup.lua` › a start that is not bare and interactive (8 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| ST-autostart | `plugin/aineo.lua` | `if config.autostart and is_bare_interactive_start() then` → `if is_bare_interactive_start() then` | `tests/test_entry_startup.lua` › a start that is not bare and interactive, mini.starter (10 cases) | killed: 2 failing, 2 by assertion, 0 otherwise |
| ST-c | `plugin/aineo.lua` | `argument == '-c' or` → *(removed)* | `tests/test_entry_startup.lua` › a start that is not bare and interactive (8 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| ST-S | `plugin/aineo.lua` | `argument == '-S' or` → *(removed)* | `tests/test_entry_startup.lua` › a start that is not bare and interactive (8 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| ST-plus | `plugin/aineo.lua` | `or vim.startswith(argument, '+')` → *(removed)* | `tests/test_entry_startup.lua` › a start that is not bare and interactive (8 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| M23 | `plugin/aineo.lua` | `vim.schedule(function()⏎ run(open)⏎ end)` → `vim.schedule(function()⏎ if not vim.tbl_contains({ 'snacks_dashboard', 'alpha', 'dashboard', 'ministarter' }, vim.bo.filetype) then⏎ run(open)⏎ end⏎ end)` | `tests/test_entry_startup.lua` › a startup dashboard, mini.starter (8 cases) | killed: 7 failing, 7 by assertion, 0 otherwise |
| D-one-schedule | `plugin/aineo.lua` | `vim.schedule(function()⏎ vim.schedule(function()⏎ run(open)⏎ end)⏎ end)` → `vim.schedule(function()⏎ run(open)⏎ end)` | `tests/test_entry_startup.lua` › a startup dashboard, mini.starter (8 cases) | killed: 2 failing, 2 by assertion, 0 otherwise |
| D-no-schedule | `plugin/aineo.lua` | `open_after_dashboards()⏎` → `run(open)⏎` | `tests/test_entry_startup.lua` › a startup dashboard, mini.starter (8 cases) | killed: 6 failing, 6 by assertion, 0 otherwise |
| L-autostarts | `plugin/aineo.lua` | `run(function()⏎ map_prefix(resolved_config().prefix)⏎ end)` → `run(start_up)` | `tests/test_entry_startup.lua` › sourced after a bare interactive start (1 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| L-unscheduled | `plugin/aineo.lua` | `vim.schedule(function()⏎ run(function()⏎ map_prefix(resolved_config().prefix)⏎ end)⏎ end)` → `run(function()⏎ map_prefix(resolved_config().prefix)⏎ end)` | `tests/test_entry_prefix.lua` › the prefix (25 cases) | killed: 5 failing, 5 by assertion, 0 otherwise |
| P1 | `plugin/aineo.lua` | `map_prefix(config.prefix)⏎` → `map_prefix('\\')⏎` | `tests/test_entry_prefix.lua` › the prefix (25 cases) | killed: 15 failing, 15 by assertion, 0 otherwise |
| P2 | `plugin/aineo.lua` | `vim.api.nvim_create_autocmd('VimEnter', {` → `run(start_up)⏎ vim.api.nvim_create_autocmd('User', {` | `tests/test_entry_prefix.lua` › the prefix (25 cases) | killed: 5 failing, 5 by assertion, 0 otherwise |
| P3 | `plugin/aineo.lua` | `if prefix == false then⏎ return⏎ end⏎` → *(removed)* | `tests/test_entry_prefix.lua` › the prefix (25 cases) | killed: 5 failing, 5 by assertion, 0 otherwise |
| M20 | `plugin/aineo.lua` | `if vim.fn.maparg(keys, 'n') == '' then` → `if true then` | `tests/test_entry_prefix.lua` › the user's own mapping (1 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| P5 | `plugin/aineo.lua` | `callback = function()⏎ run(start_up)⏎ end,` → `callback = function()⏎ start_up()⏎ end,` | `tests/test_entry_prefix.lua` › a wrong setting at startup (1 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-position | `plugin/aineo.lua` | `return (message:gsub('^.-%.lua:%d+: ', ''))` → `return message` | `tests/test_entry.lua` › :Aineo open (9 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-pcall | `plugin/aineo.lua` | `local succeeded, failure = pcall(action)` → `local succeeded, failure = true, action()` | `tests/test_entry.lua` › :Aineo open (9 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-usage-level | `plugin/aineo.lua` | `vim.notify(USAGE, vim.log.levels.ERROR)` → `vim.notify(USAGE, vim.log.levels.WARN)` | `tests/test_entry.lua` › :Aineo (4 cases) | killed: 2 failing, 2 by assertion, 0 otherwise |
| E-complete | `plugin/aineo.lua` | `return vim.startswith(subcommand, argument_lead)` → `return true` | `tests/test_entry.lua` › :Aineo (4 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-unknown-warns | `plugin/aineo.lua` | `return (config.resolve_config(vim.g.aineo, config.recorded_setup_options()))` → `local resolved, unknown = config.resolve_config(vim.g.aineo, config.recorded_setup_options())⏎ if #unknown > 0 then⏎ vim.notify('aineo: unknown ' .. table.concat(unknown, ', '), vim.log.levels.WARN)⏎ end⏎ return resolved` | `tests/test_entry.lua` › :Aineo open (9 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| M21 | `plugin/aineo.lua` | `mcp.mcp_servers(vim.v.servername, vim.v.progpath)` → `mcp.mcp_servers('', vim.v.progpath)` | `tests/test_entry_report.lua` › the report tool (3 cases) | killed: 3 failing, 3 by assertion, 0 otherwise |
| M21-open | `plugin/aineo.lua` | `mcp.mcp_servers(vim.v.servername, vim.v.progpath)` → `mcp.mcp_servers('', vim.v.progpath)` | `tests/test_entry.lua` › :Aineo open (9 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-tools | `plugin/aineo.lua` | `allowed_tools = mcp.allowed_mcp_tools(),` → `allowed_tools = {},` | `tests/test_entry.lua` › :Aineo open (9 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-instructions | `plugin/aineo.lua` | `instructions = report.report_instructions(mcp.report_tool_name()),` → `instructions = '',` | `tests/test_entry.lua` › :Aineo open (9 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-cwd | `plugin/aineo.lua` | `cwd = vim.fn.getcwd(),` → `cwd = vim.uv.os_tmpdir(),` | `tests/test_entry.lua` › :Aineo open (9 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-cached-arrangement | `plugin/aineo.lua` | `local function open()⏎ require('aineo.layout').open(arrangement(resolved_config()))⏎end` → `local cached_arrangement⏎local function open()⏎ cached_arrangement = cached_arrangement or arrangement(resolved_config())⏎ require('aineo.layout').open(cached_arrangement)⏎end` | `tests/test_entry.lua` › :Aineo open (9 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-focus-role | `plugin/aineo.lua` | `focus('report')` → `focus('input')` | `tests/test_entry.lua` › :Aineo report, input and claude (6 cases) | killed: 2 failing, 2 by assertion, 0 otherwise |
| E-focus-needs-layout | `plugin/aineo.lua` | `local function focus(role)⏎` → `local function focus(role)⏎ if require('aineo.layout').input_buffer() == nil then⏎ return⏎ end⏎` | `tests/test_entry.lua` › :Aineo report, input and claude (6 cases) | killed: 3 failing, 3 by assertion, 0 otherwise |
| E-send-unwired | `plugin/aineo.lua` | `require('aineo.send').send()⏎` → *(removed)* | `tests/test_entry.lua` › :Aineo send, <Plug>(aineo-send) (2 cases) | killed: 2 failing, 2 by assertion, 0 otherwise |
| E-plug-expr | `plugin/aineo.lua` | `end, { desc = 'aineo: ' .. subcommand })⏎end⏎⏎--- The key` → `end, { desc = 'aineo: ' .. subcommand, expr = true })⏎end⏎⏎--- The key` | `tests/test_entry.lua` › <Plug>(aineo-send) (1 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-plug-missing | `plugin/aineo.lua` | `for _, subcommand in ipairs(SUBCOMMANDS) do⏎ vim.keymap.set('n', plug_mapping(subcommand)` → `for _, subcommand in ipairs({ 'send', 'report', 'input', 'claude' }) do⏎ vim.keymap.set('n', plug_mapping(subcommand)` | `tests/test_entry.lua` › <Plug>(aineo-open) (1 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-state-dir | `plugin/aineo.lua` | `state_directory = vim.fn.stdpath('state'),` → `state_directory = vim.fn.stdpath('cache'),` | `tests/test_entry_report.lua` › the report tool (3 cases) | killed: 2 failing, 2 by assertion, 0 otherwise |
| E-report-cwd | `plugin/aineo.lua` | `working_directory = vim.fn.getcwd(),` → `working_directory = '/',` | `tests/test_entry_report.lua` › the report tool (3 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-clock | `plugin/aineo.lua` | `return os.date('%Y-%m-%dT%H:%M:%S')` → `return '2000-01-01T00:00:00'` | `tests/test_entry_report.lua` › the report tool (3 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| TP1 | `plugin/aineo.lua` | `vim.g.loaded_aineo = true⏎` → `vim.g.loaded_aineo = true⏎require('aineo.config')⏎` | `tests/test_plugin.lua` › plugin/aineo.lua (4 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| TP2 | `plugin/aineo.lua` | `local config = resolved_config()⏎ map_prefix(config.prefix)⏎` → `local config = resolved_config()⏎ require('aineo.layout')⏎ map_prefix(config.prefix)⏎` | `tests/test_plugin.lua` › plugin/aineo.lua (4 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| C1 | `lua/aineo/config/init.lua` | `copy[plain_copy(key, enclosing)] = plain_copy(inner_value, enclosing)` → `copy[plain_copy(key)] = plain_copy(inner_value, enclosing)` | `tests/test_aineo.lua` › setup() (13 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| C2 | `lua/aineo/config/init.lua` | `enclosing[value] = nil⏎` → *(removed)* | `tests/test_aineo.lua` › setup() (13 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| C3 | `lua/aineo/config/init.lua` | `recorded_setup_options = plain_copy(setup_options)` → `recorded_setup_options = {}⏎ recorded_setup_options = plain_copy(setup_options)` | `tests/test_aineo.lua` › setup() (13 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| C4 | `lua/aineo/config/init.lua` | `error('opts: contains itself', 0)` → `error('contains itself', 0)` | `tests/test_aineo.lua` › setup() (13 cases) | killed: 2 failing, 2 by assertion, 0 otherwise |
| G1 | `scripts/minimal_init.lua` | `vim.env.PATH = vim.fs.joinpath(checkout, 'tests', 'helpers', 'entry_guard') .. ':' .. vim.env.PATH⏎` → *(removed)* | `tests/test_entry_guard.lua` › the suites (4 cases) | killed: 2 failing, 2 by assertion, 0 otherwise |
| G2 | `scripts/minimal_init.lua` | `vim.env.PATH = vim.fs.joinpath(checkout, 'tests', 'helpers', 'entry_guard') .. ':' .. vim.env.PATH` → `vim.env.PATH = vim.env.PATH .. ':' .. vim.fs.joinpath(checkout, 'tests', 'helpers', 'entry_guard')` | `tests/test_entry_guard.lua` › the suites (4 cases) | killed: 2 failing, 2 by assertion, 0 otherwise |
| G3 | `scripts/minimal_init.lua` | `⏎vim.env.AINEO_CHILD = nil⏎` → `⏎` | `tests/test_entry_guard.lua` › the suites (4 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-no-restore | `plugin/aineo.lua` | `local function open()⏎` → `local function open()⏎ if require('aineo.claude').session_status() == 'starting' or require('aineo.claude').session_status() == 'ready' then⏎ return⏎ end⏎` | `tests/test_entry.lua` › :Aineo open (9 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| E-plug-focus | `plugin/aineo.lua` | `run(ACTIONS[subcommand])` → `run(ACTIONS.send)` | `tests/test_entry.lua` › <Plug>(aineo-report), (aineo-input) and (aineo-claude) (3 cases) | killed: 3 failing, 3 by assertion, 0 otherwise |
| TP3 | `plugin/aineo.lua` | `for _, subcommand in ipairs(SUBCOMMANDS) do⏎ vim.keymap.set('n', plug_mapping(subcommand)` → `for _, subcommand in ipairs({ 'send', 'report', 'input', 'claude' }) do⏎ vim.keymap.set('n', plug_mapping(subcommand)` | `tests/test_plugin.lua` › plugin/aineo.lua (4 cases) | killed: 1 failing, 1 by assertion, 0 otherwise |
| F1 | `tests/helpers/fake_claude.lua` | `['mcp-client'] = { screens = { STARTUP }, calls_report_tool = true },` → `['mcp-client'] = { screens = { STARTUP } },` | `tests/test_entry_report.lua` › the report tool (3 cases) | killed: 3 failing, 3 by assertion, 0 otherwise |

**Tally:** 50 mutants, 50 killed by an assertion, no crash, no survivor. The brief's M19–M23 are rows M19, M20, M21 (and M21-open), M22 and M23; M19 was run narrowed, with the `PATH` guard in place. In an earlier pass on `6476e44`, `E-pcall` and `C2` were killed by a crash and `E-clock` survived; the fourth commit made the first two assertions and pinned the clock, and the three were killed by assertion on the final head (rows above).

**Suites on the head `5e2d6c4`:** `make test` 573 cases, `Fails (0)`, exit 0, 03:33:43–03:40:48 CEST (425 s) — the baseline's 491 plus 82; `make lint` clean (StyLua check, selene 0 errors, 0 warnings); the modularity deep-require check prints only intra-home lines (`lua/aineo/{claude,layout,mcp,report}/…`), none from `plugin/`, `tests/` or `scripts/`.

## Task lines

- [X] T7 — Entry point (C1): prefix mapping, `<Plug>` mappings, `:Aineo`, autostart — the composition root in `plugin/aineo.lua`; prefix at `VimEnter` (lazy.nvim read at v11.17.5); autostart under D3 with `-c`, `+`, `-S` refused (reading 5); dashboards given way to two scheduled callbacks after `VimEnter` (D15); the fake's `mcp-client` mode; the suites' `PATH` guard, `AINEO_CHILD` removal and autostart default. Open: `CLAUDE.md`'s isolation paragraph (an `ai/` pass); T5's TUI helper versus the suites' autostart default.

## Commits

*Recorded after the merge.*
