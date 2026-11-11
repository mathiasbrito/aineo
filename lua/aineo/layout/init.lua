--- aineo's layout, `require('aineo.layout')`: the Claude terminal in a column
--- on one side of the screen (the left by default, `Arrangement.claude_side`),
--- and across the screen from it the panes column — "the right column" in
--- this file, whichever side it is on — whose windows show one pane at
--- a time — the agent pane, the Report above Input; the changes pane; the
--- terminal pane, a shell's terminal in the Report's window alone, taking the
--- whole column, with Input's window closed while the pane shows; the run
--- pane, a stack of terminals taking the whole column, the first in the
--- Report's window and each next in a window of its own below it; or the
--- explorer pane, a tree of files in the Report's window alone, taking the
--- whole column, Input's window closed as under the terminal pane; or the
--- walkthrough pane, the plan of a code walkthrough in the Report's window
--- with Input's window kept below it. Beside these columns the layout can
--- hold a column of the explorer's tree, at the outer edge of one side of the
--- screen, as tall as the screen, whichever side Claude's column is on. The
--- file focus closes the panes column and gives its cells to the file column
--- (`M.start_file_focus()`).
---
--- The layout shows the Claude and Report buffers, the changes pane's, the
--- shell's terminal, the run pane's terminals, and the diffs it is asked to
--- show in the file column, it is handed and never creates, writes or deletes
--- them; the Input buffer is its own.
---
--- A layout is all of that for one tab page: its three windows, Input, the
--- pane it shows, its proportions, Claude's line numbers and status line,
--- and the handlers that keep them. The module itself is one layout, made
--- when it loads, with the Input `aineo://input` and the handler group
--- `aineo.layout`: its functions are the functions of a layout, and every
--- caller of the module acts on it. `M.new()` makes another, whose functions
--- are called as fields too, with an Input of its own and handlers that act
--- on its own windows and buffers only.

local columns = require('aineo.layout.columns')
local fresh_size = require('aineo.layout.fresh_size')
local full_zoom = require('aineo.layout.full_zoom')
local gutter = require('aineo.layout.gutter')
local side = require('aineo.layout.side')
local zoom = require('aineo.layout.zoom')

---@class aineo.layout.Arrangement
---@field claude integer the Claude session's terminal buffer
---@field report integer the Report buffer
---@field report_height number the Report's share of the right column's height, strictly between 0 and 1
---@field claude_side? aineo.layout.Side the side of the screen Claude's column is on, the right column across from it; without it the layout keeps the side its columns are on, the left before any was handed
---@field changes? aineo.layout.ChangesPane the changes pane's buffers; without them the layout keeps those it was handed last
---@field shell? integer the terminal pane's buffer, the terminal of a shell, shown alone in the right column, in the Report's window; without it the layout keeps the one it was handed last, if its shell lives
---@field run? aineo.layout.RunPane the run pane's terminals; without them the run pane has nothing to show, and the layout shows the agent pane in its place
---@field explorer? integer the explorer pane's buffer, the tree of the folder Claude works in, shown alone in the right column, in the Report's window; without it the layout keeps the one it was handed last
---@field explorer_column? aineo.layout.Side|false the side of the screen the explorer column is on, a column of its own the full height of the screen beside the other columns showing `explorer`, whichever side Claude's column is on; `false` for none; without it the layout keeps what it was handed last, none before any
---@field explorer_width? integer the explorer column's width in cells, a positive whole number; without it the layout keeps the one it was handed last, and a side for the column needs one
---@field file_beside_explorer? boolean whether the file column lies beside the explorer column while that column is open, on its inner side, rather than between Claude's column and the right column; without it the layout keeps what it was handed last, false before any
---@field panel_numbers? boolean whether the layout's panels, its windows that show no file, show the user's own line numbers, sign column, fold column and status column; without it the layout keeps what it was handed last, false before any, which leaves them only the separator between windows
---@field walkthrough? integer the walkthrough pane's buffer, the plan of a code walkthrough, shown in the Report's window above Input's; without it the layout keeps the one it was handed last
---@field claude_statusline? string the 'statusline' Claude's window draws for Claude's terminal; without it the layout keeps the one it was handed last, and before any, Claude's window draws the user's own

---@class aineo.layout.ChangesPane
---@field files integer the buffer the changes pane shows in the Report's window
---@field commits integer the buffer the changes pane shows in Input's window

---@class aineo.layout.RunPane
---@field buffers integer[] the terminals the run pane stacks, top to bottom, at least one: the first in the Report's window, each next in a window of its own below it
---@field winbar string the 'winbar' each of the run pane's windows draws for its terminal

---@alias aineo.layout.Role 'claude'|'report'|'input'

--- The file focus of a layout, while it is on. Armed, it waits for a file
--- column and changes nothing; applied, the panes column is closed and its
--- cells are the file column's.
---@class aineo.layout.FileFocus
---@field applied boolean whether the panes column is closed
---@field claude_width? integer the width Claude's column has while the focus waits, and keeps once it is applied; none when Claude's window is closed
---@field views? table<integer, table> the view each window of the panes column had as the focus was applied, by the buffer it showed (`winsaveview()`)

--- A rectangle of the screen, in cells counted from the top left of the editor, from 0.
---@class aineo.layout.Area
---@field row integer the first row
---@field col integer the first column
---@field width integer
---@field height integer

---@alias aineo.layout.Pane 'agent'|'changes'|'terminal'|'run'|'explorer'|'walkthrough'

---@class aineo.layout.LineNumbers
---@field number boolean the window's 'number'
---@field relativenumber boolean the window's 'relativenumber'

--- The functions of a layout, as the module and `M.new()` give them.
---@class aineo.layout.Layout
---@field open fun(arrangement: aineo.layout.Arrangement)
---@field focus fun(role: aineo.layout.Role, arrangement: aineo.layout.Arrangement|fun(): aineo.layout.Arrangement)
---@field show_pane fun(pane: aineo.layout.Pane, arrangement: aineo.layout.Arrangement|fun(): aineo.layout.Arrangement)
---@field focus_pane fun(pane: aineo.layout.Pane, arrangement: aineo.layout.Arrangement|fun(): aineo.layout.Arrangement)
---@field shown_pane fun(): aineo.layout.Pane
---@field can_show_pane_in_place fun(pane: aineo.layout.Pane): boolean
---@field keep_pane_buffer fun(pane: aineo.layout.Pane, buffer: integer)
---@field show_diff fun(diff: integer): integer|nil
---@field show_file fun(file: integer): integer|nil
---@field is_file_column_window fun(window: integer): boolean
---@field follow_claude_terminal fun(terminal: integer)
---@field toggle_claude_numbers fun()
---@field panel_numbers fun(): boolean
---@field set_panel_numbers fun(panel_numbers: boolean)
---@field toggle_zoom fun()
---@field toggle_full_zoom fun()
---@field is_zoomed fun(): boolean
---@field input_buffer fun(): integer|nil
---@field right_column_area fun(): aineo.layout.Area|nil
---@field claude_side fun(): aineo.layout.Side
---@field set_claude_side fun(claude_side: aineo.layout.Side)
---@field set_column_sides fun(claude_side: aineo.layout.Side, explorer_side?: aineo.layout.Side)
---@field explorer_column fun(): aineo.layout.Side|false
---@field focus_explorer_column fun(arrangement: aineo.layout.Arrangement|fun(): aineo.layout.Arrangement)
---@field set_explorer_column fun(explorer_column: aineo.layout.Side|false, explorer_width: integer, file_beside_explorer?: boolean)
---@field explorer_column_is_open fun(): boolean
---@field reopen_explorer_column fun()
---@field start_file_focus fun()
---@field end_file_focus fun(arrangement: aineo.layout.Arrangement|fun(): aineo.layout.Arrangement)
---@field is_file_focused fun(): boolean
---@field let_go? fun() only on a layout `M.new()` made: removes its handlers and wipes its Input

