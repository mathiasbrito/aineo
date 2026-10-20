--- The rules of the changes pane's scope, pure functions of what the pane
--- knows: the list `s` offers, from the other worktrees the commits window
--- last listed and the local branches read when `s` is pressed, and what
--- the pane shows alone once one is picked.

local filter = require('aineo.changes.filter')
local lines = require('aineo.changes.lines')

local M = {}

--- What the picker `s` opens is titled.
M.PROMPT = 'Show alone in the changes pane'

--- What the user is told when the list `s` would offer is empty.
M.NONE_TO_SHOW = 'aineo: no other worktree or branch to show alone'

--- What the pane shows alone once the user picked it: one other worktree, or
--- one local branch; one of `top` and `branch` is given.
---@class aineo.changes.Scope
---@field top? string the top level of the worktree
---@field branch? string the name of the branch
---@field heading string the worktree's heading as the commits window last listed it, or `Branch ` and the branch's name

--- One choice of the list `s` offers: a worktree, by its top level, a local
--- branch, by its name, or the reported set.
---@class aineo.changes.ScopeItem
---@field top? string the top level of the worktree it shows alone
---@field branch? string the name of the branch it shows alone
---@field reported? boolean whether it shows the reported set
---@field text string how the picker shows it: its kind, then its name

--- What the list `s` chooses its branches from, read when `s` is pressed.
---@class aineo.changes.BranchCandidates
---@field branches aineo.git.Branch[] the local branches, newest commit first
---@field worktrees aineo.git.Worktree[] every worktree of the repository, the editor's own among them, with the branch each is on
---@field working_branch? string the working branch's name, as the setting names it or as the remote's default branch is named; nil when there is none

--- Whether the branch `name` is the working branch `working`, their short
--- names compared: `origin/dev` is `dev`. The setting may spell the name as
--- git reads one: `refs/heads/dev` and `heads/dev` are the local branch
--- `dev` alone; `refs/remotes/origin/dev` and `remotes/origin/dev` are
--- `origin/dev`. A working branch that names a local branch is that branch
--- alone; otherwise its first component is the remote's name, left off.
---
---@param name string
---@param working string|nil
---@param listed table<string, true> the names of the local branches
---@return boolean
local function is_working_branch(name, working, listed)
  if not working then
    return false
  end
  local local_branch = working:match('^refs/heads/(.+)$') or working:match('^heads/(.+)$')
  if local_branch then
    return name == local_branch
  end
  working = working:match('^refs/remotes/(.+)$') or working:match('^remotes/(.+)$') or working
  if name == working then
    return true
  end
  return not listed[working] and name == working:match('^[^/]+/(.+)$')
end

--- The branches `candidates` offers to show alone, in their order: the local
--- branches no worktree has checked out, the editor's own included, other
--- than the working branch.
---
---@param candidates aineo.changes.BranchCandidates
---@return aineo.git.Branch[]
local function branches_offered(candidates)
  local checked_out, listed = {}, {}
  for _, worktree in ipairs(candidates.worktrees) do
    if worktree.branch then
      checked_out[worktree.branch] = true
    end
  end
  for _, branch in ipairs(candidates.branches) do
    listed[branch.name] = true
  end
  return vim.tbl_filter(function(branch)
    return not checked_out[branch.name]
      and not is_working_branch(branch.name, candidates.working_branch, listed)
  end, candidates.branches)
end

