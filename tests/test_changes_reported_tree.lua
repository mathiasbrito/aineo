local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local report_rules = require('aineo.changes.reports')

--- The moment the reports of these cases are taken at, in seconds.
local NOW = 1800000000

--- Two full commit ids, the bases of the branches below.
local BASE, OTHER_BASE = ('a'):rep(40), ('b'):rep(40)

--- The worktrees `agent-1` on `feature/a` and `agent-2` on `feature/c`, as
--- git lists them.
local AGENT_1 = { top = '/projects/agent-1', branch = 'feature/a' }
local AGENT_2 = { top = '/projects/agent-2', branch = 'feature/c' }

--- The branch `name` made from `base`, `BASE` when not given.
---
---@param name string
---@param base? string
---@return aineo.changes.ReportedBranch
local function branch(name, base)
  return { name = name, base = base or BASE }
end

--- An agent's call for `worktree`, labelled `label`, listing `branches`,
--- taken at `at`.
---
---@param worktree table
---@param label string
---@param branches table[]
---@param at integer
---@return aineo.changes.NodeReport
local function call(worktree, label, branches, at)
  return { worktree = worktree, label = label, branches = branches, at = at }
end

--- The nodes `reports` make, taken one after another from none.
---
---@param reports aineo.changes.NodeReport[]
---@return aineo.changes.ReportedNode[]
local function taken(reports)
  local nodes = {}
  for _, report in ipairs(reports) do
    nodes = report_rules.with_report(nodes, report)
  end
  return nodes
end

local T = MiniTest.new_set()

T['an agent’s call'] = MiniTest.new_set()

T['an agent’s call']['for a worktree no node holds adds its node, its label and branches in their order'] = function()
  local nodes = taken({ call(AGENT_1, 'T111', { branch('feature/a'), branch('feature/b') }, NOW) })

  eq(nodes, {
    {
      worktree = AGENT_1,
      label = 'T111',
      at = NOW,
      branches = { branch('feature/a'), branch('feature/b') },
    },
  })
end

T['an agent’s call']['again for a worktree replaces its label and set, a branch left out leaving, and moves it last'] = function()
  local nodes = taken({
    call(AGENT_1, 'T111', { branch('feature/a'), branch('feature/b') }, NOW - 60),
    call(AGENT_2, 'T112', { branch('feature/c') }, NOW - 30),
    call(AGENT_1, 'T111 fix', { branch('feature/b', OTHER_BASE) }, NOW),
  })

  eq(nodes, {
    { worktree = AGENT_2, label = 'T112', at = NOW - 30, branches = { branch('feature/c') } },
    {
      worktree = AGENT_1,
      label = 'T111 fix',
      at = NOW,
      branches = { branch('feature/b', OTHER_BASE) },
    },
  })
end

T['an agent’s call']['listing no branch removes its worktree’s node'] = function()
  local nodes = taken({
    call(AGENT_1, 'T111', { branch('feature/a') }, NOW - 60),
    call(AGENT_2, 'T112', { branch('feature/c') }, NOW - 30),
    call(AGENT_1, 'T111', {}, NOW),
  })

  eq(nodes, {
    { worktree = AGENT_2, label = 'T112', at = NOW - 30, branches = { branch('feature/c') } },
  })
end

T['an agent’s call']['listing no branch for a worktree no node holds adds nothing'] = function()
  eq(taken({ call(AGENT_1, 'T111', {}, NOW) }), {})
end

T['an agent’s call']['leaves the nodes it is given as they were'] = function()
  local before = taken({ call(AGENT_1, 'T111', { branch('feature/a') }, NOW - 60) })
  local copy = vim.deepcopy(before)

  report_rules.with_report(before, call(AGENT_1, 'T111', { branch('feature/b') }, NOW))

  eq(before, copy)
end

--- A report of aineo's hook for `worktree`, of `branches`, taken at `at`.
---
---@param worktree table
---@param branches table[]
---@param at integer
---@return aineo.changes.NodeReport
local function hook(worktree, branches, at)
  return { worktree = worktree, branches = branches, at = at, by_hook = true }
end

T['a report of aineo’s hook'] = MiniTest.new_set()

