local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality
local no_eq = MiniTest.expect.no_equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The functions a layout offers as fields, as the module's own do.
local LAYOUT_FUNCTIONS = {
  { 'open' },
  { 'focus' },
  { 'show_pane' },
  { 'focus_pane' },
  { 'show_diff' },
  { 'follow_claude_terminal' },
  { 'toggle_claude_numbers' },
  { 'input_buffer' },
}

--- The expression, run in the child, that gives the number of the current
--- tab page.
local CURRENT_TAB = 'vim.api.nvim_tabpage_get_number(0)'

--- The expression, run in the child, that gives the mode it is in, as
--- `nvim_get_mode()` names it: `t` in Terminal mode, `nt` in Normal mode in a
--- terminal's window.
local MODE = 'vim.api.nvim_get_mode().mode'

--- The expression, run in the child, that gives, for the tab page whose
--- number is the argument, each of its windows with the buffer it shows and
--- its size.
local TAB_WINDOWS = [[(function(number)
  return vim.tbl_map(function(window)
    return {
      window = window,
      buffer = vim.api.nvim_win_get_buf(window),
      width = vim.api.nvim_win_get_width(window),
      height = vim.api.nvim_win_get_height(window),
    }
  end, vim.api.nvim_tabpage_list_wins(vim.api.nvim_list_tabpages()[number]))
end)(...)]]

--- The expression, run in the child, that gives the buffers shown in the
--- windows of the tab page whose number is the argument, left to right and
--- top to bottom as `nvim_tabpage_list_wins()` lists them.
local TAB_BUFFERS = [[(function(number)
  return vim.tbl_map(
    vim.api.nvim_win_get_buf,
    vim.api.nvim_tabpage_list_wins(vim.api.nvim_list_tabpages()[number])
  )
end)(...)]]

--- Makes, in `child`, a layout of its own in a new tab page, held as
--- `_G.second`, the cursor in its Input.
---
---@return { claude: integer, report: integer, input: integer } buffers the second layout's buffers
local function open_second_layout()
  local buffers = {
    claude = layout.terminal(child),
    report = layout.named_scratch(child, 'aineo://report-second'),
  }
  child.cmd('tabnew')
  child.lua(
    [[_G.second = require('aineo.layout').new(); _G.second.open(...)]],
    { layout.arrangement(buffers) }
  )
  buffers.input = child.lua_get('_G.second.input_buffer()')
  return buffers
end

--- Starts `child`, opens the module's own layout in its first tab page and a
--- layout of its own in a second one (`open_second_layout()`).
---
---@return { first: table, second: table } buffers the buffers of each layout, by role
local function open_two_layouts()
  local first = layout.open_with_stand_ins(child)
  return { first = first, second = open_second_layout() }
end

--- Calls `function_name` of the second layout in `child`, with `args`.
---
---@param function_name string
---@param ... any
local function call_second(function_name, ...)
  child.lua(('_G.second.%s(...)'):format(function_name), { ... })
end

T['new()'] = MiniTest.new_set()

T['new()']['gives a layout with the module’s function'] = MiniTest.new_set({
  parametrize = LAYOUT_FUNCTIONS,
})

T['new()']['gives a layout with the module’s function']['as a field'] = function(name)
  layout.start(child)

  eq(child.lua_get("type(require('aineo.layout').new()[...])", { name }), 'function')
end

T['new()']['gives a layout of its own on each call'] = function()
  layout.start(child)

  eq(child.lua_get("require('aineo.layout').new() == require('aineo.layout').new()"), false)
end

T['two layouts in two tabs'] = MiniTest.new_set()

T['two layouts in two tabs']['leave the first one’s windows, buffers and sizes as they were once the second opens'] = function()
  local first = layout.open_with_stand_ins(child)
  local windows_before = child.lua_get(TAB_WINDOWS, { 1 })

  open_second_layout()

  eq(child.lua_get(TAB_WINDOWS, { 1 }), windows_before)
  eq(child.lua_get('#vim.api.nvim_list_tabpages()'), 2)
  eq(child.lua_get(TAB_BUFFERS, { 1 }), { first.claude, first.report, first.input })
end

