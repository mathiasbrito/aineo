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
        _G.run_prompts = {}
        _G.run_answers = {}
        vim.ui.input = function(options, on_confirm)
          table.insert(_G.run_prompts, options)
          on_confirm(table.remove(_G.run_answers, 1))
        end
      ]])
    end,
    post_once = stop_the_child,
  },
})

--- What the layout's windows show under the agent pane, as `entry.windows()`
--- lists them.
local AGENT_PANE = { 'terminal', 'aineo://report', 'aineo://input' }

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, waits until Claude Code has launched and the
--- tab has written its entry in the list of running editors, which makes the
--- editor's handlers, and returns the start token its hooks carry.
---
---@param name string the case's own name for its files, starting `run-calls-`
---@return string token
local function open_layout(name)
  local fake = claude_session.fake(name, 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  vim.wait(entry_shell.PATIENCE_MS, function()
    return child.lua_get([[(pcall(vim.api.nvim_get_autocmds, { group = 'aineo.editors' }))]])
  end, 20)
  return claude_session.start_token(fake, 1)
end

--- Offers the child's MCP home a call of the run tool `tool`, as the relay
--- of the Claude Code with the start token `token` does, and returns what
--- the editor answers.
---
---@param token string?
---@param tool string
---@param arguments table
---@return { text: string, is_error: boolean }|false
local function call(token, tool, arguments)
  return child.lua_get(
    [[require('aineo.mcp').receive_run_call({ tool = (...), arguments = select(2, ...) }, select(3, ...))]],
    { tool, arguments, token or vim.NIL }
  )
end

--- The names of the processes of the child's first tab, the oldest first.
---
---@return string[]
local function process_names()
  return child.lua_get([[vim.tbl_map(function(entry)
    return entry.name
  end, require('aineo.run').entries())]])
end

T['a run call'] = MiniTest.new_set()

T['a run call']['starts the process in the first tab’s stack, leaves the run pane unshown, and tells the user once'] = function()
  local token = open_layout('run-calls-start')

  local answer = call(token, 'run', { command = 'sleep 30', name = 'svc' })

  eq(answer.is_error, false)
  eq(process_names(), { 'svc' })
  eq(entry.windows(child), AGENT_PANE)
  eq(entry.messages(child), {
    { message = 'aineo: started svc in the run pane', level = vim.log.levels.INFO },
  })
end

T['a run call']['guards the quit of the editor from the first process on'] = function()
  local token = open_layout('run-calls-guard')

  call(token, 'run', { command = 'sleep 30' })

  eq(
    child.lua_get([[#vim.api.nvim_get_autocmds({ group = 'aineo.entry.quit', event = 'ExitPre' })]]),
    1
  )
end

T['a run call']['adds the process to the stack at the bottom while the run pane is shown, the cursor staying where it is'] = function()
  local token = open_layout('run-calls-shown')
  child.lua([[table.insert(_G.run_answers, 'sleep 31')]])
  entry.press(child, '\\x')
  local cursor_buffer = child.lua_get('vim.api.nvim_get_current_buf()')

  call(token, 'run', { command = 'sleep 32', name = 'svc' })

  eq(entry.windows(child), { 'terminal', 'terminal', 'terminal' })
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), cursor_buffer)
  eq(process_names(), { 'sleep 31', 'svc' })
end

T['a run call']['of a start token no tab’s Claude Code has is not taken, and starts nothing'] = function()
  open_layout('run-calls-unknown')

  local answer = call('no-such-token', 'run', { command = 'sleep 30' })

  eq(answer, false)
  eq(process_names(), {})
end

T['a run call']['reads and stops the process it started'] = function()
  local token = open_layout('run-calls-read-stop')
  call(token, 'run', { command = 'echo hello; sleep 30', name = 'svc' })
  local buffer = child.lua_get([[require('aineo.run').buffers()[1] ]])
  entry_shell.shows(child, buffer, 'hello')

  local read = call(token, 'run_output', { name = 'svc', pattern = 'hello' })
  local stopped = call(token, 'run_stop', { name = 'svc' })

  eq(read, { text = 'svc: running; 1 line in total\n1: hello', is_error = false })
  eq(stopped, { text = 'Stopped "svc".', is_error = false })
  eq(process_names(), {})
end

return T
