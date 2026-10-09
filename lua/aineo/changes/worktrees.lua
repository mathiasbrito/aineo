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
---@field before_each_worktree fun(proceed: fun()) runs before each worktree's read, which starts once it calls `proceed()`
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

--- Whether `repository`, what git found from `worktree`'s directory, is
--- that worktree: its top level, or its git directory where git lists a
--- worktree by it, as it lists a submodule's checkout. A directory that
--- no longer is a worktree, its `.git` gone, is in whatever repository
--- holds it, or in none.
---
---@param repository aineo.git.Repository
---@param worktree aineo.git.Worktree
---@return boolean
local function is_listed_worktree(repository, worktree)
  return repository.top == worktree.top or repository.git_directory == worktree.top
end

--- The section of `worktree` before it is read: its top level and branch,
--- and what the window last read for it (`section_before()`), if anything.
---
---@param read aineo.changes.WorktreesRead
---@param worktree aineo.git.Worktree
---@return aineo.changes.WorktreeSection
local function unread_section(read, worktree)
  local section = { top = worktree.top, branch = worktree.branch }
  local before = section_before(read.before, worktree.top)
  if before then
    section.repository, section.base, section.listed = before.repository, before.base, before.listed
  end
  return section
end

--- Reads `worktree`'s list (`read.read_list`) from its base against the
--- commit `comparison` (`git.worktree_base()`), and calls `done(section)`;
--- when the list cannot be read, the section says why and keeps what the
--- window last listed for the worktree (`unread_section()`), if anything —
--- unless the worktree's directory is gone by then, removed while it was
--- read, when it calls `done(nil)`, as it does when git finds the directory
--- in another repository than that worktree (`is_listed_worktree()`).
---
---@param read aineo.changes.WorktreesRead
---@param worktree aineo.git.Worktree
---@param comparison string|nil
---@param done fun(section: aineo.changes.WorktreeSection|nil)
local function read_section(read, worktree, comparison, done)
  local section = unread_section(read, worktree)
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
      if not is_listed_worktree(repository, worktree) then
        done(nil)
        return
      end
      git.worktree_base(
        repository,
        comparison,
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
--- its own, reads once the commit their bases are taken against
--- (`git.comparison_commit()`), and reads each one's list
--- (`read_section()`), one after another, each once
--- `read.before_each_worktree` lets it start, then calls `done(others)`.
--- When the worktrees cannot be listed, `done(others)` says why, with the
--- sections the window knew before; when the commit cannot be read, each
--- section says why, over what the window last listed for it.
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
    if #others == 0 then
      done({ sections = {} })
      return
    end
    git.comparison_commit(read.found, function(comparison_failure, comparison)
      if comparison_failure then
        done({
          sections = vim.tbl_map(function(worktree)
            local section = unread_section(read, worktree)
            section.failure = comparison_failure
            return section
          end, others),
        })
        return
      end
      local sections = {}
      local function read_from(index)
        if index > #others then
          done({ sections = sections })
          return
        end
        read.before_each_worktree(function()
          read_section(read, others[index], comparison, function(section)
            if section then
              table.insert(sections, section)
            end
            read_from(index + 1)
          end)
        end)
      end
      read_from(1)
    end, read.git)
  end, read.git)
end

return M