--- The list `s` offers: first `report_items`, the item of each report, in
--- their order (`aineo.changes.lines`' `report_item()`); then, while
--- `reported`, the reported set, is not empty, its one item, `[reported]
--- All reported work (<n>)`; then one item per worktree of `others`, what
--- the commits window last listed of the other worktrees, in the order
--- listed, then one per branch of `candidates` that is offered
--- (`branches_offered()`), in the order given. `candidates` is nil when the
--- branches could not be read: the worktrees alone.
---
---@param others aineo.changes.OtherWorktrees
---@param candidates aineo.changes.BranchCandidates|nil
---@param reported aineo.changes.ScopeMember[]
---@param report_items aineo.changes.ScopeItem[]
---@return aineo.changes.ScopeItem[]
function M.items_of(others, candidates, reported, report_items)
  local items = vim.list_slice(report_items)
  if #reported > 0 then
    table.insert(items, {
      reported = true,
      text = ('[reported] All reported work (%d)'):format(#reported),
    })
  end
  vim.list_extend(
    items,
    vim.tbl_map(function(section)
      return { top = section.top, text = '[worktree] ' .. lines.worktree_name(section) }
    end, others.sections)
  )
  for _, branch in ipairs(candidates and branches_offered(candidates) or {}) do
    table.insert(
      items,
      { branch = branch.name, text = '[branch] ' .. lines.quoted_path(branch.name) }
    )
  end
  return items
end

--- What the pane knows when the user asks for the list.
---@class aineo.changes.OfferedFrom
---@field has_repository boolean whether the session's repository was found
---@field absence? aineo.git.Failure why no repository was found, when none was
---@field directory string the directory the session looked in
---@field others aineo.changes.OtherWorktrees what the commits window last listed of the other worktrees
---@field others_read boolean whether the commits window has read the other worktrees once

--- Why `s` cannot read what it offers, when it cannot: the words to tell the
--- user. With no repository, or the other worktrees not read yet, they are
--- the words the windows show; with the other worktrees not listed and none
--- known, the words the commits window shows, as nothing then says which
--- branches are checked out.
---
---@param known aineo.changes.OfferedFrom
---@return string|nil
function M.why_not_ready(known)
  if not known.has_repository then
    if not known.absence then
      return lines.READING
    end
    local page = lines.no_repository(known.absence, known.directory)
    return 'aineo: ' .. table.concat(page.text, '; ')
  end
  if not known.others_read then
    return lines.READING
  end
  if #known.others.sections == 0 and known.others.failure then
    return 'aineo: ' .. lines.worktrees_unlisted(known.others.failure)
  end
  return nil
end

--- The words that tell the user `failure`, why the local branches could not
--- be listed, which leaves the worktrees alone.
---
---@param failure aineo.git.Failure
---@return string
function M.branches_unlisted(failure)
  return 'aineo: the local branches could not be listed: ' .. lines.words_of(failure)
end

--- Whether `page`, a commits window's page, lists the line of `selected`, a
--- filter.
---
---@param page aineo.changes.Page
---@param selected aineo.changes.Filter
---@return boolean
function M.page_lists(page, selected)
  local key = filter.key(selected)
  for _, entry in pairs(page.entries) do
    if entry.key == key then
      return true
    end
  end
  return false
end

--- The words that tell the user `failure`, what the picker raised: its first
--- line, without the position of the Lua that raised it.
---
---@param failure any
---@return string
function M.picker_failed(failure)
  local line = tostring(failure):match('^[^\n]*'):gsub('^%S-%.lua:%d+: ', '')
  return 'aineo: ' .. line
end

--- The section of `others`, what the commits window last listed of the
--- other worktrees, whose top level is `top`; nil when it lists none.
---
---@param others aineo.changes.OtherWorktrees
---@param top string
---@return aineo.changes.WorktreeSection|nil
function M.section_on(others, top)
  return vim.iter(others.sections):find(function(section)
    return section.top == top
  end)
end

--- The scope that shows `section`, a worktree, alone.
---
---@param section aineo.changes.WorktreeSection
---@return aineo.changes.Scope
function M.of(section)
  return { top = section.top, heading = lines.worktree_heading(section) }
end

--- The scope that shows the local branch `name` alone.
---
---@param name string
---@return aineo.changes.Scope
function M.of_branch(name)
  return { branch = name, heading = lines.filter_name(filter.of_branch(name)) }
end

--- The words that tell the user that what `scope` showed alone is gone: the
--- worktree no longer listed, the branch that names no commit.
---
---@param scope aineo.changes.Scope
---@return string
function M.gone(scope)
  return ('aineo: %s is gone; the changes pane shows the default view'):format(scope.heading)
end

--- What a read of the other worktrees comes to for `scope`, a worktree's: the
--- scope as that read lists its worktree, when it does; else no scope, and
--- the words to tell the user that the worktree is gone.
---
---@param scope aineo.changes.Scope
---@param others aineo.changes.OtherWorktrees what the read gave
---@return aineo.changes.Scope|nil still_listed
---@return string|nil gone
function M.after_read(scope, others)
  local section = M.section_on(others, scope.top)
  if section then
    return M.of(section), nil
  end
  return nil, M.gone(scope)
end

--- The words that tell the user the worktree `item` offered is no longer
--- listed by the time it is picked.
---
---@param item aineo.changes.ScopeItem
---@return string
function M.picked_gone(item)
  return ('aineo: %s is gone'):format(item.text)
end

--- What `scope` shows alone, in the order the commits window lists them: the
--- worktree of `others`, what the commits window last listed of the other
--- worktrees, that a worktree's scope names; or the branch it names, as
--- `branch`, what the commits window last read of it, or, while it has read
--- none, the branch by its name alone. Nil when `scope` names a worktree
--- that `others` lists no more.
---
---@param scope aineo.changes.Scope
---@param others aineo.changes.OtherWorktrees
---@param branch aineo.changes.BranchSection|nil
---@return aineo.changes.ScopeMember[]|nil
function M.members_shown(scope, others, branch)
  if scope.branch then
    return { { branch = branch or { name = scope.branch } } }
  end
  local section = M.section_on(others, scope.top)
  return section and { { worktree = section } } or nil
end

--- A worktree or a branch an agent of the tab's Claude Code reported, as
--- `aineo.mcp` hands it on: the worktree's folder, absolute, or the
--- branch's name, each the agent's own string, the commit it was made from
--- and the agent's label for it.
---@class aineo.changes.ReportedWork
---@field kind 'worktree'|'branch'
---@field path? string the worktree's folder, with `kind` `worktree`
---@field branch? string the branch's name, with `kind` `branch`
---@field base? string the full id of the commit the work was made from; nil for a report that gives none
---@field label? string the agent's short name for the work's task
---@field by_hook? boolean whether aineo's own hook made the report, rather than the agent's call

--- What `match_report()` gives for a report of the editor's own worktree, or
--- of the branch it has checked out: the default view shows that work.
M.OWN_WORK = { own = true }

--- The local branch `name` as `candidates`, what git listed, give it: the
--- worktree that has it checked out, when one has, else the branch by its
--- name alone (`{ name }`); nil when git lists no local branch of that name.
---
---@param name string
---@param candidates aineo.changes.BranchCandidates
---@return aineo.git.Worktree|{ name: string }|nil
local function listed_branch_of(name, candidates)
  local named = vim.iter(candidates.branches):find(function(listed)
    return listed.name == name
  end)
  if not named then
    return nil
  end
  return vim.iter(candidates.worktrees):find(function(worktree)
    return worktree.branch == named.name
  end) or { name = named.name }
end

--- What `work`, a report, comes to against `candidates`, what git listed of
--- the worktrees and the branches: for a worktree, the worktree whose top
--- level is `real_path`, the reported path with every link resolved (git
--- lists worktrees by their real paths); for a branch, the local branch of
--- that name — as the worktree that has it checked out, when one has, else
--- as the branch when `s` would offer it (`branches_offered()`). The
--- editor's own worktree, `own_top`, and a branch no worktree has checked
--- out that `s` would not offer — the working branch — give `OWN_WORK`;
--- nothing listed gives nil. The agent's strings are compared with what git
--- printed, never handed on: a member holds git's own worktree or branch.
---
---@param work aineo.changes.ReportedWork
---@param real_path string|nil the reported path with every link resolved; nil when it resolves to nothing
---@param candidates aineo.changes.BranchCandidates
---@param own_top string the editor's own worktree's top level
---@return aineo.changes.ScopeMember|table|nil
function M.match_report(work, real_path, candidates, own_top)
  local listed
  if work.kind == 'branch' then
    listed = listed_branch_of(work.branch, candidates)
  else
    listed = vim.iter(candidates.worktrees):find(function(worktree)
      return worktree.top == real_path
    end)
  end
  if not listed then
    return nil
  end
  if not listed.top then
    local offered = vim.iter(branches_offered(candidates)):any(function(offered_branch)
      return offered_branch.name == listed.name
    end)
    return offered and { branch = listed } or M.OWN_WORK
  end
  if listed.top == own_top then
    return M.OWN_WORK
  end
  return { worktree = listed }
end

--- The members of `members`, the reported set, that `candidates`, what git
--- now lists, still lists, in their order: a worktree by its top level, as
--- git now lists it, its branch included; a branch by its name.
---
---@param members aineo.changes.ScopeMember[]
---@param candidates aineo.changes.BranchCandidates
---@return aineo.changes.ScopeMember[]
function M.still_listed(members, candidates)
  local worktrees_by_top, branch_names = {}, {}
  for _, worktree in ipairs(candidates.worktrees) do
    worktrees_by_top[worktree.top] = worktree
  end
  for _, listed_branch in ipairs(candidates.branches) do
    branch_names[listed_branch.name] = true
  end
  local still = {}
  for _, member in ipairs(members) do
    if member.worktree and worktrees_by_top[member.worktree.top] then
      table.insert(still, { worktree = worktrees_by_top[member.worktree.top] })
    elseif member.branch and branch_names[member.branch.name] then
      table.insert(still, member)
    end
  end
  return still
end

--- The words that tell the user the reported set is empty, all of it gone,
--- while the pane showed it.
M.REPORTED_GONE = 'aineo: the reported work is gone; the changes pane shows the default view'

--- The key that tells `member`, one of the reported set, from every other:
--- a worktree by its top level, a branch by its name.
---
---@param member aineo.changes.ScopeMember
---@return string
function M.member_key(member)
  if member.worktree then
    return 'worktree\0' .. member.worktree.top
  end
  return 'branch\0' .. member.branch.name
end

--- What the focused view shows of `members`, the reported set, in its
--- order: each worktree as `others`, what the commits window last listed of
--- the other worktrees, lists it, else as git listed it when it was
--- reported; each branch as the commits window last read it.
---
---@param members aineo.changes.ScopeMember[]
---@param others aineo.changes.OtherWorktrees
---@return aineo.changes.ScopeMember[]
function M.members_reported(members, others)
  return vim.tbl_map(function(member)
    if member.worktree then
      return { worktree = M.section_on(others, member.worktree.top) or member.worktree }
    end
    return member
  end, members)
end

--- The heading of `member`, as the commits window names it.
---
---@param member aineo.changes.ScopeMember
---@return string
local function member_heading(member)
  if member.worktree then
    return lines.worktree_heading(member.worktree)
  end
  return lines.filter_name(filter.of_branch(member.branch.name))
end

--- The words that tell the user an agent started work in `member`, which
--- joined the reported set.
---
---@param member aineo.changes.ScopeMember
---@return string
function M.started_work(member)
  return ('aineo: Claude Code started work in %s; the changes pane shows the reported work'):format(
    member_heading(member)
  )
end

--- The words that tell the user git did not list what `work` reported in
--- the time it waited: its kind and its path or branch, quoted as a path is
--- (`lines.quoted_path()`), so that no character of the agent's string
--- shows as anything but text.
---
---@param work aineo.changes.ReportedWork
---@return string
function M.unlisted_report(work)
  return ('aineo: Claude Code announced %s %s, which git does not list; the changes pane is unchanged'):format(
    work.kind,
    lines.quoted_path(work.path or work.branch)
  )
end

--- The filter of the whole change of `member`, one of what a scope shows
--- alone.
---
---@param member aineo.changes.ScopeMember
---@return aineo.changes.Filter
function M.whole_change_of(member)
  if member.worktree then
    return filter.of_worktree(member.worktree)
  end
  return filter.of_branch(member.branch.name)
end

--- What the changes pane's view of a session is made of.
---@class aineo.changes.View
---@field scope? aineo.changes.Scope the worktree or branch picked to show alone
---@field focused boolean whether the focused view shows rather than the default view
---@field reported aineo.changes.ScopeMember[] the reported set
---@field shows_reported boolean whether the focused view is the reported set rather than the pick
---@field reports? table<string, aineo.changes.Report> what was reported of each member of the reported set, by its key (`M.member_key()`); none when not given

--- `view` as it is kept for a session (`aineo.changes.kept`): what it picked
--- and reported, each by the worktree's top level or the branch's name, each
--- member of the reported set with what was reported of it.
---
---@param repository string the session's repository's top level
---@param view aineo.changes.View
---@return aineo.changes.KeptView
function M.kept_view_of(repository, view)
  local scope_kept
  if view.scope then
    scope_kept = { top = view.scope.top, branch = view.scope.branch }
  end
  local reports = view.reports or {}
  return {
    repository = repository,
    focused = view.focused,
    shows_reported = view.shows_reported,
    scope = scope_kept,
    reported = vim.tbl_map(function(member)
      local report = reports[M.member_key(member)] or {}
      local kept = {
        kind = report.kind,
        base = report.base,
        label = report.label,
        at = report.at,
        by_hook = report.by_hook,
      }
      if member.worktree then
        kept.top = member.worktree.top
      else
        kept.branch = member.branch.name
      end
      return kept
    end, view.reported),
  }
end

--- The member `pick`, kept, names, as `M.still_listed()` takes it.
---
---@param pick aineo.changes.KeptPick
---@return aineo.changes.ScopeMember
local function member_of_pick(pick)
  if pick.top then
    return { worktree = { top = pick.top } }
  end
  return { branch = { name = pick.branch } }
end

--- What `M.restored_view()` gives.
---@class aineo.changes.RestoredView: aineo.changes.View
---@field selected? aineo.changes.Filter the whole change of the first thing the focused view shows, which it chooses; nil for the default view

--- What was reported of the members `picks`, the reported set as it was
--- kept, by each member's key (`M.member_key()`): its kind as reported, or
--- the kind of the member for a record kept before reports kept theirs, and
--- its base, label, time and whether aineo's hook made it, as kept.
---
---@param picks aineo.changes.KeptReport[]
---@return table<string, aineo.changes.Report>
local function reports_of(picks)
  local reports = {}
  for _, pick in ipairs(picks) do
    reports[M.member_key(member_of_pick(pick))] = {
      kind = pick.kind or (pick.top and 'worktree' or 'branch'),
      base = pick.base,
      label = pick.label,
      at = pick.at,
      by_hook = pick.by_hook,
    }
  end
  return reports
end

--- The view `kept` keeps, as `candidates`, what git now lists, still allows
--- it: a member of the reported set that git no longer lists is dropped, so
--- is a pick of a worktree or a branch it no longer lists, all untold. The
--- editor's own worktree, which `s` never offers and the pane never keeps,
--- is never restored. The focused view shows only while what it was of — the
--- set, or the pick — is left. Each member left keeps what was reported of
--- it (`reports_of()`).
---
---@param kept aineo.changes.KeptView
---@param candidates aineo.changes.BranchCandidates
---@param own_top string the top level of the editor's own worktree
---@return aineo.changes.RestoredView
function M.restored_view(kept, candidates, own_top)
  local function is_not_own(pick)
    return pick.top ~= own_top
  end
  local kept_reported = vim.tbl_filter(is_not_own, kept.reported)
  local reported = M.still_listed(vim.tbl_map(member_of_pick, kept_reported), candidates)
  local all_reports = reports_of(kept_reported)
  local reports = {}
  for _, member in ipairs(reported) do
    local key = M.member_key(member)
    reports[key] = all_reports[key]
  end
  local picked = kept.scope
    and is_not_own(kept.scope)
    and M.still_listed({ member_of_pick(kept.scope) }, candidates)[1]
  local scope
  if picked and picked.worktree then
    scope = M.of(picked.worktree)
  elseif picked then
    scope = M.of_branch(picked.branch.name)
  end
  local shows_reported = kept.shows_reported and #reported > 0
  local shown
  if kept.focused and kept.shows_reported then
    shown = reported[1]
  elseif kept.focused then
    shown = picked
  end
  return {
    scope = scope,
    focused = shown ~= nil,
    reported = reported,
    shows_reported = shows_reported,
    reports = reports,
    selected = shown and M.whole_change_of(shown) or nil,
  }
end

return M
