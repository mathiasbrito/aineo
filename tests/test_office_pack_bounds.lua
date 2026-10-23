local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local bounded = dofile('tests/helpers/bounded.lua')
local fixture = dofile('tests/helpers/fixture.lua')

--- How long a run that must not hang may last, in milliseconds.
local LIMIT_MS = 20000

local T = MiniTest.new_set()

T['a bounded run'] = MiniTest.new_set()

T['a bounded run']['hands back what the code printed when it ends'] = function()
  local run = bounded.run("print('ended')", LIMIT_MS)

  eq(run.finished, true)
  eq(vim.trim(run.stdout), 'ended')
end

T['a bounded run']['is not finished when the code runs on past the limit'] = function()
  local run = bounded.run('while true do end', 400)

  eq(run.finished, false)
end

T['a bounded run']['is not finished when the code raises an error'] = function()
  eq(bounded.run("error('no')", LIMIT_MS).finished, false)
end

--- Lua that loads the smallest pack written in `directory`, puts `row` in
--- the place of a row of its plan, past the reader's checks, and lays the pack
--- out, draws it and prints `drawn`.
---
---@param directory string
---@param row string
---@return string
local function source_that_draws(directory, row)
  return ([[
    local files = dofile('tests/helpers/office_pack_files.lua')
    local folder = files.write_pack(%q, 'small')
    local pack = require('aineo.office_pack').load({
      name = 'small',
      folders = { folder },
      state_names = { 'standing', 'working', 'resting', 'idle' },
    })
    pack.floor.rows[2] = %q
    local stage = require('aineo.office_scene').new_stage({ pack = pack, width = 24, height = 8 })
    stage.advance({}, 0)
    stage.picture()
    print('drawn')
  ]]):format(directory, row)
end

T['a floor plan'] = MiniTest.new_set()

T['a floor plan']['with a NUL in a row is laid out and drawn without hanging'] = function()
  local directory = fixture.directory('bounds_nul_plan')

  local run = bounded.run(source_that_draws(directory, 'D.\0#'), LIMIT_MS)

  eq(run.finished, true)
  eq(vim.trim(run.stdout), 'drawn')
end

T['a floor plan']['laid out whatever the bytes of its rows are does not hang'] = function()
  local directory = fixture.directory('bounds_bytes_plan')
  local source = ([[
    local files = dofile('tests/helpers/office_pack_files.lua')
    local folder = files.write_pack(%q, 'small')
    local pack = require('aineo.office_pack').load({
      name = 'small',
      folders = { folder },
      state_names = { 'standing', 'working', 'resting', 'idle' },
    })
    for byte = 0, 255 do
      pack.floor.rows[2] = 'D' .. string.char(byte):rep(5) .. '#'
      pack.floor.legend[string.char(byte)] = { spot = 'x' }
      local stage = require('aineo.office_scene').new_stage({ pack = pack, width = 24, height = 8 })
      stage.advance({}, 0)
      stage.picture()
    end
    print('drawn')
  ]]):format(directory)

  local run = bounded.run(source, LIMIT_MS)

  eq(run.finished, true)
  eq(vim.trim(run.stdout), 'drawn')
end

T['an art header'] = MiniTest.new_set()

