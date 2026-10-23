--- The stage of the office: a pack's floor plan laid out to a size, the agents
--- on it, and the picture of it at a time.

local director_module = require('aineo.office_scene.director')
local floor_layout = require('aineo.office_scene.floor_layout')
local painter = require('aineo.office_scene.painter')
local status_list = require('aineo.office_scene.status_list')

local M = {}

---@class aineo.office_scene.StageOptions
---@field pack aineo.office_pack.Pack
---@field width integer cells
---@field height integer cells
---@field random? fun(): number the source of the random times of steps: a number from 0 up to, not including, 1; `math.random` when not given
---@field on_left_out? fun(count: integer) called with how many of the plan's pieces were left out, each time a layout leaves some out because a frame could not afford them
---@field clock? fun(): aineo.office_scene.WallTime the time on the wall outside the office, asked for each picture; none, and the pieces that show it show their art alone
---@field state_labels? table<string, string> what the status list says of each state, in words; the state's name where not given

---@class aineo.office_scene.Stage
---@field advance fun(agents: aineo.office_states.Agent[], now: number) puts the agents where their states and the time put them; `now` is in seconds, from any origin
---@field picture fun(): aineo.office_scene.Picture what the stage shows as of the last `advance()`
---@field resize fun(width: integer, height: integer) lays the plan out again for a new size; each agent keeps its activity and its step, at the spot of the same name and number

--- A stage for the office of `options.pack`, `options.width` by
--- `options.height` cells, with no agent on it.
---
---@param options aineo.office_scene.StageOptions
---@return aineo.office_scene.Stage
function M.new_stage(options)
  vim.validate('options.pack', options.pack, 'table')
  vim.validate('options.width', options.width, 'number')
  vim.validate('options.height', options.height, 'number')
  vim.validate('options.random', options.random, 'function', true)
  vim.validate('options.state_labels', options.state_labels, 'table', true)
  vim.validate('options.clock', options.clock, 'function', true)
  vim.validate('options.on_left_out', options.on_left_out, 'function', true)

  local pack = options.pack
  local width, height = options.width, options.height
  local now = 0
  local agents_shown = {}
  local plan_height, layout, director

  local function lay_out()
    plan_height = height - status_list.rows_taken(height)
    layout = floor_layout.lay_out(pack, width, plan_height)
    if layout.left_out > 0 and options.on_left_out then
      options.on_left_out(layout.left_out)
    end
    if director then
      director.use_layout(layout)
    else
      director = director_module.new_director(pack, layout, options.random or math.random)
    end
  end
  lay_out()

  local stage = {}

  function stage.advance(agents, time)
    now = time
    agents_shown = agents
    director.update(agents, time)
  end

  function stage.resize(new_width, new_height)
    width, height = new_width, new_height
    lay_out()
  end

  function stage.picture()
    return painter.paint({
      pack = pack,
      layout = layout,
      characters = director.characters(),
      things = director.things(),
      width = width,
      height = height,
      plan_height = plan_height,
      agents = agents_shown,
      places = director.places(),
      activities_played = director.activities_played(),
      state_labels = options.state_labels or {},
      wall_time = options.clock and options.clock(),
      now = now,
    })
  end

  return stage
end

return M
