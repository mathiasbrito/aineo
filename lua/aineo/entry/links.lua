--- Where a link the user follows in a tab's panes goes: a regular text file
--- of the tab's project opens in the current window, which the layout hands
--- to the middle column, as the files window's `<S-CR>` opens a file
--- (`aineo.changes`'s `open_working_file()`); anything else — a file that is
--- not text, a file outside the project, a directory — goes to the operating
--- system (`vim.ui.open()`).

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

--- Where the file `file` lies in the project whose top level is `project`,
--- both taken with every symbolic link resolved: the project's resolved top
--- level and the file's path from there, or nil when the file lies outside
--- it or either cannot be resolved.
---
---@param file string
---@param project string
---@return { top: string, path: string }?
local function place_in_project(file, project)
  local top, resolved = vim.uv.fs_realpath(project), vim.uv.fs_realpath(file)
  local path = top and resolved and vim.fs.relpath(top, resolved)
  if not path or path == '.' then
    return nil
  end
  return { top = top, path = path }
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

--- Opens the regular file `file`, an absolute path, at line `line` when
--- given: in the current window when it is a text file (`is_text_file()`)
--- of the project whose top level is `project` (`place_in_project()`),
--- else with the operating system (`open_with_system()`), which is also
--- where a file goes when there is no project.
---
---@param file string
---@param line integer?
---@param project string?
function M.open_file(file, line, project)
  local place = project and place_in_project(file, project)
  if place and is_text_file(file) then
    require('aineo.changes').open_working_file(place.top, place.path, line)
    return
  end
  open_with_system(file)
end

--- Where a tab's links are looked up and opened: the directory a relative
--- path is in, and the top level of the tab's project, nil when it has none.
---@class aineo.entry.LinkContext
---@field directory string
---@field project string?

--- Follows the link `text`, as a pane shows it, naming line `line` when the
--- text set one apart (`aineo.report`'s `find_path_candidates()`): a path,
--- in `context.directory` when relative, or a `file://` address, either
--- naming its line by a `#L<line>` at its end, opens as `M.open_file()`
--- opens a file; an address of any other scheme, such as a web link, goes
--- to the operating system.
---
---@param text string
---@param line integer?
---@param context aineo.entry.LinkContext
function M.open_link(text, line, context)
  if text:match(ADDRESS) and not vim.startswith(text, FILE_ADDRESS) then
    open_with_system(text)
    return
  end
  local path, line_named = text:match(LINE_FRAGMENT)
  path = path or text
  if vim.startswith(path, FILE_ADDRESS) then
    path = vim.uri_to_fname(path)
  end
  local file = vim.startswith(path, '/') and path or vim.fs.joinpath(context.directory, path)
  local stat = vim.uv.fs_stat(file)
  if not stat then
    vim.notify(('aineo: %s names no file'):format(text), vim.log.levels.WARN)
    return
  end
  if stat.type ~= 'file' then
    open_with_system(file)
    return
  end
  M.open_file(file, tonumber(line_named) or line, context.project)
end

--- The link that covers byte `byte`, from 0, of line `row`, from 0, of
--- `buffer` (`aineo.report`'s `find_path_candidates()`), or nil.
---
---@param buffer integer
---@param row integer
---@param byte integer
---@return aineo.report.PathCandidate?
local function link_at(buffer, row, byte)
  local text = vim.api.nvim_buf_get_lines(buffer, row, row + 1, false)[1] or ''
  return vim.iter(require('aineo.report').find_path_candidates(text)):find(function(candidate)
    return candidate.first_column <= byte and byte < candidate.end_column
  end)
end

--- The link under the mouse in `buffer` (`link_at()`), or nil when the
--- mouse is on no text of a window showing `buffer`.
---
---@param buffer integer
---@return aineo.report.PathCandidate?
local function link_under_mouse(buffer)
  local mouse = vim.fn.getmousepos()
  if mouse.winid == 0 or mouse.line == 0 or vim.api.nvim_win_get_buf(mouse.winid) ~= buffer then
    return nil
  end
  return link_at(buffer, mouse.line - 1, mouse.column - 1)
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
function M.map_link_keys(buffer, follow)
  vim.keymap.set({ 'n', 't' }, '<2-LeftMouse>', function()
    local link = link_under_mouse(buffer)
    if not link then
      vim.api.nvim_feedkeys(vim.keycode('<2-LeftMouse>'), 'ni', false)
      return
    end
    vim.cmd.stopinsert()
    follow(link.path, link.line)
  end, { buffer = buffer, desc = 'aineo: open the link under the mouse' })
  vim.keymap.set('n', 'gx', function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local link = link_at(buffer, cursor[1] - 1, cursor[2])
    if link then
      follow(link.path, link.line)
    end
  end, { buffer = buffer, desc = 'aineo: open the link under the cursor' })
end

return M
