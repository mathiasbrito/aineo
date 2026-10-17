--- The handlers this Neovim's entries in the list of running editors need,
--- and those of what other processes tell this editor — a switch of a
--- session it follows, the work an agent of a tab's Claude Code announced —
--- made once for every tab.

local places = require('aineo.entry.places')
local registry = require('aineo.entry.registry')
local routing = require('aineo.entry.routing')

local M = {}

--- Whether the editor's handlers have been made (`make_editor_handlers()`).
local editor_handlers_made = false

--- What tells the user `message`, at `INFO`, for `tab`: `tab <n>: ` before
--- it, `n` the tab's place among the tab pages, while that tab is not the
--- current one when it is told.
---
---@param tab aineo.entry.Tab
---@return fun(message: string)
local function teller_for(tab)
  return function(message)
    if registry.tab_of_current_page() ~= tab and tab.is_bound() then
      message = ('tab %d: %s'):format(registry.tab_number(tab), message)
    end
    vim.notify(message, vim.log.levels.INFO)
  end
end

--- Takes `work`, an announcement a relay offers with the start token
--- `start_token`, for the tab whose Claude Code has that token, whichever
--- tab is current (`routing.lua`'s `tab_for_work()`), and answers at once
--- whether one does: its changes home is handed the work, with what tells
--- the user for that tab (`teller_for()`), at the main loop's next turn, so
--- that the editor answers the relay before any git runs.
---
---@param work aineo.changes.ReportedWork
---@param start_token string
---@return boolean taken
local function take_announced_work(work, start_token)
  local tab = type(start_token) == 'string' and routing.tab_for_work(start_token)
  if not tab then
    return false
  end
  vim.schedule(function()
    tab.homes.changes.add_reported_work(work, teller_for(tab))
  end)
  return true
end

--- Makes, once, the handlers this Neovim's entries in the list of running
--- editors need: `FocusGained` writes the entry of the tab used last again,
--- marking it used; `TabEnter` writes the entry of an aineo tab entered;
--- `VimLeavePre` takes every entry of this Neovim off the list and lets go
--- every tab's claim; a switch told by another Claude Code's hook is
--- followed by each tab it concerns (`aineo.entry.Tab`'s
--- `follow_told_switch()`); and work an agent announced goes to the tab
--- whose Claude Code has its start token (`take_announced_work()`). Made at
--- the first entry write, so that sourcing this file makes none.
local function make_editor_handlers()
  if editor_handlers_made then
    return
  end
  editor_handlers_made = true
  local group = vim.api.nvim_create_augroup('aineo.editors', {})
  vim.api.nvim_create_autocmd('FocusGained', {
    group = group,
    desc = 'aineo: mark the tab used last used in the list of running editors',
    callback = function()
      local tab = registry.tab_of_current_page() or registry.last_used_tab or registry.tab_list[1]
      if tab then
        tab.write_entry()
      end
    end,
  })
  vim.api.nvim_create_autocmd('TabEnter', {
    group = group,
    desc = 'aineo: mark the aineo tab entered used in the list of running editors',
    callback = function()
      local tab = registry.tab_of_current_page()
      if tab then
        registry.last_used_tab = tab
        tab.write_entry()
      end
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    desc = 'aineo: take this editor off the list of running editors',
    callback = function()
      require('aineo.mcp').remove_editor_entry(
        places.kept_places().state_directory,
        vim.v.servername
      )
      for _, tab in ipairs(registry.tab_list) do
        tab.release_claim()
      end
    end,
  })
  require('aineo.mcp').on_followed_switch(function(left, new)
    for _, tab in ipairs(registry.tab_list) do
      tab.follow_told_switch(left, new)
    end
  end)
  require('aineo.mcp').on_work_announced(take_announced_work)
end

M.make_editor_handlers = make_editor_handlers

return M
