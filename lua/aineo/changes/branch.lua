--- Reads, for the changes pane, the local branches of the session's
--- repository: what `s` chooses its branches from, and, for the branch the
--- pane shows alone, its tip, its base and its commits.

local git = require('aineo.git')
local worktrees = require('aineo.changes.worktrees')
local working_branch = require('aineo.changes.working_branch')

local M = {}

--- What a read of the branches `s` chooses from starts from.
---@class aineo.changes.BranchesRead: aineo.changes.WorkingBranchRead

--- Reads the local branches (`git.list_branches()`), the worktrees, each as
--- it is now with the branch it is on (`git.list_worktrees()`), and the
--- working branch's name (`working_branch.read()`), one git at a time, and
--- calls `done(nil, candidates)`; or `done(failure)` for the first read that
--- fails. The worktrees are read again rather than taken from what the pane
--- last listed, as the editor's own worktree may have checked out another
--- branch since.
---
---@param read aineo.changes.BranchesRead
---@param done fun(failure: aineo.git.Failure|nil, candidates: aineo.changes.BranchCandidates|nil)
function M.read_candidates(read, done)
  git.list_branches(read.repository, function(branches_failure, branches)
    if branches_failure then
      done(branches_failure)
      return
    end
    git.list_worktrees(read.repository, function(worktrees_failure, listed)
      if worktrees_failure then
        done(worktrees_failure)
        return
      end
      working_branch.read(read, function(working_failure, name)
        if working_failure then
          done(working_failure)
          return
        end
        done(nil, { branches = branches, worktrees = listed, working_branch = name })
      end)
    end, read.git)
  end, read.git)
end

--- What the commits window knows of the local branch it shows alone. Either
--- `tip` and `commits` are given, or `names_no_commit` is, or neither, when
--- the first read failed.
---@class aineo.changes.BranchSection
---@field name string the branch's name
---@field tip? string the full id of the commit the branch named when it was last read
---@field base? string the branch's base at that read: its merge base with the commit the working branch names, else with the editor's comparison commit; nil when neither gave one, which counts every file and commit of the branch
---@field commits? aineo.git.Commit[] the commits reachable from `tip` and not from `base`, newest first
---@field names_no_commit? boolean whether the name named no commit when it was read: the branch was deleted or renamed
---@field failure? aineo.git.Failure why the last read failed, when it did; the other fields are then what the window knew before

--- Why nothing can be read from `section`, as the commit its files and
--- diffs are read at: its first read failed before a commit was known; or,
--- while the window has not read the branch, nothing is known of it.
---
---@param section aineo.changes.BranchSection|nil
---@return aineo.git.Failure
function M.unreadable(section)
  if section and section.failure then
    return section.failure
  end
  return { reason = 'failed', message = 'the branch has not been read yet' }
end

--- What a read of one local branch starts from.
---@class aineo.changes.BranchRead: aineo.changes.CommitBaseRead
---@field name string the branch's name
---@field before? aineo.changes.BranchSection what the commits window knew before this read

--- Reads the branch `read.name`: the commit it names now (`refs/heads/`
--- and its name, never another reference of the same name), its base
--- (`worktrees.read_base_of()`), and the commits of the tip the base cannot
--- reach, every commit of it when there is no base. Calls `done(section)`:
--- `names_no_commit` when the name names no commit. When a read fails, the
--- section is what the window knew before of the same branch, if anything,
--- with the `failure`. Nothing is kept: every call reads the tip and the
--- base anew.
---
---@param read aineo.changes.BranchRead
---@param done fun(section: aineo.changes.BranchSection)
function M.read(read, done)
  local function failed(failure)
    local before = read.before
    local kept = before and before.name == read.name and before or { name = read.name }
    done(vim.tbl_extend('force', kept, { failure = failure }))
  end
  git.resolve_commit(read.found, 'refs/heads/' .. read.name, function(tip_failure, tip)
    if tip_failure then
      failed(tip_failure)
    elseif not tip then
      done({ name = read.name, names_no_commit = true })
    else
      worktrees.read_base_of(read, tip, function(base_failure, base)
        if base_failure then
          failed(base_failure)
          return
        end
        git.commits_between(read.found, base, tip, function(commits_failure, commits)
          if commits_failure then
            failed(commits_failure)
          else
            done({ name = read.name, tip = tip, base = base, commits = commits })
          end
        end, read.git)
      end)
    end
  end, read.git)
end

return M
