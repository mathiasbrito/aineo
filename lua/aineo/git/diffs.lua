--- Gives the unified diffs of a repository's changed files and commits.

local private_index = require('aineo.git.private_index')
local process = require('aineo.git.process')
local repository = require('aineo.git.repository')

local M = {}

--- The code `git diff --no-index` exits with when the files differ, the diff
--- its answer; and also when it cannot read a file, with no diff printed.
local FILES_DIFFER_CODE = 1

--- The options that make `git diff` and `git show` print a plain unified
--- diff whatever the user's settings: no colours; git's own diff, not an
--- external program or a text conversion; `a/` and `b/` before the paths;
--- three lines of context, and hunks joined only where their context meets;
--- renames found; whole object ids; and files in git's own order, not a
--- user's order file.
local UNIFIED_DIFF = {
  '--no-color',
  '--no-ext-diff',
  '--no-textconv',
  '--src-prefix=a/',
  '--dst-prefix=b/',
  '--unified=3',
  '--inter-hunk-context=0',
  '--find-renames',
  '--full-index',
  '-O/dev/null',
}

--- The options that make `git show` print a commit's header in git's
--- default format whatever the user's settings: the medium format, the
--- whole id, no branch names or notes, the default date, the message in
--- UTF-8, no signature check, and a first commit's diff shown in full.
local COMMIT_HEADER = {
  '--root',
  '--pretty=medium',
  '--no-abbrev-commit',
  '--no-decorate',
  '--no-notes',
  '--date=default',
  '--encoding=UTF-8',
  '--no-show-signature',
}

--- The lists `lists` joined, in order, into a new one.
---
---@param lists string[][]
---@return string[]
local function joined(lists)
  local all = {}
  for _, list in ipairs(lists) do
    vim.list_extend(all, list)
  end
  return all
end

--- Gives the diff of an untracked file `change` names in `found`, compared
--- with nothing, since neither the base nor the index has it; or a failure,
--- in git's words, when git cannot read the file — gone since it was listed,
--- say, or a directory.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param change aineo.git.Change
---@param done fun(failure: aineo.git.Failure|nil, output: aineo.git.Output|nil)
local function untracked_diff(run, found, change, done)
  run(
    {
      directory = found.top,
      arguments = joined({
        { 'diff' },
        UNIFIED_DIFF,
        { '--no-index', '--', '/dev/null', change.path },
      }),
      answers = { 0, FILES_DIFFER_CODE },
    },
    process.or_fail(done, function(output)
      if output.code == FILES_DIFFER_CODE and output.stdout == '' then
        done({ reason = 'failed', message = vim.trim(output.stderr), code = output.code })
        return
      end
      done(nil, output)
    end)
  )
end

--- Gives the diff of the file `change` names in `found`, from `tree_ish` to
--- the working tree: a renamed one asked with both its paths, since git
--- shows the rename only then. The diff runs on a private copy of the index
--- (`private_index`), so it never takes the repository's lock.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param tree_ish string
---@param change aineo.git.Change
---@param done fun(failure: aineo.git.Failure|nil, output: aineo.git.Output|nil)
local function tracked_diff(run, found, tree_ish, change, done)
  local paths = change.kind == 'renamed' and { change.old_path, change.path } or { change.path }
  private_index.with_private_index(found.git_directory, function(environment, finish)
    run({
      directory = found.top,
      arguments = joined({
        { 'diff' },
        UNIFIED_DIFF,
        { '--end-of-options', tree_ish, '--' },
        paths,
      }),
      environment = environment,
    }, finish)
  end, done)
end

--- Gives the unified diff of the file `change` names in `found`, from the
--- commit `base` to the working tree, and calls `done(nil, diff)`, or
--- `done(failure)`.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param base string|nil the full id of the commit the diff runs from; nil runs it from nothing
---@param change aineo.git.Change
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
function M.file_diff(run, found, base, change, done)
  local give_diff = process.or_fail(done, function(output)
    done(nil, output.stdout)
  end)
  if change.kind == 'untracked' then
    untracked_diff(run, found, change, give_diff)
    return
  end
  repository.comparison_base(
    run,
    found.top,
    base,
    process.or_fail(done, function(tree_ish)
      tracked_diff(run, found, tree_ish, change, give_diff)
    end)
  )
end

--- Gives the unified diff of the commit `commit` in `found`, after its
--- header, as `git show` gives it in its default format, and calls
--- `done(nil, diff)`, or `done(failure)`.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param commit string
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
function M.commit_diff(run, found, commit, done)
  run(
    {
      directory = found.top,
      arguments = joined({
        { 'show' },
        COMMIT_HEADER,
        UNIFIED_DIFF,
        { '--end-of-options', commit, '--' },
      }),
    },
    process.or_fail(done, function(output)
      done(nil, output.stdout)
    end)
  )
end

return M
