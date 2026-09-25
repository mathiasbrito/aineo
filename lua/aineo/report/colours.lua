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

--- Links each of aineo's Report groups to its default as a default
--- (`:highlight default`): a group a user or a colour scheme has coloured
--- keeps its colour.
local function link_groups_to_defaults()
  for group, link in pairs(DEFAULT_LINKS) do
    vim.api.nvim_set_hl(0, group, { link = link, default = true })
  end
end

--- Defines aineo's Report groups, each linked to its default unless a user or
--- a colour scheme has coloured it, and links them so again after every
--- `:colorscheme`, which may clear a group the scheme before it had coloured.
--- The autocommand doing so is in the group `aineo_report_colours`, created
--- anew with each call, so it is never defined twice.
function M.define_report_colours()
  link_groups_to_defaults()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('aineo_report_colours', {}),
    callback = link_groups_to_defaults,
  })
end

return M
