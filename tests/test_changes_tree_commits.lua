local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local report_rules = require('aineo.changes.reports')
local tree_commits = require('aineo.changes.tree_commits')

local child = MiniTest.new_child_neovim()

--- The editor's own worktree's top level.
local OWN_TOP = '/projects/main'

--- Two full commit ids, the bases the lines below were read from.
local BASE, OTHER_BASE = ('a'):rep(40), ('b'):rep(40)

--- The worktree `agent-1` on `feature/a`, as git lists it.
local AGENT = { top = '/projects/agent-1', branch = 'feature/a' }

--- The branch `name`, reported made from `base`, none when not given.
---
---@param name string
---@param base? string
---@return aineo.changes.ReportedBranch
local function branch(name, base)
  return { name = name, base = base }
end

--- The branch lines of the tree of the worktree `agent-1` holding `branches`,
--- each read from the base `read_from` gives for its name, none when it
--- gives none.
---
---@param branches aineo.changes.ReportedBranch[]
---@param read_from table<string, string>
---@return aineo.changes.TreeLine[]
local function tree_of(branches, read_from)
  local tree = report_rules.tree_lines({ { worktree = AGENT, branches = branches } }, OWN_TOP)
  for _, line in ipairs(tree) do
    line.read_base = line.branch and read_from[line.branch.name]
  end
  return tree
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = child.stop,
  },
})

T['the commits wanted'] = MiniTest.new_set()

T['the commits wanted']['are those of each branch’s line, from exactly the base its line shows, read in place of the reported one'] = function()
  local tree = tree_of(
    { branch('feature/b', BASE), branch('feature/a', BASE) },
    { ['feature/b'] = OTHER_BASE, ['feature/a'] = BASE }
  )

  eq(tree_commits.wanted(tree), {
    { name = 'feature/b', base = OTHER_BASE },
    { name = 'feature/a', base = BASE },
  })
end

T['the commits wanted']['hold no branch whose work was not read yet, nor one whose line shows no base'] = function()
  local tree = tree_of(
    { branch('feature/unread', BASE), branch('feature/none') },
    { ['feature/none'] = OTHER_BASE }
  )

  eq(tree_commits.wanted(tree), {})
end

T['the commits wanted']['hold a branch once, however many lines show it from the same base'] = function()
  local nodes = {
    { worktree = AGENT, at = 2, branches = { branch('feature/a', BASE) } },
    {
      worktree = { top = '/projects/agent-2', branch = 'feature/x' },
      at = 1,
      branches = { branch('feature/a', BASE) },
    },
  }
  local tree = report_rules.tree_lines(nodes, OWN_TOP)
  for _, line in ipairs(tree) do
    line.read_base = line.branch and BASE
  end

  eq(tree_commits.wanted(tree), { { name = 'feature/a', base = BASE } })
end

T['the commits wanted']['hold a branch once for each base its lines show'] = function()
  local nodes = {
    { worktree = AGENT, at = 2, branches = { branch('feature/a', BASE) } },
    {
      worktree = { top = '/projects/agent-2', branch = 'feature/x' },
      at = 1,
      branches = { branch('feature/a', BASE) },
    },
  }
  local tree = report_rules.tree_lines(nodes, OWN_TOP)
  local bases = { BASE, OTHER_BASE }
  local line_number = 0
  for _, line in ipairs(tree) do
    if line.branch then
      line_number = line_number + 1
      line.read_base = bases[line_number]
    end
  end

  eq(tree_commits.wanted(tree), {
    { name = 'feature/a', base = BASE },
    { name = 'feature/a', base = OTHER_BASE },
  })
end

T['the commits of a line'] = MiniTest.new_set()

T['the commits of a line']['are those read for its branch from the base it shows, none when read from another'] = function()
  local commits = { { id = ('c'):rep(40), subject = 'Work', author = 'Ada', authored_at = 1 } }
  local tree = tree_of({ branch('feature/a', BASE) }, { ['feature/a'] = BASE })
  local kept = { [tree_commits.key('feature/a', BASE)] = commits }

  eq(tree_commits.commits_of(kept, tree[3]), commits)

  tree[3].read_base = OTHER_BASE
  eq(tree_commits.commits_of(kept, tree[3]), nil)
end

--- The Lua that reads, in the child, the commits wanted (the second value
--- of `...`) in the repository at the directory the first names, and
--- returns what `_G.await` saw, its `result` the commits kept.
local READ = [[
  local directory, wanted = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  return _G.await(function(done)
    require('aineo.changes.tree_commits').read({ found = found.result }, wanted, function(kept)
      done(nil, kept)
    end)
  end)
]]

--- The subjects of `commits`, in their order.
---
---@param commits aineo.git.Commit[]
---@return string[]
local function subjects_of(commits)
  return vim.tbl_map(function(commit)
    return commit.subject
  end, commits)
end

T['the reading'] = MiniTest.new_set()

T['the reading']['lists each branch’s commits from its base to its tip, newest first'] = function()
  local top, base = git_repo.create('tree-commits-read', { ['a.txt'] = { 'one' } })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'feature/a' })
  git_repo.write(top, 'one.txt', { 'one' })
  git_repo.commit_all(top, 'One')
  git_repo.write(top, 'two.txt', { 'two' })
  git_repo.commit_all(top, 'Two')
  git_repo.git(top, { 'checkout', '--quiet', 'main' })

  local seen = child.lua(READ, { top, { { name = 'feature/a', base = base } } })

  eq(subjects_of(seen.result[tree_commits.key('feature/a', base)]), { 'Two', 'One' })
end

T['the reading']['lists nothing for a branch with no commit past its base, and keeps its empty list'] = function()
  local top, base = git_repo.create('tree-commits-none', { ['a.txt'] = { 'one' } })
  git_repo.git(top, { 'branch', 'feature/a' })

  local seen = child.lua(READ, { top, { { name = 'feature/a', base = base } } })

  eq(seen.result[tree_commits.key('feature/a', base)], {})
end

T['the reading']['keeps nothing for a branch that names no commit, the others read'] = function()
  local top, base = git_repo.create('tree-commits-gone', { ['a.txt'] = { 'one' } })
  git_repo.git(top, { 'branch', 'feature/a' })

  local seen = child.lua(READ, {
    top,
    { { name = 'feature/gone', base = base }, { name = 'feature/a', base = base } },
  })

  eq(vim.tbl_keys(seen.result), { tree_commits.key('feature/a', base) })
end

return T