T['a report of aineo’s hook']['in a reported worktree adds its branch beside the others, the label kept, and moves it last'] = function()
  local moved = { top = AGENT_1.top, branch = 'feature/new' }
  local nodes = taken({
    call(AGENT_1, 'T111', { branch('feature/a'), branch('feature/b') }, NOW - 60),
    call(AGENT_2, 'T112', { branch('feature/c') }, NOW - 30),
    hook(moved, { branch('feature/new', OTHER_BASE) }, NOW),
  })

  eq(nodes, {
    { worktree = AGENT_2, label = 'T112', at = NOW - 30, branches = { branch('feature/c') } },
    {
      worktree = moved,
      label = 'T111',
      at = NOW,
      branches = { branch('feature/a'), branch('feature/b'), branch('feature/new', OTHER_BASE) },
    },
  })
end

T['a report of aineo’s hook']['for a worktree no node holds adds a node with no label'] = function()
  local nodes = taken({ hook(AGENT_1, { branch('feature/a') }, NOW) })

  eq(nodes, { { worktree = AGENT_1, at = NOW, branches = { branch('feature/a') } } })
end

T['a report of aineo’s hook']['of a branch its worktree’s node holds changes nothing, its base and place kept'] = function()
  local before = taken({
    call(AGENT_1, 'T111', { branch('feature/a') }, NOW - 60),
    call(AGENT_2, 'T112', { branch('feature/c') }, NOW - 30),
  })

  local nodes =
    report_rules.with_report(before, hook(AGENT_1, { branch('feature/a', OTHER_BASE) }, NOW))

  eq(nodes, before)
end

T['a report of aineo’s hook']['listing no branch removes nothing'] = function()
  local before = taken({ call(AGENT_1, 'T111', { branch('feature/a') }, NOW - 60) })

  eq(report_rules.with_report(before, hook(AGENT_1, {}, NOW)), before)
end

T['the groups'] = MiniTest.new_set()

--- The node of the worktree `name`, labelled `label`, its last report
--- taken at `at`.
---
---@param name string
---@param label string|nil
---@param at integer|nil
---@return aineo.changes.ReportedNode
local function node(name, label, at)
  return {
    worktree = { top = '/projects/' .. name, branch = name },
    label = label,
    at = at,
    branches = { branch(name) },
  }
end

--- What `groups` hold: each group's label, or `false` for none, and the
--- names of its worktrees' folders, in their order.
---
---@param groups aineo.changes.ReportedGroup[]
---@return table[]
local function shapes_of(groups)
  return vim.tbl_map(function(group)
    return {
      group.label or false,
      vim.tbl_map(function(listed)
        return vim.fs.basename(listed.worktree.top)
      end, group.nodes),
    }
  end, groups)
end

T['the groups']['are one per label, newest first by their newest worktree, each worktree newest first, an untimed one last'] = function()
  local nodes = {
    node('a1', 'T111', NOW - 300),
    node('a2', 'T112', NOW - 200),
    node('a3', 'T111', NOW - 100),
    node('a4', nil, NOW - 50),
    node('a5', nil, nil),
    node('a6', 'T113', nil),
    node('a7', 'T112', NOW - 200),
  }

  local groups = report_rules.groups(nodes)

  eq(shapes_of(groups), {
    { false, { 'a4', 'a5' } },
    { 'T111', { 'a3', 'a1' } },
    { 'T112', { 'a7', 'a2' } },
    { 'T113', { 'a6' } },
  })
end

T['the groups']['tell the time of their newest report'] = function()
  local groups = report_rules.groups({ node('a1', 'T111', NOW - 300), node('a2', 'T111', NOW) })

  eq(groups[1].at, NOW)
end

T['what git lists'] = MiniTest.new_set()

--- What git lists: the worktrees `worktrees` and the local branches named
--- `names`.
---
---@param worktrees table[]
---@param names string[]
---@return aineo.changes.BranchCandidates
local function listing(worktrees, names)
  return {
    worktrees = worktrees,
    branches = vim.tbl_map(function(name)
      return { name = name }
    end, names),
  }
end

T['what git lists']['keeps every node and branch it still lists, each worktree as it lists it now, nothing dropped'] = function()
  local nodes = taken({
    call(AGENT_1, 'T111', { branch('feature/a'), branch('feature/b') }, NOW - 60),
    call(AGENT_2, 'T112', { branch('feature/c') }, NOW),
  })
  local switched = { top = AGENT_1.top, branch = 'feature/b' }

  local kept, dropped = report_rules.still_listed(
    nodes,
    listing({ AGENT_2, switched }, { 'feature/a', 'feature/b', 'feature/c' })
  )

  eq(kept, {
    {
      worktree = switched,
      label = 'T111',
      at = NOW - 60,
      branches = { branch('feature/a'), branch('feature/b') },
    },
    { worktree = AGENT_2, label = 'T112', at = NOW, branches = { branch('feature/c') } },
  })
  eq(dropped, false)
