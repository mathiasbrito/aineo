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

--- One choice of the list `s` offers: a worktree, by its top level, or a
--- local branch, by its name.
---@class aineo.changes.ScopeItem
---@field top? string the top level of the worktree it shows alone
---@field branch? string the name of the branch it shows alone
---@field text string how the picker shows it: its kind, then its name

--- What the list `s` chooses its branches from, read when `s` is pressed.
---@class aineo.changes.BranchCandidates
---@field branches aineo.git.Branch[] the local branches, newest commit first
---@field worktrees aineo.git.Worktree[] every worktree of the repository, the editor's own among them, with the branch each is on
---@field working_branch? string the working branch's name, as the setting names it or as the remote's default branch is named; nil when there is none

--- Whether the branch `name` is the working branch `working`, their short
--- names compared: `origin/dev` is `dev`. A working branch that names a
--- local branch is that branch alone; otherwise its first component is the
--- remote's name, left off.
---
---@param name string
---@param working string|nil
---@param listed table<string, true> the names of the local branches
---@return boolean
local function is_working_branch(name, working, listed)
  if not working then
    return false
  end
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

--- The list `s` offers: one item per worktree of `others`, what the commits
--- window last listed of the other worktrees, in the order listed, then one
--- per branch of `candidates` that is offered (`branches_offered()`), in the
--- order given. `candidates` is nil when the branches could not be read:
--- the worktrees alone.
---
---@param others aineo.changes.OtherWorktrees
---@param candidates aineo.changes.BranchCandidates|nil
---@return aineo.changes.ScopeItem[]
function M.items_of(others, candidates)
  local items = vim.tbl_map(function(section)
    return { top = section.top, text = '[worktree] ' .. lines.worktree_name(section) }
  end, others.sections)
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

return M
