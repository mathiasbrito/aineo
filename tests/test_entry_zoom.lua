local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local entry_shell = dofile('tests/helpers/entry_shell.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that ends, in the child, the process of every terminal by a
--- hangup, and waits for each to end, at most 5 s each.
local END_TERMINALS = [[
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      local job = vim.b[buffer].terminal_job_id
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 5000)
    end
  end
]]

--- Stops the child, once the fake Claude Code it runs, if any, and the
--- processes of the run pane have ended by a hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      entry.restart(child)
      child.o.shell = entry_shell.TEST_SHELL
      child.lua([[
        _G.run_answers = {}
        vim.ui.input = function(_, on_confirm)
          on_confirm(table.remove(_G.run_answers, 1))
        end
      ]])
    end,
    post_once = stop_the_child,
  },
})

--- What `\z` tells the user when the cursor is in none of the right
--- column's windows.
local NOT_IN_THE_COLUMN =
  'aineo: nothing zoomed — the cursor is in none of the windows aineo shows in the right column (the agent, changes, terminal, run and explorer panes)'

--- What `:Aineo zoom` tells the user when it is given a word it does not take.
local ZOOM_USAGE = 'aineo: :Aineo zoom takes one of full'

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, and waits until Claude Code is ready.
---
---@param name string the case's own name for its files, starting `zoom-`
local function open_layout(name)
  local fake = claude_session.fake(name, 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

--- Starts, in the child's run pane, a process for each of `commands`, by
--- `\x`, the cursor ending in the last one's window.
---
---@param commands string[]
local function run_all(commands)
  for _, command in ipairs(commands) do
    child.lua('table.insert(_G.run_answers, ...)', { command })
    entry.press(child, '\\x')
  end
end

--- The expression, run in the child, that lists the text height of each
--- window right of the first column of its current tab, top to bottom: the
--- windows of the right column.
local COLUMN_HEIGHTS = [[(function()
  local column = {}
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local position = vim.api.nvim_win_get_position(window)
    if position[2] > 0 and vim.api.nvim_win_get_config(window).relative == '' then
      table.insert(column, { row = position[1], height = vim.fn.winheight(window) })
    end
  end
  table.sort(column, function(a, b)
    return a.row < b.row
  end)
  return vim.tbl_map(function(window)
    return window.height
  end, column)
end)()]]

--- The text height of each window of the child's right column, top to bottom.
---
---@return integer[]
local function column_heights()
  return child.lua_get(COLUMN_HEIGHTS)
end

--- The heights of a column of `count` windows whose window at `position` is
--- zoomed, over `lines` text lines in all: one line for each of the others.
---
---@param lines integer
---@param count integer
---@param position integer
---@return integer[] heights
local function zoomed_at(lines, count, position)
  local heights = {}
  for index = 1, count do
    heights[index] = index == position and lines - (count - 1) or 1
  end
  return heights
end

--- The text lines the windows of the child's right column show together.
---
---@return integer lines
local function column_lines()
  local lines = 0
  for _, height in ipairs(column_heights()) do
    lines = lines + height
  end
  return lines
end

--- Each way to zoom, as a set's `parametrize`: its name, and the function
--- that zooms.
local DOORS = {
  {
    'pressing \\z',
    function()
      entry.press(child, '\\z')
    end,
  },
  {
    'pressing <Plug>(aineo-zoom)',
    function()
      entry.press(child, '<Plug>(aineo-zoom)')
    end,
  },
  {
    'running :Aineo zoom',
    function()
      entry.command(child, 'Aineo zoom')
    end,
  },
}

T['zooming'] = MiniTest.new_set()

T['zooming']['gives the Report the right column’s height under the agent pane, by'] =
  MiniTest.new_set({ parametrize = DOORS })

T['zooming']['gives the Report the right column’s height under the agent pane, by']['a door'] = function(
  _,
  door
)
  open_layout('zoom-agent')
  entry.press(child, '\\r')
  local lines = column_lines()

  door()

  eq(column_heights(), zoomed_at(lines, 2, 1))
end

T['zooming']['gives the commits the right column’s height under the changes pane'] = function()
  open_layout('zoom-changes')
  entry.press(child, '\\g')
  local lines = column_lines()

  entry.press(child, '\\z')

  eq(column_heights(), zoomed_at(lines, 2, 2))
end

T['zooming']['gives the window the cursor is in the right column’s height under the run pane'] = function()
  open_layout('zoom-run')
  run_all({ 'sleep 30', 'sleep 31', 'sleep 32' })
  local lines = column_lines()

  entry.press(child, '\\z')

  eq(column_heights(), zoomed_at(lines, 3, 3))
end

T['zooming']['gives the terminal pane’s one window the column’s height, which it has'] = function()
  open_layout('zoom-terminal')
  entry.press(child, '\\pt')
  local before = column_heights()

  entry.press(child, '\\z')

  eq(entry.messages(child), {})
  eq(column_heights(), before)
end

T['zooming']['twice gives the windows the heights they had'] = function()
  open_layout('zoom-twice')
  entry.press(child, '\\r')
  local before = column_heights()

  entry.press(child, '\\z')
  entry.press(child, '\\z')

  eq(column_heights(), before)
end

T['zooming']['stays with the window it began in as the cursor goes to another'] = function()
  open_layout('zoom-cursor')
  entry.press(child, '\\r')
  entry.press(child, '\\z')
  local zoomed = column_heights()

  entry.press(child, '\\i')

  eq(column_heights(), zoomed)
end

T['zooming']['moves to the window the cursor is in when pressed in another window of the column'] = function()
  open_layout('zoom-move')
  entry.press(child, '\\r')
  local lines = column_lines()
  entry.press(child, '\\z')
  entry.press(child, '\\i')

  entry.press(child, '\\z')

  eq(column_heights(), zoomed_at(lines, 2, 2))
end

T['zooming']['tells the user once and changes nothing with the cursor in Claude’s window'] = function()
  open_layout('zoom-claude-window')
  local before = column_heights()
  entry.press(child, '\\c')
  child.type_keys('<C-\\><C-n>')

  entry.press(child, '\\z')

  eq(entry.messages(child), { { message = NOT_IN_THE_COLUMN, level = 3 } })
  eq(column_heights(), before)
end

T['zooming']['tells the user once from a tab page that is none of aineo’s'] = function()
  open_layout('zoom-other-page')
  child.cmd('tabnew')

  entry.press(child, '\\z')

  eq(entry.messages(child), { { message = NOT_IN_THE_COLUMN, level = 3 } })
  child.cmd('tabprevious')
  MiniTest.expect.no_equality(column_heights()[2], 1)
end

T['zooming']['tells the user once before aineo has opened its layout'] = function()
  entry.press(child, '\\z')

  eq(entry.messages(child), { { message = NOT_IN_THE_COLUMN, level = 3 } })
end

T['zooming']['with a word after zoom tells the user what :Aineo takes and zooms nothing'] = function()
  open_layout('zoom-extra-word')
  entry.press(child, '\\r')
  local before = column_heights()

  child.cmd('Aineo zoom now')

  eq(entry.messages(child), { { message = ZOOM_USAGE, level = vim.log.levels.ERROR } })
  eq(column_heights(), before)
end

T['zooming']['works from Terminal mode as the terminal prefix’s <C-\\>z'] = function()
  open_layout('zoom-terminal-mode')
  run_all({ 'sleep 30' })
  entry.press(child, '\\X')
  local lines = column_lines()
  eq(child.lua_get('vim.api.nvim_get_mode().mode'), 't')

  child.type_keys('<C-\\>z')

  eq(column_heights(), zoomed_at(lines, 2, 2))
end

T['a zoomed column'] = MiniTest.new_set()

for _, pane_key in ipairs({ '\\g', '\\pt' }) do
  T['a zoomed column'][('leaves no trace in the heights of the agent pane once %s has shown another pane and \\pa this one'):format(
    pane_key
  )] = function()
    open_layout('zoom-switch' .. pane_key:gsub('\\', ''))
    entry.press(child, '\\r')
    entry.press(child, pane_key)
    entry.press(child, '\\pa')
    local without_zoom = column_heights()
    entry.press(child, '\\r')
    entry.press(child, '\\z')

    entry.press(child, pane_key)
    entry.press(child, '\\pa')

    eq(column_heights(), without_zoom)
  end
end

T['a zoomed column']['gives the changes pane its heights back as the agent pane shows'] = function()
  open_layout('zoom-switch-changes')
  entry.press(child, '\\g')
  local before = column_heights()
  entry.press(child, '\\z')

  entry.press(child, '\\pa')
  entry.press(child, '\\g')

  eq(column_heights(), before)
end

T['a zoomed column']['keeps its zoom as \\pa asks for the agent pane it shows'] = function()
  open_layout('zoom-pane-shown-agent')
  entry.press(child, '\\r')
  entry.press(child, '\\z')
  local zoomed = column_heights()

  entry.press(child, '\\pa')

  eq(column_heights(), zoomed)
end

T['a zoomed column']['keeps its zoom as \\x moves the cursor into the run pane it shows'] = function()
  open_layout('zoom-pane-shown-run')
  run_all({ 'sleep 30', 'sleep 31' })
  entry.press(child, '\\z')
  local zoomed = column_heights()
  entry.press(child, '\\c')
  child.type_keys('<C-\\><C-n>')

  entry.press(child, '\\x')

  eq(column_heights(), zoomed)
end

T['a zoomed column']['ends its zoom as a process starts in the run pane, the windows sharing the column'] = function()
  open_layout('zoom-process-added')
  run_all({ 'sleep 30', 'sleep 31' })
  entry.press(child, '\\z')

  run_all({ 'sleep 32' })

  local heights = column_heights()
  eq(math.abs(heights[1] - heights[2]) <= 1 and math.abs(heights[2] - heights[3]) <= 1, true)
end

return T
