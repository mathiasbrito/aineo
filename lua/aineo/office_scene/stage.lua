--- The stage of the office: a pack's floor plan laid out to a size, the agents
--- on it, and the picture of it at a time.

local director_module = require('aineo.office_scene.director')
local floor_layout = require('aineo.office_scene.floor_layout')
local painter = require('aineo.office_scene.painter')

local M = {}

---@class aineo.office_scene.StageOptions
---@field pack aineo.office_pack.Pack
---@field width integer cells
---@field height integer cells
---@field random? fun(): number the source of the random times of steps: a number from 0 up to, not including, 1; `math.random` when not given

---@class aineo.office_scene.Stage
---@field advance fun(agents: aineo.office_states.Agent[], now: number) puts the agents where their states and the time put them; `now` is in seconds, from any origin
---@field picture fun(): aineo.office_scene.Picture what the stage shows as of the last `advance()`
---@field resize fun(width: integer, height: integer) lays the plan out again for a new size; the agents are placed again by the next `advance()`

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

  local pack = options.pack
  local width, height = options.width, options.height
  local now = 0
  local layout, director

  local function lay_out()
    layout = floor_layout.lay_out(pack, width, height)
    director = director_module.new_director(pack, layout, options.random or math.random)
  end
  lay_out()

  local stage = {}

  function stage.advance(agents, time)
    now = time
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
      width = width,
      height = height,
      now = now,
    })
  end

  return stage
end

return M
