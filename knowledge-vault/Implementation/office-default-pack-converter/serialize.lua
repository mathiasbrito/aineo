-- Writes `pack.lua`: Lua table literals of the subset the pack reader takes.

local M = {}

--- The order a table's fields are written in, by what the table is; the fields
--- a list does not name follow alphabetically.
local ORDER = {
  activity = { 'about', 'label', 'who', 'during', 'chance', 'players', 'steps' },
  step = {
    'at',
    'pose',
    'facing',
    'for_seconds',
    'effect',
    'even_if_taken',
    'the_one_moved_plays',
    'leave',
    'remove',
    'follow',
  },
  pose = { 'art', 'like', 'sitting', 'effect', 'screen', 'holding', 'rises' },
  effect = { 'text', 'colour', 'place', 'seconds_per_frame', 'bold' },
  legend = { 'piece', 'spot', 'sitting', 'facing', 'walk_over', 'in_use', 'decorations', 'shows' },
  thing = { 'piece', 'upsets_agents_within', 'upset_agents_play', 'cleaned_up_by' },
  character = { 'colours', 'how_many', 'like', 'poses' },
  floor = { 'plan', 'floor_colour', 'wall_colour', 'legend' },
}

local WIDTH = 96

local function quoted(text)
  return "'" .. text:gsub('\\', '\\\\'):gsub("'", "\\'") .. "'"
end

local function number(value)
  if value == math.floor(value) then
    return ('%d'):format(value)
  end
  return (('%.4f'):format(value):gsub('0+$', ''))
end

local function scalar(value)
  local kind = type(value)
  if kind == 'string' then
    return quoted(value)
  elseif kind == 'number' then
    return number(value)
  end
  return tostring(value)
end

local function key_text(key)
  if key:match('^[A-Za-z_][A-Za-z0-9_]*$') then
    return key
  end
  return '[' .. quoted(key) .. ']'
end

--- The keys of `table`, those of `order` first.
local function keys_of(value, order)
  local keys, seen = {}, {}
  for _, key in ipairs(order or {}) do
    if value[key] ~= nil then
      table.insert(keys, key)
      seen[key] = true
    end
  end
  local rest = {}
  for key in pairs(value) do
    if not seen[key] then
      table.insert(rest, key)
    end
  end
  table.sort(rest)
  return vim.list_extend(keys, rest)
end

local emit

--- The one-line form of a value, when it has one.
local function inline(value, order_of)
  if type(value) ~= 'table' then
    return scalar(value)
  end
  local parts = {}
  if vim.islist(value) and #value > 0 then
    for _, item in ipairs(value) do
      local text = inline(item, order_of)
      if not text then
        return nil
      end
      table.insert(parts, text)
    end
  elseif next(value) == nil then
    return '{}'
  else
    for _, key in ipairs(keys_of(value, order_of and order_of.fields)) do
      local text = inline(value[key], order_of and order_of.children and order_of.children[key])
      if not text then
        return nil
      end
      table.insert(parts, key_text(key) .. ' = ' .. text)
    end
  end
  return '{ ' .. table.concat(parts, ', ') .. ' }'
end

--- `value` as lines at `indent` columns, each line but the last ending in a
--- comma where it is an entry.
---@param value any
---@param indent integer
---@param order_of? table { fields = string[], children = table<string, table> } what to write in which order
---@return string
function emit(value, indent, order_of)
  if type(value) ~= 'table' then
    return scalar(value)
  end
  local short = inline(value, order_of)
  if short and #short + indent <= WIDTH then
    return short
  end
  local pad = (' '):rep(indent + 2)
  local lines = { '{' }
  if vim.islist(value) then
    for _, item in ipairs(value) do
      table.insert(lines, pad .. emit(item, indent + 2, order_of and order_of.item) .. ',')
    end
  else
    for _, key in ipairs(keys_of(value, order_of and order_of.fields)) do
      local child = order_of and order_of.children and order_of.children[key]
      if not child and order_of and order_of.each then
        child = order_of.each
      end
      table.insert(
        lines,
        pad .. key_text(key) .. ' = ' .. emit(value[key], indent + 2, child) .. ','
      )
    end
  end
  table.insert(lines, (' '):rep(indent) .. '}')
  return table.concat(lines, '\n')
end

local STEP = { fields = ORDER.step }
local ACTIVITY = { fields = ORDER.activity, children = { steps = { item = STEP } } }
local POSE = { fields = ORDER.pose }
local EFFECT = { fields = ORDER.effect }

--- The text of `pack.lua`.
---
---@param parts { colours: table<string, string>, definitions: table, legend: table }
---@return string
function M.pack(parts)
  local definitions = parts.definitions
  local activities = {}
  local activity_order = {}
  for _, entry in ipairs(definitions.activities) do
    activities[entry[1]] = entry[2]
    table.insert(activity_order, entry[1])
  end
  local lines = {
    '-- The default office: the approved mock\'s art, converted.',
    '-- An agent is a jelly bean. The wall carries a door, a whiteboard, a file cabinet, a bin',
    '-- under a clock, a coffee machine, a printer under a calendar and, as the room allows, a',
    '-- window, a water cooler, plants, a bookshelf, a picture and a fish tank. Rows of desks',
    '-- with monitors fill the height; a lounge with a three-seat sofa lies beside the first',
    '-- desk, another in the strip at the bottom of a tall room, with a table-tennis table.',
    'return {',
    '  format = 1,',
    "  name = 'default',",
    "  about = 'The default office: beans at desks and on sofas, a whiteboard, a file cabinet,"
      .. " a coffee machine, a printer, a cat.',",
    "  author = 'aineo',",
    '  based_on = false,',
    '',
    '  colours = ' .. emit(parts.colours, 2) .. ',',
    '',
    '  text_colours = ' .. emit(definitions.text_colours, 2) .. ',',
    '',
    '  characters = {',
    '    agent = {',
    '      colours = ' .. emit(definitions.agent_colours, 6) .. ',',
    '      poses = ' .. emit(definitions.agent_poses, 6, { each = POSE }) .. ',',
    '    },',
    '    cat = {',
    "      colours = { '#a5adcb' },",
    '      how_many = 1,',
    '      poses = ' .. emit(definitions.cat_poses, 6, { each = POSE }) .. ',',
    '    },',
    '  },',
    '',
    '  effects = ' .. emit(definitions.effects, 2, { each = EFFECT }) .. ',',
    '',
    '  floor = {',
    "    plan = 'floor.txt',",
    "    floor_colour = 'floor',",
    "    wall_colour = 'wall',",
    '    legend = ' .. emit(parts.legend, 4, { each = { fields = ORDER.legend } }) .. ',',
    '  },',
    '',
    '  activities = {',
  }
  for _, name in ipairs(activity_order) do
    table.insert(
      lines,
      '    ' .. key_text(name) .. ' = ' .. emit(activities[name], 4, ACTIVITY) .. ','
    )
  end
  table.insert(lines, '  },')
  table.insert(lines, '')
  table.insert(
    lines,
    '  things = ' .. emit(definitions.things, 2, { each = { fields = ORDER.thing } }) .. ','
  )
  table.insert(lines, '')
  table.insert(lines, '  states = ' .. emit(definitions.states, 2) .. ',')
  table.insert(lines, '}')
  return table.concat(lines, '\n') .. '\n'
end

return M
