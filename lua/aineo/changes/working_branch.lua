--- Reads, for the changes pane, the working branch: the branch work lands
--- in, which *Landed* lists the commits of and other worktrees' bases are
--- counted from.

local git = require('aineo.git')

local M = {}

--- What a read of the working branch starts from.
---@class aineo.changes.WorkingBranchRead
---@field repository aineo.git.Repository the editor's repository
---@field working_branch? string the branch the user's setting names; the remote's default branch when not given
---@field git? aineo.git.Options how the git home runs git

--- Reads the working branch's name: the setting's, else the short name of
--- the remote's default branch, and the commit that name names now, and
--- calls `done(nil, name, commit)`. `name` is nil when there is neither
--- setting nor remote default branch; `commit`, a full id, is nil when
--- `name` names no commit. When a read fails, `done(failure)` for the name,
--- `done(failure, name)` for the commit.
---
--- The commit is read at every call and never kept: the working branch
--- moves when a fetch moves it.
---
---@param read aineo.changes.WorkingBranchRead
---@param done fun(failure: aineo.git.Failure|nil, name: string|nil, commit: string|nil)
function M.read(read, done)
  local function resolve(name)
    git.resolve_commit(read.repository, name, function(failure, commit)
      if failure then
        done(failure, name)
      else
        done(nil, name, commit)
      end
    end, read.git)
  end
  if read.working_branch then
    resolve(read.working_branch)
    return
  end
  git.remote_default_branch(read.repository, function(failure, name)
    if failure then
      done(failure)
    elseif name then
      resolve(name)
    else
      done(nil)
    end
  end, read.git)
end

return M
