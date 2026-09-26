--- The web links in a line of the Report: where each starts and ends, and
--- the address it opens.

local M = {}

---@class aineo.report.WebLink
---@field first_column integer the byte it starts at, from 0
---@field end_column integer the byte it ends before, from 0
---@field url string its text

--- The scheme a link starts with, in any case.
local SCHEME = '[Hh][Tt][Tt][Pp][Ss]?://'

--- The characters a link runs over after its scheme: up to a space, an ASCII
--- control character (U+0000–U+001F, U+007F, the tab and the line breaks
--- among them), `<`, `>`, `"`, `|` or a backtick. Spelled out byte by byte,
--- since `%s` and `%c` follow the C locale's classes, which may not be
--- ASCII's.
local RUN = '^[^%z\1-\32\127<>"|`]*'

--- A C1 control character (U+0080–U+009F) in UTF-8, which also ends a link.
local C1_CONTROL = '\194[\128-\159]'

--- The characters a link never ends in: punctuation that closes the
--- sentence or the emphasis around it.
local TRAILING_PUNCTUATION = '[.,;:!?\'"*~]$'

--- Each closing bracket, by the opening bracket it pairs with.
local OPENING_BRACKETS = { [')'] = '(', [']'] = '[', ['}'] = '{' }

--- How many times the single character `character` occurs in `text`.
---
---@param text string
---@param character string
---@return integer
local function count_of(text, character)
  local _, count = text:gsub('%' .. character, '')
  return count
end

--- Whether `candidate` ends in a character a link never ends in: trailing
--- punctuation (`TRAILING_PUNCTUATION`), or a closing bracket with no opening
--- partner inside it.
---
---@param candidate string
---@return boolean
local function ends_outside_link(candidate)
  if candidate:find(TRAILING_PUNCTUATION) then
    return true
  end
  local closing = candidate:sub(-1)
  local opening = OPENING_BRACKETS[closing]
  return opening ~= nil and count_of(candidate, opening) < count_of(candidate, closing)
end

--- `candidate` without the characters at its end that a link never ends in
--- (`ends_outside_link()`), left out one after another until it ends in none.
---
---@param candidate string
---@return string
local function without_trailing_characters(candidate)
  while ends_outside_link(candidate) do
    candidate = candidate:sub(1, -2)
  end
  return candidate
end

--- Whether a link may start at byte `first` of `text`: at its start, or
--- after a character that is not an ASCII letter or digit.
---
---@param text string
---@param first integer
---@return boolean
local function may_start_link(text, first)
  return first == 1 or not text:sub(first - 1, first - 1):find('[0-9A-Za-z]')
end

--- The text a link starting at byte `first` of `text` could run over, its
--- scheme ending at byte `scheme_end`: the scheme and `RUN` after it, up to
--- any C1 control character (`C1_CONTROL`).
---
---@param text string
---@param first integer
---@param scheme_end integer
---@return string
local function candidate_at(text, first, scheme_end)
  local run = text:sub(scheme_end + 1):match(RUN)
  local before_control = run:find(C1_CONTROL)
  if before_control then
    run = run:sub(1, before_control - 1)
  end
  return text:sub(first, scheme_end) .. run
end

--- Every web link in `text`, in order. A link starts with `http://` or
--- `https://`, the scheme in any case, at the start of `text` or after a
--- character that is not an ASCII letter or digit (`may_start_link()`); it
--- runs up to a space, a control character, `<`, `>`, `"`, `|` or a backtick
--- (`candidate_at()`), and leaves out the punctuation and unpaired closing
--- brackets at its end (`without_trailing_characters()`). What is left must
--- hold at least one character after the `://`. Links never overlap: the
--- search goes on after each link's end.
---
---@param text string one line of text
---@return aineo.report.WebLink[]
function M.find_web_links(text)
  local links = {}
  local position = 1
  while true do
    local first, scheme_end = text:find(SCHEME, position)
    if not first then
      return links
    end
    local url = without_trailing_characters(candidate_at(text, first, scheme_end))
    if may_start_link(text, first) and #url > scheme_end - first + 1 then
      table.insert(links, { first_column = first - 1, end_column = first - 1 + #url, url = url })
      position = first + #url
    else
      position = first + 1
    end
  end
end

return M
