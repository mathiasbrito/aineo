--- The web links in a line of the Report: where each starts and ends, and
--- the address it opens. Finding them takes time that grows with the length
--- of the line, not with its square: a report can be as long as a line the
--- relay takes.

local M = {}

---@class aineo.report.WebLink
---@field first_column integer the byte it starts at, from 0
---@field end_column integer the byte it ends before, from 0
---@field url string its text

--- The scheme a link starts with, in any case.
local SCHEME = '[Hh][Tt][Tt][Pp][Ss]?://'

--- The ASCII characters that end a link: a space, an ASCII control
--- character (U+0000–U+001F, U+007F, the tab and the line breaks among them),
--- `<`, `>`, `"`, `|` or a backtick. Spelled out byte by byte, since `%s` and
--- `%c` follow the C locale's classes, which may not be ASCII's.
local STOP = '[%z\1-\32\127<>"|`]'

--- Whether each ASCII byte ends a link (`STOP`), by byte.
local STOP_BYTES = {}
for byte = 0, 127 do
  STOP_BYTES[byte] = string.char(byte):find(STOP) ~= nil
end

--- A C1 control character (U+0080–U+009F) in UTF-8 is the lead byte
--- `C1_LEAD` followed by a byte of 0x80 up to `C1_LAST`.
local C1_LEAD, C1_LAST = 194, 159

--- The characters a link never ends in: punctuation that closes the
--- sentence or the emphasis around it. A `"` never reaches the end of a
--- link: it ends the run (`STOP`).
local TRAILING_PUNCTUATION = "[.,;:!?'*~]"

--- Each closing bracket, by the opening bracket it pairs with.
local OPENING_BRACKETS = { [')'] = '(', [']'] = '[', ['}'] = '{' }

--- How many times `character` occurs in `text`, read as itself, never as a
--- pattern.
---
---@param text string
---@param character string
---@return integer
local function count_of(text, character)
  local _, count = text:gsub(vim.pesc(character), '')
  return count
end

--- `candidate` without the characters at its end that a link never ends in,
--- left out one after another until it ends in none: trailing punctuation
--- (`TRAILING_PUNCTUATION`), or a closing bracket with no opening partner in
--- what is left. Each bracket is counted once, so the time taken grows with
--- the length of `candidate`, not with its square.
---
---@param candidate string
---@return string
local function without_trailing_characters(candidate)
  local unpaired = {}
  for closing, opening in pairs(OPENING_BRACKETS) do
    unpaired[closing] = count_of(candidate, closing) - count_of(candidate, opening)
  end
  local last = #candidate
  while last > 0 do
    local character = candidate:sub(last, last)
    if character:find(TRAILING_PUNCTUATION) then
      last = last - 1
    elseif (unpaired[character] or 0) > 0 then
      unpaired[character] = unpaired[character] - 1
      last = last - 1
    else
      break
    end
  end
  return candidate:sub(1, last)
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

--- How many bytes a well-formed UTF-8 character starting with `lead` takes,
--- and the range its second byte must fall in (Unicode, Table 3-7), or nil
--- when no well-formed character starts with `lead`: a continuation byte,
--- `0xC0`, `0xC1` or `0xF5` and above.
---
---@param lead integer
---@return integer? length
---@return integer? second_low
---@return integer? second_high
local function sequence_of(lead)
  if lead < 0x80 then
    return 1
  elseif lead >= 0xC2 and lead <= 0xDF then
    return 2, 0x80, 0xBF
  elseif lead == 0xE0 then
    return 3, 0xA0, 0xBF
  elseif lead == 0xED then
    return 3, 0x80, 0x9F
  elseif lead >= 0xE1 and lead <= 0xEF then
    return 3, 0x80, 0xBF
  elseif lead == 0xF0 then
    return 4, 0x90, 0xBF
  elseif lead >= 0xF1 and lead <= 0xF3 then
    return 4, 0x80, 0xBF
  elseif lead == 0xF4 then
    return 4, 0x80, 0x8F
  end
  return nil
end

--- How many bytes the well-formed UTF-8 character at byte `position` of
--- `text` takes, or nil when the bytes there are not one: a lone
--- continuation byte, a raw C1 byte, a sequence cut short, an overlong form,
--- a surrogate, or a code point past U+10FFFF.
---
---@param text string
---@param position integer
---@return integer?
local function character_length(text, position)
  local length, second_low, second_high = sequence_of(text:byte(position))
  if length == nil or length == 1 then
    return length
  end
  local second = text:byte(position + 1)
  if second == nil or second < second_low or second > second_high then
    return nil
  end
  for offset = 2, length - 1 do
    local continuation = text:byte(position + offset)
    if continuation == nil or continuation < 0x80 or continuation > 0xBF then
      return nil
    end
  end
  return length
end

--- Whether the well-formed character of `length` bytes at byte `position` of
--- `text` ends a link: an ASCII one of `STOP`, or a C1 control character.
---
---@param text string
---@param position integer
---@param length integer
---@return boolean
local function ends_run(text, position, length)
  local byte = text:byte(position)
  if length == 1 then
    return STOP_BYTES[byte]
  end
  return length == 2 and byte == C1_LEAD and text:byte(position + 1) <= C1_LAST
end

--- The last byte of the run a link could cover after its scheme, which ends
--- at byte `scheme_end` of `text`: up to the first character that ends a
--- link (`ends_run()`) or the first byte that is not part of a well-formed
--- UTF-8 character (`character_length()`), or the end of `text`.
---
---@param text string
---@param scheme_end integer
---@return integer
local function run_end(text, scheme_end)
  local position = scheme_end + 1
  while position <= #text do
    local length = character_length(text, position)
    if length == nil or ends_run(text, position, length) then
      break
    end
    position = position + length
  end
  return position - 1
end

--- Every web link in `text`, in order. A link starts with `http://` or
--- `https://`, the scheme in any case, at the start of `text` or after a
--- character that is not an ASCII letter or digit (`may_start_link()`); it
--- runs up to an ASCII space, a control character, `<`, `>`, `"`, `|`, a
--- backtick or a byte that is not part of well-formed UTF-8 (`run_end()`), so
--- its url never holds a control character or such a byte; it leaves out the punctuation and unpaired
--- closing brackets at its end (`without_trailing_characters()`). What is
--- left must hold at least one character after the `://`. Links never
--- overlap: the search goes on after each link's end.
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
    local url = may_start_link(text, first)
      and without_trailing_characters(text:sub(first, run_end(text, scheme_end)))
    if url and #url > scheme_end - first + 1 then
      table.insert(links, { first_column = first - 1, end_column = first - 1 + #url, url = url })
      position = first + #url
    else
      position = first + 1
    end
  end
end

return M
