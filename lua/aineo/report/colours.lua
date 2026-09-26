--- The Report's colours: the highlight groups a report's icon, time, status
--- and web links show in, and the groups each links to unless a user or a
--- colour scheme colours it.

local M = {}

--- The group a report's `HH:MM` shows in.
M.TIME_GROUP = 'AineoReportTime'

--- The group a report's icon and `[status]` show in, by status.
M.STATUS_GROUPS = {
  started = 'AineoReportStarted',
  progress = 'AineoReportProgress',
  blocked = 'AineoReportBlocked',
  done = 'AineoReportDone',
  failed = 'AineoReportFailed',
}

--- The group a web link in a report shows in.
M.LINK_GROUP = 'AineoReportLink'

--- The group each of aineo's groups links to by default.
local DEFAULT_LINKS = {
  [M.TIME_GROUP] = 'Comment',
  [M.LINK_GROUP] = 'Underlined',
  [M.STATUS_GROUPS.started] = 'DiagnosticInfo',
  [M.STATUS_GROUPS.progress] = 'DiagnosticHint',
  [M.STATUS_GROUPS.blocked] = 'DiagnosticWarn',
  [M.STATUS_GROUPS.done] = 'DiagnosticOk',
  [M.STATUS_GROUPS.failed] = 'DiagnosticError',
}

--- Defines aineo's Report groups, each linked to its default as a default
--- (`:highlight default link`). A group a user or a colour scheme has
--- coloured keeps its colour. `:highlight clear`, which a colour scheme runs
--- first, restores each group's default link, and Neovim keeps only the first
--- default link a group is given: aineo's, unless a user or a colour scheme
--- gave the group one of its own before aineo first defined it. Such a group
--- goes back to that link at each `:highlight clear`, and defining the groups
--- again links it to aineo's default until the next one. No autocommand
--- restores the groups.
function M.define_report_colours()
  for group, link in pairs(DEFAULT_LINKS) do
    vim.cmd.highlight({ 'default', 'link', group, link })
  end
end

return M
