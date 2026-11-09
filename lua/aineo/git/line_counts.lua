--- Counts the lines added and removed in each file of a repository that
--- differs from `HEAD`.

local private_index = require('aineo.git.private_index')
local process = require('aineo.git.process')
local repository = require('aineo.git.repository')

local M = {}

--- The lines added and removed in one file.
---@class aineo.git.LineCount
---@field added integer
---@field removed integer

--- The counts `git diff --numstat -z` gave as `output`: per file its
--- added and removed counts and its path, a binary file's counts shown as
--- `-`; for a rename the path field is empty, followed by the old path and
--- the new one. A binary file has no count here, and a rename counts under
--- its new path.
---
---@param output string
---@return table<string, aineo.git.LineCount>
local function parse_numstat(output)
  local fields = vim.split(output, '\0', { plain = true })
  local counts = {}
  local index = 1
  while index <= #fields do
    local added, removed, path = fields[index]:match('^([^\t]*)\t([^\t]*)\t(.*)$')
    if not added then
      index = index + 1
    else
      if path == '' then
        path = fields[index + 2]
        index = index + 3
      else
        index = index + 1
      end
      if added ~= '-' and removed ~= '-' and path then
        counts[path] = { added = tonumber(added), removed = tonumber(removed) }
      end
    end
  end
  return counts
end

--- Counts the lines added and removed in each file of `found` that differs
--- from `HEAD` as it is now, staged or not, and calls `done(nil, counts)`
--- with the counts by path relative to the repository's top level, or
--- `done(failure)`. A binary file, a file git does not track and a file with
--- no line changed have no count. The diff is read from one private copy of
--- the index (`private_index`), so the repository's own index and its lock
--- are never touched. Before the first commit every staged line counts as
--- added.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param done fun(failure: aineo.git.Failure|nil, counts: table<string, aineo.git.LineCount>|nil)
function M.line_counts(run, found, done)
  repository.read_head(
    run,
    found.top,
    process.or_fail(done, function(head)
      repository.comparison_base(
        run,
        found.top,
        head,
        process.or_fail(done, function(tree_ish)
          private_index.with_private_index(found.git_directory, function(environment, finish)
            run(
              {
                directory = found.top,
                arguments = { 'diff', '--numstat', '-z', '-M', '--end-of-options', tree_ish, '--' },
                environment = environment,
              },
              process.or_fail(finish, function(output)
                finish(nil, parse_numstat(output.stdout))
              end)
            )
          end, done)
        end)
      )
    end)
  )
end

return M
