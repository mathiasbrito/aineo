--- The reader of a pack's `pack.lua`: a Lua table literal read as data and
--- never run. A pack is shared between people, so reading one can neither hang
--- the editor nor reach it: the text is scanned, character by character, for
--- the few things a description is made of, and anything else — a call, an
--- operator, a function, a name where a value goes — is refused with the line
--- it stands on.
---
--- What is read: `return` and a table; tables with named fields (`name = …`),
--- keys in brackets (`['*'] = …`) and list items, separated by `,` or `;`;
--- strings in single or double quotes with the escapes `\n \t \r \\ \" \'`,
--- and long strings (`[[ … ]]`); decimal numbers; `true` and `false`; and
--- comments, `--` to the end of a line and `--[[ … ]]` blocks. What is read
--- means what Lua would make of it: a list item beats a key of its number.

local long_bracket = require('aineo.office_pack.long_bracket')
local reader_module = require('aineo.office_pack.reader')

local M = {}

local refuse = reader_module.refuse
local current = reader_module.current
local advance = reader_module.advance

--- The longest text the reader reads.
local MAX_BYTES = 256 * 1024

--- How deep tables may nest.
local MAX_DEPTH = 32

local ESCAPES = { n = '\n', t = '\t', r = '\r', ['\\'] = '\\', ['"'] = '"', ["'"] = "'" }

---@class aineo.office_pack.LiteralReader : aineo.office_pack.Reader
---@field lines table<table, table<string|integer, integer>> the line each entry of each table starts on

--- Moves past white space and comments.
---
---@param reader aineo.office_pack.Reader
local function skip_blank(reader)
  while true do
    local character = current(reader)
    if character:match('%s') then
      advance(reader)
    elseif reader.text:sub(reader.position, reader.position + 1) == '--' then
      reader.position = reader.position + 2
      local level = long_bracket.level_at(reader)
      if level then
        long_bracket.read(reader, level, 'the comment is not closed')
      else
        while current(reader) ~= '' and current(reader) ~= '\n' do
          advance(reader)
        end
      end
    else
      return
    end
  end
end

--- The word of letters, digits and `_` the reader is at, moving past it; an
--- empty string when it is at none.
---
---@param reader aineo.office_pack.Reader
---@return string
local function read_word(reader)
  local word = reader.text:match('^[%a_][%w_]*', reader.position) or ''
  reader.position = reader.position + #word
  return word
end

--- Refuses what stands at the reader as a value that is not data.
---
---@param reader aineo.office_pack.Reader
local function refuse_value(reader)
  local character = current(reader)
  if character == '' then
    refuse(reader, 'a value is missing at the end of the text')
  end
  local word = reader.text:match('^[%a_][%w_]*', reader.position)
  refuse(reader, ('`%s` is not data'):format(word or character))
end

---@param reader aineo.office_pack.Reader
---@return string
local function read_string(reader)
  local quote = current(reader)
  local start_line = reader.line
  advance(reader)
  local characters = {}
  while current(reader) ~= quote do
    local character = current(reader)
    if character == '' or character == '\n' then
      reader.line = start_line
      refuse(reader, 'the string is not closed')
    end
    if character == '\\' then
      advance(reader)
      local escape = current(reader)
      if not ESCAPES[escape] then
        refuse(reader, ('`\\%s` is not an escape the reader knows'):format(escape))
      end
      character = ESCAPES[escape]
    end
    table.insert(characters, character)
    advance(reader)
  end
  advance(reader)
  return table.concat(characters)
end

--- Reads the long string the reader is at.
---
---@param reader aineo.office_pack.Reader
---@param level integer
---@return string
local function read_long_string(reader, level)
  return long_bracket.read(reader, level, 'the string is not closed')
end

--- Refuses a number that is not finite: the digits of more than 308 places
--- are not a number Lua reads, but infinity.
---
---@param reader aineo.office_pack.Reader
---@return number
local function read_number(reader)
  local text = reader.text:match('^-?%d+%.%d+', reader.position)
    or reader.text:match('^-?%d+', reader.position)
  local number = tonumber(text)
  if number == math.huge or number == -math.huge then
    refuse(reader, 'the number is too large')
  end
  reader.position = reader.position + #text
  return number
end

local read_value

--- Reads the key written in brackets, `['name'] =` or `[2] =`, moving past
--- the `=`.
---
---@param reader aineo.office_pack.Reader
---@return string|number key
local function read_bracketed_key(reader)
  advance(reader)
  skip_blank(reader)
  local character = current(reader)
  local key
  if character == '"' or character == "'" then
    key = read_string(reader)
  elseif character:match('%d') then
    key = read_number(reader)
  else
    refuse(reader, 'a key in brackets is a string or a number')
  end
  skip_blank(reader)
  if current(reader) ~= ']' then
    refuse(reader, 'a key in brackets ends with `]`')
  end
  advance(reader)
  skip_blank(reader)
  if current(reader) ~= '=' then
    refuse(reader, 'a key is followed by `=`')
  end
  advance(reader)
  return key
