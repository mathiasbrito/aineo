--- Lists the files of a repository that differ from a base.

local private_index = require('aineo.git.private_index')
local process = require('aineo.git.process')
local repository = require('aineo.git.repository')

local M = {}

--- A file that differs from a base.
---@class aineo.git.Change
---@field path string the file's path, relative to the repository's top level, exactly as on disk
---@field kind 'added'|'modified'|'deleted'|'renamed'|'type_changed'|'untracked' how it differs from the base: `type_changed` when it turned from a file into a link or back; `renamed` once the rename is staged or committed; `untracked` is new, and neither staged nor excluded by the repository's ignore rules
---@field old_path? string the path it had in the base, when it was `renamed`

--- The kind of change each status letter of `git diff --name-status` names.
local KIND_OF_STATUS = {
  A = 'added',
  M = 'modified',
  D = 'deleted',
  T = 'type_changed',
}

--- The changes `git diff --name-status -z` gave as `output`: a status
--- field, then the path, or for a rename its score after the `R`, then the
--- old path and the new one.
---
---@param output string
---@return aineo.git.Change[]
local function parse_name_status(output)
  local fields = vim.split(output, '\0', { plain = true })
  local changes = {}
  local index = 1
  while index < #fields do
    local status = fields[index]:sub(1, 1)
    if status == 'R' then
      table.insert(
        changes,
        { path = fields[index + 2], kind = 'renamed', old_path = fields[index + 1] }
      )
      index = index + 3
    else
      table.insert(changes, { path = fields[index + 1], kind = KIND_OF_STATUS[status] })
      index = index + 2
    end
  end
  return changes
end

--- The untracked files `git ls-files --others -z` gave as `output`.
---
---@param output string
---@return aineo.git.Change[]
local function parse_untracked(output)
  local untracked = {}
  for _, path in ipairs(vim.split(output, '\0', { plain = true, trimempty = true })) do
    table.insert(untracked, { path = path, kind = 'untracked' })
  end
  return untracked
end

--- Lists the files of `found` that differ from `tree_ish`, and calls `done`
--- as `M.changed_files()` does. The diff runs on a private copy of the index
--- (`private_index`), so it never takes the repository's lock.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param tree_ish string
---@param done fun(failure: aineo.git.Failure|nil, changes: aineo.git.Change[]|nil)
local function list_changes(run, found, tree_ish, done)
  private_index.with_private_index(
    found.git_directory,
    function(environment, finish)
      run({
        directory = found.top,
        arguments = { 'diff', '--name-status', '-z', '-M', '--end-of-options', tree_ish, '--' },
        environment = environment,
      }, finish)
    end,
    process.or_fail(done, function(differing)
      run(
        {
          directory = found.top,
          arguments = { 'ls-files', '--others', '--exclude-standard', '-z' },
        },
        process.or_fail(done, function(untracked)
          done(
            nil,
            vim.list_extend(parse_name_status(differing.stdout), parse_untracked(untracked.stdout))
          )
        end)
      )
    end)
  )
end

--- Lists the files of `found` that differ from the commit `base`, and calls
--- `done(nil, changes)`, or `done(failure)`.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param base string|nil the full id of the commit the changes are counted from; nil counts every file as new
---@param done fun(failure: aineo.git.Failure|nil, changes: aineo.git.Change[]|nil)
function M.changed_files(run, found, base, done)
  repository.comparison_base(
    run,
    found.top,
    base,
    process.or_fail(done, function(tree_ish)
      list_changes(run, found, tree_ish, done)
    end)
  )
end

return M
