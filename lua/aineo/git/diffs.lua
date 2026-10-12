--- Gives the unified diffs of a repository's changed files, commits, and the
--- changes between two commits.
---
--- The attributes in force stay in force: the repository's own
--- (`.gitattributes`, `.git/info/attributes`) and the user's
--- (`core.attributesFile`). A file they mark binary — `binary`, `-diff`, or a
--- diff driver the user's configuration makes `binary` — shows as git shows
--- it, `Binary files a/<path> and b/<path> differ`, and their `text` and
--- `eol` decide which line endings count as a change.

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
--- hunks joined only where their context meets; renames found; whole object
--- ids; and files in git's own order, not a user's order file. The context
--- around a change is the caller's (`context_option()`).
local UNIFIED_DIFF = {
  '--no-color',
  '--no-ext-diff',
  '--no-textconv',
  '--src-prefix=a/',
  '--dst-prefix=b/',
  '--inter-hunk-context=0',
  '--find-renames',
  '--full-index',
  '-O/dev/null',
}

--- How much of a file a diff shows around its changes: three lines, or the
--- whole file.
---@alias aineo.git.DiffContext 'three_lines'|'whole_file'

--- The option that gives each context of a diff (`aineo.git.DiffContext`):
--- three lines around a change, or git's context made unlimited, with the
--- largest count git takes (`2147483648` wraps to a negative one).
---@type table<aineo.git.DiffContext, string>
local CONTEXT_OPTIONS = {
  three_lines = '--unified=3',
  whole_file = '--unified=2147483647',
}

--- The context a diff has when its caller names none.
---@type aineo.git.DiffContext
local DEFAULT_CONTEXT = 'three_lines'

--- The option that sets a diff's context to `context`, three lines when nil.
--- Raises an error naming the contexts there are, for one there is not.
---
---@param context aineo.git.DiffContext|nil
---@return string
local function context_option(context)
  local option = CONTEXT_OPTIONS[context or DEFAULT_CONTEXT]
  if not option then
    error(("context must be 'three_lines' or 'whole_file', not %s"):format(vim.inspect(context)), 0)
  end
  return option
end

