local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then for the lines added and removed in each file that
--- differs from `HEAD`, and returns what `_G.await` saw of the second.
local LINE_COUNTS = [[
  local directory = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  return _G.await(function(done)
    git.line_counts(found.result, done)
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

T['the line counts'] = MiniTest.new_set()

T['the line counts']['are the lines added and removed in each file that differs from HEAD, staged or not'] = function()
  local top = git_repo.create('counts-kinds', {
    ['a.txt'] = { 'one', 'two', 'three' },
    ['b.txt'] = { 'b' },
    ['c.txt'] = { 'c1', 'c2' },
    ['same.txt'] = { 's' },
  })
  git_repo.write(top, 'a.txt', { 'one', 'TWO', 'three', 'four', 'five' })
  git_repo.write(top, 'c.txt', { 'c1' })
  git_repo.git(top, { 'add', 'c.txt' })
  git_repo.write(top, 'c.txt', { 'c1', 'c3', 'c4' })
  git_repo.git(top, { 'rm', '--quiet', 'b.txt' })

  local seen = child.lua(LINE_COUNTS, { top })

  eq(seen.result, {
    ['a.txt'] = { added = 3, removed = 1 },
    ['b.txt'] = { added = 0, removed = 1 },
    ['c.txt'] = { added = 2, removed = 1 },
  })
end

T['the line counts']['count a file staged as new, and leave out an untracked one'] = function()
  local top = git_repo.create('counts-new', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'staged.txt', { 'x', 'y' })
  git_repo.git(top, { 'add', 'staged.txt' })
  git_repo.write(top, 'untracked.txt', { 'u' })

  local seen = child.lua(LINE_COUNTS, { top })

  eq(seen.result, { ['staged.txt'] = { added = 2, removed = 0 } })
end

T['the line counts']['leave out a binary file'] = function()
  local top = git_repo.create('counts-binary', { ['a.txt'] = { 'a' } })
  local image = assert(io.open(vim.fs.joinpath(top, 'image.bin'), 'wb'))
  image:write('PNG\0\0\1\2\3')
  image:close()
  git_repo.git(top, { 'add', 'image.bin' })

  local seen = child.lua(LINE_COUNTS, { top })

  eq(seen.result, {})
end

T['the line counts']['are those of the new path for a renamed file, the old path left out'] = function()
  local top = git_repo.create('counts-renamed', {
    ['old.txt'] = { 'l1', 'l2', 'l3', 'l4', 'l5', 'l6' },
  })
  git_repo.git(top, { 'mv', 'old.txt', 'new.txt' })
  git_repo.write(top, 'new.txt', { 'l1', 'l2', 'l3', 'l4', 'l5', 'l6', 'l7' })
  git_repo.git(top, { 'add', 'new.txt' })

  local seen = child.lua(LINE_COUNTS, { top })

  eq(seen.result, { ['new.txt'] = { added = 1, removed = 0 } })
end

T['the line counts']['read a rename from a path with tabs in it as one file, the path of the new name'] = function()
  local top = git_repo.create('counts-renamed-tabs', {
    ['1\t2\tz.txt'] = { 'l1', 'l2', 'l3', 'l4', 'l5', 'l6' },
  })
  git_repo.git(top, { 'mv', '1\t2\tz.txt', 'new.txt' })

  local seen = child.lua(LINE_COUNTS, { top })

  eq(seen.result, {})
end

T['the line counts']['detect a rename where the repository turns rename detection off'] = function()
  local top = git_repo.create('counts-renamed-off', {
    ['old.txt'] = { 'l1', 'l2', 'l3', 'l4', 'l5', 'l6' },
  })
  git_repo.git(top, { 'config', 'diff.renames', 'false' })
  git_repo.git(top, { 'mv', 'old.txt', 'new.txt' })
  git_repo.write(top, 'new.txt', { 'l1', 'l2', 'l3', 'l4', 'l5', 'l6', 'l7' })
  git_repo.git(top, { 'add', 'new.txt' })

  local seen = child.lua(LINE_COUNTS, { top })

  eq(seen.result, { ['new.txt'] = { added = 1, removed = 0 } })
end

T['the line counts']['are every staged line as added before the first commit'] = function()
  local top = git_repo.create_unborn('counts-unborn')
  git_repo.write(top, 'first.txt', { '1', '2', '3' })
  git_repo.git(top, { 'add', 'first.txt' })

  local seen = child.lua(LINE_COUNTS, { top })

  eq(seen.result, { ['first.txt'] = { added = 3, removed = 0 } })
end

T['the line counts']['keep a path with a tab or an accent as it is on disk'] = function()
  local top = git_repo.create('counts-names', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'café\tx.txt', { 'one' })
  git_repo.git(top, { 'add', '--all' })

  local seen = child.lua(LINE_COUNTS, { top })

  eq(seen.result, { ['café\tx.txt'] = { added = 1, removed = 0 } })
end

return T