T['two layouts in two tabs']['hold the second one’s three windows in its own tab'] = function()
  local buffers = open_two_layouts().second

  eq(child.lua_get(TAB_BUFFERS, { 2 }), { buffers.claude, buffers.report, buffers.input })
  eq(child.lua_get(CURRENT_TAB), 2)
end

T['two layouts in two tabs']['give each Input a name of its own, the module’s keeping aineo://input'] = function()
  local buffers = open_two_layouts()

  eq(child.lua_get('vim.api.nvim_buf_get_name(...)', { buffers.first.input }), 'aineo://input')
  no_eq(child.lua_get('vim.api.nvim_buf_get_name(...)', { buffers.second.input }), 'aineo://input')
  no_eq(child.lua_get('vim.api.nvim_buf_get_name(...)', { buffers.second.input }), '')
end

T['two layouts in two tabs']['give a third layout a window set and an Input of its own too'] = function()
  local buffers = open_two_layouts()
  local second_tab = child.lua_get(TAB_WINDOWS, { 2 })
  child.cmd('tabnew')

  child.lua([[_G.third = require('aineo.layout').new(); _G.third.open(...)]], {
    layout.arrangement({
      claude = layout.terminal(child),
      report = layout.named_scratch(child, 'aineo://report-third'),
    }),
  })

  eq(child.lua_get(TAB_WINDOWS, { 2 }), second_tab)
  eq(child.lua_get('_G.third.input_buffer() ~= _G.second.input_buffer()'), true)
  eq(child.lua_get('_G.second.input_buffer()'), buffers.second.input)
end

T['two layouts in two tabs']['leave the first one’s Input alone when the second one’s is wiped'] = function()
  local buffers = open_two_layouts()

  child.lua('vim.api.nvim_buf_delete(..., { force = true })', { buffers.second.input })

  eq(child.lua_get('vim.api.nvim_buf_is_valid(...)', { buffers.first.input }), true)
  eq(child.lua_get('require("aineo.layout").input_buffer()'), buffers.first.input)
  eq(child.lua_get('vim.api.nvim_buf_get_name(...)', { buffers.first.input }), 'aineo://input')
end

T['focus() of a layout'] = MiniTest.new_set()

T['focus() of a layout']['moves to the second one’s tab from the first one’s'] = function()
  local buffers = open_two_layouts().second
  child.cmd('tabfirst')

  call_second('focus', 'report', layout.arrangement(buffers))

  eq(child.lua_get(CURRENT_TAB), 2)
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), buffers.report)
end

T['focus() of a layout']['moves to the first one’s tab from the second one’s'] = function()
  local buffers = open_two_layouts().first

  layout.focus(child, 'report', layout.arrangement(buffers))

  eq(child.lua_get(CURRENT_TAB), 1)
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), buffers.report)
end

--- Makes, in `child`, two scratch buffers for a changes pane and returns the
--- arrangement `buffers` makes with them.
---
---@param buffers { claude: integer, report: integer }
---@return table arrangement
local function arrangement_with_changes(buffers)
  local arrangement = layout.arrangement(buffers)
  arrangement.changes = child.lua_get(
    [[{ files = vim.api.nvim_create_buf(false, true), commits = vim.api.nvim_create_buf(false, true) }]]
  )
  return arrangement
end

T['the changes pane of a layout'] = MiniTest.new_set()

T['the changes pane of a layout']['shown in the first one leaves the second one’s right column on the agent pane'] = function()
  local buffers = open_two_layouts()
  local arrangement = arrangement_with_changes(buffers.first)

  child.lua("require('aineo.layout').show_pane('changes', ...)", { arrangement })

  eq(
    child.lua_get(TAB_BUFFERS, { 1 }),
    { buffers.first.claude, arrangement.changes.files, arrangement.changes.commits }
  )
  eq(
    child.lua_get(TAB_BUFFERS, { 2 }),
    { buffers.second.claude, buffers.second.report, buffers.second.input }
  )
end

