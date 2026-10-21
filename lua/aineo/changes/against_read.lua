--- Reads, for the changes pane, what git alone can tell of what a diff
--- compares (`aineo.changes.against`): the commit `HEAD` names, a commit's
--- parent, the merge base of what landed, and the names that point at the
--- commits on either side.

local against = require('aineo.changes.against')
local git = require('aineo.git')

local M = {}

--- What a read of what a diff compares starts from.
---@class aineo.changes.AgainstRead
---@field listed aineo.changes.Filter the filter the diff's files are listed under
---@field against_head boolean whether the diff is the one against `HEAD`
---@field source aineo.changes.DiffSource what the session knows; its `repository` is the editor's own
---@field options? aineo.git.Options how the git home runs git

--- The repository the files of `listed` are read in: the other worktree's,
--- for a filter of one, else the editor's own.
---
---@param listed aineo.changes.Filter
---@param source aineo.changes.DiffSource
---@return aineo.git.Repository
local function repository_of(listed, source)
  local worktree = listed.worktree
  return worktree and worktree.repository or source.repository
end

--- Reads, in `repository`, the commit the revision `revision` names, and
--- calls `done(commit)`: its full id, `false` when it names none, and nil
--- when git failed, which leaves the side as the words alone.
---
---@param repository aineo.git.Repository
---@param revision string
---@param options aineo.git.Options|nil
---@param done fun(commit: string|false|nil)
local function read_commit(repository, revision, options, done)
  git.resolve_commit(repository, revision, function(failure, commit)
    if failure then
      done(nil)
    else
      done(commit or false)
    end
  end, options)
end

--- Reads the merge base of the session's base and the commit the working
--- branch named, and calls `done(base)`: its full id, `false` when they
--- share no history or the session has no base, nil when git failed or the
--- working branch has not been read.
---
---@param request aineo.changes.AgainstRead
---@param done fun(merge_base: string|false|nil)
local function read_merge_base(request, done)
  local source = request.source
  if not source.base then
    done(false)
    return
  end
  local tip = source.landed and source.landed.tip
  if not tip then
    done(nil)
    return
  end
  git.worktree_base(
    { top = source.repository.top, head = source.base },
    tip,
    function(failure, base)
      if failure then
        done(nil)
      else
        done(base or false)
      end
    end,
    request.options
  )
end

--- Reads the commit the filter's diff needs that git alone tells (`needs`,
--- from `against.needs()`), one after another, into `resolved`, then calls
--- `done()`. A read that fails leaves its commit unread.
---
---@param request aineo.changes.AgainstRead
---@param needs aineo.changes.Needs
---@param resolved aineo.changes.Resolved
---@param done fun()
local function read_needed(request, needs, resolved, done)
  local repository = repository_of(request.listed, request.source)
  local function read_merge_base_then_done()
    if not needs.merge_base then
      done()
      return
    end
    read_merge_base(request, function(merge_base)
      resolved.merge_base = merge_base
      done()
    end)
  end
  local function read_parent_then_continue()
    if not needs.parent then
      read_merge_base_then_done()
      return
    end
    read_commit(repository, request.listed.commit.id .. '^', request.options, function(parent)
      resolved.parent = parent
      read_merge_base_then_done()
    end)
  end
  if not needs.head then
    read_parent_then_continue()
    return
  end
  read_commit(repository, 'HEAD', request.options, function(head)
    resolved.head = head or nil
    read_parent_then_continue()
  end)
end

--- Reads what the diff of the files listed under `request.listed` compares
--- that git alone tells (`aineo.changes.against`'s `needs()`), then the
--- names of the commits on both sides (`aineo.git`'s `names_at()`), the
--- last of the git runs, and calls `done(resolved)` once, on the main loop.
--- Nothing is raised or told when a run fails: the names, which only
--- embellish the sides, or a commit, whose side then says its words alone,
--- are left unread, and the next read tries again.
---
---@param request aineo.changes.AgainstRead
---@param done fun(resolved: aineo.changes.Resolved)
function M.read(request, done)
  local resolved = {}
  read_needed(request, against.needs(request.listed, request.against_head), resolved, function()
    local sides = against.sides(request.listed, request.against_head, request.source, resolved)
    git.names_at(
      repository_of(request.listed, request.source),
      against.ids(sides),
      function(failure, names)
        resolved.names = not failure and names or nil
        done(resolved)
      end,
      request.options
    )
  end)
end

return M
