--- Reads, for the changes pane, what landed in the working branch since the
--- session's base: the branch's name, the commit it names now, and the
--- commits of that commit the base cannot reach.

local git = require('aineo.git')
local working_branch = require('aineo.changes.working_branch')

local M = {}

--- What the heading says the working branch is called when the remote's
--- default branch could not be read and the window knew no name before.
local DEFAULT_BRANCH_NAME = 'origin/HEAD'

--- What the commits window knows of the working branch. Either `tip` and
--- `commits` are given, or `names_no_commit` is, or neither, when the first
--- read failed.
---@class aineo.changes.Landed
---@field name string the working branch, as the setting names it or as the remote's default branch is named
---@field tip? string the full id of the commit `name` named when the commits were read
---@field commits? aineo.git.Commit[] the commits reachable from `tip` and not from the session's base, newest first
---@field names_no_commit? boolean whether `name` named no commit when it was read
---@field failure? aineo.git.Failure why the last read failed, when it did; the other fields are then what the window knew before

--- What a read of what landed in the working branch starts from.
---@class aineo.changes.LandedRead: aineo.changes.WorkingBranchRead
---@field base string|nil the session's base; nil lists every commit of the working branch
---@field before? aineo.changes.Landed what the commits window knew before this read

--- Reads the working branch (`working_branch.read()`), the commit it names
--- now, once, and the commits of it the base cannot reach, and calls
--- `done(landed)`: `landed` is nil when there is no working branch, and says
--- the name names no commit when it does not. When a read fails, `landed` is
--- what the window knew before of the same branch, or of any when the name
--- could not be read, with the `failure`; a window that knew nothing gets
--- the name and the failure alone.
---
---@param read aineo.changes.LandedRead
---@param done fun(landed: aineo.changes.Landed|nil)
function M.read(read, done)
  local function failed(name, failure)
    local before = read.before
    local kept = before and (not name or before.name == name) and before
      or { name = name or DEFAULT_BRANCH_NAME }
    done(vim.tbl_extend('force', kept, { failure = failure }))
  end
  working_branch.read(read, function(failure, name, tip)
    if failure then
      failed(name, failure)
    elseif not name then
      done(nil)
    elseif not tip then
      done({ name = name, names_no_commit = true })
    else
      git.commits_between(read.repository, read.base, tip, function(commits_failure, commits)
        if commits_failure then
          failed(name, commits_failure)
        else
          done({ name = name, tip = tip, commits = commits })
        end
      end, read.git)
    end
  end)
end

--- Why nothing can be read from `landed`, as the commit its files and diffs
--- are read at: its name names no commit; its read failed before a commit
--- was known; or, while the window has not read the working branch, nothing
--- is known of it.
---
---@param landed aineo.changes.Landed|nil
---@return aineo.git.Failure
function M.unreadable(landed)
  if landed and landed.names_no_commit then
    return { reason = 'failed', message = landed.name .. ' names no commit' }
  elseif landed and landed.failure then
    return landed.failure
  end
  return { reason = 'failed', message = 'what landed has not been read yet' }
end

return M
