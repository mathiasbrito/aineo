--- Reads, for one window of the changes pane, what each worktree of the
--- session's repository other than the editor's lists.

local git = require('aineo.git')

local M = {}

--- What one window knows of a worktree other than the editor's.
---@class aineo.changes.WorktreeSection
---@field top string the worktree's top level
---@field branch string|nil the branch it is on, as last listed; nil when detached
---@field repository? aineo.git.Repository the worktree's repository, as its last read found it
---@field base? string the worktree's base when its list was last read
---@field listed? any what its last read gave: the window's list for it
---@field failure? aineo.git.Failure why its last read failed, when it did

--- What one window knows of the worktrees other than the editor's.
---@class aineo.changes.OtherWorktrees
---@field sections aineo.changes.WorktreeSection[] one per worktree, in the order git lists them
---@field failure? aineo.git.Failure why the worktrees could not be listed, when the last list failed

--- What the other worktrees' sections are before any was read.
---@type aineo.changes.OtherWorktrees
M.NONE = { sections = {} }

--- Reads one window's list for a worktree.
---@alias aineo.changes.ReadList fun(repository: aineo.git.Repository, base: string|nil, done: fun(failure: aineo.git.Failure|nil, listed: any))

--- What a read of the other worktrees, for one window, starts from.
---@class aineo.changes.WorktreesRead
---@field found aineo.git.Repository the editor's repository
---@field before aineo.changes.OtherWorktrees what the window knew of the other worktrees before this read
---@field read_list aineo.changes.ReadList reads the window's list for a worktree
---@field git? aineo.git.Options how the git home runs git

--- The section of `before` for the worktree at `top`, or nil when it has
--- none.
---
---@param before aineo.changes.OtherWorktrees
---@param top string
---@return aineo.changes.WorktreeSection|nil
local function section_before(before, top)
  for _, section in ipairs(before.sections) do
    if section.top == top then
      return section
    end
  end
  return nil
end

--- Reads `worktree`'s list (`read.read_list`) from its base
--- (`git.worktree_base()`) and calls `done(section)`; when the list cannot
--- be read, the section says why and keeps what the window last listed for
--- the worktree (`section_before()`), if anything — unless the worktree's
--- directory is gone by then, removed while it was read, when it calls
--- `done(nil)`.
---
---@param read aineo.changes.WorktreesRead
---@param worktree aineo.git.Worktree
---@param done fun(section: aineo.changes.WorktreeSection|nil)
local function read_section(read, worktree, done)
  local section = { top = worktree.top, branch = worktree.branch }
  local before = section_before(read.before, worktree.top)
  if before then
    section.repository, section.base, section.listed = before.repository, before.base, before.listed
  end
  local function or_failed(proceed)
    return function(failure, ...)
      if not failure then
        proceed(...)
      elseif vim.uv.fs_stat(worktree.top) then
        section.failure = failure
        done(section)
      else
        done(nil)
      end
    end
  end
  git.find_repository(
    worktree.top,
    or_failed(function(repository)
      git.worktree_base(
        read.found,
        repository,
        or_failed(function(base)
          read.read_list(
            repository,
            base,
            or_failed(function(listed)
              section.repository, section.base, section.listed = repository, base, listed
              done(section)
            end)
          )
        end),
        read.git
      )
    end),
    read.git
  )
end

--- Lists the worktrees of the editor's repository, `read.found`, other than
--- its own, and reads each one's list (`read_section()`), one after
--- another, then calls `done(others)`; or, when they cannot be listed,
--- `done(others)` saying why, with the sections the window knew before.
---
---@param read aineo.changes.WorktreesRead
---@param done fun(others: aineo.changes.OtherWorktrees)
function M.read_other_worktrees(read, done)
  git.list_worktrees(read.found, function(failure, listed)
    if failure then
      done({ sections = read.before.sections, failure = failure })
      return
    end
    local others = vim.tbl_filter(function(worktree)
      return worktree.top ~= read.found.top
    end, listed)
    local sections = {}
    local function read_from(index)
      if index > #others then
        done({ sections = sections })
        return
      end
      read_section(read, others[index], function(section)
        if section then
          table.insert(sections, section)
        end
        read_from(index + 1)
      end)
    end
    read_from(1)
  end, read.git)
end

return M
