local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_pack = require('aineo.office_pack')
local office_scene = require('aineo.office_scene')

--- The default pack, loaded from the `aineo-office` folders on 'runtimepath',
--- where aineo's own checkout puts it.
---
---@return aineo.office_pack.Pack
local function default_pack()
  local pack, problem = office_pack.load({
    name = 'default',
    folders = vim.api.nvim_get_runtime_file('aineo-office', true),
  })
  return assert(pack, problem)
end

--- The group drawing the cell at `column` of the row `row`, both from 0, in
--- a picture where every cell is a pixel pair of three bytes.
---
---@param picture aineo.office_scene.Picture
---@param column integer
---@param row integer
---@return string|nil group
local function group_at(picture, column, row)
  local from = 3 * column
  local found = vim.iter(picture.rows[row + 1].runs):find(function(run)
    return run.from <= from and from < run.to
  end)
  return found and found.group
end

--- The picture of the default office `width` by 18 cells with the main agent
--- in `state`.
---
---@param width integer
---@param state string
---@return aineo.office_scene.Picture
local function picture_of(width, state)
  local stage = office_scene.new_stage({ pack = default_pack(), width = width, height = 18 })
  stage.advance({ { id = 'main', state = state } }, 0)
  return stage.picture()
end

local T = MiniTest.new_set()

T['the default pack'] = MiniTest.new_set()

T['the default pack']['has no problem when it is checked'] = function()
  local problems = office_pack.check({
    name = 'default',
    folders = vim.api.nvim_get_runtime_file('aineo-office', true),
  })

  eq(problems, {})
end

T['the default pack']['gives every state of the vocabulary, and nothing else, an activity'] = function()
  local names = vim.tbl_map(function(state)
    return state.name
  end, require('aineo.office_states').vocabulary())
  local keys = vim.tbl_keys(default_pack().state_activity)

  table.sort(names)
  table.sort(keys)

  eq(keys, names)
end

T['the default pack']['loads from the aineo-office folder of the checkout'] = function()
  local pack = default_pack()

  eq(pack.name, 'default')
  eq(pack.state_activity.working, 'work_at_the_desk')
  eq(pack.state_activity.idle, 'stand_by_the_desk')
end

T['the default pack']['has the art for every piece its poses, effects and legend name'] = function()
  local pack = default_pack()
  local named = {}
  for _, pose in pairs(pack.agent.poses) do
    vim.list_extend(named, pose.art)
  end
  for _, entry in pairs(pack.floor.legend) do
    table.insert(named, entry.piece)
  end

  local missing = vim.tbl_filter(function(name)
    return pack.pieces[name] == nil
  end, named)

  eq(missing, {})
end

T['the default pack']['has an effect for every pose that shows one'] = function()
  local pack = default_pack()

  for _, pose in pairs(pack.agent.poses) do
    eq(pose.effect == nil or pack.effects[pose.effect] ~= nil, true)
  end
end

T['the default pack']['has a spot in its plan for every spot its activities go to'] = function()
  local pack = default_pack()
  local spots_in_plan = {}
  for _, entry in pairs(pack.floor.legend) do
    spots_in_plan[entry.spot or ''] = true
  end

  for _, activity in pairs(pack.activities) do
    for _, step in ipairs(activity.steps) do
      eq(spots_in_plan[step.at], true)
    end
  end
end

T['the default office'] = MiniTest.new_set()

T['the default office']['shows a standing agent beside its desk, head over the floor'] = function()
  local picture = picture_of(54, 'standing')

  eq(vim.startswith(group_at(picture, 18, 10), 'AineoOfficePixel_a6e3a1_'), true)
  eq(vim.startswith(group_at(picture, 31, 10), 'AineoOfficePixel_a6e3a1_'), false)
end

T['the default office']['shows a working agent seated at its desk, its head over the desk'] = function()
  local picture = picture_of(54, 'working')

  eq(vim.startswith(group_at(picture, 31, 10), 'AineoOfficePixel_a6e3a1_'), true)
  eq(vim.startswith(group_at(picture, 18, 10), 'AineoOfficePixel_a6e3a1_'), false)
end

T['the default office']['hides a seated agent’s body behind the top of the desk'] = function()
  local picture = picture_of(54, 'working')

  eq(group_at(picture, 31, 13), 'AineoOfficePixel_b4875a_7a5634')
end

--- How many cells of the row `row` of `picture` are drawn in a group whose
--- name starts with `prefix`, when every cell is a pixel pair of three bytes.
---
---@param picture aineo.office_scene.Picture
---@param row integer from 0
---@param prefix string
---@return integer
local function cells_in_groups_starting_with(picture, row, prefix)
  local cells = 0
  for _, run in ipairs(picture.rows[row + 1].runs) do
    if vim.startswith(run.group, prefix) then
      cells = cells + (run.to - run.from) / 3
    end
  end
  return cells
end

T['the default office']['puts a monitor on each desk the width holds, 40 columns to a desk'] =
  MiniTest.new_set({
    parametrize = { { 54, 12 }, { 93, 12 }, { 94, 24 }, { 100, 24 }, { 134, 36 } },
  })

T['the default office']['puts a monitor on each desk the width holds, 40 columns to a desk']['width'] = function(
  width,
  monitor_cells
)
  local picture = picture_of(width, 'standing')

  eq(cells_in_groups_starting_with(picture, 10, 'AineoOfficePixel_45475a_'), monitor_cells)
end

--- The picture of the default office 54 cells wide whose main agent was
--- standing at time 0 and is working, so walking to its desk, at `now`.
---
---@param now number seconds
---@return aineo.office_scene.Picture
local function walking_picture_at(now)
  local stage = office_scene.new_stage({ pack = default_pack(), width = 54, height = 18 })
  stage.advance({ { id = 'main', state = 'standing' } }, 0)
  stage.advance({ { id = 'main', state = 'working' } }, now)
  return stage.picture()
end

--- The character at `column` of the row `row` of `picture`, both from 0.
---
---@param picture aineo.office_scene.Picture
---@param row integer
---@param column integer
---@return string
local function character_at(picture, row, column)
  return vim.fn.strcharpart(picture.rows[row + 1].text, column, 1)
end

T['the default office']['has a door on the wall, its frame and its panels'] = function()
  local picture = picture_of(54, 'standing')

  eq(group_at(picture, 2, 0), 'AineoOfficePixel_6b4f3f_6b4f3f')
  eq(group_at(picture, 4, 3), 'AineoOfficePixel_8b6a4f_8b6a4f')
end

T['the default office']['has desks whose top is wood over a darker edge'] = function()
  local picture = picture_of(54, 'standing')

  eq(group_at(picture, 30, 13), 'AineoOfficePixel_b4875a_7a5634')
end

T['the default office']['shows a walking agent’s legs apart, and the other pair of legs a fifth of a second on'] = function()
  eq(group_at(walking_picture_at(0.1), 15, 15), 'AineoOfficePixel_303446_749f71')
  eq(group_at(walking_picture_at(0.3), 20, 15), 'AineoOfficePixel_749f71_749f71')
end

T['the default office']['changes the dots over a typing agent every quarter of a second'] = function()
  local stage = office_scene.new_stage({ pack = default_pack(), width = 54, height = 18 })
  stage.advance({ { id = 'main', state = 'working' } }, 0)
  local first = character_at(stage.picture(), 9, 32)
  stage.advance({ { id = 'main', state = 'working' } }, 0.5)
  local later = character_at(stage.picture(), 9, 32)

  eq({ first, later }, { '▀', '.' })
end

return T
