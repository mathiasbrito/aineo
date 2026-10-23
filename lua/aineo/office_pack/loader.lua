--- Loads a pack from its folder: `pack.lua` read as data, the floor plan and
--- the art files, laid over the pack it is based on, into the fields the
--- engine reads. Every problem is told with its file and line; what has a
--- problem is left out so that the pack it is based on shows through, and a
--- pack that cannot be used gives way to the default pack.

local art = require('aineo.office_pack.art')
local characters = require('aineo.office_pack.characters')
local checks = require('aineo.office_pack.checks')
local entries = require('aineo.office_pack.entries')
local files = require('aineo.office_pack.files')
local pack_names = require('aineo.office_pack.names')
local floor = require('aineo.office_pack.floor')
local literal = require('aineo.office_pack.literal')
local pack_format = require('aineo.office_pack.pack_format')
local problems_module = require('aineo.office_pack.problems')
local schema = require('aineo.office_pack.schema')
local states = require('aineo.office_pack.states')

local M = {}

--- The format of the vocabulary and the pack files this version of aineo reads.
local SUPPORTED_FORMAT = 1

--- The name of the pack the office falls back to, and that a pack is based on
--- when it says nothing.
local DEFAULT_NAME = 'default'

--- How many packs deep a pack may be based on others.
local MAX_BASE_DEPTH = 8

--- The most art files a pack holds.
local MAX_PIECES = 500

--- The colours of the office's text when no pack names them: the highlight
--- group of the editor each takes.
local DEFAULT_TEXT_COLOURS = {
  name = 'Comment',
  status = 'Normal',
  thought = 'Special',
  warning = 'WarningMsg',
}

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
---@field text_colours table<string, string> `#rrggbb` or the name of a highlight group, by role of the office's text
---@field agent aineo.office_pack.Character
---@field subagent aineo.office_pack.Character the looks of the agent unless the pack gives its own
---@field cat? aineo.office_pack.Character none for a pack that draws no cat
---@field effects table<string, aineo.office_pack.Effect>
---@field pieces table<string, aineo.office_pack.Piece>
---@field floor aineo.office_pack.Floor
---@field activities table<string, table> what characters do, by name; each has `steps`
---@field things table<string, table> what an activity leaves behind, by name
---@field states table<string, string> the activity the pack maps to each state it maps
---@field state_activity table<string, string> the activity each state of the vocabulary plays
---@field triggers table[] the custom matches, tried in order

---@class aineo.office_pack.Effect
---@field text string[] its frames
---@field colour string a role of the office's text, a colour as `#rrggbb` or a highlight group
---@field place string
---@field seconds_per_frame number
---@field bold boolean

---@class aineo.office_pack.LoadOptions
---@field name string the pack's name, the name of its folder
---@field folders string[] the folders that hold packs, searched in order
---@field replaced_pieces? table<string, string> art files of the user's own, by the name of the piece each replaces
---@field state_names? string[] the states a pack may map; the office's vocabulary when not given

---@class aineo.office_pack.Reading
---@field folders string[]
---@field problems aineo.office_pack.Problems
---@field state_names string[]
---@field files aineo.office_pack.FileSession

---@class aineo.office_pack.Build
---@field data table the pack's description
---@field directory string
---@field base aineo.office_pack.Pack|nil
---@field context aineo.office_pack.SchemaContext
---@field reporter_for fun(file: string): aineo.office_pack.Report
---@field files aineo.office_pack.FileSession

--- The first folder of `folders` that holds the pack `name`, with its
--- `pack.lua`; `nil` when none does.
---
---@param name string
---@param folders string[] folders that hold packs, each in a folder of its own named for it
---@param session aineo.office_pack.FileSession
---@return string|nil directory
local function find_directory(name, folders, session)
  for _, folder in ipairs(folders) do
    local directory = vim.fs.joinpath(folder, name)
    if session.exists(vim.fs.joinpath(directory, 'pack.lua')) then
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
  local report = problems.reporter_for(pack_names.shown(name), folders[1] or '', 'pack.lua')
  if #folders == 0 then
    report(nil, ('there is no pack “%s” in any folder'):format(pack_names.shown(name)))
  else
    report(
      nil,
      ('there is no pack “%s” in %s'):format(
        pack_names.shown(name),
        table.concat(folders, ', ')
      )
    )
  end
end

