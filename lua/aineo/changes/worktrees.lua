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

--- What one window knows of the worktrees other than the editor's.
---@class aineo.changes.OtherWorktrees
---@field sections aineo.changes.WorktreeSection[] one per worktree, in the order git lists them

--- What the other worktrees' sections are before any was read.
---@type aineo.changes.OtherWorktrees
M.NONE = { sections = {} }

--- Reads one window's list for a worktree.
---@alias aineo.changes.ReadList fun(repository: aineo.git.Repository, base: string|nil, done: fun(failure: aineo.git.Failure|nil, listed: any))

--- Reads `worktree`'s list (`read_list`) from its base (`git.worktree_base()`)
--- and calls `done(section)`.
---
---@param found aineo.git.Repository the editor's
---@param worktree aineo.git.Worktree
---@param read_list aineo.changes.ReadList
---@param options aineo.git.Options|nil
---@param done fun(section: aineo.changes.WorktreeSection)
local function read_section(found, worktree, read_list, options, done)
  git.find_repository(worktree.top, function(_, repository)
    git.worktree_base(found, repository, function(_, base)
      read_list(repository, base, function(_, listed)
        done({
          top = worktree.top,
          branch = worktree.branch,
          repository = repository,
          base = base,
          listed = listed,
        })
      end)
    end, options)
  end, options)
end

--- Lists the worktrees of `found`'s repository other than `found`'s own and
--- reads each one's list (`read_list`), one after another, then calls
--- `done(others)`.
---
---@param found aineo.git.Repository the editor's
---@param read_list aineo.changes.ReadList
---@param options aineo.git.Options|nil
---@param done fun(others: aineo.changes.OtherWorktrees)
function M.read_other_worktrees(found, read_list, options, done)
  git.list_worktrees(found, function(_, listed)
    local others = vim.tbl_filter(function(worktree)
      return worktree.top ~= found.top
    end, listed)
    local sections = {}
    local function read_from(index)
      if index > #others then
        done({ sections = sections })
        return
      end
      read_section(found, others[index], read_list, options, function(section)
        table.insert(sections, section)
        read_from(index + 1)
      end)
    end
    read_from(1)
  end, options)
end

return M
