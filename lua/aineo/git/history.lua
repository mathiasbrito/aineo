--- Lists the commits of a repository since a base.

local process = require('aineo.git.process')

local M = {}

--- A commit, as the home lists it.
---@class aineo.git.Commit
---@field id string its full id
---@field subject string the first line of its message

--- The commits since a base.
---@class aineo.git.CommitsSince
---@field commits aineo.git.Commit[] the commits reachable from `HEAD` and not from the base, newest first
---@field base_is_ancestor boolean whether the base is still an ancestor of `HEAD`: false once a reset or a checkout left it behind

--- The code `git merge-base --is-ancestor` exits with when the first commit
--- is an ancestor of the second.
local IS_ANCESTOR_CODE = 0

--- The code it exits with when the first is not: an answer, not a failure.
local NOT_ANCESTOR_CODE = 1

--- The commits `git log -z --format='%H %s'` gave as `output`, in its order.
---
---@param output string
---@return aineo.git.Commit[]
local function parse_log(output)
  local commits = {}
  for _, record in ipairs(vim.split(output, '\0', { plain = true, trimempty = true })) do
    local id, subject = record:match('^(%x+) (.*)$')
    table.insert(commits, { id = id, subject = subject })
  end
  return commits
end

--- Lists the commits of `found` since the commit `base`, and calls
--- `done(nil, commits_since)`, or `done(failure)`. Before the first commit
--- there are none.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param base string|nil the full id of the commit the commits are counted from; nil counts every commit
---@param done fun(failure: aineo.git.Failure|nil, commits_since: aineo.git.CommitsSince|nil)
function M.commits_since(run, found, base, done)
  run(
    {
      directory = found.top,
      arguments = {
        'log',
        '-z',
        '--format=%H %s',
        '--no-show-signature',
        '--encoding=UTF-8',
        '--ignore-missing',
        '--end-of-options',
        base and base .. '..HEAD' or 'HEAD',
        '--',
      },
    },
    process.or_fail(done, function(log)
      if not base then
        done(nil, { commits = parse_log(log.stdout), base_is_ancestor = true })
        return
      end
      run(
        {
          directory = found.top,
          arguments = { 'merge-base', '--is-ancestor', '--end-of-options', base, 'HEAD' },
          answers = { IS_ANCESTOR_CODE, NOT_ANCESTOR_CODE },
        },
        process.or_fail(done, function(ancestry)
          done(nil, {
            commits = parse_log(log.stdout),
            base_is_ancestor = ancestry.code == IS_ANCESTOR_CODE,
          })
        end)
      )
    end)
  )
end

return M