T['the changes pane of a layout']['shown in the second one leaves the first one’s right column on the agent pane'] = function()
  local buffers = open_two_layouts()
  local arrangement = arrangement_with_changes(buffers.second)

  call_second('show_pane', 'changes', arrangement)

  eq(
    child.lua_get(TAB_BUFFERS, { 2 }),
    { buffers.second.claude, arrangement.changes.files, arrangement.changes.commits }
  )
  eq(
    child.lua_get(TAB_BUFFERS, { 1 }),
    { buffers.first.claude, buffers.first.report, buffers.first.input }
  )
end

T['focus_pane() of a layout'] = MiniTest.new_set()

T['focus_pane() of a layout']['moves to the second one’s tab, the cursor in the commits window of its changes pane'] = function()
  local buffers = open_two_layouts()
  local arrangement = arrangement_with_changes(buffers.second)
  child.cmd('tabfirst')

  call_second('focus_pane', 'changes', arrangement)

  eq(child.lua_get(CURRENT_TAB), 2)
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), arrangement.changes.commits)
end

--- Opens the module's layout again with `buffers`, from whichever tab page
--- the cursor is in: it shows the tab of that layout.
---
---@param buffers { claude: integer, report: integer }
local function reopen_first_layout(buffers)
  layout.open(child, layout.arrangement(buffers))
end

T['the handlers of a layout'] = MiniTest.new_set()

T['the handlers of a layout']['keep each layout at its proportions as the editor is resized, whichever opened last'] = function()
  local buffers = open_two_layouts()
  child.o.columns = 120
  child.o.lines = 40

  child.cmd('tabfirst')

  layout.expect_near(layout.boxes(child, buffers.first).claude.width, 120 / 2)
  reopen_first_layout(buffers.first)
  child.o.columns = 100
  child.cmd('tablast')
  layout.expect_near(layout.boxes(child, buffers.second).claude.width, 100 / 2)
end

--- The expression, run in the child, that gives the `'buftype'` of the buffer
--- the argument names.
local BUFTYPE = 'vim.bo[...].buftype'

--- Deletes with `:bdelete` the Input of the layout whose tab is the current
--- one, and shows it again in its window, as `:buffer` does.
---
---@param buffers { claude: integer, report: integer, input: integer }
local function delete_input_and_show_it_again(buffers)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('bdelete')
  child.cmd('buffer ' .. buffers.input)
end

T['the handlers of a layout']['keep the first one’s Input a scratch buffer once the second one opened'] = function()
  local buffers = open_two_layouts()
  child.cmd('tabfirst')

  delete_input_and_show_it_again(buffers.first)

  eq(child.lua_get(BUFTYPE, { buffers.first.input }), 'nofile')
end

T['the handlers of a layout']['keep the second one’s Input a scratch buffer once the first one opened again'] = function()
  local buffers = open_two_layouts()
  reopen_first_layout(buffers.first)
  child.cmd('tablast')

  delete_input_and_show_it_again(buffers.second)

  eq(child.lua_get(BUFTYPE, { buffers.second.input }), 'nofile')
end

--- Opens a file from the window showing `buffer`, in the current tab, and
--- waits until the layout's redirect has made a window for it.
---
---@param buffer integer
---@param name string
---@return integer file_buffer
local function open_file_from_window_showing(buffer, name)
  layout.enter_window_showing(child, buffer)
  child.cmd('edit ' .. layout.file(name))
  eq(layout.wait_until(child, '#vim.api.nvim_tabpage_list_wins(0) == 4'), true)
  return child.lua_get('vim.fn.bufnr(...)', { layout.file(name) })
end

--- Where the window showing `buffer`, in the current tab, sits in relation to
--- Claude's window showing `claude`: the column it starts at, less the
--- column right of Claude's window and its separator.
---
---@param claude integer
---@param buffer integer
---@return integer offset 0 when `buffer`'s window is the file column right of Claude's
local function columns_right_of_claude(claude, buffer)
  local claude_box = layout.box(child, layout.window_showing(child, claude))
  local box = layout.box(child, layout.window_showing(child, buffer))
  return box.col - (claude_box.col + claude_box.width + 1)
end

