--- The rules of a test layout as they are stated — by the agent, by a
--- preset, by the user's correction — checked, and turned into the rules
--- finding uses.

local template = require('aineo.test_layout.template')

local M = {}

--- A rule as stated: either a rule of its own, or a preset named by its
--- id, with its kind or its `create` overridden.
---@class aineo.test_layout.Statement
---@field preset? string the id of a preset, for a statement that names one
---@field source? string
---@field test? string|string[] one test template, or the alternatives, the first used to create
---@field inline? boolean
---@field folder? string
---@field kind? string
---@field create? boolean
---@field discover? string[]
---@field framework? string
---@field companions? string[]

--- A preset: a known layout of tests, with what marks a repository that
--- follows it.
---@class aineo.test_layout.Preset
---@field id string such as `python.pytest.flat`
---@field framework string
---@field doc string the documentation of the layout
---@field extensions string[] the extensions of the sources it is for
---@field markers (string|{ file: string, holds: string })[] globs of the files whose presence marks it, or a file and a text it holds
---@field discover string[] the framework's discovery globs, relative to the unit root
---@field rules aineo.test_layout.Statement[]
---@field companions? string[]
---@field convention? boolean whether no documentation states the layout, which is a common convention

--- The most rules a repository keeps.
M.MOST_RULES = 32

--- The longest discovery glob, in characters.
local LONGEST_GLOB = 256

--- The fields a statement that names a preset may give.
local PRESET_FIELDS = { preset = true, kind = true, create = true }

--- The fields a rule of its own may give.
local RULE_FIELDS = {
  source = true,
  test = true,
  inline = true,
  folder = true,
  kind = true,
  create = true,
  discover = true,
  framework = true,
  companions = true,
}

--- Whether `value` is a JSON object: a table that is no non-empty list.
---
---@param value any
---@return boolean
local function is_object(value)
  return type(value) == 'table' and not (vim.islist(value) and next(value) ~= nil)
end

--- Whether `value` is a non-empty list of strings.
---
---@param value any
---@return boolean
local function is_string_list(value)
  return type(value) == 'table'
    and vim.islist(value)
    and #value > 0
    and vim.iter(value):all(function(item)
      return type(item) == 'string'
    end)
end

--- The first of `statement`'s keys, in sorted order, that `fields` lacks.
---
---@param statement table
---@param fields table<string, true>
---@return string?
local function unknown_field(statement, fields)
  local unknown = vim.tbl_filter(function(key)
    return not fields[key]
  end, vim.tbl_keys(statement))
  table.sort(unknown, function(left, right)
    return tostring(left) < tostring(right)
  end)
  return unknown[1] and tostring(unknown[1])
end

--- The longest free text a rule may give, its `kind` or `framework`, in
--- characters.
local LONGEST_TEXT = 64

--- The characters free text may not hold, as UTF-8 patterns: the C0
--- controls (NUL and the line breaks among them) and DEL; the C1 controls
--- (NEL among them); the zero-width characters U+200B–U+200F, the line and
--- paragraph separators U+2028 and U+2029 and the bidirectional embeddings
--- U+202A–U+202E; the bidirectional isolates U+2066–U+2069; and U+FEFF.
local CONTROLS = {
  '[%c\127]',
  '\194[\128-\159]',
  '\226\128[\139-\143\168-\174]',
  '\226\129[\166-\169]',
  '\239\187\191',
}

--- Whether `value` is valid UTF-8: each lead byte followed by as many
--- continuation bytes as it announces, no overlong two-byte form.
---
---@param value string
---@return boolean
local function is_utf8(value)
  local at = 1
  while at <= #value do
    local byte = value:byte(at)
    local length = byte < 0x80 and 1
      or (byte >= 0xC2 and byte < 0xE0) and 2
      or (byte >= 0xE0 and byte < 0xF0) and 3
      or (byte >= 0xF0 and byte < 0xF5) and 4
      or nil
    if not length then
      return false
    end
    for next_at = at + 1, at + length - 1 do
      local continuation = value:byte(next_at)
      if not continuation or continuation < 0x80 or continuation > 0xBF then
        return false
      end
    end
    at = at + length
  end
  return true
end

--- Why `value`, the free text an agent gives as a rule's `kind` or a
--- `framework`, is refused: no string, holding a character `CONTROLS`
--- names, not valid UTF-8, or longer than 64 characters; nil when it is
--- accepted. It reaches the user's window bar and the prompts of written
--- tests. It never raises.
---
---@param value any
---@return string?
function M.text_problem(value)
  if type(value) ~= 'string' then
    return 'expected a string'
  end
  for _, control in ipairs(CONTROLS) do
    if value:find(control) then
      return 'holds a control character'
    end
  end
  if not is_utf8(value) then
    return 'not valid UTF-8'
  end
  if vim.fn.strchars(value) > LONGEST_TEXT then
    return ('longer than %d characters'):format(LONGEST_TEXT)
  end
  return nil
end

