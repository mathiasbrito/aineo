--- The tab pages aineo shows a Claude Code session in: which tab pages are
--- held, what their titles say, what their Claude Codes are doing, the tab
--- line that draws them, and the folder's ordered list of the tabs' sessions.
---
--- Requires `aineo.config` alone, for the padding of the titles and whether
--- the line always shows: the form
--- check and the write of the folder's list are this home's own
--- (`tab_list.lua`), and so are the activity of the tabs (`activity.lua`)
--- and the clock that animates it (`animation.lua`).

local config = require('aineo.config')
local activities = require('aineo.tabs.activity')
local animation = require('aineo.tabs.animation')
local highlights = require('aineo.tabs.highlights')
local tab_lists = require('aineo.tabs.tab_list')
local tabline_format = require('aineo.tabs.tabline')
local titles = require('aineo.tabs.titles')

local M = {}

--- The 'tabline' value that has Neovim ask `tabline()` for the line each time
--- it draws it.
local TABLINE_EXPRESSION = "%!v:lua.require'aineo.tabs'.tabline()"

--- Whether `show_tabline_once()` has been called.
local tabline_shown_once = false

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

--- Whether the tab page `tab` is held and still exists.
---
---@param tab integer a tab page handle
---@return boolean
local function is_live_held(tab)
  return name_of_held[tab] ~= nil and vim.api.nvim_tabpage_is_valid(tab)
end

--- Has the tab line drawn again on the main loop's next turn, so that a
--- caller inside a variable's watcher, as the one that tells the busy state
--- is, draws nothing from within it.
local function redraw_tabline_soon()
  vim.schedule(function()
    vim.cmd.redrawtabline()
  end)
end

--- Has the animation run while a held tab page is busy, and not otherwise.
--- Each frame draws the tab line again, and the animation ends at the frame
--- that finds no busy tab page left, such as one that closed unheard of.
local function keep_animation_for_busy_tabs()
  if not activities.any_busy(is_live_held) then
    animation.stop()
    return
  end
  animation.run(function()
    if activities.any_busy(is_live_held) then
      vim.cmd.redrawtabline()
    else
      animation.stop()
    end
  end)
end

--- Lets the tab page `tab` go: it is held no more, and it has no activity.
--- A tab page that is not held is let go without a word.
---
---@param tab integer a tab page handle
function M.let_go(tab)
  vim.validate('tab', tab, 'number')
  name_of_held[tab] = nil
  activities.forget(tab)
  keep_animation_for_busy_tabs()
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
    activities.forget(tab)
  end
  keep_animation_for_busy_tabs()
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

--- Tells that the Claude Code of the held tab page `tab` is busy, or is not
--- any more. A tab page that is busy has the activity `busy`. One that stops
--- being busy while the user is in another tab page has the activity
--- `unseen`, until `mark_seen()`; in the current tab page, none. The tab line
--- is drawn again at once, and an animation of it runs while any held tab
--- page is busy. A tab page that is not held, or does not exist, is left as
--- it is.
---
--- Raises an error when `tab` is not a tab page handle (a number from 1) or
--- `busy` is not a boolean.
---
---@param tab integer a tab page handle
---@param busy boolean
function M.set_busy(tab, busy)
  vim.validate('tab', tab, is_tab_page_handle, 'a tab page handle')
  vim.validate('busy', busy, 'boolean')
  if not is_live_held(tab) then
    return
  end
  activities.tell_busy(tab, busy, tab ~= vim.api.nvim_get_current_tabpage())
  keep_animation_for_busy_tabs()
  redraw_tabline_soon()
end

--- Tells that the user saw the held tab page `tab`: its `unseen` activity is
--- gone, and the tab line is drawn again. A `busy` one goes on.
---
--- Raises an error when `tab` is not a tab page handle (a number from 1).
---
---@param tab integer a tab page handle
function M.mark_seen(tab)
  vim.validate('tab', tab, is_tab_page_handle, 'a tab page handle')
  if not is_live_held(tab) then
    return
  end
  activities.mark_seen(tab)
  redraw_tabline_soon()
end

--- What the Claude Code of the held tab page `tab` is doing: `busy` while it
--- works, `unseen` once it stopped while the user was in another tab page
--- and until `mark_seen()`, nil otherwise, and for a tab page that is not
--- held or does not exist.
---
--- Raises an error when `tab` is not a tab page handle (a number from 1).
---
---@param tab integer a tab page handle
---@return 'busy'|'unseen'|nil
function M.activity(tab)
  vim.validate('tab', tab, is_tab_page_handle, 'a tab page handle')
  if not is_live_held(tab) then
    return nil
  end
  return activities.of(tab)
end

--- The name of the tab page `tab`: what the held tab's name function gives,
--- else the tail of the name of the buffer in the tab page's current window.
---
---@param tab integer a tab page handle of a tab page that exists
---@return string
local function name_of_tab(tab)
  return name_of_held_tab(tab) or titles.buffer_tail(tab)
end