--- Tells that `name` is no pack's name.
---
---@param name string
---@param folders string[]
---@param problems aineo.office_pack.Problems
local function report_not_a_name(name, folders, problems)
  problems.reporter_for(pack_names.shown(name), folders[1] or '', 'pack.lua')(
    nil,
    ('the pack name “%s” is not letters, digits, _ and -'):format(pack_names.shown(name))
  )
end

--- The text of the file `path`, read in `session`; when it cannot be read, the
--- reason is told to `report` (once, for the reasons that are told once) and
--- there is no text.
---
---@param session aineo.office_pack.FileSession
---@param path string
---@param boundary string|nil the folder the file must lie in
---@param report aineo.office_pack.Report
---@return string|nil
local function text_of(session, path, boundary, report)
  local text, problem, told = session.read_text(path, boundary)
  if not text and not told then
    report(nil, problem)
  end
  return text
end

--- `pack.lua` of the pack in `directory`, as data, with the lines of its
--- entries.
---
---@param directory string
---@param report aineo.office_pack.Report
---@param session aineo.office_pack.FileSession
---@return table|nil data
---@return table|nil lines
local function read_description(directory, report, session)
  local text = text_of(session, vim.fs.joinpath(directory, 'pack.lua'), directory, report)
  if not text then
    return nil
  end
  local data, problem, lines = literal.parse(text)
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
      lines[data].format,
      ('the pack is written for format %s, and aineo reads format %d'):format(
        tostring(data.format),
        SUPPORTED_FORMAT
      )
    )
    return nil
  end
  if type(data.name) ~= 'string' then
    report(lines[data].name, 'name is missing')
    return nil
  end
  return data, lines
end

--- The names the colour headers of art may use: the pack's colours and the
--- character's own.
---
---@param colours table<string, string>
---@return table<string, true>
local function colour_names_of(colours)
  local names = entries.names_of(colours)
  for _, name in ipairs(CHARACTER_COLOUR_NAMES) do
    names[name] = true
  end
  return names
end

--- The pieces of the art files in the folder `art` of `directory`, those with
--- no problem.
---
---@param directory string
---@param colour_names table<string, true>
---@param reporter_for fun(file: string): aineo.office_pack.Report
---@param session aineo.office_pack.FileSession
---@return table<string, aineo.office_pack.Piece> pieces
local function read_pieces(directory, colour_names, reporter_for, session)
  local pieces = {}
  local names = session.names_of_files(vim.fs.joinpath(directory, 'art'), '.txt')
  for index, name in ipairs(names) do
    local file = ('art/%s.txt'):format(name)
    local report = reporter_for(file)
    if index > MAX_PIECES then
      report(nil, ('the pack has more than %d art files'):format(MAX_PIECES))
      break
    end
    local text = text_of(session, vim.fs.joinpath(directory, file), directory, report)
    if text then
      pieces[name] = art.parse(name, text, { report = report, colour_names = colour_names })
    end
  end
  return pieces
end

--- The name of the pack the pack `name`, whose description is `data`, is
--- based on: the one it names, none for `false`, and the default pack when it
--- says nothing, except for the default pack itself.
---
---@param name string
---@param data table
---@return string|nil
local function base_name_of(name, data)
  if data.based_on == false then
    return nil
  end
  if data.based_on == nil then
    return name ~= DEFAULT_NAME and DEFAULT_NAME or nil
  end
  return data.based_on
end

local resolve_pack

--- The pack the pack `name` is based on, resolved, or `nil` when it is based
--- on none or on a pack that cannot be used or that loops back.
---
---@param name string
---@param data table
---@param lines table
---@param reading aineo.office_pack.Reading
---@param chain string[] the packs being resolved, the pack `name` and those it is based on first
---@param report aineo.office_pack.Report
---@return aineo.office_pack.Pack|nil
local function resolve_base(name, data, lines, reading, chain, report)
  local base_name = base_name_of(name, data)
  if type(base_name) ~= 'string' then
    return nil
  end
  local line = lines[data].based_on
  if vim.list_contains(chain, base_name) then
    report(line, ('based_on loops back to the pack “%s”'):format(base_name))
    return nil
  end
  if #chain >= MAX_BASE_DEPTH then
    report(
      line,
      ('the pack is based on more than %d packs, one after another'):format(MAX_BASE_DEPTH)
    )
    return nil
  end
  local base = resolve_pack(base_name, reading, chain)
  if not base then
    report(line, ('the pack “%s” it is based on cannot be used'):format(base_name))
  end
  return base
end

