local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

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

--- Stops the child, once the fake Claude Code it runs, if any, has ended by
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
    end,
    post_once = stop_the_child,
  },
})

--- Makes the repository `layout-default-<name>`, starts the child in it with
--- the fake `claude` and every layout setting at aineo's default, opens the
--- layout once Claude Code is ready, and returns the path of `README.md`.
---
---@param name string
---@param settings? table more of `vim.g.aineo`
---@return string readme
local function open_with_default_layout(name, settings)
  local top = git_repo.create('layout-default-' .. name, { ['README.md'] = { 'readme' } })
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { git_repo.ENVIRONMENT })
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake_with_default_layout(
    child,
    claude_session.fake('layout-default-' .. name, 'ready'),
    settings
  )
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  return vim.fs.joinpath(top, 'README.md')
end

--- Waits, at most ten seconds, until the child's windows show `names` from
--- the left of the screen, and returns what they show then.
---
---@param names string[]
---@return string[]
local function wait_for_windows(names)
  vim.wait(10000, function()
    return vim.deep_equal(entry.windows(child), names)
  end, 20)
  return entry.windows(child)
end

T['the default layout'] = MiniTest.new_set()

T['the default layout']['reads Claude Code, the panes, the file column and the explorer from the left'] = function()
  local readme = open_with_default_layout('order')

  child.cmd('edit ' .. vim.fn.fnameescape(readme))

  local expected = { 'terminal', 'aineo://report', 'aineo://input', readme, 'aineo://explorer' }
  eq(wait_for_windows(expected), expected)
end

T['the default layout']['has no explorer column with layout.explorer_column set to false'] = function()
  local readme = open_with_default_layout('false', { layout = { explorer_column = false } })

  child.cmd('edit ' .. vim.fn.fnameescape(readme))

  local expected = { 'terminal', readme, 'aineo://report', 'aineo://input' }
  eq(wait_for_windows(expected), expected)
end

return T
