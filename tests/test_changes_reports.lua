local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local lines = require('aineo.changes.lines')
local report_rules = require('aineo.changes.reports')
local scope = require('aineo.changes.scope')

--- The moment the ages of these cases are counted to.
local NOW = 1800000000

--- A full commit id, the base of the reports below.
local BASE = '0123456789abcdef0123456789abcdef01234567'

--- The editor's own worktree's top level.
local OWN_TOP = '/projects/main'

--- The worktree `agent-1` on `feature/a`, as git lists it.
local AGENT = { top = '/projects/agent-1', branch = 'feature/a' }

--- The nodes of the Reported section: the worktree `agent-1`, labelled
--- `T111 reported tree` and reported 5 minutes ago, with the branches
--- `feature/b`, not checked out, and `feature/a`, checked out; and the
--- worktree `agent-2`, on `feature/c`, that aineo's hook reported 2 hours
--- ago, with no base for its branch.
local NODES = {
  {
    worktree = AGENT,
    label = 'T111 reported tree',
    at = NOW - 300,
    branches = { { name = 'feature/b', base = BASE }, { name = 'feature/a', base = BASE } },
  },
  {
    worktree = { top = '/projects/agent-2', branch = 'feature/c' },
    at = NOW - 2 * 3600,
    branches = { { name = 'feature/c' } },
  },
}

--- What the commits window knows of a session with no commit and no other
--- worktree, the lines of the Reported section `reported` given.
---
---@param reported aineo.changes.TreeLine[]
---@return aineo.changes.CommitsView
local function view_with(reported)
  return {
    lists_filters = true,
    since = { commits = {}, base_is_ancestor = true },
    worktrees = { sections = {} },
    reported = reported,
    now = NOW,
  }
end

local T = MiniTest.new_set()

T['the Reported section'] = MiniTest.new_set()

T['the Reported section']['is not listed while the session has no report'] = function()
  local page = lines.commits_window(view_with({}))

  eq(page.text, { 'Uncommitted', 'Session work', 'No commits on this session' })
end

T['the Reported section']['lists the tree above Uncommitted: each label, its worktrees below, their branches below them'] = function()
  local page = lines.commits_window(view_with(report_rules.tree_lines(NODES, OWN_TOP)))

  eq(page.text, {
    'Reported',
    'T111 reported tree 5m',
    '  agent-1',
    '    feature/b from 0123456',
    '    feature/a * from 0123456',
    '(no label) 2h',
    '  agent-2',
    '    feature/c * from ?',
    'Uncommitted',
    'Session work',
    'No commits on this session',
  })
end

T['the Reported section']['colours its heading, each label and age, worktree, branch and base in their groups'] = function()
  local page = lines.commits_window(view_with(report_rules.tree_lines(NODES, OWN_TOP)))

  eq(vim.list_slice(page.colours, 1, 8), {
    { { first_column = 0, end_column = 8, group = 'AineoChangesReportedHeading' } },
    {
      { first_column = 0, end_column = 18, group = 'AineoChangesReportedLabel' },
      { first_column = 19, end_column = 21, group = 'AineoChangesReportedAge' },
    },
    { { first_column = 2, end_column = 9, group = 'AineoChangesReportedWorktree' } },
    {
      { first_column = 4, end_column = 13, group = 'AineoChangesReportedBranch' },
      { first_column = 19, end_column = 26, group = 'AineoChangesCommitId' },
    },
    {
      { first_column = 4, end_column = 13, group = 'AineoChangesReportedBranch' },
      { first_column = 21, end_column = 28, group = 'AineoChangesCommitId' },
    },
    {
      { first_column = 0, end_column = 10, group = 'AineoChangesReportedLabel' },
      { first_column = 11, end_column = 13, group = 'AineoChangesReportedAge' },
    },
    { { first_column = 2, end_column = 9, group = 'AineoChangesReportedWorktree' } },
    { { first_column = 4, end_column = 13, group = 'AineoChangesReportedBranch' } },
  })
end

T['the Reported section']['lists on each line what it chooses, and what Enter picks'] = function()
  local tree = report_rules.tree_lines(NODES, OWN_TOP)

  local page = lines.commits_window(view_with(tree))

  eq(vim.list_slice(page.entries, 2, 5), {
    { picks = { group = 'T111 reported tree', text = '[reported] T111 reported tree 5m' } },
    {
      key = '/projects/agent-1\0\0worktree',
      filter = { kind = 'worktree', worktree = AGENT },
      worktree = AGENT,
      picks = { top = AGENT.top, text = '[reported]   agent-1' },
    },
    {
      key = '\0branch\0feature/b',
      filter = { kind = 'branch', branch = 'feature/b' },
      picks = { branch = 'feature/b', text = '[reported]     feature/b from 0123456' },
    },
    {
      key = '/projects/agent-1\0\0worktree',
      filter = { kind = 'worktree', worktree = AGENT },
      worktree = AGENT,
      picks = { top = AGENT.top, text = '[reported]     feature/a * from 0123456' },
    },
  })
