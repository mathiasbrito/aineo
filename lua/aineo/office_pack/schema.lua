--- A way to say what a table read from `pack.lua` must look like, and to
--- check one against it: each node of a schema names a kind of value, and
--- checking tells every way a value falls short, at the line of the entry
--- that does, in plain words that name the entry by its path (`pose
--- characters.agent.poses.typing`). It also fills in the defaults a schema
--- gives.
---
--- ```
--- local POSE = schema.fields('a pose', {
---   art = schema.list(schema.reference('piece')),
---   sitting = schema.with_default(schema.flag, false),
--- }, { at_least_one_of = { 'art', 'like' } })
--- ```

local config = require('aineo.config')

local M = {}

---@class aineo.office_pack.SchemaContext
---@field report aineo.office_pack.Report tells a problem of `pack.lua`
---@field lines table<table, table<string|integer, integer>> the line each entry of each table starts on
---@field known table<string, table<string, true>> the names the pack has, by kind: `piece`, `effect`, `pose`, `activity`, `thing`, `state`, `colour`

---@class aineo.office_pack.SchemaNode
---@field kind string
---@field expected string what the value must be, in words that complete “… must be …”
---@field default? any filled in when the entry is left out
---@field required? boolean

--- The most colours a pack names.
local MAX_COLOURS = 64

--- A name: lowercase words joined by `_`.
local NAME_PATTERN = '^[a-z][a-z0-9_]*$'

--- Shallow copy of `node` with `changes` over it.
---
---@param node aineo.office_pack.SchemaNode
---@param changes table
---@return aineo.office_pack.SchemaNode
local function derived(node, changes)
  return vim.tbl_extend('force', node, changes)
end

--- `node`, required: the entry cannot be left out.
---
---@param node aineo.office_pack.SchemaNode
---@return aineo.office_pack.SchemaNode
function M.required(node)
  return derived(node, { required = true })
end

--- `node`, filled in with `value` when the entry is left out.
---
---@param node aineo.office_pack.SchemaNode
---@param value any
---@return aineo.office_pack.SchemaNode
function M.with_default(node, value)
  return derived(node, { default = value })
end

M.text = { kind = 'text', expected = 'text' }
M.flag = { kind = 'flag', expected = 'true or false' }
M.number = { kind = 'number', expected = 'a number' }
M.amount = { kind = 'amount', expected = 'a number above 0' }
M.count = { kind = 'count', expected = 'a whole number of at least 1' }
M.colour = { kind = 'colour', expected = 'a colour as #rrggbb' }
M.text_colour = {
  kind = 'text_colour',
  expected = 'a colour as #rrggbb or the name of a highlight group',
}
M.cells = { kind = 'cells', expected = 'text of characters one cell wide' }

