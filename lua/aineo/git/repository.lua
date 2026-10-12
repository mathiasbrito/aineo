--- Finds the repository a directory is in, and what its `HEAD` names.

local process = require('aineo.git.process')

local M = {}

--- A repository, as git gives it for a directory inside it.
---@class aineo.git.Repository
---@field top string its top level, the directory of its working tree
---@field git_directory string its git directory, absolute: `<top>/.git`, or `<main>/.git/worktrees/<name>` for a linked worktree
---@field common_directory string the git directory it shares with its linked worktrees, absolute, where its branches live
---@field head string|nil the full id of the commit `HEAD` names; nil before the first commit
---@field branch string|nil the branch `HEAD` is on; nil when `HEAD` is detached

--- The code git exits with when it cannot find a repository for the
--- directory it is given.
local NOT_A_REPOSITORY_CODE = 128

--- The code `git rev-parse --verify --quiet` and `git symbolic-ref --quiet`
--- exit with, silently, when `HEAD` names no commit yet or no branch: an
--- answer, not a failure.
local NONE_CODE = 1

--- The paths `git rev-parse` prints for `locate()`, one per line: the top
--- level, the git directory and the common one. A path that holds a
--- newline makes more lines than this, and cannot be read from them.
local LOCATED_PATHS = 3

--- Splits `output` into its lines, the last newline dropped.
---
---@param output string
---@return string[]
local function lines_of(output)
  return vim.split(output:gsub('\n$', ''), '\n', { plain = true })
end

--- The first line of `output`, or nil when it has none.
---
---@param output string
---@return string|nil
function M.first_line(output)
  local line = lines_of(output)[1]
  return line ~= '' and line or nil
end

--- Finds the top level and the git directories of the repository
--- `directory` is in, and calls `done(nil, top, git_directory,
--- common_directory)`, or `done(failure)` — a `not_a_repository` one when
--- git finds none, a `failed` one when a path holds a newline.
---
---@param run aineo.git.Run
---@param directory string
---@param done fun(failure: aineo.git.Failure|nil, top: string?, git_directory: string?, common_directory: string?)
local function locate(run, directory, done)
  run({
    directory = directory,
    arguments = {
      'rev-parse',
      '--show-toplevel',
      '--absolute-git-dir',
      '--path-format=absolute',
      '--git-common-dir',
    },
  }, function(failure, output)
    if failure and failure.code == NOT_A_REPOSITORY_CODE then
      done({ reason = 'not_a_repository', message = failure.message })
      return
    end
    if failure then
      done(failure)
      return
    end
    local paths = lines_of(output.stdout)
    if #paths ~= LOCATED_PATHS then
      done({
        reason = 'failed',
        message = ('git gave %d lines for the %d paths of the repository: a path holds a newline'):format(
          #paths,
          LOCATED_PATHS
        ),
      })
      return
    end
    done(nil, unpack(paths))
  end)
end

--- Reads the commit `HEAD` names in the repository at `top`, and the branch
--- it is on, and calls `done(nil, head, branch)`, either nil when there is
--- none; or `done(failure)`.
---
---@param run aineo.git.Run
---@param top string
---@param done fun(failure: aineo.git.Failure|nil, head: string?, branch: string?)
function M.read_head(run, top, done)
  run(
    {
      directory = top,
      arguments = { 'rev-parse', '--verify', '--quiet', 'HEAD' },
      answers = { 0, NONE_CODE },
    },
    process.or_fail(done, function(head)
      run(
        {
          directory = top,
          arguments = { 'symbolic-ref', '--quiet', 'HEAD' },
          answers = { 0, NONE_CODE },
        },
        process.or_fail(done, function(reference)
          done(
            nil,
            M.first_line(head.stdout),
            M.first_line((reference.stdout:gsub('^refs/heads/', '')))
          )
        end)
      )
    end)
  )
end

--- Reads the commit the upstream of `branch` names in the repository at
--- `top`, and calls `done(nil, upstream)`, nil when `branch` has no
--- upstream, or one whose branch git does not have; or `done(failure)`.
---
---@param run aineo.git.Run
---@param top string
---@param branch string
---@param done fun(failure: aineo.git.Failure|nil, upstream: string?)
function M.read_upstream(run, top, branch, done)
  run(
    {
      directory = top,
      arguments = {
        'rev-parse',
        '--verify',
        '--quiet',
        '--end-of-options',
        branch .. '@{upstream}',
      },
      answers = { 0, NONE_CODE },
    },
    process.or_fail(done, function(upstream)
      done(nil, M.first_line(upstream.stdout))
    end)
  )