end

T['the Reported section']['chooses the editor’s own work on its own worktree’s lines'] = function()
  local own = {
    worktree = { top = OWN_TOP, branch = 'main' },
    at = NOW,
    branches = { { name = 'main', base = BASE } },
  }

  local page = lines.commits_window(view_with(report_rules.tree_lines({ own }, OWN_TOP)))

  eq({ page.entries[3], page.entries[4] }, {
    {
      key = '\0session_work',
      filter = { kind = 'session_work' },
      picks = { own = true, text = '[reported]   main' },
    },
    {
      key = '\0session_work',
      filter = { kind = 'session_work' },
      picks = { own = true, text = '[reported]     main * from 0123456' },
    },
  })
end

T['the Reported section']['shows each branch’s base its work was last read from, in place of the reported one'] = function()
  local read_from = ('c'):rep(40)
  local tree = report_rules.tree_lines(NODES, OWN_TOP)
  tree[3].read_base = read_from

  local page = lines.commits_window(view_with(tree))

  eq(
    { page.text[4], page.text[5] },
    { '    feature/b from ccccccc', '    feature/a * from 0123456' }
  )
end

T['the Reported section']['quotes a folder’s and a branch’s name as a path, and shows a control character of the label as a space'] = function()
  local nodes = {
    {
      worktree = { top = '/projects/agent\n3', branch = 'odd\tname' },
      label = 'a\tb\27c',
      branches = { { name = 'odd\tname', base = BASE } },
    },
  }

  local page = lines.commits_window(view_with(report_rules.tree_lines(nodes, OWN_TOP)))

  eq(vim.list_slice(page.text, 2, 4), {
    'a b c',
    '  "agent\\n3"',
    '    "odd\\tname" * from 0123456',
  })
end

T['the list s offers'] = MiniTest.new_set()

T['the list s offers']['holds the tree first, each item as its line, then all reported work, then the worktrees and branches'] = function()
  local report_items = vim.tbl_map(function(line)
    return lines.report_item(line, NOW)
  end, report_rules.tree_lines(NODES, OWN_TOP))
  local others = { sections = { AGENT } }
  local candidates = {
    branches = { { name = 'main' }, { name = 'feature/b' }, { name = 'lonely' } },
    worktrees = { { top = '/projects/main', branch = 'main' }, AGENT },
  }

  local items = scope.items_of(others, candidates, #NODES, report_items)

  eq(
    vim.tbl_map(function(item)
      return item.text
    end, items),
    {
      '[reported] T111 reported tree 5m',
      '[reported]   agent-1',
      '[reported]     feature/b from 0123456',
      '[reported]     feature/a * from 0123456',
      '[reported] (no label) 2h',
      '[reported]   agent-2',
      '[reported]     feature/c * from ?',
      '[reported] All reported work (2)',
      '[worktree] agent-1 (feature/a)',
      '[branch] feature/b',
      '[branch] lonely',
    }
  )
end

T['the base a report is read from'] = MiniTest.new_set()

--- Two commits: the base an agent reported, and the pane's own base for the
--- same work.
local REPORTED, OWN = ('a'):rep(40), ('b'):rep(40)

T['the base a report is read from']['is the reported one or the pane’s own, as their history says'] =
  MiniTest.new_set({
    parametrize = {
      {
        'the reported base descends from the pane’s',
        REPORTED,
        OWN,
        { reported_in_tip = true, own_before_reported = true },
        REPORTED,
      },
      {
        'the pane’s base descends from the reported one',
        REPORTED,
        OWN,
        { reported_in_tip = true, own_before_reported = false },
        OWN,
      },
      {
        'the reported base is no longer behind the tip',
        REPORTED,
        OWN,
        { reported_in_tip = false, own_before_reported = true },
        OWN,
      },
    },
  })

T['the base a report is read from']['is the reported one where the pane has no base of its own'] = function()
  eq(
    report_rules.effective_base(
      REPORTED,
      nil,
      { reported_in_tip = true, own_before_reported = false }
    ),
    REPORTED
  )
end

T['the base a report is read from']['is the reported one or the pane’s own, as their history says']['when'] = function(
  _,
  reported,
  own,
  ancestry,
  expected
)
  eq(report_rules.effective_base(reported, own, ancestry), expected)
end

T['the base a report is read from']['is the pane’s own for a report that gave none'] = function()
  eq(
    report_rules.effective_base(nil, OWN, { reported_in_tip = false, own_before_reported = false }),
    OWN
  )
end

return T
