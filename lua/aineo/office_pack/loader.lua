--- Loads a pack from its folder: `pack.lua` read as data, the floor plan and
--- the art files, assembled into the fields the engine reads. Every problem
--- is told with its file and line; a pack that cannot be used gives way to
--- the default pack.

local art = require('aineo.office_pack.art')
local description = require('aineo.office_pack.description')
local files = require('aineo.office_pack.files')
local floor = require('aineo.office_pack.floor')
local literal = require('aineo.office_pack.literal')
local problems_module = require('aineo.office_pack.problems')

local M = {}

--- The format of the vocabulary and the pack files this version of aineo reads.
local SUPPORTED_FORMAT = 1

--- The name of the pack the office falls back to.
local DEFAULT_NAME = 'default'

--- The colours the art of a character can name, besides the pack's.
local CHARACTER_COLOUR_NAMES = { 'agent', 'agent_light', 'agent_shade', 'agent_blush' }

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

---@class aineo.office_pack.LoadOptions
---@field name string the pack's name, the name of its folder
---@field folders string[] the folders that hold packs, searched in order

---@class aineo.office_pack.Reading
---@field name string the pack being read
---@field folders string[]
---@field problems aineo.office_pack.Problems

--- The first folder of `folders` that holds the pack `name`, with its
--- `pack.lua`; `nil` when none does.
---
---@param name string
---@param folders string[] folders that hold packs, each in a folder of its own named for it
---@return string|nil directory
local function find_directory(name, folders)
  for _, folder in ipairs(folders) do
    local directory = vim.fs.joinpath(folder, name)
    if vim.uv.fs_stat(vim.fs.joinpath(directory, 'pack.lua')) then
      return directory
    end
  end
  return nil
end

--- Tells that the pack `name` is in none of `folders`.
---
---@param name string
---@param folders string[]
---@param problems aineo.office_pack.Problems
local function report_missing(name, folders, problems)
  local report = problems.reporter_for(name, folders[1] or '', 'pack.lua')
  if #folders == 0 then
    report(nil, ('there is no pack “%s” in any folder'):format(name))
  else
    report(nil, ('there is no pack “%s” in %s'):format(name, table.concat(folders, ', ')))
  end
end

--- `pack.lua` of the pack in `directory`, as data.
---
---@param directory string
---@param report aineo.office_pack.Report
---@return table|nil data
local function read_description(directory, report)
  local text, read_problem = files.read_text(vim.fs.joinpath(directory, 'pack.lua'))
  if not text then
    report(nil, read_problem)
    return nil
  end
  local data, problem = literal.parse(text)
  if not data then
    local line, message = problem:match('^line (%d+): (.*)$')
    report(tonumber(line), message or problem)
    return nil
  end
  if data.format == nil then
    report(nil, 'the pack does not say its format')
    return nil
  end
  if data.format ~= SUPPORTED_FORMAT then
    report(
      nil,
      ('the pack is written for format %s, and aineo reads format %d'):format(
        tostring(data.format),
        SUPPORTED_FORMAT
      )
    )
    return nil
  end
  if type(data.name) ~= 'string' then
    report(nil, 'name is missing')
    return nil
  end
  return data
end

--- The floor of the pack in `directory`: the plan `data.floor.plan` names
--- with the colours and legend `data.floor` gives.
---
---@param directory string
---@param data table
---@param reporter_for fun(file: string): aineo.office_pack.Report
---@return aineo.office_pack.Floor|nil loaded
local function read_floor(directory, data, reporter_for)
  if type(data.floor) ~= 'table' then
    reporter_for('pack.lua')(nil, 'floor is missing')
    return nil
  end
  local file = type(data.floor.plan) == 'string' and data.floor.plan or 'floor.txt'
  local report = reporter_for(file)
  local text, read_problem = files.read_text(vim.fs.joinpath(directory, file))
  if not text then
    report(nil, read_problem)
    return nil
  end
  local plan, problem = floor.parse(text)
  if not plan then
    report(nil, problem)
    return nil
  end
  plan.floor_colour = data.floor.floor_colour
  plan.wall_colour = data.floor.wall_colour
  plan.legend = type(data.floor.legend) == 'table' and data.floor.legend or {}
  return plan
