--- The changes pane's colours: the highlight groups its lines show in, and
--- the group each links to unless a user or a colour scheme colours it.

local M = {}

--- The group a file's letter and path show in, by the kind of its change.
---@type table<string, string>
M.KIND_GROUPS = {
  added = 'AineoChangesAdded',
  modified = 'AineoChangesModified',
  deleted = 'AineoChangesDeleted',
  renamed = 'AineoChangesRenamed',
  type_changed = 'AineoChangesTypeChanged',
  untracked = 'AineoChangesUntracked',
}

--- The group the `*` of a file the user saved shows in.
M.SAVED_GROUP = 'AineoChangesSaved'

--- The group a commit's abbreviated id shows in.
M.COMMIT_ID_GROUP = 'AineoChangesCommitId'

--- The group a commit's subject shows in.
M.COMMIT_SUBJECT_GROUP = 'AineoChangesCommitSubject'

--- The group a line that lists nothing shows in, whole.
M.NOTE_GROUP = 'AineoChangesNote'

--- The group a line that tells a failure shows in, whole.
M.FAILURE_GROUP = 'AineoChangesFailure'

--- The group each linked group of the pane links to by default.
---@type table<string, string>
local DEFAULT_LINKS = {
  [M.KIND_GROUPS.added] = 'Added',
  [M.KIND_GROUPS.untracked] = 'Added',
  [M.KIND_GROUPS.modified] = 'Changed',
  [M.KIND_GROUPS.renamed] = 'Changed',
  [M.KIND_GROUPS.type_changed] = 'Changed',
  [M.KIND_GROUPS.deleted] = 'Removed',
  [M.SAVED_GROUP] = 'WarningMsg',
  [M.COMMIT_ID_GROUP] = 'Identifier',
  [M.NOTE_GROUP] = 'Comment',
  [M.FAILURE_GROUP] = 'DiagnosticWarn',
}

--- Defines the pane's groups: each in `DEFAULT_LINKS` linked to its default
--- as a default (`:highlight default link`), and the subject's empty, as a
--- default, so that a subject shows in the colours of the window it is in,
--- a window not current dimmed by `NormalNC` included. A group a user or a
--- colour scheme has coloured keeps its colour. `:highlight clear`, which a
--- colour scheme runs first, gives each group its default again: its first
--- default link, which is aineo's unless a user or a colour scheme gave the
--- group one before aineo first defined it, or the subject's empty group.
function M.define_changes_colours()
  for group, link in pairs(DEFAULT_LINKS) do
    vim.cmd.highlight({ 'default', 'link', group, link })
  end
  vim.api.nvim_set_hl(0, M.COMMIT_SUBJECT_GROUP, { default = true })
end

return M
