--- The files a repository holds, as `git ls-files` lists them.

local process = require('aineo.git.process')

local M = {}

--- The paths `git ls-files -z` gave as `output`, in git's order.
---
---@param output string
---@return string[]
local function parse_paths(output)
  return vim.split(output, '\0', { plain = true, trimempty = true })
end

--- Lists the files of `found`: the tracked ones and the untracked ones its
--- ignore rules leave in, as paths relative to its top level, and calls
--- `done(nil, paths)`, or `done(failure)`.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param done fun(failure: aineo.git.Failure|nil, paths: string[]|nil)
function M.list_files(run, found, done)
  run(
    {
      directory = found.top,
      arguments = { 'ls-files', '-z', '--cached', '--others', '--exclude-standard' },
    },
    process.or_fail(done, function(output)
      done(nil, parse_paths(output.stdout))
    end)
  )
end

return M
