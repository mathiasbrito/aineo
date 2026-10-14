--- Input's draft: the text of the buffer it is handed — the layout's
--- Input — kept in one file per Claude session under the editor's state
--- directory, or per working directory before the home is told a session,
--- so that text not sent yet outlives the editor, a crash included. Editors
--- following one session, or in one working directory, share its draft,
--- the last change winning.
---
--- The module is one copy of the home's per-view state: the Inputs it keeps
--- and the session it follows. `new()` makes another, each tab's own.

local home = require('aineo.draft.home')

local M = {}

--- The module's own copy of the home, which the module's functions are.
local module_copy = home.new({ group_name = 'aineo.draft' })

--- The number of copies made, the module's included.
local copies_made = 1

--- Whether the autocommand group `name` exists.
---
---@param name string
---@return boolean
local function has_group(name)
  return (pcall(vim.api.nvim_get_autocmds, { group = name }))
end

--- Sets where the module's copy keeps the draft
--- (`aineo.draft.Home`'s `set_draft_environment()`).
M.set_draft_environment = module_copy.set_draft_environment

--- Keeps a buffer's text as the module's copy's draft
--- (`aineo.draft.Home`'s `keep_draft()`).
M.keep_draft = module_copy.keep_draft

--- Makes the module's copy follow a Claude session
--- (`aineo.draft.Home`'s `follow_draft_session()`).
M.follow_draft_session = module_copy.follow_draft_session

--- Hands the draft of one Claude session over to another in the module's
--- copy (`aineo.draft.Home`'s `hand_over_draft_session()`).
M.hand_over_draft_session = module_copy.hand_over_draft_session

--- A new copy of the home, whose kept Inputs, followed session, environment
--- and handlers are its own, apart from the module's and from every copy
--- made before. Its functions are fields, as the module's own are. Its
--- handlers, and its retries at `SafeState`, are in the group
--- `aineo.draft.<n>`, `<n>` being the next number after those the copies made
--- since the module loaded took, and one whose group does not exist yet: the
--- copy creates that group when it is made, so a module loaded again never
--- takes the group of a copy still alive, whether or not it keeps an Input
--- yet.
---
--- The copy keeps the text of its Input before it follows a session in a
--- draft file named `<n>`, never in the working directory's draft, which is
--- the module's copy's alone.
---
---@return aineo.draft.Home
function M.new()
  repeat
    copies_made = copies_made + 1
  until not has_group(('aineo.draft.%d'):format(copies_made))
  local group_name = ('aineo.draft.%d'):format(copies_made)
  vim.api.nvim_create_augroup(group_name, { clear = false })
  return home.new({ group_name = group_name, label = tostring(copies_made) })
end

return M
