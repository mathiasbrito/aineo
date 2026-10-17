--- The changes pane's base and the user's saves, and the view it showed,
--- kept for each Claude Code session under the editor's state directory,
--- one file of each per session, so that a later editor following the
--- session shows them again.

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

--- The JSON of the file `path`, decoded, or nil when it is not there or
--- holds none. A file that is there but cannot be read says so.
---
---@param path string
---@return any decoded
---@return boolean unreadable whether a file is there that could not be read
local function read_decoded(path)
  local file = io.open(path, 'rb')
  if not file then
    return nil, vim.uv.fs_stat(path) ~= nil
  end
  local text = file:read('*a')
  file:close()
  local decoded, value = pcall(vim.json.decode, text, { luanil = { object = true, array = true } })
  return decoded and value or nil, false
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
  local value, unreadable = read_decoded(M.kept_base_file(state_directory, id))
  return as_kept_base(value), unreadable
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

--- Replaces the whole of `file` with the JSON of `value`, making the
--- directories that lead to it when missing. The file holds the whole of
--- `value` or, when the write fails, what it held before.
---
---@param file string
---@param value table
---@return string? failure why it could not be kept, naming the file; nil once kept
local function keep_file(file, value)
  local failure = make_directory(vim.fs.dirname(file)) or replace_file(file, vim.json.encode(value))
  if failure then
    return ('%s: %s'):format(file, failure)
  end
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
  return keep_file(
    M.kept_base_file(state_directory, id),
    { top = kept.top, base = kept.base, saved = kept.saved }
  )
end

--- Moves the file `from_file` to `to_file`, when `to_file` has none and
--- `from_file` has one: `from_file` unread — a symbolic link as a link — is
--- then `to_file`, and `from_file` is gone. Neither is touched otherwise.
--- `to_file` is looked for first and then `from_file` renamed to it, in one
--- step: two editors moving one `from_file` at the same moment leave it with
--- one of them, never shared, and the one that finds it gone moves nothing,
--- which is no failure.
---
---@param from_file string
---@param to_file string
---@return string? failure why it could not be moved, naming both files; nil when it was moved, or when `to_file` exists or `from_file` does not
local function move_file(from_file, to_file)
  if vim.uv.fs_stat(to_file) then
    return nil
  end
  local renamed, failure, code = vim.uv.fs_rename(from_file, to_file)
  if renamed or code == 'ENOENT' then
    return nil
  end
  return ('cannot move %s to %s: %s'):format(from_file, to_file, failure)
end

--- Moves what is kept for the session `from` to the session `to`, under
--- `state_directory`, when `to` has no file and `from` has one (`move_file()`).
---
---@param state_directory string
---@param from string
---@param to string
---@return string? failure why it could not be moved, naming both files; nil when it was moved, or when `to`'s file exists or `from`'s does not
function M.move_kept_base(state_directory, from, to)
  return move_file(M.kept_base_file(state_directory, from), M.kept_base_file(state_directory, to))
end

--- What the changes pane kept of one worktree or one local branch: either
--- the worktree's top level, or the branch's name.
---@class aineo.changes.KeptPick
---@field top? string the worktree's top level
---@field branch? string the local branch's name

--- The view the changes pane showed, kept for a session.
---@class aineo.changes.KeptView
---@field repository string the repository's top level the view is of
---@field focused boolean whether the focused view showed, rather than the default view
---@field shows_reported boolean whether the focused view was the reported set, rather than the pick
---@field scope? aineo.changes.KeptPick the worktree or branch picked to show alone
---@field reported aineo.changes.KeptPick[] the reported set's members, in their order

--- The file that keeps the view of the session `id`, beside the file that
--- keeps its base: named by the id's SHA-256 as that file is
--- (`M.kept_base_file()`).
---
---@param state_directory string
---@param id string
---@return string
function M.kept_view_file(state_directory, id)
  return vim.fs.joinpath(
    state_directory,
    'aineo',
    'changes-sessions',
    vim.fn.sha256(id) .. '.view.json'
  )
end

--- `decoded` as a pick: a table holding one non-empty string, `top` or
--- `branch`, not both; nil when it is not.
---
---@param decoded any
---@return aineo.changes.KeptPick|nil
local function as_kept_pick(decoded)
  if type(decoded) ~= 'table' then
    return nil
  end
  local top, branch = decoded.top, decoded.branch
  if type(top) == 'string' and top ~= '' and branch == nil then
    return { top = top }
  end
  if type(branch) == 'string' and branch ~= '' and top == nil then
    return { branch = branch }
  end
  return nil
end

--- `decoded`, a kept view file's JSON, as the view it keeps, or nil when it
--- is not of that shape.
---
---@param decoded any
---@return aineo.changes.KeptView|nil
local function as_kept_view(decoded)
  if
    type(decoded) ~= 'table'
    or type(decoded.repository) ~= 'string'
    or type(decoded.focused) ~= 'boolean'
    or type(decoded.shows_reported) ~= 'boolean'
    or not vim.islist(decoded.reported)
  then
    return nil
  end
  local scope
  if decoded.scope ~= nil then
    scope = as_kept_pick(decoded.scope)
    if not scope then
      return nil
    end
  end
  local reported = {}
  for _, member in ipairs(decoded.reported) do
    local pick = as_kept_pick(member)
    if not pick then
      return nil
    end
    table.insert(reported, pick)
  end
  return {
    repository = decoded.repository,
    focused = decoded.focused,
    shows_reported = decoded.shows_reported,
    scope = scope,
    reported = reported,
  }
end

--- The view kept for the session `id`, or nil when none is: a file that is
--- missing, cannot be read, or holds anything but what `M.keep_view()`
--- writes counts as none.
---
---@param state_directory string
---@param id string
---@return aineo.changes.KeptView|nil
function M.read_kept_view(state_directory, id)
  return as_kept_view((read_decoded(M.kept_view_file(state_directory, id))))
end

--- Keeps `view` for the session `id`, in place of what was kept before,
--- making the directories that lead to its file when missing. The file holds
--- the whole of `view` or, when the write fails, what it held before.
---
---@param state_directory string
---@param id string
---@param view aineo.changes.KeptView
---@return string? failure why it could not be kept, naming the file; nil once kept
function M.keep_view(state_directory, id, view)
  return keep_file(M.kept_view_file(state_directory, id), {
    repository = view.repository,
    focused = view.focused,
    shows_reported = view.shows_reported,
    scope = view.scope,
    reported = view.reported,
  })
end

--- Moves the view kept for the session `from` to the session `to`, under
--- `state_directory`, when `to` has none and `from` has one (`move_file()`).
---
---@param state_directory string
---@param from string
---@param to string
---@return string? failure why it could not be moved, naming both files; nil when it was moved, or when `to`'s file exists or `from`'s does not
function M.move_kept_view(state_directory, from, to)
  return move_file(M.kept_view_file(state_directory, from), M.kept_view_file(state_directory, to))
end

return M
