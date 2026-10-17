--- The files under a directory, for the finder's own list: the files of the
--- repository the directory is in, else the files found walking it. Both are
--- bounded, so that a directory of a million files does not hold the editor.

local M = {}

--- How long `git` may run before it is stopped.
local GIT_LIMIT_MS = 10000

--- How many files a list holds at most.
M.MOST_FILES = 20000

--- How many directories deep a walk goes.
local WALK_DEPTH = 8

--- What `git ls-files` lists in `directory`: the tracked files, and the
--- untracked ones its ignore rules leave in, each path relative to
--- `directory` and ended by a NUL byte.
---
---@param directory string
---@return string[]
local function list_files_command(directory)
  return { 'git', '-C', directory, 'ls-files', '-z', '--cached', '--others', '--exclude-standard' }
end

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

--- Calls `done(files, cut)`, never before it returns, with the files under
--- `directory` as paths relative to it: those `git ls-files` lists when
--- `directory` is in a repository, else those a walk finds (`walk()`);
--- `cut` tells whether the list stops at `M.MOST_FILES` with more to follow.
---
---@param directory string
---@param done fun(files: string[], cut: boolean)
function M.list(directory, done)
  local started = pcall(vim.system, list_files_command(directory), {
    timeout = GIT_LIMIT_MS,
  }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        done(sorted_and_bounded(vim.split(result.stdout, '\0', { plain = true, trimempty = true })))
      else
        done(walk(directory))
      end
    end)
  end)
  if not started then
    vim.schedule(function()
      done(walk(directory))
    end)
  end
end

return M
