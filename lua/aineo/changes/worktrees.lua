--- Reads, for the changes pane, what each worktree of the session's
--- repository other than the editor's lists: for the commits window, every
--- worktree's commits; for the files window, one worktree's files.

local git = require('aineo.git')
local reports = require('aineo.changes.reports')
local working_branch = require('aineo.changes.working_branch')

local M = {}

--- Where a base came from when an agent reported it.
---@type aineo.changes.BaseOrigin
M.REPORTED_ORIGIN = { kind = 'reported' }

--- What one window knows of a worktree other than the editor's.
---@class aineo.changes.WorktreeSection
---@field top string the worktree's top level
---@field branch string|nil the branch it is on, as last listed; nil when detached
---@field repository? aineo.git.Repository the worktree's repository, as its last read found it
---@field base? string the worktree's base when its list was last read
---@field base_origin? aineo.changes.BaseOrigin where `base` came from
---@field listed? any what its last read gave: the window's list for it
---@field failure? aineo.git.Failure why its last read failed, when it did

--- What one window knows of the worktrees other than the editor's.
---@class aineo.changes.OtherWorktrees
---@field sections aineo.changes.WorktreeSection[] one per worktree, in the order git lists them
---@field failure? aineo.git.Failure why the worktrees could not be listed, when the last list failed

--- What the other worktrees' sections are before any was read.
---@type aineo.changes.OtherWorktrees
M.NONE = { sections = {} }

--- Reads one window's list for a worktree.
---@alias aineo.changes.ReadList fun(repository: aineo.git.Repository, base: string|nil, done: fun(failure: aineo.git.Failure|nil, listed: any))

--- What a read of one worktree starts from.
---@class aineo.changes.WorktreeRead: aineo.changes.CommitBaseRead
---@field before aineo.changes.OtherWorktrees what the window knew of the other worktrees before this read
---@field read_list aineo.changes.ReadList reads the window's list for a worktree
---@field base_of? fun(worktree: aineo.git.Worktree): string|nil the commit an agent reported the branch `worktree` has checked out was made from, nil when none was: read from in place of the one `read_base()` reads when `M.read_effective_base()` chooses it

--- What a read of the other worktrees, for one window, starts from.
---@class aineo.changes.WorktreesRead: aineo.changes.WorktreeRead
---@field before_each_worktree fun(proceed: fun()) runs before each worktree's read, which starts once it calls `proceed()`

--- What the bases of one read are taken against.
---@class aineo.changes.BaseSources
---@field working_commit string|nil the commit the working branch names now; nil when it gives none: no working branch, or a name that names no commit
---@field working_name string|nil the working branch's name; nil when there is none
---@field comparison fun(done: fun(failure: aineo.git.Failure|nil, commit: string|nil)) reads the editor's comparison commit (`git.comparison_commit()`), on its first call alone; a later call is answered with the first call's answer

--- The function that reads the editor's comparison commit for one read, once
--- however many worktrees need it, and answers every later call with the
--- first answer, a failure included.
---
---@param read aineo.changes.CommitBaseRead
---@return fun(done: fun(failure: aineo.git.Failure|nil, commit: string|nil))
local function comparison_read_once(read)
  local answered, answered_failure, answered_commit = false, nil, nil
  return function(done)
    if answered then
      done(answered_failure, answered_commit)
      return
    end
    git.comparison_commit(read.found, function(failure, commit)
      answered, answered_failure, answered_commit = true, failure, commit
      done(failure, commit)
    end, read.git)
  end
end

--- Reads what the bases of one read are taken against: the commit the
--- working branch names now (`working_branch.read()`), once, and calls
--- `done(nil, sources)`; or `done(failure)` when the working branch's name
--- or commit cannot be read.
---
---@param read aineo.changes.CommitBaseRead
---@param done fun(failure: aineo.git.Failure|nil, sources: aineo.changes.BaseSources|nil)
local function read_base_sources(read, done)
  working_branch.read({
    repository = read.found,
    working_branch = read.working_branch,
    git = read.git,
  }, function(failure, name, commit)
    if failure then
      done(failure)
      return
    end
    done(nil, {
      working_commit = commit,
      working_name = name,
      comparison = comparison_read_once(read),
    })
  end)
end

--- The section of `before` for the worktree at `top`, or nil when it has
--- none.
---
---@param before aineo.changes.OtherWorktrees
---@param top string
---@return aineo.changes.WorktreeSection|nil
local function section_before(before, top)
  for _, section in ipairs(before.sections) do
    if section.top == top then
      return section
    end
  end
  return nil
end

--- Whether `repository`, what git found from `worktree`'s directory, is
--- that worktree: its top level, or its git directory where git lists a
--- worktree by it, as it lists a submodule's checkout. A directory that
--- no longer is a worktree, its `.git` gone, is in whatever repository
--- holds it, or in none.
---
---@param repository aineo.git.Repository
---@param worktree aineo.git.Worktree
---@return boolean
local function is_listed_worktree(repository, worktree)
  return repository.top == worktree.top or repository.git_directory == worktree.top
