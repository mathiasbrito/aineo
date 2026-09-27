--- A private copy of a repository's index, for a git that would otherwise
--- rewrite the index itself.
---
--- `git diff` against a commit refreshes the index whenever a tracked file's
--- stat changed but its content did not, and to do so takes the index's
--- lock, `GIT_OPTIONAL_LOCKS=0` or not: a `git commit` or `git add` started
--- meanwhile then fails. Run against a copy, the same diff answers the same,
--- and the repository's own index and its lock are never touched.

local M = {}

--- Removes the index copy at `copy`, and the lock git leaves beside it when
--- it is stopped while writing it. Either may be missing: a git that found
--- nothing to refresh writes neither, and no copy is made of an index that
--- does not exist.
---
---@param copy string
local function remove_copy(copy)
  vim.fn.delete(copy)
  vim.fn.delete(copy .. '.lock')
end

--- Runs `use(environment, finish)` with a copy of the index of the
--- repository whose git directory is `git_directory`, where `environment`
--- points git at the copy (`GIT_INDEX_FILE`); a repository with no index yet
--- gives an empty one. Once `use` calls `finish(…)`, the copy is removed and
--- `done(…)` is called with the same arguments. When the index cannot be
--- copied, `done(failure)` is called instead, and `use` is not.
---
---@param git_directory string
---@param use fun(environment: table<string, string>, finish: fun(...: any))
---@param done fun(...: any)
function M.with_private_index(git_directory, use, done)
  local copy = vim.fn.tempname()
  vim.uv.fs_copyfile(vim.fs.joinpath(git_directory, 'index'), copy, function(copy_error)
    vim.schedule(function()
      if copy_error and not vim.startswith(copy_error, 'ENOENT') then
        done({ reason = 'failed', message = 'cannot copy the index: ' .. copy_error })
        return
      end
      use({ GIT_INDEX_FILE = copy }, function(...)
        remove_copy(copy)
        done(...)
      end)
    end)
  end)
end

return M
