--- The small files aineo keeps under the state directory for the report
--- server and its editors — the list of running editors, the claims and the
--- record of each Claude Code process — each written whole, readable by its
--- owner alone, in folders only the owner can enter.

local M = {}

--- The permissions of a kept file: the user's alone to read and write.
local OWNER_ONLY_FILE = tonumber('600', 8)

--- The permissions of a folder of kept files: the user's alone to enter,
--- list and write.
local OWNER_ONLY_FOLDER = tonumber('700', 8)

--- The codes, as libuv gives them, of a hard link the file system refuses:
--- it has none (exFAT, FAT, some network and FUSE mounts), the file is on
--- another device, or it has too many.
local LINK_REFUSALS = { ENOTSUP = true, EPERM = true, EXDEV = true, EMLINK = true, ENOSYS = true }

--- Makes the folder `path`, and the folders leading to it, unless it exists,
--- and makes it the user's alone (`OWNER_ONLY_FOLDER`). Another process
--- making one of them at the same moment makes `mkdir()` fail, so it tries
--- again, up to once for each of the path's folders.
---
--- Raises an error naming `path` when it cannot be made.
---
---@param path string
function M.make_private_folder(path)
  local tries_left = #vim.split(path, '/', { trimempty = true })
  local made, failure = pcall(vim.fn.mkdir, path, 'p')
  while not made and tries_left > 0 do
    tries_left = tries_left - 1
    made, failure = pcall(vim.fn.mkdir, path, 'p')
  end
  if not made then
    error(('aineo cannot make %s: %s'):format(path, (tostring(failure):gsub('^Vim:', ''))), 0)
  end
  vim.uv.fs_chmod(path, OWNER_ONLY_FOLDER)
end

--- Writes `text` as the whole of a new file `path`, created with
--- `OWNER_ONLY_FILE` permissions; `path` must not exist.
---
---@param path string
---@param text string
---@return string? failure why it could not be written whole, as libuv says it; nil once written
local function write_new_file(path, text)
  local descriptor, open_failure = vim.uv.fs_open(path, 'wx', OWNER_ONLY_FILE)
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

--- A name beside `path` that is this process's own, for a file written
--- before it takes `path`'s place.
---
---@param path string
---@return string
local function own_name_beside(path)
  return ('%s.%d.writing'):format(path, vim.uv.os_getpid())
end

--- Replaces the whole of the file `path` with `text`: `text` is written to a
--- file of this process's own beside it, which then takes its name, so that
--- a reader never reads part of it and two processes writing at once never
--- write each other's. A write that fails leaves `path` as it was.
---
--- Raises an error naming `path` when it cannot be written.
---
---@param path string
---@param text string
function M.replace_file(path, text)
  local beside = own_name_beside(path)
  vim.uv.fs_unlink(beside)
  local failure = write_new_file(beside, text)
  if not failure then
    local renamed, rename_failure = vim.uv.fs_rename(beside, path)
    failure = not renamed and rename_failure or nil
  end
  if failure then
    vim.uv.fs_unlink(beside)
    error(('aineo cannot write %s: %s'):format(path, failure), 0)
  end
end

--- Creates the file `path` holding `text` unless it exists: `text` is
--- written to a file beside it, which is then linked to `path` — a link
--- refuses an existing `path` — and removed. Where the file system refuses
--- hard links (`LINK_REFUSALS`), nothing is created.
---
---@param path string
---@param text string
---@return 'created'|'exists'|'refused'|'failed' outcome
function M.create_unless_present(path, text)
  local beside = own_name_beside(path)
  vim.uv.fs_unlink(beside)
  if write_new_file(beside, text) then
    vim.uv.fs_unlink(beside)
    return 'failed'
  end
  local linked, _, code = vim.uv.fs_link(beside, path)
  vim.uv.fs_unlink(beside)
  if linked then
    return 'created'
  end
  if code == 'EEXIST' then
    return 'exists'
  end
  return LINK_REFUSALS[code] and 'refused' or 'failed'
end

--- The whole text of the file `path`, or nil when it cannot be read.
---
---@param path string
---@return string?
function M.read_file(path)
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  return text
end

--- Removes the file `path` if it still holds `text`, read again just before
--- it is removed, so that a file another process has written since is kept.
---
---@param path string
---@param text string
function M.remove_if_unchanged(path, text)
  if M.read_file(path) == text then
    vim.uv.fs_unlink(path)
  end
end

--- The names of the files in the folder `path` that end in `suffix`, sorted;
--- none when the folder cannot be read.
---
---@param path string
---@param suffix string
---@return string[]
function M.file_names(path, suffix)
  local names = {}
  for name, kind in vim.fs.dir(path) do
    if kind == 'file' and vim.endswith(name, suffix) then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

return M
