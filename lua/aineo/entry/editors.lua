--- The handlers this Neovim's entries in the list of running editors need,
--- and those of what other processes tell this editor — a switch of a
--- session it follows, the work an agent of a tab's Claude Code announced, a
--- call of a run tool — made once for every tab.

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

--- How long the editor waits for a report's branches to be resolved before
--- it refuses the announcement: above the limit the changes home gives git
--- for each run, so that git's own answer comes first, and inside the 5 s
--- the report server waits for the editor.
local BASE_WAIT_MS = 4000

--- `work` with each branch checked to be a local branch and its base
--- resolved to its full id, in the worktree's own folder, else in the
--- session's repository of `changes`, a tab's changes home
--- (`aineo.changes.Home`'s `resolve_reported_work()`), waited for at most
--- `BASE_WAIT_MS`; or nil and why it is refused, in words for the agent.
---
---@param changes aineo.changes.Home
---@param work aineo.changes.ReportedWork
---@return aineo.changes.ReportedWork|nil resolved
---@return string|nil refusal
local function resolved_work(changes, work)
  local answered, resolved, refusal = false, nil, nil
  changes.resolve_reported_work(work, function(answer, why)
    answered, resolved, refusal = true, answer, why
  end)
  if not vim.wait(BASE_WAIT_MS, function()
    return answered
  end, 5) then
    return nil, ('branches: git did not resolve them within %d s'):format(BASE_WAIT_MS / 1000)
  end
  return resolved, refusal
end

--- Whether `work` has the shape of a report of a worktree: a table of a
--- `worktree` string and a list of `branches`, as an aineo older than the
--- relay or the hook would not give.
---
---@param work any
---@return boolean
local function is_worktree_report(work)
  return type(work) == 'table'
    and type(work.worktree) == 'string'
    and type(work.branches) == 'table'
    and vim.islist(work.branches)
end

--- Takes `work`, an announcement a relay or aineo's hook offers with the
--- start token `start_token`, for the tab whose Claude Code has that token,
--- whichever tab is current (`routing.lua`'s `tab_for_work()`), and answers
--- whether it took it, or why it refuses it: with no such tab, or a work of
--- another shape (`is_worktree_report()`), false; else each branch it gives
--- is checked to be a local branch and its base resolved to its full id in
--- the worktree's own folder, else in that tab's session's repository
--- (`resolved_work()`) — a branch git does not have, or a base that cannot
--- be resolved, is refused, and nothing is recorded — and the tab's changes
--- home is handed the work, with what tells the user for that tab
--- (`teller_for()`), and answers, starting its git reads without waiting on
--- them (`aineo.changes.Home`'s `add_reported_work()`).
---
---@param work aineo.changes.ReportedWork
---@param start_token string
---@return boolean|string taken `true` when taken, or the words of its refusal
local function take_announced_work(work, start_token)
  local tab = type(start_token) == 'string' and routing.tab_for_work(start_token)
  if not (tab and is_worktree_report(work)) then
    return false
  end
  local changes = tab.homes.changes
  local resolved, refusal = resolved_work(changes, work)
  if not resolved then
    return refusal
  end
  work = resolved
  return changes.add_reported_work(work, teller_for(tab)) == true
end

--- Takes `run_call`, a call of a run tool a relay offers with the start token
--- `start_token`, for the tab whose Claude Code has that token, whichever tab
--- is current (`routing.lua`'s `tab_for_work()`), and answers at once with
--- the words for the agent and whether they are an error: with no such tab,
--- false; else what that tab's run pane does (`aineo.entry.run_tools`'s
--- `call()`), in the project folder, telling the user for that tab
--- (`teller_for()`).
---
---@param run_call aineo.mcp.RunCall
---@param start_token string
---@return aineo.entry.RunToolAnswer|false
local function take_run_call(run_call, start_token)
  local tab = type(start_token) == 'string' and routing.tab_for_work(start_token)
  if not tab then
    return false
  end
  return require('aineo.entry.run_tools').call(tab, run_call, {
    folder = places.kept_places().working_directory,
    tell = teller_for(tab),
  })
end

--- Makes, once, the handlers this Neovim's entries in the list of running
--- editors need: `FocusGained` writes the entry of the tab used last again,
--- marking it used; `TabEnter` writes the entry of an aineo tab entered;
--- `VimLeavePre` takes every entry of this Neovim off the list and lets go
--- every tab's claim; a switch told by another Claude Code's hook is
--- followed by each tab it concerns (`aineo.entry.Tab`'s
--- `follow_told_switch()`); and work an agent announced goes to the tab
--- whose Claude Code has its start token (`take_announced_work()`), and so
--- does a call of a run tool (`take_run_call()`); a call of the test layout
--- tool is kept for its repository, whichever tab's Claude Code made it,
--- when that repository is the one of the folder the editor started in or
--- of its working folder (`aineo.test_layout`'s `declare()`). Made at the
--- first entry write, so
--- that sourcing this file makes none.
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
  require('aineo.mcp').on_run_called(take_run_call)
  require('aineo.mcp').on_test_layout_declared(function(call)
    return require('aineo.test_layout').declare(
      call,
      { places.kept_places().working_directory, vim.fn.getcwd() }
    )
  end)
end

M.make_editor_handlers = make_editor_handlers

return M
