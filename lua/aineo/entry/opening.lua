--- The tabs made and opened: the first tab, made of the homes the modules
--- themselves are, the tabs of copies after it, the tab an action acts on,
--- and the tab pages a new tab opens in.

local closing = require('aineo.entry.closing')
local explorer = require('aineo.entry.explorer')
local folder_tabs = require('aineo.entry.folder_tabs')
local registry = require('aineo.entry.registry')
local routing = require('aineo.entry.routing')
local one_tab = require('aineo.entry.tab')

local M = {}

--- Opens a tab page at the end, after the last tab page, with a tab of
--- aineo's in it, which `start` starts Claude Code in (`aineo.entry.Tab`'s
--- `start_in_new_tab()` when none is given); `after_current` puts it after
--- the current tab page instead. Defined below; every tab made here is given
--- it (`tab_callbacks()`).
---@type fun(start?: fun(tab: aineo.entry.Tab), after_current?: boolean)
local open_new_tab

--- The first tab: made of the homes the modules themselves are, and kept for
--- the editor's life from the first call of `new_tab()` on. Those homes
--- cannot be let go, so when the tab closes it is left as it stands, out of
--- `tab_list`, and `new_tab()` gives it again to the next tab opened, as
--- today's single composition goes on when the layout's tab page has closed
--- and the layout opens again.
---@type aineo.entry.Tab?
local module_tab = nil

--- Whether the handlers of closed and entered tab pages have been made
--- (`hold_tab()`).
local tab_page_handlers_made = false

