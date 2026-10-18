# 2026-10-18 — T94 README refresh

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t94-readme` · **Pull request:** into `dev` (number recorded after the merge)

The README is brought up to date with the help (`doc/aineo.txt`) and the code as they stand on `dev` after T91: a richer opening chart, the key tables split by panel, the changes pane's own keys and remembered view, the agents' MCP tools, the tmux and iTerm2 notes for `<S-CR>`, the finder, and the installation. Docs only.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — A486 (narrowed), A487, A488
- `doc/aineo.txt` — *aineo-install*, *aineo-panes*, *aineo-changes*, *aineo-changes-edit*, *aineo-changes-view-kept*, *aineo-find*, *aineo-run*, *aineo-report*
- `README.md`

## Task lines

- [X] T94 README refresh (A486 as narrowed, A487, A488): the opening chart shows the tab line, Claude's terminal, the file column and the right column with its four panes and their keys; the key table is one table per panel (Global, Claude terminal, Agent pane, Changes pane, Terminal pane, Run pane); a section on the changes pane (its keys, reported work, the remembered view, the `<S-CR>` notes for tmux and iTerm2), one on finding a file, one on what Claude tells aineo (`report`, `announce_work`); the Installation takes `version = '*'`, the update, a pin, the lockfile and `:checkhealth aineo`; Requirements say what each new host needs. T92 (run tools) and T93 (zoom) are left out; a later addition covers them.

## The user's words

"the project README seems completly outdated" — then, narrowed: "I exageranted, not completly, but missing some points, like the chart you show in the begging is oversimplified and do not reflect how rich aineo became". And: "cover your findings also, after that we need to compact the session"; "the table, must have sections 'separations' based on the type of panel... so that it is clear that the commands are related to the panel"; "ok, it works, make sure that the README is also up to date with the installation proccess".

## Design

- **Kept:** the README's order and voice, the Run section, the Settings table, the activity-indicator and tmux section, the Health check and Development sections. Each was read against the help and the config's setting list (`lua/aineo/config/init.lua`): every setting, default and sentence matched.
- **Chart.** Two fenced blocks in one: the layout (tab line with titles and activity marks, Claude's terminal, the file column, the Report over Input), and the four panes the right column switches between, each under its key. The changes pane shows the files window over the commits window, as the help has it (the files window takes the Report's place); the brief's wording said "commits over files", and the help won.
- **Key tables.** One `###` heading and one table per panel, as A487 reads: a key in a panel's table is the one that acts in or opens that panel. `\d` sits with the changes pane, `\f` with the global keys (A487), `\s` with the agent pane. The terminal-prefix paragraph (`<C-\>` twins) stays above the tables.
- **Installation (A488).** Release tags were checked: `git tag` on the checkout lists only `vX.Y.Z` tags (none else), and the GitHub tags API lists `v0.2.53`, `v0.2.52`, `v0.2.51` newest first (v0.2.52 when first written); the repository has tags and no GitHub releases, which lazy.nvim's `version = '*'` does not need. The statements about lazy.nvim itself (clones missing plugins at start, `:Lazy update`, `tag`, `lazy-lock.json`, `:Lazy restore`) are lazy.nvim's documented behaviour and were not run here.
- **Left out on purpose:** T92 (`run`, `run_output`, `run_stop`) and T93 (`\z`), neither on `dev`.

## Checks

- `make lint` — clean (it does not cover Markdown).
- The chart's rows were measured at equal width per box (character counts, not bytes) and sit in a fenced block, so they render in a fixed-width font.
- A second reading of the README top to bottom against the help; the findings of it are in the report.
- No code, so no red step, no mutants and no suite run (the brief's rule for a docs-only packet).

## Open threads

- A short README addition for T92 and T93 when they land.
- Items in the help that look wrong or doubtful are listed in the packet's report, not changed here.

## Commits

PR #272, merged by rebase after one fix round; released in `v0.2.54` (PR #274, `main` `bc8b814`). On `dev`, in order:

- `fe63eaa` Bring the README up to date with the help and the install
- `1993246` Correct the README where the key tables outgrew its sentences
