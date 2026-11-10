local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local layout = dofile('tests/helpers/layout.lua')
local tabs = dofile('tests/helpers/entry_tabs.lua')

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

--- Stops the child, once the fake Claude Codes it runs, if any, have ended by
--- a hangup (`END_TERMINALS`).
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
      child.o.termguicolors = true
    end,
    post_once = stop_the_child,
  },
})

--- What the layout's windows show under the agent pane, left to right, with
--- Claude Code on the left.
local CLAUDE_LEFT = { 'terminal', 'aineo://report', 'aineo://input' }

--- What they show with Claude Code on the right.
local CLAUDE_RIGHT = { 'aineo://report', 'aineo://input', 'terminal' }

--- Opens the layout in the child with aineo running the fake `claude` under
--- `name`, and waits until Claude Code is ready.
---
---@param name string the case's own name for its files, starting `layout-side-`
---@param settings? table more of `vim.g.aineo`
local function open_layout(name, settings)
  entry.use_fake(child, claude_session.fake(name, 'ready'), settings)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

--- Each way to put Claude Code on the right, as a set's `parametrize`: the
--- name of the way, and the function that does it.
local WAYS_TO_THE_RIGHT = {
  {
    'running :Aineo layout right',
    function()
      entry.command(child, 'Aineo layout right')
    end,
  },
  {
    'pressing <Plug>(aineo-layout-right)',
    function()
      entry.press(child, '<Plug>(aineo-layout-right)')
    end,
  },
}

T['putting Claude Code on the right'] = MiniTest.new_set()

T['putting Claude Code on the right']['moves its column to the right of the screen, by'] =
  MiniTest.new_set({ parametrize = WAYS_TO_THE_RIGHT })

T['putting Claude Code on the right']['moves its column to the right of the screen, by']['a way'] = function(
  _,
  way
)
  open_layout('layout-side-right')

  way()

  eq(entry.windows(child), CLAUDE_RIGHT)
  eq(entry.messages(child), {})
end

T['putting Claude Code on the right']['keeps Claude Code running in the same terminal'] = function()
  open_layout('layout-side-right-job')
  local terminal = tabs.claude_terminal_of_tab(child, 1)
  local job = child.lua_get('vim.bo[...].channel', { terminal })

  entry.command(child, 'Aineo layout right')

  eq(child.lua_get('vim.bo[...].channel', { terminal }), job)
  eq(claude_session.wait_for_status(child, 'ready'), { 'ready' })
end

T['putting Claude Code on the right']['leaves a draft in Input and the cursor window as they were'] = function()
  open_layout('layout-side-right-draft')
  entry.press(child, '\\i')
  entry.set_input(child, { 'a draft to send' })
  local before = child.lua_get('vim.api.nvim_get_current_win()')

  entry.command(child, 'Aineo layout right')

  eq(child.lua_get('vim.api.nvim_get_current_win()'), before)
  eq(
    child.lua_get("vim.api.nvim_buf_get_lines(require('aineo.layout').input_buffer(), 0, -1, true)"),
    { 'a draft to send' }
  )
end

T['putting Claude Code on the right']['changes nothing when Claude Code is on the right already'] = function()
  open_layout('layout-side-right-twice')
  entry.command(child, 'Aineo layout right')

  entry.command(child, 'Aineo layout right')

  eq(entry.windows(child), CLAUDE_RIGHT)
end

T['putting Claude Code on the left'] = MiniTest.new_set()

T['putting Claude Code on the left']['moves its column back to the left of the screen'] = function()
  open_layout('layout-side-left')
  entry.command(child, 'Aineo layout right')

  entry.command(child, 'Aineo layout left')

  eq(entry.windows(child), CLAUDE_LEFT)
end

--- Whether the window showing `buffer` lies left of the window showing
--- `other` in the child's current tab.
---
---@param buffer integer
---@param other integer
---@return boolean
local function lies_left_of(buffer, other)
  return layout.box(child, layout.window_showing(child, buffer)).col
    < layout.box(child, layout.window_showing(child, other)).col
end

T['swapping the layout'] = MiniTest.new_set()

T['swapping the layout']['moves Claude Code to the other side each time, by :Aineo layout swap'] = function()
  open_layout('layout-side-swap')

  entry.command(child, 'Aineo layout swap')
  local swapped = entry.windows(child)
  entry.command(child, 'Aineo layout swap')

  eq({ swapped, entry.windows(child) }, { CLAUDE_RIGHT, CLAUDE_LEFT })
end

T['swapping the layout']['moves Claude Code to the other side by <Plug>(aineo-layout-swap)'] = function()
  open_layout('layout-side-swap-plug')

  entry.press(child, '<Plug>(aineo-layout-swap)')

  eq(entry.windows(child), CLAUDE_RIGHT)
end

T['swapping the layout']['swaps from the side the setting names'] = function()
  open_layout('layout-side-swap-setting', { layout = { claude_side = 'right' } })

  entry.command(child, 'Aineo layout swap')

  eq(entry.windows(child), CLAUDE_LEFT)
end

T['swapping the layout']['ends a zoom of the right column'] = function()
  open_layout('layout-side-swap-zoom')
  entry.press(child, '\\r')
  entry.press(child, '\\z')
  local zoomed_before = child.lua_get([[require('aineo.layout').is_zoomed()]])

  entry.command(child, 'Aineo layout swap')

  eq({ zoomed_before, child.lua_get([[require('aineo.layout').is_zoomed()]]) }, { true, false })
end