end

T['what git lists']['drops a branch it no longer lists, a worktree it no longer lists, and one with no branch left'] = function()
  local agent_3 = { top = '/projects/agent-3', branch = 'feature/d' }
  local nodes = taken({
    call(AGENT_1, 'T111', { branch('feature/a'), branch('feature/b') }, NOW - 60),
    call(AGENT_2, 'T112', { branch('feature/c') }, NOW - 30),
    call(agent_3, 'T113', { branch('feature/d') }, NOW),
  })

  local kept, dropped =
    report_rules.still_listed(nodes, listing({ AGENT_1, agent_3 }, { 'feature/a', 'feature/c' }))

  eq(kept, {
    { worktree = AGENT_1, label = 'T111', at = NOW - 60, branches = { branch('feature/a') } },
  })
  eq(dropped, true)
end

T['the lines'] = MiniTest.new_set()

--- The editor's own worktree's top level.
local OWN_TOP = '/projects/main'

T['the lines']['are each group’s label, its worktrees below, each worktree’s branches below it, with what each picks'] = function()
  local nodes = taken({
    call(AGENT_1, 'T111', { branch('feature/b'), branch('feature/a') }, NOW - 60),
    call(AGENT_2, 'T112', { branch('feature/c') }, NOW),
  })

  local lines = report_rules.tree_lines(nodes, OWN_TOP)

  eq(lines, {
    { depth = 0, group = report_rules.groups(nodes)[1], picks = { group = 'T112' } },
    { depth = 1, node = nodes[2], picks = { top = AGENT_2.top } },
    {
      depth = 2,
      node = nodes[2],
      branch = branch('feature/c'),
      checked_out = true,
      picks = { top = AGENT_2.top },
    },
    { depth = 0, group = report_rules.groups(nodes)[2], picks = { group = 'T111' } },
    { depth = 1, node = nodes[1], picks = { top = AGENT_1.top } },
    {
      depth = 2,
      node = nodes[1],
      branch = branch('feature/b'),
      checked_out = false,
      picks = { branch = 'feature/b' },
    },
    {
      depth = 2,
      node = nodes[1],
      branch = branch('feature/a'),
      checked_out = true,
      picks = { top = AGENT_1.top },
    },
  })
end

T['the lines']['pick the editor’s own worktree alone while its checked-out branch is reported, and an unlabelled group by its empty label'] = function()
  local own = { top = OWN_TOP, branch = 'main' }
  local nodes = taken({
    { worktree = own, branches = { branch('main'), branch('lonely') }, at = NOW, by_hook = true },
  })

  local picks = vim.tbl_map(function(line)
    return line.picks
  end, report_rules.tree_lines(nodes, OWN_TOP))

  eq(picks, {
    { group = '' },
    { top = OWN_TOP, own_worktree = true },
    { top = OWN_TOP, own_worktree = true },
    { branch = 'lonely' },
  })
end

T['the editor’s own checked-out branch'] = MiniTest.new_set()

T['the editor’s own checked-out branch']['is the branch reported of its worktree that it has checked out'] = function()
  local nodes = taken({
    call(AGENT_1, 'T', { branch('feature/a') }, NOW - 60),
    call(
      { top = OWN_TOP, branch = 'main' },
      'own',
      { branch('lonely'), branch('main', OTHER_BASE) },
      NOW
    ),
  })

  eq(report_rules.own_checked_out_branch(nodes, OWN_TOP), branch('main', OTHER_BASE))
end

T['the editor’s own checked-out branch']['is none while the branch it has checked out is not reported'] = function()
  local nodes =
    taken({ call({ top = OWN_TOP, branch = 'main' }, 'own', { branch('lonely') }, NOW) })

  eq(report_rules.own_checked_out_branch(nodes, OWN_TOP), nil)
end

T['the editor’s own checked-out branch']['is none while its worktree is detached'] = function()
  local nodes = taken({ call({ top = OWN_TOP }, 'own', { branch('main') }, NOW) })

  eq(report_rules.own_checked_out_branch(nodes, OWN_TOP), nil)
end

T['the editor’s own checked-out branch']['is none while its worktree is not reported'] = function()
  local nodes = taken({ call(AGENT_1, 'T', { branch('feature/a') }, NOW) })

  eq(report_rules.own_checked_out_branch(nodes, OWN_TOP), nil)
end

