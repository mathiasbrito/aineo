--- Reads a file of a repository as a commit has it.

local process = require('aineo.git.process')

local M = {}

--- The object type `git ls-tree` gives an entry that holds a file's bytes,
--- a link's target included.
local FILE_OBJECT_TYPE = 'blob'

--- The object id and type of the entry `git ls-tree -z` gave as `output`,
--- one entry at most, as `<mode> <type> <id>\t<path>`; nil when it gave none.
---
---@param output string
---@return { type: string, id: string }|nil
local function parse_entry(output)
  local kind, id = output:match('^%d+ (%a+) (%x+)\t')
  return kind and { type = kind, id = id } or nil
end

--- Calls `done` with the failure that says the commit `commit` has no file
--- at `path` as a file: `path_missing` when it has nothing there, `failed`
--- when it has a directory or a submodule.
---
---@param commit string
---@param path string
---@param entry { type: string, id: string }|nil
---@param done fun(failure: aineo.git.Failure)
local function report_no_file(commit, path, entry, done)
  if not entry then
    done({
      reason = 'path_missing',
      message = ('%s does not exist in %s'):format(path, commit),
    })
    return
  end
  done({
    reason = 'failed',
    message = ('%s is a %s in %s, not a file'):format(path, entry.type, commit),
  })
end

--- Reads the file at `path` as the commit `commit` of `found` has it, and
--- calls `done(nil, text)`, the bytes exactly as git printed them, or
--- `done(failure)`: `path_missing` when the commit has nothing at `path`,
--- told apart from any other failure, such as a commit the repository does
--- not have or a directory at `path`. The path is taken whole: never as a
--- pattern, never as an option.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param commit string the commit's id
---@param path string relative to the repository's top level
---@param done fun(failure: aineo.git.Failure|nil, text: string|nil)
function M.file_at_commit(run, found, commit, path, done)
  run(
    {
      directory = found.top,
      arguments = { 'ls-tree', '-z', '--full-tree', '--end-of-options', commit, '--', path },
    },
    process.or_fail(done, function(listing)
      local entry = parse_entry(listing.stdout)
      if not entry or entry.type ~= FILE_OBJECT_TYPE then
        report_no_file(commit, path, entry, done)
        return
      end
      run(
        { directory = found.top, arguments = { 'cat-file', FILE_OBJECT_TYPE, entry.id } },
        process.or_fail(done, function(file)
          done(nil, file.stdout)
        end)
      )
    end)
  )
end

return M