--- A Lua pattern a pack may match with: one Lua reads whole that repeats once
--- at most (`aineo.config`'s `lua_pattern_problem()`).
M.pattern = {
  kind = 'pattern',
  expected = 'a Lua pattern Lua reads whole that repeats once at most',
}

--- Text, or a table that `table_node` describes.
---
---@param table_node aineo.office_pack.SchemaNode
---@param expected string
---@return aineo.office_pack.SchemaNode
function M.text_or_table(table_node, expected)
  return { kind = 'text_or_table', table_node = table_node, expected = expected }
end

--- A key that is a name: lowercase words joined by `_`.
M.name = { kind = 'name', expected = 'a name of lowercase words joined by _' }

--- A key that is one character, other than the characters a plan is drawn in.
M.letter = { kind = 'letter', expected = 'one character that is not . # space or ~' }

--- Anything: the entries are checked one by one by whoever needs them.
M.anything = { kind = 'anything', expected = 'anything' }

--- `false`, the way to say none.
M.none = { kind = 'none', expected = 'false' }

--- A time in seconds: one number above 0, or two for a random time between.
M.seconds = {
  kind = 'seconds',
  expected = 'a number above 0, or two numbers, the shortest and the longest',
}

--- One of `values`.
---
---@param values string[]
---@return aineo.office_pack.SchemaNode
function M.choice(values)
  return {
    kind = 'choice',
    values = values,
    expected = 'one of ' .. table.concat(values, ', '),
  }
end

--- The name of an entry of the pack of kind `target`: `piece`, `effect`,
--- `pose`, `activity`, `thing`, `state` or `colour`. A problem calls the
--- entry `options.noun` (`target` by default), and says `options.owner` (the
--- pack by default) does not have it.
---
---@param target string
---@param options? { noun?: string, owner?: string }
---@return aineo.office_pack.SchemaNode
function M.reference(target, options)
  local noun = options and options.noun or target
  return {
    kind = 'reference',
    target = target,
    noun = noun,
    owner = options and options.owner or 'pack',
    expected = 'the name of a ' .. noun,
  }
end

--- A list of at least `minimum` entries of `item`.
---
---@param item aineo.office_pack.SchemaNode
---@param minimum? integer
---@return aineo.office_pack.SchemaNode
function M.list(item, minimum)
  return {
    kind = 'list',
    item = item,
    minimum = minimum or 0,
    expected = 'a list' .. ((minimum or 0) > 0 and (' of at least %d'):format(minimum) or ''),
  }
end

--- A table of entries of `item`, each under a name of `keys` — a node that
--- checks the key, `name` for lowercase words joined by `_` — and, when
--- `most` is given, at most that many.
---
---@param item aineo.office_pack.SchemaNode
---@param options? { keys?: aineo.office_pack.SchemaNode, most?: integer }
---@return aineo.office_pack.SchemaNode
function M.map(item, options)
  return {
    kind = 'map',
    item = item,
    keys = options and options.keys,
    most = options and options.most,
    expected = 'a table',
  }
end

--- A table with the entries `spec` names, each a node, and no others.
--- `options.at_least_one_of` names entries of which one must be there.
---
---@param what string how the table is called in a problem, such as `a pose`
---@param spec table<string, aineo.office_pack.SchemaNode>
---@param options? { at_least_one_of?: string[] }
---@return aineo.office_pack.SchemaNode
function M.fields(what, spec, options)
  return {
    kind = 'fields',
    what = what,
    spec = spec,
    at_least_one_of = options and options.at_least_one_of,
    expected = 'a table',
  }
end

--- The first of `nodes` the value passes.
---
---@param expected string
---@param nodes aineo.office_pack.SchemaNode[]
---@return aineo.office_pack.SchemaNode
function M.either(expected, nodes)
  return { kind = 'either', nodes = nodes, expected = expected }
end

--- The path of the entry `key` of the entry at `path`; the root's path is empty.
---
---@param path string
---@param key string|integer
---@return string
local function child(path, key)
  if path == '' then
    return tostring(key)
  end
  return ('%s.%s'):format(path, key)
end

--- Tells `message` for the entry at `path`, on `line`.
---
---@param context aineo.office_pack.SchemaContext
---@param line integer|nil
---@param path string
---@param message string
local function tell(context, line, path, message)
  context.report(line, path == '' and message or ('%s %s'):format(path, message))
end

---@param context aineo.office_pack.SchemaContext
---@param line integer|nil
---@param path string
---@param node aineo.office_pack.SchemaNode
local function tell_must_be(context, line, path, node)
  tell(context, line, path, 'must be ' .. node.expected)
end

--- Whether `value` is a number that is neither infinite nor not a number.
---
---@param value any
---@return boolean
local function is_finite(value)
  return type(value) == 'number' and value == value and math.abs(value) ~= math.huge
end

--- Whether `value` is text of characters one cell wide each.
---
---@param value any
---@return boolean
local function is_single_cell_text(value)
  return type(value) == 'string' and vim.fn.strdisplaywidth(value) == vim.fn.strchars(value)
end

--- Whether `value` is a colour as `#rrggbb`.
---
---@param value any
---@return boolean
local function is_hex_colour(value)
  return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
end

--- Whether `value` is a colour as `#rrggbb` or the name of a highlight group.
---
---@param value any
---@return boolean
local function is_text_colour(value)
  if type(value) ~= 'string' then
    return false
  end
  if vim.startswith(value, '#') then
    return is_hex_colour(value)
  end
  return value:match('^[%w_.@]+$') ~= nil
end

--- Checks of the kinds that look at one value only: whether `value` is what
--- the node says.
---@type table<string, fun(value: any, node: aineo.office_pack.SchemaNode): boolean>
local SCALAR_CHECKS = {
  text = function(value)
    return type(value) == 'string'
  end,
  flag = function(value)
    return type(value) == 'boolean'
  end,
  number = is_finite,
  amount = function(value)
    return is_finite(value) and value > 0
  end,
  count = function(value)
    return is_finite(value) and value >= 1 and value == math.floor(value)
  end,
  colour = is_hex_colour,
  text_colour = is_text_colour,
  cells = is_single_cell_text,
  pattern = function(value)
    return type(value) == 'string' and config.lua_pattern_problem(value) == nil
  end,
  name = function(value)
    return type(value) == 'string' and value:match(NAME_PATTERN) ~= nil
  end,
  letter = function(value)
    return type(value) == 'string' and #value == 1 and not value:match('[%.# ~]')
  end,
  anything = function()
    return true
  end,
  none = function(value)
    return value == false
  end,
  choice = function(value, node)
    return vim.list_contains(node.values, value)
  end,
  seconds = function(value)
    if type(value) == 'table' then
      return #value == 2
        and is_finite(value[1])
        and is_finite(value[2])
        and value[1] >= 0
        and value[1] <= value[2]
    end
    return is_finite(value) and value > 0
  end,
}

local check_node

--- Checks a value of a scalar kind.
---
---@param value any
---@param node aineo.office_pack.SchemaNode
---@param context aineo.office_pack.SchemaContext
---@param path string
---@param line integer|nil
---@return boolean
local function check_scalar(value, node, context, path, line)
  if SCALAR_CHECKS[node.kind](value, node) then
    return true
  end
  if node.kind == 'pattern' and type(value) == 'string' then
    tell_must_be(
      context,
      line,
      path,
      { expected = node.expected .. ': ' .. config.lua_pattern_problem(value) }
    )
  elseif node.kind == 'cells' and type(value) == 'string' then
    tell(
      context,
      line,
      path,
      ('“%s” has characters wider than one cell on this screen'):format(value)
    )
  else
    tell_must_be(context, line, path, node)
  end
  return false
end

--- Checks a reference to an entry of the pack.
---
---@param value any
---@param node aineo.office_pack.SchemaNode
---@param context aineo.office_pack.SchemaContext
---@param path string
---@param line integer|nil
---@return boolean
local function check_reference(value, node, context, path, line)
  if type(value) ~= 'string' then
    tell_must_be(context, line, path, node)
    return false
  end
  if not context.known[node.target][value] then
    tell(
      context,
      line,
      path,
      ('names the %s “%s”, which the %s does not have'):format(node.noun, value, node.owner)
    )
    return false
  end
  return true
end

--- Checks the entries of a list.
---
---@param value any
---@param node aineo.office_pack.SchemaNode
---@param context aineo.office_pack.SchemaContext
---@param path string
---@param line integer|nil
---@return boolean
local function check_list(value, node, context, path, line)
  if type(value) ~= 'table' or not vim.islist(value) then
    tell_must_be(context, line, path, node)
    return false
  end
  if #value < node.minimum then
    tell_must_be(context, line, path, node)
    return false
  end
  local lines = context.lines[value] or {}
  local ok = true
  for index, item in ipairs(value) do
    local item_ok =
      check_node(item, node.item, context, ('%s[%d]'):format(path, index), lines[index])
    ok = ok and item_ok
  end
  return ok
end

--- Checks the keys and the entries of a table of entries of one kind.
---
---@param value any
---@param node aineo.office_pack.SchemaNode
---@param context aineo.office_pack.SchemaContext
---@param path string
---@param line integer|nil
---@return boolean
local function check_map(value, node, context, path, line)
  if type(value) ~= 'table' or (next(value) ~= nil and vim.islist(value)) then
    tell_must_be(context, line, path, node)
    return false
  end
  local lines = context.lines[value] or {}
  local ok = true
  if node.most and vim.tbl_count(value) > node.most then
    tell(context, line, path, ('has more than %d entries'):format(node.most))
    ok = false
  end
  for key, item in pairs(value) do
    local key_line = lines[key]
    if node.keys and not check_node(key, node.keys, context, child(path, key), key_line) then
      ok = false
    end
    local item_ok = check_node(item, node.item, context, child(path, key), key_line)
    ok = ok and item_ok
  end
  return ok
end

--- Checks the entries of a table with the entries a spec names.
---
---@param value any
---@param node aineo.office_pack.SchemaNode
---@param context aineo.office_pack.SchemaContext
---@param path string
---@param line integer|nil
---@return boolean
local function check_fields(value, node, context, path, line)
  if type(value) ~= 'table' or (next(value) ~= nil and vim.islist(value)) then
    tell_must_be(context, line, path, node)
    return false
  end
  local lines = context.lines[value] or {}
  local ok = true
  for key, entry in pairs(value) do
    local spec = node.spec[key]
    if not spec then
      tell(context, lines[key], child(path, key), ('is not a field of %s'):format(node.what))
      ok = false
    else
      local entry_ok = check_node(entry, spec, context, child(path, key), lines[key])
      ok = ok and entry_ok
    end
  end
  for key, spec in pairs(node.spec) do
    if value[key] == nil then
      if spec.required then
        tell(context, line, path, ('is missing %s'):format(key))
        ok = false
      elseif spec.default ~= nil then
        value[key] = vim.deepcopy(spec.default)
      end
    end
  end
  if node.at_least_one_of then
    local given = vim.tbl_filter(function(key)
      return value[key] ~= nil
    end, node.at_least_one_of)
    if #given == 0 then
      tell(context, line, path, ('needs %s'):format(table.concat(node.at_least_one_of, ' or ')))
      ok = false
    end
  end
  return ok
end

--- Checks that `value` passes one of the nodes, without telling what is
--- wrong with the others.
---
---@param value any
---@param node aineo.office_pack.SchemaNode
---@param context aineo.office_pack.SchemaContext
---@param path string
---@param line integer|nil
---@return boolean
local function check_either(value, node, context, path, line)
  for _, alternative in ipairs(node.nodes) do
    local silent = { report = function() end, lines = context.lines, known = context.known }
    if check_node(value, alternative, silent, path, line) then
      return true
    end
  end
  tell_must_be(context, line, path, node)
  return false
end

--- Checks `value` that is text or a table the node describes.
---
---@param value any
---@param node aineo.office_pack.SchemaNode
---@param context aineo.office_pack.SchemaContext
---@param path string
---@param line integer|nil
---@return boolean
local function check_text_or_table(value, node, context, path, line)
  if type(value) == 'string' then
    return true
  elseif type(value) == 'table' then
    return check_node(value, node.table_node, context, path, line)
  end
  tell_must_be(context, line, path, node)
  return false
end

--- Checks `value` against `node`, telling every problem to `context.report`
--- with the line of the entry that has it, and filling in the defaults the
--- schema gives. `path` names the entry in what is told.
---
---@param value any
---@param node aineo.office_pack.SchemaNode
---@param context aineo.office_pack.SchemaContext
---@param path string
---@param line integer|nil the line `value` starts on
---@return boolean ok whether nothing was told
function check_node(value, node, context, path, line)
  if node.kind == 'fields' then
    return check_fields(value, node, context, path, line)
  elseif node.kind == 'map' then
    return check_map(value, node, context, path, line)
  elseif node.kind == 'list' then
    return check_list(value, node, context, path, line)
  elseif node.kind == 'reference' then
    return check_reference(value, node, context, path, line)
  elseif node.kind == 'either' then
    return check_either(value, node, context, path, line)
  elseif node.kind == 'text_or_table' then
    return check_text_or_table(value, node, context, path, line)
  end
  return check_scalar(value, node, context, path, line)
end

M.check = check_node

--- Checks that `value` is a table that can hold the entries `node` (a map)
--- describes, and not too many of them; the entries are for `check_entry()`.
---
---@param value any
---@param node aineo.office_pack.SchemaNode
---@param context aineo.office_pack.SchemaContext
---@param path string
---@param line integer|nil
---@return boolean ok
function M.check_shape(value, node, context, path, line)
  if type(value) ~= 'table' or (next(value) ~= nil and vim.islist(value)) then
    tell_must_be(context, line, path, node)
    return false
  end
  if node.most and vim.tbl_count(value) > node.most then
    tell(context, line, path, ('has more than %d entries'):format(node.most))
    return false
  end
  return true
end

--- Checks the entry `key` of `value`, a table `check_shape()` accepted, and
--- the key itself, as `node` (a map) says.
---
---@param value table
---@param key string
---@param node aineo.office_pack.SchemaNode
---@param context aineo.office_pack.SchemaContext
---@param path string the path of `value`
---@return boolean ok
function M.check_entry(value, key, node, context, path)
  local entry_path = child(path, key)
  local line = (context.lines[value] or {})[key]
  local key_ok = not node.keys or check_node(key, node.keys, context, entry_path, line)
  local entry_ok = check_node(value[key], node.item, context, entry_path, line)
  return key_ok and entry_ok
end

--- The most colours a pack names.
M.MAX_COLOURS = MAX_COLOURS

return M