--- Why the optional fields every statement may give — `kind`, a short
--- text (`text_problem()`), and `create`, true or false — are refused,
--- naming the field after `at`; nil when they are accepted.
---
---@param statement table
---@param at string
---@return string?
local function common_problem(statement, at)
  local kind_problem = statement.kind ~= nil and M.text_problem(statement.kind)
  if kind_problem then
    return at .. '.kind: ' .. kind_problem
  end
  if statement.create ~= nil and type(statement.create) ~= 'boolean' then
    return at .. '.create: expected true or false'
  end
  return nil
end

--- Why `statement`, which names a preset, is refused: a preset `catalogue`
--- does not have, or another field than its kind and `create`.
---
---@param statement table
---@param at string
---@param catalogue { presets: aineo.test_layout.Preset[] }
---@return string?
local function preset_problem(statement, at, catalogue)
  local known = vim.iter(catalogue.presets):any(function(preset)
    return preset.id == statement.preset
  end)
  if not known then
    return ('%s.preset: no preset %s'):format(at, tostring(statement.preset))
  end
  local unknown = unknown_field(statement, PRESET_FIELDS)
  if unknown then
    return ('%s.%s: not a field of a preset rule'):format(at, unknown)
  end
  return common_problem(statement, at)
end

--- Why `test`, the test templates of a rule whose source template is
--- `source`, are refused: no template and no non-empty list of them, or a
--- template refused (`aineo.test_layout.template`'s `problem()` and
--- `pair_problem()`), named by its position in a list.
---
---@param test any
---@param source string
---@param at string
---@return string?
local function tests_problem(test, source, at)
  local list = type(test) == 'string' and { test } or test
  if not is_string_list(list) then
    return at .. '.test: expected a template or a non-empty list of them'
  end
  for position, pattern in ipairs(list) do
    local field = type(test) == 'string' and at .. '.test' or ('%s.test[%d]'):format(at, position)
    local problem = template.problem(pattern) or template.pair_problem(source, pattern)
    if problem then
      return field .. ': ' .. problem
    end
  end
  return nil
end

--- Why `folder`, a rule's folder of tests, is refused: no folder ending in
--- `/`, a placeholder, or what `template.problem()` refuses.
---
---@param folder any
---@param at string
---@return string?
local function folder_problem(folder, at)
  if type(folder) ~= 'string' or not vim.endswith(folder, '/') then
    return at .. '.folder: expected a folder ending in /'
  end
  if folder:find('[{}]') then
    return at .. '.folder: a placeholder'
  end
  local problem = template.problem(folder:sub(1, -2))
  return problem and at .. '.folder: ' .. problem
end

--- Why the list `value`, a rule's `field`, is refused: no non-empty list
--- of strings, or an item `item_problem` refuses, named by its position.
---
---@param value any
---@param field string
---@param expected string what the list holds, in words
---@param item_problem fun(item: string): string?
---@return string?
local function list_problem(value, field, expected, item_problem)
  if value == nil then
    return nil
  end
  if not is_string_list(value) then
    return ('%s: expected a list of %s'):format(field, expected)
  end
  for position, item in ipairs(value) do
    local problem = item_problem(item)
    if problem then
      return ('%s[%d]: %s'):format(field, position, problem)
    end
  end
  return nil
end

--- The most `**` a discovery glob may hold: each more multiplies the time
--- `vim.glob` takes to match a path.
local MOST_DOUBLE_STARS = 2

--- The most brace groups a discovery glob may hold, and the most paths
--- their alternatives may spell together: `vim.glob` takes a time that
--- grows with each group to read a glob.
local MOST_BRACE_GROUPS = 4
local MOST_ALTERNATIVES = 64

--- How many paths the brace groups of `glob` spell together: the product
--- of each group's number of alternatives.
---
---@param glob string
---@return integer
local function alternatives_of(glob)
  local product = 1
  for group in glob:gmatch('{([^{}]*)}') do
    local _, commas = group:gsub(',', '')
    product = product * (commas + 1)
  end
  return product
end

--- Why `glob`, a discovery glob, is refused: more than 256 characters,
--- what `template.problem()` refuses of a path — an absolute one, a `..`
--- segment, a `~`, a control character — more than two `**`, more than four
--- brace groups or 64 alternatives, or a glob `vim.glob` cannot read; nil
--- when it is accepted. The limits come before `vim.glob` reads it.
---
---@param glob string
---@return string?
function M.glob_problem(glob)
  if #glob > LONGEST_GLOB then
    return ('longer than %d characters'):format(LONGEST_GLOB)
  end
  local problem = template.problem((glob:gsub('[{}]', '')))
  if problem then
    return problem
  end
  local _, double_stars = glob:gsub('%*%*', '')
  if double_stars > MOST_DOUBLE_STARS then
    return 'more than two **'
  end
  local _, brace_groups = glob:gsub('{', '')
  if brace_groups > MOST_BRACE_GROUPS then
    return 'more than four brace groups'
  end
  if alternatives_of(glob) > MOST_ALTERNATIVES then
    return ('more than %d alternatives'):format(MOST_ALTERNATIVES)
  end
  if not pcall(vim.glob.to_lpeg, glob) then
    return 'not a glob aineo can read'
  end
  return nil
end

