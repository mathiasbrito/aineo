--- What `:Aineo`'s arguments do, and the actions of tabs themselves: move to
--- a tab, claim a session in the current tab, close the current tab.

local cheatsheets = require('aineo.entry.cheatsheet')
local finding = require('aineo.entry.finding')
local offices = require('aineo.entry.office')
local opening = require('aineo.entry.opening')
local quitting = require('aineo.entry.quitting')
local registry = require('aineo.entry.registry')
local reopening = require('aineo.entry.reopening')
local one_tab = require('aineo.entry.tab')

local M = {}

--- What `:Aineo tab {n}` tells the user, as a warning, when there is no tab
--- page `n`: the number as the user typed it.
---
---@param typed string
---@return string
local function no_such_tab(typed)
  return ('aineo: no tab %s'):format(typed)
end

--- Moves to the tab page `number`, as `{n}gt` counts them, an aineo tab or
--- not; the cursor lands where it was in that tab page. With no such tab page
--- it moves nowhere and warns the user, naming the number as `typed`, which
--- is `number` as it is written when not given.
---
---@param number number
---@param typed? string
local function jump_to_tab(number, typed)
  local page = vim.api.nvim_list_tabpages()[number]
  if not page then
    vim.notify(no_such_tab(typed or tostring(number)), vim.log.levels.WARN)
    return
  end
  vim.api.nvim_set_current_tabpage(page)
end

