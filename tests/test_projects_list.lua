local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local projects = require('aineo.projects')

local T = MiniTest.new_set()

--- The project of the repository `name`, checked out at `/work/<name>`.
---
---@param name string
---@return aineo.projects.Project
local function project(name)
  return { key = '/work/' .. name .. '/.git', top = '/work/' .. name }
end

--- The names of the tops of `list`'s projects, in order.
---
---@param list aineo.projects.List
---@return string[]
local function tops(list)
  return vim.tbl_map(function(each)
    return each.top
  end, list.entries())
end

T['a list'] = MiniTest.new_set()

T['a list']['begins with the session’s project alone, chosen'] = function()
  local list = projects.new_list(project('aineo'))

  eq(tops(list), { '/work/aineo' })
  eq(list.chosen().top, '/work/aineo')
end

T['a list']['takes the projects that join after the session’s, in the order they joined'] = function()
  local list = projects.new_list(project('aineo'))

  eq(list.join(project('api')), 'joined')
  eq(list.join(project('docs')), 'joined')

  eq(tops(list), { '/work/aineo', '/work/api', '/work/docs' })
end

T['a list']['does not take a project twice, whatever folder of it joins'] = function()
  local list = projects.new_list(project('api'))
  list.join(project('docs'))

  local answer = list.join({ key = '/work/docs/.git', top = '/work/docs-second-checkout' })

  eq(answer, 'known')
  eq(tops(list), { '/work/api', '/work/docs' })
end

T['a list']['does not move the chosen project as one joins'] = function()
  local list = projects.new_list(project('aineo'))

  list.join(project('api'))

  eq(list.chosen().top, '/work/aineo')
end

T['a list']['takes at most as many projects as the cap says, the session’s among them'] = function()
  local list = projects.new_list(project('p1'))
  for number = 2, projects.MOST do
    list.join(project('p' .. number))
  end

  local answer = list.join(project('one-too-many'))

  eq(answer, 'full')
  eq(#list.entries(), projects.MOST)
end

T['a list']['has a cap of eight'] = function()
  eq(projects.MOST, 8)
end

T['a list']['chooses the next project, and the first after the last'] = function()
  local list = projects.new_list(project('a'))
  list.join(project('b'))
  list.join(project('c'))

  list.choose_next()
  eq(list.chosen().top, '/work/b')
  list.choose_next()
  list.choose_next()
  eq(list.chosen().top, '/work/a')
end

T['a list']['chooses the previous project, and the last before the first'] = function()
  local list = projects.new_list(project('a'))
  list.join(project('b'))
  list.join(project('c'))

  list.choose_previous()
  eq(list.chosen().top, '/work/c')
  list.choose_previous()
  eq(list.chosen().top, '/work/b')
end

T['a list']['chooses the project a key names'] = function()
  local list = projects.new_list(project('a'))
  list.join(project('b'))

  eq(list.choose(project('b').key), true)
  eq(list.chosen().top, '/work/b')
  eq(list.choose('/nowhere/.git'), false)
  eq(list.chosen().top, '/work/b')
end

T['a list']['closes a project other than the session’s'] = function()
  local list = projects.new_list(project('a'))
  list.join(project('b'))

  eq(list.close(project('b').key), true)

  eq(tops(list), { '/work/a' })
end

T['a list']['does not close the session’s project'] = function()
  local list = projects.new_list(project('a'))
  list.join(project('b'))

  eq(list.close(project('a').key), false)

  eq(tops(list), { '/work/a', '/work/b' })
end

T['a list']['does not close a project it does not hold'] = function()
  local list = projects.new_list(project('a'))

  eq(list.close('/nowhere/.git'), false)
end

T['a list']['chooses the project before the one closed when that was chosen'] = function()
  local list = projects.new_list(project('a'))
  list.join(project('b'))
  list.join(project('c'))
  list.choose(project('c').key)

  list.close(project('c').key)

  eq(list.chosen().top, '/work/b')
end

T['a list']['keeps the chosen project when another closes'] = function()
  local list = projects.new_list(project('a'))
  list.join(project('b'))
  list.join(project('c'))
  list.choose(project('c').key)

  list.close(project('b').key)

  eq(list.chosen().top, '/work/c')
end

T['a list']['takes a project that was closed once more'] = function()
  local list = projects.new_list(project('a'))
  list.join(project('b'))
  list.close(project('b').key)

  eq(list.join(project('b')), 'joined')

  eq(tops(list), { '/work/a', '/work/b' })
end

T['a list']['takes a project again once a closed one makes room'] = function()
  local list = projects.new_list(project('p1'))
  for number = 2, projects.MOST do
    list.join(project('p' .. number))
  end
  list.close(project('p3').key)

  eq(list.join(project('late')), 'joined')
end

T['a list']['answers a copy of its projects'] = function()
  local list = projects.new_list(project('a'))

  list.entries()[1].top = '/changed'

  eq(list.chosen().top, '/work/a')
end

T['a list']['can be built from the projects that were kept, the session’s first'] = function()
  local list = projects.new_list(project('a'), { project('b'), project('c') })

  eq(tops(list), { '/work/a', '/work/b', '/work/c' })
end

T['a list']['leaves out of the kept projects the session’s, repeats and what the cap leaves out'] = function()
  local kept = { project('a'), project('b'), project('b') }
  for number = 1, projects.MOST + 2 do
    table.insert(kept, project('k' .. number))
  end

  local list = projects.new_list(project('a'), kept)

  eq(#list.entries(), projects.MOST)
  eq(list.entries()[2].top, '/work/b')
end

T['a list']['takes another checkout for a project, its place, its joining and the chosen project unchanged'] = function()
  local joined = { key = '/work/b/.git', top = '/work/b', joined = 77 }
  local list = projects.new_list(project('a'), { joined })
  list.choose(joined.key)

  eq(list.retop(joined.key, '/work/b-main'), true)

  eq(list.entries()[2], { key = '/work/b/.git', top = '/work/b-main', joined = 77 })
  eq(list.chosen().top, '/work/b-main')
end

T['a list']['does not take another checkout for the session’s project, nor for one it does not hold'] = function()
  local list = projects.new_list(project('a'))

  eq(list.retop(project('a').key, '/elsewhere'), false)
  eq(list.retop('/nowhere/.git', '/elsewhere'), false)
  eq(list.entries()[1].top, '/work/a')
end

return T