end

--- The name the reader is at when `=` follows it, moving past the `=`; `nil`,
--- and the reader where it was, when what stands there is a value.
---
---@param reader aineo.office_pack.Reader
---@return string|nil name
local function read_field_name(reader)
  local start_position, start_line = reader.position, reader.line
  local word = read_word(reader)
  skip_blank(reader)
  if
    word ~= ''
    and current(reader) == '='
    and reader.text:sub(reader.position + 1, reader.position + 1) ~= '='
  then
    advance(reader)
    return word
  end
  reader.position, reader.line = start_position, start_line
  return nil
end

--- Whether the reader is at the key of a field written in brackets, rather
--- than at a long string.
---
---@param reader aineo.office_pack.Reader
---@return boolean
local function is_at_bracketed_key(reader)
  return current(reader) == '[' and long_bracket.level_at(reader) == nil
end

--- Reads one entry of a table: a field, a field with its key in brackets,
--- or a list item. A field goes into `table_value`, a list item into `items`;
--- the line the entry starts on goes into `lines`.
---
---@param reader aineo.office_pack.LiteralReader
---@param table_value table
---@param items any[]
---@param depth integer
local function read_entry(reader, table_value, items, depth)
  local line = reader.line
  local key
  if is_at_bracketed_key(reader) then
    key = read_bracketed_key(reader)
  else
    key = read_field_name(reader)
  end
  skip_blank(reader)
  local value = read_value(reader, depth)
  if key ~= nil then
    table_value[key] = value
    reader.lines[table_value][key] = line
  else
    table.insert(items, value)
    reader.lines[table_value][#items] = line
  end
end

---@param reader aineo.office_pack.LiteralReader
---@param depth integer how many tables are open, this one included
---@return table
local function read_table(reader, depth)
  if depth > MAX_DEPTH then
    refuse(reader, 'tables are nested too deep')
  end
  advance(reader)
  local table_value = {}
  local items = {}
  reader.lines[table_value] = {}
  while true do
    skip_blank(reader)
    local character = current(reader)
    if character == '}' then
      advance(reader)
      for index, item in ipairs(items) do
        table_value[index] = item
      end
      return table_value
    end
    if character == '' then
      refuse(reader, 'the table is not closed')
    end
    read_entry(reader, table_value, items, depth)
    skip_blank(reader)
    local separator = current(reader)
    if separator == ',' or separator == ';' then
      advance(reader)
    elseif separator ~= '}' then
      refuse(
        reader,
        ('`%s` stands where `,` or `}` should'):format(separator == '' and 'the end' or separator)
      )
    end
  end
end

--- Reads the value the reader is at: a table, a string, a number, `true` or `false`.
---
---@param reader aineo.office_pack.LiteralReader
---@param depth integer how many tables are open
---@return any
function read_value(reader, depth)
  local character = current(reader)
  local long_string_level = long_bracket.level_at(reader)
  if character == '{' then
    return read_table(reader, depth + 1)
  elseif character == '"' or character == "'" then
    return read_string(reader)
  elseif long_string_level then
    return read_long_string(reader, long_string_level)
  elseif
    character:match('%d') or (character == '-' and reader.text:match('^-%d', reader.position))
  then
    return read_number(reader)
  end
  local word = reader.text:match('^[%a_][%w_]*', reader.position)
  if word == 'true' or word == 'false' then
    read_word(reader)
    return word == 'true'
  end
  return refuse_value(reader)
end

---@param reader aineo.office_pack.LiteralReader
---@return table
local function read_pack_text(reader)
  skip_blank(reader)
  if read_word(reader) ~= 'return' then
    refuse(reader, 'the text starts with `return`')
  end
  skip_blank(reader)
  local value = read_value(reader, 0)
  if type(value) ~= 'table' then
    refuse(reader, 'the text returns a table')
  end
  skip_blank(reader)
  if current(reader) ~= '' then
    refuse(reader, ('`%s` stands after the table'):format(current(reader)))
  end
  return value
end

--- Reads `text`, a Lua table literal, as data, and never runs it.
---
--- Gives the table, `nil` for the problem, and the line each entry of each
--- table starts on: `lines[table][key]`, a list item's key its index. Gives
--- `nil` and the problem instead — `line <n>: <what is wrong>` for text that
--- is not data, or a problem without a line for text over 256 KiB.
---
---@param text string
---@return table|nil value
---@return string|nil problem
---@return table<table, table<string|integer, integer>>|nil lines
function M.parse(text)
  if #text > MAX_BYTES then
    return nil, 'the text is longer than 256 KiB'
  end
  local reader = reader_module.new(text)
  reader.lines = {}
  local read, result = pcall(read_pack_text, reader)
  if read then
    return result, nil, reader.lines
  end
  if not result:match('^line %d+: ') then
    error(result, 0)
  end
  return nil, result
end

return M