--- The characters of `pack` by kind; none for a pack that is none.
---
---@param pack aineo.office_pack.Pack|nil
---@return table<string, aineo.office_pack.Character>
local function characters_of(pack)
  if not pack then
    return {}
  end
  return { agent = pack.agent, subagent = pack.subagent, cat = pack.cat }
end

--- The names the references of the pack's entries may name: the entries the
--- pack declares, even when one has a problem, and those of the pack it is
--- based on.
---
---@param build aineo.office_pack.Build
---@param reading aineo.office_pack.Reading
---@param colours table<string, string>
---@param pieces table<string, aineo.office_pack.Piece>
---@return table<string, table<string, true>>
local function known_names(build, reading, colours, pieces)
  local data, base = build.data, build.base or {}
  local function declared(field)
    return entries.names_of(base[field], type(data[field]) == 'table' and data[field] or nil)
  end
  local state_set = {}
  for _, state in ipairs(reading.state_names) do
    state_set[state] = true
  end
  return {
    colour = entries.names_of(colours),
    piece = entries.names_of(pieces),
    effect = declared('effects'),
    activity = declared('activities'),
    thing = declared('things'),
    pose = characters.pose_names(data, characters_of(build.base)),
    state = state_set,
    during = vim.tbl_extend('force', state_set, { always = true }),
  }
end

--- The floor of the pack: the plan its `floor` field names read, with its
--- colours and the legend entries that have no problem; the floor of the pack
--- it is based on when the pack gives none or the plan cannot be used.
---
---@param build aineo.office_pack.Build
---@return aineo.office_pack.Floor|nil
local function read_floor(build)
  local data, context = build.data, build.context
  local base_floor = build.base and build.base.floor
  if data.floor == nil then
    if not base_floor then
      context.report(nil, 'floor is missing')
    end
    return base_floor
  end
  if
    not schema.check(data.floor, pack_format.FLOOR, context, 'floor', context.lines[data].floor)
  then
    return base_floor
  end
  local legend = entries.accepted(
    data.floor.legend,
    pack_format.LEGEND,
    'floor.legend',
    context,
    context.lines[data.floor].legend
  )
  local report = build.reporter_for(data.floor.plan)
  local text =
    text_of(build.files, vim.fs.joinpath(build.directory, data.floor.plan), build.directory, report)
  if not text then
    return base_floor
  end
  local plan = floor.parse(text, report)
  if not plan then
    return base_floor
  end
  floor.check_letters(plan, type(data.floor.legend) == 'table' and data.floor.legend or {}, report)
  checks.check_spots_reachable(plan, legend, report)
  return vim.tbl_extend('force', plan, {
    floor_colour = data.floor.floor_colour,
    wall_colour = data.floor.wall_colour,
    legend = legend,
  })
end

--- The triggers of the pack that have no problem, followed by those of the
--- pack it is based on.
---
---@param build aineo.office_pack.Build
---@return table[]
local function read_triggers(build)
  local data, context = build.data, build.context
  local own = data.triggers
  local triggers = {}
  if own ~= nil and (type(own) ~= 'table' or not vim.islist(own)) then
    context.report(context.lines[data].triggers, 'triggers must be a list')
  elseif own ~= nil then
    for index, trigger in ipairs(own) do
      local path = ('triggers[%d]'):format(index)
      if schema.check(trigger, pack_format.TRIGGER, context, path, context.lines[own][index]) then
        table.insert(triggers, trigger)
      end
    end
  end
  return vim.list_extend(triggers, vim.deepcopy(build.base and build.base.triggers or {}))
end

--- Tells the problems of `pack.lua` that no entry has: a field no pack has, a
--- name that is not the folder's.
---
---@param build aineo.office_pack.Build
---@param folder_name string
local function check_head(build, folder_name)
  local data, context = build.data, build.context
  schema.check(data, pack_format.HEAD, context, '', 1)
  if data.name ~= folder_name then
    context.report(
      context.lines[data].name,
      ('name is “%s”, and the pack’s folder is “%s”'):format(data.name, folder_name)
    )
  end
end

--- The entries of the field `field` of the pack that have no problem, laid
--- over those of the pack it is based on.
---
---@param build aineo.office_pack.Build
---@param field string
---@param node aineo.office_pack.SchemaNode
---@return table
local function read_entries(build, field, node)
  local data, context = build.data, build.context
  local accepted = entries.accepted(data[field], node, field, context, context.lines[data][field])
  return entries.overlaid(build.base and build.base[field], accepted)
end

