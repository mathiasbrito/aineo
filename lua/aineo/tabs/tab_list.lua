--- The folder's list of the tabs' sessions, kept in a file of its own beside
--- the session id kept for the folder: one file per folder under
--- `<state directory>/aineo/claude-tabs/`, named by the folder's SHA-256.
---
--- The form check of a session id and the write of the file are this
--- home's own, so that it requires no other aineo home. The id check is the
--- one `aineo.claude`'s `is_session_id()` makes.

local M = {}

--- The permissions of the file: the user's alone to read and write.
local OWNER_ONLY = tonumber('600', 8)

--- The most bytes a kept list is read from: far more than any editor's tab
--- pages hold, so a file grown beyond it is not a list that was kept.
local MAX_FILE_BYTES = 64 * 1024

--- The form of a session id: a lower-case version-4 UUID, `8-4-4-4-12`. Each
--- becomes an argument to `claude --resume`, so nothing else is read as one.
local SESSION_ID_PATTERN =
  '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$'

--- The list a folder keeps: the sessions of its tabs in the order of the
--- tabs' places, and the place of the tab that was current.
---
---@class aineo.tabs.TabList
---@field sessions string[] session ids, one per tab
---@field current integer a place in `sessions`

--- One tab, as the editor lists its tabs in the order of their places.
---
---@class aineo.tabs.PlacedTab
---@field session string? the session its Claude Code follows; nil before it has one
---@field current boolean whether it is the tab to list as the current one

--- The file that keeps the list of `folder`.
---
---@param state_directory string
---@param folder string
---@return string
local function list_file(state_directory, folder)
  return vim.fs.joinpath(state_directory, 'aineo', 'claude-tabs', vim.fn.sha256(folder) .. '.json')
end

--- Whether `text` is a lower-case version-4 UUID.
---
---@param text any
---@return boolean
local function is_session_id(text)
  return type(text) == 'string' and text:find(SESSION_ID_PATTERN) ~= nil and text == text:lower()
end

--- Whether `sessions` is a non-empty list, without a hole, of session ids
--- none of which repeats: two tabs never show one session.
---
---@param sessions any
---@return boolean
local function is_list_of_distinct_session_ids(sessions)
  if type(sessions) ~= 'table' or not vim.islist(sessions) or #sessions == 0 then
    return false
  end
  local seen = {}
  for _, session in ipairs(sessions) do
    if not is_session_id(session) or seen[session] then
      return false
    end
    seen[session] = true
  end
  return true
end

--- Whether `value` is a list of distinct session ids and a whole `current`
--- place in it.
---
---@param value any
---@return boolean
local function is_tab_list(value)
  if type(value) ~= 'table' or not is_list_of_distinct_session_ids(value.sessions) then
    return false
  end
  local current = value.current
  return type(current) == 'number'
    and current >= 1
    and current <= #value.sessions
    and current % 1 == 0
end

--- The list of `placed`, the editor's tabs in the order of their places: the
--- session of each tab that has one, a session two tabs show once, at the
--- lower place; the place of the current tab, or of the tab that shows its
--- session first, else the first. Nil when no tab has a session.
---
---@param placed aineo.tabs.PlacedTab[]
---@return aineo.tabs.TabList|nil
function M.list_of_placed_tabs(placed)
  local sessions, place_of = {}, {}
  local current = 1
  for _, tab in ipairs(placed) do
    if tab.session and not place_of[tab.session] then
      table.insert(sessions, tab.session)
      place_of[tab.session] = #sessions
    end
    if tab.current and tab.session then
      current = place_of[tab.session]
    end
  end
  if #sessions == 0 then
    return nil
  end
  return { sessions = sessions, current = current }
end

--- The text of the file `path`, or nil when it is missing, unreadable, or
--- longer than `MAX_FILE_BYTES`.
---
---@param path string
---@return string|nil
local function read_file(path)
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local succeeded, text = pcall(file.read, file, MAX_FILE_BYTES + 1)
  file:close()
  if not succeeded or text == nil or #text > MAX_FILE_BYTES then
    return nil
  end
  return text
end

--- The list kept for `folder`, or nil when none is kept: a file that is
--- missing, unreadable, too long, not JSON, or not a non-empty list of
--- session ids with a place in it.
---
--- Raises nothing.
---
---@param state_directory string
---@param folder string
---@return aineo.tabs.TabList|nil
function M.read_tab_list(state_directory, folder)
  local text = read_file(list_file(state_directory, folder))
  if not text then
    return nil
  end
  local decoded, value = pcall(vim.json.decode, text)
  if not decoded or not is_tab_list(value) then
    return nil
  end
  return { sessions = value.sessions, current = value.current }
end

--- Makes the directory `path` and the directories leading to it, unless it
--- exists. Another editor making one of them at the same moment makes
--- `mkdir()` fail, so a directory that is there afterwards counts as made.
---
---@param path string
---@return string|nil failure why it could not be made; nil once made
local function make_directory(path)
  local made, failure = pcall(vim.fn.mkdir, path, 'p')
  if made or vim.fn.isdirectory(path) == 1 then
    return nil
  end
  return (tostring(failure):gsub('^Vim:', ''))
end

--- Writes `text` as the whole of the file `path`, emptied first, created
--- with `OWNER_ONLY` permissions when missing.
---
---@param path string
---@param text string
---@return string|nil failure why it could not be opened, written or closed, as libuv says it, or how many of the bytes a write cut short wrote; nil once written whole
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
  return nil
end

--- Replaces the whole of `file` with `text`: `text` is written to a file
--- beside it named for this editor, which then replaces it, so that a write
--- cut short leaves `file` as it was, and two editors writing at once never
--- write each other's. A write, or a replacement, that fails removes that
--- file again.
---
---@param file string
---@param text string
---@return string|nil failure why `file` could not be replaced; nil once replaced
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

--- Keeps `tab_list` as the list of `folder`, in place of any kept before,
--- making the directories that lead to its file when missing. The file
--- holds the whole list or, when the write fails, what it held before.
--- Only a list `read_tab_list()` would give back is written.
---
--- Raises an error naming the file when `tab_list` is no such list, or when
--- the file cannot be written.
---
---@param state_directory string
---@param folder string
---@param tab_list aineo.tabs.TabList
function M.write_tab_list(state_directory, folder, tab_list)
  local file = list_file(state_directory, folder)
  local failure
  if not is_tab_list(tab_list) then
    failure = 'not a list of distinct session ids with a place in it'
  else
    local text = vim.json.encode({ sessions = tab_list.sessions, current = tab_list.current })
    failure = make_directory(vim.fs.dirname(file)) or replace_file(file, text)
  end
  if failure then
    error(("cannot keep the folder's tabs in %s: %s"):format(file, failure), 0)
  end
end

return M
