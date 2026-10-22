--- Long brackets, as Lua reads them: `[[ … ]]`, and `[==[ … ]==]` with as many
--- `=` as the opening has. A long string is the text between them; a block
--- comment is `--` before them. Counterpart of `literal.lua`.

local reader_module = require('aineo.office_pack.reader')

local M = {}

--- The level of the long bracket the reader is at: how many `=` its opening
--- has, `[[` being level 0; `nil` when the reader is at none.
---
---@param reader aineo.office_pack.Reader
---@return integer|nil level
function M.level_at(reader)
  local equals = reader.text:match('^%[(=*)%[', reader.position)
  return equals and #equals
end

--- Reads the long bracket of `level` the reader is at, and moves past its
--- closing bracket. A line break right after the opening is not part of the
--- text.
---
--- Refuses with `unclosed`, at the line the bracket opens on, when it is never
--- closed.
---
---@param reader aineo.office_pack.Reader
---@param level integer
---@param unclosed string what the refusal says
---@return string text what stands between the brackets
function M.read(reader, level, unclosed)
  local content_start = reader.position + level + 2
  local closing = ']' .. ('='):rep(level) .. ']'
  local closing_start = reader.text:find(closing, content_start, true)
  if not closing_start then
    reader_module.refuse(reader, unclosed)
  end
  local text = reader.text:sub(content_start, closing_start - 1):gsub('^\r?\n', '')
  reader_module.advance_to(reader, closing_start + #closing)
  return text
end

return M
