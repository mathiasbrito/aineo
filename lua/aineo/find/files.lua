--- The files under a directory, for the finder's own list: the files a
--- repository lists, when the caller hands in how to list them, else the
--- files found walking the directory. Both are bounded, so that a directory
--- of a million files does not hold the editor.

local M = {}

--- How many files a list holds at most.
M.MOST_FILES = 20000

--- How many directories deep a walk goes.
local WALK_DEPTH = 8

--- `files` in the order of their bytes, cut to the first `M.MOST_FILES`, and
--- whether there were more.
---
---@param files string[]
---@return string[] files
---@return boolean cut
local function sorted_and_bounded(files)
  table.sort(files)
  if #files <= M.MOST_FILES then
    return files, false
  end
  return vim.list_slice(files, 1, M.MOST_FILES), true
end

--- The files found walking `directory`, as paths relative to it, the first
--- `M.MOST_FILES` of them, down to `WALK_DEPTH` directories, leaving `.git`
--- out; and whether there were more.
---
---@param directory string
---@return string[] files
---@return boolean cut
local function walk(directory)
  local files = {}
  local entries = vim.fs.dir(directory, {
    depth = WALK_DEPTH,
    skip = function(name)
      return name ~= '.git'
    end,
  })
  for path, kind in entries do
    if kind == 'file' then
      table.insert(files, path)
      if #files > M.MOST_FILES then
        break
      end
    end
  end
  return sorted_and_bounded(files)
end

--- Why a repository's files could not be listed.
---@class aineo.find.ListFailure
---@field message string the words for it

--- How a repository's files are listed: calls `done(nil, paths)`, never
--- before it returns, with the paths relative to the directory searched, or
--- `done(failure)`.
---@alias aineo.find.ListFiles fun(done: fun(failure: aineo.find.ListFailure|nil, paths: string[]|nil))

--- Calls `done(files, cut, failure)`, never before it returns, with the files
--- under `directory` as paths relative to it: those `list_files` gives, in the
--- order of their bytes, or, when `list_files` is nil or fails, those a walk
--- finds (`walk()`). `cut` tells whether the list stops at `M.MOST_FILES` with
--- more to follow; `failure` is why `list_files` failed, when it did.
---
---@param directory string
---@param list_files aineo.find.ListFiles|nil
---@param done fun(files: string[], cut: boolean, failure: aineo.find.ListFailure|nil)
function M.list(directory, list_files, done)
  if not list_files then
    vim.schedule(function()
      done(walk(directory))
    end)
    return
  end
  list_files(function(failure, paths)
    if failure then
      local files, cut = walk(directory)
      done(files, cut, failure)
      return
    end
    done(sorted_and_bounded(paths))
  end)
end

return M
