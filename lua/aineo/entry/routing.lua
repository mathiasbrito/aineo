--- Which tab a report is for, as the report home's router asks
--- (`aineo.report`'s `set_report_router()`), and which tab an announcement
--- of work, or a call of a run tool, is for.

local registry = require('aineo.entry.registry')

local M = {}

--- The tab of `tab_list` the report `session_id` of the Claude Code with the
--- start token `options.start_token` is for, or nil when it is for none, in
--- the order of the rules the report home's router gives (D63):
---
--- 1. the tab whose Claude Code has the token and whose panes follow the
---    session;
--- 2. else a tab whose panes follow the session;
--- 3. else, offered `at_start`, the tab whose Claude Code has the token, which
---    the tab's report home then takes or declines by its own rules: it takes
---    the report while its panes follow no session yet, and, offered to keep
---    it with the directory's records, while a claim holds them elsewhere;
--- 4. a report of no known session (`session_id` nil): the tab whose Claude
---    Code has the token.
---
---@param session_id string?
---@param options { at_start: boolean?, start_token: string? }
---@return aineo.entry.Tab?
local function tab_for_report(session_id, options)
  local token = options.start_token
  local function find(matches)
    return vim.iter(registry.tab_list):find(matches)
  end
  local function has_token(tab)
    return token ~= nil and tab.start_token() == token
  end
  if session_id == nil then
    return find(has_token)
  end
  return find(function(tab)
    return has_token(tab) and tab.panes_session() == session_id
  end) or find(function(tab)
    return tab.panes_session() == session_id
  end) or (options.at_start and find(has_token) or nil)
end

--- What the report home's router answers (`aineo.report`'s
--- `set_report_router()`): the report home of the tab a report is for
--- (`tab_for_report()`), nil when it is for none.
---
---@param session_id string?
---@param options table
---@return aineo.report.Home?
local function route_report(session_id, options)
  local tab = tab_for_report(session_id, options)
  return tab and tab.homes.report
end

--- The tab of `tab_list` whose Claude Code has the start token
--- `start_token`, whichever tab is current, in a tab page that exists; nil
--- when there is none: an announcement of work, or a call of a run tool, is
--- about the tab whose Claude Code works, not about the session a report
--- narrates.
---
---@param start_token string
---@return aineo.entry.Tab?
local function tab_for_work(start_token)
  return vim.iter(registry.tab_list):find(function(tab)
    return tab.is_bound() and tab.start_token() == start_token
  end)
end

M.route_report = route_report
M.tab_for_work = tab_for_work

return M
