--- The rules of the changes pane's Reported section, pure functions of
--- what was reported: the tree of labels, worktrees and branches, the order
--- it lists them in, what a report does to it, what git no longer lists
--- drops from it, what each of its lines picks, and the base a reported
--- branch is read from.

local M = {}

--- What git says of a reported base, the tip of its work and the pane's own
--- base for that work.
---@class aineo.changes.BaseAncestry
---@field reported_in_tip boolean whether the reported base is an ancestor of the tip, or the tip itself
---@field own_before_reported boolean whether the pane's own base is an ancestor of the reported base, or that base itself

--- The base a reported worktree or branch is read from, of `reported`, the
--- base its report gave, and `own`, the one the pane reads for it without a
--- report: the reported base while it is behind the tip and descends from
--- the pane's own, or the pane has none; else the pane's own — the reported
--- base older than the pane's, unrelated to it, or no longer behind the tip
--- after a rebase, so that a pick never lists commits the agent did not make.
--- The pane's own for a report that gave no base.
---
---@param reported string|nil
---@param own string|nil
---@param ancestry aineo.changes.BaseAncestry
---@return string|nil
function M.effective_base(reported, own, ancestry)
  if not (reported and ancestry.reported_in_tip) then
    return own
  end
  if own == nil or ancestry.own_before_reported then
    return reported
  end
  return own
end

--- One branch an agent works on in a reported worktree: its name, and the
--- commit it was made from.
---@class aineo.changes.ReportedBranch
---@field name string the local branch's name
---@field base? string the full id of the commit the branch was made from; nil for a report kept before reports gave one

--- One worktree of the Reported section: the worktree as git listed it,
--- the agent's label for its task, when its last report was taken, and the
--- branches reported of it, in the order reported.
---@class aineo.changes.ReportedNode
---@field worktree aineo.git.Worktree the worktree as git listed it, the branch it has checked out included
---@field label? string the agent's short name for the task; nil until an agent's call gives one
---@field at? integer when its last report was taken, in seconds since the epoch; nil for a report kept before reports were timed
---@field branches aineo.changes.ReportedBranch[]

--- What one report says of one worktree git lists: the worktree, the label
--- and the branches, when it was taken, and whether aineo's own hook made
--- it, rather than the agent's call.
---@class aineo.changes.NodeReport
---@field worktree aineo.git.Worktree
---@field label? string
---@field branches aineo.changes.ReportedBranch[]
---@field at integer
---@field by_hook? boolean

--- `report`, one of aineo's hook, laid over `before`, the node of its
--- worktree: each branch it names that the node does not hold is added after
--- the node's own, which stay, as its label does; nil when it adds none.
---
---@param before aineo.changes.ReportedNode
---@param report aineo.changes.NodeReport
---@return aineo.changes.ReportedNode|nil
local function hook_report_over(before, report)
  local held = {}
  for _, listed in ipairs(before.branches) do
    held[listed.name] = true
  end
  local added = vim.tbl_filter(function(reported)
    return not held[reported.name]
  end, report.branches)
  if #added == 0 then
    return nil
  end
  return {
    worktree = report.worktree,
    label = before.label,
    at = report.at,
    branches = vim.list_extend(vim.deepcopy(before.branches), vim.deepcopy(added)),
  }
end

--- `nodes`, the Reported section's worktrees in the order their last
--- reports were taken, after `report`. An agent's call replaces the node of
--- its worktree, its label and every branch, and moves it last — or, listing
--- no branch, removes it. A report of aineo's hook adds each branch it names
--- that the node does not hold, the others and the label kept, and moves the
--- node last; it never removes a branch, and one that adds none changes
--- nothing. Either makes a node for a worktree none holds, with no label
--- from the hook. A new list of new nodes; `nodes` is left as it is.
---
---@param nodes aineo.changes.ReportedNode[]
---@param report aineo.changes.NodeReport
---@return aineo.changes.ReportedNode[]
function M.with_report(nodes, report)
  local top = report.worktree.top
  local before = vim.iter(nodes):find(function(node)
    return node.worktree.top == top
  end)
  local replacement
  if report.by_hook and before then
    replacement = hook_report_over(before, report)
    if not replacement then
      return vim.deepcopy(nodes)
    end
  elseif #report.branches > 0 then
    replacement = {
      worktree = report.worktree,
      label = report.label,
      at = report.at,
      branches = vim.deepcopy(report.branches),
    }
  end
  local kept = vim.tbl_filter(function(node)
    return node.worktree.top ~= top
  end, vim.deepcopy(nodes))
  if replacement then
    table.insert(kept, replacement)
  end
  return kept
end

