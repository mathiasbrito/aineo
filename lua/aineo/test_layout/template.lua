--- The template engine of test layouts: a template is a path with
--- placeholders, such as `tests/{path}/test_{name}.py`; a source template
--- matched against a path binds its placeholders, and a test template is
--- rendered from those bindings.
---
--- A placeholder is a word in braces. `{path}` stands for one or more
--- folders, and for none when a `/` follows it (the slash then goes with
--- it); every other word, `{name}` and `{ext}` among them, for one segment.
--- A word may carry a modifier after `|`: `{path|_}` joins the folders with
--- `_`, `{name|-_}` turns each `-` into `_`; a modified placeholder stands
--- for one segment. Nothing is re-cased.

local M = {}

--- The placeholders that stand for one or more folders; every other one
--- stands for one segment of a path. `{unit}`, the folder of the unit a
--- path belongs to, begins a template only.
local SEVERAL_SEGMENTS = { path = true, unit = true }

--- The longest template, in characters.
local LONGEST_TEMPLATE = 256

--- What each modifier does to the value of the placeholder it follows.
---@type table<string, fun(value: string): string>
local MODIFIERS = {
  ['_'] = function(value)
    return (value:gsub('/', '_'))
  end,
  ['-_'] = function(value)
    return (value:gsub('%-', '_'))
  end,
}

--- One piece of a parsed template: a literal text, or a placeholder.
---@class aineo.test_layout.Piece
---@field text? string the literal text, for a literal piece
---@field word? string the placeholder's whole word, its modifier included, for a placeholder
---@field name? string the placeholder's word without its modifier
---@field modifier? string the placeholder's modifier, `''` for none
---@field folders? boolean whether the placeholder takes the `/` after it: it then stands for folders, each with its slash, or for nothing

--- `pieces` with each unmodified placeholder of several segments that a
--- `/` follows taking that slash (`folders`), so that it may stand for no
--- folder.
---
---@param pieces aineo.test_layout.Piece[]
---@return aineo.test_layout.Piece[]
local function with_folders(pieces)
  for index, piece in ipairs(pieces) do
    local after = pieces[index + 1]
    local several = SEVERAL_SEGMENTS[piece.name] and piece.modifier == ''
    if several and after and after.text and vim.startswith(after.text, '/') then
      piece.folders = true
      after.text = after.text:sub(2)
    end
  end
  return vim.tbl_filter(function(piece)
    return piece.text ~= ''
  end, pieces)
end

--- The pieces of `template`, in order.
---
---@param template string
---@return aineo.test_layout.Piece[]
local function pieces_of(template)
  local pieces = {}
  local position = 1
  while position <= #template do
    local open, close, word = template:find('{([^{}]*)}', position)
    if not open then
      table.insert(pieces, { text = template:sub(position) })
      break
    end
    if open > position then
      table.insert(pieces, { text = template:sub(position, open - 1) })
    end
    local name, modifier = word:match('^([^|]*)|?(.*)$')
    table.insert(pieces, { word = word, name = name, modifier = modifier })
    position = close + 1
  end
  return with_folders(pieces)
end

--- Whether `value` can stand for the placeholder `piece`: one segment, or,
--- for an unmodified placeholder of several (`SEVERAL_SEGMENTS`), segments
--- joined by `/`, none of them empty; nothing at all when it takes the
--- slash after it.
---
---@param piece aineo.test_layout.Piece
---@param value string
---@return boolean
local function can_stand_for(piece, value)
  if piece.folders and value == '' then
    return true
  end
  if SEVERAL_SEGMENTS[piece.name] and piece.modifier == '' then
    return value ~= ''
      and not value:find('//', 1, true)
      and not vim.startswith(value, '/')
      and not vim.endswith(value, '/')
  end
  return value ~= '' and not value:find('/', 1, true)
end

--- The value `piece`, a placeholder, already has under `bindings`: its own
--- word's, or, for a modified one, the modified value of its plain word;
--- nil when it has none yet.
---
---@param piece aineo.test_layout.Piece
---@param bindings table<string, string>
---@return string?
local function bound_value(piece, bindings)
  local plain = bindings[piece.name]
  if piece.modifier ~= '' and plain and MODIFIERS[piece.modifier] then
    return MODIFIERS[piece.modifier](plain)
  end
  return bindings[piece.word]
end

--- The value a placeholder that takes the slash after it (`folders`) has
--- for `text`, the part of a path it spans: nothing for no text, the
--- folders without their last slash, or nil when `text` does not end with
--- one.
---
---@param text string
---@return string?
local function folders_value(text)
  if text == '' then
    return ''
  end
  return vim.endswith(text, '/') and text:sub(1, -2) or nil
end

