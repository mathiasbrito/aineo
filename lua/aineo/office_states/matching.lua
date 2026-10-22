--- The one rule by which the office matches a text against what a user or a
--- pack wrote: the classes of commands (`office.commands`) and a pack's
--- triggers. Pure.
---
--- A rule is
---   - plain words, `'docker'` or `'make test'`: they match a text that holds
---     them as whole words, in that order, however the text spaces them
---     (`'docker'` matches `sudo docker compose up`, not `dockerfile`; a letter,
---     a digit and `_` are what a word is made of);
---   - a glob, a string with a `*` or a `?` in it: it matches a text as a
---     whole, `*` for any run of characters and `?` for any one;
---   - `{ lua_pattern = '^make%s+test' }`: a Lua pattern, found anywhere in the
---     text;
---   - a boolean or a number: it matches a value that is equal to it.
---
--- Only the first `LONGEST_TEXT` bytes of a text are matched, so that a
--- pattern cannot be made to run long by a long command.

local M = {}

--- How many bytes of a text are matched.
M.LONGEST_TEXT = 4096

--- A rule that is a Lua pattern.
---@class aineo.office_states.PatternRule
---@field lua_pattern string

--- What a text can be matched against.
---@alias aineo.office_states.Rule string|boolean|number|aineo.office_states.PatternRule

--- The first `LONGEST_TEXT` bytes of `text`.
---
---@param text string
---@return string
function M.shortened(text)
  return text:sub(1, M.LONGEST_TEXT)
end

--- `text` with every run of white space made one space.
---
---@param text string
---@return string
local function with_single_spaces(text)
  return (text:gsub('%s+', ' '))
end

--- Whether `character` is part of a word: a letter, a digit or `_`.
---
---@param character string a single character, or '' past an end
---@return boolean
local function is_word_character(character)
  return character:find('^[%w_]') ~= nil
end

--- Whether `text` holds `words` as whole words: with no word character
--- joined to the first or last of them.
---
---@param text string
---@param words string
---@return boolean
local function holds_whole_words(text, words)
  local wanted = with_single_spaces(words)
  local spaced = with_single_spaces(text)
  local from = 1
  while wanted ~= '' do
    local first, last = spaced:find(wanted, from, true)
    if not first then
      return false
    end
    local joined_before = is_word_character(spaced:sub(first - 1, first - 1))
      and is_word_character(wanted:sub(1, 1))
    local joined_after = is_word_character(spaced:sub(last + 1, last + 1))
      and is_word_character(wanted:sub(-1))
    if not joined_before and not joined_after then
      return true
    end
    from = first + 1
  end
  return false
end

--- The Lua pattern that matches exactly what `glob` matches.
---
---@param glob string
---@return string pattern
local function pattern_of_glob(glob)
  local pattern = glob:gsub('.', function(character)
    if character == '*' then
      return '.*'
    elseif character == '?' then
      return '.'
    end
    return (character:gsub('%p', '%%%0'))
  end)
  return '^' .. pattern .. '$'
end

--- Whether `text` matches the Lua pattern `pattern`. A pattern Lua cannot
--- read matches nothing: the pack's check names it, so the office does not
--- complain on every call.
---
---@param text string
---@param pattern string
---@return boolean
local function matches_pattern(text, pattern)
  local read, found = pcall(string.find, text, pattern)
  return read and found ~= nil
end

--- Whether `value` matches `rule`.
---
---@param rule aineo.office_states.Rule
---@param value any the text or value to match; a text is matched by its first `LONGEST_TEXT` bytes
---@return boolean
function M.matches(rule, value)
  if type(rule) == 'table' then
    return type(rule.lua_pattern) == 'string'
      and type(value) == 'string'
      and matches_pattern(M.shortened(value), rule.lua_pattern)
  end
  if type(rule) ~= 'string' then
    return rule == value
  end
  if type(value) ~= 'string' then
    return false
  end
  local text = M.shortened(value)
  if rule:find('[*?]') then
    return text:find(pattern_of_glob(rule)) ~= nil
  end
  return holds_whole_words(text, rule)
end

return M
