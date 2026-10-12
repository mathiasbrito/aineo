--- Reads, for the changes pane, what landed in the working branch since the
--- session's base: the branch's name, the commit it names now, and the
--- commits of that commit the base cannot reach.

local git = require('aineo.git')

local M = {}

--- What the commits window knows of the working branch. Either `tip` and
--- `commits` are given, or `names_no_commit` is.
---@class aineo.changes.Landed
---@field name string the working branch, as the setting names it or as the remote's default branch is named
---@field tip? string the full id of the commit `name` named when the commits were read
---@field commits? aineo.git.Commit[] the commits reachable from `tip` and not from the session's base, newest first
---@field names_no_commit? boolean whether `name` named no commit when it was read

--- What a read of the working branch starts from.
---@class aineo.changes.LandedRead
---@field repository aineo.git.Repository the editor's repository
---@field base string|nil the session's base; nil lists every commit of the working branch
---@field working_branch? string the branch the user's setting names; the remote's default branch when not given
---@field before? aineo.changes.Landed what the commits window knew before this read
---@field git? aineo.git.Options how the git home runs git

--- Finds the working branch's name for `read`: the setting's, or the short
--- name of the remote's default branch, and calls `done(nil, name)`; `name`
--- is nil when there is neither, or `done(failure)`.
---
---@param read aineo.changes.LandedRead
---@param done fun(failure: aineo.git.Failure|nil, name: string|nil)
local function find_name(read, done)
  if read.working_branch then
    done(nil, read.working_branch)
    return
  end
  git.remote_default_branch(read.repository, done, read.git)
end

--- Reads the working branch (`find_name()`), the commit it names now, once,
--- and the commits of it the base cannot reach, and calls `done(nil,
--- landed)`: `landed` is nil when there is no working branch, and says the
--- name names no commit when it does not. When a read fails, `done(failure,
--- read.before)` keeps what the window knew.
---
---@param read aineo.changes.LandedRead
---@param done fun(failure: aineo.git.Failure|nil, landed: aineo.changes.Landed|nil)
function M.read(read, done)
  local function failed(failure)
    done(failure, read.before)
  end
  find_name(read, function(name_failure, name)
    if name_failure or not name then
      done(name_failure, name_failure and read.before or nil)
      return
    end
    git.resolve_commit(read.repository, name, function(resolve_failure, tip)
      if resolve_failure then
        failed(resolve_failure)
      elseif not tip then
        done(nil, { name = name, names_no_commit = true })
      else
        git.commits_between(read.repository, read.base, tip, function(commits_failure, commits)
          if commits_failure then
            failed(commits_failure)
          else
            done(nil, { name = name, tip = tip, commits = commits })
          end
        end, read.git)
      end
    end, read.git)
  end)
end

--- Why nothing can be read from `landed`, as the commit its files and diffs
--- are read at: its name names no commit; or, while the window has not read
--- the working branch, nothing is known of it.
---
---@param landed aineo.changes.Landed|nil
---@return aineo.git.Failure
function M.unreadable(landed)
  if landed and landed.names_no_commit then
    return { reason = 'failed', message = landed.name .. ' names no commit' }
  end
  return { reason = 'failed', message = 'what landed has not been read yet' }
end

return M
