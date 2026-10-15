--- The folder's list of tabs, kept as the tabs stand: as a tab opens or
--- closes or its session changes, and when Neovim quits.

local errors = require('aineo.entry.errors')
local places = require('aineo.entry.places')
local registry = require('aineo.entry.registry')

local M = {}

--- Whether the tabs of the folder's list are being reopened
--- (`reopening.lua`'s `reopen_folder_tabs()`, through `while_reopening()`):
--- the list is kept once, when the last has opened, so that the list being
--- restored is never replaced by a part of itself.
local tabs_reopening = false

--- Keeps the folder's list of tabs as the tabs stand (`aineo.tabs`'
--- `keep_tabs()`): the session of each tab whose layout is in a tab page, in
--- the order of the tab pages, and the place of the tab whose tab page is
--- current, or of the tab used last (`last_used_tab`) when the current tab
--- page is none of aineo's. `not_opened` are sessions a reopening has not
--- opened (cut off, or not tried): they follow those of the tabs in the list.
--- Keeps nothing when no tab and none of `not_opened` has a session; a list
--- that cannot be kept is told the user once (`run()`).
---
--- When the session kept for the folder (the one the next start without a
--- list lands in) is not in the list, the session at the list's place is kept
--- in its stead (`aineo.claude`'s `keep_session()`): a tab closed whose
--- session was the kept one is not brought back alone by the next start.
---
---@param not_opened? string[]
local function write_folder_tabs(not_opened)
  local current = registry.tab_of_current_page()
  if not current and registry.last_used_tab and registry.last_used_tab.is_bound() then
    current = registry.last_used_tab
  end
  local bound = vim
    .iter(registry.tab_list)
    :filter(function(tab)
      return tab.is_bound()
    end)
    :totable()
  table.sort(bound, function(left, right)
    return registry.tab_number(left) < registry.tab_number(right)
  end)
  local tabs = require('aineo.tabs')
  local list = tabs.list_of_tabs(vim.tbl_map(function(tab)
    return { session = tab.session_id(), current = tab == current }
  end, bound))
  list = list or (not_opened and #not_opened > 0 and { sessions = {}, current = 1 }) or nil
  if not list then
    return
  end
  for _, session in ipairs(not_opened or {}) do
    if not vim.tbl_contains(list.sessions, session) then
      table.insert(list.sessions, session)
    end
  end
  local folder = places.kept_places()
  errors.run(function()
    tabs.keep_tabs(folder.state_directory, folder.working_directory, list)
    local claude = require('aineo.claude')
    local kept = claude.kept_session(folder.state_directory, folder.working_directory)
    if not vim.tbl_contains(list.sessions, kept) then
      claude.keep_session(
        folder.state_directory,
        folder.working_directory,
        list.sessions[list.current]
      )
    end
  end)
end

--- Keeps the folder's list of tabs (`write_folder_tabs()`) as a tab opens or
--- closes or a tab's session changes. Does nothing while tabs reopen, and
--- once Neovim is quitting: the list is kept at the quit, before the Claude
--- Codes are stopped (`keep_folder_tabs_at_quit()`). `not_opened` as
--- `write_folder_tabs()` takes it.
---
---@param not_opened? string[]
local function keep_folder_tabs(not_opened)
  if tabs_reopening or vim.v.exiting ~= vim.NIL then
    return
  end
  write_folder_tabs(not_opened)
end

--- Whether the handler that keeps the folder's list of tabs at the quit has
--- been made (`keep_folder_tabs_at_quit()`).
local quit_keeper_made = false

--- Makes, once, the handler that keeps the folder's list of tabs when Neovim
--- quits (`write_folder_tabs()`), with the tab current then. Made when the
--- first tab is made, before its Claude Code starts, so that it runs before
--- the handler that stops every Claude Code (handlers run in the order they
--- were made).
local function keep_folder_tabs_at_quit()
  if quit_keeper_made then
    return
  end
  quit_keeper_made = true
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('aineo.tab_list', {}),
    desc = "aineo: keep the folder's list of tabs before Claude Code is stopped",
    callback = function()
      write_folder_tabs()
    end,
  })
end

--- Runs `reopen`, which reopens the tabs of the folder's list, with the list
--- kept by none of the tabs it opens (`keep_folder_tabs()` doing nothing
--- meanwhile), and returns what `pcall()` returns for it: whether it ran
--- without an error, and the error it raised.
---
---@param reopen fun()
---@return boolean reopened
---@return any failure
local function while_reopening(reopen)
  tabs_reopening = true
  local reopened, failure = pcall(reopen)
  tabs_reopening = false
  return reopened, failure
end

M.keep_folder_tabs = keep_folder_tabs
M.keep_folder_tabs_at_quit = keep_folder_tabs_at_quit
M.while_reopening = while_reopening

return M
