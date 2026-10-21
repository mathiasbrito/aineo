local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that finds, in the child, the repository of the directory `...`,
--- reads the worktrees other than its own with the working branch the next
--- argument names (nil for none) and the base an agent reported for each,
--- the last argument (nil for none), and returns what `_G.await` saw of
--- each section: its branch, its base and where the base came from.
local READ_WORKTREES = [[
  local directory, working_branch, reported = ...
  local git = require('aineo.git')
  return _G.await(function(done)
    git.find_repository(directory, function(failure, found)
      if failure then
        done(failure)
        return
      end
      require('aineo.changes.worktrees').read_other_worktrees({
        found = found,
        working_branch = working_branch ~= vim.NIL and working_branch or nil,
        before = { sections = {} },
        read_list = function(_, _, listed)
          listed(nil, {})
        end,
        base_of = reported ~= vim.NIL and function()
          return reported
        end or nil,
        before_each_worktree = function(proceed)
          proceed()
        end,
      }, function(others)
        done(nil, vim.tbl_map(function(section)
          return { branch = section.branch, base = section.base, origin = section.base_origin }
        end, others.sections))
      end)
    end)
  end)
]]

--- The Lua that finds, in the child, the repository of the directory `...`,
--- reads the local branch `feature` with the working branch the next
--- argument names (nil for none) and the base an agent reported, the last
--- argument (nil for none), and returns what `_G.await` saw of its base and
--- where the base came from.
local READ_BRANCH = [[
  local directory, working_branch, reported = ...
  local git = require('aineo.git')
  return _G.await(function(done)
    git.find_repository(directory, function(failure, found)
      if failure then
        done(failure)
        return
      end
      require('aineo.changes.branch').read({
        found = found,
        name = 'feature',
        working_branch = working_branch ~= vim.NIL and working_branch or nil,
        base = reported ~= vim.NIL and reported or nil,
      }, function(section)
        done(nil, { base = section.base, origin = section.base_origin })
      end)
    end)
  end)
]]

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = child.stop,
  },
})

--- A repository on `main` with one commit, and a worktree beside it on the
--- branch `feature` with two commits more.
---
---@param name string
---@return string top
---@return string base the commit `feature` was made from
---@return string middle the first commit of `feature`
local function create_with_feature(name)
  local top, base = git_repo.create(name, { ['a.txt'] = { 'a' } })
  local other = vim.fs.joinpath(vim.fs.dirname(top), 'other')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'feature', other })
  git_repo.write(other, 'b.txt', { 'b' })
  local middle = git_repo.commit_all(other, 'Middle')
  git_repo.write(other, 'c.txt', { 'c' })
  git_repo.commit_all(other, 'Tip')
  return top, base, middle
end

T['the base of another worktree'] = MiniTest.new_set()

T['the base of another worktree']['comes from a merge base with the working branch, named'] = function()
  local top, base = create_with_feature('origin-worktree-working')

  local seen = child.lua(READ_WORKTREES, { top, 'main', vim.NIL })

  eq(seen.result[1].base, base)
  eq(seen.result[1].origin, { kind = 'merge_base', ref = 'main' })
end

T['the base of another worktree']['comes from a merge base with the editor’s commit where there is no working branch'] = function()
  local top, base = create_with_feature('origin-worktree-comparison')

  local seen = child.lua(READ_WORKTREES, { top, vim.NIL, vim.NIL })

  eq(seen.result[1].base, base)
  eq(seen.result[1].origin, { kind = 'merge_base', commit = base })
end

T['the base of another worktree']['comes from the report when the reported base is chosen'] = function()
  local top, _, middle = create_with_feature('origin-worktree-reported')

  local seen = child.lua(READ_WORKTREES, { top, 'main', middle })

  eq(seen.result[1].base, middle)
  eq(seen.result[1].origin, { kind = 'reported' })
end

T['the base of another worktree']['comes from a merge base when the reported base is not chosen'] = function()
  local top, base = create_with_feature('origin-worktree-not-reported')
  git_repo.write(top, 'd.txt', { 'd' })
  local elsewhere = git_repo.commit_all(top, 'Elsewhere')

  local seen = child.lua(READ_WORKTREES, { top, 'main', elsewhere })

  eq(seen.result[1].base, base)
  eq(seen.result[1].origin, { kind = 'merge_base', ref = 'main' })
end

T['the base of a local branch'] = MiniTest.new_set()

T['the base of a local branch']['comes from a merge base with the working branch, named'] = function()
  local top, base = create_with_feature('origin-branch-working')

  local seen = child.lua(READ_BRANCH, { top, 'main', vim.NIL })

  eq(seen.result.base, base)
  eq(seen.result.origin, { kind = 'merge_base', ref = 'main' })
end

T['the base of a local branch']['comes from the report when the reported base is chosen'] = function()
  local top, _, middle = create_with_feature('origin-branch-reported')

  local seen = child.lua(READ_BRANCH, { top, 'main', middle })

  eq(seen.result.base, middle)
  eq(seen.result.origin, { kind = 'reported' })
end

return T
