--- aineo's configuration home, `require('aineo.config')`. Pure: it reads no
--- editor state, and is handed every source of settings it resolves.

local M = {}

--- Whether `value` is a prefix: a string, or `false` for no prefix at all.
---
---@param value any
---@return boolean
local function is_prefix(value)
  return type(value) == 'string' or value == false
end

--- Whether `value` is a command: a list of at least one string.
---
---@param value any
---@return boolean
local function is_command(value)
  return vim.islist(value)
    and #value > 0
    and vim.iter(value):all(function(word)
      return type(word) == 'string'
    end)
end

--- Whether `value` is a share of the screen: a number strictly between 0 and 1.
---
---@param value any
---@return boolean
local function is_share(value)
  return type(value) == 'number' and value > 0 and value < 1
end

--- aineo's settings, each named by its path in `vim.g.aineo`, with its
--- default and the check its value must pass (`vim.validate`'s validator and,
--- for a function, the words that describe what it expects).
local SETTINGS = {
  { name = 'prefix', default = '\\', validator = is_prefix, expected = 'a string, or false' },
  { name = 'autostart', default = true, validator = 'boolean' },
  {
    name = 'claude.cmd',
    default = { 'claude' },
    validator = is_command,
    expected = 'a list of at least one string',
  },
  {
    name = 'layout.report_height',
    default = 2 / 3,
    validator = is_share,
    expected = 'a number strictly between 0 and 1',
  },
}

--- The keys leading to a setting, from the outermost table inwards.
---
---@param name string a setting's name, such as `claude.cmd`
---@return string[]
local function path_of(name)
  return vim.split(name, '.', { plain = true })
end

--- The tables that group `settings`, such as `claude`, each named once, in
--- the order the settings first name them.
---
---@param settings { name: string }[]
---@return string[]
local function sections_of(settings)
  local sections, named = {}, {}
  for _, setting in ipairs(settings) do
    local path = path_of(setting.name)
    if #path > 1 and not named[path[1]] then
      named[path[1]] = true
      table.insert(sections, path[1])
    end
  end
  return sections
end

local SECTIONS = sections_of(SETTINGS)

--- Whether a full path, such as `claude.cmd`, names a setting.
local IS_SETTING = {}
for _, setting in ipairs(SETTINGS) do
  IS_SETTING[setting.name] = true
end

--- Whether a top-level key, such as `claude`, names a section.
local IS_SECTION = {}
for _, section in ipairs(SECTIONS) do
  IS_SECTION[section] = true
end

--- The full paths of the keys in `source` that no setting knows — a section's
--- own keys included, as `claude.command`. Expects every section in `source`
--- to be a table.
---
---@param source table
---@return string[]
local function unknown_keys_in(source)
  local unknown = {}
  for key, value in pairs(source) do
    if IS_SECTION[key] then
      for inner_key in pairs(value) do
        local name = key .. '.' .. tostring(inner_key)
        if not IS_SETTING[name] then
          table.insert(unknown, name)
        end
      end
    elseif not IS_SETTING[key] then
      table.insert(unknown, tostring(key))
    end
  end
  return unknown
end

--- The full paths of the keys no setting knows across `sources`, each named
--- once, in sorted order.
---
---@param sources table[]
---@return string[]
local function unknown_keys_across(sources)
  local named = {}
  for _, source in ipairs(sources) do
    for _, key in ipairs(unknown_keys_in(source)) do
      named[key] = true
    end
  end
  local unknown = vim.tbl_keys(named)
  table.sort(unknown)
  return unknown
end

--- The value `source` holds for the setting named `name`, if any.
---
---@param source table
---@param name string
---@return any
local function value_in(source, name)
  return vim.tbl_get(source, unpack(path_of(name)))
end

--- Checks every value `source` gives: the source itself and each section must
--- be tables, and each setting must pass its check. `false` counts as given.
--- Raises an error naming the offending value's full path.
---
---@param source_name string how an error names the source itself
---@param source any
local function check_source(source_name, source)
  vim.validate(source_name, source, 'table', true)
  if source == nil then
    return
  end
  for _, section in ipairs(SECTIONS) do
    vim.validate(section, source[section], 'table', true)
  end
  for _, setting in ipairs(SETTINGS) do
    vim.validate(
      setting.name,
      value_in(source, setting.name),
      setting.validator,
      true,
      setting.expected
    )
  end
end

--- Puts `value` into `config` at the setting named `name`, creating the
--- enclosing tables it needs.
---
---@param config table
---@param name string
---@param value any
local function put(config, name, value)
  local path = path_of(name)
  local parent = config
  for depth = 1, #path - 1 do
    parent[path[depth]] = parent[path[depth]] or {}
    parent = parent[path[depth]]
  end
  parent[path[#path]] = value
end

--- The value of `setting` from the first of `sources` that gives one — `false`
--- included — or its default when none does.
---
---@param setting { name: string, default: any }
---@param sources table[] the sources, the one that wins first
---@return any
local function resolve_setting(setting, sources)
  for _, source in ipairs(sources) do
    local value = value_in(source, setting.name)
    if value ~= nil then
      return value
    end
  end
  return setting.default
end

--- Resolves aineo's configuration from its two sources: each setting comes from
--- the `setup()` options, else from `vim.g.aineo`, else from its default —
--- `false` counts as given. The result shares no table with the sources or the
--- defaults.
---
--- Raises an error naming the full path of the first wrong value either source
--- gives — `claude.cmd`, never `cmd` — even when the other source overrides it.
--- A key no setting knows is no error: it is returned.
---
---@param global_settings? table the value of `vim.g.aineo`
---@param setup_options? table the options `require('aineo').setup()` recorded
---@return table config every setting, shaped as `vim.g.aineo`
---@return string[] unknown_keys the full paths of the keys no setting knows, each once, sorted
function M.resolve_config(global_settings, setup_options)
  check_source('vim.g.aineo', global_settings)
  check_source('setup_options', setup_options)
  local sources = { setup_options or {}, global_settings or {} }
  local config = {}
  for _, setting in ipairs(SETTINGS) do
    put(config, setting.name, vim.deepcopy(resolve_setting(setting, sources)))
  end
  return config, unknown_keys_across(sources)
end

return M