--- Has the tabs home hold the tab page `tab` is in, called with the tab as
--- its layout opens there for the first time: its title says the name of the
--- session its Claude terminal shows and whether its Claude Code is busy;
--- aineo's tab line is drawn while the user's own is empty, and the line
--- shows with a single tab page unless `tabs.always_show` is off
--- (`aineo.tabs`' `show_tabline_once()`); a tab page that
--- closes closes the tab (`close_tabs_of_closed_pages()`); a tab page the user
--- enters and is still in once the event loop has turned is seen
--- (`aineo.tabs`' `mark_seen()`), so that aineo's own pass through a tab page
--- marks none.
---
---@param tab aineo.entry.Tab
local function hold_tab(tab)
  local tabs = require('aineo.tabs')
  tabs.hold(tab.page(), tab.session_name)
  tabs.set_busy(tab.page(), tab.is_busy())
  tabs.draw_tabline()
  tabs.show_tabline_once()
  registry.last_used_tab = tab
  folder_tabs.keep_folder_tabs()
  if not tab_page_handlers_made then
    tab_page_handlers_made = true
    local group = vim.api.nvim_create_augroup('aineo.tabs', {})
    vim.api.nvim_create_autocmd('TabClosed', {
      group = group,
      desc = 'aineo: close the tab of a tab page that closed',
      callback = closing.close_tabs_of_closed_pages,
    })
    vim.api.nvim_create_autocmd('TabEnter', {
      group = group,
      desc = 'aineo: the tab of a tab page the user stays in has been seen',
      callback = function()
        local entered = vim.api.nvim_get_current_tabpage()
        vim.schedule(function()
          if vim.api.nvim_get_current_tabpage() == entered then
            require('aineo.tabs').mark_seen(entered)
          end
        end)
      end,
    })
  end
end

--- What every tab made here is given of the editor it is in
--- (`aineo.entry.TabCallbacks`): `hold_tab()` for each time its layout opens
--- in a tab page it was not in, and `open_new_tab()`.
---
---@return aineo.entry.TabCallbacks
local function tab_callbacks()
  return { on_bound = hold_tab, open_new_tab = open_new_tab }
end

--- How many tabs have been made (`new_tab()`), the first included; each tab
--- made of copies is keyed by the number it was made as.
local tabs_made = 0

--- `homes` with the explorer made of them (`aineo.entry.explorer`).
---
---@param homes aineo.entry.Homes
---@return aineo.entry.Homes
local function with_explorer(homes)
  homes.explorer = explorer.make_explorer(homes)
  return homes
end

--- The homes the modules themselves are: the first tab's, with an explorer
--- of its own, as the explorer home has no module copy.
---
---@return aineo.entry.Homes
local function module_homes()
  return with_explorer({
    layout = require('aineo.layout'),
    claude = require('aineo.claude'),
    report = require('aineo.report'),
    draft = require('aineo.draft'),
    changes = require('aineo.changes'),
    shell = require('aineo.shell'),
    run = require('aineo.run'),
  })
end

--- The copies each home's `new()` makes, for a tab made while the first tab
--- is in `tab_list`, with an explorer of their own.
---
---@return aineo.entry.Homes
local function copied_homes()
  return with_explorer({
    layout = require('aineo.layout').new(),
    claude = require('aineo.claude').new(),
    report = require('aineo.report').new(),
    draft = require('aineo.draft').new(),
    changes = require('aineo.changes').new(),
    shell = require('aineo.shell').new(),
    run = require('aineo.run').new(),
  })
end

--- Whether the report home has been given its router yet.
local report_router_given = false

--- Whether the first tab (`module_tab`) can be taken up again: it is in no
--- tab page, and its Claude Code has ended or never started, so that a tab
--- made of its homes starts a Claude Code of its own and none is left running.
---
---@return boolean
local function first_tab_can_be_taken_up_again()
  if vim.tbl_contains(registry.tab_list, module_tab) then
    return false
  end
  local status = module_tab.homes.claude.session_status()
  return status == nil or status == 'exited'
end

--- Makes a tab and adds it to `tab_list`: the first tab, made of the homes the
--- modules themselves are (`module_tab`), when it is not in `tab_list` and its
--- Claude Code has stopped (`first_tab_can_be_taken_up_again()`); else a tab
--- of copies (`copied_homes()`), keyed by the number it is made as, and held
--- in the tabs home once its layout opens (`hold_tab()`). The first tab made
--- has the report home route a report to the tab it is for (`route_report()`).
--- The Claude Codes of the tabs closed so far are stopped first
--- (`finish_closing()`), while the first tab's homes still hold the start they
--- stop, so that taking them up again in the command that closed the first
--- tab does not give its new Claude Code a stop meant for the old.
---
---@return aineo.entry.Tab
local function new_tab()
  closing.finish_closing()
  folder_tabs.keep_folder_tabs_at_quit()
  tabs_made = tabs_made + 1
  local tab
  if module_tab == nil then
    module_tab = one_tab.make_tab(module_homes(), nil, tab_callbacks())
    tab = module_tab
  elseif first_tab_can_be_taken_up_again() then
    tab = module_tab
    tab.reopen()
  else
    tab = one_tab.make_tab(copied_homes(), tostring(tabs_made), tab_callbacks())
  end
  table.insert(registry.tab_list, tab)
  if not report_router_given then
    report_router_given = true
    require('aineo.report').set_report_router(routing.route_report)
  end
  return tab
end

--- The aineo tab an action acts on, without making one: the tab whose tab
--- page the current window is in; from a tab page that is none of aineo's,
--- the aineo tab used last, else the first, which the cursor moves to (O5).
--- Nil with no aineo tab bound.
---
---@return aineo.entry.Tab|nil
local function existing_acting_tab()
  local current = registry.tab_of_current_page()
  if current then
    registry.last_used_tab = current
    return current
  end
  local to_return_to = (
    registry.last_used_tab
    and registry.last_used_tab.is_bound()
    and registry.last_used_tab
  ) or vim.iter(registry.tab_list):find(function(tab)
      return tab.is_bound()
    end)
  if to_return_to then
    vim.api.nvim_set_current_tabpage(to_return_to.page())
    registry.last_used_tab = to_return_to
    return to_return_to
  end
  return nil
end

--- The tab an action acts on: the existing aineo tab
--- (`existing_acting_tab()`); with no aineo tab at all, the tab a claim made
--- before aineo opened (`aineo.entry.Tab`'s `claim_session()`), else a new
--- one, whose layout opens in the current tab page.
---
---@return aineo.entry.Tab
local function acting_tab()
  return existing_acting_tab()
    or vim.iter(registry.tab_list):find(function(tab)
      return not tab.is_bound()
    end)
    or new_tab()
end

--- Opens a tab page at the end, after the last tab page, so that no tab
--- changes its number, and a tab of aineo's in it, which `start` starts Claude
--- Code in (`aineo.entry.Tab`'s `start_in_new_tab()`, on a new session id in
--- the folder, when none is given): its layout around the Claude Code, the
--- cursor in Claude's window in Terminal mode. With `after_current` the tab
--- page is after the current one, as a reopening of the folder's tabs puts
--- each after the one before it. With no aineo tab yet, it opens the first one
--- in the current tab page. When the tab cannot start, the tab page it made is
--- closed again and the error raised.
---
---@param start? fun(tab: aineo.entry.Tab)
---@param after_current? boolean
open_new_tab = function(start, after_current)
  start = start or function(tab)
    tab.start_in_new_tab()
  end
  if not vim.iter(registry.tab_list):any(function(tab)
    return tab.is_bound()
  end) then
    start(acting_tab())
    return
  end
  local tab = new_tab()
  vim.cmd(after_current and 'tabnew' or '$tabnew')
  local made_page = vim.api.nvim_get_current_tabpage()
  local started, failure = pcall(start, tab)
  if started then
    return
  end
  for index, listed in ipairs(registry.tab_list) do
    if listed == tab then
      table.remove(registry.tab_list, index)
      break
    end
  end
  tab.release()
  tab.finish(false)
  if vim.api.nvim_tabpage_is_valid(made_page) and #vim.api.nvim_list_tabpages() > 1 then
    vim.cmd.tabclose(vim.api.nvim_tabpage_get_number(made_page))
  end
  error(failure, 0)
end

M.acting_tab = acting_tab
M.existing_acting_tab = existing_acting_tab
M.open_new_tab = open_new_tab

return M
