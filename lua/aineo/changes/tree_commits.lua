--- Reads, for the changes pane's Reported section, the commits each of its
--- branches' lines lists below it: those from the base the line shows to
--- the branch's tip.

local git = require('aineo.git')

local M = {}

--- What one branch's line asks to have read: the branch, and the full id
--- of the base its line shows.
---@class aineo.changes.TreeCommitsWanted
---@field name string the local branch's name
---@field base string the full id of the commit its commits are counted from

--- What a read of the commits of the Reported section starts from.
---@class aineo.changes.TreeCommitsRead
---@field found aineo.git.Repository the session's repository
---@field git? aineo.git.Options

--- What tells the commits of a branch read from a base apart from those of
--- any other branch or base.
---
---@param name string the local branch's name
---@param base string the full id of the commit its commits are counted from
---@return string
function M.key(name, base)
  return name .. '\0' .. base
end

--- The commits to read for `tree`, the lines of the Reported section: for
--- each branch's line that shows a base — the pane has read its work, from
--- the base `read_base` names, and a report gave it a base — the branch and
--- that base, each pair once, in the order of the lines.
---
---@param tree aineo.changes.TreeLine[]
---@return aineo.changes.TreeCommitsWanted[]
function M.wanted(tree)
  local wanted, seen = {}, {}
  for _, line in ipairs(tree) do
    if line.branch and line.branch.base and line.read_base then
      local key = M.key(line.branch.name, line.read_base)
      if not seen[key] then
        seen[key] = true
        table.insert(wanted, { name = line.branch.name, base = line.read_base })
      end
    end
  end
  return wanted
end

--- The commits of `kept`, what `M.read()` kept, that belong to the line
--- `line`, a branch's: those read for its branch from the base it shows;
--- nil when none were read from that base.
---
---@param kept table<string, aineo.git.Commit[]>
---@param line aineo.changes.TreeLine
---@return aineo.git.Commit[]|nil
function M.commits_of(kept, line)
  if not (line.branch and line.read_base) then
    return nil
  end
  return kept[M.key(line.branch.name, line.read_base)]
end

--- Reads the commits of `item`, one of the commits wanted: those of the
--- commit `refs/heads/` and its name names now that its base cannot reach,
--- newest first. Calls `done(commits)`, or `done(nil)` when the name names
--- no commit or git fails: the line then lists none.
---
---@param read aineo.changes.TreeCommitsRead
---@param item aineo.changes.TreeCommitsWanted
---@param done fun(commits: aineo.git.Commit[]|nil)
local function read_item(read, item, done)
  git.resolve_commit(read.found, 'refs/heads/' .. item.name, function(tip_failure, tip)
    if tip_failure or not tip then
      done(nil)
      return
    end
    git.commits_between(read.found, item.base, tip, function(failure, commits)
      done(not failure and commits or nil)
    end, read.git)
  end, read.git)
end

--- Reads the commits of `wanted`, one branch after another, and calls
--- `done(kept)` with what was read, by `M.key()`: a branch whose read
--- failed has no entry, one with no commit past its base has an empty list.
---
---@param read aineo.changes.TreeCommitsRead
---@param wanted aineo.changes.TreeCommitsWanted[]
---@param done fun(kept: table<string, aineo.git.Commit[]>)
function M.read(read, wanted, done)
  local kept = {}
  local function read_from(position)
    local item = wanted[position]
    if not item then
      done(kept)
      return
    end
    read_item(read, item, function(commits)
      kept[M.key(item.name, item.base)] = commits
      read_from(position + 1)
    end)
  end
  read_from(1)
end

return M
