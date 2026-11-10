local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local claude_work = require('aineo.explorer.claude_work')

local T = MiniTest.new_set()

T['the paths in a repository'] = MiniTest.new_set()

T['the paths in a repository']['are those of the work when it is in that repository'] = function()
  local work = { top = '/repo', paths = { 'a.txt', 'src/b.txt' } }

  eq(claude_work.paths_in(work, { top = '/repo' }), { 'a.txt', 'src/b.txt' })
end

T['the paths in a repository']['are none when the work is in another one, or is not known'] = function()
  eq(claude_work.paths_in({ top = '/elsewhere', paths = { 'a.txt' } }, { top = '/repo' }), nil)
  eq(claude_work.paths_in(nil, { top = '/repo' }), nil)
end

T['the paths in a repository']['are those of the work when its top is the repository by a link'] = function()
  local folder = fixture.directory('claude-work-link')
  local top = vim.fs.joinpath(folder, 'top')
  vim.fn.mkdir(top, 'p')
  local link = vim.fs.joinpath(folder, 'link')
  vim.uv.fs_symlink(top, link)

  eq(claude_work.paths_in({ top = link, paths = { 'a.txt' } }, { top = top }), { 'a.txt' })
end

return T
