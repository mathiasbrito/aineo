local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that finds, in the child, the repository of the directory `...`,
--- reads what the diff of the files listed under the filter after it
--- compares (`aineo.changes.against_read`), against `HEAD` when the next
--- argument says so, from the session's `source` (without its repository),
--- and returns what `_G.await` saw.
local READ = [[
  local directory, listed, against_head, source = ...
  local git = require('aineo.git')
  return _G.await(function(done)
    git.find_repository(directory, function(failure, found)
      if failure then
        done(failure)
        return
      end
      source.repository = found
      require('aineo.changes.against_read').read({
        listed = listed,
        against_head = against_head,
        source = source,
      }, function(resolved)
        done(nil, resolved)
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

T['what a diff compares'] = MiniTest.new_set()

T['what a diff compares']['under Uncommitted is HEAD, by the names that point at it'] = function()
  local top, head = git_repo.create('against-uncommitted', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'branch', 'dev' })

  local seen = child.lua(READ, { top, { kind = 'uncommitted' }, false, {} })

  eq(seen.failure, nil)
  eq(seen.result.head, head)
  eq(seen.result.names[head], { 'dev', 'main' })
end

T['what a diff compares']['under a commit is its parent, and the names of both'] = function()
  local top, first = git_repo.create('against-parent', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'branch', 'before' })
  git_repo.write(top, 'b.txt', { 'b' })
  local second = git_repo.commit_all(top, 'Second')

  local seen = child.lua(READ, { top, { kind = 'commit', commit = { id = second } }, false, {} })

  eq(seen.result.parent, first)
  eq(seen.result.names[first], { 'before' })
  eq(seen.result.names[second], { 'main' })
end

T['what a diff compares']['under a root commit is no parent'] = function()
  local top, first = git_repo.create('against-root', { ['a.txt'] = { 'a' } })

  local seen = child.lua(READ, { top, { kind = 'commit', commit = { id = first } }, false, {} })

  eq(seen.result.parent, false)
end

T['what a diff compares']['under Landed is the merge base of the session base and the working branch'] = function()
  local top, fork = git_repo.create('against-landed', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'session' })
  git_repo.write(top, 'b.txt', { 'b' })
  local session_base = git_repo.commit_all(top, 'Session work')
  git_repo.git(top, { 'checkout', '--quiet', 'main' })
  git_repo.write(top, 'c.txt', { 'c' })
  local tip = git_repo.commit_all(top, 'Landed work')

  local seen = child.lua(READ, {
    top,
    { kind = 'landed', landed = 'main' },
    false,
    { base = session_base, landed = { name = 'main', tip = tip } },
  })

  eq(seen.result.merge_base, fork)
  eq(seen.result.names[fork], nil)
  eq(seen.result.names[tip], { 'main' })
end

T['what a diff compares']['under Landed is no commit where the session has no base'] = function()
  local top, tip = git_repo.create('against-landed-no-base', { ['a.txt'] = { 'a' } })

  local seen = child.lua(READ, {
    top,
    { kind = 'landed', landed = 'main' },
    false,
    { landed = { name = 'main', tip = tip } },
  })

  eq(seen.result.merge_base, false)
  eq(seen.result.names[tip], { 'main' })
end

T['what a diff compares']['under Session work needs no commit read, only the names of its base'] = function()
  local top, base = git_repo.create('against-session', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'tag', 'v1' })

  local seen = child.lua(READ, { top, { kind = 'session_work' }, false, { base = base } })

  eq(seen.result.head, nil)
  eq(seen.result.parent, nil)
  eq(seen.result.names[base], { 'main', 'v1' })
end

T['what a diff compares']['against HEAD is HEAD, whichever list the file is in'] = function()
  local top, first = git_repo.create('against-head', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'b.txt', { 'b' })
  local head = git_repo.commit_all(top, 'Second')

  local seen = child.lua(READ, { top, { kind = 'commit', commit = { id = first } }, true, {} })

  eq(seen.result.head, head)
  eq(seen.result.parent, nil)
  eq(seen.result.names[head], { 'main' })
end

T['what a diff compares']['under another worktree is read in that worktree'] = function()
  local top, base = git_repo.create('against-worktree', { ['a.txt'] = { 'a' } })
  local other = vim.fs.joinpath(vim.fs.dirname(top), 'other')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'feature', other })
  git_repo.write(other, 'b.txt', { 'b' })
  local feature_head = git_repo.commit_all(other, 'Feature work')

  local seen = child.lua(READ, {
    top,
    { kind = 'worktree', worktree = { top = other, repository = { top = other }, base = base } },
    true,
    {},
  })

  eq(seen.result.head, feature_head)
  eq(seen.result.names[feature_head], { 'feature' })
end

return T