T['the handlers of a layout']['move a file opened in the second one’s Input to the file column of its tab'] = function()
  local buffers = open_two_layouts()
  local first_tab = child.lua_get(TAB_WINDOWS, { 1 })

  local file = open_file_from_window_showing(buffers.second.input, 'first.txt')

  eq(columns_right_of_claude(buffers.second.claude, file), 0)
  eq(child.lua_get(TAB_WINDOWS, { 1 }), first_tab)
end

T['the handlers of a layout']['move a file opened in the first one’s Input to the file column of its tab'] = function()
  local buffers = open_two_layouts()
  local second_tab = child.lua_get(TAB_WINDOWS, { 2 })
  child.cmd('tabfirst')

  local file = open_file_from_window_showing(buffers.first.input, 'second.txt')

  eq(columns_right_of_claude(buffers.first.claude, file), 0)
  eq(child.lua_get(TAB_WINDOWS, { 2 }), second_tab)
end

T['show_diff() of a layout'] = MiniTest.new_set()

T['show_diff() of a layout']['shows the diff in the file column of the second one’s tab, from the first one’s'] = function()
  open_two_layouts()
  child.cmd('tabfirst')
  local first_tab = child.lua_get(TAB_WINDOWS, { 1 })
  local diff = child.lua_get([[(function()
      local buffer = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(buffer, 'aineo://diff/second.txt')
      return buffer
    end)()]])

  local window = child.lua_get('_G.second.show_diff(...)', { diff })

  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { window }), diff)
  eq(
    child.lua_get(
      'vim.api.nvim_win_get_tabpage(...) == vim.api.nvim_list_tabpages()[2]',
      { window }
    ),
    true
  )
  eq(child.lua_get(TAB_WINDOWS, { 1 }), first_tab)
  eq(child.lua_get(CURRENT_TAB), 1)
  eq(#child.lua_get(TAB_WINDOWS, { 2 }), 4)
end

--- The expression, run in the child, that gives the line numbers the first
--- window showing the buffer the argument names shows.
local NUMBERS_OF_BUFFER_WINDOW = [[(function(buffer)
  local window = vim.fn.win_findbuf(buffer)[1]
  return { number = vim.wo[window].number, relativenumber = vim.wo[window].relativenumber }
end)(...)]]

T['the Claude window of a layout'] = MiniTest.new_set()

T['the Claude window of a layout']['shows the line numbers the second one toggled, the first one’s showing none'] = function()
  local buffers = open_two_layouts()

  call_second('toggle_claude_numbers')

  eq(
    child.lua_get(NUMBERS_OF_BUFFER_WINDOW, { buffers.second.claude }),
    { number = true, relativenumber = false }
  )
  eq(
    child.lua_get(NUMBERS_OF_BUFFER_WINDOW, { buffers.first.claude }),
    { number = false, relativenumber = false }
  )
end

T['the Claude window of a layout']['shows the line numbers the first one toggled from the second one’s tab, the second one’s showing none'] = function()
  local buffers = open_two_layouts()

  child.lua("require('aineo.layout').toggle_claude_numbers()")

  eq(
    child.lua_get(NUMBERS_OF_BUFFER_WINDOW, { buffers.first.claude }),
    { number = true, relativenumber = false }
  )
  eq(
    child.lua_get(NUMBERS_OF_BUFFER_WINDOW, { buffers.second.claude }),
    { number = false, relativenumber = false }
  )
  eq(child.lua_get(CURRENT_TAB), 2)
end

--- The status line the second layout is handed for its Claude window.
local SECOND_STATUSLINE = 'the second Claude window'

--- The status line the first layout is handed for its Claude window.
local FIRST_STATUSLINE = 'the first Claude window'

T['the Claude window of a layout']['draws the status line of its own layout for the terminal it follows'] = function()
  local first = layout.open_with_stand_ins(child)
  child.lua(
    "require('aineo.layout').open(...)",
    { vim.tbl_extend('force', layout.arrangement(first), { claude_statusline = FIRST_STATUSLINE }) }
  )
  local second = open_second_layout()
  child.lua('_G.second.open(...)', {
    vim.tbl_extend('force', layout.arrangement(second), { claude_statusline = SECOND_STATUSLINE }),
  })
  local followed = layout.terminal(child)
  child.lua(
    [[(function(shown, buffer)
      vim.api.nvim_win_set_buf(vim.fn.win_findbuf(shown)[1], buffer)
    end)(...)]],
    { second.claude, followed }
  )

  call_second('follow_claude_terminal', followed)

  eq(
    child.lua_get('vim.wo[vim.fn.win_findbuf(...)[1]].statusline', { followed }),
    SECOND_STATUSLINE
  )
  eq(
    child.lua_get('vim.wo[vim.fn.win_findbuf(...)[1]].statusline', { first.claude }),
    FIRST_STATUSLINE
  )
end

--- Puts the cursor in the window showing `terminal`, in Terminal mode, ends
--- the terminal's process, and waits until Neovim has left Terminal mode.
---
---@param terminal integer
---@return boolean left_terminal_mode
local function end_terminal_entered(terminal)
  layout.enter_window_showing(child, terminal)
  child.type_keys('i')
  child.lua('vim.fn.jobstop(vim.bo[...].channel)', { terminal })
  return layout.wait_until(child, MODE .. " == 'nt'")
end

T['the Claude window of a layout']['leaves Terminal mode as the second one’s terminal ends'] = function()
  local buffers = open_two_layouts()

  eq(end_terminal_entered(buffers.second.claude), true)
end

T['the Claude window of a layout']['leaves Terminal mode as the first one’s terminal ends, once the second one opened'] = function()
  local buffers = open_two_layouts()
  child.cmd('tabfirst')

  eq(end_terminal_entered(buffers.first.claude), true)
end

--- The expression, run in the child, that unlists every buffer but the one
--- the argument names, so that none is listed once that one is wiped and
--- Neovim leaves an empty buffer where it was shown.
local UNLIST_BUT = [[(function(kept)
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    vim.bo[buffer].buflisted = buffer == kept
  end
end)(...)]]

T['the Claude window of a layout']['closes with its terminal wiped there, the other layout’s staying whole'] =
  MiniTest.new_set({
    parametrize = { { 'second', 2, 1 }, { 'first', 1, 2 } },
  })

T['the Claude window of a layout']['closes with its terminal wiped there, the other layout’s staying whole']['when it is the'] = function(
  wiped,
  wiped_tab,
  kept_tab
)
  local buffers = open_two_layouts()
  local kept_windows = child.lua_get(TAB_WINDOWS, { kept_tab })
  child.cmd(wiped_tab .. 'tabnext')
  layout.enter_window_showing(child, buffers[wiped].claude)
  child.lua(UNLIST_BUT, { buffers[wiped].claude })

  child.cmd('bwipeout! ' .. buffers[wiped].claude)

  eq(#child.lua_get(TAB_WINDOWS, { wiped_tab }), 2)
  eq(child.lua_get(TAB_WINDOWS, { kept_tab }), kept_windows)
end

T['a layout whose tab page was closed'] = MiniTest.new_set()

T['a layout whose tab page was closed']['opens in the current tab, leaving the first one’s tab alone'] = function()
  local buffers = open_two_layouts()
  local first_tab = child.lua_get(TAB_WINDOWS, { 1 })
  child.cmd('tabclose')
  child.cmd('tabnew')
  local new_tab_buffer = child.lua_get('vim.api.nvim_get_current_buf()')

  call_second('open', layout.arrangement(buffers.second))

  eq(child.lua_get(CURRENT_TAB), 2)
  eq(
    child.lua_get(TAB_BUFFERS, { 2 }),
    { buffers.second.claude, new_tab_buffer, buffers.second.report, buffers.second.input }
  )
  eq(child.lua_get(TAB_WINDOWS, { 1 }), first_tab)
end

T['a layout whose tab page was closed']['has no window to toggle the line numbers of, and raises nothing'] = function()
  open_two_layouts()
  child.cmd('tabclose')

  eq(child.lua_get('pcall(_G.second.toggle_claude_numbers)'), true)
end

--- The expression, run in the child, that gives the names of the
--- autocommand groups of the layouts, sorted.
local LAYOUT_GROUPS = [[(function()
  local names = {}
  for _, autocmd in ipairs(vim.api.nvim_get_autocmds({})) do
    if autocmd.group_name and autocmd.group_name:find('^aineo%.layout') then
      names[autocmd.group_name] = true
    end
  end
  local sorted = vim.tbl_keys(names)
  table.sort(sorted)
  return sorted
end)()]]

--- The expression, run in the child, that gives the names of the buffers
--- that are Input of a layout, sorted.
local INPUT_NAMES = [[(function()
  local names = {}
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buffer)
    if name:find('aineo://input', 1, true) then
      table.insert(names, name:match('aineo://input.*$'))
    end
  end
  table.sort(names)
  return names
end)()]]

T['a layout let go'] = MiniTest.new_set()

T['a layout let go']['leaves no handler group and no Input behind, the first one working'] = function()
  local buffers = open_two_layouts()
  child.cmd('tabclose')

  call_second('let_go')

  eq(#child.lua_get(LAYOUT_GROUPS), 1)
  eq(child.lua_get(INPUT_NAMES), { 'aineo://input' })
  layout.focus(child, 'input', layout.arrangement(buffers.first))
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), buffers.first.input)
end

