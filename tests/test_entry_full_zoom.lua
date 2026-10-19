local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local entry_shell = dofile('tests/helpers/entry_shell.lua')
local layout = dofile('tests/helpers/layout.lua')

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

--- What `\Z` tells the user when the cursor is in no window of an aineo tab
--- page, or in a floating window.
local NOTHING_TO_ZOOM =
  'aineo: nothing zoomed — the cursor is in no window of an aineo tab page, or in a floating window'

--- What `:Aineo zoom` tells the user when it is given a word it does not take.
local ZOOM_USAGE = 'aineo: :Aineo zoom takes one of full'

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, and waits until Claude Code is ready.
---
---@param name string the case's own name for its files, starting `full-zoom-`
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

--- The width and height of every window of the child's current tab, in the
--- order the tab lists them.
---
---@return { width: integer, height: integer }[] sizes
local function sizes()
  return child.lua_get([[vim.tbl_map(function(window)
    return { width = vim.api.nvim_win_get_width(window), height = vim.api.nvim_win_get_height(window) }
  end, vim.api.nvim_tabpage_list_wins(0))]])
end

--- The width of the window the child's cursor is in.
---
---@return integer width
local function current_width()
  return child.lua_get('vim.api.nvim_win_get_width(0)')
end

--- The width of the window the child's cursor is in once it is zoomed fully
--- beside one other column of windows: the screen less that column at its
--- least and the separator.
---
---@return integer width
local function zoomed_width()
  return entry.COLUMNS - child.o.winminwidth - 1
end

--- Puts the cursor in Claude's window, in Normal mode.
local function enter_claude()
  entry.press(child, '\\c')
  child.type_keys('<C-\\><C-n>')
end

--- Each way to zoom fully, as a set's `parametrize`: its name, and the
--- function that zooms.
local DOORS = {
  {
    'pressing \\Z',
    function()
      entry.press(child, '\\Z')
    end,
  },
  {
    'pressing <Plug>(aineo-zoom-full)',
    function()
      entry.press(child, '<Plug>(aineo-zoom-full)')
    end,
  },
  {
    'running :Aineo zoom full',
    function()
      entry.command(child, 'Aineo zoom full')
    end,
  },
}

T['zooming fully'] = MiniTest.new_set()

T['zooming fully']['takes every column the others can spare for Claude’s window, by'] =
  MiniTest.new_set({ parametrize = DOORS })

T['zooming fully']['takes every column the others can spare for Claude’s window, by']['a door'] = function(
  _,
  door
)
  open_layout('full-zoom-claude')
  enter_claude()

  door()

  eq(entry.messages(child), {})
  eq(current_width(), zoomed_width())
end

T['zooming fully']['twice gives every window the size it had, by'] =
  MiniTest.new_set({ parametrize = DOORS })

T['zooming fully']['twice gives every window the size it had, by']['a door'] = function(_, door)
  open_layout('full-zoom-twice')
  entry.press(child, '\\r')
  local before = sizes()

  door()
  local zoomed = current_width()
  door()

  eq(zoomed, zoomed_width())
  eq(sizes(), before)
end

T['zooming fully']['works from a right-column window and from Terminal mode as the terminal prefix’s <C-\\>Z'] = function()
  open_layout('full-zoom-terminal-mode')
  run_all({ 'sleep 30' })
  entry.press(child, '\\X')
  eq(child.lua_get('vim.api.nvim_get_mode().mode'), 't')

  child.type_keys('<C-\\>Z')

  eq(current_width(), zoomed_width())
end

T['zooming fully']['works from the file column'] = function()
  open_layout('full-zoom-file-column')
  child.cmd('edit ' .. layout.file('full-zoom-entry.txt'))
  local before = sizes()

  entry.press(child, '\\Z')

  eq(current_width(), entry.COLUMNS - 2 * (child.o.winminwidth + 1))
  entry.press(child, '\\Z')
  eq(sizes(), before)
end

T['zooming fully']['tells the user once before aineo has opened its layout'] = function()
  entry.press(child, '\\Z')

  eq(entry.messages(child), { { message = NOTHING_TO_ZOOM, level = 3 } })
end

T['zooming fully']['tells the user once from a tab page that is none of aineo’s, and zooms nothing'] = function()
  open_layout('full-zoom-other-page')
  child.cmd('tabnew')
  local before = sizes()

  entry.press(child, '\\Z')

  eq(entry.messages(child), { { message = NOTHING_TO_ZOOM, level = 3 } })
  eq(sizes(), before)
end

T['zooming fully']['with a word after full tells the user what :Aineo zoom takes and zooms nothing'] = function()
  open_layout('full-zoom-extra-word')
  entry.press(child, '\\r')
  local before = sizes()

  child.cmd('Aineo zoom full now')

  eq(entry.messages(child), { { message = ZOOM_USAGE, level = vim.log.levels.ERROR } })
  eq(sizes(), before)
end

T['zooming fully']['is offered by :Aineo zoom’s completion, and nothing after it'] = function()
  eq(child.fn.getcompletion('Aineo zoom ', 'cmdline'), { 'full' })
  eq(child.fn.getcompletion('Aineo zoom f', 'cmdline'), { 'full' })
  eq(child.fn.getcompletion('Aineo zoom full ', 'cmdline'), {})
end

T['a window zoomed fully'] = MiniTest.new_set()

T['a window zoomed fully']['ends as a process starts in the run pane, the windows sharing the screen again'] = function()
  open_layout('full-zoom-process-added')
  run_all({ 'sleep 30' })
  local before = sizes()
  entry.press(child, '\\Z')
  eq(current_width(), zoomed_width())

  run_all({ 'sleep 31' })

  local after = sizes()
  eq(after[1], before[1])
  eq(math.abs(after[2].height - after[3].height) <= 1, true)
end

T['a window zoomed fully']['ends as another pane shows'] = function()
  open_layout('full-zoom-pane-switch')
  entry.press(child, '\\r')
  local before = sizes()
  entry.press(child, '\\Z')
  eq(current_width(), zoomed_width())

  entry.press(child, '\\g')
  entry.press(child, '\\pa')

  eq(sizes(), before)
end

T['a window zoomed fully']['stays as the cursor goes to another window'] = function()
  open_layout('full-zoom-cursor')
  entry.press(child, '\\r')
  entry.press(child, '\\Z')
  local zoomed = sizes()
  eq(current_width(), zoomed_width())

  entry.press(child, '\\i')
  entry.press(child, '\\r')

  eq(sizes(), zoomed)
end

T['a window zoomed fully']['ends before \\z zooms the column'] = function()
  open_layout('full-zoom-then-column')
  entry.press(child, '\\r')
  local before = sizes()
  entry.press(child, '\\Z')
  eq(current_width(), zoomed_width())

  entry.press(child, '\\z')

  local after = sizes()
  eq(after[1], before[1])
  eq(after[2].width, before[2].width)
  eq(after[3].height, child.o.winminheight)
end

return T