--- `nodes`, in the order their last reports were taken, newest first: a
--- node kept before reports were timed after every timed one; of two taken
--- at the same second, or both untimed, the one taken later first. A new
--- list; `nodes` is left as it is.
---
---@param nodes aineo.changes.ReportedNode[]
---@return aineo.changes.ReportedNode[]
local function newest_nodes_first(nodes)
  local positions = {}
  for position, listed in ipairs(nodes) do
    positions[listed] = position
  end
  local ordered = vim.list_slice(nodes)
  table.sort(ordered, function(left, right)
    local left_at, right_at = left.at or -math.huge, right.at or -math.huge
    if left_at ~= right_at then
      return left_at > right_at
    end
    return positions[left] > positions[right]
  end)
  return ordered
end

--- The worktrees of one label in the Reported section.
---@class aineo.changes.ReportedGroup
---@field label? string the label they share; nil for those no agent's call labelled
---@field at? integer when the newest of them was reported; nil when none was timed
---@field nodes aineo.changes.ReportedNode[] newest first

--- `nodes` as the Reported section groups them: one group per label, those
--- with none together, the groups newest first by their newest worktree
--- and the worktrees of each newest first (`newest_nodes_first()`).
---
---@param nodes aineo.changes.ReportedNode[]
---@return aineo.changes.ReportedGroup[]
function M.groups(nodes)
  local groups, by_label = {}, {}
  for _, listed in ipairs(newest_nodes_first(nodes)) do
    local key = listed.label or ''
    local group = by_label[key]
    if not group then
      group = { label = listed.label, at = listed.at, nodes = {} }
      by_label[key] = group
      table.insert(groups, group)
    end
    table.insert(group.nodes, listed)
  end
  return groups
end

--- What a line of the Reported section, or its item in `s`, picks: the
--- worktrees of one label, by that label, the empty one for those with
--- none; one worktree, by its top level; the editor's own work, which the
--- default view shows; or a local branch, by its name.
---@class aineo.changes.TreePick
---@field group? string the label, `''` for the worktrees with none
---@field top? string
---@field own? boolean
---@field branch? string
---@field uncommitted? boolean whether the worktree's *Uncommitted* is chosen in place of its whole change, or the editor's own in place of *Session work*: the pick of the *Uncommitted* line under a branch a worktree has checked out

--- One line of the Reported section, by its depth: a group's label line
--- (0), a worktree's line (1) or a branch's (2), with what it shows and
--- what it picks.
---@class aineo.changes.TreeLine
---@field depth 0|1|2
---@field group? aineo.changes.ReportedGroup the group, on its label line
---@field node? aineo.changes.ReportedNode the worktree, on its line and on its branches'
---@field branch? aineo.changes.ReportedBranch the branch, on its line
---@field checked_out? boolean on a branch's line, whether its worktree has it checked out now
---@field picks aineo.changes.TreePick
---@field read_base? string on a branch's line, the base its work was last read from, which the pane gives once it has read it
---@field commits? aineo.git.Commit[] on a branch's line, the commits from `read_base` to the branch's tip, newest first, which the pane gives once it has read them
---@field worktree_section? aineo.changes.WorktreeSection on a branch's line, the worktree other than the editor's that has the branch checked out, whichever worktree the line stands under, as the commits window last listed it, which the pane gives: the commits are read in it

--- What the line of `node` picks: its worktree, or the editor's own work
--- when it is the editor's own worktree, `own_top`.
---
---@param node aineo.changes.ReportedNode
---@param own_top string
---@return aineo.changes.TreePick
local function worktree_pick(node, own_top)
  if node.worktree.top == own_top then
    return { own = true }
  end
  return { top = node.worktree.top }
end

--- The lines of the Reported section for `nodes`, in its order
--- (`M.groups()`): each group's label line, then, for each of its
--- worktrees, its line and a line per branch, in the order reported. A
--- label line picks its group; a worktree's line its worktree, or the
--- editor's own work for `own_top`; a branch's line picks as its worktree's
--- does while that worktree has it checked out, its uncommitted changes
--- with it, else the branch alone.
---
---@param nodes aineo.changes.ReportedNode[]
---@param own_top string the editor's own worktree's top level
---@return aineo.changes.TreeLine[]
function M.tree_lines(nodes, own_top)
  local lines = {}
  for _, group in ipairs(M.groups(nodes)) do
    table.insert(lines, { depth = 0, group = group, picks = { group = group.label or '' } })
    for _, listed in ipairs(group.nodes) do
      table.insert(lines, { depth = 1, node = listed, picks = worktree_pick(listed, own_top) })
      for _, reported in ipairs(listed.branches) do
        local checked_out = reported.name == listed.worktree.branch
        table.insert(lines, {
          depth = 2,
          node = listed,
          branch = reported,
          checked_out = checked_out,
          picks = checked_out and worktree_pick(listed, own_top) or { branch = reported.name },
        })
      end
    end
  end
  return lines