--- What `:Aineo claim {id}` does: claims the session in the current tab
--- (`aineo.entry.Tab`'s `claim_session()`); but when another tab of this
--- Neovim runs that session, moves to that tab instead and claims nothing.
---
---@param id string
local function claim_in_current_tab(id)
  if not require('aineo.claude').is_session_id(id) then
    error((':Aineo claim takes a Claude session id, not %s'):format(id), 0)
  end
  local tab = opening.acting_tab()
  local running = vim.iter(registry.tab_list):find(function(other)
    return other ~= tab and other.is_bound() and other.runs_session(id)
  end)
  if running then
    vim.api.nvim_set_current_tabpage(running.page())
    registry.last_used_tab = running
    return
  end
  tab.claim_session(id)
end

--- What `:Aineo tab close` tells the user, as a warning, from a tab page
--- that is none of aineo's.
local NO_TAB_TO_CLOSE = 'aineo: this tab holds no Claude Code session'

--- What `:Aineo tab close` does. In an aineo tab, while another aineo tab
--- remains, it closes the tab page, which releases the tab and stops its
--- Claude Code as quitting stops it (`close_tabs_of_closed_pages()`), after
--- asking once when the tab's run pane runs processes, which the close stops
--- with it, and keeping the tab if the user cancels. In the last aineo tab it
--- quits Neovim as `:qa` does, which asks about the processes of the run panes
--- (`aineo.entry.quitting`) and refuses while a buffer has unsaved changes,
--- and nothing is stopped then, and otherwise stops every Claude Code as
--- quitting stops it. From a tab page that is none of aineo's it closes
--- nothing and tells the user so.
local function close_current_tab()
  local current = registry.tab_of_current_page()
  if not current then
    vim.notify(NO_TAB_TO_CLOSE, vim.log.levels.WARN)
    return
  end
  local remaining = vim
    .iter(registry.tab_list)
    :filter(function(tab)
      return tab.is_bound()
    end)
    :totable()
  if #remaining > 1 then
    if quitting.confirm_closing(current) then
      vim.cmd.tabclose()
    end
  else
    vim.cmd.qall()
  end
end

--- The arguments of `:Aineo` that open a tab's pieces when none is open: the
--- first run of one in an editor reopens the folder's tabs first
--- (`reopen_folder_tabs()`), so that the list is not replaced by the one
--- session it opens.
local REOPENS_TABS_FIRST = {
  claude = true,
  report = true,
  input = true,
  ['pane agent'] = true,
  ['pane changes'] = true,
  ['pane explorer'] = true,
}

--- What each of `:Aineo`'s arguments that runs an action does, by the
--- argument, its words joined by a space (`tab new`): the actions that act on
--- a tab (`aineo.entry.Tab`'s `actions`) on the tab to act on
--- (`acting_tab()`), and the actions of tabs themselves.
---@type table<string, fun()>
local ACTIONS = {}

for _, argument in ipairs({
  'send',
  'claim',
  'report',
  'input',
  'claude',
  'claude-numbers',
  'sessions',
  'new',
  'pane agent',
  'pane changes',
  'pane terminal',
  'pane run',
  'pane explorer',
  'run shell',
}) do
  ACTIONS[argument] = function()
    local origin = vim.api.nvim_get_current_buf()
    if REOPENS_TABS_FIRST[argument] then
      reopening.reopen_folder_tabs()
    end
    opening.acting_tab().actions[argument](origin)
  end
end

--- What `:Aineo open` does: the first run in an editor reopens the folder's
--- tabs when it keeps a list of them (`reopen_folder_tabs()`); any other run,
--- and a first run that finds none, opens the layout in the current tab, or
--- restores it, as the tab to act on does.
ACTIONS.open = function()
  if not reopening.reopen_folder_tabs() then
    opening.acting_tab().actions.open()
  end
end

--- What `:Aineo diff close` does: closes the diff of the existing aineo tab to
--- act on (`aineo.entry.opening`'s `existing_acting_tab()`), and never makes
--- a tab. With none, the module's own changes home, which shows no diff,
--- tells the user there is none to close.
ACTIONS['diff close'] = function()
  local tab = opening.existing_acting_tab()
  if tab then
    tab.actions['diff close']()
  else
    require('aineo.changes').close_shown_diff()
  end
end

--- What `:Aineo find` tells the user, as a warning, when there is no aineo tab.
local NO_TAB_TO_FIND_IN = 'aineo: there is no aineo tab to find a file in'

--- What `:Aineo find` does: searches for a file in the folder of the existing
--- aineo tab to act on (`aineo.entry.opening`'s `existing_acting_tab()`,
--- `aineo.entry.finding`), and never makes a tab. With none, tells the user.
ACTIONS.find = function()
  local tab = opening.existing_acting_tab()
  if not tab then
    vim.notify(NO_TAB_TO_FIND_IN, vim.log.levels.WARN)
    return
  end
  finding.find_in(tab)
end

--- What `:Aineo office` tells the user, as a warning, when there is no aineo tab.
local NO_TAB_FOR_OFFICE = 'aineo: there is no aineo tab to show the office in'

--- What `:Aineo office` does: shows the office over the right side of the
--- layout of the existing aineo tab to act on (`aineo.entry.opening`'s
--- `existing_acting_tab()`, `aineo.entry.office`), and never makes a tab. With
--- none, tells the user.
ACTIONS.office = function()
  local tab = opening.existing_acting_tab()
  if not tab then
    vim.notify(NO_TAB_FOR_OFFICE, vim.log.levels.WARN)
    return
  end
  cheatsheets.close(tab)
  offices.show(tab)
end

--- What `:Aineo cheatsheet` tells the user, as a warning, when there is no
--- aineo tab.
local NO_TAB_FOR_CHEATSHEET = 'aineo: there is no aineo tab to show the cheatsheet in'

--- What `:Aineo cheatsheet` does: shows the cheatsheet over the right side of
--- the layout of the existing aineo tab to act on (`aineo.entry.opening`'s
--- `existing_acting_tab()`, `aineo.entry.cheatsheet`), the office closed
--- first, or closes it when it shows; never makes a tab. With none, tells the
--- user.
ACTIONS.cheatsheet = function()
  local tab = opening.existing_acting_tab()
  if not tab then
    vim.notify(NO_TAB_FOR_CHEATSHEET, vim.log.levels.WARN)
    return
  end
  offices.hide(tab)
  cheatsheets.toggle(tab)
end

--- What `:Aineo office reset` does: shows the office of the existing aineo
--- tab to act on (as `:Aineo office`) as if its session began now, every
--- agent forgotten and the main agent walking in (`aineo.entry.office`'s
--- `reset()`), the cheatsheet closed first. With no aineo tab, tells the user.
function M.reset_office()
  local tab = opening.existing_acting_tab()
  if not tab then
    vim.notify(NO_TAB_FOR_OFFICE, vim.log.levels.WARN)
    return
  end
  cheatsheets.close(tab)
  offices.reset(tab)
end

--- What `:Aineo office preview [name]` does: shows the office of the existing
--- aineo tab to act on (as `:Aineo office`) acting out every state in turn
--- with the pack `name`, or the one the setting `office.pack` names
--- (`aineo.entry.office`'s `preview()`). With no aineo tab, tells the user.
---
---@param name? string
function M.preview_office(name)
  local tab = opening.existing_acting_tab()
  if not tab then
    vim.notify(NO_TAB_FOR_OFFICE, vim.log.levels.WARN)
    return
  end
  cheatsheets.close(tab)
  offices.preview(tab, name)
end

--- What `:Aineo zoom` does: zooms the window of the right column the cursor
--- is in, or gives back the heights it took (`aineo.layout`'s `toggle_zoom()`),
--- in the aineo tab of the current tab page, and never makes a tab. From a tab
--- page that is none of aineo's, the module's own layout, which has no such
--- window there, tells the user so.
ACTIONS.zoom = function()
  local tab = registry.tab_of_current_page()
  if tab then
    tab.actions.zoom()
  else
    require('aineo.layout').toggle_zoom()
  end
end

--- What `:Aineo zoom full` does: zooms the window the cursor is in to every
--- column and row the tab page's other windows can spare, or gives back the
--- sizes they had (`aineo.layout`'s `toggle_full_zoom()`), in the aineo tab of
--- the current tab page, and never makes a tab. From a tab page that is none
--- of aineo's, the module's own layout, which has no window there, tells the
--- user so.
ACTIONS['zoom full'] = function()
  local tab = registry.tab_of_current_page()
  if tab then
    tab.actions['zoom full']()
  else
    require('aineo.layout').toggle_full_zoom()
  end
end

ACTIONS['tab new'] = function()
  reopening.reopen_folder_tabs()
  opening.open_new_tab()
end

ACTIONS['tab close'] = close_current_tab

for number = 1, 9 do
  ACTIONS['tab ' .. number] = function()
    jump_to_tab(number)
  end
end

--- Does what `:Aineo` does with `argument`, one of its arguments that runs an
--- action (`ACTIONS`), its words joined by a space (`pane agent`). Raises the
--- error the action raises.
---
---@param argument string
function M.act(argument)
  ACTIONS[argument]()
end

--- What Send does in Visual mode: sends the selection alone, in the tab the
--- selection is in (`aineo.entry.Tab`'s `send_selection()`). A selection in a
--- tab page that is not an aineo tab's is in no Input: Send says so, and the
--- cursor stays where it is.
function M.send_visual_selection()
  local tab = registry.tab_of_current_page()
  if tab then
    tab.send_selection()
    return
  end
  require('aineo.send').send_selection({
    input = one_tab.NO_INPUT_BUFFER,
    session = require('aineo.claude'),
  })
end

M.claim_in_current_tab = claim_in_current_tab
M.jump_to_tab = jump_to_tab

return M
