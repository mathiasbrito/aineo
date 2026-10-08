--- Lists the worktrees of a repository, and reads the base of each one
--- other than the editor's.

local process = require('aineo.git.process')
local repository = require('aineo.git.repository')

local M = {}

--- A worktree of a repository, as `git worktree list` gives it.
---@class aineo.git.Worktree
---@field top string its top level, the directory of its working tree
---@field head string|nil the full id of the commit its `HEAD` names; nil before its first commit
---@field branch string|nil the branch its `HEAD` is on; nil when `HEAD` is detached

--- A worktree as `git worktree list` gives it, and whether git marks it as
--- one the home leaves out.
---@class aineo.git.ListedWorktree
---@field worktree aineo.git.Worktree
---@field left_out boolean whether git marks it `prunable`, its directory gone, or `bare`, the directory of a bare repository, which has no working tree to read

--- The fields `git worktree list` marks a worktree the home leaves out with.
local LEFT_OUT_MARKS = { prunable = true, bare = true }

--- The worktrees `git worktree list --porcelain -z` gave as `output`, in its
--- order: each a run of fields, each field ended by a NUL, the run by an
--- empty field, so that a path holding a newline is read whole. The `HEAD`
--- of zeros git gives a worktree with no commit yet names none.
---
---@param output string
---@return aineo.git.ListedWorktree[]
local function parse_porcelain(output)
  local listed, current = {}, nil
  for _, field in ipairs(vim.split(output, '\0', { plain = true })) do
    local name, value = field:match('^(%S+) ?(.*)$')
    if name == 'worktree' then
      current = { worktree = { top = value }, left_out = false }
      table.insert(listed, current)
    elseif name == 'HEAD' and not value:find('^0+$') then
      current.worktree.head = value
    elseif name == 'branch' then
      current.worktree.branch = value:gsub('^refs/heads/', '')
    elseif LEFT_OUT_MARKS[name] then
      current.left_out = true
    end
  end
  return listed
end

--- Lists the worktrees of the repository `found` is in, and calls
--- `done(nil, worktrees)`, the worktree `found` is first and the others in
--- git's order, or `done(failure)`. A worktree git marks `prunable` or
--- `bare` is left out (`LEFT_OUT_MARKS`), and so is one whose directory does
--- not exist, which git marks `locked` rather than `prunable` once it is
--- locked.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param done fun(failure: aineo.git.Failure|nil, worktrees: aineo.git.Worktree[]|nil)
function M.list_worktrees(run, found, done)
  run(
    { directory = found.top, arguments = { 'worktree', 'list', '--porcelain', '-z' } },
    process.or_fail(done, function(output)
      local own, others = {}, {}
      for _, listed in ipairs(parse_porcelain(output.stdout)) do
        local worktree = listed.worktree
        if not listed.left_out and vim.uv.fs_stat(worktree.top) then
          table.insert(worktree.top == found.top and own or others, worktree)
        end
      end
      done(nil, vim.list_extend(own, others))
    end)
  )
end

--- The code `git merge-base` exits with, silently, when the two commits
--- share no history: an answer, not a failure.
local NO_MERGE_BASE_CODE = 1

--- Reads the merge base of `worktree`'s `HEAD` and the commit `other`, and
--- calls `done(nil, base)`, nil when they share no history or either has
--- no commit yet; or `done(failure)`.
---
---@param run aineo.git.Run
---@param worktree aineo.git.Worktree
---@param other string|nil
---@param done fun(failure: aineo.git.Failure|nil, base: string?)
local function merge_base(run, worktree, other, done)
  if not (worktree.head and other) then
    done(nil, nil)
    return
  end
  run(
    {
      directory = worktree.top,
      arguments = { 'merge-base', worktree.head, other },
      answers = { 0, NO_MERGE_BASE_CODE },
    },
    process.or_fail(done, function(output)
      done(nil, repository.first_line(output.stdout))
    end)
  )
end

--- Reads the base of `worktree`, one of the repository's worktrees other
--- than the editor's, `found`, as `found`'s `HEAD` is now: its merge base
--- with the upstream of the branch `found` is on; with that branch when it
--- has no upstream; with `found`'s `HEAD` when that is detached. Calls
--- `done(nil, base)`, nil when they share no history or either has no
--- commit yet, or `done(failure)`.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param worktree aineo.git.Worktree
---@param done fun(failure: aineo.git.Failure|nil, base: string?)
function M.worktree_base(run, found, worktree, done)
  repository.read_head(
    run,
    found.top,
    process.or_fail(done, function(head, branch)
      if not branch then
        merge_base(run, worktree, head, done)
        return
      end
      repository.read_upstream(
        run,
        found.top,
        branch,
        process.or_fail(done, function(upstream)
          merge_base(run, worktree, upstream or head, done)
        end)
      )
    end)
  )
end

return M
