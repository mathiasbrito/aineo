local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fixture = dofile('tests/helpers/fixture.lua')
local files = dofile('tests/helpers/office_pack_files.lua')
local office_pack = require('aineo.office_pack')

--- The directory the packs of one case are written in, emptied.
---
---@return string
local function pack_root()
  return fixture.directory('office_pack_floor')
end

--- The pack `small` with `plan_text` as its floor plan.
---
---@param plan_text string
---@return string folder
local function pack_with_plan(plan_text)
  return files.write_pack(pack_root(), 'small', { ['floor.txt'] = plan_text })
end

--- The floor of the pack `small` with `plan_text` as its plan.
---
---@param plan_text string
---@return aineo.office_pack.Floor
local function floor_of(plan_text)
  local pack = office_pack.load({ name = 'small', folders = { pack_with_plan(plan_text) } })
  return pack.floor
end

--- The problems the plan `plan_text` has, each as `{ line, message }`.
---
---@param plan_text string
---@return table[]
local function plan_problems(plan_text)
  local problems = office_pack.check({ name = 'small', folders = { pack_with_plan(plan_text) } })
  local told = {}
  for _, problem in ipairs(problems) do
    assert(problem.file == 'floor.txt', 'a problem in another file: ' .. problem.file)
    table.insert(told, { problem.line, problem.message })
  end
  return told
end

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      vim.fn.delete(pack_root(), 'rf')
    end,
  },
})

T['floor plans'] = MiniTest.new_set()

T['floor plans']['are read without their comments and their marker column'] = function()
  local floor = floor_of('# one\n# two\n  ~~\n ####\n D..#\n ..s.\n')

  eq(floor.rows, { '####', 'D..#', '..s.' })
end

T['floor plans']['say the columns that repeat, counted from 1 in the plan'] = function()
  eq(floor_of('  ~~\n ####\n D..#\n').repeated_columns, { first = 2, last = 3 })
end

T['floor plans']['read a row shorter than the widest as ending in spaces'] = function()
  local floor = floor_of(' \n .....\n ..\n .\n')

  eq(floor.rows, { '.....', '..   ', '.    ' })
end

T['floor plans']['say no columns repeat when the marker line marks none'] = function()
  eq(floor_of('    \n ####\n D..#\n').repeated_columns, nil)
end

T['floor plans']['say the rows that repeat, counted from 1 in the plan'] = function()
  local floor = floor_of(' \n ####\n~D..#\n~.s.#\n ####\n')

  eq(floor.repeated_rows, { first = 2, last = 3 })
  eq(#floor.rows, 4)
end

T['floor plans']['say no rows repeat when the first column marks none'] = function()
  eq(floor_of(' \n ####\n D..#\n').repeated_rows, nil)
end

--- Plans with something wrong, the line each problem is on and what it says.
local WRONG_PLANS = {
  { 'no rows', '# only comments\n', 1, 'the plan has no rows' },
  { 'a marker line and no row', ' ~~\n', 1, 'the plan has no rows' },
  {
    'columns that repeat in two blocks',
    ' ~~.~\n ####\n D..#\n',
    1,
    'the marker line marks one block of columns that repeat',
  },
  {
    'a row that starts with neither a space nor ~',
    '\n ####\nx####\n',
    3,
    'a row starts with a space, or with ~ when it repeats',
  },
  {
    'rows that repeat in two blocks',
    ' \n ####\n~D..#\n D..#\n~D..#\n',
    5,
    'the rows that repeat are one block',
  },
  {
    'a letter the legend does not have',
    ' \n .D..\n .D.q\n',
    3,
    'the letter “q” is not in the floor legend',
  },
  {
    'a letter the legend does not have, told once',
    ' \n .q..\n .q.q\n',
    2,
    'the letter “q” is not in the floor legend',
  },
}

T['floor plans']['that are wrong are told with the line, one by one'] = MiniTest.new_set({
  parametrize = WRONG_PLANS,
})

T['floor plans']['that are wrong are told with the line, one by one']['case'] = function(
  _,
  plan_text,
  line,
  message
)
  eq(plan_problems(plan_text), { { line, message } })
end

T['floor plans']['may be 400 cells wide and 200 rows tall'] = function()
  local wide = ' \n ' .. ('.'):rep(400) .. '\n'
  local tall = ' \n' .. (' .\n'):rep(200)

  eq(plan_problems(wide), {})
  eq(plan_problems(tall), {})
end

T['floor plans']['are refused over 400 cells wide'] = function()
  eq(plan_problems(' \n ' .. ('.'):rep(401) .. '\n'), { { 2, 'the plan is wider than 400 cells' } })
end

T['floor plans']['are refused over 200 rows tall'] = function()
  eq(plan_problems(' \n' .. (' .\n'):rep(201)), { { 2, 'the plan is taller than 200 rows' } })
end

return T
