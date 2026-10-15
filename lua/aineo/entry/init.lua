--- The body of aineo's composition root, `require('aineo.entry')`: what
--- `:Aineo`, its `<Plug>` mappings and the autostart do, which
--- `plugin/aineo.lua` registers and calls here once a command, a mapping or
--- the autostart first needs it.
---
--- One tab of aineo (`tab.lua`'s `make_tab()`) is a Claude Code session with
--- the layout, Report, Input and changes pane that follow it, in a tab page.
--- The first tab is made of the homes the modules themselves are, and every
--- tab after it of the copies each home's `new()` makes (`opening.lua`). What
--- an action does it does to a tab (`opening.lua`'s `acting_tab()`), and what
--- the editor shares — the folder (`places.lua`), the tabs (`registry.lua`),
--- the list of running editors (`editors.lua`), the report home's router
--- (`routing.lua`) — is held once, in this home.
---
--- Loading it loads no other home: each is required when an action first
--- needs it.

local actions = require('aineo.entry.actions')
local errors = require('aineo.entry.errors')
local places = require('aineo.entry.places')
local reopening = require('aineo.entry.reopening')

local M = {}

M.act = actions.act
M.send_visual_selection = actions.send_visual_selection
M.claim_in_current_tab = actions.claim_in_current_tab
M.jump_to_tab = actions.jump_to_tab
M.running_sessions_here = places.running_sessions_here
M.forgo_tab_reopening = reopening.forgo_tab_reopening
M.tell_error = errors.tell_error

return M