--- The bindings that make `pieces`, from the `index`th on, spell `path`
--- from its byte `at` on, extending `bindings`; nil when none do. A
--- placeholder tries its longest text first.
---
---@param pieces aineo.test_layout.Piece[]
---@param index integer
---@param path string
---@param at integer
---@param bindings table<string, string>
---@return table<string, string>?
local function match_from(pieces, index, path, at, bindings)
  local piece = pieces[index]
  if not piece then
    return at == #path + 1 and bindings or nil
  end
  if piece.text then
    if path:sub(at, at + #piece.text - 1) ~= piece.text then
      return nil
    end
    return match_from(pieces, index + 1, path, at + #piece.text, bindings)
  end
  local bound = bound_value(piece, bindings)
  for stop = #path, at - 1, -1 do
    local value = path:sub(at, stop)
    if piece.folders then
      value = folders_value(value)
    end
    if value and can_stand_for(piece, value) and (bound == nil or bound == value) then
      local extended = vim.tbl_extend('force', bindings, { [piece.word] = value })
      local matched = match_from(pieces, index + 1, path, stop + 1, extended)
      if matched then
        return matched
      end
    end
  end
  return nil
end

--- The text `piece`, a placeholder, stands for under `bindings`: its
--- plain word's value, modified by its modifier, with the slash it takes
--- when it stands for folders and there are some; the placeholder as
--- written when it has no value.
---
---@param piece aineo.test_layout.Piece
---@param bindings table<string, string>
---@return string
local function rendered_placeholder(piece, bindings)
  local value = bound_value(piece, bindings) or bindings[piece.name]
  if value == nil then
    return '{' .. piece.word .. '}' .. (piece.folders and '/' or '')
  end
  if piece.folders and value ~= '' then
    return value .. '/'
  end
  return value
end

--- Why the text of `template` outside its placeholders is refused: a `..`
--- segment, an absolute path, a `~`, a backslash, an empty segment or a
--- brace that opens or closes no placeholder; nil when it is accepted.
---
---@param template string
---@return string?
local function path_problem(template)
  if vim.startswith(template, '/') then
    return 'an absolute path'
  end
  for _, segment in ipairs(vim.split(template, '/', { plain = true })) do
    if segment == '..' then
      return 'a .. segment'
    end
  end
  if template:find('~', 1, true) then
    return 'a ~'
  end
  if template:find('\\', 1, true) then
    return 'a backslash'
  end
  if template:find('//', 1, true) then
    return 'an empty segment'
  end
  if template:gsub('{[^{}]*}', ''):find('[{}]') then
    return 'an unclosed brace'
  end
  return nil
end

--- Why a placeholder of `template` is refused: an empty one, an unknown
--- modifier, or a `{unit}` anywhere but at the start; nil when none is.
---
---@param template string
---@return string?
local function placeholder_problem(template)
  for index, piece in ipairs(pieces_of(template)) do
    if piece.word and piece.name == '' then
      return 'an empty placeholder'
    end
    if piece.word and piece.modifier ~= '' and not MODIFIERS[piece.modifier] then
      return 'an unknown modifier |' .. piece.modifier
    end
    if piece.name == 'unit' and index ~= 1 then
      return '{unit} only begins a template'
    end
  end
  return nil
end

--- Why `template` is refused, in words, or nil when it is accepted: it is
--- empty, longer than 256 characters, could reach out of the repository —
--- an absolute path, a `..` segment, a `~` — uses another separator than
--- `/`, has an empty segment, a brace of no placeholder, an empty
--- placeholder or an unknown modifier, or a `{unit}` that does not begin
--- it.
---
---@param template string
---@return string?
function M.problem(template)
  if template == '' then
    return 'empty'
  end
  if #template > LONGEST_TEMPLATE then
    return ('longer than %d characters'):format(LONGEST_TEMPLATE)
  end
  return path_problem(template) or placeholder_problem(template)
end

--- The plain words of the placeholders of `template`, as a set.
---
---@param template string
---@return table<string, true>
local function plain_words(template)
  local words = {}
  for _, piece in ipairs(pieces_of(template)) do
    if piece.name then
      words[piece.name] = true
    end
  end
  return words
end

--- Why `test`, a test template, cannot be rendered from what `source`, a
--- source template, binds: it names a placeholder `source` lacks, `{unit}`
--- aside, which every path has; nil when it can.
---
---@param source string
---@param test string
---@return string?
function M.pair_problem(source, test)
  local bound = plain_words(source)
  local lacking = vim.tbl_filter(function(word)
    return word ~= 'unit' and not bound[word]
  end, vim.tbl_keys(plain_words(test)))
  table.sort(lacking)
  return lacking[1] and ('{%s} is not in the source template'):format(lacking[1])
end

--- Whether a path `source` matches can be found again from the path
--- `test` renders: `test` holds every placeholder of `source` unmodified,
--- so that matching `test` binds them all. A pair that is not two-way is
--- used from source to test only.
---
---@param source string
---@param test string
---@return boolean
function M.is_two_way(source, test)
  local kept = {}
  for _, piece in ipairs(pieces_of(test)) do
    if piece.word and piece.modifier == '' then
      kept[piece.name] = true
    end
  end
  for word in pairs(plain_words(source)) do
    if not kept[word] and word ~= 'unit' then
      return false
    end
  end
  return true
end

--- The bindings `template` gives `path` when it matches it whole, or nil:
--- each placeholder's whole word, its modifier included, to the text it
--- stands for. A placeholder `bound` gives a value matches that value only,
--- and keeps it in the bindings.
---
---@param template string
---@param path string
---@param bound? table<string, string>
---@return table<string, string>?
function M.match(template, path, bound)
  return match_from(pieces_of(template), 1, path, 1, bound or {})
end

--- `template` with each placeholder replaced by its value in `bindings`; a
--- placeholder `bindings` gives no value is left as written, so that a
--- path rendered from too few bindings never names an existing file.
---
---@param template string
---@param bindings table<string, string>
---@return string
function M.render(template, bindings)
  return (
    table.concat(vim.tbl_map(function(piece)
      return piece.text or rendered_placeholder(piece, bindings)
    end, pieces_of(template)))
  )
end

--- The path `to` gives for `path` when `from` matches it, or nil when it
--- does not: the source template and test template of a rule, or the
--- reverse; `bound` as `match()` takes it.
---
---@param from string
---@param to string
---@param path string
---@param bound? table<string, string>
---@return string?
function M.translate(from, to, path, bound)
  local bindings = M.match(from, path, bound)
  return bindings and M.render(to, bindings)
end

return M