T['the lines']['pick the editor’s own work for its own worktree while no branch it has checked out is reported'] = function()
  local own = { top = OWN_TOP, branch = 'main' }
  local nodes =
    taken({ { worktree = own, branches = { branch('lonely') }, at = NOW, by_hook = true } })

  local picks = vim.tbl_map(function(line)
    return line.picks
  end, report_rules.tree_lines(nodes, OWN_TOP))

  eq(picks, { { group = '' }, { own = true }, { branch = 'lonely' } })
end

T['the lines']['of a detached worktree mark no branch checked out, and pick each branch alone'] = function()
  local detached = { top = '/projects/agent-3' }
  local nodes = taken({ call(detached, 'T', { branch('feature/d'), branch('feature/e') }, NOW) })

  local branch_lines = vim.list_slice(report_rules.tree_lines(nodes, OWN_TOP), 3, 4)

  eq(
    vim.tbl_map(function(line)
      return { line.checked_out, line.picks }
    end, branch_lines),
    { { false, { branch = 'feature/d' } }, { false, { branch = 'feature/e' } } }
  )
end

T['a group’s work'] = MiniTest.new_set()

T['a group’s work']['is each worktree but the editor’s own, then each of its branches it has not checked out, each once'] = function()
  local own = { top = OWN_TOP, branch = 'main' }
  local nodes = taken({
    call(own, 'T111', { branch('main'), branch('lonely') }, NOW - 120),
    call(AGENT_1, 'T111', { branch('feature/b'), branch('feature/a') }, NOW - 60),
    call(AGENT_2, 'T112', { branch('feature/c'), branch('lonely') }, NOW),
  })

  local work = report_rules.work_of(nodes, OWN_TOP)

  eq(work, {
    { top = AGENT_2.top },
    { branch = 'lonely' },
    { top = AGENT_1.top },
    { branch = 'feature/b' },
  })
end

T['a group’s work']['is that of the worktrees of one label, the empty one for those with none'] = function()
  local nodes = taken({
    call(AGENT_1, 'T111', { branch('feature/a') }, NOW - 60),
    { worktree = AGENT_2, branches = { branch('feature/c') }, at = NOW, by_hook = true },
  })

  eq(
    { report_rules.labelled(nodes, 'T111'), report_rules.labelled(nodes, '') },
    { { nodes[1] }, { nodes[2] } }
  )
end

T['reports kept before the tree'] = MiniTest.new_set()

T['reports kept before the tree']['load as nodes: a worktree with its branch, a branch under the worktree that has it checked out, else the main checkout'] = function()
  local main = { top = OWN_TOP, branch = 'main' }
  local detached = { top = '/projects/agent-3' }
  local kept = {
    { top = AGENT_1.top, kind = 'worktree', base = BASE, label = 'T108', at = NOW - 60 },
    { branch = 'feature/c', kind = 'branch', base = OTHER_BASE, label = 'T109', at = NOW - 30 },
    { branch = 'lonely', kind = 'branch', label = 'T110' },
    { top = detached.top, kind = 'worktree', base = BASE, label = 'T107' },
    { branch = 'feature/x', kind = 'branch', base = BASE },
  }
  local candidates = listing({ main, AGENT_1, AGENT_2, detached }, {
    'main',
    'feature/a',
    'feature/c',
    'lonely',
  })

  local nodes = report_rules.nodes_of_kept_reports(kept, candidates)

  eq(nodes, {
    { worktree = AGENT_1, label = 'T108', at = NOW - 60, branches = { branch('feature/a') } },
    {
      worktree = AGENT_2,
      label = 'T109',
      at = NOW - 30,
      branches = { branch('feature/c', OTHER_BASE) },
    },
    { worktree = main, label = 'T110', branches = { { name = 'lonely' } } },
  })
end

T['reports kept before the tree']['add a branch to the node a worktree report made, its label kept, each branch once'] = function()
  local kept = {
    { top = AGENT_1.top, kind = 'worktree', base = BASE, label = 'T108', at = NOW - 60 },
    { branch = 'feature/b', kind = 'branch', base = OTHER_BASE, label = 'other', at = NOW },
    { branch = 'feature/b', kind = 'branch', base = BASE, at = NOW },
  }
  local candidates = listing({ AGENT_1 }, { 'feature/a', 'feature/b' })

  local nodes = report_rules.nodes_of_kept_reports(kept, candidates)

  eq(nodes, {
    {
      worktree = AGENT_1,
      label = 'T108',
      at = NOW - 60,
      branches = { branch('feature/a'), branch('feature/b', OTHER_BASE) },
    },
  })
end

return T
