--- aineo's layout, `require('aineo.layout')`: the Claude terminal in a column
--- on the left, and a column on the right whose windows show one pane at
--- a time — the agent pane, the Report above Input; the changes pane; the
--- terminal pane, a shell's terminal in the Report's window alone, taking the
--- whole column, with Input's window closed while the pane shows; the run
--- pane, a stack of terminals taking the whole column, the first in the
--- Report's window and each next in a window of its own below it; or the
--- explorer pane, a tree of files in the Report's window alone, taking the
--- whole column, Input's window closed as under the terminal pane.
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
local full_zoom = require('aineo.layout.full_zoom')
local zoom = require('aineo.layout.zoom')

---@class aineo.layout.Arrangement
---@field claude integer the Claude session's terminal buffer
---@field report integer the Report buffer
---@field report_height number the Report's share of the right column's height, strictly between 0 and 1
---@field changes? aineo.layout.ChangesPane the changes pane's buffers; without them the layout keeps those it was handed last
---@field shell? integer the terminal pane's buffer, the terminal of a shell, shown alone in the right column, in the Report's window; without it the layout keeps the one it was handed last, if its shell lives
---@field run? aineo.layout.RunPane the run pane's terminals; without them the run pane has nothing to show, and the layout shows the agent pane in its place
---@field explorer? integer the explorer pane's buffer, the tree of the folder Claude works in, shown alone in the right column, in the Report's window; without it the layout keeps the one it was handed last
---@field claude_statusline? string the 'statusline' Claude's window draws for Claude's terminal; without it the layout keeps the one it was handed last, and before any, Claude's window draws the user's own

---@class aineo.layout.ChangesPane
---@field files integer the buffer the changes pane shows in the Report's window
---@field commits integer the buffer the changes pane shows in Input's window

---@class aineo.layout.RunPane
---@field buffers integer[] the terminals the run pane stacks, top to bottom, at least one: the first in the Report's window, each next in a window of its own below it
---@field winbar string the 'winbar' each of the run pane's windows draws for its terminal

---@alias aineo.layout.Role 'claude'|'report'|'input'

