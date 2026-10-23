--- The fake transcript writer: the lines of a recorded transcript, and the
--- appending of lines to a transcript file the way Claude Code writes them,
--- one line ending in a newline at a time.
---
--- The recordings live in `tests/fixtures/transcripts/`; each opens with a
--- `fixture-header` line naming the Claude Code version it was recorded on.

local M = {}

local FIXTURES = 'tests/fixtures/transcripts'

--- The recorded subagent's meta file, in the state the recording ended in.
local SUBAGENT_META = 'subagent-explore-2.1.308.meta.json'

--- The lines of the recording `name` in `tests/fixtures/transcripts/`, as it
--- holds them, the header included.
---
---@param name string the recording's file name
---@return string[] lines
function M.lines_of(name)
  return vim.fn.readfile(vim.fs.joinpath(FIXTURES, name))
end

--- Writes the meta file of a subagent at `path`, as Claude Code writes it: the
--- recorded subagent's meta, in the state `state` — `'running'`, which carries
--- neither flag, `'finished'`, or `'stopped_by_user'`.
---
---@param path string
---@param state 'running'|'finished'|'stopped_by_user'
function M.write_subagent_meta(path, state)
  local recorded = table.concat(vim.fn.readfile(vim.fs.joinpath(FIXTURES, SUBAGENT_META)), '\n')
  local meta = vim.json.decode(recorded)
  meta.finished = state == 'finished' or nil
  meta.stoppedByUser = state == 'stopped_by_user' or nil
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile({ vim.json.encode(meta) }, path)
end

--- Appends `text` to the file `path`, making it, and the folders it is in,
--- when they do not exist. Nothing is added to `text`: it may end a line or
--- cut one short.
---
---@param path string
---@param text string
function M.append_text(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
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

--- Writes `lines` over the file `path`, each ending in a newline, in the file
--- itself: it is cut to nothing first, as a tool that rewrites a log does.
---
---@param path string
---@param lines string[]
function M.rewrite(path, lines)
  local file = assert(io.open(path, 'wb'))
  file:write(table.concat(lines, '\n') .. '\n')
  file:close()
end

--- Replaces the file `path` by another file that holds `lines`, each ending
--- in a newline, made beside it and renamed over it, as a tool that saves
--- atomically does: the path then names another file.
---
---@param path string
---@param lines string[]
function M.replace(path, lines)
  local beside = path .. '.new'
  M.rewrite(beside, lines)
  assert(vim.uv.fs_rename(beside, path))
end

return M
