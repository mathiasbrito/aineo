--- Lists the local branches of a repository.

local process = require('aineo.git.process')

local M = {}

--- A local branch, as the home lists it.
---@class aineo.git.Branch
---@field name string its short name, as git names it: `a/b`, `x-1`, `v1.2`
---@field commit string the full id of the commit it names

--- The prefix of the full name of a local branch.
local HEADS = 'refs/heads/'

--- The branches `git for-each-ref` gave as `output`, in its order: a line
--- each, the commit's id, a NUL, then the branch's full name. A name holds
--- no line break, which git refuses in one.
---
---@param output string
---@return aineo.git.Branch[]
local function parse_references(output)
  local branches = {}
  for _, line in ipairs(vim.split(output, '\n', { plain = true, trimempty = true })) do
    local commit, reference = line:match('^(%x+)%z(.+)$')
    table.insert(branches, { name = reference:sub(#HEADS + 1), commit = commit })
  end
  return branches
end

--- Lists the local branches of `found`, newest commit first, those whose
--- commits are equally new in name order, and calls `done(nil, branches)`,
--- or `done(failure)`. A repository with no commit lists none, and so does
--- one with only remote-tracking branches.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param done fun(failure: aineo.git.Failure|nil, branches: aineo.git.Branch[]|nil)
function M.list_branches(run, found, done)
  run(
    {
      directory = found.top,
      arguments = {
        'for-each-ref',
        '--sort=refname',
        '--sort=-committerdate',
        '--format=%(objectname)%00%(refname)',
        HEADS,
      },
    },
    process.or_fail(done, function(output)
      done(nil, parse_references(output.stdout))
    end)
  )
end

return M