end

--- The nodes of `nodes` labelled `label`, `''` for those with none, in
--- their order.
---
---@param nodes aineo.changes.ReportedNode[]
---@param label string
---@return aineo.changes.ReportedNode[]
function M.labelled(nodes, label)
  return vim.tbl_filter(function(listed)
    return (listed.label or '') == label
  end, nodes)
end

--- What the focused view shows of `nodes`, in the Reported section's order
--- (`M.groups()`), each once: each worktree, by its top level, but the
--- editor's own, `own_top`, whose work the default view shows; then each
--- branch of it that it has not checked out, by its name, read alone.
---
---@param nodes aineo.changes.ReportedNode[]
---@param own_top string
---@return aineo.changes.TreePick[]
function M.work_of(nodes, own_top)
  local work, seen = {}, {}
  local function add(pick, key)
    if not seen[key] then
      seen[key] = true
      table.insert(work, pick)
    end
  end
  for _, group in ipairs(M.groups(nodes)) do
    for _, listed in ipairs(group.nodes) do
      if listed.worktree.top ~= own_top then
        add({ top = listed.worktree.top }, 'worktree\0' .. listed.worktree.top)
      end
      for _, reported in ipairs(listed.branches) do
        if reported.name ~= listed.worktree.branch then
          add({ branch = reported.name }, 'branch\0' .. reported.name)
        end
      end
    end
  end
  return work
end

--- The nodes of `nodes` that `candidates`, what git now lists, still
--- lists, in their order, each with its worktree as git now lists it, the
--- branch it has checked out included, and with the branches git still
--- lists as local branches; a node whose worktree git no longer lists, or
--- with no branch left, is dropped. Returns too whether anything was
--- dropped, a node or a branch. A new list; `nodes` is left as it is.
---
---@param nodes aineo.changes.ReportedNode[]
---@param candidates aineo.changes.BranchCandidates
---@return aineo.changes.ReportedNode[] kept
---@return boolean dropped
function M.still_listed(nodes, candidates)
  local worktrees_by_top, branch_names = {}, {}
  for _, worktree in ipairs(candidates.worktrees) do
    worktrees_by_top[worktree.top] = worktree
  end
  for _, listed_branch in ipairs(candidates.branches) do
    branch_names[listed_branch.name] = true
  end
  local kept, dropped = {}, false
  for _, listed in ipairs(nodes) do
    local branches = vim.tbl_filter(function(reported)
      return branch_names[reported.name] == true
    end, listed.branches)
    local worktree = worktrees_by_top[listed.worktree.top]
    dropped = dropped or #branches < #listed.branches
    if worktree and #branches > 0 then
      table.insert(kept, {
        worktree = worktree,
        label = listed.label,
        at = listed.at,
        branches = vim.deepcopy(branches),
      })
    else
      dropped = true
    end
  end
  return kept, dropped
end

--- `kept`, reports kept before reports were a tree, as nodes, as git now
--- lists the worktrees and branches, `candidates` (`M.still_listed()`): a
--- worktree's report is a node of that worktree, its label and time kept,
--- with the branch it has checked out now and the report's base, or no
--- branch when it is detached; a branch's report is that branch, with its
--- base, in the node of the worktree that has it checked out, else of the
--- repository's main checkout, the first worktree git lists — a node made
--- for it taking its label and time. Nodes keep the order of the reports
--- that made them; a node with no branch, or one git no longer lists, is
--- dropped, as is a branch git no longer lists.
---
---@param kept aineo.changes.KeptReport[]
---@param candidates aineo.changes.BranchCandidates
---@return aineo.changes.ReportedNode[]
function M.nodes_of_kept_reports(kept, candidates)
  local nodes, by_top = {}, {}
  local function node_for(worktree, report)
    if not by_top[worktree.top] then
      by_top[worktree.top] =
        { worktree = worktree, label = report.label, at = report.at, branches = {} }
      table.insert(nodes, by_top[worktree.top])
    end
    return by_top[worktree.top]
  end
  for _, report in ipairs(kept) do
    local worktree, name
    if report.top then
      worktree = vim.iter(candidates.worktrees):find(function(listed)
        return listed.top == report.top
      end)
      name = worktree and worktree.branch
    else
      worktree = vim.iter(candidates.worktrees):find(function(listed)
        return listed.branch == report.branch
      end) or candidates.worktrees[1]
      name = report.branch
    end
    if worktree then
      local listed = node_for(worktree, report)
      local held = vim.iter(listed.branches):any(function(reported)
        return reported.name == name
      end)
      if name and not held then
        table.insert(listed.branches, { name = name, base = report.base })
      end
    end
  end
  return (M.still_listed(nodes, candidates))
end

return M
