local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that finds, in the child, the repository of the directory `...`
--- and asks the git home for the names of the commits after it, and returns
--- what `_G.await` saw.
local NAMES_AT = [[
  local directory, ids = ...
  local git = require('aineo.git')
  return _G.await(function(done)
    git.find_repository(directory, function(failure, found)
      if failure then
        done(failure)
        return
      end
      git.names_at(found, ids, done)
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

T['the names of a commit'] = MiniTest.new_set()

T['the names of a commit']['are its local branches, then its remote-tracking branches, then its tags, each kind by name'] = function()
  local top, commit = git_repo.create('names-order', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'branch', 'zeta' })
  git_repo.git(top, { 'branch', 'alpha' })
  git_repo.git(top, { 'update-ref', 'refs/remotes/origin/main', commit })
  git_repo.git(top, { 'update-ref', 'refs/remotes/fork/dev', commit })
  git_repo.git(top, { 'tag', 'v2' })
  git_repo.git(top, { 'tag', 'v1' })

  local seen = child.lua(NAMES_AT, { top, { commit } })

  eq(seen.failure, nil)
  eq(seen.result[commit], { 'alpha', 'main', 'zeta', 'fork/dev', 'origin/main', 'v1', 'v2' })
end

T['the names of a commit']['include an annotated tag as they include a lightweight one'] = function()
  local top, commit = git_repo.create('names-annotated', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'tag', '--annotate', '--message', 'Release', 'v1' })

  local seen = child.lua(NAMES_AT, { top, { commit } })

  eq(seen.result[commit], { 'main', 'v1' })
end

T['the names of a commit']['leave out the remote HEAD, which only repeats a branch'] = function()
  local top, commit = git_repo.create('names-remote-head', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'update-ref', 'refs/remotes/origin/main', commit })
  git_repo.git(top, { 'symbolic-ref', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/main' })

  local seen = child.lua(NAMES_AT, { top, { commit } })

  eq(seen.result[commit], { 'main', 'origin/main' })
end

T['the names of a commit']['include a branch and a tag whose names only end in /HEAD'] = function()
  local top, commit = git_repo.create('names-head-suffix', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'branch', 'topic/HEAD' })
  git_repo.git(top, { 'tag', 'v/HEAD' })
  git_repo.git(top, { 'update-ref', 'refs/remotes/origin/main', commit })
  git_repo.git(top, { 'update-ref', 'refs/remotes/fork/topic/HEAD', commit })
  git_repo.git(top, { 'symbolic-ref', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/main' })

  local seen = child.lua(NAMES_AT, { top, { commit } })

  eq(seen.result[commit], { 'main', 'topic/HEAD', 'fork/topic/HEAD', 'origin/main', 'v/HEAD' })
end

T['the names of a commit']['leave out references that are no branch, remote-tracking branch or tag'] = function()
  local top, commit = git_repo.create('names-others', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'update-ref', 'refs/pull/7/head', commit })
  git_repo.git(top, { 'update-ref', 'refs/stash', commit })

  local seen = child.lua(NAMES_AT, { top, { commit } })

  eq(seen.result[commit], { 'main' })
end

T['the names of a commit']['are told for each of several commits, and none for a commit nothing points at'] = function()
  local top, first = git_repo.create('names-several', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'branch', 'first' })
  git_repo.write(top, 'b.txt', { 'b' })
  local second = git_repo.commit_all(top, 'Second')
  git_repo.write(top, 'c.txt', { 'c' })
  local third = git_repo.commit_all(top, 'Third')
  git_repo.git(top, { 'checkout', '--quiet', '--detach', second })

  local seen = child.lua(NAMES_AT, { top, { first, second, third } })

  eq(seen.result[first], { 'first' })
  eq(seen.result[second], nil)
  eq(seen.result[third], { 'main' })
end

T['the names of a commit']['are none when no commit is asked about'] = function()
  local top = git_repo.create('names-none', { ['a.txt'] = { 'a' } })

  local seen = child.lua(NAMES_AT, { top, {} })

  eq(seen.failure, nil)
  eq(seen.result, {})
end

return T
