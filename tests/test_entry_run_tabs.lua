local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local entry_shell = dofile('tests/helpers/entry_shell.lua')
local fixture = dofile('tests/helpers/fixture.lua')
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

--- Stops the child, once the fake Claude Codes it runs and the processes of
--- the run panes have ended by a hangup (`END_TERMINALS`).
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

--- What the layout's windows show under the run pane with `count` processes,
--- as `tabs.windows_of_tab()` lists them.
---
---@param count integer
---@return string[]
local function run_pane(count)
  return vim.fn['repeat']({ 'terminal' }, count + 1)
end

--- Opens two tabs of aineo in the child, each around a fake Claude Code, and
--- returns the fakes: the child is in the second tab.
---
---@param name string the case's own name for its files
---@return table first
---@return table second
local function open_two_tabs(name)
  local _, first = tabs.open_first_tab(child, name)
  local second = tabs.fake(name .. '-second')
  tabs.use_next_fake(child, second)
  child.cmd('Aineo tab new')
  claude_session.wait_for_start(second)
  return first, second
end

--- Runs `command` in the child's current tab by `\x`, answering the prompt.
---
---@param command string
local function run(command)
  child.lua('table.insert(_G.run_answers, ...)', { command })
  entry.press(child, '\\x')
end

--- Makes the child answer the question of a close or a quit with `answer`
--- (1 confirms, 2 cancels), counting the questions in `_G.run_questions`.
---
---@param answer integer
local function answer_questions(answer)
  child.lua(
    [[
      local answer = ...
      _G.run_questions = _G.run_questions or {}
      vim.fn.confirm = function(message, choices, default)
        table.insert(_G.run_questions, { message, choices, default })
        return answer
      end
    ]],
    { answer }
  )
end

--- The questions the child has asked since `answer_questions()`.
---
---@return table[]
local function questions()
  return child.lua_get('_G.run_questions or {}')
end

--- What the winbars of the windows right of the first column of the child's
--- tab page number `number` draw, top to bottom: the processes the tab's run
--- pane shows.
---
---@param number integer
---@return string[]
local function winbars_of_tab(number)
  return child.lua_get(
    [[(function(number)
      local rows = {}
      for _, window in ipairs(vim.api.nvim_tabpage_list_wins(vim.api.nvim_list_tabpages()[number])) do
        local position = vim.api.nvim_win_get_position(window)
        if position[2] > 0 then
          table.insert(rows, {
            position[1],
            vim.api.nvim_eval_statusline(
              vim.wo[window].winbar,
              { winid = window, use_winbar = true }
            ).str,
          })
        end
      end
      table.sort(rows, function(a, b)
        return a[1] < b[1]
      end)
      return vim.tbl_map(function(row)
        return row[2]
      end, rows)
    end)(...)]],
    { number }
  )
end

T['each tab'] = MiniTest.new_set()

T['each tab']['has a stack of its own, and shows its own processes alone'] = function()
  open_two_tabs('run-tabs-own')
  run('sleep 302')
  child.cmd('tabfirst')
  run('sleep 301')

  eq(winbars_of_tab(1), { 'sleep 301 — running' })
  eq(winbars_of_tab(2), { 'sleep 302 — running' })
  eq(tabs.windows_of_tab(child, 1), run_pane(1))
  eq(tabs.windows_of_tab(child, 2), run_pane(1))
end

T['each tab']['keeps its processes running while the other tab shows its panes'] = function()
  open_two_tabs('run-tabs-keep')
  run('sleep 302')
  local pid = entry_shell.pid_of(child, child.lua_get('vim.api.nvim_get_current_buf()'))
  child.cmd('tabfirst')

  entry.press(child, '\\pa')

  eq(entry_shell.is_running(pid), true)
  eq(tabs.windows_of_tab(child, 2), run_pane(1))
end

