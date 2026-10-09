--- The changes pane's base and the user's saves, kept for each Claude Code
--- session under the editor's state directory, one file per session, so
--- that a later editor following the session shows them again.

local M = {}

--- The permissions of a kept file: the user's alone to read and write.
local OWNER_ONLY = tonumber('600', 8)

--- What is kept for a session.
---@class aineo.changes.KeptBase
---@field top string the repository's top level
---@field base? string the full id of the base commit; nil when the session began before the repository's first commit
---@field saved string[] the paths the user saved, relative to the top level, sorted

--- The file that keeps what is kept for the session `id`: named by the id's
--- SHA-256, so that no id makes an invalid name, nor two ids one name.
---
---@param state_directory string
---@param id string
---@return string
function M.kept_base_file(state_directory, id)
  return vim.fs.joinpath(state_directory, 'aineo', 'changes-sessions', vim.fn.sha256(id) .. '.json')
end

--- Whether `value` is a list of strings.
---
---@param value any
---@return boolean
local function is_list_of_strings(value)
  if not vim.islist(value) then
    return false
  end
  for _, item in ipairs(value) do
    if type(item) ~= 'string' then
      return false
    end
  end
  return true
end

--- `decoded`, a kept file's JSON, as what is kept, or nil when it is not of
--- that shape.
---
---@param decoded any
---@return aineo.changes.KeptBase|nil
local function as_kept_base(decoded)
  if
    type(decoded) ~= 'table'
    or type(decoded.top) ~= 'string'
    or not (decoded.base == nil or type(decoded.base) == 'string')
    or not is_list_of_strings(decoded.saved)
  then
    return nil
  end
  return { top = decoded.top, base = decoded.base, saved = decoded.saved }
end

--- What is kept for the session `id`, or nil when nothing is: a file that
--- holds anything but what `M.keep_base()` writes counts as nothing kept.
--- A file that is there but cannot be read is nil too, and says so.
---
---@param state_directory string
---@param id string
---@return aineo.changes.KeptBase|nil kept
---@return boolean unreadable whether a file is there that could not be read
function M.read_kept_base(state_directory, id)
  local path = M.kept_base_file(state_directory, id)
  local file = io.open(path, 'rb')
  if not file then
    return nil, vim.uv.fs_stat(path) ~= nil
  end
  local text = file:read('*a')
  file:close()
  local decoded, value = pcall(vim.json.decode, text, { luanil = { object = true, array = true } })
  return decoded and as_kept_base(value) or nil, false
end

--- Makes the directory `path` and the directories leading to it, unless it
--- exists. Another editor making one of them at the same moment makes
--- `mkdir()` fail, so it tries again, up to once for each of the path's
--- directories.
---
---@param path string
---@return string? failure why it could not be made, as `mkdir()` says it, without the `Vim:` Neovim puts before it; nil once made
local function make_directory(path)
  local tries_left = #vim.split(path, '/', { trimempty = true })
  local made, failure = pcall(vim.fn.mkdir, path, 'p')
  while not made and tries_left > 0 do
    tries_left = tries_left - 1
    made, failure = pcall(vim.fn.mkdir, path, 'p')
  end
  if not made then
    return (tostring(failure):gsub('^Vim:', ''))
  end
end

--- Writes `text` as the whole of the file `path`, created with
--- `OWNER_ONLY` permissions when missing.
---
---@param path string
---@param text string
---@return string? failure why it could not be opened, written or closed, as libuv says it, or how many of the bytes a write cut short wrote; nil once written whole
local function write_file(path, text)
  local descriptor, open_failure = vim.uv.fs_open(path, 'w', OWNER_ONLY)
  if not descriptor then
    return open_failure
  end
  local written, write_failure = vim.uv.fs_write(descriptor, text)
  local closed, close_failure = vim.uv.fs_close(descriptor)
  if not written then
    return write_failure
  end
  if written < #text then
    return ('wrote %d of %d bytes'):format(written, #text)
  end
  if not closed then
    return close_failure
  end
end

--- Replaces the whole of `file` with `text`: `text` is written to a file
--- beside it named for this editor, which then replaces it, so that a write
--- cut short leaves `file` as it was, and two editors writing at once never
--- write each other's. A write, or a replacement, that fails removes that
--- file again.
---
---@param file string
---@param text string
---@return string? failure why `file` could not be replaced; nil once replaced
local function replace_file(file, text)
  local cut = ('%s.%d.cut'):format(file, vim.uv.os_getpid())
  local failure = write_file(cut, text)
  if not failure then
    local renamed, rename_failure = vim.uv.fs_rename(cut, file)
    failure = not renamed and rename_failure or nil
  end
  if failure then
    vim.uv.fs_unlink(cut)
  end
  return failure
end

--- Keeps `kept` for the session `id`, in place of what was kept before,
--- making the directories that lead to its file when missing. The file
--- holds the whole of `kept` or, when the write fails, what it held before.
---
---@param state_directory string
---@param id string
---@param kept aineo.changes.KeptBase
---@return string? failure why it could not be kept, naming the file; nil once kept
function M.keep_base(state_directory, id, kept)
  local file = M.kept_base_file(state_directory, id)
  local failure = make_directory(vim.fs.dirname(file))
    or replace_file(file, vim.json.encode({ top = kept.top, base = kept.base, saved = kept.saved }))
  if failure then
    return ('%s: %s'):format(file, failure)
  end
end

return M