end

--- The names the colour headers of art may use: the pack's colours and the
--- character's own.
---
---@param colours table<string, string>
---@return table<string, true>
local function colour_names_of(colours)
  local names = {}
  for name in pairs(colours) do
    names[name] = true
  end
  for _, name in ipairs(CHARACTER_COLOUR_NAMES) do
    names[name] = true
  end
  return names
end

--- The pieces of the pack in `directory`, one for each art file that has no
--- problem.
---
---@param directory string
---@param colours table<string, string> the pack's colours
---@param reporter_for fun(file: string): aineo.office_pack.Report
---@return table<string, aineo.office_pack.Piece> pieces
local function read_pieces(directory, colours, reporter_for)
  local pieces = {}
  local colour_names = colour_names_of(colours)
  for _, name in ipairs(files.names_of_files(vim.fs.joinpath(directory, 'art'), '.txt')) do
    local file = ('art/%s.txt'):format(name)
    local report = reporter_for(file)
    local text, read_problem = files.read_text(vim.fs.joinpath(directory, file))
    if not text then
      report(nil, read_problem)
    else
      pieces[name] = art.parse(name, text, { report = report, colour_names = colour_names })
    end
  end
  return pieces
end

--- Assembles the pack from its description, floor and pieces.
---
---@param data table
---@param loaded_floor aineo.office_pack.Floor
---@param pieces table<string, aineo.office_pack.Piece>
---@param report aineo.office_pack.Report the report of `pack.lua`
---@return aineo.office_pack.Pack|nil pack
local function assemble(data, loaded_floor, pieces, report)
  local agent = type(data.characters) == 'table' and data.characters.agent or {}
  local poses, poses_problem = description.resolve_poses(agent.poses or {})
  if not poses then
    report(nil, poses_problem)
    return nil
  end
  local state_activity, states_problem = description.state_activities(data.states or {})
  if not state_activity then
    report(nil, states_problem)
    return nil
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

--- Loads the pack `name` from the first of `folders` that holds it, telling
--- its problems to `problems`.
---
---@param name string
---@param folders string[]
---@param problems aineo.office_pack.Problems
---@return aineo.office_pack.Pack|nil pack `nil` when the pack cannot be used
local function load_pack(name, folders, problems)
  local directory = find_directory(name, folders)
  if not directory then
    report_missing(name, folders, problems)
    return nil
  end
  local function reporter_for(file)
    return problems.reporter_for(name, directory, file)
  end
  local data = read_description(directory, reporter_for('pack.lua'))
  if not data then
    return nil
  end
  local loaded_floor = read_floor(directory, data, reporter_for)
  local pieces = read_pieces(directory, data.colours or {}, reporter_for)
  if not loaded_floor then
    return nil
  end
  return assemble(data, loaded_floor, pieces, reporter_for('pack.lua'))
end

--- Loads the pack `options.name` from the first of `options.folders` that
--- holds it, and gives the pack with every problem found in its files, each
--- with its file and line.
---
--- A pack that cannot be used — not found, not data, without a floor — gives
--- the default pack in its place, and its problems are among the problems; the
--- pack is `nil` only when the default pack cannot be used either.
---
---@param options aineo.office_pack.LoadOptions
---@return aineo.office_pack.Pack|nil pack
---@return aineo.office_pack.Problem[] problems
function M.load(options)
  vim.validate('options.name', options.name, 'string')
  vim.validate('options.folders', options.folders, 'table')
  local problems = problems_module.new_problems()
  local pack = load_pack(options.name, options.folders, problems)
  if not pack and options.name ~= DEFAULT_NAME then
    pack = load_pack(DEFAULT_NAME, options.folders, problems)
  end
  return pack, problems.list
end

--- Every problem of the pack `options.name` alone, whether or not it can be
--- used: what `:Aineo office check` lists.
---
---@param options aineo.office_pack.LoadOptions
---@return aineo.office_pack.Problem[] problems
function M.check(options)
  vim.validate('options.name', options.name, 'string')
  vim.validate('options.folders', options.folders, 'table')
  local problems = problems_module.new_problems()
  load_pack(options.name, options.folders, problems)
  return problems.list
end

return M
