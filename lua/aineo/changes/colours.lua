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

--- The group a commit's author name shows in.
M.COMMIT_AUTHOR_GROUP = 'AineoChangesCommitAuthor'

--- The group a commit's age shows in.
M.COMMIT_AGE_GROUP = 'AineoChangesCommitAge'

--- The group the commits window's two fixed lines and its Landed heading,
--- and the files window's first line, show in, whole.
M.FILTER_GROUP = 'AineoChangesFilter'

--- The group the commits window's Reported heading shows in, whole.
M.REPORTED_HEADING_GROUP = 'AineoChangesReportedHeading'

--- The group a label shows in, in the Reported section.
M.REPORTED_LABEL_GROUP = 'AineoChangesReportedLabel'

--- The group the age of a label's newest report shows in.
M.REPORTED_AGE_GROUP = 'AineoChangesReportedAge'

--- The group a reported worktree's folder shows in.
M.REPORTED_WORKTREE_GROUP = 'AineoChangesReportedWorktree'

--- The group a reported branch's name shows in.
M.REPORTED_BRANCH_GROUP = 'AineoChangesReportedBranch'

--- The group a line that lists nothing shows in, whole.
M.NOTE_GROUP = 'AineoChangesNote'

--- The group a line that tells a failure shows in, whole.
M.FAILURE_GROUP = 'AineoChangesFailure'

--- The group a commit's age shows in, between its parentheses, in the
--- commit graph.
M.GRAPH_AGE_GROUP = 'AineoChangesGraphAge'

--- The group a commit's author name shows in, in the commit graph.
M.GRAPH_AUTHOR_GROUP = 'AineoChangesGraphAuthor'

--- The group the names that point at a commit show in, between their
--- parentheses, in the commit graph.
M.GRAPH_REF_GROUP = 'AineoChangesGraphRef'

--- The groups the lanes of the commit graph show in, the first lane's
--- first, cycled from the seventh lane on.
---@type string[]
M.GRAPH_LANE_GROUPS = {
  'AineoChangesGraphLane1',
  'AineoChangesGraphLane2',
  'AineoChangesGraphLane3',
  'AineoChangesGraphLane4',
  'AineoChangesGraphLane5',
  'AineoChangesGraphLane6',
}

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
  [M.COMMIT_AUTHOR_GROUP] = 'Identifier',
  [M.COMMIT_AGE_GROUP] = 'Comment',
  [M.FILTER_GROUP] = 'Title',
  [M.REPORTED_HEADING_GROUP] = 'Title',
  [M.REPORTED_LABEL_GROUP] = 'Identifier',
  [M.REPORTED_AGE_GROUP] = 'Comment',
  [M.REPORTED_WORKTREE_GROUP] = 'Directory',
  [M.REPORTED_BRANCH_GROUP] = 'Label',
  [M.NOTE_GROUP] = 'Comment',
  [M.FAILURE_GROUP] = 'DiagnosticWarn',
  [M.GRAPH_AGE_GROUP] = 'String',
  [M.GRAPH_AUTHOR_GROUP] = 'Comment',
  [M.GRAPH_REF_GROUP] = 'Label',
  [M.GRAPH_LANE_GROUPS[1]] = 'Identifier',
  [M.GRAPH_LANE_GROUPS[2]] = 'String',
  [M.GRAPH_LANE_GROUPS[3]] = 'Function',
  [M.GRAPH_LANE_GROUPS[4]] = 'Type',
  [M.GRAPH_LANE_GROUPS[5]] = 'Constant',
  [M.GRAPH_LANE_GROUPS[6]] = 'Statement',
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
