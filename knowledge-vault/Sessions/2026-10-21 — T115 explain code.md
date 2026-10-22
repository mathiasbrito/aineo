# 2026-10-21 — T115 explain code

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t115-explain` · **Pull request:** into `dev`

A regular packet of wave 21 (D26: the whole suite once before the push). aineo asks a Claude of its own, started for one request and never kept, to explain the code of the current file or of the selected lines, and shows each explanation as virtual lines above the line it explains (D103, A544). The work resumed a draft that an earlier agent left uncommitted when the computer restarted; the draft was read against A544 in full, kept where it was right, and every unit had its test seen failing again (below).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D103, A544 (inside D103's row), T115; C1, C3, D26, D29
- `lua/aineo/explain/` (new: `init.lua`, `request.lua`, `answer.lua`, `marks.lua`), `lua/aineo/entry/explaining.lua` (new), `plugin/aineo.lua`, `lua/aineo/config/init.lua`, `lua/aineo/health.lua`
- `doc/aineo.txt` — `aineo-explain`, `:AineoExplain`, `<Plug>(aineo-explain)`, `<Plug>(aineo-explain-tools)`, `aineo-\v`, `aineo-\V`, `aineo-config-explain.model`, `aineo-config-explain.timeout_ms`, `hl-AineoExplain`; `README.md`
- `tests/test_explain.lua`, `tests/test_entry_explain.lua` (new); `test_config.lua`, `test_plugin.lua`, `test_health.lua`, `test_doc.lua`; `tests/helpers/fake_claude.lua` (print mode)

## Task lines

- [X] T115 Explain code (C1, C3; D103, A544): a new home `aineo.explain` behind one entry point, requiring no other home (`request` builds the argv and the prompt, `answer` reads the result, `marks` places the virtual lines, the entry runs one `claude` process per buffer in the file's git top level and stops it at `explain.timeout_ms`, on a second request, on `clear()` and at `VimLeavePre`, and drops an answer for a buffer that changed); `aineo.entry`'s `explaining` module (the file check, the configuration at call time, the Visual range); `plugin/aineo.lua` maps `<Plug>(aineo-explain)` and `<Plug>(aineo-explain-tools)` and `\v`/`\V` in Normal and Visual mode and defines `:AineoExplain [tools|clear]` with a range; `explain.model` and `explain.timeout_ms` in `aineo.config`; the health check's prefix keys and an Explain code section; the fake `claude`'s print mode (synthetic answers); the help, the README and `AineoExplain` — done, PR to follow

## What was done

- **The home.** `request.arguments()` builds the argv A544 lists, nothing else: `-p --output-format json --json-schema <schema> --no-session-persistence --strict-mcp-config --model <model> --tools ""` for `\v`, `--tools Read,Grep,Glob --allowedTools Read,Grep,Glob` for `\V`. `request.prompt()` gives the relative path, the 'filetype', the range and every line of the buffer numbered (right-aligned), unsaved text included. `answer.explanations_in()` reads `structured_output`, else `result` as JSON, and keeps one explanation per line in the range. `marks` places them as `virt_lines_above` in `aineo_explain` (indent as the line, `┊ ` prefix, wrapped by display width at the window's text width, `invalidate`), and the `┊ explaining…` line while a request runs. The home's entry runs one process per buffer with `vim.system` (list argv, the prompt on stdin, `cwd` the git top level or the file's folder).
- **The entry.** `aineo.entry.explaining` refuses a buffer that holds no file (aineo's own panes), reads the configuration at call time, and for Visual mode reads `line('v')` and `line('.')` before leaving Visual mode.
- **The maps and the command.** `plugin/aineo.lua`: the two `<Plug>` mappings in Normal and Visual mode, `\v`/`\V` through `map_unless_mapped`, and `:AineoExplain [tools|clear]` with a range and completion. The health check lists the four keys (no Terminal or Insert twin) and has an Explain code section.
- **The fake.** `tests/helpers/fake_claude.lua` answers `claude -p …`: it records its argv and its stdin, optionally waits (so the cancel and timeout cases can stop it), and prints a file's contents or fails with a code. Its answers are synthetic, shaped as the headless documentation of Claude Code 2.1.306 describes `--output-format json` with `--json-schema`; no real run was recorded.

## Decisions

- A544 built as written. Where it was silent: any `\v`/`\V` press while a request runs for the buffer cancels it, in Visual mode too; `:AineoExplain` takes one optional word, `tools` or `clear` (Neovim refuses a second argument), the brief's `[tools] [clear]` read as two alternatives, not a combination.
- The commit-count validator of `changes.graph_limit` became `is_positive_count`, shared by `explain.timeout_ms`.
- Commit trailers follow the session's own attribution reminder (this agent's model), not the model named in the brief.

## What was seen red

The draft's tests existed before the code was re-examined; each unit's red step was redone by breaking the code for a moment and running the unit's file (mutants below), and `test_doc` was seen red on its own before the help existed (11 cases, `No help for aineo-explain` and the like), then green once the help was written. Each case the mutants below kill was seen failing for the intended reason — the assertion named the behaviour — with the code that makes it pass restored afterwards.

## Mutants

Applied to the committed file, run on the test file named, restored (none left). `request.lua` is `R`, `init.lua` of the home `I`, `answer.lua` `A`, `marks.lua` `M`, `explaining.lua` `E`, `plugin/aineo.lua` `P`.

| Edit | Run on | Killed by |
|---|---|---|
| R1 `\v` passes tools: `if tools then` → `if not tools then` | `test_explain` | assertion, 2 cases (argv of `\v`, argv of `\V`) |
| R2 an MCP config reaches argv: `--mcp-config {}` added after `--strict-mcp-config` | `test_explain` | assertion, 2 cases |
| I1 a changed buffer still shown: the `b:changedtick` check replaced by `false` | `test_explain` | assertion, 1 case (a change to the buffer has the answer dropped) |
| I2 the Visual range ignored: `explaining.range or {1, #lines}` → `{1, #lines}` | `test_explain` | assertion, 4 cases |
| E1 the Visual range ignored at the entry: `range = …` dropped from `explain_selection()` | `test_entry_explain` | assertion, 2 cases |
| P1 `\v` passes tools at the map: `explain = { tools = false }` → `true` | `test_entry_explain` | assertion, 2 cases |
| I3 toggle removed | `test_explain` | assertion, 1 case |
| I4 cancel removed | `test_explain` | assertion, 1 case |
| I5 timeout ignored | `test_explain` | assertion, 1 case |
| I6 no stop at `VimLeavePre` | `test_explain` | assertion, 1 case |
| I7 non-zero exit ignored | `test_explain` | assertion, 1 case |
| I8 `cwd` not passed | `test_explain` | assertion, 2 cases |
| R3 numbering dropped from the prompt | `test_explain` | assertion, 2 cases |
| A1 no dedupe | `test_explain` | assertion, 1 case |
| A2 `result` text not read | `test_explain` | assertion, 1 case |
| A3 `is_error` ignored | `test_explain` | assertion, 1 case |
| M1 no wrapping | `test_explain` | assertion, 4 cases |
| M2 no indent | `test_explain` | assertion, 6 cases |
| M3 no `invalidate` | `test_explain` | assertion, 1 case |
| C1 default model `opus`; C2 validator accepts anything; C3 default timeout 18000 | `test_config` | assertion, 6, 4 and 6 cases |
| H1 health section dropped | `test_health` | assertion, 1 case |
| P2 `V` key not mapped | `test_plugin` | assertion, 1 case |
| P3 command ignores `tools`; P4 ignores the range; E2 `clear` does nothing; E3 file check removed; P5 unknown word accepted | `test_entry_explain` | assertion, 1 case each |

## Runs

Files run one at a time while working: `test_explain` 37 cases, `test_entry_explain` 10, `test_config` 25, `test_plugin` 5, `test_health` 24, `test_doc` 93 (the help written after its tags were seen failing: 11 cases red): green. `make lint` clean (StyLua, selene: 0 errors, 0 warnings). The deep-`require` check prints only the explain home's and `aineo.entry`'s own files.

The whole suite once, on the tree pushed, on Neovim 0.12.5 on the host (D26, D29): `make test` printed `Total number of cases: 5704`, `Total number of groups: 157` and `Fails (1) and Notes (0)`. The one failure is `test_entry_panes | :Aineo pane | completes after a command modifier or a range as it does without one` with the argument `silent! Ain pane a`: see the spec conflict below. No load flake failed.

## Open threads

- **Spec conflict, not chosen.** A544 names the command `:AineoExplain`. A second user command beginning with `Aineo` makes Neovim refuse the abbreviations `:Ain` and `:Aine` of `:Aineo` with E464 (ambiguous use of a user-defined command), measured in a headless Neovim 0.12.5 with the plugin loaded; the existing case `silent! Ain pane a` of `test_entry_panes` pins that `:Ain` abbreviates `:Aineo`, and fails for it. The code follows A544 and the case is left as it was. The ways out are the orchestrator's: keep the name and accept that `:Aineo` has no abbreviation left (the case then types `Aineo`), give the command another name that does not begin with `Aineo` (`:ExplainCode`), or take the explanation as a subcommand, `:Aineo explain [tools|clear]`, which needs a range on `:Aineo`.
- No real `claude -p --output-format json --json-schema` run was recorded: the fake's answers are synthetic, shaped from the documentation of 2.1.306. A contract run that records one is the user's to start (the suite never runs the real Claude).
- The health check does not check a version floor for the flags this uses (`--json-schema`, `--no-session-persistence`, `--tools`), as none is measured.
- The `modularity` skill's table of homes does not list `explain`; `aineo.entry` requiring its entry point is an edge that table already allows. Adding the row is an `ai/` change, not part of this packet.
- **Commits** — recorded after the merge.
