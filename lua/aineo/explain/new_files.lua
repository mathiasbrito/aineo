--- The files not on disk yet that code is proposed for: each is written,
--- with its missing folders and the files written beside it, when the user
--- first accepts code in it, and never before.

local folders = require('aineo.explain.folders')

local M = {}

--- A file waiting for the first code accepted in its buffer.
---@class aineo.explain.ExpectedFile
---@field path string the absolute path the layout of the project's tests gave it
---@field companions string[] the absolute paths of the files written beside it
---@field on_written fun() called once it is written

--- The files waiting to be written, by buffer.
---@type table<integer, aineo.explain.ExpectedFile>
local expected = {}

--- Has the file of `buffer`, at `path`, which the layout of the project's
--- tests gave and which is not on disk, written when code is first
--- accepted in it (`write_if_expected()`), with `companions`, the absolute
--- paths of files written beside it, each empty, when missing; then calls
--- `on_written`.
---
---@param buffer integer
---@param path string
---@param companions string[]
---@param on_written fun()
function M.expect(buffer, path, companions, on_written)
  expected[buffer] = { path = path, companions = companions, on_written = on_written }
end

--- `path` from the project that holds it, as the user is told it.
---
---@param path string
---@return string
local function shown_path(path)
  return vim.fs.relpath(folders.project_of(path), path) or path
end

--- Why the file `waiting` for `buffer` cannot be written now, or `nil`:
--- the buffer is no longer named with its path, or something is on disk
--- at that path, which is never written over.
---
---@param buffer integer
---@param waiting aineo.explain.ExpectedFile
---@return string|nil
local function refusal_of(buffer, waiting)
  local name = vim.api.nvim_buf_get_name(buffer)
  if name ~= waiting.path then
    return ('%s is not where %s was to be written: nothing was written'):format(
      shown_path(name),
      shown_path(waiting.path)
    )
  end
  if vim.uv.fs_stat(waiting.path) then
    return ('%s is on disk now: nothing was written over it'):format(shown_path(waiting.path))
  end
end

--- Writes `path` empty, with its missing folders, unless it is on disk.
---
---@param path string
local function write_empty(path)
  if vim.uv.fs_stat(path) then
    return
  end
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile({}, path)
end

--- Writes the file of `buffer` when it was expected (`expect()`), at the
--- path it was given, with its missing folders and its companions, then
--- forgets it and calls its `on_written`; tells the user, once, what was
--- written, or why nothing was
--- (`refusal_of()`: the buffer renamed, or something on disk at that path
--- at that moment), leaving the buffer unwritten then. A buffer not
--- expected is left as it is.
---
---@param buffer integer
function M.write_if_expected(buffer)
  local waiting = expected[buffer]
  expected[buffer] = nil
  if not waiting then
    return
  end
  local refusal = refusal_of(buffer, waiting)
  if refusal then
    vim.notify('aineo: ' .. refusal, vim.log.levels.WARN)
    return
  end
  local path = waiting.path
  local companions = waiting.companions
  local written, problem = pcall(function()
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    vim.api.nvim_buf_call(buffer, function()
      vim.cmd('silent keepalt write')
    end)
    vim.tbl_map(write_empty, companions)
  end)
  if not written then
    vim.notify(
      ('aineo: %s could not be written: %s'):format(path, tostring(problem)),
      vim.log.levels.ERROR
    )
    return
  end
  vim.notify(('aineo: %s written, a new file'):format(shown_path(path)), vim.log.levels.INFO)
  waiting.on_written()
end

--- Forgets `buffer`, whose file is then never written by `write_if_expected()`.
---
---@param buffer integer
function M.forget(buffer)
  expected[buffer] = nil
end

return M