---@alias aineo.layout.Pane 'agent'|'changes'|'terminal'|'run'|'explorer'

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
---@field show_diff fun(diff: integer): integer|nil
---@field follow_claude_terminal fun(terminal: integer)
---@field toggle_claude_numbers fun()
---@field toggle_zoom fun()
---@field toggle_full_zoom fun()
---@field input_buffer fun(): integer|nil
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

  --- The layout's windows, by role, and the buffers they show, by role or, for
  --- the changes pane's and the shell's, by name; the pane the right column
  --- shows, for the editor's life; the Report and its `b:changedtick` as they
  --- were when the agent pane was hidden, until the agent pane shows again
  --- with the Report in the Report's window;
  --- the view each buffer a switch took out of the right column had there,
  --- by buffer, until a switch shows it again (`show_in_place()`);
  --- the Report's share of the right column's height, Claude's
  --- terminal once Neovim has seen its process end, the line numbers
  --- `M.toggle_claude_numbers()` last set in Claude's window, those it showed
  --- before it hid them, and the window and buffer those line numbers were
  --- last shown for; the status line Claude's window draws for Claude's
  --- terminal, the one handed last; the diffs `M.show_diff()` showed, by
  --- buffer; while the Report's window closes with the shell's terminal in
  --- it, whether the cursor was in that window, and the ID of such a window
  --- that closed on its own (`note_shell_window_closing()`); whether Input's
  --- window was already closed when the terminal pane took the column, which
  --- the agent pane then leaves closed as the shell ends; the terminals and
  --- winbar the run pane was handed last, and the windows it opened below
  --- the Report's, top to bottom; the zoom of the right column, if it is
  --- zoomed (`M.toggle_zoom()`); and the window zoomed fully, if one is
  --- (`M.toggle_full_zoom()`).
  local state = {
    ---@type table<aineo.layout.Role, integer>
    windows = {},
    ---@type table<aineo.layout.Role|'files'|'commits'|'shell'|'run'|'explorer', integer>
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
  --- for Input; the run pane opens more windows below the Report's, which
  --- are no role of the layout.
  ---@type table<aineo.layout.Pane, table<aineo.layout.Role, string>>
  local PANE_BUFFERS = {
    agent = { report = 'report', input = 'input' },
    changes = { report = 'files', input = 'commits' },
    terminal = { report = 'shell' },
    run = { report = 'run' },
    explorer = { report = 'explorer' },
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

  --- The file column's windows, top to bottom: those of the columns right of
  --- Claude's column and left of the right one, in the row that holds the
  --- layout's windows; with Claude's window closed, those left of the right
  --- column, and with both of the right column's closed, those right of
  --- Claude's. None when the file column is not open.
  ---
  ---@return integer[] windows
  local function file_column_windows()
    local tree = vim.fn.winlayout(vim.api.nvim_tabpage_get_number(layout_tab()))
    return columns.windows_between(tree, {
      held = existing_windows(),
      left = has_window('claude') and state.windows.claude or nil,
      right = right_column_window(),
    })
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

  --- Sizes the columns. With the file column open, Claude's column and the right
  --- one take a third each of the screen's columns, the two separators taken
  --- out, and the file column the rest; without it, Claude's column takes half
  --- and the right one the rest.
  local function size_columns()
    if has_file_column() then
      local third = math.floor((vim.o.columns - 2) / 3)
      vim.api.nvim_win_set_width(state.windows.claude, third)
      vim.api.nvim_win_set_width(state.windows.report, third)
    else
      vim.api.nvim_win_set_width(state.windows.claude, math.floor(vim.o.columns / 2))
    end
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

  --- Puts the layout's proportions back: the columns' widths, the Report's
  --- share of the right column's rows when Input's window shows, and the
  --- equal shares of the run pane's stack; with the right column zoomed, the
  --- zoom is kept in their place (`keep_zoom()`), and with a window zoomed
  --- fully, that zoom is kept in place of all of them (`keep_full_zoom()`).
  local function apply_proportions()
    if keep_full_zoom() then
      return
    end
    size_columns()
    if keep_zoom() then
      return
    end
    if has_window('input') then
      size_right_column()
    end
    equalize_run_windows()
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

  --- Ends the full zoom, if a window is zoomed fully. When the tab page holds
  --- the windows it held as the zoom began, every window gets the size it had
  --- (a zoom of the right column that was on stays on). When a window opened
  --- or closed meanwhile, those sizes no longer apply: the layout's
  --- proportions are put back (`apply_proportions()`), and, while the layout
  --- is not open, because the zoomed window of the layout closed, the windows
  --- that remain get the sizes they had.
  local function end_full_zoom()
    local zoomed = state.full_zoom
    if not zoomed then
      return
    end
    state.full_zoom = nil
    local holds_the_same_windows = has_any_window()
      and vim.deep_equal(tab_windows(), zoomed.windows)
    if not holds_the_same_windows and is_open() then
      apply_proportions()
    else
      full_zoom.restore(zoomed)
    end
  end

  --- Puts the layout's proportions back while it is open, and does nothing
  --- once a window the pane shown needs is gone. A full zoom whose window is
  --- gone ends first (`end_full_zoom()`), the layout open or not.
  local function keep_proportions()
    if state.full_zoom and not vim.api.nvim_win_is_valid(state.full_zoom.window) then
      end_full_zoom()
    end
    if is_open() then
      apply_proportions()
    end
  end

  --- Opens a file column showing `file`, with the cursor in it: right of
  --- Claude's column, or, with Claude's window closed, at the left of the tab
  --- holding the layout's `window`.
  ---
  ---@param file integer
  ---@param window integer one of the layout's windows
  ---@return integer file_window
  local function open_file_column(file, window)
    if has_window('claude') then
      return vim.api.nvim_open_win(file, true, { split = 'right', win = state.windows.claude })
    end
    vim.api.nvim_set_current_win(window)
    return vim.api.nvim_open_win(file, true, { split = 'left', win = -1 })
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

  --- Moves `file` from the layout's `window` to the file column (see
  --- `place_in_file_column()`), with the cursor there on the position it had in
  --- `window`, gives `window` its own buffer back, and puts the proportions back
  --- while the layout is open (`is_open()`). When the file column has no
  --- room for `file`, leaves it in `window` and warns. Does nothing when
  --- `window` is no longer one of the layout's windows — closed, or replaced
  --- by a window the layout reopened — no longer shows `file`, or has no
  --- buffer of its own to take back, its own having been wiped.
  ---
  ---@param window integer
  ---@param file integer
  local function redirect(window, file)
    local role = role_of(window)
    if
      not role
      or not has_window(role)
      or vim.api.nvim_win_get_buf(window) ~= file
      or not vim.api.nvim_buf_is_valid(own_buffer(role))
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
    vim.api.nvim_win_set_buf(window, own_buffer(role))
    keep_proportions()
  end

  --- Redirects a file shown in one of the layout's windows, once the command
  --- that showed it has finished with that window. A window's own buffer is
  --- never taken for a file there, whatever its options.
  ---
  ---@param event { buf: integer }
  local function redirect_when_file(event)
    local window = vim.api.nvim_get_current_win()
    local role = role_of(window)
    if not role or event.buf == own_buffer(role) or not is_file(event.buf) then
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
  local function build()
    local start = starting_window()
    local shown = vim.api.nvim_win_get_buf(start)
    hide_other_windows(start)
    local input = take_input_buffer(shown)
    local input_window = start
    if shown ~= input and is_file_to_keep(shown) then
      input_window =
        vim.api.nvim_open_win(own_buffer('input'), false, { split = 'right', win = -1 })
    else
      vim.api.nvim_win_set_buf(input_window, own_buffer('input'))
    end
    local report_window =
      vim.api.nvim_open_win(own_buffer('report'), false, { split = 'above', win = input_window })
    local claude_window =
      vim.api.nvim_open_win(own_buffer('claude'), false, { split = 'left', win = -1 })
    state.windows = { claude = claude_window, report = report_window, input = input_window }
    vim.api.nvim_set_current_win(input_window)
    if not PANE_BUFFERS[state.pane].input then
      close_input_window()
    end
  end

  --- Opens the Report's window again, showing its own buffer: above Input, or
  --- above the first window of the run pane's stack that remains when Input
  --- is closed, or as the rightmost column when there is none either.
  local function open_report_window()
    local below = right_column_window()
    local place = below and { split = 'above', win = below } or { split = 'right', win = -1 }
    state.windows.report = vim.api.nvim_open_win(own_buffer('report'), false, place)
  end

  --- Opens again, in their places, those of the layout's windows that were
  --- closed, each showing its buffer: Claude's as the leftmost column, the
  --- Report above Input, or as the rightmost column when Input is closed too,
  --- and Input below the Report, unless the pane shown has none for Input.
  local function reopen_closed_windows()
    if not has_window('claude') then
      state.windows.claude =
        vim.api.nvim_open_win(own_buffer('claude'), false, { split = 'left', win = -1 })
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

  --- Keeps Input a scratch buffer and redirects the files shown in the layout's
  --- windows; keeps Claude's terminal in Normal mode once its process has ended
  --- (`leave_terminal_mode_as_claude_exits()`, `remember_claude_exit()`,
  --- `refuse_terminal_mode_once_claude_exited()`) and closes Claude's window
  --- when its terminal is wiped there (`close_claude_window_when_wiped()`);
  --- keeps Claude's line numbers and status line as Claude's terminal enters
  --- a window (`keep_claude_window_on_entry()`); and puts the proportions back
  --- whenever a window closes, the editor is resized or a tab is entered,
  --- replacing what an earlier call set up.
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
      { group = group, callback = keep_claude_window_on_entry }
    )
    vim.api.nvim_create_autocmd('WinClosed', {
      group = group,
      callback = function()
        vim.schedule(keep_proportions)
      end,
    })
    vim.api.nvim_create_autocmd('VimResized', { group = group, callback = keep_proportions })
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
    vim.validate('arrangement.changes', arrangement.changes, 'table', true)
    vim.validate('arrangement.claude_statusline', arrangement.claude_statusline, 'string', true)
    vim.validate('arrangement.shell', arrangement.shell, is_buffer, true, 'a buffer')
    vim.validate('arrangement.explorer', arrangement.explorer, is_buffer, true, 'a buffer')
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

  --- Opens Input's window below the Report's, or as the rightmost column when
  --- the Report's is closed too, showing the buffer `pane` shows there, gives
  --- the Report its share of the column (also with Claude's window closed),
  --- puts the proportions back and gives the window the view kept for that buffer,
  --- once the window has its size.
  ---
  ---@param pane aineo.layout.Pane
  local function open_input_window(pane)
    local buffer = state.buffers[PANE_BUFFERS[pane].input]
    local place = has_window('report') and { split = 'below', win = state.windows.report }
      or { split = 'right', win = -1 }
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
  --- the terminal pane and the run pane.
  ---
  ---@param pane aineo.layout.Pane
  ---@return boolean
  local function takes_whole_column(pane)
    return PANE_BUFFERS[pane].input == nil
  end

  --- Closes or opens Input's window as the pane shown changes from `from` to
  --- `to`: closed as a pane that takes the whole column (the terminal pane,
  --- the run pane) takes it, opened again as it gives way. Nothing between
  --- panes that all show Input, nor between panes that all take the column.
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
  --- Raises an error naming the setting, before changing anything, when
  --- `arrangement` is not a table, `claude` or `report` is not an existing
  --- buffer, `report_height` is not a number strictly between 0 and 1, or
  --- `changes`, when given, is not a table whose `files` and `commits` are
  --- existing buffers, or `shell`, when given, is not an existing buffer, or
  --- `run`, when given, is not a table whose `buffers` are at least one
  --- existing buffer and whose `winbar` is a string, or `explorer`, when
  --- given, is not an existing buffer, or `claude_statusline`, when given, is
  --- not a string.
  ---
  ---@param arrangement aineo.layout.Arrangement
  function M.open(arrangement)
    validate_arrangement(arrangement)
    take_arrangement(arrangement)
    forget_wiped_shell()
    if has_any_window() then
      vim.api.nvim_set_current_tabpage(layout_tab())
      if not has_input() then
        make_input(buffer_named_input() or vim.api.nvim_create_buf(false, true))
      end
      reopen_closed_windows()
      show_buffers()
    else
      build()
    end
    state.report_height = arrangement.report_height
    pin_windows()
    wrap_agent_pane()
    follow_reports_shown_again()
    keep_claude_numbers()
    keep_claude_statusline()
    if state.pane == 'run' then
      sync_run_windows()
    else
      close_run_windows()
    end
    apply_proportions()
    watch_windows()
    watch_shell()
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
  --- `'changes'`, `'terminal'`, `'run'` and `'explorer'`, and one naming
  --- `arrangement.changes` when the changes pane is asked for and no
  --- arrangement has handed its buffers, `arrangement.run` when the run pane
  --- is asked for with none handed, `arrangement.explorer` when the explorer
  --- pane is asked for and no arrangement has handed its buffer, or
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
    end, false, "'agent', 'changes', 'terminal', 'run' or 'explorer'")
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
  --- and under the terminal, run and explorer panes, which show the shell,
  --- the first terminal and the tree; Input's, which shows the commits, under
  --- the changes pane.
  ---@type table<aineo.layout.Pane, aineo.layout.Role>
  local PANE_LANDING = {
    agent = 'report',
    changes = 'input',
    terminal = 'report',
    run = 'report',
    explorer = 'report',
  }

  --- Shows `pane` as `M.show_pane()` does, then moves the cursor to the window
  --- the pane lands it in: the Report's window under the agent pane and
  --- under the terminal pane, which shows the shell there and enters no mode,
  --- and under the run and explorer panes, the commits window under the
  --- changes pane. The cursor moves even when the pane was shown already, and
  --- from another tab page into the layout's own. When showing the pane
  --- raises, the cursor stays where it is.
  ---
  --- Raises the errors `M.show_pane()` raises, and an error naming `pane` when
  --- it is none of `'agent'`, `'changes'`, `'terminal'`, `'run'` and
  --- `'explorer'`.
  ---
  ---@param pane aineo.layout.Pane
  ---@param arrangement aineo.layout.Arrangement|fun(): aineo.layout.Arrangement
  function M.focus_pane(pane, arrangement)
    M.show_pane(pane, arrangement)
    vim.api.nvim_set_current_win(state.windows[PANE_LANDING[pane]])
  end

  --- Shows `diff`, a buffer that is no file — a diff the changes pane shows —
  --- in the file column, as a file opened from one of the layout's windows is
  --- shown there (`place_in_file_column()`), and returns its window. A file or
  --- a diff shown in the file column later takes `diff`'s window in its turn
  --- (`window_taking_files()`): the column keeps one window for them. The
  --- layout's proportions are put back once `diff` is placed, as they are
  --- once a file is (`keep_proportions()`): with a file column open, the
  --- three columns take a third each. The cursor stays in the window it was
  --- in. When the screen has no room for `diff` — no room above a file that
  --- cannot leave the column's window, or for a new file column (E36) — it
  --- shows `diff` nowhere and returns nil.
  --- With none of the layout's windows open, `diff` opens in a window above
  --- the current one. Raises any other error a window raises as it is made or
  --- given `diff`.
  ---
  ---@param diff integer
  ---@return integer|nil window
  function M.show_diff(diff)
    state.diffs[diff] = true
    local current = vim.api.nvim_get_current_win()
    local placed, window
    if has_any_window() then
      placed, window =
        pcall(place_in_file_column, diff, right_column_window() or state.windows.claude)
    else
      placed, window = pcall(open_window_above, diff, current)
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
  --- 'relativenumber', when it shows either, and shows those it showed before
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
    'aineo: nothing zoomed — the cursor is in none of the windows aineo shows in the right column (the agent, changes, terminal, run and explorer panes)'

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

  --- Lets the layout go, as its tab page closes: removes its handlers, by
  --- deleting their group, and wipes its Input. Its windows are the tab
  --- page's to close. What Input holds goes with it, so a caller that keeps
  --- a draft saves it first.
  local function let_go()
    pcall(vim.api.nvim_del_augroup_by_name, group_name)
    if has_input() then
      vim.api.nvim_buf_delete(state.buffers.input, { force = true })
    end
  end

  return M, let_go
end

--- The number of layouts made, the module's included.
local layouts_made = 1

local M = make_layout('aineo://input', 'aineo.layout')

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
