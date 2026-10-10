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

--- The codes, as libuv gives them, of a hard link the file system refuses:
--- it has none (exFAT, FAT, some network and FUSE mounts), the file is on
--- another device, or it has too many.
local LINK_REFUSALS = { ENOTSUP = true, EPERM = true, EXDEV = true, EMLINK = true, ENOSYS = true }

--- Moves the kept file `from` to `to` by renaming it, when `to` does not
--- exist and `from` does; neither is touched otherwise. `to` is looked for
--- first and then `from` renamed, so another editor making `to` between
--- the two has its file replaced.
---
---@param from string
---@param to string
---@return string? failure why `from` could not be moved, naming both files; nil when it was moved, or when `to` exists or `from` does not
local function move_by_rename(from, to)
  if vim.uv.fs_stat(to) then
    return nil
  end
  local renamed, failure, code = vim.uv.fs_rename(from, to)
  if renamed or code == 'ENOENT' then
    return nil
  end
  return ('cannot move %s to %s: %s'):format(from, to, failure)
end

--- Removes `to`, just linked to the kept file `from`, once `from` was found
--- gone: another editor took `from` between the link and its removal, and
--- when `to` is not the only name left of that file, the other editor's
--- session holds it, so `to` is removed for the two sessions to keep one
--- file each. A `to` that is that file's only name is kept: `from` was
--- removed some other way, and `to` holds the only copy.
---
---@param from string
---@param to string
---@return string? failure why `to` could not be removed, naming both files; nil once removed, or kept
local function give_up_link_taken_meanwhile(from, to)
  local moved = vim.uv.fs_stat(to)
  if not moved or moved.nlink < 2 then
    return nil
  end
  local removed, removal_failure = vim.uv.fs_unlink(to)
  if not removed then
    return ('cannot move %s to %s: another editor moved it to its session at the same moment, and %s cannot be removed, so both sessions keep it: %s'):format(
      from,
      to,
      to,
      removal_failure
    )
  end
  return nil
end

--- Moves what is kept for the session `from` to the session `to`, under
--- `state_directory`, when `to` has no file and `from` has one: `from`'s
--- file, unread, is then `to`'s, and `from`'s is gone. Neither is touched
--- otherwise. The move links `to`'s file to `from`'s and then removes
--- `from`'s; the link refuses an existing file at once, so another editor
--- making `to`'s file, or taking `from`'s, meanwhile never has its file
--- replaced, and is no failure. Another editor that took `from`'s file
--- between the link and the removal took the same file: `to`'s is then
--- removed again (`give_up_link_taken_meanwhile()`), so that two sessions
--- never share one file. Where the file system refuses the link
--- (`LINK_REFUSALS`), or `from`'s file is a symbolic link, which then stays
--- one, it is renamed instead (`move_by_rename()`).
---
---@param state_directory string
---@param from string
---@param to string
---@return string? failure why it could not be moved, naming both files; nil when it was moved, or when `to`'s file exists or `from`'s does not
function M.move_kept_base(state_directory, from, to)
  local from_file = M.kept_base_file(state_directory, from)
  local to_file = M.kept_base_file(state_directory, to)
  local from_link = vim.uv.fs_lstat(from_file)
  if from_link and from_link.type == 'link' then
    return move_by_rename(from_file, to_file)
  end
  local linked, failure, code = vim.uv.fs_link(from_file, to_file)
  if LINK_REFUSALS[code] then
    return move_by_rename(from_file, to_file)
  end
  if linked then
    local removed, removal_failure, removal_code = vim.uv.fs_unlink(from_file)
    if removal_code == 'ENOENT' then
      return give_up_link_taken_meanwhile(from_file, to_file)
    end
    if not removed then
      return ('cannot move %s to %s: it is in both, the first cannot be removed: %s'):format(
        from_file,
        to_file,
        removal_failure
      )
    end
    return nil
  end
  if code == 'EEXIST' or code == 'ENOENT' then
    return nil
  end
  return ('cannot move %s to %s: %s'):format(from_file, to_file, failure)
end

return M