T['swapping the layout']['moves the layout of every aineo tab'] = function()
  local _, first = tabs.open_first_tab(child, 'layout-side-swap-tabs')
  tabs.use_next_fake(child, tabs.fake('layout-side-swap-tabs-second'))
  child.cmd('Aineo tab new')
  claude_session.wait_for_status(child, 'ready')
  child.cmd('tabfirst')

  entry.command(child, 'Aineo layout swap')

  eq(tabs.windows_of_tab(child, 1), CLAUDE_RIGHT)
  eq(tabs.windows_of_tab(child, 2), CLAUDE_RIGHT)
  eq(#claude_session.wait_for_starts(first, 1), 1)
end

T['swapping the layout']['opens a tab made later on the side it left Claude Code on'] = function()
  tabs.open_first_tab(child, 'layout-side-swap-later')
  entry.command(child, 'Aineo layout swap')

  tabs.use_next_fake(child, tabs.fake('layout-side-swap-later-second'))
  child.cmd('Aineo tab new')
  claude_session.wait_for_status(child, 'ready')

  eq(tabs.windows_of_tab(child, 2), CLAUDE_RIGHT)
end

T['swapping the layout']['restores a closed layout on the side it left Claude Code on'] = function()
  open_layout('layout-side-swap-restore')
  entry.command(child, 'Aineo layout swap')
  child.cmd('only')

  entry.press(child, '\\o')

  eq(entry.windows(child), CLAUDE_RIGHT)
end

T['swapping the layout']['restores a closed window beside the others on its side'] = function()
  open_layout('layout-side-swap-window')
  entry.command(child, 'Aineo layout swap')
  child.cmd('only')
  entry.press(child, '\\o')
  child.cmd('wincmd t')
  child.cmd('close')

  entry.press(child, '\\r')

  eq(entry.windows(child), CLAUDE_RIGHT)
end

T['the layout side'] = MiniTest.new_set()

T['the layout side']['is the one layout.claude_side names when the layout opens'] = function()
  open_layout('layout-side-setting', { layout = { claude_side = 'right' } })

  eq(entry.windows(child), CLAUDE_RIGHT)
end

T['the layout side']['is chosen before any aineo tab exists, for the first to open on'] = function()
  entry.use_fake(child, claude_session.fake('layout-side-before-open', 'ready'))

  entry.command(child, 'Aineo layout right')
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')

  eq(entry.windows(child), CLAUDE_RIGHT)
  eq(entry.messages(child), {})
end

T['the layout side']['is chosen over the setting for the editor’s life'] = function()
  open_layout('layout-side-over-setting', { layout = { claude_side = 'right' } })

  entry.command(child, 'Aineo layout left')
  child.cmd('only')
  entry.press(child, '\\o')

  eq(entry.windows(child), CLAUDE_LEFT)
end

T['the clients of the right column'] = MiniTest.new_set()

--- The window of the cheatsheet in the child, `nil` when none shows.
---
---@return integer|nil
local function sheet_window()
  return child.lua_get([[(function()
    return vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(function(window)
      return vim.bo[vim.api.nvim_win_get_buf(window)].filetype == 'aineo-cheatsheet'
    end)
  end)()]])
end

T['the clients of the right column']['show the cheatsheet over the panes column, on the left once Claude Code is on the right'] = function()
  open_layout('layout-side-cheatsheet')
  entry.command(child, 'Aineo layout right')

  entry.command(child, 'Aineo cheatsheet')

  local sheet = layout.box(child, sheet_window())
  local report = layout.box(
    child,
    layout.window_showing(child, child.lua_get([[vim.fn.bufnr('aineo://report')]]))
  )
  eq(sheet.col, report.col)
  eq(sheet.width, report.width)
end

T[':Aineo layout'] = MiniTest.new_set()

T[':Aineo layout']['tells the user the words it takes when given another or none'] =
  MiniTest.new_set({
    parametrize = { { 'Aineo layout' }, { 'Aineo layout up' }, { 'Aineo layout swap now' } },
  })

T[':Aineo layout']['tells the user the words it takes when given another or none']['command'] = function(
  command
)
  entry.command(child, command)

  eq(entry.messages(child), {
    {
      message = 'aineo: :Aineo layout takes one of swap, left, right',
      level = vim.log.levels.ERROR,
    },
  })
end

T[':Aineo layout']['completes swap, left and right'] = function()
  eq(
    child.lua_get([[vim.fn.getcompletion('Aineo layout ', 'cmdline')]]),
    { 'swap', 'left', 'right' }
  )
end

T['swapping the layout']['swaps from the side the layout is on, whatever the setting says now'] = function()
  open_layout('layout-side-swap-setup')
  child.lua([[require('aineo').setup({ layout = { claude_side = 'right' } })]])

  entry.command(child, 'Aineo layout swap')

  eq(entry.windows(child), CLAUDE_RIGHT)
end

T['swapping the layout']['with a window across the screen keeps the file column between the columns'] =
  MiniTest.new_set({
    parametrize = { { 'botright 6new' }, { 'help' } },
  })

T['swapping the layout']['with a window across the screen keeps the file column between the columns']['opened by'] = function(
  command
)
  open_layout('layout-side-swap-across')
  entry.press(child, '\\i')
  child.cmd('edit ' .. layout.file('first.txt'))
  local file = child.lua_get('vim.api.nvim_get_current_buf()')
  entry.press(child, '\\i')
  child.cmd(command)
  local report = child.lua_get([[vim.fn.bufnr('aineo://report')]])
  local claude = tabs.claude_terminal_of_tab(child, 1)

  entry.command(child, 'Aineo layout swap')

  eq(lies_left_of(report, file), true)
  eq(lies_left_of(file, claude), true)
end

return T