end

--- Reads the full id of the commit the name `name` gives in the repository at
--- `top`, as git reads a name — a branch, a remote-tracking branch, a tag
--- (an annotated one gives the commit it tags), a reference by its full
--- path, an id — and calls `done(nil, commit)`, nil when the name gives no
--- commit; or `done(failure)`. A name that begins with `-` is a name.
---
---@param run aineo.git.Run
---@param top string
---@param name string
---@param done fun(failure: aineo.git.Failure|nil, commit: string?)
function M.resolve_commit(run, top, name, done)
  run(
    {
      directory = top,
      arguments = { 'rev-parse', '--verify', '--quiet', '--end-of-options', name .. '^{commit}' },
      answers = { 0, NONE_CODE },
    },
    process.or_fail(done, function(commit)
      done(nil, M.first_line(commit.stdout))
    end)
  )
end

--- Reads the short name of the branch the remote `origin`'s `HEAD` points at
--- in the repository at `top` — `origin/main` — and calls `done(nil, name)`,
--- nil when the repository has no `origin/HEAD`; or `done(failure)`. It is
--- the remote's choice of default branch, whatever branch `top` has checked
--- out.
---
---@param run aineo.git.Run
---@param top string
---@param done fun(failure: aineo.git.Failure|nil, name: string?)
function M.read_remote_default_branch(run, top, done)
  run(
    {
      directory = top,
      arguments = { 'symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD' },
      answers = { 0, NONE_CODE },
    },
    process.or_fail(done, function(reference)
      done(nil, M.first_line(reference.stdout))
    end)
  )
end

--- Finds the repository `directory` is in, and calls `done(nil,
--- repository)`, or `done(failure)`.
---
---@param run aineo.git.Run
---@param directory string
---@param done fun(failure: aineo.git.Failure|nil, repository: aineo.git.Repository|nil)
function M.find_repository(run, directory, done)
  locate(
    run,
    directory,
    process.or_fail(done, function(top, git_directory, common_directory)
      M.read_head(
        run,
        top,
        process.or_fail(done, function(head, branch)
          done(nil, {
            top = top,
            git_directory = git_directory,
            common_directory = common_directory,
            head = head,
            branch = branch,
          })
        end)
      )
    end)
  )
end

--- Calls `done(nil, tree_ish)` with what the repository at `top` compares
--- against for the commit `base`: `base` itself, or when there is none the
--- empty tree, in the repository's own hash; or `done(failure)`.
---
---@param run aineo.git.Run
---@param top string
---@param base string|nil
---@param done fun(failure: aineo.git.Failure|nil, tree_ish: string?)
function M.comparison_base(run, top, base, done)
  if base then
    done(nil, base)
    return
  end
  run(
    { directory = top, arguments = { 'hash-object', '-t', 'tree', '/dev/null' } },
    process.or_fail(done, function(output)
      done(nil, M.first_line(output.stdout))
    end)
  )
end

--- Calls `done(nil, revisions)` with the revision arguments `git diff` takes
--- to compare the commit `to` straight with the commit `from`, or with the
--- empty tree when `from` is nil; or `done(failure)`.
---
---@param run aineo.git.Run
---@param top string
---@param from string|nil
---@param to string
---@param done fun(failure: aineo.git.Failure|nil, revisions: string[]?)
function M.straight_revisions(run, top, from, to, done)
  M.comparison_base(
    run,
    top,
    from,
    process.or_fail(done, function(tree_ish)
      done(nil, { tree_ish, to })
    end)
  )
end

--- Calls `done(nil, revisions)` with the revision arguments `git diff` takes
--- to compare the commit `to` with the merge base of `from` and `to` —
--- `from...to`, what `to` gained since the two forked — or with the empty
--- tree when `from` is nil; or `done(failure)`.
---
---@param run aineo.git.Run
---@param top string
---@param from string|nil
---@param to string
---@param done fun(failure: aineo.git.Failure|nil, revisions: string[]?)
function M.merge_base_revisions(run, top, from, to, done)
  if from then
    done(nil, { from .. '...' .. to })
    return
  end
  M.straight_revisions(run, top, nil, to, done)
end

return M