T['a layout let go']['is offered by the layouts new() makes, not by the module'] = function()
  open_two_layouts()

  eq(child.lua_get("type(require('aineo.layout').let_go)"), 'nil')
  eq(child.lua_get('type(_G.second.let_go)'), 'function')
end

T['a layout let go']['leaves the first one redirecting files opened in its Input'] = function()
  local buffers = open_two_layouts()
  child.cmd('tabclose')
  call_second('let_go')

  local file = open_file_from_window_showing(buffers.first.input, 'first.txt')

  eq(columns_right_of_claude(buffers.first.claude, file), 0)
end

T['a layout made after the module was loaded again'] = MiniTest.new_set()

T['a layout made after the module was loaded again']['takes a number no live layout holds, leaving the older layout its Input and its handlers'] = function()
  local buffers = open_two_layouts()
  child.lua("package.loaded['aineo.layout'] = nil; _G.reloaded = require('aineo.layout')")
  child.cmd('tabnew')
  local third = {
    claude = layout.terminal(child),
    report = layout.named_scratch(child, 'aineo://report-third'),
  }

  child.lua('_G.third = _G.reloaded.new(); _G.third.open(...)', { layout.arrangement(third) })

  no_eq(child.lua_get('_G.third.input_buffer()'), buffers.second.input)
  eq(#child.lua_get('vim.fn.win_findbuf(...)', { buffers.second.input }), 1)
  child.cmd('2tabnext')
  local file = open_file_from_window_showing(buffers.second.input, 'first.txt')
  eq(columns_right_of_claude(buffers.second.claude, file), 0)
end

T['the windows between two columns'] = MiniTest.new_set()

T['the windows between two columns']['are none when no row of the tree holds the windows held'] =
  MiniTest.new_set({
    parametrize = {
      { { held = { 1000, 9999 }, left = 1000 } },
      { { held = { 9998, 9999 }, left = 9998, right = 9999 } },
    },
  })

T['the windows between two columns']['are none when no row of the tree holds the windows held']['given'] = function(
  bounds
)
  layout.start(child)

  eq(
    child.lua_get(
      [[require('aineo.layout.columns').windows_between(
        { 'row', { { 'leaf', 1000 }, { 'leaf', 1001 }, { 'leaf', 1002 } } }, ...)]],
      { bounds }
    ),
    {}
  )
end

--- The width of the first window showing `buffer`.
---
---@param buffer integer
---@return integer width
local function width_of_window_showing(buffer)
  return child.lua_get('vim.api.nvim_win_get_width(vim.fn.win_findbuf(...)[1])', { buffer })
end

--- Sets the width of the first window showing `buffer`.
---
---@param buffer integer
---@param width integer
local function set_width_of_window_showing(buffer, width)
  child.lua(
    [[(function(buffer, width)
      vim.api.nvim_win_set_width(vim.fn.win_findbuf(buffer)[1], width)
    end)(...)]],
    { buffer, width }
  )
end

--- The expression, run in the child, that tells whether the first window
--- showing the buffer the first argument names is within a cell of the width
--- the second argument gives.
local WIDTH_NEAR = [[(function(buffer, width)
  return math.abs(vim.api.nvim_win_get_width(vim.fn.win_findbuf(buffer)[1]) - width) <= 1
end)(...)]]

--- How wide the editor is made where a case needs a width other than the
--- child's default.
local WIDE = 120

T['the file column of the second layout'] = MiniTest.new_set()

T['the file column of the second layout']['takes a second file opened in its Input in the window of the first'] = function()
  local buffers = open_two_layouts()
  open_file_from_window_showing(buffers.second.input, 'first.txt')
  layout.enter_window_showing(child, buffers.second.input)

  child.cmd('edit ' .. layout.file('second.txt'))

  eq(
    layout.wait_until(
      child,
      'vim.fn.bufnr(...) > 0 and #vim.fn.win_findbuf(vim.fn.bufnr(...)) == 1',
      { layout.file('second.txt') }
    ),
    true
  )
  eq(#child.lua_get(TAB_WINDOWS, { 2 }), 4)
end

T['the file column of the second layout']['takes a file opened in its Input while the first layout has a file column of its own'] = function()
  local buffers = open_two_layouts()
  child.cmd('tabfirst')
  open_file_from_window_showing(buffers.first.input, 'first.txt')
  local first_tab = child.lua_get(TAB_WINDOWS, { 1 })
  child.cmd('tablast')

  local file = open_file_from_window_showing(buffers.second.input, 'second.txt')

  eq(columns_right_of_claude(buffers.second.claude, file), 0)
  eq(child.lua_get(TAB_WINDOWS, { 1 }), first_tab)
end

T['the proportions of the second layout'] = MiniTest.new_set()

T['the proportions of the second layout']['are put back when its tab is entered'] = function()
  local buffers = open_two_layouts()
  child.o.columns = WIDE
  set_width_of_window_showing(buffers.second.claude, 20)

  child.cmd('tabfirst')
  child.cmd('tablast')

  layout.expect_near(width_of_window_showing(buffers.second.claude), WIDE / 2)
end

T['the proportions of the second layout']['are put back as the editor is resized'] = function()
  local buffers = open_two_layouts()
  child.o.columns = WIDE
  set_width_of_window_showing(buffers.second.claude, 20)

  child.o.columns = WIDE - 20

  eq(layout.wait_until(child, WIDTH_NEAR, { buffers.second.claude, (WIDE - 20) / 2 }), true)
end

T['the proportions of the second layout']['are put back as the window of a file column closes'] = function()
  local buffers = open_two_layouts()
  child.o.columns = WIDE
  local file = open_file_from_window_showing(buffers.second.input, 'first.txt')

  child.lua('vim.api.nvim_win_close(vim.fn.win_findbuf(...)[1], false)', { file })

  eq(layout.wait_until(child, WIDTH_NEAR, { buffers.second.claude, WIDE / 2 }), true)
end

T['the Claude terminal of the second layout'] = MiniTest.new_set()

T['the Claude terminal of the second layout']['is not entered in Terminal mode once its process ended and was seen to'] = function()
  local buffers = open_two_layouts()
  child.lua(
    [[
      vim.uv.kill = function()
        return 0
      end
      _G.term_closed = false
      vim.api.nvim_create_autocmd('TermClose', {
        callback = function()
          _G.term_closed = true
        end,
      })
      vim.fn.jobstop(vim.bo[...].channel)
    ]],
    { buffers.second.claude }
  )
  eq(layout.wait_until(child, '_G.term_closed'), true)
  layout.enter_window_showing(child, buffers.second.claude)

  child.type_keys('i')

  eq(child.lua_get(MODE), 'nt')
end

T['the Claude terminal of the second layout']['is not entered in Terminal mode once its process is gone'] = function()
  local buffers = open_two_layouts()
  child.lua('vim.fn.jobstop(vim.bo[...].channel)', { buffers.second.claude })
  eq(
    layout.wait_until(
      child,
      'vim.fn.jobwait({ vim.bo[...].channel }, 0)[1] ~= -1',
      { buffers.second.claude }
    ),
    true
  )
  layout.enter_window_showing(child, buffers.second.claude)

  child.type_keys('i')

  eq(child.lua_get(MODE), 'nt')
end

return T
