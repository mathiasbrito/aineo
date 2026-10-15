--- The tab pages aineo shows a Claude Code session in: which tab pages are
--- held, what their titles say, the tab line that draws them, and the
--- folder's ordered list of the tabs' sessions.
---
--- Requires no other aineo home: the form check and the write of the
--- folder's list are this home's own (`tab_list.lua`).

local tab_lists = require('aineo.tabs.tab_list')
local tabline_format = require('aineo.tabs.tabline')
local titles = require('aineo.tabs.titles')

local M = {}

--- The 'tabline' value that has Neovim ask `tabline()` for the line each time
--- it draws it.
local TABLINE_EXPRESSION = "%!v:lua.require'aineo.tabs'.tabline()"

--- The name function of each held tab page, by the tab page's handle.
---
---@type table<integer, fun(): string|nil>
local name_of_held = {}

--- Whether `value` can be the handle of a tab page: 0 is not one, though the
--- API takes it for the current tab page.
---
---@param value any
---@return boolean
local function is_tab_page_handle(value)
  return type(value) == 'number' and value >= 1
end

--- Holds the tab page `tab`. Its title says `name()`, asked each time the
--- title is drawn. A tab page held again takes the new `name`.
---
--- Raises an error when `tab` is not a tab page handle (a number from 1) or
--- `name` is not a function.
---
---@param tab integer a tab page handle
---@param name fun(): string|nil
function M.hold(tab, name)
  vim.validate('tab', tab, is_tab_page_handle, 'a tab page handle')
  vim.validate('name', name, 'function')
  name_of_held[tab] = name
end

--- Lets the tab page `tab` go: it is held no more. A tab page that is not
--- held is let go without a word.
---
---@param tab integer a tab page handle
function M.let_go(tab)
  vim.validate('tab', tab, 'number')
  name_of_held[tab] = nil
end

--- The held tab pages that still exist, in the order of their places.
---
---@return integer[] handles
function M.held()
  return vim.tbl_filter(function(tab)
    return name_of_held[tab] ~= nil
  end, vim.api.nvim_list_tabpages())
end

--- Each held tab page that no longer exists, in the order of their handles,
--- let go: a second call gives none of them again. A tab page that
--- `:tabmove` moved still exists, with the same handle and another place,
--- and is not among them.
---
---@return integer[] handles
function M.closed()
  local closed = {}
  for tab in pairs(name_of_held) do
    if not vim.api.nvim_tabpage_is_valid(tab) then
      table.insert(closed, tab)
    end
  end
  table.sort(closed)
  for _, tab in ipairs(closed) do
    name_of_held[tab] = nil
  end
  return closed
end

--- The place of the tab page `tab`, as `{n}gt` counts it: 1 for the
--- leftmost. It follows `:tabmove` and the close of a tab page before it.
--- Held or not.
---
---@param tab integer a tab page handle
---@return integer|nil number nil when no such tab page exists
function M.number(tab)
  vim.validate('tab', tab, 'number')
  if not vim.api.nvim_tabpage_is_valid(tab) then
    return nil
  end
  return vim.api.nvim_tabpage_get_number(tab)
end

--- What the name function of the held tab page `tab` gives, or nil when
--- `tab` is not held or its function gives no text. A function that raises,
--- or gives text with a NUL in it, gives none too: the tab line is drawn on
--- every redraw, and an error there would repeat on each one.
---
---@param tab integer a tab page handle
---@return string|nil
local function name_of_held_tab(tab)
  local name_of = name_of_held[tab]
  if not name_of then
    return nil
  end
  local succeeded, name = pcall(name_of)
  if succeeded and type(name) == 'string' and name ~= '' and not name:find('\0', 1, true) then
    return name
  end
  return nil
end

--- The title of the tab page `tab`: its place and a name, `<number>: <name>`.
--- The name is what the held tab's name function gives, else the tail of the
--- name of the buffer in the tab page's current window, and is cut to fit; the
--- cut counts the name alone.
---
---@param tab integer a tab page handle
---@return string|nil title nil when no such tab page exists
function M.title(tab)
  local number = M.number(tab)
  if not number then
    return nil
  end
  return ('%d: %s'):format(number, titles.cut(name_of_held_tab(tab) or titles.buffer_tail(tab)))
end

--- The 'tabline' format that draws the title of every tab page, each in the
--- click region of its tab page, the current tab page's in `TabLineSel`, the
--- others' in `TabLine`, and the rest of the line in `TabLineFill`.
---
---@return string
function M.tabline()
  local current = vim.api.nvim_get_current_tabpage()
  local entries = {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    table.insert(entries, {
      number = vim.api.nvim_tabpage_get_number(tab),
      title = M.title(tab),
      current = tab == current,
    })
  end
  return tabline_format.format(entries, vim.o.columns)
end

--- Keeps `tab_list` as the list of the tabs of `folder`: the sessions of its
--- tabs in the order of the tabs' places, and the place of the tab that is
--- current. It goes into a file of its own under `state_directory`, readable
--- by the user alone, written whole or not at all. The session id kept for
--- the folder is another file and stays as it is. Only a list `kept_tabs()`
--- would give back is written.
---
--- Raises an error naming the file when `tab_list` is no such list, or when
--- the file cannot be written.
---
---@param state_directory string
---@param folder string
---@param tab_list aineo.tabs.TabList
function M.keep_tabs(state_directory, folder, tab_list)
  vim.validate('state_directory', state_directory, 'string')
  vim.validate('folder', folder, 'string')
  vim.validate('tab_list', tab_list, 'table')
  tab_lists.write_tab_list(state_directory, folder, tab_list)
end

--- The list kept for the tabs of `folder` by `keep_tabs()`: its sessions in
--- the same order, and its current place. Nil when none is kept: no file, an
--- unreadable one, one that is not a non-empty list of distinct session ids
--- (each a lower-case version-4 UUID, since each becomes an argument to
--- `--resume`, and no two tabs showing one session) with a place in it. A
--- list kept for another folder is not read.
---
--- Raises nothing.
---
---@param state_directory string
---@param folder string
---@return aineo.tabs.TabList|nil
function M.kept_tabs(state_directory, folder)
  if type(state_directory) ~= 'string' or type(folder) ~= 'string' then
    return nil
  end
  return tab_lists.read_tab_list(state_directory, folder)
end

--- Has Neovim draw aineo's tab line while the user's 'tabline' is empty; a
--- 'tabline' the user set is left in place. Called again, it changes nothing.
--- It never touches 'showtabline', so the line shows from two tab pages on
--- unless the user chose otherwise.
---
---@return boolean in_use whether 'tabline' draws aineo's line
function M.draw_tabline()
  if vim.o.tabline == '' then
    vim.o.tabline = TABLINE_EXPRESSION
  end
  return vim.o.tabline == TABLINE_EXPRESSION
end

return M
