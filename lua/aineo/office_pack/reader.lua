--- The position of the literal reader in a text: the character it is at and
--- the line that character is on, and the one way it stops, a refusal naming
--- that line. Counterpart of `literal.lua`, which reads with it.

local M = {}

--- Where the reader is in the text.
---@class aineo.office_pack.Reader
---@field text string
---@field position integer the next character to read, from 1
---@field line integer the line that character is on

--- A reader at the start of `text`.
---
---@param text string
---@return aineo.office_pack.Reader
function M.new(text)
  return { text = text, position = 1, line = 1 }
end

--- The character the reader is at, or an empty string at the end of the text.
---
---@param reader aineo.office_pack.Reader
---@return string
function M.current(reader)
  return reader.text:sub(reader.position, reader.position)
end

--- Moves the reader past the character it is at.
---
---@param reader aineo.office_pack.Reader
function M.advance(reader)
  if M.current(reader) == '\n' then
    reader.line = reader.line + 1
  end
  reader.position = reader.position + 1
end

--- Moves the reader to `position`, further along the text, counting the
--- lines it passes.
---
---@param reader aineo.office_pack.Reader
---@param position integer
function M.advance_to(reader, position)
  local passed = reader.text:sub(reader.position, position - 1)
  reader.line = reader.line + select(2, passed:gsub('\n', ''))
  reader.position = position
end

--- Stops the reading with a problem at the reader's line, raised as the text
--- `line <n>: <message>`. Caught by `literal.parse()`.
---
---@param reader aineo.office_pack.Reader
---@param message string
function M.refuse(reader, message)
  error(('line %d: %s'):format(reader.line, message), 0)
end

return M
