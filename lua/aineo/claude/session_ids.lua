--- The ids of the Claude Code sessions aineo starts, and the one it keeps for
--- each working directory.

local M = {}

--- The permissions of a kept id's file: the user's alone to read and write.
local OWNER_ONLY = tonumber('600', 8)

--- How many random bytes a session id is made of.
local SESSION_ID_BYTES = 16

--- The form of every session id `new_session_id()` makes.
local SESSION_ID_PATTERN =
  '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$'

--- `byte` with its high four bits replaced by `high`, a number from 0 to 15.
---
---@param byte integer
---@param high integer
---@return integer
local function with_high_nibble(byte, high)
  return high * 16 + byte % 16
end

--- `byte` with its high two bits set to `10`.
---
---@param byte integer
---@return integer
local function with_variant_bits(byte)
  return 0x80 + byte % 0x40
end

--- A new session id: a random version-4 UUID (RFC 9562 §5.4) from the
--- operating system's random source, in lower-case hexadecimal, `8-4-4-4-12`.
---
--- Raises an error naming the random source's failure when it gives none.
---
---@return string
function M.new_session_id()
  local random, failure = vim.uv.random(SESSION_ID_BYTES)
  if not random then
    error('aineo.claude: cannot make a session id: ' .. tostring(failure), 0)
  end
  local bytes = { random:byte(1, SESSION_ID_BYTES) }
  bytes[7] = with_high_nibble(bytes[7], 4)
  bytes[9] = with_variant_bits(bytes[9])
  local hex = string.format(string.rep('%02x', SESSION_ID_BYTES), unpack(bytes))
  return table.concat({
    hex:sub(1, 8),
    hex:sub(9, 12),
    hex:sub(13, 16),
    hex:sub(17, 20),
    hex:sub(21, 32),
  }, '-')
end

--- The file that keeps the session id of `working_directory`: one per
--- directory, named by the directory's SHA-256 so that any path makes a
--- valid file name of the same length.
---
---@param state_directory string
---@param working_directory string
---@return string
local function kept_id_file(state_directory, working_directory)
  return vim.fs.joinpath(
    state_directory,
    'aineo',
    'claude-sessions',
    vim.fn.sha256(working_directory) .. '.txt'
  )
end

--- Whether `text` is a session id of the form `new_session_id()` makes,
--- its letters lower-case: nil, what a read of a directory gives, is not.
---
---@param text string|nil
---@return boolean
local function is_session_id(text)
  return type(text) == 'string' and text:find(SESSION_ID_PATTERN) ~= nil and text == text:lower()
end

--- The session id kept for `working_directory`, or nil when none is kept:
--- a kept file that cannot be read, or holds anything but a session id of
--- the form `new_session_id()` makes, counts as none.
---
---@param state_directory string
---@param working_directory string
---@return string|nil
function M.kept_session_id(state_directory, working_directory)
  local file = io.open(kept_id_file(state_directory, working_directory), 'rb')
  if not file then
    return nil
  end
  local kept = file:read('*a')
  file:close()
  if not is_session_id(kept) then
    return nil
  end
  return kept
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

--- Writes `text` as the whole of the file `path`, emptied first, created
--- with `OWNER_ONLY` permissions when missing.
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

--- Keeps `id` as the session id of `working_directory`, in place of any
--- kept before, making the directories that lead to its file when missing.
--- The file holds the whole id or, when the write fails, what it held
--- before.
---
--- Raises an error naming the file when it cannot be written.
---
---@param state_directory string
---@param working_directory string
---@param id string
function M.keep_session_id(state_directory, working_directory, id)
  local file = kept_id_file(state_directory, working_directory)
  local failure = make_directory(vim.fs.dirname(file)) or replace_file(file, id)
  if failure then
    error(("cannot keep Claude Code's session id in %s: %s"):format(file, failure), 0)
  end
end

return M