end

--- The section of `worktree` before it is read: its top level and branch,
--- and what the window last read for it (`section_before()`), if anything.
---
---@param read aineo.changes.WorktreeRead
---@param worktree aineo.git.Worktree
---@return aineo.changes.WorktreeSection
local function unread_section(read, worktree)
  local section = { top = worktree.top, branch = worktree.branch }
  local before = section_before(read.before, worktree.top)
  if before then
    section.repository, section.base, section.listed = before.repository, before.base, before.listed
    section.base_origin = before.base_origin
  end
  return section
end

--- The section of `worktree` for a read that failed before the worktree's
--- own was begun: `unread_section()` saying why.
---
---@param read aineo.changes.WorktreeRead
---@param worktree aineo.git.Worktree
---@param failure aineo.git.Failure
---@return aineo.changes.WorktreeSection
local function failed_section(read, worktree, failure)
  local section = unread_section(read, worktree)
  section.failure = failure
  return section
end

--- Reads the base of `repository`, the worktree's: its merge base with the
--- commit the working branch names (`sources.working_commit`), else, where
--- that gives none — no working branch, a name that names no commit, no
--- shared history — its merge base with the editor's comparison commit
--- (`sources.comparison`). Calls `done(nil, base, origin)`, `base` nil when
--- neither gives one, and at once, reading neither, for a worktree with no
--- commit yet, and `origin` saying what the merge base was taken against: the
--- working branch's name, or the comparison commit; or `done(failure)`.
---
---@param read { git?: aineo.git.Options }
---@param sources aineo.changes.BaseSources
---@param repository { top: string, head: string|nil } a worktree, or the top level of the editor's repository with a commit as its `head`
---@param done fun(failure: aineo.git.Failure|nil, base: string|nil, origin: aineo.changes.BaseOrigin|nil)
local function read_base(read, sources, repository, done)
  if not repository.head then
    done(nil, nil)
    return
  end
  local function against_comparison()
    sources.comparison(function(failure, comparison)
      if failure then
        done(failure)
        return
      end
      git.worktree_base(repository, comparison, function(base_failure, base)
        done(base_failure, base, base and { kind = 'merge_base', commit = comparison } or nil)
      end, read.git)
    end)
  end
  if not sources.working_commit then
    against_comparison()
    return
  end
  git.worktree_base(repository, sources.working_commit, function(failure, base)
    if failure or base then
      done(failure, base, base and { kind = 'merge_base', ref = sources.working_name } or nil)
    else
      against_comparison()
    end
  end, read.git)
end

--- Whether the commit `older` is an ancestor of the commit `newer`, or
--- `newer` itself, in the repository at `top`: their merge base is `older`
--- (`git.worktree_base()`). Calls `done(nil, is_ancestor)` or
--- `done(failure)`.
---
---@param read { git?: aineo.git.Options }
---@param top string
---@param older string
---@param newer string
---@param done fun(failure: aineo.git.Failure|nil, is_ancestor: boolean|nil)
local function read_is_ancestor(read, top, older, newer, done)
  git.worktree_base({ top = top, head = older }, newer, function(failure, merge_base)
    done(failure, not failure and merge_base == older or nil)
  end, read.git)
end

--- Reads which base a reported worktree or branch is read from: of
--- `reported`, the base its report gave, and `own`, the one the pane reads
--- for it, as `aineo.changes.reports`' `effective_base()` chooses by
--- whether `reported` is behind `tip` and `own` behind `reported`, read in
--- the repository at `top`. Calls `done(nil, base, reported)`: at once with
--- `own` for no reported base or no tip, and with `own` too when git cannot
--- tell the history of the reported base — a commit the repository no longer
--- has, say — as a base the pane cannot place is no base to read from;
--- `reported` says whether `base` is the reported one.
---
---@param read { git?: aineo.git.Options }
---@param top string
---@param reported string|nil
---@param own string|nil
---@param tip string|nil
---@param done fun(failure: nil, base: string|nil, reported: boolean)
function M.read_effective_base(read, top, reported, own, tip, done)
  if not (reported and tip) then
    done(nil, own, false)
    return
  end
  read_is_ancestor(read, top, reported, tip, function(failure, reported_in_tip)
    if failure then
      done(nil, own, false)
      return
    end
    local function chosen(own_before_reported)
      local base = reports.effective_base(reported, own, {
        reported_in_tip = reported_in_tip,
        own_before_reported = own_before_reported,
      })
      done(nil, base, base == reported)
    end
    if not (reported_in_tip and own) then
      chosen(false)
      return
    end
    read_is_ancestor(read, top, own, reported, function(own_failure, own_before_reported)
      if own_failure then
        done(nil, own, false)
      else
        chosen(own_before_reported)
      end
    end)
  end)
end

