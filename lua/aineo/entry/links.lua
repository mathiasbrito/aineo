--- Where a link the user follows in a tab's panes goes: a regular text file,
--- wherever it lies, opens in the current window, which the layout hands to
--- the middle column, as the files window's `<S-CR>` opens a file
--- (`aineo.changes`'s `open_working_file()`); anything else — a file that is
--- not text, a directory, a web address — goes to the operating system
--- (`vim.ui.open()`).

local wrapped_links = require('aineo.entry.wrapped_links')

local M = {}

--- How many bytes at a file's start decide whether it is text.
local TEXT_SAMPLE_BYTES = 8192

--- An address: a scheme, as RFC 3986 §3.1 spells one, then `://`.
local ADDRESS = '^%a[%w+.-]*://'

--- The start of an address of a local file (RFC 8089).
local FILE_ADDRESS = 'file://'

--- A link that names a line at its end, as `#L<line>`: what comes before it,
--- and the line.
local LINE_FRAGMENT = '^(.*)#L(%d+)$'

--- Whether the regular file `file` is text: its first `TEXT_SAMPLE_BYTES`
--- bytes hold no NUL byte. A file that cannot be read is not.
---
---@param file string
---@return boolean
local function is_text_file(file)
  local handle = io.open(file, 'rb')
  if not handle then
    return false
  end
  local sample = handle:read(TEXT_SAMPLE_BYTES) or ''
  handle:close()
  return not sample:find('\0', 1, true)
end

--- Hands `target`, a file or an address, to the operating system
--- (`vim.ui.open()`), and tells the user, once, when it cannot.
---
---@param target string
local function open_with_system(target)
  local _, failure = vim.ui.open(target)
  if failure then
    vim.notify(('aineo: %s could not be opened: %s'):format(target, failure), vim.log.levels.ERROR)
  end
end

--- `path` with a leading `~`, alone or before a `/`, replaced by the home
--- folder; any other path as it is, as is every path when the home folder is
--- unknown. A `~` anywhere else, and `~name/`, is part of a name. The
--- Report reads its paths by the same rule (`aineo.report`'s environment).
---
---@param path string
---@return string
function M.with_home_expanded(path)
  local home = vim.uv.os_homedir()
  if home and (path == '~' or vim.startswith(path, '~/')) then
    return home .. path:sub(2)
  end
  return path
end

--- Opens the regular file `file`, an absolute path, at line `line` when
--- given: in the current window when it is a text file (`is_text_file()`),
--- wherever it lies, else with the operating system (`open_with_system()`).
---
---@param file string
---@param line integer?
function M.open_file(file, line)
  if is_text_file(file) then
    require('aineo.changes').open_working_file(vim.fs.dirname(file), vim.fs.basename(file), line)
    return
  end
  open_with_system(file)
end

--- Whether the link `text` is an address of anything but a local file.
---
---@param text string
---@return boolean
local function is_web_address(text)
  return text:match(ADDRESS) ~= nil and not vim.startswith(text, FILE_ADDRESS)
end

--- Where the path link `text` leads, in `directory` when relative: the
--- absolute path of the file it names, what the file system knows of it (nil
--- when it names nothing), and the line the link names by a `#L<line>` at its
--- end. `M.open_link()` and the joining of wrapped links decide by the same
--- rule.
---
---@param text string
---@param directory string
---@return string file
---@return uv.fs_stat.result? stat
---@return string? line_named
local function locate(text, directory)
  local path, line_named = text:match(LINE_FRAGMENT)
  path = path or text
  if vim.startswith(path, FILE_ADDRESS) then
    path = vim.uri_to_fname(path)
  end
  path = M.with_home_expanded(path)
  local file = vim.startswith(path, '/') and path or vim.fs.joinpath(directory, path)
  return file, vim.uv.fs_stat(file), line_named
end

--- Follows the link `text`, as a pane shows it, naming line `line` when the
--- text set one apart (`aineo.report`'s `find_path_candidates()`): a path,
--- in `directory` when relative, or in the home folder when it starts with
--- `~/` (a `~` alone is the home folder; `~name/` is a relative path), or a
--- `file://` address, either naming its line by a `#L<line>` at its end,
--- opens as `M.open_file()` opens a regular file; a directory, any other file
--- that is no regular file, and an address of any other scheme, such as a web
--- link, go to the operating system. A link that names nothing that exists
--- opens nothing, and the user is told so once.
---
---@param text string
---@param line integer?
---@param directory string the directory a relative path is in
function M.open_link(text, line, directory)
  if is_web_address(text) then
    open_with_system(text)
    return
  end
  local file, stat, line_named = locate(text, directory)
  if not stat then
    vim.notify(('aineo: %s names no file'):format(text), vim.log.levels.WARN)
    return
  end
  if stat.type ~= 'file' then
    open_with_system(file)
    return
  end
  M.open_file(file, tonumber(line_named) or line)
end

--- Whether the link `link`, joined from rows, names something that exists
--- in `directory`, as `M.open_link()` finds it. A web address names nothing
--- that can be checked.
---
---@param link aineo.entry.WrappedLink
---@param directory string
---@return boolean
local function names_something(link, directory)
  if is_web_address(link.path) then
    return false
  end
  return select(2, locate(link.path, directory)) ~= nil
end

--- The link that covers byte `byte`, from 0, of line `row`, from 0, of
--- `buffer`, or nil: the longest one joined from rows that names something in
--- `directory` (`wrapped_links.covering()`), else the one the line holds
--- (`aineo.report`'s `find_path_candidates()`).
---
---@param buffer integer
---@param row integer
---@param byte integer
---@param directory string
---@return { path: string, line: integer? }?
local function link_at(buffer, row, byte, directory)
  local function row_text(index)
    return vim.api.nvim_buf_get_lines(buffer, index, index + 1, false)[1] or ''
  end
  local joined = vim.iter(wrapped_links.covering(row_text, row, byte)):find(function(link)
    return names_something(link, directory)
  end)
  if joined then
    return joined
  end
  local candidates = require('aineo.report').find_path_candidates(row_text(row))
  return vim.iter(candidates):find(function(candidate)
    return candidate.first_column <= byte and byte < candidate.end_column
  end)
end

--- The link under the mouse in `buffer` (`link_at()`), or nil when the
--- mouse is on no text of a window showing `buffer`.
---
---@param buffer integer
---@param directory string
---@return { path: string, line: integer? }?
local function link_under_mouse(buffer, directory)
  local mouse = vim.fn.getmousepos()
  if mouse.winid == 0 or mouse.line == 0 or vim.api.nvim_win_get_buf(mouse.winid) ~= buffer then
    return nil
  end
  return link_at(buffer, mouse.line - 1, mouse.column - 1, directory)
end

--- Maps, in the terminal `buffer`, a double-click (`<2-LeftMouse>`), in
--- Normal and Terminal mode, to follow the link under the mouse, after
--- leaving Terminal mode, and `gx`, in Normal mode, to follow the link under
--- the cursor: `follow` is handed the link's text and the line it names.
--- A double-click on no link does what it does unmapped, typed as if no
--- mapping had it: it selects the word in Normal mode and reaches the
--- terminal's program in Terminal mode. `gx` on no link does nothing. The
--- mappings belong to the buffer.
---
---@param buffer integer
---@param follow fun(text: string, line: integer?)
---@param directory fun(): string the directory a relative path is in
function M.map_link_keys(buffer, follow, directory)
  vim.keymap.set({ 'n', 't' }, '<2-LeftMouse>', function()
    local link = link_under_mouse(buffer, directory())
    if not link then
      vim.api.nvim_feedkeys(vim.keycode('<2-LeftMouse>'), 'ni', false)
      return
    end
    vim.cmd.stopinsert()
    follow(link.path, link.line)
  end, { buffer = buffer, desc = 'aineo: open the link under the mouse' })
  vim.keymap.set('n', 'gx', function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local link = link_at(buffer, cursor[1] - 1, cursor[2], directory())
    if link then
      follow(link.path, link.line)
    end
  end, { buffer = buffer, desc = 'aineo: open the link under the cursor' })
end

return M