--- The options that make `git show` print a commit's header in git's
--- default format whatever the user's settings: the medium format, the
--- whole id, no branch names or notes, the default date, the message in
--- UTF-8, no signature check, a first commit's diff shown in full, and a
--- merge's diff taken against its first parent: what the merge brought in.
local COMMIT_HEADER = {
  '--root',
  '--diff-merges=first-parent',
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
---@param unified string the option that sets the diff's context (`context_option()`)
---@param done fun(failure: aineo.git.Failure|nil, output: aineo.git.Output|nil)
local function untracked_diff(run, found, change, unified, done)
  run(
    {
      directory = found.top,
      arguments = joined({
        { 'diff' },
        UNIFIED_DIFF,
        { unified },
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
---@param unified string the option that sets the diff's context (`context_option()`)
---@param done fun(failure: aineo.git.Failure|nil, output: aineo.git.Output|nil)
local function tracked_diff(run, found, tree_ish, change, unified, done)
  local paths = change.kind == 'renamed' and { change.old_path, change.path } or { change.path }
  private_index.with_private_index(found.git_directory, function(environment, finish)
    run({
      directory = found.top,
      arguments = joined({
        { 'diff' },
        UNIFIED_DIFF,
        { unified },
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
---@param context? aineo.git.DiffContext the lines of context around a change; three when not given
function M.file_diff(run, found, base, change, done, context)
  local unified = context_option(context)
  local give_diff = process.or_fail(done, function(output)
    done(nil, output.stdout)
  end)
  if change.kind == 'untracked' then
    untracked_diff(run, found, change, unified, give_diff)
    return
  end
  repository.comparison_base(
    run,
    found.top,
    base,
    process.or_fail(done, function(tree_ish)
      tracked_diff(run, found, tree_ish, change, unified, give_diff)
    end)
  )
end

--- Gives the commit `commit` in `found`, after its header, as `git show`
--- gives it in its default format, limited to `paths` or, when there are
--- none, whole, and calls `done(nil, diff)`, or `done(failure)`.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param commit string
---@param paths string[]
---@param unified string the option that sets the diff's context (`context_option()`)
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
local function show_commit(run, found, commit, paths, unified, done)
  run(
    {
      directory = found.top,
      arguments = joined({
        { 'show' },
        COMMIT_HEADER,
        UNIFIED_DIFF,
        { unified },
        { '--end-of-options', commit, '--' },
        paths,
      }),
    },
    process.or_fail(done, function(output)
      done(nil, output.stdout)
    end)
  )
end

--- Gives the unified diff of the commit `commit` in `found`, after its
--- header, as `git show` gives it in its default format — a merge's against
--- its first parent — and calls `done(nil, diff)`, or `done(failure)`.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param commit string
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param context? aineo.git.DiffContext the lines of context around a change; three when not given
function M.commit_diff(run, found, commit, done, context)
  show_commit(run, found, commit, {}, context_option(context), done)
end

--- Gives the commit `commit` in `found`, after its header, as
--- `M.commit_diff()` does, limited to the file `change` names: a renamed one
--- asked with both its paths, since git shows the rename only then. Calls
--- `done(nil, diff)`, or `done(failure)`.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param commit string
---@param change aineo.git.Change one of the changes `changes.commit_files()` gave
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param context? aineo.git.DiffContext the lines of context around a change; three when not given
function M.commit_file_diff(run, found, commit, change, done, context)
  local paths = change.kind == 'renamed' and { change.old_path, change.path } or { change.path }
  show_commit(run, found, commit, paths, context_option(context), done)
end

--- Gives the unified diff of the file `change` names in `found`, from
--- `HEAD` as it is now to the working tree, as `M.file_diff()` gives it from
--- a base, and calls `done(nil, diff)`, or `done(failure)`. Before the first
--- commit the file is wholly added.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param change aineo.git.Change
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param context? aineo.git.DiffContext the lines of context around a change; three when not given
function M.uncommitted_file_diff(run, found, change, done, context)
  context_option(context)
  repository.read_head(
    run,
    found.top,
    process.or_fail(done, function(head)
      M.file_diff(run, found, head, change, done, context)
    end)
  )
end

--- The files `git ls-files --others -z` gave as `output`, less the
--- directories it names, which end in a slash: an untracked repository
--- with no commit yet, which git cannot enter as to be added.
---
---@param output string
---@return string[]
local function untracked_files(output)
  return vim.tbl_filter(function(path)
    return not vim.endswith(path, '/')
  end, vim.split(output, '\0', { plain = true, trimempty = true }))
end

--- Enters `paths`, files of `found`, in the index `environment` names as to
--- be added (`git add --intent-to-add`), and calls `done(nil, output)`, or
--- `done(failure)`. The paths go to git in a file beside that index, NUL
--- separated and removed once git has run, so that their number is not
--- bounded by the length of a command line.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param environment table<string, string>
---@param paths string[]
---@param done fun(failure: aineo.git.Failure|nil, output: aineo.git.Output|nil)
local function enter_as_to_be_added(run, found, environment, paths, done)
  local list = environment.GIT_INDEX_FILE .. '.untracked'
  local file, opening_failure = io.open(list, 'wb')
  if not file then
    done({ reason = 'failed', message = 'cannot write the list of new files: ' .. opening_failure })
    return
  end
  file:write(table.concat(paths, '\0'), '\0')
  file:close()
  run({
    directory = found.top,
    arguments = {
      'add',
      '--intent-to-add',
      '--pathspec-from-file=' .. list,
      '--pathspec-file-nul',
    },
    environment = environment,
  }, function(...)
    os.remove(list)
    done(...)
  end)
end

--- Gives the diff of every file of `found` from `tree_ish` to the working
--- tree, the untracked files wholly added: they are entered in a private
--- copy of the index as to be added (`enter_as_to_be_added()`), so that the
--- diff shows them, and the repository's own index and lock are never
--- touched (`private_index`). Calls `done(nil, output)`, or `done(failure)`.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param tree_ish string
---@param unified string the option that sets the diff's context (`context_option()`)
---@param done fun(failure: aineo.git.Failure|nil, output: aineo.git.Output|nil)
local function whole_diff(run, found, tree_ish, unified, done)
  private_index.with_private_index(found.git_directory, function(environment, finish)
    local function diff_from_tree()
      run({
        directory = found.top,
        arguments = joined({
          { 'diff' },
          UNIFIED_DIFF,
          { unified },
          { '--end-of-options', tree_ish, '--' },
        }),
        environment = environment,
      }, finish)
    end
    run(
      {
        directory = found.top,
        arguments = { 'ls-files', '--others', '--exclude-standard', '-z' },
        environment = environment,
      },
      process.or_fail(finish, function(untracked)
        local paths = untracked_files(untracked.stdout)
        if #paths == 0 then
          diff_from_tree()
          return
        end
        enter_as_to_be_added(
          run,
          found,
          environment,
          paths,
          process.or_fail(finish, diff_from_tree)
        )
      end)
    )
  end, done)
end

--- Gives the unified diff of every file of `found` from the commit `base` to
--- the working tree, the untracked files the ignore rules leave in wholly
--- added, and calls `done(nil, diff)`, or `done(failure)`.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param base string|nil the full id of the commit the diff runs from; nil runs it from nothing
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param context? aineo.git.DiffContext the lines of context around a change; three when not given
function M.diff_since(run, found, base, done, context)
  local unified = context_option(context)
  local give_diff = process.or_fail(done, function(output)
    done(nil, output.stdout)
  end)
  repository.comparison_base(
    run,
    found.top,
    base,
    process.or_fail(done, function(tree_ish)
      whole_diff(run, found, tree_ish, unified, give_diff)
    end)
  )
end

--- Gives the diff between two commits of `found`, as `git diff` prints it
--- for `revisions` (`repository.merge_base_revisions()` or
--- `repository.straight_revisions()`), limited to `paths` or, when there are
--- none, whole, and calls `done(nil, diff)`, or `done(failure)`. Only the
--- commits are read, so no private index is needed.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param revisions string[]
---@param paths string[]
---@param unified string the option that sets the diff's context (`context_option()`)
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
local function diff_commits(run, found, revisions, paths, unified, done)
  run(
    {
      directory = found.top,
      arguments = joined({
        { 'diff' },
        UNIFIED_DIFF,
        { unified },
        { '--end-of-options' },
        revisions,
        { '--' },
        paths,
      }),
    },
    process.or_fail(done, function(output)
      done(nil, output.stdout)
    end)
  )
end

--- The paths a diff limited to the file `change` names asks git for: a
--- renamed one with both its paths, since git shows the rename only then.
---
---@param change aineo.git.Change
---@return string[]
local function paths_of(change)
  return change.kind == 'renamed' and { change.old_path, change.path } or { change.path }
end

--- Gives the unified diff of every file of `found` between the merge base of
--- the commits `from` and `to`, and `to`, and calls `done(nil, diff)`, or
--- `done(failure)`.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param from string|nil the full id of the first commit; nil runs the diff from nothing
---@param to string the full id of the second commit
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param context? aineo.git.DiffContext the lines of context around a change; three when not given
function M.diff_between(run, found, from, to, done, context)
  local unified = context_option(context)
  repository.merge_base_revisions(
    run,
    found.top,
    from,
    to,
    process.or_fail(done, function(revisions)
      diff_commits(run, found, revisions, {}, unified, done)
    end)
  )
end

--- Gives the unified diff of the file `change` names in `found` between the
--- merge base of the commits `from` and `to`, and `to`, as
--- `M.diff_between()` gives it, and calls `done(nil, diff)`, or
--- `done(failure)`.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param from string|nil the full id of the first commit; nil runs the diff from nothing
---@param to string the full id of the second commit
---@param change aineo.git.Change
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param context? aineo.git.DiffContext the lines of context around a change; three when not given
function M.file_diff_between(run, found, from, to, change, done, context)
  local unified = context_option(context)
  repository.merge_base_revisions(
    run,
    found.top,
    from,
    to,
    process.or_fail(done, function(revisions)
      diff_commits(run, found, revisions, paths_of(change), unified, done)
    end)
  )
end

--- Gives the unified diff of the file `change` names in `found` straight
--- from the commit `from` to the commit `to`, not from their merge base, and
--- calls `done(nil, diff)`, or `done(failure)`.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param from string|nil the full id of the first commit; nil runs the diff from nothing
---@param to string the full id of the second commit
---@param change aineo.git.Change
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param context? aineo.git.DiffContext the lines of context around a change; three when not given
function M.file_diff_straight(run, found, from, to, change, done, context)
  local unified = context_option(context)
  repository.straight_revisions(
    run,
    found.top,
    from,
    to,
    process.or_fail(done, function(revisions)
      diff_commits(run, found, revisions, paths_of(change), unified, done)
    end)
  )
end

--- Gives the unified diff of every file of `found` from `HEAD` as it is now
--- to the working tree, as `M.diff_since()` gives it from a base, and calls
--- `done(nil, diff)`, or `done(failure)`. Before the first commit every file
--- is wholly added.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param context? aineo.git.DiffContext the lines of context around a change; three when not given
function M.uncommitted_diff(run, found, done, context)
  context_option(context)
  repository.read_head(
    run,
    found.top,
    process.or_fail(done, function(head)
      M.diff_since(run, found, head, done, context)
    end)
  )
end

return M