T['each tab']['leaves no handler of its run pane behind once its tab page closes'] = function()
  open_two_tabs('run-tabs-handlers')
  local group_exists = [[(pcall(vim.api.nvim_get_autocmds, { group = 'aineo.entry.run.2' }))]]
  local before = child.lua_get(group_exists)

  child.cmd('tabclose')
  local closed = vim.wait(tabs.PATIENCE_MS, function()
    return not child.lua_get(group_exists)
  end, 20)

  eq({ before, closed }, { true, true })
end

T['closing a tab with \\Q'] = MiniTest.new_set()

T['closing a tab with \\Q']['asks once, listing the tab’s commands, and keeps the tab and its processes on Cancel'] = function()
  open_two_tabs('run-tabs-close-cancel')
  run('sleep 302')
  local pid = entry_shell.pid_of(child, child.lua_get('vim.api.nvim_get_current_buf()'))
  answer_questions(2)

  entry.press(child, '\\Q')

  eq(questions(), {
    { 'aineo: 1 process will be stopped (sleep 302) — close the tab?', '&Close\n&Cancel', 2 },
  })
  eq(tabs.tab_count(child), 2)
  eq(entry_shell.is_running(pid), true)
end

T['closing a tab with \\Q']['closes the tab and stops its processes when the user confirms'] = function()
  open_two_tabs('run-tabs-close-confirm')
  run('sleep 302')
  local pid = entry_shell.pid_of(child, child.lua_get('vim.api.nvim_get_current_buf()'))
  answer_questions(1)

  entry.press(child, '\\Q')

  eq(tabs.tab_count(child), 1)
  eq(entry_shell.has_ended(pid), true)
  eq(#questions(), 1)
end

--- The command that starts a child that ignores the hangup of a closed
--- terminal and writes its process id to `child.pid` in `folder`.
---
---@param folder string
---@return string
local function service_with_child(folder)
  return 'nohup sleep 300 >/dev/null 2>&1 & echo $! > ' .. folder .. '/child.pid; wait'
end

--- The process id of the child the service of `service_with_child()` wrote
--- to `folder`, once it has.
---
---@param folder string
---@return integer
local function child_pid_in(folder)
  local pid
  vim.wait(entry_shell.PATIENCE_MS, function()
    local lines = vim.fn.filereadable(folder .. '/child.pid') == 1
        and vim.fn.readfile(folder .. '/child.pid')
      or {}
    pid = tonumber(lines[1])
    return pid ~= nil
  end, 20)
  return pid
end

T['closing a tab with \\Q']['stops the processes of the closed tab with their children, whichever tab it was'] =
  MiniTest.new_set({ parametrize = { { 'second' }, { 'first' } } })

T['closing a tab with \\Q']['stops the processes of the closed tab with their children, whichever tab it was']['tab'] = function(
  which
)
  open_two_tabs('run-tabs-close-orphans-' .. which)
  local folder = fixture.directory('run-tabs/close-orphans-' .. which)
  if which == 'first' then
    child.cmd('tabfirst')
  end
  run(service_with_child(folder))
  local pid = entry_shell.pid_of(child, child.lua_get('vim.api.nvim_get_current_buf()'))
  local child_pid = child_pid_in(folder)
  answer_questions(1)

  entry.press(child, '\\Q')
  local ended = { entry_shell.has_ended(pid), entry_shell.has_ended(child_pid) }
  pcall(vim.uv.kill, child_pid, 'sigkill')

  eq(ended, { true, true })
  eq(tabs.tab_count(child), 1)
end

T['closing a tab with \\Q']['asks nothing for a tab that runs no process'] = function()
  open_two_tabs('run-tabs-close-none')
  answer_questions(2)

  entry.press(child, '\\Q')

  eq(tabs.tab_count(child), 1)
  eq(questions(), {})
end

T['closing a tab with \\Q']['does not count the processes of the other tabs'] = function()
  open_two_tabs('run-tabs-close-others')
  run('sleep 302')
  child.cmd('tabfirst')
  answer_questions(2)

  entry.press(child, '\\Q')

  eq(tabs.tab_count(child), 1)
  eq(questions(), {})
end

return T