--- The title of the tab page `tab`: its place and a name, `<number>: <name>`,
--- then a space and the indicator of its activity: ◒ or ◓ while it is busy,
--- by the frame of the animation, ● while it is unseen. The name is what the
--- held tab's name function gives, else the tail of the name of the buffer in
--- the tab page's current window, and is whole: aineo's own tab line cuts
--- names when it has no room for them (`tabline()`).
---
---@param tab integer a tab page handle
---@return string|nil title nil when no such tab page exists
function M.title(tab)
  local number = M.number(tab)
  if not number then
    return nil
  end
  return titles.title_of(number, name_of_tab(tab), activities.indicator(tab, animation.glyph()))
end

--- The `tabs` settings, as `vim.g.aineo` and the options
--- `require('aineo').setup()` recorded give them; their defaults when those
--- give a wrong value, which `:checkhealth aineo` reports, so that a redraw
--- of the line never raises.
---
---@return { padding: integer, always_show: boolean }
local function tabs_settings()
  local is_valid, resolved =
    pcall(config.resolve_config, vim.g.aineo, config.recorded_setup_options())
  if not is_valid then
    return config.resolve_config(nil, nil).tabs
  end
  return resolved.tabs
end

--- The `tabs.padding` setting (`tabs_settings()`).
---
---@return integer
local function padding()
  return tabs_settings().padding
end

--- The 'tabline' format that draws the title of every tab page, each in the
--- click region of its tab page with `tabs.padding` spaces either side, the
--- current tab page's in `AineoTabLineSel`, the others' in `AineoTabLine`,
--- and the rest of the line in `AineoTabLineFill`. Names are whole while the
--- titles fit the line; when they do not, `tabline_format.format()` cuts the
--- longest first. A control character in a name is drawn as `^X`, and is
--- counted so.
---
---@return string
function M.tabline()
  local current = vim.api.nvim_get_current_tabpage()
  local entries = {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    table.insert(entries, {
      number = vim.api.nvim_tabpage_get_number(tab),
      name = vim.fn.strtrans(name_of_tab(tab)),
      indicator = activities.indicator(tab, animation.glyph()),
      current = tab == current,
    })
  end
  return tabline_format.format(entries, vim.o.columns, padding())
end

--- The list of `placed`, the editor's tabs in the order of their places: the
--- session of each tab that has one, a session two tabs show listed once, at
--- the lower place (no two tabs of a list show one session); and the place of
--- the tab flagged current, or of the one that shows its session first, else
--- the first. What `keep_tabs()` keeps. Nil when no tab has a session.
---
---@param placed aineo.tabs.PlacedTab[]
---@return aineo.tabs.TabList|nil
function M.list_of_tabs(placed)
  vim.validate('placed', placed, 'table')
  return tab_lists.list_of_placed_tabs(placed)
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

--- The most tabs a Neovim reopens at once.
M.MAX_REOPENED_TABS = 20

--- The tabs a Neovim reopens in `folder`: the list kept for it
--- (`kept_tabs()`) when it holds `kept_session`, the session kept for the
--- folder as the one the next start lands in, cut to its first
--- `MAX_REOPENED_TABS` sessions with its place kept within them; and the
--- sessions cut off, in order (none for a short list). Nil when no list is
--- kept, the list lacks that session, or none is kept for the folder: one tab
--- then opens on the kept session, as before the list was kept.
---
--- Raises nothing.
---
---@param state_directory string
---@param folder string
---@param kept_session string|nil
---@return aineo.tabs.TabList|nil
---@return string[]|nil left
function M.tabs_to_reopen(state_directory, folder, kept_session)
  local list = kept_session and M.kept_tabs(state_directory, folder)
  if not (list and vim.tbl_contains(list.sessions, kept_session)) then
    return nil
  end
  local reopened = vim.list_slice(list.sessions, 1, M.MAX_REOPENED_TABS)
  local left = vim.list_slice(list.sessions, M.MAX_REOPENED_TABS + 1)
  return { sessions = reopened, current = math.min(list.current, #reopened) }, left
end

--- Has Neovim draw aineo's tab line while the user's 'tabline' is empty; a
--- 'tabline' the user set is left in place. When it is aineo's, its highlight
--- groups are defined (`AineoTabLineSel`, `AineoTabLine` and
--- `AineoTabLineFill`, none that the user defined) and again after every
--- `:colorscheme`. Called again, it changes nothing.
--- It never touches 'showtabline' (`show_tabline_once()` does).
---
---@return boolean in_use whether 'tabline' draws aineo's line
function M.draw_tabline()
  if vim.o.tabline == '' then
    vim.o.tabline = TABLINE_EXPRESSION
  end
  local in_use = vim.o.tabline == TABLINE_EXPRESSION
  if in_use then
    highlights.keep_defined()
  end
  return in_use
end

--- The first time it is called, sets 'showtabline' to 2, so that the tab line
--- shows with a single tab page, when `tabs.always_show` holds; with it
--- `false` it leaves 'showtabline' as it is. Every later call does nothing,
--- so that a 'showtabline' the user sets afterwards is kept, and nothing sets
--- it back when the tabs close.
function M.show_tabline_once()
  if tabline_shown_once then
    return
  end
  tabline_shown_once = true
  if tabs_settings().always_show then
    vim.o.showtabline = 2
  end
end

return M
