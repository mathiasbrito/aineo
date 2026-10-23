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
---     whole, `*` for any run of characters and `?` for any one character;
---   - `{ lua_pattern = '^make%s+test' }`: a Lua pattern, found anywhere in the
---     text, that Lua reads whole and that repeats (`*`, `+`, `-`) once at most
---     (`aineo.config`'s `lua_pattern_problem()`); any other matches nothing;
---   - a boolean or a number: it matches a value that is equal to it.
---
--- What a rule can cost, for a text of any length: only the first
--- `LONGEST_TEXT` bytes of a text are matched, and only the first
--- `LONGEST_TEXT_FOR_PATTERN` by a Lua pattern. Plain words and globs take a
--- time in proportion to the rule's length times the text's, a glob however
--- many stars it has. A Lua pattern of one repetition takes a few milliseconds
--- at most on its bytes, which Lua's matcher, written in C, cannot be stopped
--- from; that is why it may repeat once.

local config = require('aineo.config')

local M = {}

--- How many bytes of a text are matched.
M.LONGEST_TEXT = 4096

--- How many bytes of a text a Lua pattern is matched against: a pattern of
--- one repetition costs the square of them, and on 4096 bytes that is over 50
--- milliseconds.
M.LONGEST_TEXT_FOR_PATTERN = 1024

--- A rule that is a Lua pattern.
---@class aineo.office_states.PatternRule
---@field lua_pattern string

--- What a text can be matched against.
---@alias aineo.office_states.Rule string|boolean|number|aineo.office_states.PatternRule

local STAR = ('*'):byte()
local QUESTION_MARK = ('?'):byte()

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

--- How many bytes the character that starts at `at` takes: its first byte and
--- the continuation bytes of UTF-8 after it.
---
---@param text string
---@param at integer
---@return integer
local function character_length(text, at)
  local length = 1
  local following = text:byte(at + length)
  while following and following >= 0x80 and following < 0xC0 do
    length = length + 1
    following = text:byte(at + length)
  end
  return length
end

--- Whether the glob `glob` matches `text` as a whole. It remembers the last
--- `*` and, when the rest fails, lets it take one character more: the time is
--- at most the glob's length times the text's, whatever the stars.
---
---@param glob string
---@param text string
---@return boolean
local function glob_matches(glob, text)
  local glob_at, text_at = 1, 1
  local star_at, star_ends_at = nil, nil
  while text_at <= #text do
    local wanted = glob:byte(glob_at)
    if wanted == STAR then
      star_at, star_ends_at = glob_at, text_at
      glob_at = glob_at + 1
    elseif wanted == QUESTION_MARK then
      text_at = text_at + character_length(text, text_at)
      glob_at = glob_at + 1
    elseif wanted and wanted == text:byte(text_at) then
      text_at = text_at + 1
      glob_at = glob_at + 1
    elseif star_at then
      star_ends_at = star_ends_at + character_length(text, star_ends_at)
      glob_at, text_at = star_at + 1, star_ends_at
    else
      return false
    end
  end
  while glob:byte(glob_at) == STAR do
    glob_at = glob_at + 1
  end
  return glob_at > #glob
end

--- Whether a Lua pattern has a problem, by the pattern, remembered.
---@type table<string, boolean>
local has_problem = {}

--- Whether `text` matches the Lua pattern `pattern`. A pattern that Lua
--- cannot read whole or that repeats more than once matches nothing: the
--- setting and the pack's check refuse it by name, so the office does not
--- complain on every call.
---
---@param text string
---@param pattern string
---@return boolean
local function matches_pattern(text, pattern)
  if has_problem[pattern] == nil then
    has_problem[pattern] = config.lua_pattern_problem(pattern) ~= nil
  end
  if has_problem[pattern] then
    return false
  end
  local read, found = pcall(string.find, text:sub(1, M.LONGEST_TEXT_FOR_PATTERN), pattern)
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
    return glob_matches(rule, text)
  end
  return holds_whole_words(text, rule)
end

return M
