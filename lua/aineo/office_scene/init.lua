--- The office's engine, `require('aineo.office_scene')`: what the office looks
--- like, from a pack, a size, the agents' states and the time. Pure: it reads
--- no editor state, and it knows no art — the pack draws it.
---
--- A stage lays a pack's floor plan out to a size and puts the agents on it:
--- each agent plays the activity its state maps to, walking over the floor from
--- spot to spot and holding the pose of each step for its time (`director.lua`).
--- Its picture is rows of text and the highlight of their parts, painted on a
--- canvas of cells that hold two pixels each (`canvas.lua`): the floor, the
--- pieces and the agents back to front, and, from 24 rows, a status list on
--- the last rows (`status_list.lua`).

local canvas = require('aineo.office_scene.canvas')
local stage = require('aineo.office_scene.stage')

local M = {}

M.new_canvas = canvas.new_canvas
M.new_stage = stage.new_stage

return M
