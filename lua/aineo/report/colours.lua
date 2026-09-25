--- The Report's colours: the highlight groups a report's time and status
--- show in, and the groups each links to unless a user or a colour scheme
--- colours it.

local M = {}

--- The group a report's `HH:MM` shows in.
M.TIME_GROUP = 'AineoReportTime'

--- The group a report's `[status]` shows in, by status.
M.STATUS_GROUPS = {
  started = 'AineoReportStarted',
  progress = 'AineoReportProgress',
  blocked = 'AineoReportBlocked',
  done = 'AineoReportDone',
  failed = 'AineoReportFailed',
}

--- The group each of aineo's groups links to by default.
local DEFAULT_LINKS = {
  [M.TIME_GROUP] = 'Comment',
  [M.STATUS_GROUPS.started] = 'DiagnosticInfo',
  [M.STATUS_GROUPS.progress] = 'DiagnosticHint',
  [M.STATUS_GROUPS.blocked] = 'DiagnosticWarn',
  [M.STATUS_GROUPS.done] = 'DiagnosticOk',
  [M.STATUS_GROUPS.failed] = 'DiagnosticError',
}

--- Defines aineo's Report groups, each linked to its default as a default
--- (`:highlight default link`). A group a user or a colour scheme has
--- coloured keeps its colour. `:highlight clear`, which a colour scheme runs
--- first, links each group to its default again, whoever coloured it before,
--- so no autocommand is needed to restore them. Defining them again changes
--- nothing.
function M.define_report_colours()
  for group, link in pairs(DEFAULT_LINKS) do
    vim.cmd.highlight({ 'default', 'link', group, link })
  end
end

return M
