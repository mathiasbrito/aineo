--- Packs, stages and readings of a picture for the tests of the office's
--- scene: a small pack of one-cell art in plain colours, drawn on a plan the
--- test gives, and the groups a picture's cells are drawn in.

local fixture = dofile('tests/helpers/fixture.lua')
local files = dofile('tests/helpers/office_pack_files.lua')
local office_pack = require('aineo.office_pack')
local office_scene = require('aineo.office_scene')

local M = {}

M.FLOOR = '#404040'
M.WALL = '#202020'
M.AGENT = '#ff00ff'
M.SECOND_AGENT = '#00ffff'

--- The text of an art file of one cell: two pixels of `letter`, which is
--- the colour `colour`, with its anchor at the bottom left.
---
---@param letter string
---@param colour string
---@return string
function M.cell_art(letter, colour)
  return ('colours: %s = %s\nanchor: 0, 1\n---\n%s\n%s\n'):format(letter, colour, letter, letter)
end

--- The art files of the scene tests' packs: one cell of a colour each, a
--- person who is one cell and takes the agent's colour, and a walker of two
--- cells, the agent's and a blue one.
M.ART = {
  ['art/person.txt'] = M.cell_art('A', 'agent'),
  ['art/walker.txt'] = 'colours: A = agent, B = blue\nanchor: 0, 1\n---\nAB\nAB\n',
  ['art/left.txt'] = M.cell_art('R', 'red'),
  ['art/dot.txt'] = 'colours: R = red\nanchor: 0, 0\n---\nR\n',
  ['art/first.txt'] = M.cell_art('G', 'green'),
  ['art/second.txt'] = M.cell_art('Y', 'yellow'),
  ['art/right.txt'] = M.cell_art('B', 'blue'),
  ['art/desk.txt'] = M.cell_art('W', 'brown'),
  ['art/wide.txt'] = 'colours: W = brown\nanchor: 0, 1\n---\nWW\nWW\n',
  ['art/bar.txt'] = 'colours: L = red, M = green, R = blue\nanchor: 0, 1\nstretch: columns 2-2\n---\nLMR\nLMR\n',
  ['art/blink.txt'] = 'colours: R = red, G = green\nanchor: 0, 1\nseconds per frame: 1\n---\nR\nR\n---\nG\nG\n',
  ['art/shades.txt'] = 'colours: L = agent_light, S = agent_shade, P = agent_blush\nanchor: 0, 1\n---\nLSP\nLSP\n',
}

--- The pack.lua fields of the scene tests' packs.
---@type table
M.PACK_FIELDS = {
  name = 'scene',
  colours = {
    wall = M.WALL,
    floor = M.FLOOR,
    red = '#ff0000',
    green = '#00ff00',
    yellow = '#ffff00',
    blue = '#0000ff',
    brown = '#885500',
  },
  characters = {
    agent = {
      colours = { M.AGENT, M.SECOND_AGENT },
      poses = {
        standing = { art = { 'person' } },
        walking = { art = { 'walker' } },
        sitting = { art = { 'person' }, sitting = true },
        typing = { like = 'sitting', effect = 'dots' },
      },
    },
  },
  effects = { dots = { text = { '.', '..' }, colour = '#ffffff', seconds_per_frame = 1 } },
  activities = {
    stand = { steps = { { at = 'aside', pose = 'standing' } } },
    work = { steps = { { at = 'seat', pose = 'typing' } } },
  },
  states = { standing = 'stand', working = 'work' },
}

--- A random source that gives `value` every time.
---
---@param value number from 0 up to, not including, 1
---@return fun(): number
function M.always(value)
  return function()
    return value
  end
end

--- A random source that gives the numbers of `first` in turn, and `value`
--- every time after them.
---
---@param first number[]
---@param value number
---@return fun(): number
function M.sequence(first, value)
  local drawn = 0
  return function()
    drawn = drawn + 1
    return first[drawn] or value
  end
end

