--- The handlers this Neovim's entries in the list of running editors need,
--- made once for every tab.

local places = require('aineo.entry.places')
local registry = require('aineo.entry.registry')

local M = {}

--- Whether the editor's handlers have been made (`make_editor_handlers()`).
local editor_handlers_made = false

--- Makes, once, the handlers this Neovim's entries in the list of running
--- editors need: `FocusGained` writes the entry of the tab used last again,
--- marking it used; `TabEnter` writes the entry of an aineo tab entered;
--- `VimLeavePre` takes every entry of this Neovim off the list and lets go
--- every tab's claim; and a switch told by another Claude Code's hook is
--- followed by each tab it concerns (`aineo.entry.Tab`'s
--- `follow_told_switch()`). Made at the first entry write, so that sourcing
--- this file makes none.
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
end

M.make_editor_handlers = make_editor_handlers

return M