--- Lua that loads the smallest pack with the art file `art_text` and prints
--- the number of problems.
---
---@param directory string
---@param art_text string
---@return string
local function source_that_loads_art(directory, art_text)
  return ([[
    local files = dofile('tests/helpers/office_pack_files.lua')
    local folder = files.write_pack(%q, 'small', { ['art/probe.txt'] = %q })
    local _, problems = require('aineo.office_pack').load({
      name = 'small',
      folders = { folder },
      state_names = { 'standing', 'working', 'resting', 'idle' },
    })
    print(#problems)
  ]]):format(directory, art_text)
end

T['an art header']['of a value of 200 000 spaces is read at once'] = function()
  local directory = fixture.directory('bounds_header_value')
  local art = 'about: a' .. (' '):rep(200000) .. 'b\ncolours: A = ink\n---\nA\n'

  local run = bounded.run(source_that_loads_art(directory, art), 5000)

  eq(run.finished, true)
  eq(vim.trim(run.stdout), '0')
end

T['an art header']['of a line of 200 000 spaces and no colon is told at once'] = function()
  local directory = fixture.directory('bounds_header_keyless')
  local art = 'a' .. (' '):rep(200000) .. 'b\ncolours: A = ink\n---\nA\n'

  local run = bounded.run(source_that_loads_art(directory, art), 5000)

  eq(run.finished, true)
  eq(vim.trim(run.stdout), '1')
end

T['an art file'] = MiniTest.new_set()

T['an art file']['of 100 000 rows of other widths is told once, not for every row'] = function()
  local directory = fixture.directory('bounds_rows')
  local rows = {}
  for _ = 1, 50000 do
    table.insert(rows, 'AA')
    table.insert(rows, 'A')
  end
  local art = 'colours: A = ink\n---\n' .. table.concat(rows, '\n') .. '\n'

  local run = bounded.run(source_that_loads_art(directory, art), 10000)

  eq(run.finished, true)
  eq(vim.trim(run.stdout), '2')
end

T['a picture'] = MiniTest.new_set()

T['a picture']['of runs of a stretchable piece of 64 frames is drawn in a few milliseconds, frame after frame'] = function()
  local directory = fixture.directory('bounds_stretch')
  local source = ([[
    local files = dofile('tests/helpers/office_pack_files.lua')
    local frames = {}
    for _ = 1, 64 do
      frames[#frames + 1] = ('AB\n'):rep(100)
    end
    local art = 'colours: A = ink, B = wood\nstretch: columns 2-2\n---\n' .. table.concat(frames, '---\n')
    local plan = ' ~~~~~~\n ######\n' .. (' BBBB..\n'):rep(30)
    local folder = files.write_pack(%q, 'small', { ['art/bar.txt'] = art, ['floor.txt'] = plan })
    local pack = require('aineo.office_pack').load({
      name = 'small',
      folders = { folder },
      state_names = { 'standing', 'working', 'resting', 'idle' },
    })
    pack.floor.legend.B = { piece = 'bar' }
    local stage = require('aineo.office_scene').new_stage({ pack = pack, width = 100, height = 40 })
    stage.advance({}, 0)
    stage.picture()
    local started = vim.uv.hrtime()
    for frame = 1, 5 do
      stage.advance({}, frame)
      stage.picture()
    end
    print(((vim.uv.hrtime() - started) / 1e6 / 5) < 80 and 'quick' or 'slow')
  ]]):format(directory)

  local run = bounded.run(source, LIMIT_MS)

  eq(run.stderr, '')
  eq(vim.trim(run.stdout), 'quick')
end

T['loading a pack'] = MiniTest.new_set()

T['loading a pack']['and drawing it, whatever bytes its files hold, ends without an error'] = function()
  local directory = fixture.directory('bounds_fuzz')
  local source = ([[
    local files = dofile('tests/helpers/office_pack_files.lua')
    local office_pack = require('aineo.office_pack')
    local office_scene = require('aineo.office_scene')
    math.randomseed(20251023)
    local plan_pieces = { ' ', '.', '#', '~', '\n', 'D', 's', 'x', '\0', '\1', '\127', '\255', '%%', '(', '[', '\r' }
    local art_pieces = { 'colours: A = ink\n', '---\n', 'A', '.', '\n', ' ', ':', '\0', '\1', 'about', 'area screen: 0, 0, 1 x 1\n', 'stretch: columns 1-1\n', '\255', '\t' }
    local description_values = { "'\0'", "'a\1b'", "'%%'", "'" .. ('x'):rep(300) .. "'", '1e999', '-1e999', '{}', '{ {} }', 'true' }
    local function pick(pieces, count)
      local text = {}
      for _ = 1, count do
        text[#text + 1] = pieces[math.random(#pieces)]
      end
      return table.concat(text)
    end
    local errors = 0
    for case = 1, 150 do
      local description = files.pack_text({
        about = 'x',
        effects = { busy_dots = { text = { '.' } } },
      })
      local about = 'about = ' .. description_values[math.random(#description_values)]
      description = description:gsub("about = 'x'", function() return about end)
      local frame = 'text = { ' .. description_values[math.random(#description_values)] .. ' }'
      description = description:gsub('text = { "%%." }', function() return frame end)
      local folder = files.write_pack(%q .. '/' .. case, 'small', {
        ['pack.lua'] = description,
        ['floor.txt'] = ' ' .. pick(plan_pieces, math.random(1, 80)),
        ['art/person.txt'] = pick(art_pieces, math.random(1, 40)),
        ['art/extra.txt'] = pick(art_pieces, math.random(1, 40)),
      })
      local state = { 'standing', 'working', 'resting', 'idle' }
      local ok, pack, problems = pcall(office_pack.load, { name = 'small', folders = { folder }, state_names = state })
      local ok_check, checked = pcall(office_pack.check, { name = 'small', folders = { folder }, state_names = state })
      if not ok or not ok_check then
        errors = errors + 1
        io.stderr:write(tostring(pack), tostring(checked), '\n')
      elseif pack then
        local drew, failure = pcall(function()
          local stage = office_scene.new_stage({ pack = pack, width = 30, height = 10 })
          stage.advance({ { id = 'main', state = 'working' } }, 0)
          stage.picture()
        end)
        if not drew then
          errors = errors + 1
          io.stderr:write(tostring(failure), '\n')
        end
        vim.fn.setqflist({}, ' ', { items = office_pack.quickfix_items(problems) })
      end
    end
    print('errors ' .. errors)
  ]]):format(directory)

  local run = bounded.run(source, 60000)

  eq(run.stderr, '')
  eq(run.finished, true)
  eq(vim.trim(run.stdout), 'errors 0')
end

return T