--- The colours of the office's text: the defaults, those of the pack it is
--- based on, and those of the pack that have no problem.
---
---@param build aineo.office_pack.Build
---@return table<string, string>
local function read_text_colours(build)
  local data, context = build.data, build.context
  local own = entries.accepted(
    data.text_colours,
    pack_format.TEXT_COLOURS,
    'text_colours',
    context,
    context.lines[data].text_colours
  )
  return vim.tbl_extend(
    'force',
    DEFAULT_TEXT_COLOURS,
    build.base and build.base.text_colours or {},
    own
  )
end

--- Tells what keeps the pack from being used, and whether it can be: it
--- needs a floor, an agent that stands and walks, and an activity for standing.
---
---@param pack table the pack as far as it is read
---@param build aineo.office_pack.Build
---@return boolean
local function is_usable(pack, build)
  local data, lines = build.data, build.context.lines
  local is_usable_agent = characters.check_agent(pack, build.context, lines[data].characters)
  if not pack.state_activity then
    build.context.report(lines[data].states, 'states must give standing an activity')
  end
  return pack.floor ~= nil and is_usable_agent and pack.state_activity ~= nil
end

--- The pack `name`, resolved from its description and the pack it is based on.
---
---@param name string
---@param reading aineo.office_pack.Reading
---@param chain string[] the packs being resolved, the outermost first
---@return aineo.office_pack.Pack|nil pack `nil` when the pack cannot be used
function resolve_pack(name, reading, chain)
  if not pack_names.is_plain(name) then
    report_not_a_name(name, reading.folders, reading.problems)
    return nil
  end
  local directory = find_directory(name, reading.folders, reading.files)
  if not directory then
    report_missing(name, reading.folders, reading.problems)
    return nil
  end
  local function reporter_for(file)
    return reading.problems.reporter_for(name, directory, file)
  end
  local report = reporter_for('pack.lua')
  local data, lines = read_description(directory, report, reading.files)
  if not data then
    return nil
  end
  local base = resolve_base(name, data, lines, reading, vim.list_extend({ name }, chain), report)
  local build = {
    data = data,
    directory = directory,
    base = base,
    context = { report = report, lines = lines, known = {} },
    reporter_for = reporter_for,
    files = reading.files,
  }
  check_head(build, name)
  local pack = { name = data.name, about = data.about, author = data.author }
  pack.colours = read_entries(build, 'colours', pack_format.COLOURS)
  pack.pieces = entries.overlaid(
    base and base.pieces,
    read_pieces(directory, colour_names_of(pack.colours), reporter_for, reading.files)
  )
  build.context.known = known_names(build, reading, pack.colours, pack.pieces)
  pack.text_colours = read_text_colours(build)
  pack.states = read_entries(build, 'states', pack_format.STATES)
  pack.state_activity = states.activities(pack.states)
  pack.effects = read_entries(build, 'effects', pack_format.EFFECTS)
  pack.activities = read_entries(build, 'activities', pack_format.ACTIVITIES)
  pack.things = read_entries(build, 'things', pack_format.THINGS)
  pack.triggers = read_triggers(build)
  local drawn = characters.read(data, characters_of(base), build.context)
  pack.agent, pack.subagent, pack.cat = drawn.agent, drawn.subagent, drawn.cat
  pack.floor = read_floor(build)
  if pack.floor then
    checks.check_activities_have_spots({
      activities = pack.activities,
      legend = pack.floor.legend,
      things = pack.things,
      described = type(data.activities) == 'table' and data.activities or {},
      lines = lines,
      floor_line = data.floor ~= nil and lines[data].floor or nil,
      report = report,
    })
  end
  return is_usable(pack, build) and pack or nil
end

--- Puts the art files of `replaced_pieces` in the place of the pieces of
--- their names, those with no problem.
---
---@param pack aineo.office_pack.Pack
---@param replaced_pieces table<string, string> art files, by the name of the piece each replaces
---@param problems aineo.office_pack.Problems
---@param session aineo.office_pack.FileSession
local function replace_pieces(pack, replaced_pieces, problems, session)
  local colour_names = colour_names_of(pack.colours)
  for _, name in ipairs(entries.sorted_keys(replaced_pieces)) do
    local path = vim.fs.normalize(replaced_pieces[name])
    local directory, file = vim.fs.dirname(path), vim.fs.basename(path)
    local report = problems.reporter_for('office.pieces', directory, file)
    local text = text_of(session, path, nil, report)
    if text then
      pack.pieces[name] = art.parse(name, text, { report = report, colour_names = colour_names })
        or pack.pieces[name]
    end
  end
