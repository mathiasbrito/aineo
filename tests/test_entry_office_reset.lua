local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')

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

--- Stops the child, once the fake Claude Code it runs, if any, has ended by a
--- hangup (`END_TERMINALS`).
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

--- What `:Aineo office reset` tells the user when no aineo tab exists.
local NO_TAB = 'aineo: there is no aineo tab to show the office in'

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, and waits until Claude Code is ready.
---
---@param name string the case's own name for its files, starting `reset-`
local function open_layout(name)
  entry.use_fake(child, claude_session.fake(name, 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

--- The text of the office's window, its lines joined; '' while it shows none.
---
---@return string
local function office_text()
  local window = office_cells.window(child)
  if window == vim.NIL then
    return ''
  end
  local lines = child.lua_get(
    [[vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(...), 0, -1, false)]],
    { window }
  )
  return table.concat(lines, '\n')
end

T[':Aineo office reset'] = MiniTest.new_set()

T[':Aineo office reset']['shows the office of the aineo tab with its agent walking in'] = function()
  open_layout('reset-shows')

  entry.command(child, 'Aineo office reset')

  eq(
    vim.wait(5000, function()
      return office_text():find('arriving', 1, true) ~= nil
    end, 20),
    true
  )
end

T[':Aineo office reset']['tells the user when there is no aineo tab, and shows nothing'] = function()
  entry.command(child, 'Aineo office reset')

  eq(entry.messages(child), { { message = NO_TAB, level = vim.log.levels.WARN } })
  eq(office_cells.window(child), vim.NIL)
end

T[':Aineo office reset']['refuses a word after it, and says what it takes'] = function()
  entry.command(child, 'Aineo office reset alt')

  eq(entry.messages(child), { { message = entry.OFFICE_USAGE, level = vim.log.levels.ERROR } })
end

T[':Aineo office reset']['is offered after office, with nothing after it'] = function()
  eq(vim.tbl_contains(child.fn.getcompletion('Aineo office ', 'cmdline'), 'reset'), true)
  eq(child.fn.getcompletion('Aineo office reset ', 'cmdline'), {})
end

return T
