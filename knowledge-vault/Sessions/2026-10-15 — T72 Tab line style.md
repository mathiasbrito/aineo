# 2026-10-15 — T72 Tab line style

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t72-tabline-style` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D12, D26, D29, D30

A small fix in the user's prompt-driven waves (D30). Measured on Neovim 0.12.5.

## The user's words (2026-10-15)

- "I want to make it bigger, and have the selected tab bold font"
- "also the inactive tab font color is barely visible"
- "better... it is fine with the bold, and the color you propposed for the inactive one... how about the font size?"
- "ok, add these choices to aineo"

The user's two choices: the selected tab in bold, and the inactive tabs in the colour proposed (Normal's foreground over TabLine's background). The font size cannot change in a terminal; the user was told so. The groups' names, `default = true`, the redefinition on `ColorScheme`, and the padding setting with its default of 2 are the orchestrator's assumptions (A325, A332–A334), not the user's decisions.

## Task lines

- [X] T72 The tab line's look: bold current title, readable inactive titles, padding — done on `feature/t72-tabline-style`: `AineoTabLineSel` (TabLineSel's colours plus bold), `AineoTabLine` (Normal's foreground over TabLine's background; linked to TabLine when Normal has no foreground) and `AineoTabLineFill` (linked to TabLineFill) are defined by `lua/aineo/tabs/highlights.lua` when aineo takes the tab line and after every `:colorscheme`; the setting `tabs.padding` (a whole number from 0, default 2) is the spaces either side of every title and counts in the width the line fits; help `*aineo-tabline*` and `*aineo-config-tabs.padding*`; reviews and the pull request's merge are open.

## What changed

- `lua/aineo/tabs/highlights.lua` (new): the three groups' names (`GROUPS`) and `keep_defined()`, which defines them as defaults (a group the user defined stays) and again from a `ColorScheme` autocommand in the augroup `aineo.tabs.highlights`, recreated, never duplicated, on each call.
- `lua/aineo/tabs/tabline.lua`: draws with those groups; `format(entries, columns, padding)`; the width of a title is its cells plus twice the padding.
- `lua/aineo/tabs/init.lua`: `draw_tabline()` calls `keep_defined()` only while 'tabline' is aineo's; `tabline()` reads `tabs.padding` through `aineo.config` and draws the default when the configuration is wrong (`:checkhealth aineo` reports it), so a redraw never raises.
- `lua/aineo/config/init.lua`: the row `tabs.padding`.
- `doc/aineo.txt`: the `*aineo-tabline*` paragraph after `*aineo-tab_title*`, and the `tabs.padding` entry in the settings.

## Cases (red first)

- `tests/test_config.lua`: the padding from either source and 2 by default; a padding of -1, 1.5, a string or `false` refused as `tabs.padding`.
- `tests/test_tabs.lua`: the line's groups and the default padding; padding 0 and 4 drawn; padding counted in what fits (80 columns with 0 fits three titles, 66 columns with 4 fits one); the padding from `setup()`; the default drawn for a wrong value. The other expectations of the file now hold the default padding.
- `tests/test_tabs_highlights.lua` (new): the defaults' values against a known Normal, TabLine and TabLineSel; the link when Normal has no foreground; the fill link; a user's own `AineoTabLineSel` kept; groups defined again after `:colorscheme default`; defaults following a new Normal after `:highlight clear`; one autocommand after two calls; nothing defined while the tab line is the user's.
- `tests/test_doc.lua`: the two new tags.

## Mutants (literal edits; each killed on the files named)

| Edit | Killed by |
|---|---|
| `tabline.lua`: width `+ 2 * padding` → `+ 2` | `test_tabs.lua` (2) |
| `tabline.lua`: trailing margin `margin` → `''` | `test_tabs.lua` (10) |
| `highlights.lua`: `{ bold = true }` → `{}` | `test_tabs_highlights.lua` (1) |
| `highlights.lua`: `{ default = true }` → `{}` | `test_tabs_highlights.lua` (1) |
| `highlights.lua`: the `ColorScheme` autocommand removed | `test_tabs_highlights.lua` (3) |
| `highlights.lua`: `nvim_create_augroup(AUGROUP, {})` → `{ clear = false }` | `test_tabs_highlights.lua` (1) |
| `highlights.lua`: `fg = normal.fg` → `fg = tabline.fg` | `test_tabs_highlights.lua` (2) |
| `highlights.lua`: `if normal.fg or normal.ctermfg then` → `if false then` | `test_tabs_highlights.lua` (2) |
| `highlights.lua`: fill `link = 'TabLineFill'` → `'TabLine'` | `test_tabs_highlights.lua` (2) |
| `init.lua`: `config.recorded_setup_options()` → `nil` | `test_tabs.lua` (1) |
| `init.lua`: the fallback padding → `0` | `test_tabs.lua` (1) |
| `init.lua`: `keep_defined()` called without `if in_use` | `test_tabs_highlights.lua` (1) |
| `config/init.lua`: `and value == math.floor(value)` removed | `test_config.lua` (1) |
| `config/init.lua`: `value >= 0` → `value >= -5` | `test_config.lua` (1) |
| `config/init.lua`: `default = 2` → `default = 1` | `test_config.lua` (6), `test_tabs.lua` (9) |

## Open threads

- The tabs home now requires `aineo.config`: a new edge of the modularity skill's direction table (A334), to be added by the orchestrator's `ai/` change.
- The paragraph of `*aineo-tabs*` that says the current tab is drawn "in |hl-TabLineSel|, the others in |hl-TabLine|" is stale; T68 rewrites those paragraphs, so it is left alone here.
- A colorscheme that does not `:highlight clear` before it sets its groups leaves the three groups as they were defined before it: a default does not replace an earlier definition.

## Commits

Recorded after the merge.
