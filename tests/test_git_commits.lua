local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then for the commits there since the base that follows
--- it (`vim.NIL` for none), and returns what `_G.await` saw of the second.
local COMMITS_SINCE = [[
  local directory, base = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  return _G.await(function(done)
    git.commits_since(found.result, base ~= vim.NIL and base or nil, done)
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

T['the commits since a base'] = MiniTest.new_set()

T['the commits since a base']['are those reachable from the head, newest first, with their subjects'] = function()
  local top, base = git_repo.create('commits-since', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'a.txt', { 'a, again' })
  local first = git_repo.commit_all(top, 'Change a')
  local second = git_repo.commit_all(top, 'Record nothing: an empty commit')

  local seen = child.lua(COMMITS_SINCE, { top, base })

  eq(seen.result, {
    commits = {
      { id = second, subject = 'Record nothing: an empty commit' },
      { id = first, subject = 'Change a' },
    },
    base_is_ancestor = true,
  })
end

T['the commits since a base']['tell when a reset left the base behind'] = function()
  local top, before = git_repo.create('commits-reset', { ['a.txt'] = { 'a' } })
  local base = git_repo.commit_all(top, 'The session’s base')
  git_repo.git(top, { 'reset', '--quiet', '--hard', before })
  local after = git_repo.commit_all(top, 'After the reset')

  local seen = child.lua(COMMITS_SINCE, { top, base })

  eq(seen.result, {
    commits = { { id = after, subject = 'After the reset' } },
    base_is_ancestor = false,
  })
end

T['the commits since a base']['are every commit when there is no base'] = function()
  local top = git_repo.create_unborn('commits-no-base')
  local first = git_repo.commit_all(top, 'First')
  local second = git_repo.commit_all(top, 'Second')

  local seen = child.lua(COMMITS_SINCE, { top, vim.NIL })

  eq(seen.result, {
    commits = { { id = second, subject = 'Second' }, { id = first, subject = 'First' } },
    base_is_ancestor = true,
  })
end

T['the commits since a base']['are none before the first commit'] = function()
  local top = git_repo.create_unborn('commits-unborn')

  local seen = child.lua(COMMITS_SINCE, { top, vim.NIL })

  eq({ failure = seen.failure, result = seen.result }, {
    result = { commits = {}, base_is_ancestor = true },
  })
end

T['the commits since a base']['since a base named like an option are refused, and write nothing'] = function()
  local top = git_repo.create('commits-option', { ['a.txt'] = { 'a' } })
  local written = vim.fs.joinpath(vim.fs.dirname(top), 'written')

  local seen = child.lua(COMMITS_SINCE, { top, '--output=' .. written })

  eq({
    reason = vim.tbl_get(seen, 'failure', 'reason'),
    beside = vim.fn.readdir(vim.fs.dirname(top)),
  }, { reason = 'failed', beside = { 'repo' } })
end

return T
