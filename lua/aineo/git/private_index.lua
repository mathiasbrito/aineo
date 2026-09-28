--- A private copy of a repository's index, for a git that would otherwise
--- rewrite the index itself.
---
--- `git diff` against a commit refreshes the index whenever a tracked file's
--- stat changed but its content did not, and to do so takes the index's
--- lock, `GIT_OPTIONAL_LOCKS=0` or not: a `git commit` or `git add` started
--- meanwhile then fails. Run against a copy that carries the index's own
--- modification time, the same diff answers the same, and the repository's
--- own index and its lock are never touched. What git refreshes in the copy
--- is thrown away with it, so a repository whose files all changed stat —
--- rewritten with the same content — makes every read hash every file again
--- until a git of the user's or Claude's refreshes the index itself.

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

--- Copies the index at `index` to `copy`, and gives the copy the index's
--- own modification time, taken before the copy: git trusts an entry's
--- recorded stat only when the entry is older than the index, so a copy
--- stamped with the time it was made would hide a file rewritten, at the
--- same size, within the second the index was written. An index replaced
--- between the two steps gets an older stamp, which only makes git check
--- more entries. Calls `copied(nil)` once done, or `copied(error)`, in a
--- fast event.
---
---@param index string
---@param copy string
---@param copied fun(error: string|nil)
local function copy_index(index, copy, copied)
  vim.uv.fs_stat(index, function(stat_error, original)
    if stat_error then
      copied(stat_error)
      return
    end
    vim.uv.fs_copyfile(index, copy, function(copy_error)
      if copy_error then
        copied(copy_error)
        return
      end
      vim.uv.fs_utime(copy, original.atime.sec, original.mtime.sec, copied)
    end)
  end)
end

--- Runs `use(environment, finish)` with a copy of the index of the
--- repository whose git directory is `git_directory`, where `environment`
--- points git at the copy (`GIT_INDEX_FILE`); a repository with no index yet
--- gives an empty one. Once `use` calls `finish(…)`, the copy is removed and
--- `done(…)` is called with the same arguments. When the index cannot be
--- copied, `done(failure)` is called instead, and `use` is not. It may be
--- called from a fast event: the copy's name, which only the main loop can
--- ask Neovim for, is taken there.
---
---@param git_directory string
---@param use fun(environment: table<string, string>, finish: fun(...: any))
---@param done fun(...: any)
function M.with_private_index(git_directory, use, done)
  vim.schedule(function()
    local copy = vim.fn.tempname()
    copy_index(vim.fs.joinpath(git_directory, 'index'), copy, function(copy_error)
      vim.schedule(function()
        if copy_error and not vim.startswith(copy_error, 'ENOENT') then
          remove_copy(copy)
          done({ reason = 'failed', message = 'cannot copy the index: ' .. copy_error })
          return
        end
        use({ GIT_INDEX_FILE = copy }, function(...)
          remove_copy(copy)
          done(...)
        end)
      end)
    end)
  end)
end

return M
