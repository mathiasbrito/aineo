--- Loads a pack from its folder: `pack.lua` read as data, the floor plan and
--- the art files, assembled into the fields the engine reads. The first
--- problem stops the load, and names the file it is in.

local art = require('aineo.office_pack.art')
local description = require('aineo.office_pack.description')
local files = require('aineo.office_pack.files')
local floor = require('aineo.office_pack.floor')
local literal = require('aineo.office_pack.literal')

local M = {}

--- The format of the vocabulary and the pack files this version of aineo reads.
local SUPPORTED_FORMAT = 1

---@class aineo.office_pack.Floor : aineo.office_pack.FloorPlan
---@field floor_colour? string a name from the pack's `colours`
---@field wall_colour? string a name from the pack's `colours`
---@field legend table<string, table> what each letter of the plan is

---@class aineo.office_pack.Pack
---@field name string
---@field about string
---@field author string
---@field colours table<string, string> `#rrggbb` by name
---@field text_colours table<string, string> `#rrggbb` by role of the office's text
---@field agent { colours: string[], poses: table<string, aineo.office_pack.Pose> }
---@field effects table<string, aineo.office_pack.Effect>
---@field pieces table<string, aineo.office_pack.Piece>
---@field floor aineo.office_pack.Floor
---@field activities table<string, table> what characters do, by name; each has `steps`
---@field state_activity table<string, string> the activity each state of the vocabulary plays

--- `problem` located in `file` of the pack: its line when it names one.
---
---@param file string
---@param problem string
---@return string
local function located(file, problem)
  if problem:match('^line %d+: ') then
    return ('%s, %s'):format(file, problem)
  end
  return ('%s: %s'):format(file, problem)
end

--- The first folder of `folders` that holds the pack `name`, with its
--- `pack.lua`; `nil` and the problem when none does.
---
---@param name string
---@param folders string[] folders that hold packs, each in a folder of its own named for it
---@return string|nil directory
---@return string|nil problem
local function find_directory(name, folders)
  for _, folder in ipairs(folders) do
    local directory = vim.fs.joinpath(folder, name)
    if vim.uv.fs_stat(vim.fs.joinpath(directory, 'pack.lua')) then
      return directory
    end
  end
  if #folders == 0 then
    return nil, ('there is no pack “%s” in any folder'):format(name)
  end
  return nil, ('there is no pack “%s” in %s'):format(name, table.concat(folders, ', '))
end

--- `pack.lua` of the pack in `directory`, as data.
---
---@param directory string
---@return table|nil data
---@return string|nil problem
local function read_description(directory)
  local text, read_problem = files.read_text(vim.fs.joinpath(directory, 'pack.lua'))
  if not text then
    return nil, located('pack.lua', read_problem)
  end
  local data, problem = literal.parse(text)
  if not data then
    return nil, located('pack.lua', problem)
  end
  if data.format == nil then
    return nil, located('pack.lua', 'the pack does not say its format')
  end
  if data.format ~= SUPPORTED_FORMAT then
    return nil,
      located(
        'pack.lua',
        ('the pack is written for format %s, and aineo reads format %d'):format(
          tostring(data.format),
          SUPPORTED_FORMAT
        )
      )
  end
  if type(data.name) ~= 'string' then
    return nil, located('pack.lua', 'name is missing')
  end
  return data
end

--- The floor of the pack in `directory`: the plan `data.floor.plan` names
--- with the colours and legend `data.floor` gives.
---
---@param directory string
---@param data table
---@return aineo.office_pack.Floor|nil loaded
---@return string|nil problem
local function read_floor(directory, data)
  if type(data.floor) ~= 'table' then
    return nil, located('pack.lua', 'floor is missing')
  end
  local file = type(data.floor.plan) == 'string' and data.floor.plan or 'floor.txt'
  local text, read_problem = files.read_text(vim.fs.joinpath(directory, file))
  if not text then
    return nil, located(file, read_problem)
  end
  local plan, problem = floor.parse(text)
  if not plan then
    return nil, located(file, problem)
  end
  plan.floor_colour = data.floor.floor_colour
  plan.wall_colour = data.floor.wall_colour
  plan.legend = type(data.floor.legend) == 'table' and data.floor.legend or {}
  return plan
end

--- The pieces of the pack in `directory`, one for each file in its `art` folder.
---
---@param directory string
---@return table<string, aineo.office_pack.Piece>|nil pieces
---@return string|nil problem
local function read_pieces(directory)
  local pieces = {}
  for _, name in ipairs(files.names_of_files(vim.fs.joinpath(directory, 'art'), '.txt')) do
    local file = ('art/%s.txt'):format(name)
    local text, read_problem = files.read_text(vim.fs.joinpath(directory, file))
    if not text then
      return nil, located(file, read_problem)
    end
    local piece, problem = art.parse(name, text)
    if not piece then
      return nil, located(file, problem)
    end
    pieces[name] = piece
  end
  return pieces
end

--- Assembles the pack from its description, floor and pieces.
---
---@param data table
---@param loaded_floor aineo.office_pack.Floor
---@param pieces table<string, aineo.office_pack.Piece>
---@return aineo.office_pack.Pack|nil pack
---@return string|nil problem
local function assemble(data, loaded_floor, pieces)
  local agent = type(data.characters) == 'table' and data.characters.agent or {}
  local poses, poses_problem = description.resolve_poses(agent.poses or {})
  if not poses then
    return nil, located('pack.lua', poses_problem)
  end
  local state_activity, states_problem = description.state_activities(data.states or {})
  if not state_activity then
    return nil, located('pack.lua', states_problem)
  end
  return {
    name = data.name,
    about = data.about or '',
    author = data.author or '',
    colours = data.colours or {},
    text_colours = description.fill_text_colours(data.text_colours),
    agent = { colours = description.agent_colours(agent.colours), poses = poses },
    effects = description.fill_effects(data.effects or {}),
    pieces = pieces,
    floor = loaded_floor,
    activities = data.activities or {},
    state_activity = state_activity,
  }
end

---@class aineo.office_pack.LoadOptions
---@field name string the pack's name, the name of its folder
---@field folders string[] the folders that hold packs, searched in order

--- Loads the pack `options.name` from the first of `options.folders` that
--- holds it.
---
--- `nil` and the first problem, naming its file and line, when the pack is
--- not found or its files are not what a pack is.
---
---@param options aineo.office_pack.LoadOptions
---@return aineo.office_pack.Pack|nil pack
---@return string|nil problem
function M.load(options)
  vim.validate('options.name', options.name, 'string')
  vim.validate('options.folders', options.folders, 'table')
  local directory, missing = find_directory(options.name, options.folders)
  if not directory then
    return nil, missing
  end
  local data, problem = read_description(directory)
  if not data then
    return nil, problem
  end
  local loaded_floor
  loaded_floor, problem = read_floor(directory, data)
  if not loaded_floor then
    return nil, problem
  end
  local pieces
  pieces, problem = read_pieces(directory)
  if not pieces then
    return nil, problem
  end
  return assemble(data, loaded_floor, pieces)
end

return M
