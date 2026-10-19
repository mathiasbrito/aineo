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

--- Stops the child, once the fake Claude Code it runs and the processes of
--- the run pane have ended by a hangup (`END_TERMINALS`).
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

--- A process that prints 100 lines, waits for a line typed into it, prints
--- 200 more, and runs on: more lines than a window of the run pane holds.
local PRINTS_THEN_WAITS = 'seq 1 100; read ready; seq 101 300; sleep 30'

--- The last line the process of `PRINTS_THEN_WAITS` prints.
local LAST_OUTPUT = '300'

--- Opens the layout in the child with aineo running the fake `claude`, and
--- waits until Claude Code has launched.
---
---@param name string the case's own name for its files, starting `run-follow-`
local function open_layout(name)
  local fake = claude_session.fake(name, 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
end

--- Starts each of `commands` in the child by `\x`, answering its prompt.
---
---@param commands string[]
local function run_all(commands)
  for _, command in ipairs(commands) do
    child.lua('table.insert(_G.run_answers, ...)', { command })
    entry.press(child, '\\x')
  end
end

--- The terminals of the first aineo tab's processes, oldest first.
---
---@return integer[]
local function process_buffers()
  return child.lua_get("require('aineo.run').buffers()")
end

--- Has the process behind `buffer` read its waiting line, and waits until the
--- last line of its output is in the buffer.
---
---@param buffer integer
local function release_and_wait_for_last_output(buffer)
  entry_shell.type_into(child, buffer, '')
  eq(entry_shell.shows(child, buffer, LAST_OUTPUT), true)
end

--- Where the window showing `buffer` in the child stands: whether its cursor
--- is on the buffer's last line, and whether that line is in view.
---
---@param buffer integer
---@return { follows: boolean, last_line_in_view: boolean }
local function standing_of(buffer)
  return child.lua_get(
    [[(function(buffer)
      local window = vim.fn.win_findbuf(buffer)[1]
      local last = vim.api.nvim_buf_line_count(buffer)
      return vim.api.nvim_win_call(window, function()
        return {
          follows = vim.api.nvim_win_get_cursor(window)[1] == last,
          last_line_in_view = vim.fn.line('w$') == last,
        }
      end)
    end)(...)]],
    { buffer }
  )
end

--- The cursor line of the window showing `buffer` in the child.
---
---@param buffer integer
---@return integer
local function cursor_line_of(buffer)
  return child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.win_findbuf((...))[1])[1]', { buffer })
end

--- Closes the window showing `buffer` in the child as the user does, with
--- `:q` in it.
---
---@param buffer integer
local function quit_window_of(buffer)
  child.lua('vim.api.nvim_set_current_win(vim.fn.win_findbuf((...))[1])', { buffer })
  child.cmd('quit')
end

local FOLLOWS = { follows = true, last_line_in_view = true }

T['a window of the run pane'] = MiniTest.new_set()

T['a window of the run pane']['follows the output of the first process, shown by \\x'] = function()
  open_layout('run-follow-first')

  run_all({ 'seq 1 300; sleep 30' })
  local buffer = process_buffers()[1]

  eq(entry_shell.shows(child, buffer, LAST_OUTPUT), true)
  eq(standing_of(buffer), FOLLOWS)
end

T['a window of the run pane']['follows the output of a process added below, by \\x'] = function()
  open_layout('run-follow-added')

  run_all({ 'sleep 31', 'seq 1 300; sleep 30' })
  local buffer = process_buffers()[2]

  eq(entry_shell.shows(child, buffer, LAST_OUTPUT), true)
  eq(standing_of(buffer), FOLLOWS)
end

T['a window of the run pane']['follows the output of the first process when \\x shows the stack again'] = function()
  open_layout('run-follow-again')
  run_all({ PRINTS_THEN_WAITS })
  local buffer = process_buffers()[1]
  entry.press(child, '\\pa')

  release_and_wait_for_last_output(buffer)
  entry.press(child, '\\x')

  eq(standing_of(buffer), FOLLOWS)
end

T['a window of the run pane']['follows the output of a process below when \\x shows the stack again'] = function()
  open_layout('run-follow-again-below')
  run_all({ 'sleep 31', PRINTS_THEN_WAITS })
  local buffer = process_buffers()[2]
  entry.press(child, '\\pa')

  release_and_wait_for_last_output(buffer)
  entry.press(child, '\\x')

  eq(standing_of(buffer), FOLLOWS)
end

T['a window of the run pane']['follows the output of a process whose window :q closed, when \\x brings it back'] = function()
  open_layout('run-follow-quit')
  run_all({ 'sleep 31', PRINTS_THEN_WAITS })
  local buffer = process_buffers()[2]
  quit_window_of(buffer)

  release_and_wait_for_last_output(buffer)
  child.lua('vim.api.nvim_set_current_win(vim.fn.win_getid(1))')
  entry.press(child, '\\x')

  eq(standing_of(buffer), FOLLOWS)
end

T['a window of the run pane']['follows the output of a shell added below, by \\X'] = function()
  open_layout('run-follow-shell')
  run_all({ 'sleep 31' })

  entry.press(child, '\\X')
  local buffer = process_buffers()[2]
  entry_shell.type_into(child, buffer, 'seq 1 300')

  eq(entry_shell.shows(child, buffer, LAST_OUTPUT), true)
  eq(standing_of(buffer), FOLLOWS)
end

T['a window of the run pane']['keeps the cursor of a window that stays open where the user put it'] = function()
  open_layout('run-follow-scrolled')
  run_all({ 'seq 1 300; sleep 30', 'sleep 31' })
  local buffer = process_buffers()[1]
  eq(entry_shell.shows(child, buffer, LAST_OUTPUT), true)
  child.lua('vim.api.nvim_set_current_win(vim.fn.win_findbuf((...))[1])', { buffer })
  child.cmd('stopinsert')
  child.cmd('normal! gg')
  child.lua('vim.api.nvim_set_current_win(vim.fn.win_getid(1))')

  entry.press(child, '\\x')

  eq(cursor_line_of(buffer), 1)
end

return T
