--- Drives a tab of aineo in a child Neovim for the suites of the walkthrough
--- pane: a git project of its own, the layout opened around the fake
--- `claude`, and the calls the walkthrough tools make of the editor — a plan,
--- a step — as the relay of the Claude Code with a start token makes them.

local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local explained = dofile('tests/helpers/explain_child.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local M = {}

--- The lines of the files every case walks through.
M.CODE = {
  'local a = 1',
  'local b = 2',
  'local c = 3',
  'local d = 4',
  'local e = 5',
  'return a',
}

--- Takes on the git isolation of the git home's suites in this Neovim, which
--- every child it starts inherits, and makes the project the cases work in,
--- with the files `src/code.lua` and `src/other.lua`.
---
---@param name string
---@return string folder
function M.make_project(name)
  for variable, value in pairs(git_repo.ENVIRONMENT) do
    vim.env[variable] = value
  end
  return git_repo.create(name, { ['src/code.lua'] = M.CODE, ['src/other.lua'] = M.CODE })
end

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

--- Stops `child`, once the fake Claude Code it runs, if any, has ended.
---
---@param child table
function M.stop(child)
  if child.is_running() then
    child.lua(END_TERMINALS)
  end
  child.stop()
end

--- Starts `child` afresh in `project`, where Claude Code starts, 200 columns
--- wide.
---
---@param child table
---@param project string
function M.restart(child, project)
  M.stop(child)
  entry.restart(child)
  child.o.columns = 200
  child.o.lines = 50
  child.cmd('cd ' .. vim.fn.fnameescape(project))
end

--- Opens aineo's layout in `child` with the fake `claude` ready for input
--- under `name`, waits until the tab has written its entry in the list of
--- running editors, which makes the editor's handlers, and returns the
--- start token its hooks carry.
---
---@param child table
---@param name string the case's own name for its files
---@param settings? table more of `vim.g.aineo`
---@param fake_environment? table<string, string> more of the fake `claude`'s environment
---@return string token
function M.open_layout(child, name, settings, fake_environment)
  local fake = claude_session.fake(name, 'ready', fake_environment)
  entry.use_fake(child, fake, settings)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  claude_session.wait_for_status(child, 'ready')
  vim.wait(explained.PATIENCE_MS, function()
    return child.lua_get([[(pcall(vim.api.nvim_get_autocmds, { group = 'aineo.editors' }))]])
  end, 20)
  return claude_session.start_token(fake, 1)
end

--- A call of the walkthrough plan tool for the files `src/code.lua` and
--- `src/other.lua` of `project`, valid but for the fields `overrides`
--- replaces.
---
---@param project string
---@param overrides? table
---@return table
function M.plan_for(project, overrides)
  return vim.tbl_extend('force', {
    title = 'The values',
    summary = 'How the values are defined and returned.',
    covers = { 'Defining the values', 'Returning one' },
    steps = {
      { title = 'The definitions', file = project .. '/src/code.lua', introduces = { 'value' } },
      { title = 'The result', file = project .. '/src/other.lua', introduces = { 'return' } },
    },
  }, overrides or {})
end

--- A call of the walkthrough tool for `path`, a file of `project`, with the
--- number `number`, valid but for the fields `overrides` replaces.
---
---@param project string
---@param path string
---@param number integer
---@param overrides? table
---@return table
function M.step_for(project, path, number, overrides)
  return vim.tbl_extend('force', {
    file = project .. '/' .. path,
    title = 'The values',
    step = number,
    total = 2,
    ranges = { { start = 2, ['end'] = 3, text = 'Two values.' } },
  }, overrides or {})
end

--- Offers the child's MCP home a call, with `receiver` the name of its
--- function that takes it (`receive_walkthrough_plan`,
--- `receive_walkthrough_step`), as the relay of the Claude Code with the
--- start token `token` does, and returns what the editor answers, or, when
--- the editor raises an error instead, a table naming it, so that a case
--- compares it with what it expects and fails by its assertion.
---
---@param child table
---@param receiver string
---@param token string
---@param call table
---@return { text: string, is_error: boolean }|false|{ raised: string }
function M.offer(child, receiver, token, call)
  local answered, answer =
    pcall(child.lua_get, [[require('aineo.mcp')[...](select(2, ...))]], { receiver, call, token })
  return answered and answer or { raised = tostring(answer) }
end

--- The number of Claude's terminal buffer in `child`.
---
---@param child table
---@return integer
function M.terminal_buffer(child)
  return child.lua_get([[vim.iter(vim.api.nvim_list_bufs()):find(function(number)
    return vim.bo[number].buftype == 'terminal'
  end)]])
end

--- Has `child`'s Claude Code count as busy, or not.
---
---@param child table
---@param busy boolean
function M.be_busy(child, busy)
  child.lua('vim.b[...].aineo_session_busy = select(2, ...)', { M.terminal_buffer(child), busy })
end

return M