--- Makes a layout: its state, and the functions that act on it, and the
--- function that lets it go (`let_go()`).
---
--- What a layout holds once for the editor is named for it: `input_name`, the
--- name of its Input buffer, which is not a file path, so `:edit` never takes
--- the buffer for one and no other buffer of the editor may hold it, and
--- `group_name`, the autocommand group of its handlers, which Neovim clears
--- when it is made again, as opening the layout again does.
---
---@param input_name string
---@param group_name string
---@return aineo.layout.Layout layout
---@return fun() let_go removes the layout's handlers and wipes its Input
local function make_layout(input_name, group_name)
  local M = {}

  --- The side of the screen Claude's column is on, the right column across
  --- from it and the file column between; the layout's windows, by role, and
  --- the buffers they show, by role or, for the changes pane's and the
  --- shell's, by name; the pane the right column
  --- shows, for the editor's life; the Report and its `b:changedtick` as they
  --- were when the agent pane was hidden, until the agent pane shows again
  --- with the Report in the Report's window;
  --- the view each buffer a switch took out of the right column had there,
  --- by buffer, until a switch shows it again (`show_in_place()`);
  --- the Report's share of the right column's height, Claude's
  --- terminal once Neovim has seen its process end, the line numbers
  --- `M.toggle_claude_numbers()` last set in Claude's window, those it showed
  --- before it hid them, and the window and buffer those line numbers were
  --- last shown for; whether the panels show the user's own gutter
  --- (`M.set_panel_numbers()`); the status line Claude's window draws for
  --- Claude's terminal, the one handed last; the diffs `M.show_diff()` showed, by
  --- buffer; while the Report's window closes with the shell's terminal in
  --- it, whether the cursor was in that window, and the ID of such a window
  --- that closed on its own (`note_shell_window_closing()`); whether Input's
  --- window was already closed when the terminal pane took the column, which
  --- the agent pane then leaves closed as the shell ends; the terminals and
  --- winbar the run pane was handed last, and the windows it opened below
  --- the Report's, top to bottom; the zoom of the right column, if it is
  --- zoomed (`M.toggle_zoom()`); the window zoomed fully, if one is
  --- (`M.toggle_full_zoom()`); and the file focus, while it is on, with the
  --- width Claude's column keeps and the views the panes column's windows
  --- had (`M.start_file_focus()`).
  local state = {
    ---@type aineo.layout.Side
    claude_side = side.DEFAULT,
    ---@type table<aineo.layout.Role, integer>
    windows = {},
    ---@type table<aineo.layout.Role|'files'|'commits'|'shell'|'run'|'explorer'|'walkthrough', integer>
    buffers = {},
    ---@type aineo.layout.Pane
    pane = 'agent',
    ---@type { buffer: integer, tick: integer }|nil
    report_when_hidden = nil,
    ---@type table<integer, table>
    views = {},
    ---@type number|nil
    report_height = nil,
    ---@type integer|nil
    ended_claude_terminal = nil,
    ---@type aineo.layout.LineNumbers|nil
    claude_numbers = nil,
    ---@type aineo.layout.LineNumbers|nil
    claude_numbers_before_hiding = nil,
    ---@type { window: integer, buffer: integer }|nil
    claude_numbers_shown_in = nil,
    ---@type string|nil
    claude_statusline = nil,
    ---@type table<integer, true>
    diffs = {},
    ---@type { had_cursor: boolean }|nil
    closing_shell_window = nil,
    ---@type integer|nil
    left_closed_shell_window = nil,
    ---@type boolean|nil
    input_closed_by_user = nil,
    ---@type aineo.layout.RunPane|nil
    run = nil,
    ---@type integer[]
    run_windows = {},
    ---@type aineo.layout.Zoom|nil
    zoom = nil,
    ---@type aineo.layout.FullZoom|nil
    full_zoom = nil,
    ---@type aineo.layout.FileFocus|nil
    file_focus = nil,
    ---@type aineo.layout.Side|false
    explorer_column = false,
    ---@type integer|nil
    explorer_width = nil,
    ---@type integer|nil
    explorer_window = nil,
    ---@type boolean
    file_beside_explorer = false,
    ---@type boolean
    panel_numbers = false,
    ---@type aineo.layout.FilePart[]|nil
    file_parts = nil,
    ---@type uv.uv_timer_t|nil
    fresh_size_timer = nil,
  }

  --- The role of `window` in the layout, or `nil` when it is not one of its
  --- three windows.
  ---
  ---@param window integer
  ---@return aineo.layout.Role|nil role
  local function role_of(window)
    for role, layout_window in pairs(state.windows) do
      if layout_window == window then
        return role
      end
    end
    return nil
  end

  ---@type aineo.layout.Role[]
  local ROLES = { 'claude', 'report', 'input' }

  --- What the layout tells the user, as a warning, when the screen has no room
  --- for the windows of `%d` of the run pane's terminals, which stay hidden.
  local NO_ROOM_FOR_RUN =
    'aineo: the run pane has no room for %d more terminals; they run on, hidden'

  --- The roles of the right column's two windows, which show one pane at a
  --- time.
  ---@type aineo.layout.Role[]
  local RIGHT_COLUMN_ROLES = { 'report', 'input' }

  --- The buffer each pane shows in each of the right column's windows it
  --- shows, named as `state.buffers` keys them, by the window's role. The
  --- terminal, run and explorer panes show one window, the Report's, and none
  --- for Input; the walkthrough pane shows its own buffer in the Report's
  --- window and Input in Input's; the run pane opens more windows below the
  --- Report's, which are no role of the layout.
  ---@type table<aineo.layout.Pane, table<aineo.layout.Role, string>>
  local PANE_BUFFERS = {
    agent = { report = 'report', input = 'input' },
    changes = { report = 'files', input = 'commits' },
    terminal = { report = 'shell' },
    run = { report = 'run' },
    explorer = { report = 'explorer' },
    walkthrough = { report = 'walkthrough', input = 'input' },
  }

  --- The roles of the right column's windows `pane` shows, the Report's
  --- first.
  ---
  ---@param pane aineo.layout.Pane
  ---@return aineo.layout.Role[] roles
  local function pane_roles(pane)
    return vim.tbl_filter(function(role)
      return PANE_BUFFERS[pane][role] ~= nil
    end, RIGHT_COLUMN_ROLES)
  end

  --- The buffer the layout's window for `role` shows as its own: Claude's
  --- terminal in Claude's window, and the shown pane's buffer for that window
  --- in the right column's two.
  ---
  ---@param role aineo.layout.Role
  ---@return integer buffer
  local function own_buffer(role)
    return state.buffers[PANE_BUFFERS[state.pane][role] or role]
  end

  --- Whether the layout's window for `role` exists.
  ---
  ---@param role aineo.layout.Role
  ---@return boolean
  local function has_window(role)
    local window = state.windows[role]
    return window ~= nil and vim.api.nvim_win_is_valid(window)
  end

  --- Whether the layout's window for `role` exists and the role's own buffer
  --- — Claude's terminal, the Report or Input — was not wiped, whatever buffer
  --- the window shows, the changes pane's included: a window left on another
  --- buffer after the role's own was wiped counts as gone.
  ---
  ---@param role aineo.layout.Role
  ---@return boolean
  local function has_window_and_buffer(role)
    return has_window(role) and vim.api.nvim_buf_is_valid(state.buffers[role])
  end

  --- Whether the layout is open: Claude's window and the windows of the pane
  --- shown exist, the three under the agent and changes panes, and not Input's
  --- under the terminal pane.
  ---
  ---@return boolean
  local function is_open()
    return has_window('claude') and vim.iter(pane_roles(state.pane)):all(has_window)
  end

  --- Whether the file focus is applied: on, with the panes column closed on
  --- purpose (`M.start_file_focus()`).
  ---
  ---@return boolean
  local function is_file_focus_applied()
    return state.file_focus ~= nil and state.file_focus.applied
  end

  --- Whether the layout's windows are where it puts them: it is open
  --- (`is_open()`), or the file focus is applied, which leaves Claude's window
  --- and no panes column.
  ---
  ---@return boolean
  local function is_laid_out()
    return is_open() or (is_file_focus_applied() and has_window('claude'))
  end

  --- Whether any of the layout's three windows exists.
  ---
  ---@return boolean
  local function has_any_window()
    return vim.iter(ROLES):any(has_window)
  end

  --- Those of the layout's three windows that exist, Claude's first, then the
  --- Report's and Input's.
  ---
  ---@return integer[] windows
  local function existing_windows()
    return vim
      .iter(ROLES)
      :filter(has_window)
      :map(function(role)
        return state.windows[role]
      end)
      :totable()
  end

  --- The tab page holding the layout: the tab of its windows that exist. All of
  --- them are in one tab, since the layout reopens its windows there.
  ---
  ---@return integer tab
  local function layout_tab()
    return vim.api.nvim_win_get_tabpage(existing_windows()[1])
  end

  --- Whether `buffer` holds a file: a buffer with an empty `'buftype'`.
  ---
  ---@param buffer integer
  ---@return boolean
  local function is_file(buffer)
    return vim.bo[buffer].buftype == ''
  end

  --- The window standing for the right column: the Report's, or Input's when
  --- the Report's is closed, or the first window the run pane opened below
  --- the Report's when both are; `nil` when there is none.
  ---
  ---@return integer|nil window
  local function right_column_window()
    if has_window('report') then
      return state.windows.report
    end
    if has_window('input') then
      return state.windows.input
    end
    return vim.iter(state.run_windows):find(vim.api.nvim_win_is_valid)
  end

  --- The direction that splits a window to the outer edge of the screen on
  --- Claude's side, which is the side Claude's column is on.
  ---
  ---@return aineo.layout.Side
  local function claude_edge()
    return state.claude_side
  end

  --- The direction that splits a window to the outer edge of the screen on
  --- the right column's side, across from Claude's.
  ---
  ---@return aineo.layout.Side
  local function right_column_edge()
    return side.opposite(state.claude_side)
  end

  --- Whether the explorer column's window exists.
  ---
  ---@return boolean
  local function has_explorer_column()
    return state.explorer_window ~= nil and vim.api.nvim_win_is_valid(state.explorer_window)
  end

  --- The file column's windows when it lies between Claude's column and the
  --- right one, top to bottom: those of the columns between them, in the row
  --- that holds the layout's windows, the explorer column's not among them;
  --- with Claude's window closed, those on the file side of the right column,
  --- and with both of the right column's closed, those on the file side of
  --- Claude's. None when no column lies there.
  ---
  ---@return integer[] windows
  local function centre_file_column_windows()
    local tree = vim.fn.winlayout(vim.api.nvim_tabpage_get_number(layout_tab()))
    local left = has_window('claude') and state.windows.claude or nil
    local right = right_column_window()
    if state.claude_side ~= 'left' then
      left, right = right, left
    end
    local between =
      columns.windows_between(tree, { held = existing_windows(), left = left, right = right })
    return vim.tbl_filter(function(window)
      return window ~= state.explorer_window
    end, between)
  end

  --- The window standing for the layout's column nearest the edge of the
  --- screen on `edge`: Claude's window when Claude's column is on that side,
  --- else the right column's; the other one when that is closed; `nil` when
  --- both are.
  ---
  ---@param edge aineo.layout.Side
  ---@return integer|nil window
  local function layout_column_window_nearest(edge)
    local claude_window = has_window('claude') and state.windows.claude or nil
    if state.claude_side == edge then
      return claude_window or right_column_window()
    end
    return right_column_window() or claude_window
  end

  --- The file column's windows when it lies beside the explorer column,
  --- top to bottom: those of the columns between the explorer column, or the
  --- edge of the screen when its window is closed, and the layout's column
  --- nearest it. None when the layout has no explorer column.
  ---
  ---@return integer[] windows
  local function file_column_windows_beside_explorer()
    if not state.explorer_column then
      return {}
    end
    local tree = vim.fn.winlayout(vim.api.nvim_tabpage_get_number(layout_tab()))
    local held = existing_windows()
    local explorer = nil
    if has_explorer_column() then
      explorer = state.explorer_window
      table.insert(held, explorer)
    end
    local nearest = layout_column_window_nearest(state.explorer_column)
    if state.explorer_column == 'left' then
      return columns.windows_between(tree, { held = held, left = explorer, right = nearest })
    end
    return columns.windows_between(tree, { held = held, left = nearest, right = explorer })
  end

  --- Whether the file column belongs beside the explorer column: the layout
  --- was handed the option and the explorer column is open.
  ---
  ---@return boolean
  local function wants_file_column_beside_explorer()
    return state.file_beside_explorer and state.explorer_column ~= false and has_explorer_column()
  end

  --- The file column's windows, top to bottom, wherever it lies: in the place
  --- it belongs, beside the explorer column or between Claude's column and the
  --- right one (`wants_file_column_beside_explorer()`), else in the other
  --- while it has not moved there yet (`keep_file_column_in_place()`). None
  --- when the file column is not open.
  ---
  ---@return integer[] windows
  local function file_column_windows()
    local beside, centre = file_column_windows_beside_explorer, centre_file_column_windows
    local in_place, elsewhere = centre, beside
    if wants_file_column_beside_explorer() then
      in_place, elsewhere = beside, centre
    end
    local windows = in_place()
    return #windows > 0 and windows or elsewhere()
  end

  --- Whether the file column is open.
  ---
  ---@return boolean
  local function has_file_column()
    return #file_column_windows() > 0
  end

  --- The file column's first window that may take a file or a diff: one
  --- showing a file or a diff `M.show_diff()` showed, not one of the layout's
  --- windows and without `'winfixbuf'`, so that neither another plugin's
  --- window in the file column's place, such as a sidebar, nor a layout window
  --- moved there is ever taken. `nil` when there is none.
  ---
  ---@return integer|nil window
  local function window_taking_files()
    return vim.iter(file_column_windows()):find(function(window)
      local buffer = vim.api.nvim_win_get_buf(window)
      return not role_of(window)
        and (is_file(buffer) or state.diffs[buffer] == true)
        and not vim.wo[window].winfixbuf
    end)
  end

  --- A column of the file column that the user split side by side: the first
  --- of its windows, and the width it had.
  ---@class aineo.layout.FilePart
  ---@field window integer
  ---@field width integer

  --- The columns of the file column, left to right, each with the first of its
  --- windows and its width: more than one when the user split the file column
  --- side by side.
  ---
  ---@return aineo.layout.FilePart[] parts
  local function file_column_parts()
    local by_left = {}
    for _, window in ipairs(file_column_windows()) do
      local left = vim.api.nvim_win_get_position(window)[2]
      by_left[left] = by_left[left]
        or { window = window, width = vim.api.nvim_win_get_width(window) }
    end
    local lefts = vim.tbl_keys(by_left)
    table.sort(lefts)
    return vim.tbl_map(function(left)
      return by_left[left]
    end, lefts)
  end

  --- Records the widths of the columns of a file column the user split side by
  --- side, for the sizing that follows (`size_file_column()`), unless they are
  --- recorded already: a window that opens or moves at the edge of the screen
  --- changes them before the columns are placed, so the first record is the
  --- one that counts. Does nothing while no window of the layout is open.
  local function remember_file_parts()
    if state.file_parts or not has_any_window() then
      return
    end
    local parts = file_column_parts()
    if #parts > 1 then
      state.file_parts = parts
    end
  end

  --- Gives the file column `width` cells in all. A file column the user split
  --- side by side gives each of its columns the share of the cells it had
  --- before the columns moved (`state.file_parts`, recorded by
  --- `place_columns()`), the separators between them taken out; one split that
  --- way and not moved keeps the widths the user gave it.
  ---
  ---@param width integer
  local function size_file_column(width)
    local parts = file_column_parts()
    if #parts == 1 then
      vim.api.nvim_win_set_width(parts[1].window, width)
      return
    end
    local before = state.file_parts
    if not before or #before ~= #parts then
      return
    end
    local cells = width - (#parts - 1)
    local total = vim.iter(before):fold(0, function(sum, part)
      return sum + part.width
    end)
    for index = 1, #parts - 1 do
      local share = math.max(1, math.floor(cells * before[index].width / total + 0.5))
      vim.api.nvim_win_set_width(parts[index].window, share)
    end
  end

  --- Sets the columns' widths once: the explorer column, when it is open,
  --- takes its width and a separator. Of the screen's columns that remain,
  --- with the file column open, Claude's column and the right one take a third
  --- each, the two separators taken out, and the file column the rest, set
  --- too, since a window next to a fixed one keeps whatever width a neighbour
  --- leaves it; without it, Claude's column takes half and the right one the
  --- rest.
  local function set_column_widths()
    local available = vim.o.columns
    if has_explorer_column() then
      vim.api.nvim_win_set_width(state.explorer_window, state.explorer_width)
      available = available - state.explorer_width - 1
    end
    if has_file_column() then
      local third = math.floor((available - 2) / 3)
      size_file_column(available - 2 * third - 2)
      vim.api.nvim_win_set_width(state.windows.claude, third)
      vim.api.nvim_win_set_width(state.windows.report, third)
    else
      vim.api.nvim_win_set_width(state.windows.claude, math.floor(available / 2))
    end
  end

  --- Sizes the columns (`set_column_widths()`), twice, since a window given
  --- its width takes the cells of its neighbours, which the next window then
  --- gives back, and forgets the widths of the file column's parts
  --- (`state.file_parts`) once they are given.
  local function size_columns()
    set_column_widths()
    set_column_widths()
    state.file_parts = nil
  end

  --- Sizes the columns while the file focus is on, once each of two passes,
  --- since a window given its width takes the cells of its neighbours: the
  --- explorer column, when it is open, takes its width and a separator,
  --- Claude's column the width it had as the focus began
  --- (`state.file_focus.claude_width`), and the file column the cells that
  --- remain, less the separator. Changes nothing without a file column or
  --- Claude's window.
  local function size_focused_columns()
    local claude_width = state.file_focus.claude_width
    if not (claude_width and has_window('claude') and has_file_column()) then
      return
    end
    for _ = 1, 2 do
      local available = vim.o.columns
      if has_explorer_column() then
        vim.api.nvim_win_set_width(state.explorer_window, state.explorer_width)
        available = available - state.explorer_width - 1
      end
      claude_width = math.min(claude_width, available - 2)
      vim.api.nvim_win_set_width(state.windows.claude, claude_width)
      size_file_column(available - claude_width - 1)
    end
    state.file_parts = nil
  end

  --- Gives the Report its share of the rows the Report and Input hold together.
  --- Needs both windows.
  local function size_right_column()
    local rows = vim.api.nvim_win_get_height(state.windows.report)
      + vim.api.nvim_win_get_height(state.windows.input)
    vim.api.nvim_win_set_height(state.windows.report, math.floor(rows * state.report_height + 0.5))
  end

  --- Keeps Neovim from resizing the layout's windows that exist when it makes
  --- windows equal (`:wincmd =`, `'equalalways'`).
  local function pin_windows()
    for _, window in ipairs(existing_windows()) do
      vim.wo[window].winfixwidth = true
      vim.wo[window].winfixheight = true
    end
  end

  --- The options that make a window wrap long lines between words, a wrapped
  --- line keeping its indent.
  local WORD_WRAP = { 'wrap', 'linebreak', 'breakindent' }

  --- Makes the Report's and Input's windows wrap long lines between words, a
  --- wrapped line keeping its indent, for the buffer each shows, as `:setlocal`
  --- does, while they show the agent pane: another buffer shown in either
  --- window, or in a window split from it, keeps the user's own settings —
  --- the changes pane's buffers included — and the Report and Input wrap again
  --- when they return to their windows.
  local function wrap_agent_pane()
    if state.pane ~= 'agent' then
      return
    end
    for _, role in ipairs(vim.tbl_filter(has_window, RIGHT_COLUMN_ROLES)) do
      for _, option in ipairs(WORD_WRAP) do
        vim.wo[state.windows[role]][0][option] = true
      end
    end
  end

  --- The line numbers of a window that shows none.
  ---@type aineo.layout.LineNumbers
  local NO_LINE_NUMBERS = { number = false, relativenumber = false }

  --- The line numbers Claude's window is given when the toggle shows line
  --- numbers it never hid.
  ---@type aineo.layout.LineNumbers
  local ABSOLUTE_LINE_NUMBERS = { number = true, relativenumber = false }

  --- The line numbers `window` shows.
  ---
  ---@param window integer
  ---@return aineo.layout.LineNumbers
  local function line_numbers(window)
    return { number = vim.wo[window].number, relativenumber = vim.wo[window].relativenumber }
  end

  --- Makes `window` show the line numbers `numbers` for the buffer it shows,
  --- as `:setlocal` does: another buffer shown later in `window`, or in a
  --- window split from it, shows the user's own.
  ---
  ---@param window integer
  ---@param numbers aineo.layout.LineNumbers
  local function show_line_numbers(window, numbers)
    vim.wo[window][0].number = numbers.number
    vim.wo[window][0].relativenumber = numbers.relativenumber
  end

  --- Makes `window` show the line numbers `M.toggle_claude_numbers()` last
  --- set, for the buffer it shows (`show_line_numbers()`), and remembers that
  --- window and that buffer as where they were last shown.
  ---
  ---@param window integer
  local function show_claude_numbers(window)
    show_line_numbers(window, state.claude_numbers)
    state.claude_numbers_shown_in = { window = window, buffer = vim.api.nvim_win_get_buf(window) }
  end

  --- Whether Claude's window shows Claude's terminal, after a toggle, and
  --- the toggle's line numbers were not yet shown there for that window and
  --- that terminal: the terminal is new, the window is, or the toggle was
  --- last shown there for another buffer.
  ---
  ---@return boolean
  local function misses_claude_numbers()
    local shown_in = state.claude_numbers_shown_in
    return state.claude_numbers ~= nil
      and has_window('claude')
      and vim.api.nvim_win_get_buf(state.windows.claude) == state.buffers.claude
      and not (
        shown_in
        and shown_in.window == state.windows.claude
        and shown_in.buffer == state.buffers.claude
      )
  end

  --- Makes Claude's window show, for Claude's terminal, the line numbers
  --- `M.toggle_claude_numbers()` last set, when they were not yet shown there
  --- for that window and that terminal (`misses_claude_numbers()`). Line
  --- numbers the user set by hand for the same terminal in the same window
  --- stay as they are.
  local function keep_claude_numbers()
    if misses_claude_numbers() then
      show_claude_numbers(state.windows.claude)
    end
  end

  --- Makes Claude's window draw, for Claude's terminal, the status line the
  --- layout was handed last, as `:setlocal` sets it: another buffer shown
  --- later in that window, or in a window split from it, draws the user's
  --- own. Does nothing before one was handed, or while Claude's window shows
  --- another buffer.
  local function keep_claude_statusline()
    if
      state.claude_statusline
      and has_window('claude')
      and vim.api.nvim_win_get_buf(state.windows.claude) == state.buffers.claude
    then
      vim.wo[state.windows.claude][0].statusline = state.claude_statusline
    end
  end

  --- Keeps Claude's line numbers (`keep_claude_numbers()`) and status line
  --- (`keep_claude_statusline()`) when Claude's terminal enters a window, as
  --- it does when the user brings it back into Claude's window by hand.
  ---
  ---@param event { buf: integer }
  local function keep_claude_window_on_entry(event)
    if event.buf == state.buffers.claude then
      keep_claude_numbers()
      keep_claude_statusline()
    end
  end

  --- The windows of the layout that are panels': those of its three roles,
  --- the explorer column's and the run pane's below the Report's, that exist.
  ---
  ---@return integer[] windows
  local function panel_windows()
    local windows = existing_windows()
    if state.explorer_window and vim.api.nvim_win_is_valid(state.explorer_window) then
      table.insert(windows, state.explorer_window)
    end
    return vim.list_extend(windows, vim.tbl_filter(vim.api.nvim_win_is_valid, state.run_windows))
  end

  --- The buffers the layout shows in its panels: Claude's terminal, the
  --- Report, Input, the changes pane's, the shell's, the explorer's, the
  --- walkthrough's and the run pane's terminals.
  ---
  ---@return integer[] buffers
  local function panel_buffers()
    local buffers = vim.tbl_values(state.buffers)
    return vim.list_extend(buffers, state.run and state.run.buffers or {})
  end

  --- Whether `window` is a panel: one of the layout's windows (`panel_windows()`),
  --- or a window of the layout's tab page that shows one of its buffers
  --- (`panel_buffers()`), as a window just opened for one does before the
  --- layout has recorded it.
  ---
  ---@param window integer
  ---@return boolean
  local function is_panel_window(window)
    if vim.list_contains(panel_windows(), window) then
      return true
    end
    return has_any_window()
      and vim.api.nvim_win_get_tabpage(window) == layout_tab()
      and vim.list_contains(panel_buffers(), vim.api.nvim_win_get_buf(window))
  end

  --- Whether Claude's window keeps the line numbers `M.toggle_claude_numbers()`
  --- set, which the panels' gutter leaves as they are.
  ---
  ---@param window integer
  ---@return boolean
  local function keeps_claude_numbers(window)
    return window == state.windows.claude and state.claude_numbers ~= nil
  end

  --- Takes the gutter out of the panel `window` while it shows a panel's buffer
  --- and the panels' numbers are off (`state.panel_numbers`). A file shown in
  --- the window has the user's own: the options are set for the buffer the
  --- window shows, as `:setlocal` does, and Neovim gives a buffer shown for
  --- the first time the window's global values.
  ---
  ---@param window integer
  local function keep_panel_gutter(window)
    if state.panel_numbers or not gutter.is_panel_buffer(vim.api.nvim_win_get_buf(window)) then
      return
    end
    gutter.hide(window, keeps_claude_numbers(window))
  end

  --- Keeps the gutter of every panel (`keep_panel_gutter()`).
  local function keep_panel_gutters()
    vim.iter(panel_windows()):each(keep_panel_gutter)
  end

  --- Gives every panel the gutter the panels' numbers ask for, as they were
  --- just turned on or off: the user's own to each panel that shows a panel's
  --- buffer once they are on (`keep_panel_gutter()` leaves it as it is), none
  --- once they are off.
  local function restyle_panel_gutters()
    for _, window in ipairs(panel_windows()) do
      if state.panel_numbers and gutter.is_panel_buffer(vim.api.nvim_win_get_buf(window)) then
        gutter.show(window, keeps_claude_numbers(window))
      else
        keep_panel_gutter(window)
      end
    end
  end

  --- Keeps the gutter of the panels a buffer has just entered
  --- (`keep_panel_gutter()`).
  ---
  ---@param event { buf: integer }
  local function keep_panel_gutter_on_entry(event)
    for _, window in ipairs(vim.fn.win_findbuf(event.buf)) do
      if is_panel_window(window) then
        keep_panel_gutter(window)
      end
    end
  end

  --- The windows of the run pane's stack that exist, top to bottom: the
  --- Report's, then those the pane opened below it.
  ---
  ---@return integer[] windows
  local function run_stack_windows()
    local windows = has_window('report') and { state.windows.report } or {}
    return vim.list_extend(windows, vim.tbl_filter(vim.api.nvim_win_is_valid, state.run_windows))
  end

  --- The windows of the right column that exist under the pane shown, top to
  --- bottom: the run pane's stack, or the Report's window and Input's.
  ---
  ---@return integer[] windows
  local function column_windows()
    if state.pane == 'run' then
      return run_stack_windows()
    end
    return vim
      .iter(pane_roles(state.pane))
      :filter(has_window)
      :map(function(role)
        return state.windows[role]
      end)
      :totable()
  end

  --- Whether the right column's windows are those that were zoomed.
  ---
  ---@return boolean
  local function is_zoom_of_column()
    return state.zoom ~= nil and vim.deep_equal(column_windows(), state.zoom.windows)
  end

  --- Ends the zoom, if the right column is zoomed, giving its windows the
  --- heights they had before it. Gives back none when the column's windows are
  --- no longer the ones that were zoomed, which have taken their rows to their
  --- neighbours already.
  local function end_zoom()
    if is_zoom_of_column() then
      zoom.restore(state.zoom)
    end
    state.zoom = nil
  end

  --- Keeps the zoomed window zoomed fully as the tab page's cells changed, or
  --- ends the zoom, without giving back any size, when the window that was
  --- zoomed is gone: the layout's proportions are what the windows take then.
  ---
  ---@return boolean zoomed whether a window is zoomed fully
  local function keep_full_zoom()
    if not state.full_zoom then
      return false
    end
    if not vim.api.nvim_win_is_valid(state.full_zoom.window) then
      state.full_zoom = nil
      return false
    end
    full_zoom.keep(state.full_zoom)
    return true
  end

  --- Keeps the right column zoomed as its rows changed, or ends the zoom,
  --- without giving back any height, when the column's windows are no longer
  --- the ones that were zoomed: the layout's proportions are what the windows
  --- take then.
  ---
  ---@return boolean zoomed whether the column is zoomed
  local function keep_zoom()
    if not is_zoom_of_column() then
      state.zoom = nil
      return false
    end
    zoom.keep(state.zoom)
    return true
  end

  --- Gives the windows of the run pane's stack the rows they hold together in
  --- equal shares, the first windows one row more when the rows do not divide.
  --- Does nothing under another pane, which has no stack, for a stack of one
  --- window, or while the stack is zoomed.
  local function equalize_run_windows()
    local windows = run_stack_windows()
    if state.pane ~= 'run' or #windows < 2 or state.zoom or state.full_zoom then
      return
    end
    local rows = 0
    for _, window in ipairs(windows) do
      rows = rows + vim.api.nvim_win_get_height(window)
    end
    local share, remainder = math.floor(rows / #windows), rows % #windows
    for index = 1, #windows - 1 do
      vim.api.nvim_win_set_height(windows[index], share + (index <= remainder and 1 or 0))
    end
  end

  --- Whether `window` is not floating.
  ---
  ---@param window integer
  ---@return boolean
  local function is_tiled(window)
    return vim.api.nvim_win_get_config(window).relative == ''
  end

  --- The windows of the layout's tab page that are not floating, in the order
  --- the tab page lists them.
  ---
  ---@return integer[] windows
  local function tab_windows()
    return vim.iter(vim.api.nvim_tabpage_list_wins(layout_tab())):filter(is_tiled):totable()
  end

  --- A window that lies across the whole screen, as `:botright split` or
  --- `:copen` opens one, which the layout's columns end above or below.
  ---@class aineo.layout.AcrossTheScreen
  ---@field window integer
  ---@field edge 'above'|'below' the edge of the screen it lies on
  ---@field height integer

  --- The windows of the layout's tab page, none of the layout's own, that are
  --- as wide as the screen, top to bottom: each with the edge it lies on, the
  --- top one when it lies above the layout's first window, and its height, to put it back with `put_across_the_screen()` after a window
  --- opened or moved to the screen's edge, which `nvim_open_win()` and
  --- `nvim_win_set_config()` with `win = -1` do over the whole tab page,
  --- across such a window too.
  ---
  ---@return aineo.layout.AcrossTheScreen[] across
  local function windows_across_the_screen()
    local windows = tab_windows()
    local top = math.huge
    for _, window in ipairs(existing_windows()) do
      top = math.min(top, vim.api.nvim_win_get_position(window)[1])
    end
    local across = {}
    for _, window in ipairs(windows) do
      if
        not role_of(window)
        and window ~= state.explorer_window
        and vim.api.nvim_win_get_width(window) == vim.o.columns
      then
        table.insert(across, {
          window = window,
          edge = vim.api.nvim_win_get_position(window)[1] < top and 'above' or 'below',
          height = vim.api.nvim_win_get_height(window),
        })
      end
    end
    return across
  end

  --- Puts the windows `windows_across_the_screen()` listed back across the
  --- screen at their edges and their heights, those on the top edge from the
  --- bottom one up, those on the bottom edge from the top one down, so that
  --- they keep their order.
  ---
  ---@param across aineo.layout.AcrossTheScreen[]
  local function put_across_the_screen(across)
    local ordered = vim.tbl_filter(function(entry)
      return entry.edge == 'above'
    end, across)
    ordered = vim.fn.reverse(ordered)
    vim.list_extend(
      ordered,
      vim.tbl_filter(function(entry)
        return entry.edge == 'below'
      end, across)
    )
    for _, entry in ipairs(ordered) do
      if vim.api.nvim_win_is_valid(entry.window) then
        vim.api.nvim_win_set_config(entry.window, { split = entry.edge, win = -1 })
        vim.api.nvim_win_set_height(entry.window, entry.height)
      end
    end
  end

  --- Runs `action`, which opens or moves layout windows to the screen's
  --- edges, and puts the windows across the screen back where they were
  --- (`put_across_the_screen()`), so that no column spans them.
  ---
  ---@generic T
  ---@param action fun(): T
  ---@return T result what `action` returns
  local function keeping_across_the_screen(action)
    local across = windows_across_the_screen()
    local result = action()
    put_across_the_screen(across)
    return result
  end

  --- The windows, top to bottom, of the column that holds `window`, in the
  --- row of the tab that holds the layout's windows; none when no row does.
  --- Read from the tab as it is now, so that it is read for both columns
  --- before either moves: a window across the screen below the row turns the
  --- column the other moves to the edge into the whole old row.
  ---
  ---@param window integer
  ---@return integer[] members
  local function column_members(window)
    local tree = vim.fn.winlayout(vim.api.nvim_tabpage_get_number(layout_tab()))
    return columns.windows_of_column_holding(tree, existing_windows(), window)
  end

  --- Moves the windows of a column, as `column_members()` listed them, to the
  --- outer edge of the screen on `edge`, window by window, each below the one
  --- before it: the windows keep their buffers, jobs, cursors and IDs. A
  --- window of the column split further than a column holds comes with it,
  --- below the window before it.
  ---
  ---@param members integer[]
  ---@param edge aineo.layout.Side
  local function move_column(members, edge)
    local above = nil
    for _, member in ipairs(members) do
      vim.api.nvim_win_set_config(
        member,
        above and { split = 'below', win = above } or { split = edge, win = -1 }
      )
      above = member
    end
  end

  --- Moves the explorer column back to the outer edge of its side when a
  --- column opened beyond it, as Claude's does at the edge of the screen: it
  --- is left alone while it is outermost, or when no row of the tab holds the
  --- layout's windows and it.
  local function keep_explorer_outermost()
    if not has_explorer_column() or not state.explorer_column then
      return
    end
    local held = vim.list_extend(existing_windows(), { state.explorer_window })
    local tree = vim.fn.winlayout(vim.api.nvim_tabpage_get_number(layout_tab()))
    if not columns.is_outermost(tree, held, state.explorer_window, state.explorer_column) then
      keeping_across_the_screen(function()
        move_column(column_members(state.explorer_window), state.explorer_column)
      end)
    end
  end

  --- Where `place_columns()` puts the layout's columns.
  ---@class aineo.layout.ColumnPlan
  ---@field claude_side aineo.layout.Side the side Claude's column goes to, the right column going across from it
  ---@field explorer_side aineo.layout.Side|nil the side the explorer column goes to, nil to leave it
  ---@field beside boolean whether the file column lies beside the explorer column, on its inner side, rather than between Claude's column and the right one

  --- Puts Claude's column, the right column and the explorer column where
  --- `plan` says, in one pass over the tab page of the layout, the file column
  --- staying where it is: the other columns move to the edges of the screen
  --- around it, which leaves it between them or, with `plan.beside`, next to
  --- the explorer column. The windows of a column move together, in their
  --- order, so that a file column split by hand keeps its splits, and every
  --- window keeps its buffer, job and cursor, and the widths of a file column's
  --- parts are recorded for the sizing that follows (`remember_file_parts()`).
  --- Windows across the screen keep their place.
  ---
  ---@param plan aineo.layout.ColumnPlan
  local function place_columns(plan)
    remember_file_parts()
    local claude_members = has_window('claude') and column_members(state.windows.claude) or {}
    local right_column = right_column_window()
    local right_members = right_column and column_members(right_column) or {}
    local explorer_members = plan.explorer_side
        and has_explorer_column()
        and column_members(state.explorer_window)
      or {}
    local members = {
      [plan.claude_side] = claude_members,
      [side.opposite(plan.claude_side)] = right_members,
    }
    keeping_across_the_screen(function()
      if plan.beside and #explorer_members > 0 then
        local inner = side.opposite(plan.explorer_side)
        local first, second = members.left, members.right
        if inner == 'left' then
          first, second = second, first
        end
        move_column(first, inner)
        move_column(second, inner)
      else
        move_column(members.left, 'left')
        move_column(members.right, 'right')
      end
      move_column(explorer_members, plan.explorer_side)
    end)
  end

  --- Moves the file column from between Claude's column and the right one to
  --- the explorer column's inner side. Changes nothing while the file column
  --- lies beside the explorer column already or is not open.
  local function move_file_column_beside_explorer()
    if #centre_file_column_windows() == 0 or #file_column_windows_beside_explorer() > 0 then
      return
    end
    place_columns({
      claude_side = state.claude_side,
      explorer_side = state.explorer_column,
      beside = true,
    })
  end

  --- Moves the file column from beside the explorer column, or from the edge
  --- of the screen the explorer column leaves open, to between Claude's column
  --- and the right one. Changes nothing while the file column lies there
  --- already or is not open.
  local function move_file_column_to_centre()
    if #file_column_windows_beside_explorer() == 0 or #centre_file_column_windows() > 0 then
      return
    end
    place_columns({
      claude_side = state.claude_side,
      explorer_side = state.explorer_column or nil,
      beside = false,
    })
  end

  --- Puts the file column where it belongs: beside the explorer column
  --- (`wants_file_column_beside_explorer()`), else between Claude's column and
  --- the right one.
  local function keep_file_column_in_place()
    if wants_file_column_beside_explorer() then
      move_file_column_beside_explorer()
    else
      move_file_column_to_centre()
    end
  end

  --- Whether the file column lies beside the explorer column now and would
  --- not once the layout took the settings given: an `explorer_column` that is
  --- another side or `false`, or a `file_beside_explorer` that is `false`; a
  --- setting that is `nil` stays as it is.
  ---
  ---@param explorer_column? aineo.layout.Side|false
  ---@param file_beside_explorer? boolean
  ---@return boolean
  local function file_column_leaves_explorer(explorer_column, file_beside_explorer)
    if not wants_file_column_beside_explorer() then
      return false
    end
    if explorer_column == nil then
      explorer_column = state.explorer_column
    end
    if file_beside_explorer == nil then
      file_beside_explorer = state.file_beside_explorer
    end
    return not file_beside_explorer or explorer_column ~= state.explorer_column
  end

  --- Moves the file column from beside the explorer column to the centre when
  --- the settings given would take it away from the explorer column
  --- (`file_column_leaves_explorer()`), in the layout's tab page whether or not
  --- it is shown. To be called before the layout takes the settings, while the
  --- explorer column is where the file column lies.
  ---
  ---@param explorer_column? aineo.layout.Side|false
  ---@param file_beside_explorer? boolean
  local function leave_explorer_when_settings_change(explorer_column, file_beside_explorer)
    if has_any_window() and file_column_leaves_explorer(explorer_column, file_beside_explorer) then
      vim.api.nvim_win_call(existing_windows()[1], move_file_column_to_centre)
    end
  end

  --- Puts the layout's proportions back: the columns' widths, the Report's
  --- share of the right column's rows when Input's window shows, and the
  --- equal shares of the run pane's stack; with the right column zoomed, the
  --- zoom is kept in their place (`keep_zoom()`), and with a window zoomed
  --- fully, that zoom is kept in place of all of them (`keep_full_zoom()`).
  local function apply_proportions()
    if keep_full_zoom() then
      return
    end
    keep_explorer_outermost()
    keep_file_column_in_place()
    if is_file_focus_applied() then
      size_focused_columns()
      return
    end
    size_columns()
    if state.file_focus and has_window('claude') then
      state.file_focus.claude_width = vim.api.nvim_win_get_width(state.windows.claude)
    end
    if keep_zoom() then
      return
    end
    if has_window('input') then
      size_right_column()
    end
    equalize_run_windows()
  end

  --- Ends the full zoom, if a window is zoomed fully. When the tab page holds
  --- the windows it held as the zoom began, every window gets the size it had
  --- (a zoom of the right column that was on stays on). When a window opened
  --- or closed meanwhile, those sizes no longer apply: the layout's
  --- proportions are put back (`apply_proportions()`), and, while the layout
  --- is not open, because the zoomed window of the layout closed, the windows
  --- that remain get the sizes they had, but for the explorer column, which
  --- keeps its width whatever size the screen had.
  local function end_full_zoom()
    local zoomed = state.full_zoom
    if not zoomed then
      return
    end
    state.full_zoom = nil
    local holds_the_same_windows = has_any_window()
      and vim.deep_equal(tab_windows(), zoomed.windows)
    if not holds_the_same_windows and is_laid_out() then
      apply_proportions()
    else
      full_zoom.restore(zoomed)
      if has_explorer_column() then
        vim.api.nvim_win_set_width(state.explorer_window, state.explorer_width)
      end
    end
  end

  --- Closes the panes column and gives its cells to the file column, for a
  --- file focus that waits for a file column (`M.start_file_focus()`). Defined
  --- below.
  ---@type fun()
  local apply_file_focus

  --- Opens the panes column again, for an applied file focus whose file
  --- column closed, leaving the focus waiting for the next one. Defined below.
  ---@type fun()
  local restore_panes_column

  --- Puts the layout's proportions back while it is laid out
  --- (`is_laid_out()`), and does nothing once a window the pane shown needs is
  --- gone. A full zoom whose window is gone ends first (`end_full_zoom()`),
  --- the layout open or not. A file focus that waits for a file column
  --- (`M.start_file_focus()`) is applied once one is open, and an applied
  --- focus whose file column is gone gives the panes column back.
  local function keep_proportions()
    if state.full_zoom and not vim.api.nvim_win_is_valid(state.full_zoom.window) then
      end_full_zoom()
    end
    local focus = state.file_focus
    if focus and has_window('claude') and has_file_column() then
      if not focus.applied then
        apply_file_focus()
        return
      end
    elseif focus and focus.applied and has_window('claude') then
      restore_panes_column()
      return
    end
    if is_laid_out() then
      apply_proportions()
    end
  end

  --- The width and height of each window of the layout's tab page that does
  --- not float, by window.
  ---
  ---@return table<integer, integer[]> sizes
  local function sizes_of_tab_windows()
    local sizes = {}
    for _, window in ipairs(tab_windows()) do
      sizes[window] = { vim.api.nvim_win_get_width(window), vim.api.nvim_win_get_height(window) }
    end
    return sizes
  end

  --- Gives each window of `sizes` that exists the width and height it had.
  --- Done twice over, since a window given its size takes the cells of its
  --- neighbours, which the next window then gives back.
  ---
  ---@param sizes table<integer, integer[]>
  local function restore_sizes(sizes)
    for _ = 1, 2 do
      for window, size in pairs(sizes) do
        if vim.api.nvim_win_is_valid(window) then
          vim.api.nvim_win_set_width(window, size[1])
          vim.api.nvim_win_set_height(window, size[2])
        end
      end
    end
  end

  --- Moves Claude's column to `target` and the right column across from it,
  --- the file column staying between them, in the tab page of the layout
  --- whether or not it is the one shown. The windows move, never their
  --- buffers or jobs, and the cursor stays in the window it was in. A zoom
  --- ends first, its sizes not given back; every window of the tab page then
  --- gets the size it had, which mirrors the columns, and the layout's
  --- proportions are put back while the layout is open. The columns move in
  --- one pass (`place_columns()`): the explorer column, to the edge of its own
  --- side, stays outermost there, and the file column, which does not move,
  --- stays between Claude's column and the right one or beside the explorer
  --- column. With `explorer_side`, the explorer column of a layout that has one
  --- goes to that side in the same pass. With no window of the layout open,
  --- only the sides are recorded, for the layout to open on.
  ---
  ---@param target aineo.layout.Side
  ---@param explorer_side? aineo.layout.Side the side the explorer column goes to too, when the layout has one
  local function move_columns_to(target, explorer_side)
    state.claude_side = target
    if explorer_side and state.explorer_column then
      state.explorer_column = explorer_side
    end
    if not has_any_window() then
      return
    end
    vim.api.nvim_win_call(existing_windows()[1], function()
      end_full_zoom()
      end_zoom()
      local sizes = sizes_of_tab_windows()
      place_columns({
        claude_side = target,
        explorer_side = state.explorer_column or nil,
        beside = wants_file_column_beside_explorer(),
      })
      restore_sizes(sizes)
      if is_laid_out() then
        apply_proportions()
      end
    end)
  end

  --- Opens a file column showing `file`, with the cursor in it: beside the
  --- explorer column, on its inner side, when the file column belongs there
  --- (`wants_file_column_beside_explorer()`); else beside Claude's column, on
  --- the side of the right column, or, with Claude's window closed, at the
  --- edge of the tab holding the layout's `window` on Claude's side.
  ---
  ---@param file integer
  ---@param window integer one of the layout's windows
  ---@return integer file_window
  local function open_file_column(file, window)
    if wants_file_column_beside_explorer() then
      return vim.api.nvim_open_win(
        file,
        true,
        { split = side.opposite(state.explorer_column), win = state.explorer_window }
      )
    end
    if has_window('claude') then
      return vim.api.nvim_open_win(
        file,
        true,
        { split = right_column_edge(), win = state.windows.claude }
      )
    end
    vim.api.nvim_set_current_win(window)
    return vim.api.nvim_open_win(file, true, { split = claude_edge(), win = -1 })
  end

  --- Whether the buffer `window` shows can leave it without being lost: when it
  --- holds no unsaved change, when another window shows it too, or when it is
  --- kept loaded once hidden — its `'bufhidden'` is `hide`, or empty under
  --- `'hidden'`.
  ---
  ---@param window integer
  ---@return boolean
  local function can_leave(window)
    local buffer = vim.api.nvim_win_get_buf(window)
    local bufhidden = vim.bo[buffer].bufhidden
    return not vim.bo[buffer].modified
      or #vim.fn.win_findbuf(buffer) > 1
      or bufhidden == 'hide'
      or (vim.o.hidden and bufhidden == '')
  end

  --- Opens a window showing `file` above `window`, with the cursor in it, or
  --- returns `nil`, changing nothing, when the screen has no room for another
  --- window there (E36). Raises any other error the split raises.
  ---
  ---@param file integer
  ---@param window integer
  ---@return integer|nil file_window
  local function open_window_above(file, window)
    local opened, result =
      pcall(vim.api.nvim_open_win, file, true, { split = 'above', win = window })
    if opened then
      return result
    end
    if not tostring(result):find('E36:', 1, true) then
      error(result, 0)
    end
    return nil
  end

  --- Shows `file` in the file column's `column_window`, with the cursor there;
  --- above it, in a window of its own, when another buffer there cannot leave
  --- it; nowhere, returning `nil`, when the screen has no room for that window.
  ---
  ---@param file integer
  ---@param column_window integer
  ---@return integer|nil file_window
  local function show_in_file_column(file, column_window)
    if vim.api.nvim_win_get_buf(column_window) ~= file and not can_leave(column_window) then
      return open_window_above(file, column_window)
    end
    vim.api.nvim_win_set_buf(column_window, file)
    vim.api.nvim_set_current_win(column_window)
    return column_window
  end

  --- Shows `file` in the file column, with the cursor there: in a window of it
  --- that may take a file (see `show_in_file_column()`), or in a new file column
  --- beside the layout's `window` when it has none. `nil` when the file column
  --- has no room for `file`.
  ---
  ---@param file integer
  ---@param window integer one of the layout's windows
  ---@return integer|nil file_window
  local function place_in_file_column(file, window)
    local column_window = window_taking_files()
    if column_window then
      return show_in_file_column(file, column_window)
    end
    return open_file_column(file, window)
  end

  --- Warns that `file` stays in the layout's window it was opened in, since the
  --- file column has no room for it.
  ---
  ---@param file integer
  local function warn_no_room_for(file)
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(file), ':t')
    vim.notify(
      ('aineo: the file column has no room for %s, which stays where it was opened'):format(name),
      vim.log.levels.WARN
    )
  end

  --- The buffer that belongs in `window` when it is one of the layout's
  --- windows that exists: Claude's, the Report's or Input's, each with its
  --- own buffer under the pane shown (`own_buffer()`), or the explorer
  --- column's with the explorer's. `nil` for any other window.
  ---
  ---@param window integer
  ---@return integer|nil buffer
  local function own_buffer_in(window)
    if has_explorer_column() and window == state.explorer_window then
      return state.buffers.explorer
    end
    local role = role_of(window)
    return role and has_window(role) and own_buffer(role) or nil
  end

  --- Moves `file` from one of the layout's windows, the explorer column's
  --- included, to the file column (see `place_in_file_column()`), with the
  --- cursor there on the position it had in `window`, gives `window` its own
  --- buffer back, and puts the proportions back
  --- while the layout is laid out (`is_laid_out()`). When the file column has no
  --- room for `file`, leaves it in `window` and warns. Does nothing when
  --- `window` is no longer one of the layout's windows — closed, or replaced
  --- by a window the layout reopened — no longer shows `file`, or has no
  --- buffer of its own to take back, its own having been wiped.
  ---
  ---@param window integer
  ---@param file integer
  local function redirect(window, file)
    local own = own_buffer_in(window)
    if
      not own
      or vim.api.nvim_win_get_buf(window) ~= file
      or not vim.api.nvim_buf_is_valid(own)
    then
      return
    end
    local cursor = vim.api.nvim_win_get_cursor(window)
    local file_window = place_in_file_column(file, window)
    if not file_window then
      warn_no_room_for(file)
      return
    end
    vim.api.nvim_win_set_cursor(file_window, cursor)
    vim.api.nvim_win_set_buf(window, own)
    keep_proportions()
  end

  --- Redirects a file shown in one of the layout's windows, once the command
  --- that showed it has finished with that window. A window's own buffer is
  --- never taken for a file there, whatever its options.
  ---
  ---@param event { buf: integer }
  local function redirect_when_file(event)
    local window = vim.api.nvim_get_current_win()
    local own = own_buffer_in(window)
    if not own or event.buf == own or not is_file(event.buf) then
      return
    end
    vim.schedule(function()
      redirect(window, event.buf)
    end)
  end

  --- The buffer already named as Input is (`input_name`), such as one a
  --- restored session made, or `nil`.
  ---
  ---@return integer|nil buffer
  local function buffer_named_input()
    return vim.iter(vim.api.nvim_list_bufs()):find(function(buffer)
      return vim.api.nvim_buf_get_name(buffer) == input_name
    end)
  end

  --- Whether `buffer` has no name and holds no text, as the buffer Neovim
  --- starts with, whatever filetype the user's configuration gave it — and is
  --- not wiped once hidden, as a startup dashboard's is before it has drawn.
  ---
  ---@param buffer integer
  ---@return boolean
  local function is_unnamed_and_empty(buffer)
    return vim.api.nvim_buf_get_name(buffer) == ''
      and vim.bo[buffer].bufhidden ~= 'wipe'
      and vim.api.nvim_buf_line_count(buffer) == 1
      and vim.api.nvim_buf_get_lines(buffer, 0, 1, true)[1] == ''
  end

  --- Makes `buffer` a scratch buffer: never a file, unlisted, kept when hidden,
  --- with no swap file.
  ---
  ---@param buffer integer
  local function make_scratch(buffer)
    vim.bo[buffer].buftype = 'nofile'
    vim.bo[buffer].bufhidden = 'hide'
    vim.bo[buffer].buflisted = false
    vim.bo[buffer].swapfile = false
  end

  --- Makes Input a scratch buffer again whenever it is shown: deleting a buffer
  --- (`:bdelete`) resets its options, so Input would come back as a file.
  ---
  ---@param event { buf: integer }
  local function keep_input_scratch(event)
    if event.buf == state.buffers.input then
      make_scratch(event.buf)
    end
  end

  --- Whether the Input buffer the layout made still exists.
  ---
  ---@return boolean
  local function has_input()
    return state.buffers.input ~= nil and vim.api.nvim_buf_is_valid(state.buffers.input)
  end

  --- Makes `buffer` Input: a scratch buffer named `input_name`.
  ---
  ---@param buffer integer
  ---@return integer input
  local function make_input(buffer)
    make_scratch(buffer)
    vim.api.nvim_buf_set_name(buffer, input_name)
    state.buffers.input = buffer
    return buffer
  end

  --- The Input buffer: the one the layout made before, while it exists; else
  --- the buffer already named `input_name` made Input, else `shown` made
  --- Input when it is unnamed and empty (`is_unnamed_and_empty()`), or else a
  --- new buffer made Input.
  ---
  ---@param shown integer the buffer of the window the layout opens from
  ---@return integer input
  local function take_input_buffer(shown)
    if has_input() then
      return state.buffers.input
    end
    local named = buffer_named_input()
    if named then
      return make_input(named)
    end
    if is_unnamed_and_empty(shown) then
      return make_input(shown)
    end
    return make_input(vim.api.nvim_create_buf(false, true))
  end

  --- Whether `window` floats over the others rather than taking a place among
  --- them.
  ---
  ---@param window integer
  ---@return boolean
  local function is_floating(window)
    return vim.api.nvim_win_get_config(window).relative ~= ''
  end

  --- Closes every window of the current tab but `kept` and the floating ones,
  --- hiding their buffers, which stay loaded.
  ---
  ---@param kept integer the window to keep
  local function hide_other_windows(kept)
    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if window ~= kept and not is_floating(window) then
        vim.api.nvim_win_hide(window)
      end
    end
  end

  --- The window the layout is built from: the current one, or, when it floats,
  --- the first window of the current tab that does not.
  ---
  ---@return integer window
  local function starting_window()
    local current = vim.api.nvim_get_current_win()
    if not is_floating(current) then
      return current
    end
    return vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(function(window)
      return not is_floating(window)
    end)
  end

  --- Whether `buffer` is a file the layout keeps beside it when it opens: a
  --- file (`is_file()`) that is not wiped once hidden, as a startup
  --- dashboard's buffer is, or one that is but holds changes, which Neovim
  --- refuses to wipe (E37).
  ---
  ---@param buffer integer
  ---@return boolean
  local function is_file_to_keep(buffer)
    return is_file(buffer) and (vim.bo[buffer].bufhidden ~= 'wipe' or vim.bo[buffer].modified)
  end

  --- Closes Input's window, when it exists, keeping the view of the buffer it
  --- shows (`state.views`) for the window that shows it again. A cursor in it
  --- goes to the window above, the Report's, which grows into the room and is
  --- given back the view it had, since Neovim moves the top line of a window
  --- that changes height.
  local function close_input_window()
    if not has_window('input') then
      return
    end
    local window = state.windows.input
    state.views[vim.api.nvim_win_get_buf(window)] =
      vim.api.nvim_win_call(window, vim.fn.winsaveview)
    local report_view = has_window('report')
      and vim.api.nvim_win_call(state.windows.report, vim.fn.winsaveview)
    vim.api.nvim_win_close(window, false)
    if report_view and has_window('report') then
      vim.api.nvim_win_call(state.windows.report, function()
        vim.fn.winrestview(report_view)
      end)
    end
  end

  --- Makes the layout's three windows in the current tab, closing its other
  --- windows but the floating ones, with the cursor in the window in Input's
  --- place, each window showing its own buffer (`own_buffer()`). The window it
  --- starts from (see `starting_window()`) becomes the one in Input's place,
  --- unless it shows a file (`is_file_to_keep()`), which it keeps as the file
  --- column.
  --- When that window is the explorer column's, the column is given up and
  --- opens again as a window of its own (`keep_explorer_column()`).
  local function build()
    local start = starting_window()
    if start == state.explorer_window then
      state.explorer_window = nil
    end
    local shown = vim.api.nvim_win_get_buf(start)
    hide_other_windows(start)
    local input = take_input_buffer(shown)
    local input_window = start
    if shown ~= input and is_file_to_keep(shown) then
      input_window =
        vim.api.nvim_open_win(own_buffer('input'), false, { split = right_column_edge(), win = -1 })
    else
      vim.api.nvim_win_set_buf(input_window, own_buffer('input'))
    end
    local report_window =
      vim.api.nvim_open_win(own_buffer('report'), false, { split = 'above', win = input_window })
    local claude_window =
      vim.api.nvim_open_win(own_buffer('claude'), false, { split = claude_edge(), win = -1 })
    state.windows = { claude = claude_window, report = report_window, input = input_window }
    vim.api.nvim_set_current_win(input_window)
    if not PANE_BUFFERS[state.pane].input then
      close_input_window()
    end
  end

  --- Opens the Report's window again, showing its own buffer: above Input, or
  --- above the first window of the run pane's stack that remains when Input
  --- is closed, or as the outermost column on the right column's side when
  --- there is none either.
  local function open_report_window()
    local below = right_column_window()
    local place = below and { split = 'above', win = below }
      or { split = right_column_edge(), win = -1 }
    state.windows.report = vim.api.nvim_open_win(own_buffer('report'), false, place)
  end

  --- Opens again, in their places, those of the layout's windows that were
  --- closed, each showing its buffer: Claude's as the outermost column on
  --- Claude's side, the Report above Input, or as the outermost column on the
  --- right column's side when Input is closed too, and Input below the
  --- Report, unless the pane shown has none for Input.
  local function reopen_closed_windows()
    keeping_across_the_screen(function()
      if not has_window('claude') then
        state.windows.claude =
          vim.api.nvim_open_win(own_buffer('claude'), false, { split = claude_edge(), win = -1 })
      end
      if not has_window('report') then
        open_report_window()
      end
      if not has_window('input') and PANE_BUFFERS[state.pane].input then
        state.windows.input = vim.api.nvim_open_win(
          own_buffer('input'),
          false,
          { split = 'below', win = state.windows.report }
        )
      end
    end)
  end

  --- Opens the explorer column: a window showing the explorer's buffer, as
  --- tall as the screen, at the outer edge on the side the column is on, its
  --- width fixed. The cursor stays where it is.
  local function open_explorer_column()
    state.explorer_window = keeping_across_the_screen(function()
      return vim.api.nvim_open_win(
        state.buffers.explorer,
        false,
        { split = state.explorer_column, win = -1 }
      )
    end)
    vim.wo[state.explorer_window].winfixwidth = true
  end

  --- Moves the cursor of the explorer column's tab page, when it is in the
  --- column, to the file column, when that is open: the cursor of a tab page
  --- that is not shown too.
  local function leave_explorer_column()
    local page = vim.api.nvim_win_get_tabpage(state.explorer_window)
    if vim.api.nvim_tabpage_get_win(page) == state.explorer_window then
      local file_window = file_column_windows()[1]
      if file_window then
        vim.api.nvim_tabpage_set_win(page, file_window)
      end
    end
  end

  --- Closes the explorer column, the cursor having left it
  --- (`leave_explorer_column()`).
  local function close_explorer_column()
    leave_explorer_column()
    vim.api.nvim_win_close(state.explorer_window, false)
  end

  --- Makes the explorer column what the layout was handed: open when it is on
  --- a side, closed when it is not (`close_explorer_column()`), on that side,
  --- showing the explorer's buffer. A column on the other side moves there
  --- (`keep_explorer_outermost()`).
  local function keep_explorer_column()
    if has_explorer_column() and not state.explorer_column then
      close_explorer_column()
    elseif not has_explorer_column() and state.explorer_column then
      open_explorer_column()
      keep_panel_gutter(state.explorer_window)
    end
  end

  --- Whether `buffer`, shown in one of the layout's windows in place of the
  --- layout's own buffer, is a file that moves to the file column rather than
  --- leave the screen: a file to keep (`is_file_to_keep()`), not the unnamed,
  --- empty buffer Neovim puts in a window (`is_unnamed_and_empty()`), and shown
  --- in no other window.
  ---
  ---@param buffer integer
  ---@return boolean
  local function is_file_to_move(buffer)
    return is_file_to_keep(buffer)
      and not is_unnamed_and_empty(buffer)
      and #vim.fn.win_findbuf(buffer) == 1
  end

  --- Shows each of the layout's buffers in its window that exists, where
  --- another took its place; a file that took it (`is_file_to_move()`) moves to
  --- the file column first, when the column has room for it
  --- (`place_in_file_column()`). The cursor stays in the window it was in.
  local function show_buffers()
    local current = vim.api.nvim_get_current_win()
    for _, role in ipairs(vim.tbl_filter(has_window, ROLES)) do
      local window = state.windows[role]
      local shown = vim.api.nvim_win_get_buf(window)
      if shown ~= own_buffer(role) then
        if is_file_to_move(shown) then
          place_in_file_column(shown, window)
        end
        vim.api.nvim_win_set_buf(window, own_buffer(role))
      end
    end
    vim.api.nvim_set_current_win(current)
  end

  --- Leaves Terminal mode as the process of Claude's terminal ends while that
  --- terminal is the current buffer, so that the next key, which would close
  --- the ended terminal and its exit with it, is a Normal-mode command. The
  --- mode stays in any other buffer: Insert mode in Input, Terminal mode in
  --- another terminal.
  ---
  ---@param event { buf: integer }
  local function leave_terminal_mode_as_claude_exits(event)
    if event.buf == state.buffers.claude and event.buf == vim.api.nvim_get_current_buf() then
      vim.cmd.stopinsert()
    end
  end

  --- Keeps Claude's terminal as `state.ended_claude_terminal` once Neovim has
  --- seen its process end (`TermClose`), so that entering Terminal mode there
  --- is refused without waiting on that process.
  ---
  ---@param event { buf: integer }
  local function remember_claude_exit(event)
    if event.buf == state.buffers.claude then
      state.ended_claude_terminal = event.buf
    end
  end

  --- Whether the process of the terminal `buffer` has ended, read without
  --- waiting on it: its process id names no process any more. A process that
  --- was stopped but still runs has not ended.
  ---
  ---@param buffer integer
  ---@return boolean
  local function has_ended(buffer)
    return vim.uv.kill(vim.b[buffer].terminal_job_pid, 0) == nil
  end

  --- Leaves the Terminal mode just entered in Claude's terminal once its
  --- process has ended, as `i`, `a` or `:startinsert` enter it: a key typed in
  --- Terminal mode on an ended terminal closes it. The end is known from
  --- `remember_claude_exit()`, or, where no `TermClose` autocommand of aineo's
  --- ran for it, from the process being gone (`has_ended()`). Another terminal
  --- keeps Neovim's own behaviour, and so does Claude's while its process
  --- still runs, stopped or not.
  ---
  ---@param event { buf: integer }
  local function refuse_terminal_mode_once_claude_exited(event)
    if
      event.buf == state.ended_claude_terminal
      or (event.buf == state.buffers.claude and has_ended(event.buf))
    then
      vim.cmd.stopinsert()
    end
  end

  --- Closes `window`, hiding its buffer, when Neovim lets it close, and leaves
  --- it as it is otherwise, raising nothing: Neovim's last window cannot close
  --- (E444), nor can the window the command-line window was opened from
  --- (E11). A window of the layout left so, on an empty buffer, counts as gone
  --- only to the focus of the role whose buffer was wiped (`M.focus()`), which
  --- opens the layout again around it; focusing another role whose window is
  --- open only moves the cursor there.
  ---
  ---@param window integer
  local function close_when_possible(window)
    pcall(vim.api.nvim_win_hide, window)
  end

  --- Closes Claude's window once Claude's terminal is wiped while that window
  --- shows it, or shows the unnamed, empty buffer Neovim puts there in its
  --- place — before the wipe for a running terminal, after it for an ended
  --- one — when the terminal was the current buffer and no other buffer is
  --- listed. The close waits until the command that wiped it is done, and
  --- happens only if the window still shows such an empty buffer then: a
  --- window showing anything else, such as a new session's terminal or a file
  --- opened in the same command line, stays; and a window Neovim will not
  --- close stays too (`close_when_possible()`).
  ---
  ---@param event { buf: integer }
  local function close_claude_window_when_wiped(event)
    if event.buf ~= state.buffers.claude or not has_window('claude') then
      return
    end
    local window = state.windows.claude
    local shown = vim.api.nvim_win_get_buf(window)
    if shown ~= event.buf and not is_unnamed_and_empty(shown) then
      return
    end
    vim.schedule(function()
      if
        vim.api.nvim_win_is_valid(window)
        and is_unnamed_and_empty(vim.api.nvim_win_get_buf(window))
      then
        close_when_possible(window)
      end
    end)
  end

  --- The size Neovim gives Claude's terminal: the most columns, without the
  --- gutter, and the most lines of the windows that show it, in every tab page,
  --- Claude's window and any other; `nil` when the layout has no Claude
  --- window.
  ---
  ---@return integer|nil width
  ---@return integer|nil height
  local function claude_terminal_size()
    if not has_window('claude') then
      return nil, nil
    end
    local width, height = 0, 0
    for _, window in ipairs(vim.fn.win_findbuf(vim.api.nvim_win_get_buf(state.windows.claude))) do
      local info = vim.fn.getwininfo(window)[1]
      width = math.max(width, info.width - info.textoff)
      height = math.max(height, info.height)
    end
    return width, height
  end

  --- Tells Claude's terminal the size of its window once more
  --- (`aineo.layout.fresh_size`), so that Claude Code lays its screen out for
  --- that size whichever sizes the window took before. Does nothing while a
  --- window is zoomed fully, which leaves Claude's window the sliver the zoom
  --- gave it, or while Claude's window shows no terminal of Claude's.
  local function give_claude_terminal_a_fresh_size()
    if state.full_zoom or not has_window('claude') then
      return
    end
    local buffer = vim.api.nvim_win_get_buf(state.windows.claude)
    local job = vim.b[buffer].terminal_job_id
    if buffer ~= state.buffers.claude or not job then
      return
    end
    fresh_size.give(job, claude_terminal_size)
  end

  --- Gives Claude's terminal a fresh size once the windows have settled
  --- (`aineo.layout.fresh_size`'s `SETTLE_DELAY_MS`) when Claude's window
  --- was one of those that changed size, once for a run of changes
  --- (`give_claude_terminal_a_fresh_size()`).
  local function give_claude_terminal_a_fresh_size_when_resized()
    if
      not has_window('claude') or not vim.list_contains(vim.v.event.windows, state.windows.claude)
    then
      return
    end
    local timer = state.fresh_size_timer
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
    state.fresh_size_timer =
      vim.defer_fn(give_claude_terminal_a_fresh_size, fresh_size.SETTLE_DELAY_MS)
  end

  --- Puts the layout's proportions back when the editor is resized, unless the
  --- layout's tab page is not the one shown: its windows still have the sizes
  --- of the old editor, and the proportions of the new one would squeeze them
  --- and tell Claude's terminal a width the window never has. They are put back
  --- when the tab is entered.
  local function keep_proportions_of_the_tab_shown()
    if has_any_window() and layout_tab() ~= vim.api.nvim_get_current_tabpage() then
      return
    end
    keep_proportions()
  end

  --- Keeps Input a scratch buffer and redirects the files shown in the layout's
  --- windows; keeps Claude's terminal in Normal mode once its process has ended
  --- (`leave_terminal_mode_as_claude_exits()`, `remember_claude_exit()`,
  --- `refuse_terminal_mode_once_claude_exited()`) and closes Claude's window
  --- when its terminal is wiped there (`close_claude_window_when_wiped()`);
  --- keeps Claude's line numbers and status line as Claude's terminal enters
  --- a window (`keep_claude_window_on_entry()`); tells Claude's terminal the
  --- size of its window again once Claude's window changed size
  --- (`give_claude_terminal_a_fresh_size_when_resized()`); and puts the
  --- proportions back whenever a window that is not a float closes, the editor
  --- is resized while the layout's tab is shown (`keep_proportions_of_the_tab_shown()`)
  --- or a tab is entered, replacing what an earlier call set up.
  --- Input is made a scratch buffer first, so the redirect never takes it for
  --- a file. A window is still in the layout while `WinClosed` runs, so the
  --- proportions are put back after it; a tab that is not shown is resized
  --- when it is entered, so the proportions are put back then.
  local function watch_windows()
    local group = vim.api.nvim_create_augroup(group_name, {})
    vim.api.nvim_create_autocmd('BufWinEnter', { group = group, callback = keep_input_scratch })
    vim.api.nvim_create_autocmd('BufWinEnter', { group = group, callback = redirect_when_file })
    vim.api.nvim_create_autocmd(
      'BufWinEnter',
      { group = group, callback = keep_panel_gutter_on_entry }
    )
    vim.api.nvim_create_autocmd(
      'BufWinEnter',
      { group = group, callback = keep_claude_window_on_entry }
    )
    vim.api.nvim_create_autocmd('WinClosed', {
      group = group,
      callback = function(event)
        local closed = tonumber(event.match)
        if
          closed
          and vim.api.nvim_win_is_valid(closed)
          and vim.api.nvim_win_get_config(closed).relative ~= ''
        then
          return
        end
        vim.schedule(keep_proportions)
      end,
    })
    vim.api.nvim_create_autocmd('VimResized', {
      group = group,
      callback = keep_proportions_of_the_tab_shown,
    })
    vim.api.nvim_create_autocmd(
      'WinResized',
      { group = group, callback = give_claude_terminal_a_fresh_size_when_resized }
    )
    vim.api.nvim_create_autocmd('TabEnter', { group = group, callback = keep_proportions })
    vim.api.nvim_create_autocmd('TermClose', { group = group, callback = remember_claude_exit })
    vim.api.nvim_create_autocmd(
      'TermClose',
      { group = group, callback = leave_terminal_mode_as_claude_exits }
    )
    vim.api.nvim_create_autocmd(
      'TermEnter',
      { group = group, callback = refuse_terminal_mode_once_claude_exited }
    )
    vim.api.nvim_create_autocmd('BufWipeout', {
      group = group,
      callback = close_claude_window_when_wiped,
    })
  end

  --- Takes the run pane's terminals and winbar from `run`, or forgets them
  --- when it is `nil`: the stack is whatever the arrangement hands each time,
  --- since processes come and go.
  ---
  ---@param run aineo.layout.RunPane|nil
  local function take_run(run)
    state.run = run
    state.buffers.run = run and run.buffers[1] or nil
  end

  --- Takes what `arrangement` hands as the layout's own: Claude's terminal,
  --- the Report and the run pane's terminals and, when it hands them, the
  --- changes pane's buffers and the status line of Claude's window; the
  --- changes pane's and the status line handed last are kept when it hands
  --- none. The run pane shown when it hands no terminal gives way to the
  --- agent pane.
  ---
  ---@param arrangement aineo.layout.Arrangement
  local function take_arrangement(arrangement)
    state.buffers.claude = arrangement.claude
    state.buffers.report = arrangement.report
    if arrangement.changes then
      state.buffers.files = arrangement.changes.files
      state.buffers.commits = arrangement.changes.commits
    end
    state.buffers.shell = arrangement.shell or state.buffers.shell
    state.buffers.explorer = arrangement.explorer or state.buffers.explorer
    if arrangement.explorer_column ~= nil then
      state.explorer_column = arrangement.explorer_column
    end
    state.explorer_width = arrangement.explorer_width or state.explorer_width
    if arrangement.file_beside_explorer ~= nil then
      state.file_beside_explorer = arrangement.file_beside_explorer
    end
    if arrangement.panel_numbers ~= nil then
      state.panel_numbers = arrangement.panel_numbers
    end
    if state.explorer_column and state.pane == 'explorer' then
      state.pane = 'agent'
      state.input_closed_by_user = nil
    end
    state.buffers.walkthrough = arrangement.walkthrough or state.buffers.walkthrough
    take_run(arrangement.run)
    if state.pane == 'run' and not arrangement.run then
      state.pane = 'agent'
    end
    state.claude_statusline = arrangement.claude_statusline or state.claude_statusline
  end

  --- Whether `value` is the number of an existing buffer.
  ---
  ---@param value any
  ---@return boolean
  local function is_buffer(value)
    return type(value) == 'number' and vim.api.nvim_buf_is_valid(value)
  end

  --- Whether `value` is a list of at least one existing buffer.
  ---
  ---@param value any
  ---@return boolean
  local function is_run_buffers(value)
    return vim.islist(value) and #value > 0 and vim.iter(value):all(is_buffer)
  end

  --- Whether `value` is a share: a number strictly between 0 and 1.
  ---
  ---@param value any
  ---@return boolean
  local function is_share(value)
    return type(value) == 'number' and value > 0 and value < 1
  end

  --- Whether `value` names how the explorer column is: a side, or `false` for
  --- none.
  ---
  ---@param value any
  ---@return boolean
  local function is_explorer_column(value)
    return value == false or side.is_side(value)
  end

  --- Whether `value` is a width in cells: a whole number from 1.
  ---
  ---@param value any
  ---@return boolean
  local function is_column_width(value)
    return type(value) == 'number' and value >= 1 and value % 1 == 0
  end

  --- Raises an error naming the first of the explorer column's settings of
  --- `arrangement` the layout cannot show: the column, which is a side or
  --- `false`, its width, and, when the column is a side, the explorer's buffer
  --- and a width, handed now or kept from before.
  ---
  ---@param arrangement table
  local function validate_explorer_column(arrangement)
    vim.validate(
      'arrangement.explorer_column',
      arrangement.explorer_column,
      is_explorer_column,
      true,
      "'left', 'right' or false"
    )
    vim.validate(
      'arrangement.explorer_width',
      arrangement.explorer_width,
      is_column_width,
      true,
      'a positive whole number'
    )
    local column = arrangement.explorer_column
    if column == nil then
      column = state.explorer_column
    end
    if column then
      vim.validate(
        'arrangement.explorer',
        arrangement.explorer or state.buffers.explorer,
        is_buffer,
        false,
        'a buffer'
      )
      vim.validate(
        'arrangement.explorer_width',
        arrangement.explorer_width or state.explorer_width,
        is_column_width,
        false,
        'a positive whole number'
      )
    end
  end

  --- Raises an error naming the first setting of `arrangement` the layout
  --- cannot show.
  ---
  ---@param arrangement any
  local function validate_arrangement(arrangement)
    vim.validate('arrangement', arrangement, 'table')
    vim.validate('arrangement.claude', arrangement.claude, is_buffer, false, 'a buffer')
    vim.validate('arrangement.report', arrangement.report, is_buffer, false, 'a buffer')
    vim.validate(
      'arrangement.report_height',
      arrangement.report_height,
      is_share,
      false,
      'a number strictly between 0 and 1'
    )
    vim.validate(
      'arrangement.claude_side',
      arrangement.claude_side,
      side.is_side,
      true,
      "'left' or 'right'"
    )
    vim.validate('arrangement.changes', arrangement.changes, 'table', true)
    vim.validate('arrangement.claude_statusline', arrangement.claude_statusline, 'string', true)
    vim.validate('arrangement.shell', arrangement.shell, is_buffer, true, 'a buffer')
    vim.validate('arrangement.explorer', arrangement.explorer, is_buffer, true, 'a buffer')
    vim.validate('arrangement.walkthrough', arrangement.walkthrough, is_buffer, true, 'a buffer')
    vim.validate(
      'arrangement.file_beside_explorer',
      arrangement.file_beside_explorer,
      'boolean',
      true
    )
    vim.validate('arrangement.panel_numbers', arrangement.panel_numbers, 'boolean', true)
    validate_explorer_column(arrangement)
    vim.validate('arrangement.run', arrangement.run, 'table', true)
    if arrangement.run then
      vim.validate(
        'arrangement.run.buffers',
        arrangement.run.buffers,
        is_run_buffers,
        false,
        'a list of at least one buffer'
      )
      vim.validate('arrangement.run.winbar', arrangement.run.winbar, 'string')
    end
    if arrangement.changes then
      vim.validate(
        'arrangement.changes.files',
        arrangement.changes.files,
        is_buffer,
        false,
        'a buffer'
      )
      vim.validate(
        'arrangement.changes.commits',
        arrangement.changes.commits,
        is_buffer,
        false,
        'a buffer'
      )
    end
  end

  --- Whether the Report has changed since the agent pane was hidden
  --- (`state.report_when_hidden`): a report arrived while the changes pane
  --- showed, into the Report kept then, or into another the report home made
  --- since, as it does once the Report is wiped.
  ---
  ---@return boolean
  local function has_report_changed_while_hidden()
    local hidden = state.report_when_hidden
    return state.buffers.report ~= hidden.buffer
      or vim.api.nvim_buf_get_changedtick(state.buffers.report) ~= hidden.tick
  end

  --- Whether the Report's window exists and shows the Report.
  ---
  ---@return boolean
  local function is_report_shown()
    return has_window('report')
      and vim.api.nvim_win_get_buf(state.windows.report) == state.buffers.report
  end

  --- Moves the cursor of the Report's window to the Report's last line, where
  --- an arriving report puts it.
  local function follow_reports()
    local last_line = vim.api.nvim_buf_line_count(state.buffers.report)
    vim.api.nvim_win_set_cursor(state.windows.report, { last_line, 0 })
  end

  --- Once the agent pane shows with the Report in the Report's window, after
  --- it was hidden: moves that window to the Report's last line when a report
  --- arrived meanwhile (`has_report_changed_while_hidden()`, `follow_reports()`),
  --- and forgets the Report kept as it was hidden. Until then — the agent pane
  --- shown again with the Report's window closed, as focusing Input does, or
  --- with another buffer in it, as a refused switch can leave it, or the
  --- Report in its window under the changes pane, as a refused switch or the
  --- user can leave it — the Report kept is kept, and so is the arrival.
  local function follow_reports_shown_again()
    if state.pane ~= 'agent' or state.report_when_hidden == nil or not is_report_shown() then
      return
    end
    if has_report_changed_while_hidden() then
      follow_reports()
    end
    state.report_when_hidden = nil
  end

  --- The view each window of the panes column's two windows that exists has,
  --- by the buffer it shows.
  ---
  ---@return table<integer, table> views
  local function save_panes_views()
    local views = {}
    for _, role in ipairs(RIGHT_COLUMN_ROLES) do
      if has_window(role) then
        local window = state.windows[role]
        views[vim.api.nvim_win_get_buf(window)] = vim.api.nvim_win_call(window, vim.fn.winsaveview)
      end
    end
    return views
  end

  --- Gives each of the panes column's two windows that exists the view saved
  --- for the buffer it shows (`save_panes_views()`), but for the Report's when
  --- a report arrived meanwhile (`report_arrived`), which keeps the line its
  --- arrival put it on.
  ---
  ---@param views table<integer, table>|nil
  ---@param report_arrived boolean
  local function restore_panes_views(views, report_arrived)
    for _, role in ipairs(RIGHT_COLUMN_ROLES) do
      if has_window(role) then
        local window = state.windows[role]
        local buffer = vim.api.nvim_win_get_buf(window)
        local view = views and views[buffer]
        if view and not (report_arrived and buffer == state.buffers.report) then
          vim.api.nvim_win_call(window, function()
            vim.fn.winrestview(view)
          end)
        end
      end
    end
  end

  --- Gives `window`, which shows `buffer`, the view kept for `buffer` in
  --- `state.views` when it last left a window, and forgets that view.
  ---
  ---@param window integer
  ---@param buffer integer
  local function restore_view(window, buffer)
    local view = state.views[buffer]
    state.views[buffer] = nil
    if view then
      vim.api.nvim_win_call(window, function()
        vim.fn.winrestview(view)
      end)
    end
  end

  --- Puts the cursor of `window`, which shows a terminal of the run pane, on
  --- the last line of the terminal's buffer, the last line in view: a
  --- terminal window follows new output while its cursor is on the last
  --- line, so a window the run pane shows afresh starts at the end of the
  --- output and goes on with it.
  ---
  ---@param window integer
  local function follow_output_in(window)
    local last_line = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(window))
    vim.api.nvim_win_set_cursor(window, { last_line, 0 })
  end

  --- Shows `buffer` in `window` in place of the buffer it shows, as a switch
  --- does: the view of the buffer leaving — its cursor and its top line
  --- (`winsaveview()`) — is kept in `state.views`, and `buffer` is given the
  --- view kept for it there when it last left by a switch, which is then
  --- forgotten. Neovim itself keeps a buffer's cursor line, not its top line.
  --- A terminal of the run pane starts at the end of its output instead
  --- (`follow_output_in()`).
  ---
  ---@param window integer
  ---@param buffer integer
  local function show_in_place(window, buffer)
    state.views[vim.api.nvim_win_get_buf(window)] =
      vim.api.nvim_win_call(window, vim.fn.winsaveview)
    vim.api.nvim_win_set_buf(window, buffer)
    restore_view(window, buffer)
    if state.run and vim.list_contains(state.run.buffers, buffer) then
      follow_output_in(window)
    end
  end

  --- Shows, in the layout's window for `role`, one of the right column's two,
  --- the buffer `pane` shows there (`PANE_BUFFERS`), in place
  --- (`show_in_place()`), when it shows another. Raises the error the window
  --- raises as it is given its buffer.
  ---
  ---@param pane aineo.layout.Pane
  ---@param role aineo.layout.Role
  local function show_pane_buffer_in(pane, role)
    local window = state.windows[role]
    local buffer = state.buffers[PANE_BUFFERS[pane][role]]
    if vim.api.nvim_win_get_buf(window) ~= buffer then
      show_in_place(window, buffer)
    end
  end

  --- Shows, in each of the right column's windows `pane` shows that exists
  --- and shows another buffer, the buffer `pane` shows there
  --- (`show_pane_buffer_in()`). Raises the error a window raises as it is given
  --- its buffer, leaving the windows after it as they are.
  ---
  ---@param pane aineo.layout.Pane
  local function show_buffers_of(pane)
    for _, role in ipairs(vim.tbl_filter(has_window, pane_roles(pane))) do
      show_pane_buffer_in(pane, role)
    end
  end

  --- Whether `buffer`, shown in the right column's window for `role`, is the
  --- buffer a pane other than `pane` shows there.
  ---
  ---@param pane aineo.layout.Pane
  ---@param role aineo.layout.Role
  ---@param buffer integer
  ---@return boolean
  local function is_buffer_of_another_pane(pane, role, buffer)
    for other, buffers in pairs(PANE_BUFFERS) do
      if other ~= pane and buffers[role] and state.buffers[buffers[role]] == buffer then
        return true
      end
    end
    return false
  end

  --- Whether one of the right column's windows `pane` shows that exists
  --- shows, in place of the buffer `pane` shows there (`PANE_BUFFERS`), the
  --- buffer another pane shows there. A window showing a buffer `pane` shows
  --- there never counts, whichever other pane shows it too.
  ---
  ---@param pane aineo.layout.Pane
  ---@return boolean
  local function shows_a_buffer_of_another_pane(pane)
    return vim.iter(vim.tbl_filter(has_window, pane_roles(pane))):any(function(role)
      local shown = vim.api.nvim_win_get_buf(state.windows[role])
      return shown ~= state.buffers[PANE_BUFFERS[pane][role]]
        and is_buffer_of_another_pane(pane, role, shown)
    end)
  end

  --- Shows again, in each of the right column's windows `pane` shows that
  --- exists, the buffer `pane` shows there, as `show_buffers_of()` does, each
  --- window on its own: a window that raises as its buffer enters it, or
  --- refuses it, leaves the other window to be shown its buffer still. The
  --- errors are dropped: this undoes a switch whose own error is the one
  --- raised.
  ---
  ---@param pane aineo.layout.Pane
  local function show_buffers_of_each_window(pane)
    for _, role in ipairs(vim.tbl_filter(has_window, pane_roles(pane))) do
      pcall(show_pane_buffer_in, pane, role)
    end
  end

  --- Draws the run pane's winbar in `window`, for the buffer it shows, as
  --- `:setlocal` sets it: another buffer shown in the window later draws the
  --- user's own.
  ---
  ---@param window integer
  local function draw_run_winbar(window)
    vim.wo[window][0].winbar = state.run.winbar
  end

  --- Opens a window below `above` showing `buffer`, without entering it, its
  --- cursor at the end of the output (`follow_output_in()`), or returns
  --- `nil`, changing nothing, when the screen has no room for another window
  --- there (E36). Raises any other error the split raises.
  ---
  ---@param buffer integer
  ---@param above integer
  ---@return integer|nil window
  local function open_run_window_below(buffer, above)
    local opened, result =
      pcall(vim.api.nvim_open_win, buffer, false, { split = 'below', win = above })
    if opened then
      vim.wo[result].winfixheight = false
      follow_output_in(result)
      return result
    end
    if not tostring(result):find('E36:', 1, true) then
      error(result, 0)
    end
    return nil
  end

  --- Closes the windows the run pane opened below the Report's, hiding their
  --- terminals, which stay loaded. The cursor goes to the Report's window when
  --- it was in one of them.
  local function close_run_windows()
    local had_cursor = vim.list_contains(state.run_windows, vim.api.nvim_get_current_win())
    for _, window in ipairs(state.run_windows) do
      if vim.api.nvim_win_is_valid(window) then
        close_when_possible(window)
      end
    end
    state.run_windows = {}
    if had_cursor and has_window('report') then
      vim.api.nvim_set_current_win(state.windows.report)
    end
  end

  --- Whether the windows of the run pane's stack show `buffers`, one window
  --- for each, top to bottom.
  ---
  ---@param buffers integer[]
  ---@return boolean
  local function run_stack_shows(buffers)
    local windows = run_stack_windows()
    return #windows == #buffers
      and vim.iter(ipairs(windows)):all(function(index, window)
        return vim.api.nvim_win_get_buf(window) == buffers[index]
      end)
  end

  --- Makes the run pane's windows show its terminals: the first in the
  --- Report's window, each next in a window below the one before it, a window
  --- a terminal already has kept, a window shown another buffer or no longer
  --- wanted closed. Every window draws the pane's winbar, and they share the
  --- column's rows in equal parts (`equalize_run_windows()`). A terminal the
  --- screen has no room for stays hidden and the user is told. Does nothing
  --- without terminals handed or without the Report's window.
  local function sync_run_windows()
    if not state.run or not has_window('report') then
      return
    end
    if (state.zoom or state.full_zoom) and not run_stack_shows(state.run.buffers) then
      end_full_zoom()
      end_zoom()
    end
    show_pane_buffer_in('run', 'report')
    local kept = {}
    for _, window in ipairs(state.run_windows) do
      if vim.api.nvim_win_is_valid(window) then
        kept[vim.api.nvim_win_get_buf(window)] = window
      end
    end
    local stack, above, hidden = {}, state.windows.report, 0
    for index = 2, #state.run.buffers do
      local buffer = state.run.buffers[index]
      local window = kept[buffer] or open_run_window_below(buffer, above)
      if window then
        table.insert(stack, window)
        above = window
      else
        hidden = hidden + 1
      end
    end
    for _, window in pairs(kept) do
      if not vim.list_contains(stack, window) then
        close_when_possible(window)
      end
    end
    state.run_windows = stack
    for _, window in ipairs(run_stack_windows()) do
      draw_run_winbar(window)
    end
    equalize_run_windows()
    if hidden > 0 then
      vim.notify(NO_ROOM_FOR_RUN:format(hidden), vim.log.levels.WARN)
    end
  end

  --- Opens Input's window below the Report's, or as the outermost column on
  --- the right column's side when the Report's is closed too, showing the
  --- buffer `pane` shows there, gives the Report its share of the column
  --- (also with Claude's window closed), puts the proportions back and gives
  --- the window the view kept for that buffer, once the window has its size.
  ---
  ---@param pane aineo.layout.Pane
  local function open_input_window(pane)
    local buffer = state.buffers[PANE_BUFFERS[pane].input]
    local place = has_window('report') and { split = 'below', win = state.windows.report }
      or { split = right_column_edge(), win = -1 }
    state.windows.input = vim.api.nvim_open_win(buffer, false, place)
    pin_windows()
    if has_window('report') then
      size_right_column()
    end
    keep_proportions()
    restore_view(state.windows.input, buffer)
  end

  --- Gives the right column to the Report's window, for the terminal pane or
  --- the run pane: closes Input's window (`close_input_window()`), and notes
  --- whether it was closed already, by the user, so that the agent pane shown
  --- again as the shell ends leaves it closed
  --- (`show_input_window_after_whole_column_pane()`).
  local function close_input_window_for_whole_column_pane()
    local was_closed = not has_window('input')
    close_input_window()
    state.input_closed_by_user = was_closed
  end

  --- Opens Input's window again for `pane`, once the pane that closed
  --- it gave way, unless the user had closed it before that pane showed.
  ---
  ---@param pane aineo.layout.Pane the pane now shown, which shows Input
  local function show_input_window_after_whole_column_pane(pane)
    if not state.input_closed_by_user and not has_window('input') then
      open_input_window(pane)
    end
    state.input_closed_by_user = nil
  end

  --- Whether `pane` takes the whole right column, with no window for Input:
  --- the terminal pane, the run pane and the explorer pane.
  ---
  ---@param pane aineo.layout.Pane
  ---@return boolean
  local function takes_whole_column(pane)
    return PANE_BUFFERS[pane].input == nil
  end

  --- Closes or opens Input's window as the pane shown changes from `from` to
  --- `to`: closed as a pane that takes the whole column (the terminal pane,
  --- the run pane, the explorer pane) takes it, opened again as it gives
  --- way. Nothing between panes that all show Input, nor between panes that
  --- all take the column.
  ---
  ---@param from aineo.layout.Pane
  ---@param to aineo.layout.Pane
  local function switch_input_window(from, to)
    if takes_whole_column(to) and not takes_whole_column(from) then
      close_input_window_for_whole_column_pane()
    elseif takes_whole_column(from) and not takes_whole_column(to) then
      show_input_window_after_whole_column_pane(to)
    end
  end

  --- Shows `pane` in the right column, in place of the pane shown, and makes it
  --- the pane shown: in the windows of the column that exist, which show one
  --- pane's buffers or the other's, Input's window closing as the terminal pane
  --- or the run pane takes the column and opening again as it gives way, the
  --- run pane's lower windows closing as it gives way. Asked for the
  --- pane shown, it changes nothing, unless one of those windows shows
  --- another pane's buffer there, and not one `pane` shows there too, as a
  --- refused switch can leave it (below): it then shows `pane`'s. Shown
  --- again, the agent pane wraps the Report and
  --- Input (`wrap_agent_pane()`), and, when a report arrived while it was
  --- hidden, the Report's window shows the Report's last line
  --- (`follow_reports_shown_again()`). As the agent pane is hidden, the Report
  --- and its `b:changedtick` are kept, to tell an arrival by, unless they are
  --- kept already, the Report not shown in its window since it was last
  --- hidden.
  ---
  --- When a window refuses its buffer — `'winfixbuf'`, the command-line
  --- window (E11), an autocommand that fails as the buffer enters it — each of
  --- the two windows is given back the buffer of the pane shown before, on its
  --- own (`show_buffers_of_each_window()`), and the pane shown stays that one;
  --- then the window's error is raised, whatever a window raises as it is
  --- given its buffer back. A window that refuses that buffer too is left
  --- showing the other pane's, and the next switch to either pane shows that
  --- pane in both windows. When the pane shown before is the agent pane, the
  --- Report back in its window is then followed as when that pane shows again
  --- (`follow_reports_shown_again()`), so that a refused switch leaves nothing
  --- for a later restore to follow. While the buffers enter their windows,
  --- `pane` is the pane shown, so that the file column's redirect takes none
  --- of them for a file (`redirect_when_file()`).
  ---
  ---@param pane aineo.layout.Pane
  local function switch_pane(pane)
    local shown = state.pane
    if pane == shown and not shows_a_buffer_of_another_pane(pane) then
      return
    end
    end_full_zoom()
    end_zoom()
    if shown == 'agent' and state.report_when_hidden == nil then
      state.report_when_hidden = {
        buffer = state.buffers.report,
        tick = vim.api.nvim_buf_get_changedtick(state.buffers.report),
      }
    end
    state.pane = pane
    local switched, failure = pcall(function()
      if shown == 'run' then
        close_run_windows()
      end
      switch_input_window(shown, pane)
      show_buffers_of(pane)
    end)
    if not switched then
      state.pane = shown
      pcall(switch_input_window, pane, shown)
      show_buffers_of_each_window(shown)
      if shown == 'run' then
        pcall(sync_run_windows)
      end
      follow_reports_shown_again()
      error(failure, 0)
    end
    wrap_agent_pane()
    follow_reports_shown_again()
  end

  --- Whether the windows of the right column `pane` shows exist, Input's
  --- being closed on purpose under the terminal pane and so opened by the
  --- switch, and the buffers `pane` shows in them are loaded: neither wiped
  --- nor unloaded, as `:bdelete` unloads a buffer, which then comes back empty.
  ---
  ---@param pane aineo.layout.Pane
  ---@return boolean
  local function can_show_in_place(pane)
    return vim.iter(pane_roles(pane)):all(function(role)
      local buffer = state.buffers[PANE_BUFFERS[pane][role]]
      local closed_on_purpose = role == 'input' and PANE_BUFFERS[state.pane].input == nil
      return (has_window(role) or closed_on_purpose)
        and buffer ~= nil
        and vim.api.nvim_buf_is_loaded(buffer)
    end)
  end

  --- Hands the layout `buffer`, the one `pane` shows in the Report's window, as
  --- an arrangement's field for that pane does, but without opening, resizing
  --- or moving anything: the layout can then show the pane in place
  --- (`M.can_show_pane_in_place()`, `M.show_pane()`) with no arrangement.
  --- Meant for the panes that own a buffer, such as the walkthrough pane.
  ---
  --- Raises an error naming `pane` when it is none of the layout's panes, and
  --- one naming `buffer` when it is no existing buffer.
  ---
  ---@param pane aineo.layout.Pane
  ---@param buffer integer
  function M.keep_pane_buffer(pane, buffer)
    vim.validate('pane', pane, function(value)
      return PANE_BUFFERS[value] ~= nil
    end, false, "'agent', 'changes', 'terminal', 'run', 'explorer' or 'walkthrough'")
    vim.validate('buffer', buffer, is_buffer, false, 'a buffer')
    state.buffers[PANE_BUFFERS[pane].report] = buffer
  end

  --- Hands the layout `changes`, the buffers the changes pane shows from now
  --- on in place of those it was handed: shown in place in the pane's two
  --- windows at once while the changes pane is the pane shown, each buffer
  --- leaving keeping its view for when it is shown again
  --- (`show_in_place()`); otherwise the next showing of the pane shows them.
  --- Opens, resizes and moves nothing, and the cursor stays in the window it
  --- was in.
  ---
  --- Raises an error naming `changes.files` or `changes.commits` when it is
  --- no existing buffer, before anything changes, and what a window raises as
  --- it is given its buffer.
  ---
  ---@param changes aineo.layout.ChangesPane
  function M.replace_changes_pane(changes)
    vim.validate('changes', changes, 'table')
    vim.validate('changes.files', changes.files, is_buffer, false, 'a buffer')
    vim.validate('changes.commits', changes.commits, is_buffer, false, 'a buffer')
    state.buffers.files = changes.files
    state.buffers.commits = changes.commits
    if state.pane == 'changes' then
      show_buffers_of('changes')
    end
  end

  --- Whether the layout can show `pane` in place now, opening nothing: the
  --- windows of the right column it shows exist, and the buffers it shows in
  --- them were handed and are loaded (`can_show_in_place()`).
  ---
  ---@param pane aineo.layout.Pane
  ---@return boolean
  function M.can_show_pane_in_place(pane)
    return can_show_in_place(pane)
  end

  --- Forgets the shell the layout was handed: the terminal pane has no buffer
  --- to show until an arrangement hands another.
  local function forget_shell()
    state.buffers.shell = nil
  end

  --- Makes the agent pane the pane shown, and forgets the shell, when the
  --- shell's buffer was wiped where no handler of the layout's saw it: by a
  --- command run in an autocommand that is not nested, such as a user's
  --- `TermClose` handler that deletes the terminal, which runs no
  --- `BufWipeout`. The windows are left as they are.
  local function forget_wiped_shell()
    if state.buffers.shell and not vim.api.nvim_buf_is_valid(state.buffers.shell) then
      forget_shell()
      if state.pane == 'terminal' then
        end_full_zoom()
        state.pane = 'agent'
      end
    end
  end

  --- `message` without the file and line of Lua source a Neovim error carries
  --- in front of its words.
  ---
  ---@param message any
  ---@return string
  local function without_source_location(message)
    return (tostring(message):gsub('^.-%.lua:%d+: ', ''))
  end

  --- Tells the user that the agent pane could not be shown, in the words of
  --- the refusal.
  ---
  ---@param failure any
  local function warn_agent_pane_cannot_show(failure)
    vim.notify(
      ('aineo: the agent pane could not be shown: %s'):format(without_source_location(failure)),
      vim.log.levels.WARN
    )
  end

  --- Shows the agent pane again with its windows, once the commands that
  --- wiped the shell's terminal are done. The Report's window is opened again
  --- in its place above Input when the wipe closed it, and not when the user
  --- had closed it before (`state.left_closed_shell_window`); a window of the
  --- layout the user closed stays closed, Input's included when it was closed
  --- before the terminal pane showed; Input's window the terminal pane closed
  --- opens again below the Report's. Every window of the right column
  --- that exists shows the agent pane's buffer, and the proportions are put
  --- back. The cursor goes to the Report when it was in the shell's window,
  --- and stays in the window it is in otherwise, in whichever tab page. Does
  --- nothing once the layout's windows are all gone; tells the user, raising
  --- nothing, when the agent pane cannot be shown.
  ---
  ---@param cursor_was_in_shell_window boolean
  local function reopen_agent_pane(cursor_was_in_shell_window)
    if not has_any_window() then
      return
    end
    local current = vim.api.nvim_get_current_win()
    local reopened, failure = pcall(function()
      if not has_window('report') and state.left_closed_shell_window ~= state.windows.report then
        vim.api.nvim_set_current_tabpage(layout_tab())
        open_report_window()
        pin_windows()
      end
      show_input_window_after_whole_column_pane('agent')
      show_buffers_of('agent')
      wrap_agent_pane()
      follow_reports_shown_again()
      keep_proportions()
    end)
    if not reopened then
      warn_agent_pane_cannot_show(failure)
    end
    if cursor_was_in_shell_window and has_window('report') then
      vim.api.nvim_set_current_win(state.windows.report)
    elseif vim.api.nvim_win_is_valid(current) then
      vim.api.nvim_set_current_win(current)
    end
  end

  --- Notes, as the Report's window closes with the shell's terminal in it,
  --- whether the cursor was in that window, for the wipe of the terminal that
  --- follows in the same command (`show_agent_pane_as_shell_is_wiped()`),
  --- which finds the cursor moved to another window. When the command is done
  --- and no wipe took the note, the window was closed on its own: the layout
  --- keeps its ID as the Report's window left closed, which the wipe of the
  --- terminal, later, does not open again (`reopen_agent_pane()`).
  ---
  ---@param event { match: string }
  local function note_shell_window_closing(event)
    local window = tonumber(event.match)
    if
      state.pane ~= 'terminal'
      or window ~= state.windows.report
      or vim.api.nvim_win_get_buf(window) ~= state.buffers.shell
    then
      return
    end
    local note = { had_cursor = vim.api.nvim_get_current_win() == window }
    state.closing_shell_window = note
    vim.schedule(function()
      if state.closing_shell_window == note then
        state.closing_shell_window = nil
        state.left_closed_shell_window = window
      end
    end)
  end

  --- Forgets the shell as its terminal is wiped, and, when the terminal pane
  --- showed it, makes the agent pane the pane shown at once and shows it
  --- again (`reopen_agent_pane()`) once the command that wiped the terminal is
  --- done: Neovim closes the Report's window with the terminal, before any
  --- buffer event, so the window cannot be kept as it is when the terminal's
  --- shell ends (`show_agent_pane_as_shell_ends()`).
  ---
  ---@param event { buf: integer }
  local function show_agent_pane_as_shell_is_wiped(event)
    if event.buf ~= state.buffers.shell then
      return
    end
    local was_shown = state.pane == 'terminal'
    local note = state.closing_shell_window
    state.closing_shell_window = nil
    forget_shell()
    if not was_shown then
      return
    end
    end_full_zoom()
    state.pane = 'agent'
    vim.schedule(function()
      reopen_agent_pane(note ~= nil and note.had_cursor)
    end)
  end

  --- Tells the user that the agent pane could not be shown as the shell ended,
  --- unless the wipe of the shell's terminal has shown it by then: the home of
  --- the shell wipes the terminal from a scheduled callback, and the wipe that
  --- follows makes the agent pane the pane shown. A failure that fixes itself
  --- so is not told; the check waits two ticks, past a wipe scheduled after
  --- it.
  ---
  ---@param buffer integer the shell's terminal
  ---@param failure any
  local function warn_unless_wiped_meanwhile(buffer, failure)
    vim.schedule(function()
      vim.schedule(function()
        if state.buffers.shell == buffer then
          warn_agent_pane_cannot_show(failure)
        end
      end)
    end)
  end

  --- Shows the agent pane in place as the process of the shell ends
  --- while the terminal pane shows it, so that the Report's window stays the
  --- window it is when the shell's buffer goes, and forgets the shell
  --- (`forget_shell()`); while another pane shows, only forgets it. A terminal
  --- wiped already, where no handler saw it, is dealt with as a wipe is
  --- (`show_agent_pane_as_shell_is_wiped()`). The Report's window gone, as a
  --- wipe of the terminal that is running closes it before the shell is told
  --- to end, or a window that refuses the agent pane's buffer, leaves the
  --- shell remembered and the terminal pane shown: the terminal's wipe, which
  --- follows, then shows the agent pane, and the user is told only if it does
  --- not (`warn_unless_wiped_meanwhile()`).
  ---
  ---@param event { buf: integer }
  local function show_agent_pane_as_shell_ends(event)
    if event.buf ~= state.buffers.shell then
      return
    end
    if not vim.api.nvim_buf_is_valid(event.buf) then
      show_agent_pane_as_shell_is_wiped(event)
      return
    end
    if state.pane == 'terminal' then
      if not has_window('report') then
        return
      end
      local shown, failure = pcall(switch_pane, 'agent')
      if not shown then
        warn_unless_wiped_meanwhile(event.buf, failure)
        return
      end
    end
    forget_shell()
  end

  --- Adds to the layout's group of handlers (`watch_windows()`) those that
  --- keep the terminal pane when the shell's process ends and its terminal is
  --- wiped (`show_agent_pane_as_shell_ends()`,
  --- `show_agent_pane_as_shell_is_wiped()`, `note_shell_window_closing()`),
  --- leaving the group's other handlers as they are.
  local function watch_shell()
    local group = vim.api.nvim_create_augroup(group_name, { clear = false })
    vim.api.nvim_create_autocmd(
      'TermClose',
      { group = group, callback = show_agent_pane_as_shell_ends }
    )
    vim.api.nvim_create_autocmd(
      'BufWipeout',
      { group = group, callback = show_agent_pane_as_shell_is_wiped }
    )
    vim.api.nvim_create_autocmd(
      'WinClosed',
      { group = group, callback = note_shell_window_closing }
    )
  end

  --- What `M.show_pane()` raises when, the layout opened, the buffers of the
  --- pane asked for are not there to show, by pane.
  ---@type table<aineo.layout.Pane, string>
  local MISSING_BUFFERS_ERROR = {
    changes = "arrangement.changes: expected the changes pane's buffers, and none was handed",
    terminal = "arrangement.shell: expected the shell's terminal buffer, and none was handed",
    run = "arrangement.run: expected the run pane's terminals, and none was handed",
    explorer = "arrangement.explorer: expected the explorer's buffer, and none was handed",
    walkthrough = "arrangement.walkthrough: expected the walkthrough pane's buffer, and none was handed",
  }

  --- Opens the layout in the current tab: `arrangement.claude` in a column on
  --- the left taking half the columns, `arrangement.report` above the Input
  --- buffer in a column on the right, the Report taking
  --- `arrangement.report_height` of its rows, and the cursor in Input's
  --- window. The right column shows the pane it showed last (`M.show_pane()`),
  --- for the editor's life, the agent pane until then: under the changes pane
  --- its two windows show `arrangement.changes`' files and commits buffers in
  --- the Report's and Input's places; under the terminal pane the Report's
  --- window shows `arrangement.shell`, the terminal of a shell, alone over the
  --- whole right column, and Input has no window; under the run pane the
  --- Report's window shows the first of `arrangement.run`'s terminals, each
  --- next in a window of its own below it, and Input has no window either;
  --- under the explorer pane the Report's window shows `arrangement.explorer`
  --- alone over the whole right column, and Input has no window. The tab's
  --- other windows close, but floating ones; their buffers stay loaded. A file
  --- the current window shows stays there, as the file column, unless it is
  --- wiped once hidden and holds no changes, as a startup dashboard's buffer
  --- is, which Input replaces. Opened from a floating window, the layout is
  --- built from the first window of the tab that does not float. Input is a
  --- scratch buffer named by `input_name` (`aineo://input` in the module's
  --- layout, `aineo://input-<n>` in one `M.new()` made), made once: from a
  --- buffer already so named, such as one a restored session made, else from the unnamed,
  --- empty buffer the current window shows, such as the one Neovim starts
  --- with, when it is not wiped once hidden, or else a new buffer; it is made
  --- anew, from a buffer so named when there is one, when it was wiped, and
  --- made a scratch buffer again whenever it is shown. The Report's and Input's
  --- windows wrap long lines between words, a wrapped line keeping its indent
  --- (`'wrap'`, `'linebreak'`, `'breakindent'`), whatever the user's settings,
  --- while they show the agent pane; Claude's window, the changes pane's
  --- buffers, and any other buffer shown in or split from those two, keep the
  --- user's own. Once `M.toggle_claude_numbers()` has set Claude's
  --- line numbers, Claude's window shows them for a Claude terminal new to
  --- it, and when the window itself is new (`keep_claude_numbers()`); line
  --- numbers the user set by hand for the same terminal in the same window
  --- stay as they are. Claude's window draws, for Claude's terminal, the
  --- `claude_statusline` handed last, as `:setlocal` sets it, whenever that
  --- terminal shows there — opened, followed (`M.follow_claude_terminal()`)
  --- or brought back by hand (`keep_claude_statusline()`); a window split
  --- from it, or any window Claude's terminal is shown in, draws it too, as
  --- window-local options go with a buffer; another buffer shown in those
  --- windows, and every other window, draw the user's own.
  ---
  --- Claude's column is on `arrangement.claude_side`, the right column across
  --- the screen from it, and the file column between them; an arrangement
  --- without it leaves the columns on the side they are on, the left before
  --- any was handed, and one that names the other side moves the columns of
  --- a layout that is open (`M.set_claude_side()`).
  ---
  --- With `arrangement.explorer_column` a side, a fourth window shows
  --- `arrangement.explorer` as a column of its own at the outer edge of that
  --- side, as tall as the screen, `arrangement.explorer_width` cells wide and
  --- fixed there; the other three columns share the screen's remaining cells
  --- as they do without it. Claude's column being on either side leaves it
  --- where it is (`M.explorer_column()`). Handed again with another side or
  --- width the column moves or resizes, with `false` it closes, the cursor
  --- going to the file column when it was in the column, and a column closed
  --- by hand opens again in place. While the column is a side the
  --- explorer pane gives way to the agent pane.
  ---
  --- With `arrangement.file_beside_explorer` true and the explorer column
  --- open, the file column lies beside it, on its inner side, and Claude's
  --- column and the right one keep their order; otherwise it lies between
  --- those two. Handed again with another value, or with an explorer column
  --- that moves or closes, an open file column moves to the place it belongs
  --- with its windows, buffers and cursors, as the explorer column opens or
  --- closes.
  ---
  --- While any of the three windows exists, opening again restores the layout
  --- instead, in the tab that holds it: it creates only the windows that were
  --- closed, in their places, Input's not under the terminal pane, shows in
  --- each window its buffer under the pane shown — the Claude and Report
  --- buffers it is handed this time, and the changes pane's and the shell's
  --- when it hands them — a file shown there in its place
  --- moving to the file column first (`show_buffers()`), makes the Report and
  --- Input wrap again while the agent pane shows, and puts the proportions
  --- back. Opened or restored under the agent pane, the Report's window shows
  --- the Report's last line when a report arrived while the agent pane was
  --- hidden, and the agent pane has not shown with the Report in that window
  --- since (`follow_reports_shown_again()`). The changes pane's buffers an
  --- arrangement without `changes` leaves are those it was handed last, and
  --- so is the shell an arrangement without `shell` leaves, while its shell
  --- lives; the terminal pane shown with no shell alive is the agent pane. The
  --- run pane's terminals are the arrangement's alone: without `run` the layout
  --- shows no run pane, and the run pane shown gives way to the agent pane.
  --- The cursor stays where it is when the layout's tab is the current one,
  --- and moves to that tab otherwise.
  ---
  --- From then on a file shown in one of the three windows moves to a file
  --- column beside them, while any of them exists, and the window gets back
  --- the buffer it shows under the pane shown; with the windows of the pane
  --- shown open, the columns take a third of the screen each while the file
  --- column is open, and the proportions are put back whenever a window closes, the editor is
  --- resized or the layout's tab is entered; a zoomed right column
  --- (`M.toggle_zoom()`) or a window zoomed fully (`M.toggle_full_zoom()`) is
  --- kept zoomed then, until its windows change.
  ---
  --- From then on, too, Claude's terminal, once its process has ended, stays
  --- in Normal mode, so that no key closes it and its exit stays on screen:
  --- Terminal mode ends there as the process ends while that terminal is the
  --- current buffer, and is not entered on it again. Once the terminal is
  --- wiped while Claude's window shows it, that window closes rather than
  --- stay on the empty buffer Neovim may put there; one Neovim will not
  --- close, such as its last window, stays on that buffer. Either way,
  --- focusing Claude (`focus()`) opens the layout again.
  ---
  --- From then on, too, the terminal pane gives way to the agent pane when
  --- its shell ends or its terminal is wiped (`watch_shell()`): as the shell's
  --- process ends, the agent pane shows in place, the Report's window staying
  --- the window it is, and Input's window opens again below it; as the terminal
  --- is wiped, the layout opens again once the command that wiped it is done,
  --- which opens the Report's window again in its place when Neovim closed it
  --- with the terminal, and Input's below it. The cursor goes to the Report
  --- when it was in the shell's window, and stays where it is otherwise, in
  --- whichever tab page; the Report's window the user had
  --- closed stays closed, and so does Input's when it was closed before the
  --- terminal pane showed. The layout then forgets that shell, whichever pane
  --- shows, and a shell wiped where none of these handlers saw it, by a
  --- command in an autocommand that is not nested, is forgotten when the
  --- process ends, or by the next `open()`, which `focus()` and `show_pane()`
  --- call when a window is gone.
  ---
  --- Opening the layout ends the file focus (`M.start_file_focus()`): the
  --- panes column opens again with the windows of the pane shown.
  ---
  --- Raises an error naming the setting, before changing anything, when
  --- `arrangement` is not a table, `claude` or `report` is not an existing
  --- buffer, `report_height` is not a number strictly between 0 and 1,
  --- `claude_side`, when given, is neither `'left'` nor `'right'`,
  --- `explorer_column`, when given, is neither a side nor `false`,
  --- `explorer_width`, when given, is not a positive whole number,
  --- `file_beside_explorer`, when given, is not a boolean, the
  --- explorer column is a side and no explorer buffer or width was handed,
  --- now or before, or `changes`, when given, is not a table whose `files` and
  --- `commits` are existing buffers, or `shell`, when given, is not an existing buffer, or
  --- `run`, when given, is not a table whose `buffers` are at least one
  --- existing buffer and whose `winbar` is a string, or `explorer`, when
  --- given, is not an existing buffer, or `claude_statusline`, when given, is
  --- not a string.
  ---
  ---@param arrangement aineo.layout.Arrangement
  function M.open(arrangement)
    validate_arrangement(arrangement)
    leave_explorer_when_settings_change(
      arrangement.explorer_column,
      arrangement.file_beside_explorer
    )
    local panel_numbers_changed = arrangement.panel_numbers ~= nil
      and arrangement.panel_numbers ~= state.panel_numbers
    take_arrangement(arrangement)
    local focus_views = is_file_focus_applied() and state.file_focus.views or nil
    state.file_focus = nil
    forget_wiped_shell()
    local wanted_side = arrangement.claude_side or state.claude_side
    if has_any_window() then
      vim.api.nvim_set_current_tabpage(layout_tab())
      if not has_input() then
        make_input(buffer_named_input() or vim.api.nvim_create_buf(false, true))
      end
      if wanted_side ~= state.claude_side then
        move_columns_to(wanted_side)
      end
      reopen_closed_windows()
      show_buffers()
    else
      state.claude_side = wanted_side
      build()
    end
    remember_file_parts()
    keep_explorer_column()
    state.report_height = arrangement.report_height
    pin_windows()
    wrap_agent_pane()
    local report_arrived = state.report_when_hidden ~= nil and has_report_changed_while_hidden()
    follow_reports_shown_again()
    keep_claude_numbers()
    keep_claude_statusline()
    if state.pane == 'run' then
      sync_run_windows()
    else
      close_run_windows()
    end
    apply_proportions()
    restore_panes_views(focus_views, report_arrived)
    watch_windows()
    watch_shell()
    if panel_numbers_changed then
      restyle_panel_gutters()
    else
      keep_panel_gutters()
    end
  end

  --- Whether the Report and Input are both loaded: neither wiped nor unloaded,
  --- as `:bdelete` unloads a buffer, which then comes back empty.
  ---
  ---@return boolean
  local function has_agent_pane_buffers()
    return vim.iter(RIGHT_COLUMN_ROLES):all(function(role)
      return state.buffers[role] ~= nil and vim.api.nvim_buf_is_loaded(state.buffers[role])
    end)
  end

  --- Whether focusing `role` shows the agent pane first: the Report's and
  --- Input's windows always; Claude's never.
  ---
  ---@param role aineo.layout.Role
  ---@return boolean
  local function focus_shows_agent_pane(role)
    return role == 'report' or role == 'input'
  end

  --- Whether the layout's window for `role` is closed on purpose by the pane
  --- shown: Input's under the terminal pane, which showing the agent pane
  --- opens again.
  ---
  ---@param role aineo.layout.Role
  ---@return boolean
  local function is_closed_by_pane(role)
    return role == 'input' and PANE_BUFFERS[state.pane].input == nil
  end

  --- Whether focusing `role` must open the layout first: its window is gone,
  --- or its own buffer was wiped (`has_window_and_buffer()`), a window the pane
  --- shown closed on purpose (`is_closed_by_pane()`) aside, which needs only
  --- its buffer; or, when it shows the agent pane first
  --- (`focus_shows_agent_pane()`) while another pane shows, the agent pane it
  --- must show again lost the Report or Input, wiped or unloaded
  --- (`has_agent_pane_buffers()`).
  ---
  ---@param role aineo.layout.Role
  ---@return boolean
  local function must_open_to_focus(role)
    if not has_window_and_buffer(role) and not (is_closed_by_pane(role) and has_input()) then
      return true
    end
    return focus_shows_agent_pane(role) and state.pane ~= 'agent' and not has_agent_pane_buffers()
  end

  --- Moves the cursor to the layout's window for `role`, opening the layout
  --- with `arrangement` first when that window is gone, or its buffer was
  --- wiped, or, for a window that shows the agent pane first while another
  --- pane shows, the Report or Input was wiped or unloaded (see `open()`). The
  --- Report's and Input's windows show the agent pane first (`M.show_pane()`),
  --- those of the right column's windows that are open, the terminal pane
  --- giving way to it, which opens Input's window again, a window the user
  --- closed before the terminal pane showed included when Input is asked for.
  --- Claude's leaves the pane shown.
  --- `arrangement` may be a function that returns it, which is called only
  --- then, so that what it makes — a session's terminal, say — is made only
  --- when the layout opens.
  ---
  --- Raises an error naming `role` when it is not one of the three windows.
  ---
  ---@param role aineo.layout.Role
  ---@param arrangement aineo.layout.Arrangement|fun(): aineo.layout.Arrangement
  function M.focus(role, arrangement)
    vim.validate('role', role, function(value)
      return vim.list_contains(ROLES, value)
    end, false, "'claude', 'report' or 'input'")
    if must_open_to_focus(role) then
      if type(arrangement) == 'function' then
        arrangement = arrangement()
      end
      M.open(arrangement)
    end
    if role == 'input' then
      state.input_closed_by_user = nil
    end
    if focus_shows_agent_pane(role) then
      switch_pane('agent')
    end
    vim.api.nvim_set_current_win(state.windows[role])
  end

  --- Shows `pane` in the right column, in place: the agent pane, the Report
  --- above Input; the changes pane, its files buffer in the Report's window and
  --- its commits buffer in Input's; the terminal pane, the shell's terminal
  --- alone in the Report's window, which takes the whole column while Input's
  --- window is closed; the run pane, `arrangement.run`'s terminals stacked
  --- over the whole column at equal heights, the first in the Report's window
  --- and each next in a window below the one before it, each drawing the pane's
  --- winbar; or the explorer pane, its buffer alone in the Report's window,
  --- which takes the whole column while Input's window is closed. The run pane reads its terminals from the arrangement each time it
  --- is asked for, shown already or not, since processes come and go: a window
  --- the user closed for a terminal opens again, a terminal that is no longer
  --- listed loses its window, and the first terminal listed takes the Report's
  --- window. A terminal the screen has no room for stays hidden, and the user
  --- is told once. A pane that takes the Report's window alone gives way to
  --- another by closing the windows below it, their terminals hidden, not
  --- stopped. The windows that show again stay, by window ID, at their
  --- sizes; Input's window closes as the terminal pane shows and a new one,
  --- below the Report's, shows Input's buffer again as it gives way, at the
  --- Report's share with Input's cursor and top line as they were, unless the
  --- user had closed Input's window before the terminal pane showed, which stays
  --- closed as the shell ends but opens again here when the agent pane or the
  --- changes pane is asked for. The cursor stays in the window it was in, and
  --- moves to the Report's window when it was in Input's as that closes. The
  --- pane shown is kept for the editor's life: opening the layout again shows
  --- it (`open()`), unless it is the terminal pane and its shell is gone, or
  --- the run pane and the arrangement hands no terminal.
  --- Asked for the pane it shows, it changes
  --- nothing, unless one of the right column's windows shows another pane's
  --- buffer there, and not one the pane asked for shows there too, as a
  --- refused switch or the user can leave it: it then shows the pane asked
  --- for there.
  ---
  --- Each buffer a switch shows again comes back with the view it had when a
  --- switch took it out: its cursor and its top line. Shown again, the agent
  --- pane wraps the Report and Input as `open()` does; when the Report changed
  --- while hidden — a report arrived — its cursor is on its last line, as an
  --- arrival puts it in a window showing the Report, once the agent pane shows
  --- with the Report in the Report's window, by a switch or by `open()`.
  ---
  --- Opens the layout with `arrangement` first when a window of the right
  --- column `pane` shows is gone, Input's under the terminal pane aside, or a
  --- buffer of `pane` was wiped or unloaded
  --- (see `open()`). `arrangement` may be a function that returns it, which is
  --- called only then. A layout restored so, while any of its windows was
  --- left, leaves the cursor in the window it was in, in whichever tab page,
  --- unless that window closed meanwhile, as it does when making the
  --- arrangement wipes the buffer it showed: from another tab page, the pane
  --- is shown in the layout's own.
  ---
  --- Raises an error naming `pane` when it is none of `'agent'`,
  --- `'changes'`, `'terminal'`, `'run'`, `'explorer'` and `'walkthrough'`, and
  --- one naming `arrangement.changes` when the changes pane is asked for and no
  --- arrangement has handed its buffers, `arrangement.run` when the run pane
  --- is asked for with none handed, `arrangement.explorer` when the explorer
  --- pane is asked for and no arrangement has handed its buffer,
  --- `arrangement.walkthrough` when the walkthrough pane is asked for and no
  --- arrangement has handed its buffer, or
  --- `arrangement.shell` when the terminal
  --- pane is asked for and no arrangement has handed a shell that lives (the layout forgets a shell
  --- whose process ended or whose terminal was wiped), after opening the
  --- layout and before switching anything. A window that refuses its
  --- buffer raises its own error, each window given back the buffer it showed
  --- unless it refuses that too (see `switch_pane()`).
  ---
  ---@param pane aineo.layout.Pane
  ---@param arrangement aineo.layout.Arrangement|fun(): aineo.layout.Arrangement
  function M.show_pane(pane, arrangement)
    vim.validate('pane', pane, function(value)
      return PANE_BUFFERS[value] ~= nil
    end, false, "'agent', 'changes', 'terminal', 'run', 'explorer' or 'walkthrough'")
    if pane == 'run' then
      if type(arrangement) == 'function' then
        arrangement = arrangement()
      end
      validate_arrangement(arrangement)
      take_run(arrangement.run)
    end
    if not can_show_in_place(pane) then
      local current = vim.api.nvim_get_current_win()
      local restoring = has_any_window()
      if type(arrangement) == 'function' then
        arrangement = arrangement()
      end
      M.open(arrangement)
      if restoring and vim.api.nvim_win_is_valid(current) then
        vim.api.nvim_set_current_win(current)
      end
    end
    if not can_show_in_place(pane) then
      error(MISSING_BUFFERS_ERROR[pane] or MISSING_BUFFERS_ERROR.changes, 0)
    end
    if not takes_whole_column(pane) then
      state.input_closed_by_user = nil
    end
    switch_pane(pane)
    if pane == 'run' then
      sync_run_windows()
    end
  end

  --- The pane the right column shows.
  ---
  ---@return aineo.layout.Pane pane
  function M.shown_pane()
    return state.pane
  end

  --- The role of the right column's window the cursor lands in as a pane is
  --- focused (`M.focus_pane()`): the Report's window under the agent pane,
  --- and under the terminal, run, explorer and walkthrough panes, which show
  --- the shell, the first terminal, the tree and the plan; Input's, which
  --- shows the commits, under the changes pane.
  ---@type table<aineo.layout.Pane, aineo.layout.Role>
  local PANE_LANDING = {
    agent = 'report',
    changes = 'input',
    terminal = 'report',
    run = 'report',
    explorer = 'report',
    walkthrough = 'report',
  }

  --- Shows `pane` as `M.show_pane()` does, then moves the cursor to the window
  --- the pane lands it in: the Report's window under the agent pane and
  --- under the terminal pane, which shows the shell there and enters no mode,
  --- and under the run, explorer and walkthrough panes, which show the first
  --- terminal, the tree and the plan there; the commits window under the
  --- changes pane. The cursor moves even when the pane was shown already, and
  --- from another tab page into the layout's own. When showing the pane
  --- raises, the cursor stays where it is.
  ---
  --- Raises the errors `M.show_pane()` raises, and an error naming `pane` when
  --- it is none of `'agent'`, `'changes'`, `'terminal'`, `'run'`, `'explorer'`
  --- and `'walkthrough'`.
  ---
  ---@param pane aineo.layout.Pane
  ---@param arrangement aineo.layout.Arrangement|fun(): aineo.layout.Arrangement
  function M.focus_pane(pane, arrangement)
    M.show_pane(pane, arrangement)
    vim.api.nvim_set_current_win(state.windows[PANE_LANDING[pane]])
  end

  --- What `M.focus_explorer_column()` raises when, the layout opened, it has
  --- no explorer column to move the cursor to.
  local NO_EXPLORER_COLUMN =
    'arrangement.explorer_column: expected a side, the explorer column was asked for'

  --- Moves the cursor into the explorer column, opening the layout with
  --- `arrangement` first when the layout is not open or the column is gone, in
  --- which case the column opens in place, at the outer edge of its side.
  --- With the cursor in the column already, it changes nothing. `arrangement`
  --- may be a function that returns it, which is called only when the layout
  --- must open.
  ---
  --- Raises an error naming `arrangement.explorer_column` when the layout has
  --- no column once it is open, after opening it and before moving the cursor.
  ---
  ---@param arrangement aineo.layout.Arrangement|fun(): aineo.layout.Arrangement
  function M.focus_explorer_column(arrangement)
    if not (is_laid_out() and has_explorer_column()) then
      if type(arrangement) == 'function' then
        arrangement = arrangement()
      end
      M.open(arrangement)
    end
    if not has_explorer_column() then
      error(NO_EXPLORER_COLUMN, 0)
    end
    vim.api.nvim_set_current_win(state.explorer_window)
  end

  --- Shows `buffer` in the file column, as a file opened from one of the
  --- layout's windows is shown there (`place_in_file_column()`), and returns
  --- its window. A file or a diff shown in the file column later takes its
  --- window in its turn (`window_taking_files()`): the column keeps one
  --- window for them. The layout's proportions are put back once `buffer`
  --- is placed, as they are once a file is (`keep_proportions()`): with a
  --- file column open, the three columns take a third each. The cursor stays
  --- in the window it was in. When the screen has no room for `buffer` — no
  --- room above a file that cannot leave the column's window, or for a new
  --- file column (E36) — it shows `buffer` nowhere and returns nil. With none
  --- of the layout's windows open, `buffer` opens in a window above the
  --- current one. Raises any other error a window raises as it is made or
  --- given `buffer`.
  ---
  ---@param buffer integer
  ---@return integer|nil window
  local function show_in_file_column_keeping_cursor(buffer)
    local current = vim.api.nvim_get_current_win()
    local placed, window
    if has_any_window() then
      placed, window =
        pcall(place_in_file_column, buffer, right_column_window() or state.windows.claude)
    else
      placed, window = pcall(open_window_above, buffer, current)
    end
    vim.api.nvim_set_current_win(current)
    if placed then
      keep_proportions()
      return window
    end
    if not tostring(window):find('E36:', 1, true) then
      error(window, 0)
    end
    return nil
  end

  --- Shows `diff`, a buffer that is no file — a diff the changes pane shows —
  --- in the file column (`show_in_file_column_keeping_cursor()`), and
  --- returns its window.
  ---
  ---@param diff integer
  ---@return integer|nil window
  function M.show_diff(diff)
    state.diffs[diff] = true
    return show_in_file_column_keeping_cursor(diff)
  end

  --- Whether `window` is one of the file column's windows, where files and
  --- diffs are shown (`file_column_windows()`).
  ---
  ---@param window integer
  ---@return boolean
  function M.is_file_column_window(window)
    return vim.list_contains(file_column_windows(), window)
  end

  --- Shows `file`, a buffer that holds a file, in the file column
  --- (`show_in_file_column_keeping_cursor()`), in the window of the file or
  --- diff shown there, which stays listed, and returns its window.
  ---
  ---@param file integer
  ---@return integer|nil window
  function M.show_file(file)
    return show_in_file_column_keeping_cursor(file)
  end

  --- Makes `terminal` the layout's Claude terminal from now on, in place of
  --- the one it was handed last: a new session's terminal that has taken the
  --- old one's place in its windows without the layout opening again. What
  --- the layout does for Claude's terminal — a file shown in its window moved
  --- to the file column, Terminal mode ended as its process ends and refused
  --- once it has, its window closed once it is wiped — then applies to
  --- `terminal`. It shows `terminal` in no window itself; Claude's window,
  --- when it shows `terminal` already, shows the line numbers
  --- `M.toggle_claude_numbers()` last set (`keep_claude_numbers()`) and the
  --- status line `M.open()` was handed last (`keep_claude_statusline()`), and
  --- so does it when `terminal` enters it later.
  ---
  --- Raises an error naming `terminal` when it is not an existing buffer.
  ---
  ---@param terminal integer
  function M.follow_claude_terminal(terminal)
    vim.validate('terminal', terminal, is_buffer, false, 'a buffer')
    state.buffers.claude = terminal
    keep_claude_numbers()
    keep_claude_statusline()
  end

  --- What `M.toggle_claude_numbers()` tells the user when the layout has no
  --- Claude window.
  local NO_CLAUDE_WINDOW =
    'aineo: no line numbers toggled — there is no Claude window; open aineo’s layout to make one'

  --- Hides the line numbers of the layout's Claude window, 'number' and
  --- 'relativenumber', when it shows either (the panels show none until
  --- `M.set_panel_numbers()` shows them), and shows those it showed before
  --- they were last hidden otherwise, or 'number' alone when it has hidden
  --- none before. The options are set for the buffer Claude's window shows,
  --- whichever it is, as `:setlocal` does: a file opened from that window
  --- keeps the user's own. Acts on Claude's window in the layout's tab from
  --- any tab, changing no other window and moving neither the cursor nor the
  --- tab.
  ---
  --- The line numbers it sets are kept for as long as the editor runs, and
  --- Claude's window shows them for Claude's terminal whenever the terminal
  --- or the window is one they were not yet shown for: a new Claude terminal
  --- `M.open()` shows there or `M.follow_claude_terminal()` follows, a window
  --- `M.open()` makes anew, and a terminal that enters Claude's window by
  --- hand (`keep_claude_numbers()`). Line numbers the user set by hand for the
  --- same terminal in the same window stay as they are. Toggled while
  --- Claude's window shows another buffer, the line numbers it set are the
  --- ones Claude's terminal is given there next.
  ---
  --- Without a Claude window — the layout never opened, Claude's window
  --- closed, or left without its terminal once the terminal was wiped, on an
  --- empty buffer or on a file Neovim showed there, as `M.focus()` counts it
  --- — it changes nothing and warns the user once.
  function M.toggle_claude_numbers()
    if not has_window_and_buffer('claude') then
      vim.notify(NO_CLAUDE_WINDOW, vim.log.levels.WARN)
      return
    end
    local shown = line_numbers(state.windows.claude)
    if shown.number or shown.relativenumber then
      state.claude_numbers_before_hiding = shown
      state.claude_numbers = NO_LINE_NUMBERS
    else
      state.claude_numbers = state.claude_numbers_before_hiding or ABSOLUTE_LINE_NUMBERS
    end
    show_claude_numbers(state.windows.claude)
  end

  --- What `M.toggle_zoom()` tells the user, as a warning, when the cursor is
  --- in none of the right column's windows.
  local NOT_IN_THE_COLUMN =
    'aineo: nothing zoomed — the cursor is in none of the windows aineo shows in the panes column (the agent, changes, terminal, run and explorer panes)'

  --- Whether the layout is zoomed now: a window of the right column
  --- (`M.toggle_zoom()`), or a window over the whole tab page
  --- (`M.toggle_full_zoom()`).
  ---
  ---@return boolean
  function M.is_zoomed()
    return state.zoom ~= nil or state.full_zoom ~= nil
  end

  --- Zooms the window of the right column the cursor is in, under whichever
  --- pane is shown: the window takes every row the column's other windows can
  --- spare, and they keep `'winminheight'` lines each (one by default, none at
  --- 0), their winbar and status line still showing what they are. Rows are
  --- taken from the column alone: a window across the whole width below the
  --- layout keeps its height, as does Claude's window. Zoomed already, it gives
  --- the windows the heights they had when the zoom began, a manual resize
  --- before it included, scaled to the rows the windows hold now when the
  --- editor was resized meanwhile.
  ---
  --- The zoom stays with the window it began in while the cursor goes
  --- elsewhere, and toggled with the cursor in another window of the column
  --- it moves there. It stays through a resize of the editor and through
  --- entering the layout's tab, the zoomed window taking the rows the column
  --- gained or lost, and through `:wincmd =`, which equalizes the run pane's
  --- stack on screen but not in the layout: the next toggle then gives back the
  --- recorded heights. It ends, giving back the heights, as another pane shows
  --- (`switch_pane()`) and as the run pane's stack gains or loses a window
  --- (`sync_run_windows()`); it ends, the proportions put back, as a window of
  --- the column closes (`keep_zoom()`). The column is the layout's windows: one
  --- the user splits off it by hand is outside it. A window zoomed fully
  --- (`M.toggle_full_zoom()`) is given its size back first, and the zoom of the
  --- column goes on from the heights it had.
  ---
  --- With the cursor in none of the column's windows — Claude's window, the
  --- file column, a window split off the column by hand, a tab page that is
  --- not the layout's, or no layout open — it changes nothing and warns the
  --- user once.
  function M.toggle_zoom()
    local current = vim.api.nvim_get_current_win()
    if not vim.list_contains(column_windows(), current) then
      vim.notify(NOT_IN_THE_COLUMN, vim.log.levels.WARN)
      return
    end
    end_full_zoom()
    local zoomed = is_zoom_of_column() and state.zoom.window or nil
    end_zoom()
    if zoomed ~= current then
      state.zoom = zoom.start(column_windows(), current)
    end
  end

  --- What `M.toggle_full_zoom()` tells the user, as a warning, when the cursor
  --- is in no window it can zoom.
  local NOTHING_TO_ZOOM_FULLY =
    'aineo: nothing zoomed — the cursor is in no window of an aineo tab page, or in a floating window'

  --- Whether `window` is one the layout's tab page holds, not floating.
  ---
  ---@param window integer
  ---@return boolean
  local function is_zoomable_in_layout_tab(window)
    return has_any_window()
      and vim.api.nvim_win_get_tabpage(window) == layout_tab()
      and is_tiled(window)
  end

  --- Zooms the window the cursor is in fully: it takes every column and row
  --- the other windows of the layout's tab page can spare, and they shrink to
  --- `'winminwidth'` columns or `'winminheight'` lines each, wherever they
  --- sit, their winbars and status lines still showing, `'winfixwidth'` and
  --- `'winfixheight'` as they were, and `'cmdheight'` untouched. Zoomed fully
  --- already, it gives every window the size it had when the zoom began, a
  --- manual resize before it included, scaled to the editor's size now when
  --- the editor was resized meanwhile; toggled with the cursor in another
  --- window, the zoom moves there. A zoom of the right column
  --- (`M.toggle_zoom()`) that was on stays on, as it was, once the full zoom
  --- ends. When a window opened or closed meanwhile, the recorded sizes no
  --- longer fit, and the layout's proportions are put back instead
  --- (`end_full_zoom()`).
  ---
  --- The zoom stays with the window it began in while the cursor goes
  --- elsewhere, through a resize of the editor, entering the layout's tab and
  --- the closing of a window other than the zoomed one. It ends as another
  --- pane shows (`switch_pane()`, and the terminal pane's shell ending or
  --- being wiped), as the run pane's stack gains or loses a window
  --- (`sync_run_windows()`), as `M.toggle_zoom()` zooms the right column and
  --- as the zoomed window closes (`keep_proportions()`).
  ---
  --- With the cursor in a floating window, in a tab page that is not the
  --- layout's, or with no layout open, it changes nothing and warns the user
  --- once.
  function M.toggle_full_zoom()
    local current = vim.api.nvim_get_current_win()
    if not is_zoomable_in_layout_tab(current) then
      vim.notify(NOTHING_TO_ZOOM_FULLY, vim.log.levels.WARN)
      return
    end
    local zoomed = state.full_zoom and state.full_zoom.window
    end_full_zoom()
    if zoomed ~= current then
      state.full_zoom = full_zoom.start(tab_windows(), current)
    end
  end

  --- The Input buffer, or `nil` before the layout was first opened.
  ---
  ---@return integer|nil buffer
  function M.input_buffer()
    return state.buffers.input
  end

  --- The rows a window's own status line takes under `'laststatus'`: one
  --- under 1, which gives a status line to each of two windows or more, as
  --- the layout's tab page has, and under 2; none under 0 and 3, whose one
  --- status line spans the screen and belongs to no window.
  ---
  ---@return integer rows
  local function status_line_rows()
    return (vim.o.laststatus == 1 or vim.o.laststatus == 2) and 1 or 0
  end

  --- The screen rectangle the right column's windows take now, their winbars
  --- and status lines included: all of the column, whichever pane it shows,
  --- and with a window of the column zoomed (`M.toggle_zoom()`) too, whose
  --- column still spans the same cells. `nil` when the column has no window,
  --- when the current tab page is not the layout's, whose cells these are not,
  --- and while a window is zoomed over the whole tab page (`M.toggle_full_zoom()`),
  --- which leaves the column's windows a line or a column each.
  ---
  ---@return aineo.layout.Area|nil area
  function M.right_column_area()
    local windows = column_windows()
    local full_zoomed = state.full_zoom and vim.api.nvim_win_is_valid(state.full_zoom.window)
    if
      #windows == 0
      or full_zoomed
      or vim.api.nvim_win_get_tabpage(windows[1]) ~= vim.api.nvim_get_current_tabpage()
    then
      return nil
    end
    local top, left, bottom, right = math.huge, math.huge, 0, 0
    for _, window in ipairs(windows) do
      local info = vim.fn.getwininfo(window)[1]
      local window_bottom = info.winrow - 1 + info.winbar + info.height + status_line_rows()
      top = math.min(top, info.winrow - 1)
      left = math.min(left, info.wincol - 1)
      bottom = math.max(bottom, window_bottom)
      right = math.max(right, info.wincol - 1 + info.width)
    end
    return { row = top, col = left, width = right - left, height = bottom - top }
  end

  --- The side of the screen Claude's column is on.
  ---
  ---@return aineo.layout.Side
  function M.claude_side()
    return state.claude_side
  end

  --- The side of the screen the explorer column is on, or `false` when the
  --- layout has none.
  ---
  ---@return aineo.layout.Side|false
  function M.explorer_column()
    return state.explorer_column
  end

  --- Moves Claude's column to `claude_side`, the right column across the
  --- screen from it and the file column between them, in the layout's tab
  --- page whether or not it is shown: the windows move, and Claude's terminal
  --- and its job, Input's draft, every pane's buffer, the file column's
  --- buffers and splits, each window's cursor and the window the cursor is in
  --- stay, and so does the explorer column, outermost on its side, with the
  --- file column beside it when it lies there (`arrangement.file_beside_explorer`). A zoom ends
  --- first, its sizes not given back (`M.toggle_zoom()`,
  --- `M.toggle_full_zoom()`), and the columns take the layout's proportions.
  --- With none of the layout's windows open, the layout opens on that side
  --- next (`M.open()`). Asked for the side it is on, it changes nothing.
  ---
  --- Raises an error naming `claude_side` when it is neither `'left'` nor
  --- `'right'`.
  ---
  ---@param claude_side aineo.layout.Side
  function M.set_claude_side(claude_side)
    vim.validate('claude_side', claude_side, side.is_side, false, "'left' or 'right'")
    if claude_side ~= state.claude_side then
      move_columns_to(claude_side)
    end
  end

  --- Mirrors the layout in one pass: Claude's column goes to `claude_side` and
  --- the explorer column, when the layout has one (`M.explorer_column()`), to
  --- `explorer_side`, the right column across from Claude's and the file
  --- column beside the explorer column or between the other two as
  --- `arrangement.file_beside_explorer` says. As `M.set_claude_side()` moves
  --- Claude's column, the windows move, never their buffers, jobs or splits,
  --- the cursor and the tab page shown stay, a zoom ends and windows across
  --- the screen keep their place. With no `explorer_side`, or no explorer
  --- column, it moves Claude's column alone; asked for the sides the layout
  --- has, it changes nothing. With none of the layout's windows open, only the
  --- sides are recorded, for the layout to open on.
  ---
  --- Raises an error naming the argument when `claude_side` or `explorer_side`,
  --- when given, is neither `'left'` nor `'right'`, before changing anything.
  ---
  ---@param claude_side aineo.layout.Side
  ---@param explorer_side? aineo.layout.Side
  function M.set_column_sides(claude_side, explorer_side)
    vim.validate('claude_side', claude_side, side.is_side, false, "'left' or 'right'")
    vim.validate('explorer_side', explorer_side, side.is_side, true, "'left' or 'right'")
    local moves_explorer = explorer_side ~= nil
      and state.explorer_column ~= false
      and explorer_side ~= state.explorer_column
    if claude_side ~= state.claude_side or moves_explorer then
      move_columns_to(claude_side, explorer_side)
    end
  end

  --- Makes the explorer column `explorer_column` at `explorer_width` cells in
  --- the layout's tab page whether or not it is shown, as handing the
  --- arrangement again does but without moving the cursor or the tab page: a
  --- column that is not open opens, one that is open moves to the other side,
  --- takes the width, or closes when it is `false`, the cursor of the tab page
  --- going to the file column first when it was in the column, and the other
  --- columns take the layout's proportions. A zoom ends first, its sizes not given
  --- back (`M.toggle_zoom()`, `M.toggle_full_zoom()`), and the explorer pane
  --- gives way to the agent pane while the column is a side. With none of the
  --- layout's windows open, only the column is recorded, for the layout to
  --- open with (`M.open()`). `file_beside_explorer`, when given, says whether the
  --- file column lies beside the explorer column while that is open
  --- (`arrangement.file_beside_explorer`): an open file column moves to the
  --- place it belongs, with its windows, buffers and cursors, as the column
  --- opens, closes, changes sides or the option changes. Asked for the column
  --- it has, at the width it has, with the option it has, it changes nothing,
  --- a zoom staying and a column closed by hand staying closed. The
  --- explorer's buffer must have been handed (`M.open()`,
  --- `M.keep_pane_buffer()`) when the column is a side.
  ---
  --- Raises an error naming `explorer_column` when it is neither a side nor
  --- `false`, `explorer_width` when it is not a positive whole number,
  --- `file_beside_explorer` when it is given and not a boolean, and the
  --- explorer's buffer when the column is a side and none was handed, before
  --- changing anything.
  ---
  ---@param explorer_column aineo.layout.Side|false
  ---@param explorer_width integer
  ---@param file_beside_explorer? boolean
  function M.set_explorer_column(explorer_column, explorer_width, file_beside_explorer)
    vim.validate(
      'explorer_column',
      explorer_column,
      is_explorer_column,
      false,
      "'left', 'right' or false"
    )
    vim.validate(
      'explorer_width',
      explorer_width,
      is_column_width,
      false,
      'a positive whole number'
    )
    vim.validate('file_beside_explorer', file_beside_explorer, 'boolean', true)
    if explorer_column then
      vim.validate('explorer buffer', state.buffers.explorer, is_buffer, false, 'a buffer')
    end
    local changes_the_column = explorer_column ~= state.explorer_column
      or (explorer_column and explorer_width ~= state.explorer_width)
      or (file_beside_explorer ~= nil and file_beside_explorer ~= state.file_beside_explorer)
    if changes_the_column and has_any_window() then
      vim.api.nvim_win_call(existing_windows()[1], function()
        end_full_zoom()
        end_zoom()
        leave_explorer_when_settings_change(explorer_column, file_beside_explorer)
      end)
    end
    state.explorer_column = explorer_column
    state.explorer_width = explorer_width
    if file_beside_explorer ~= nil then
      state.file_beside_explorer = file_beside_explorer
    end
    if not changes_the_column or not has_any_window() then
      return
    end
    if not explorer_column and has_explorer_column() then
      leave_explorer_column()
    end
    vim.api.nvim_win_call(existing_windows()[1], function()
      end_full_zoom()
      end_zoom()
      if explorer_column and state.pane == 'explorer' then
        if is_file_focus_applied() then
          state.pane = 'agent'
        else
          switch_pane('agent')
        end
      end
      remember_file_parts()
      keep_explorer_column()
      if is_laid_out() then
        apply_proportions()
      end
    end)
  end

  --- Whether the explorer column's window exists: false for a layout that has
  --- no column and for one whose column the user closed.
  ---
  ---@return boolean
  function M.explorer_column_is_open()
    return has_explorer_column()
  end

  --- Whether the panels show the user's own line numbers, sign column, fold
  --- column and status column (`M.set_panel_numbers()`).
  ---
  ---@return boolean
  function M.panel_numbers()
    return state.panel_numbers
  end

  --- Shows or hides the gutter of the layout's panels, the windows that show
  --- no file: Claude's window, the Report's, Input's, the explorer column's,
  --- the run pane's. `true` gives each the user's own line numbers, sign
  --- column, fold column and status column, those the global settings give
  --- every window; `false` takes them out, so that only the separator between
  --- windows is left, and every panel's buffer entering a window then has none
  --- either. Files, wherever they are shown, keep the user's own. The line
  --- numbers `M.toggle_claude_numbers()` set in Claude's window stay as they
  --- are. Works whether or not the layout is shown, and records the value for
  --- a layout opened later (`arrangement.panel_numbers`).
  ---
  --- Raises an error naming `panel_numbers` when it is not a boolean.
  ---
  ---@param panel_numbers boolean
  function M.set_panel_numbers(panel_numbers)
    vim.validate('panel_numbers', panel_numbers, 'boolean')
    state.panel_numbers = panel_numbers
    restyle_panel_gutters()
  end

  --- Opens the explorer column again, in place, in the layout's tab page
  --- whether or not it is shown, when the layout has one (`M.explorer_column()`)
  --- and its window was closed, as `set_explorer_column()` opens one: the cursor
  --- and the tab page shown stay and the other columns take the layout's
  --- proportions. Changes nothing otherwise, and while no window of the layout
  --- is open.
  function M.reopen_explorer_column()
    if not state.explorer_column or has_explorer_column() or not has_any_window() then
      return
    end
    vim.api.nvim_win_call(existing_windows()[1], function()
      end_full_zoom()
      end_zoom()
      keep_explorer_column()
      if is_laid_out() then
        apply_proportions()
      end
    end)
  end

  --- What `M.start_file_focus()` tells the user, as a warning, when none of
  --- the layout's windows is open.
  local NO_LAYOUT_TO_FOCUS =
    'aineo: no file focus — aineo’s layout is not open in this tab page; open it first'

  --- Whether the cursor is in a window of the panes column: the Report's,
  --- Input's or one of the run pane's.
  ---
  ---@return boolean
  local function cursor_is_in_panes_column()
    local current = vim.api.nvim_get_current_win()
    return vim.list_contains(run_stack_windows(), current)
      or (has_window('input') and state.windows.input == current)
  end

  --- Moves the cursor out of the panes column, to the file column's window
  --- that takes files, else Claude's window, when it is in the column.
  local function leave_panes_column()
    if not cursor_is_in_panes_column() then
      return
    end
    local target = window_taking_files() or (has_window('claude') and state.windows.claude)
    if target then
      vim.api.nvim_set_current_win(target)
    end
  end

  --- Closes the windows of the panes column that exist. The Report and its
  --- `b:changedtick` are noted as the agent pane is hidden, as
  --- `switch_pane()` does, so that a report that arrives meanwhile is
  --- followed when the pane shows again.
  local function close_panes_column()
    if state.pane == 'agent' and state.report_when_hidden == nil then
      state.report_when_hidden = {
        buffer = state.buffers.report,
        tick = vim.api.nvim_buf_get_changedtick(state.buffers.report),
      }
    end
    close_run_windows()
    close_input_window()
    if has_window('report') then
      close_when_possible(state.windows.report)
    end
  end

  --- Applies the file focus (`M.start_file_focus()`) now that a file column is
  --- open: the cursor leaves the panes column, a zoom ends, the views of the
  --- panes column's windows are kept and the column closes, and the file
  --- column takes its cells.
  apply_file_focus = function()
    leave_panes_column()
    vim.api.nvim_win_call(existing_windows()[1], function()
      end_full_zoom()
      end_zoom()
      local focus = state.file_focus
      focus.claude_width = focus.claude_width
        or (has_window('claude') and vim.api.nvim_win_get_width(state.windows.claude) or nil)
      focus.views = save_panes_views()
      focus.applied = true
      close_panes_column()
      apply_proportions()
    end)
  end

  --- Opens the panes column again, showing the pane it showed with the views
  --- it had (`restore_panes_views()`), as the file column closed, and leaves
  --- the file focus waiting for a file column.
  restore_panes_column = function()
    local focus = state.file_focus
    local views = focus.views
    focus.applied, focus.views = false, nil
    vim.api.nvim_win_call(existing_windows()[1], function()
      reopen_closed_windows()
      show_buffers()
      pin_windows()
      wrap_agent_pane()
      local report_arrived = state.report_when_hidden ~= nil and has_report_changed_while_hidden()
      follow_reports_shown_again()
      if state.pane == 'run' then
        sync_run_windows()
      else
        close_run_windows()
      end
      apply_proportions()
      restore_panes_views(views, report_arrived)
    end)
  end

  --- Turns the file focus on, for reading files at the width the panes column
  --- takes. With a file column open it is applied at once: the panes column
  --- — the Report's and Input's windows, and the run pane's — closes, and its
  --- cells go to the file column, which takes every cell but Claude's column's
  --- and the explorer column's, whose widths stay. With no file column the
  --- focus is armed instead and changes nothing: no window opens, closes or
  --- changes size, so that Claude's terminal is told no size; it is applied as
  --- the first file column opens (`M.show_file()`, or any window that makes
  --- one), Claude's column keeping the width it has. Closing the file column
  --- of an applied focus opens the panes column again, the focus armed.
  ---
  --- The pane shown stays the pane shown, and the views of its windows
  --- (`winsaveview()`) are kept; they show again when the layout opens
  --- (`M.open()`), which ends the focus, as does `M.end_file_focus()`, and
  --- when the file column closes. While the focus is applied, the layout keeps
  --- these proportions through a resize of the editor, a swap or a mirror of
  --- its columns and the explorer column opening, closing or moving, the
  --- explorer pane giving way to the agent pane unseen as the column opens; a
  --- file shown in the file column leaves the panes column closed
  --- (`M.show_file()`); and a zoom, of the panes column or fully, ends as it
  --- is applied, its sizes not given back. The cursor stays where it is, in a
  --- window of the panes column going to the file column. Changes nothing
  --- when the focus is on already; warns the user once, and changes nothing,
  --- when none of the layout's windows is open.
  function M.start_file_focus()
    if state.file_focus then
      return
    end
    if not has_any_window() then
      vim.notify(NO_LAYOUT_TO_FOCUS, vim.log.levels.WARN)
      return
    end
    state.file_focus = {
      applied = false,
      claude_width = has_window('claude') and vim.api.nvim_win_get_width(state.windows.claude)
        or nil,
    }
    if has_window('claude') and has_file_column() then
      apply_file_focus()
    end
  end

  --- Turns the file focus off, as `M.open()` does with `arrangement`, which
  --- may be a function that returns it, called only then: the panes column
  --- opens again at the proportions of the layout, showing the pane it
  --- showed, and the file stays in the file column, the cursor where it
  --- was. Changes nothing when the focus is off.
  ---
  ---@param arrangement aineo.layout.Arrangement|fun(): aineo.layout.Arrangement
  function M.end_file_focus(arrangement)
    if not state.file_focus then
      return
    end
    if type(arrangement) == 'function' then
      arrangement = arrangement()
    end
    M.open(arrangement)
  end

  --- Whether the file focus is on (`M.start_file_focus()`), applied or armed.
  ---
  ---@return boolean
  function M.is_file_focused()
    return state.file_focus ~= nil
  end

  --- Lets the layout go, as its tab page closes: removes its handlers, by
  --- deleting their group, and wipes its Input. Its windows are the tab
  --- page's to close. What Input holds goes with it, so a caller that keeps
  --- a draft saves it first.
  local function let_go()
    pcall(vim.api.nvim_del_augroup_by_name, group_name)
    local timer = state.fresh_size_timer
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
    if has_input() then
      vim.api.nvim_buf_delete(state.buffers.input, { force = true })
    end
  end

  return M, let_go
end

--- The number of layouts made, the module's included.
local layouts_made = 1

local M = make_layout('aineo://input', 'aineo.layout')

--- The side of the screen across from `claude_side`, where the right column
--- is when Claude's column is on `claude_side`.
---
---@param claude_side aineo.layout.Side
---@return aineo.layout.Side
function M.opposite_side(claude_side)
  return side.opposite(claude_side)
end

--- Whether the autocommand group `name` exists.
---
---@param name string
---@return boolean
local function has_group(name)
  return (pcall(vim.api.nvim_get_autocmds, { group = name }))
end

--- Makes a layout of its own, in addition to the module's and to every one
--- made before: its three windows, Input, pane, proportions, Claude's line
--- numbers and status line, and handlers are its own, and it opens in the tab
--- page its `open()` is called in. Its Input is named `aineo://input-<n>` and
--- its handlers are in the group `aineo.layout.<n>`, `<n>` being the next
--- number after those the layouts made since the module loaded took, and
--- one whose group exists: a module loaded again never takes the Input and
--- the handlers of a layout still alive.
---
--- The layout has a `let_go()` of its own, which the module's layout lacks:
--- it removes the layout's handlers and wipes its Input, for when its tab
--- page has closed.
---
---@return aineo.layout.Layout layout
function M.new()
  repeat
    layouts_made = layouts_made + 1
  until not has_group(('aineo.layout.%d'):format(layouts_made))
  local layout, let_go =
    make_layout(('aineo://input-%d'):format(layouts_made), ('aineo.layout.%d'):format(layouts_made))
  layout.let_go = let_go
  return layout
end

return M