end

--- Reads the options, fills what they leave out.
---
---@param options aineo.office_pack.LoadOptions
---@return aineo.office_pack.Reading
local function reading_of(options)
  vim.validate('options.name', options.name, 'string')
  vim.validate('options.folders', options.folders, 'table')
  vim.validate('options.replaced_pieces', options.replaced_pieces, 'table', true)
  vim.validate('options.state_names', options.state_names, 'table', true)
  return {
    folders = options.folders,
    problems = problems_module.new_problems(),
    state_names = options.state_names or states.names(),
    files = files.new_session(),
  }
end

--- Loads the pack `name` with the art files of `options.replaced_pieces` in
--- place of its pieces.
---
---@param name string
---@param options aineo.office_pack.LoadOptions
---@param reading aineo.office_pack.Reading
---@return aineo.office_pack.Pack|nil
local function load_pack(name, options, reading)
  local pack = resolve_pack(name, reading, {})
  if pack and options.replaced_pieces then
    replace_pieces(pack, options.replaced_pieces, reading.problems, reading.files)
  end
  return pack
end

--- The loads kept, by what was asked for, so that the office showing again
--- reads a pack only when a file of it has changed.
---@type table<string, { files: aineo.office_pack.FileSession, pack: aineo.office_pack.Pack|nil, problems: aineo.office_pack.Problem[] }>
local kept_loads = {}

--- How many loads are kept at most.
local MOST_KEPT_LOADS = 8

--- What a load asked for, as one string: the name, the folders, the pieces
--- of the user's own and the states.
---
---@param options aineo.office_pack.LoadOptions
---@return string
local function key_of(options)
  local pieces = {}
  for _, name in ipairs(entries.sorted_keys(options.replaced_pieces or {})) do
    table.insert(pieces, name .. '=' .. options.replaced_pieces[name])
  end
  return table.concat({
    options.name,
    table.concat(options.folders, '\1'),
    table.concat(pieces, '\1'),
    table.concat(options.state_names or {}, '\1'),
  }, '\0')
end

--- `pack` with the tables a caller changes - the colours of its text and its
--- effects, which the office makes from highlight groups into colours - copied.
---
---@param pack aineo.office_pack.Pack|nil
---@return aineo.office_pack.Pack|nil
local function copy_for_showing(pack)
  if not pack then
    return nil
  end
  return vim.tbl_extend('force', pack, {
    text_colours = vim.deepcopy(pack.text_colours),
    effects = vim.deepcopy(pack.effects),
  })
end

--- Loads the pack `options.name` from the first of `options.folders` that
--- holds it, laid over the pack it is based on, and gives the pack with every
--- problem found in its files, each with its file and line.
---
--- A pack that cannot be used — not found, not data, without a floor or a
--- standing agent — gives the default pack in its place, and its problems are
--- among the problems; the pack is `nil` only when the default pack cannot be
--- used either.
---
--- A load is kept, and the next one with the same options gives it again, no
--- file read, while every file and folder it looked at is as it was (its type,
--- size and time of change); the pack it gives is its own to change.
---
---@param options aineo.office_pack.LoadOptions
---@return aineo.office_pack.Pack|nil pack
---@return aineo.office_pack.Problem[] problems
function M.load(options)
  local reading = reading_of(options)
  local key = key_of(options)
  local kept = kept_loads[key]
  if kept and kept.files.is_unchanged() then
    return copy_for_showing(kept.pack), vim.deepcopy(kept.problems)
  end
  local pack = load_pack(options.name, options, reading)
  if not pack and options.name ~= DEFAULT_NAME then
    pack = load_pack(DEFAULT_NAME, options, reading)
  end
  local problems = problems_module.ordered(reading.problems.list)
  if vim.tbl_count(kept_loads) >= MOST_KEPT_LOADS then
    kept_loads = {}
  end
  kept_loads[key] = {
    files = reading.files,
    pack = copy_for_showing(pack),
    problems = vim.deepcopy(problems),
  }
  return pack, problems
end

--- Every problem of the pack `options.name` alone, whether or not it can be
--- used: what `:Aineo office check` lists.
---
---@param options aineo.office_pack.LoadOptions
---@return aineo.office_pack.Problem[] problems
function M.check(options)
  local reading = reading_of(options)
  load_pack(options.name, options, reading)
  return problems_module.ordered(reading.problems.list)
end

return M
