# 2026-10-19 — T97 README run tools and zoom

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t97-readme-tools-zoom` · **Pull request:** into `dev` (number recorded after the merge)

The README's section on what Claude tells aineo gains the run tools, its Global key table gains `\z` with a short paragraph on the zoom, and the help's install section gains the release-tag sentences and its layout section the file column and the four panes. Docs only.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — A504 (the orchestrator's record of the ruling)
- `README.md`
- `doc/aineo.txt` — *aineo-install*, *aineo-layout*; ground truth *aineo-run-tools*, *aineo-zoom*
- `lua/aineo/mcp/run_tools.lua`, `plugin/aineo.lua`

## Task lines

- [X] T97 README run tools and zoom (A504): README "What Claude tells aineo" lists `run`, `run_output` and `run_stop` (`run` and `run_stop` for an explicit request only, asked on every call even in auto and bypass modes, denied in `dontAsk`; `run_output` needs no approval, reads `\x` and `run` processes and never the `\X` shells, filters by Vim regex with the six fields, 2-second matching bound); `\z` in the Global table with a paragraph; the help's lazy.nvim spec has `version = '*'` with the README's three sentences; the help's layout diagram shows the file column and the right column's four panes with their keys.

## Verified against the code and the help

- **The tools' approval.** *aineo-run-tools*: `run` and `run_stop` are not allowed without asking and carry `_meta["anthropic/requiresUserInteraction"]`; `run_output` is allowed without asking. The README's introduction of the tools said "two tools, both allowed without asking"; it now names the five and says which three are allowed.
- **The fields and the bound.** `lua/aineo/mcp/run_tools.lua` declares `pattern`, `exclude`, `ignore_case`, `last`, `after_line` and `context` for `run_output`, and its description says matching stops after 2000 ms.
- **The zoom.** *aineo-zoom* says it acts under any pane, takes the column's whole height and gives the heights back on the second press.

## Checks

- `make lint` — clean.
- `make test_file FILE=tests/test_doc.lua` — 75 cases, `Fails (0) and Notes (0)`.
- No code, so no red step, no mutants and no suite run (the brief's rule for a docs-only packet). The diagram lines in the help are at most 78 columns.

## Open threads

None.

## Commits

Recorded after the merge.
