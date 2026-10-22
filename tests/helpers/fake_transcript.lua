--- The fake transcript writer: the lines of a recorded transcript, and the
--- appending of lines to a transcript file the way Claude Code writes them,
--- one line ending in a newline at a time.
---
--- The recordings live in `tests/fixtures/transcripts/`; each opens with a
--- `fixture-header` line naming the Claude Code version it was recorded on.

local M = {}

local FIXTURES = 'tests/fixtures/transcripts'

--- The lines of the recording `name` in `tests/fixtures/transcripts/`, as it
--- holds them, the header included.
---
---@param name string the recording's file name
---@return string[] lines
function M.lines_of(name)
  return vim.fn.readfile(vim.fs.joinpath(FIXTURES, name))
end

--- Appends `text` to the file `path`, making it when it does not exist.
--- Nothing is added to `text`: it may end a line or cut one short.
---
---@param path string
---@param text string
function M.append_text(path, text)
  local file = assert(io.open(path, 'ab'))
  file:write(text)
  file:close()
end

--- Appends each of `lines` to the file `path`, each ending in a newline.
---
---@param path string
---@param lines string[]
function M.append(path, lines)
  M.append_text(path, table.concat(lines, '\n') .. '\n')
end

return M
