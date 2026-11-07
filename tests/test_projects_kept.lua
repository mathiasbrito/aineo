local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local projects = require('aineo.projects')

local T = MiniTest.new_set()

local SESSION = '11111111-1111-4111-8111-111111111111'
local OTHER_SESSION = '22222222-2222-4222-8222-222222222222'

local API = { key = '/work/api/.git', top = '/work/api' }
local DOCS = { key = '/work/docs/.git', top = '/work/docs' }

--- A state directory of the case's own.
---
---@param name string
---@return string
local function state_directory(name)
  return fixture.directory('projects_kept_' .. name)
end

--- What the file `path` holds.
---
---@param path string
---@return string
local function contents(path)
  return table.concat(vim.fn.readfile(path), '\n')
end

T['kept projects'] = MiniTest.new_set()

T['kept projects']['are read back as they were kept, in their order'] = function()
  local state = state_directory('round_trip')

  eq(projects.keep(state, SESSION, { API, DOCS }), nil)

  eq(projects.read_kept(state, SESSION), { API, DOCS })
end

T['kept projects']['are none for a session nothing was kept for'] = function()
  eq(projects.read_kept(state_directory('none'), SESSION), nil)
end

T['kept projects']['are kept for the session alone'] = function()
  local state = state_directory('per_session')
  projects.keep(state, SESSION, { API })

  eq(projects.read_kept(state, OTHER_SESSION), nil)
end

T['kept projects']['replace what was kept before'] = function()
  local state = state_directory('replace')
  projects.keep(state, SESSION, { API, DOCS })

  projects.keep(state, SESSION, { DOCS })

  eq(projects.read_kept(state, SESSION), { DOCS })
end

T['kept projects']['are in a file only their owner reads, in a directory only their owner enters'] = function()
  local state = state_directory('modes')

  projects.keep(state, SESSION, { API })

  local file = projects.kept_file(state, SESSION)
  eq(vim.uv.fs_stat(file).mode % 4096, tonumber('600', 8))
  eq(vim.uv.fs_stat(vim.fs.dirname(file)).mode % 4096, tonumber('700', 8))
end

T['kept projects']['leave no file beside the one kept'] = function()
  local state = state_directory('no_leftovers')

  projects.keep(state, SESSION, { API })

  eq(#vim.fn.readdir(vim.fs.dirname(projects.kept_file(state, SESSION))), 1)
end

T['kept projects']['are none when the file holds no JSON'] = function()
  local state = state_directory('not_json')
  projects.keep(state, SESSION, { API })
  vim.fn.writefile({ '{ nope' }, projects.kept_file(state, SESSION))

  eq(projects.read_kept(state, SESSION), nil)
end

T['kept projects']['are none when the file holds another shape'] = function()
  local state = state_directory('another_shape')
  projects.keep(state, SESSION, { API })
  vim.fn.writefile({ '{"projects": "api"}' }, projects.kept_file(state, SESSION))

  eq(projects.read_kept(state, SESSION), nil)
end

T['kept projects']['leave out of what is read a project that is not a pair of paths'] = function()
  local state = state_directory('bad_entries')
  projects.keep(state, SESSION, { API })
  local good = vim.json.encode({ key = DOCS.key, top = DOCS.top })
  vim.fn.writefile({
    '{"projects": [{"key": 3, "top": "/x"}, {"key": "/y/.git"}, null, "z", ' .. good .. ']}',
  }, projects.kept_file(state, SESSION))

  eq(projects.read_kept(state, SESSION), { DOCS })
end

T['kept projects']['say why they could not be kept, naming the file'] = function()
  local state = state_directory('unwritable')
  vim.fn.writefile({ 'a file, not a directory' }, vim.fs.joinpath(state, 'aineo'))

  local failure = projects.keep(state, SESSION, { API })

  eq(type(failure), 'string')
  eq(failure:find(projects.kept_file(state, SESSION), 1, true) ~= nil, true)
end

T['kept projects']['are moved to the session that takes the place of another'] = function()
  local state = state_directory('move')
  projects.keep(state, SESSION, { API })

  eq(projects.move_kept(state, SESSION, OTHER_SESSION), nil)

  eq(projects.read_kept(state, OTHER_SESSION), { API })
  eq(projects.read_kept(state, SESSION), nil)
end

T['kept projects']['are not moved over what the other session has kept'] = function()
  local state = state_directory('move_over')
  projects.keep(state, SESSION, { API })
  projects.keep(state, OTHER_SESSION, { DOCS })

  projects.move_kept(state, SESSION, OTHER_SESSION)

  eq(projects.read_kept(state, OTHER_SESSION), { DOCS })
  eq(projects.read_kept(state, SESSION), { API })
end

T['kept projects']['move nothing when the session had none kept'] = function()
  local state = state_directory('move_none')

  eq(projects.move_kept(state, SESSION, OTHER_SESSION), nil)

  eq(projects.read_kept(state, OTHER_SESSION), nil)
end

T['kept projects']['hold the time each project joined'] = function()
  local state = state_directory('joined')
  local joined = { key = API.key, top = API.top, joined = 1700000000123 }

  projects.keep(state, SESSION, { joined })

  eq(projects.read_kept(state, SESSION), { joined })
end

T['kept projects']['hold nothing but the key, the top and the joining of each project'] = function()
  local state = state_directory('shape')

  projects.keep(state, SESSION, { { key = API.key, top = API.top, joined = 5, extra = 'x' } })

  eq(
    vim.json.decode(contents(projects.kept_file(state, SESSION))),
    { projects = { { key = API.key, top = API.top, joined = 5 } } }
  )
end

T['the id a project follows'] = MiniTest.new_set()

T['the id a project follows']['differs for each project of one session'] = function()
  eq(projects.followed_id(SESSION, API) ~= projects.followed_id(SESSION, DOCS), true)
end

T['the id a project follows']['differs for each session of one project'] = function()
  eq(projects.followed_id(SESSION, API) ~= projects.followed_id(OTHER_SESSION, API), true)
end

T['the id a project follows']['differs for each joining of one project'] = function()
  local joined_again = { key = API.key, top = API.top, joined = 1700000000123 }

  eq(projects.followed_id(SESSION, API) ~= projects.followed_id(SESSION, joined_again), true)
end

T['the id a project follows']['is the same each time for a session and a joining'] = function()
  local joined = { key = API.key, top = API.top, joined = 1700000000123 }
  local met_elsewhere = { key = API.key, top = '/elsewhere', joined = 1700000000123 }

  eq(projects.followed_id(SESSION, joined), projects.followed_id(SESSION, met_elsewhere))
end

return T
