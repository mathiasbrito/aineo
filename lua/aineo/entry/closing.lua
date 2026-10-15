--- The close of aineo's tabs: a tab whose tab page has closed is released
--- at once, and its Claude Code stopped once the command that closed it has
--- ended.

local errors = require('aineo.entry.errors')
local folder_tabs = require('aineo.entry.folder_tabs')
local places = require('aineo.entry.places')
local registry = require('aineo.entry.registry')

local M = {}

--- Takes the entry of `tab` off the list of running editors. The first tab's
--- has no key, and taking off an entry with none takes off every entry of
--- this Neovim, so the entries of the tabs that remain are written again.
---
---@param tab aineo.entry.Tab
local function remove_entry_of(tab)
  if vim.v.servername == '' then
    return
  end
  local mcp = require('aineo.mcp')
  mcp.remove_editor_entry(places.kept_places().state_directory, vim.v.servername, tab.key)
  if tab.key == nil then
    for _, remaining in ipairs(registry.tab_list) do
      remaining.write_entry()
    end
  end
end

--- The tabs released (`release_tab()`) whose Claude Code has yet to stop
--- (`finish_closing()`).
---@type aineo.entry.Tab[]
local closing = {}

--- The tabs whose Claude Code a background stop is stopping now
--- (`finish_closing()`), until it has stopped.
---@type aineo.entry.Tab[]
local stopping = {}

--- Whether the Claude Code of a tab that has closed and has yet to stop
--- (`closing`, `stopping`) is on the session `id`.
---
---@param id string
---@return boolean
local function stops_in_closed_tab(id)
  return vim.iter({ closing, stopping }):flatten():any(function(tab)
    return tab.session_id() == id
  end)
end

--- Releases `tab`, whose tab page has closed: out of `tab_list` first, so
--- that no report or switch is told to it, then its entry off the list of
--- running editors, then its homes (`aineo.entry.Tab`'s `release()`). It
--- waits in `closing` for its Claude Code to stop.
---
---@param tab aineo.entry.Tab
local function release_tab(tab)
  for index, listed in ipairs(registry.tab_list) do
    if listed == tab then
      table.remove(registry.tab_list, index)
      break
    end
  end
  if registry.last_used_tab == tab then
    registry.last_used_tab = nil
  end
  remove_entry_of(tab)
  tab.release()
  table.insert(closing, tab)
end

--- Stops the shells of the tabs in `closing` that run one still
--- (`aineo.shell`'s `stop()`): the first tab's, whose module has no
--- `let_go()`, which a wipe inside `TabClosed` would hide from the layout's
--- handlers; those of the other tabs were let go when their tab pages
--- closed (`aineo.entry.Tab`'s `release()`). Then stops their Claude Codes
--- together, as quitting stops them (`aineo.claude`'s
--- `stop_sessions_in_background()`), without holding the editor, and ends
--- the tabs (`aineo.entry.Tab`'s `finish()`) once each Claude Code has
--- stopped. A shell stops at once, before the wait for a Claude Code that may
--- take seconds. Does nothing while Neovim quits: the quit stops every Claude
--- Code that runs, those of the tabs in `closing` and those still stopping
--- among them, and Neovim hangs up every shell.
local function finish_closing()
  if #closing == 0 or vim.v.exiting ~= vim.NIL then
    return
  end
  local finishing = closing
  closing = {}
  vim.list_extend(stopping, finishing)
  for _, tab in ipairs(finishing) do
    errors.run(tab.homes.shell.stop)
  end
  local function finish_each(already_stopped)
    for _, tab in ipairs(finishing) do
      for index, listed in ipairs(stopping) do
        if listed == tab then
          table.remove(stopping, index)
          break
        end
      end
      tab.finish(already_stopped)
    end
  end
  local started = errors.run(function()
    require('aineo.claude').stop_sessions_in_background(
      vim.tbl_map(function(tab)
        return tab.homes.claude
      end, finishing),
      function()
        finish_each(true)
      end
    )
  end)
  if not started then
    finish_each(false)
  end
end

--- Releases each tab whose tab page has closed (`aineo.tabs`' `closed()`), as
--- `:tabclose`, `:tabonly` and the close of a tab page's last window close
--- one, and has their Claude Codes stopped together once the command that
--- closed them has ended (`finish_closing()`): the editor is not held inside
--- `TabClosed`, and a command that closes several tab pages stops them once.
--- Does nothing while Neovim quits.
local function close_tabs_of_closed_pages()
  if vim.v.exiting ~= vim.NIL then
    return
  end
  local released = false
  for _, page in ipairs(require('aineo.tabs').closed()) do
    local tab = vim.iter(registry.tab_list):find(function(listed)
      return listed.page() == page
    end)
    if tab then
      release_tab(tab)
      released = true
    end
  end
  if released then
    folder_tabs.keep_folder_tabs()
  end
  vim.schedule(finish_closing)
end

M.stops_in_closed_tab = stops_in_closed_tab
M.finish_closing = finish_closing
M.close_tabs_of_closed_pages = close_tabs_of_closed_pages

return M