--- Why `name`, a companion, is refused: it is no plain file name.
---
---@param name string
---@return string?
local function companion_problem(name)
  if name == '' or name == '.' or name == '..' or name:find('[/\\~]') then
    return 'expected a file name'
  end
  return nil
end

--- Why the shape of `statement`, a rule of its own, is refused: not one
--- and only one of `test`, `inline` and `folder`; or a `source` missing
--- where a folder rule does not stand without one.
---
---@param statement table
---@param at string
---@return string?
local function form_problem(statement, at)
  local forms = (statement.test ~= nil and 1 or 0)
    + (statement.inline ~= nil and 1 or 0)
    + (statement.folder ~= nil and 1 or 0)
  if forms ~= 1 then
    return at .. ': give one of test, inline and folder'
  end
  if statement.folder == nil and type(statement.source) ~= 'string' then
    return at .. '.source: expected a template'
  end
  return nil
end

--- Why `statement`, a rule of its own, is refused (A666): its form, its
--- source and test templates, `inline` other than true, its folder, its
--- discovery globs, its companions, its kind, `create` and framework, or
--- any other field.
---
---@param statement table
---@param at string
---@return string?
local function rule_problem(statement, at)
  local problem = form_problem(statement, at)
  if problem then
    return problem
  end
  if statement.source ~= nil then
    local source_problem = type(statement.source) ~= 'string' and 'expected a template'
      or template.problem(statement.source)
    if source_problem then
      return at .. '.source: ' .. source_problem
    end
  end
  if statement.test ~= nil then
    problem = tests_problem(statement.test, statement.source, at)
  elseif statement.inline ~= nil and statement.inline ~= true then
    problem = at .. '.inline: expected true'
  elseif statement.folder ~= nil then
    problem = folder_problem(statement.folder, at)
  end
  problem = problem
    or list_problem(statement.discover, at .. '.discover', 'globs', M.glob_problem)
    or list_problem(statement.companions, at .. '.companions', 'file names', companion_problem)
    or common_problem(statement, at)
  if problem then
    return problem
  end
  local framework_problem = statement.framework ~= nil and M.text_problem(statement.framework)
  if framework_problem then
    return at .. '.framework: ' .. framework_problem
  end
  local unknown = unknown_field(statement, RULE_FIELDS)
  return unknown and ('%s.%s: not a field of a rule'):format(at, unknown)
end

--- Why `statements`, the rules an agent states for a repository, are
--- refused, naming the field at fault, such as `rules[2].test: a ..
--- segment`; nil when every one is accepted. A statement is an object that
--- names a preset of `catalogue`, with its kind or `create` overridden, or
--- a rule of its own (A666); at most `MOST_RULES` of them.
---
---@param statements any
---@param catalogue { presets: aineo.test_layout.Preset[] }
---@return string?
function M.statements_problem(statements, catalogue)
  if type(statements) ~= 'table' or not vim.islist(statements) then
    return 'rules: expected a list of rules'
  end
  if #statements > M.MOST_RULES then
    return ('rules: more than %d rules'):format(M.MOST_RULES)
  end
  for position, statement in ipairs(statements) do
    local at = ('rules[%d]'):format(position)
    local problem
    if not is_object(statement) then
      problem = at .. ': expected an object'
    elseif statement.preset ~= nil then
      problem = preset_problem(statement, at, catalogue)
    else
      problem = rule_problem(statement, at)
    end
    if problem then
      return problem
    end
  end
  return nil
end

--- The rule `statement`, a rule of its own, states, with `origin` and
--- `description`; the fields of `defaults` fill those it does not give.
---
---@param statement aineo.test_layout.Statement
---@param origin 'user'|'agent'|'repository'|'preset'
---@param description string
---@param defaults? { discover?: string[], framework?: string, companions?: string[], extensions?: string[] }
---@return aineo.test_layout.Rule
function M.of_statement(statement, origin, description, defaults)
  defaults = defaults or {}
  local tests = statement.test
  if type(tests) == 'string' then
    tests = { tests }
  end
  return {
    source = statement.source,
    tests = tests,
    inline = statement.inline,
    folder = statement.folder,
    kind = statement.kind,
    create = statement.create,
    discover = statement.discover or defaults.discover,
    framework = statement.framework or defaults.framework,
    companions = statement.companions or defaults.companions,
    extensions = defaults.extensions,
    origin = origin,
    description = description,
  }
end

--- The rules of `preset`, in its order, each described by `description`
--- (the preset's id when not given) and with `origin`, `overrides` — a
--- kind, a `create` — given to each.
---
---@param preset aineo.test_layout.Preset
---@param origin 'user'|'agent'|'repository'|'preset'
---@param description? string
---@param overrides? { kind?: string, create?: boolean }
---@return aineo.test_layout.Rule[]
function M.of_preset(preset, origin, description, overrides)
  return vim.tbl_map(function(statement)
    local rule = M.of_statement(statement, origin, description or preset.id, {
      discover = preset.discover,
      framework = preset.framework,
      companions = preset.companions,
      extensions = preset.extensions,
    })
    return vim.tbl_extend('force', rule, overrides or {})
  end, preset.rules)
end

return M