--- What a test of the scene needs, with its packs written under the
--- fixture directory `directory_name`, which no other test file uses.
---
---@param directory_name string
---@return table scene
function M.new(directory_name)
  local scene = {
    FLOOR = M.FLOOR,
    WALL = M.WALL,
    AGENT = M.AGENT,
    SECOND_AGENT = M.SECOND_AGENT,
    cell_art = M.cell_art,
    always = M.always,
    sequence = M.sequence,
  }

  --- Loads a pack from `plan` and `legend` (the plan text and what its
  --- letters are), with the scene tests' art and the fields `changes`
  --- replace; `more_art` adds art files, or replaces the common ones.
  ---
  ---@param plan string the plan's text, comment and marker lines included
  ---@param legend table
  ---@param changes? table fields of pack.lua replaced
  ---@param more_art? table<string, string> art files by their path in the pack
  ---@return aineo.office_pack.Pack
  function scene.pack(plan, legend, changes, more_art)
    local fields = vim.tbl_extend('force', M.PACK_FIELDS, {
      floor = { floor_colour = 'floor', wall_colour = 'wall', legend = legend },
    }, changes or {})
    local folder = files.write_pack(
      fixture.directory(directory_name),
      'scene',
      vim.tbl_extend('force', M.ART, more_art or {}, {
        ['pack.lua'] = files.pack_text(fields),
        ['floor.txt'] = plan,
      })
    )
    return assert(office_pack.load({ name = 'scene', folders = { folder } }))
  end

  --- Loads a pack whose agents are one cell wide in every pose, so that the
  --- cell an agent is drawn in is the cell it is at: standing at `aside`
  --- and sitting at `seat` unless `changes` say otherwise.
  ---
  ---@param plan string
  ---@param legend table
  ---@param changes? table fields of pack.lua replaced
  ---@param more_art? table<string, string>
  ---@return aineo.office_pack.Pack
  function scene.people_pack(plan, legend, changes, more_art)
    return scene.pack(
      plan,
      legend,
      vim.tbl_extend('force', {
        characters = {
          agent = {
            colours = { M.AGENT, M.SECOND_AGENT },
            poses = {
              standing = { art = { 'person' } },
              walking = { art = { 'person' } },
              sitting = { art = { 'person' }, sitting = true },
            },
          },
        },
        activities = {
          stand = { steps = { { at = 'aside', pose = 'standing' } } },
          work = { steps = { { at = 'seat', pose = 'sitting' } } },
        },
      }, changes or {}),
      more_art
    )
  end

  --- A stage of `pack`, `width` by `height` cells.
  ---
  ---@param pack aineo.office_pack.Pack
  ---@param width integer
  ---@param height integer
  ---@param options? table more options of the stage
  ---@return aineo.office_scene.Stage
  function scene.stage_of(pack, width, height, options)
    return office_scene.new_stage(
      vim.tbl_extend('force', { pack = pack, width = width, height = height }, options or {})
    )
  end

  --- The group of the pixel pair of one colour, top and bottom alike.
  ---
  ---@param colour string `#rrggbb`
  ---@return string
  function scene.solid(colour)
    return ('AineoOfficePixel_%s_%s'):format(colour:sub(2), colour:sub(2))
  end

  --- The group drawing the cell at `column` of the row `row`, both from 0,
  --- in a picture where every cell is a pixel pair (three bytes of text).
  ---
  ---@param picture aineo.office_scene.Picture
  ---@param column integer
  ---@param row integer
  ---@return string|nil group
  function scene.group_at(picture, column, row)
    local from = 3 * column
    local found = vim.iter(picture.rows[row + 1].runs):find(function(run)
      return run.from <= from and from < run.to
    end)
    return found and found.group
  end

  --- The groups of the cells of a row of a picture, from the left.
  ---
  ---@param picture aineo.office_scene.Picture
  ---@param row integer from 0
  ---@param width integer
  ---@return string[]
  function scene.row_groups(picture, row, width)
    local groups = {}
    for column = 0, width - 1 do
      groups[column + 1] = scene.group_at(picture, column, row)
    end
    return groups
  end

  --- The picture drawn as a line of letters for each row, a letter for each
  --- cell: the one `letters` gives for the colour of a cell that is a pixel
  --- pair of one colour, `t` for a cell with text in it, and `?` for any other.
  ---
  ---@param picture aineo.office_scene.Picture
  ---@param width integer
  ---@param letters table<string, string> a letter by `#rrggbb`
  ---@return string[]
  function scene.sketch(picture, width, letters)
    local by_group = {}
    for colour, letter in pairs(letters) do
      by_group[scene.solid(colour)] = letter
    end
    local lines = {}
    for index, row in ipairs(picture.rows) do
      local starts = vim.str_utf_pos(row.text)
      local cells = {}
      for column = 1, width do
        local group = (vim.iter(row.runs):find(function(run)
          return run.from <= starts[column] - 1 and starts[column] - 1 < run.to
        end) or {}).group
        cells[column] = by_group[group] or (group and group:find('^AineoOfficeText') and 't') or '?'
      end
      lines[index] = table.concat(cells)
    end
    return lines
  end

  --- The cell an agent is drawn in, as `column .. ',' .. row`, or 'nowhere'
  --- when no cell of the picture is drawn in the agent's colour: the first
  --- agent's unless `colour` says another's. The picture is of cells that
  --- are all pixel pairs.
  ---
  ---@param picture aineo.office_scene.Picture
  ---@param width integer
  ---@param height integer
  ---@param colour? string `#rrggbb`
  ---@return string
  function scene.agent_cell(picture, width, height, colour)
    for row = 0, height - 1 do
      for column = 0, width - 1 do
        if scene.group_at(picture, column, row) == scene.solid(colour or M.AGENT) then
          return column .. ',' .. row
        end
      end
    end
    return 'nowhere'
  end

  --- A stage of `pack` and the cell its agent is drawn in at each time it is
  --- advanced to.
  ---
  ---@param pack aineo.office_pack.Pack
  ---@param width integer
  ---@param height integer
  ---@param options? table more options of the stage
  ---@return { stage: aineo.office_scene.Stage, cell_at: fun(agents: aineo.office_states.Agent[], time: number): string }
  function scene.watch(pack, width, height, options)
    local watched = { stage = scene.stage_of(pack, width, height, options) }
    function watched.cell_at(agents, time)
      watched.stage.advance(agents, time)
      return scene.agent_cell(watched.stage.picture(), width, height)
    end
    return watched
  end

  --- The agents, in the order given, in the states given: the first is
  --- `main`.
  ---
  ---@param ... string states
  ---@return aineo.office_states.Agent[]
  function scene.agents_in(...)
    local agents = {}
    for index, state in ipairs({ ... }) do
      agents[index] = { id = index == 1 and 'main' or ('agent' .. index), state = state }
    end
    return agents
  end

  --- Removes the packs the test wrote.
  function scene.cleanup()
    vim.fn.delete(fixture.directory(directory_name), 'rf')
  end

  return scene
end

return M