--- Reads `worktree`'s list (`read.read_list`) from its base — the one
--- `read_base()` reads, or, when `read.base_of` gives a reported one, the
--- one `M.read_effective_base()` chooses — and calls
--- `done(section)`; when the list cannot be
--- read, the section says why and keeps what the window last listed for the
--- worktree (`unread_section()`), if anything — unless the worktree's
--- directory is gone by then, removed while it was read, when it calls
--- `done(nil)`, as it does when git finds the directory in another
--- repository than that worktree (`is_listed_worktree()`).
---
---@param read aineo.changes.WorktreeRead
---@param worktree aineo.git.Worktree
---@param sources aineo.changes.BaseSources
---@param done fun(section: aineo.changes.WorktreeSection|nil)
local function read_section(read, worktree, sources, done)
  local section = unread_section(read, worktree)
  local function or_failed(proceed)
    return function(failure, ...)
      if not failure then
        proceed(...)
      elseif vim.uv.fs_stat(worktree.top) then
        section.failure = failure
        done(section)
      else
        done(nil)
      end
    end
  end
  git.find_repository(
    worktree.top,
    or_failed(function(repository)
      if not is_listed_worktree(repository, worktree) then
        done(nil)
        return
      end
      local reported = read.base_of and read.base_of(worktree)
      read_base(
        read,
        sources,
        repository,
        or_failed(function(own, own_origin)
          local function read_from(base, is_reported)
            local origin = base and (is_reported and M.REPORTED_ORIGIN or own_origin) or nil
            read.read_list(
              repository,
              base,
              or_failed(function(listed)
                section.repository, section.base, section.listed = repository, base, listed
                section.base_origin = origin
                done(section)
              end)
            )
          end
          M.read_effective_base(
            read,
            repository.top,
            reported,
            own,
            repository.head,
            or_failed(read_from)
          )
        end)
      )
    end),
    read.git
  )
end

--- Reads the list of `worktree` alone (`read.read_list`), from its base
--- (`read_base()`), the commit the working branch names read now
--- (`read_base_sources()`), and calls `done(section)`: the section holds
--- the list, or says why it could not be read, over what `read.before` knew
--- of the worktree (`unread_section()`); `done(nil)` when the worktree's
--- directory is gone by then.
---
---@param read aineo.changes.WorktreeRead
---@param worktree aineo.git.Worktree
---@param done fun(section: aineo.changes.WorktreeSection|nil)
function M.read_worktree(read, worktree, done)
  read_base_sources(read, function(failure, sources)
    if failure then
      done(failed_section(read, worktree, failure))
      return
    end
    read_section(read, worktree, sources, done)
  end)
end

--- What the base of a commit of the editor's repository is read from.
---@class aineo.changes.CommitBaseRead
---@field found aineo.git.Repository the editor's repository
---@field working_branch? string the branch the user's setting names; the remote's default branch when not given
---@field git? aineo.git.Options how the git home runs git

--- Reads the base of `commit`, any commit of the editor's repository, as the
--- base of a worktree whose `HEAD` it is is read (`read_base()`): its merge
--- base with the commit the working branch names now
--- (`read_base_sources()`), else with the editor's comparison commit. Calls
--- `done(nil, base, origin)`, `base` nil when neither gives one, `origin`
--- saying what the merge base was taken against; or `done(failure)`.
---
---@param read aineo.changes.CommitBaseRead
---@param commit string the commit's full id
---@param done fun(failure: aineo.git.Failure|nil, base: string|nil, origin: aineo.changes.BaseOrigin|nil)
function M.read_base_of(read, commit, done)
  read_base_sources(read, function(failure, sources)
    if failure then
      done(failure)
      return
    end
    read_base(read, sources, { top = read.found.top, head = commit }, done)
  end)
end

--- Lists the worktrees of the editor's repository, `read.found`, other than
--- its own, reads once what their bases are taken against
--- (`read_base_sources()`), and reads each one's list (`read_section()`),
--- one after another, each once `read.before_each_worktree` lets it start,
--- then calls `done(others)`. When the worktrees cannot be listed,
--- `done(others)` says why, with the sections the window knew before; when
--- the working branch cannot be read, each section says why, over what the
--- window last listed for it.
---
---@param read aineo.changes.WorktreesRead
---@param done fun(others: aineo.changes.OtherWorktrees)
function M.read_other_worktrees(read, done)
  git.list_worktrees(read.found, function(failure, listed)
    if failure then
      done({ sections = read.before.sections, failure = failure })
      return
    end
    local others = vim.tbl_filter(function(worktree)
      return worktree.top ~= read.found.top
    end, listed)
    if #others == 0 then
      done({ sections = {} })
      return
    end
    read_base_sources(read, function(sources_failure, sources)
      if sources_failure then
        done({
          sections = vim.tbl_map(function(worktree)
            return failed_section(read, worktree, sources_failure)
          end, others),
        })
        return
      end
      local sections = {}
      local function read_from(index)
        if index > #others then
          done({ sections = sections })
          return
        end
        read.before_each_worktree(function()
          read_section(read, others[index], sources, function(section)
            if section then
              table.insert(sections, section)
            end
            read_from(index + 1)
          end)
        end)
      end
      read_from(1)
    end)
  end, read.git)
end

return M
