--- The editor's first open, which reopens the folder's list of tabs.

local folder_tabs = require('aineo.entry.folder_tabs')
local opening = require('aineo.entry.opening')
local places = require('aineo.entry.places')
local registry = require('aineo.entry.registry')

local M = {}

--- Whether the editor's first open has yet to use the folder's list of tabs
--- (`reopen_folder_tabs()`). The first run of `:Aineo open` clears it, and so
--- does a session restored by a session plugin (`forgo_tab_reopening()`).
local first_open_pending = true

--- The list of tabs to reopen in the editor's folder: the list kept for it
--- when it holds the session kept for the folder (`aineo.tabs`'
--- `tabs_to_reopen()`), cut to the most tabs a reopening opens, and the
--- sessions cut off; nil when there is none.
---
---@return aineo.tabs.TabList|nil
---@return string[]|nil left
local function folder_tabs_to_reopen()
  local folder = places.kept_places()
  local kept =
    require('aineo.claude').kept_session(folder.state_directory, folder.working_directory)
  return require('aineo.tabs').tabs_to_reopen(
    folder.state_directory,
    folder.working_directory,
    kept
  )
end

--- The editor's first open, when the folder keeps a list of tabs that holds
--- its kept session and no aineo tab exists yet: opens every tab of the list in
--- its order, the first in the current tab page and each next one after the
--- tab before it (`opening.lua`'s `open_new_tab()`), each with its Claude
--- Code started on its session at once, with the claim the list keeps for
--- it (`aineo.entry.Tab`'s `open_on_session()`), and moves to the
--- tab at the list's place among them. The list is kept once all have opened,
--- with the sessions cut off by the most tabs a reopening opens, which the user
--- is told of. The first open uses the list once: later runs, and an open that
--- finds no such list, open as they always have (returns false). A tab that
--- cannot start raises an error that names its session and those not tried,
--- leaves the tabs opened before it, and keeps the sessions not tried in the
--- list; a list of one session that cannot start raises that start's own
--- error.
---
---@return boolean reopened
local function reopen_folder_tabs()
  if not first_open_pending then
    return false
  end
  first_open_pending = false
  if vim.iter(registry.tab_list):any(function(tab)
    return tab.is_bound()
  end) then
    return false
  end
  local list, left = folder_tabs_to_reopen()
  if not list then
    return false
  end
  local opened, failed_at = {}, nil
  local reopened, failure = folder_tabs.while_reopening(function()
    for index, session in ipairs(list.sessions) do
      failed_at = index
      opening.open_new_tab(function(tab)
        tab.open_on_session(session, list.claims and list.claims[session])
        table.insert(opened, tab)
      end, true)
    end
    failed_at = nil
  end)
  local untried = vim.list_slice(list.sessions, (failed_at or #list.sessions) + 1)
  vim.list_extend(untried, left)
  local current = opened[list.current]
  if current and current.is_bound() then
    vim.api.nvim_set_current_tabpage(current.page())
  end
  folder_tabs.keep_folder_tabs(untried)
  if not reopened then
    if #untried == 0 and #opened == 0 then
      error(failure, 0)
    end
    local cause = tostring(failure):match('^[^\n]*')
    error(
      ('reopening stopped at %s: %s%s'):format(
        list.sessions[failed_at],
        cause,
        #untried > 0 and '; not tried: ' .. table.concat(untried, ', ') or ''
      ),
      0
    )
  end
  if #left > 0 then
    vim.notify(
      ('aineo: reopened the first %d tabs of the list; %d more stay in the list'):format(
        #list.sessions,
        #left
      ),
      vim.log.levels.WARN
    )
  end
  return true
end

--- Has the editor's first open open as it always has, without the folder's
--- list of tabs (`reopen_folder_tabs()`): what a session restored at startup
--- asks for, its windows being the user's to keep.
function M.forgo_tab_reopening()
  first_open_pending = false
end

M.reopen_folder_tabs = reopen_folder_tabs

return M
