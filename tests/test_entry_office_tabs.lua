local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local entry_tabs = dofile('tests/helpers/entry_tabs.lua')

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

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 4000

--- How long a wait for something that should not happen lasts, in milliseconds.
local QUIET_MS = 400

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, shows the office with `:Aineo office`, and puts
--- the cursor in the window `window_command` goes to: `wincmd b` is Input, in
--- the right column the office covers, `wincmd t` the left column's top.
---
---@param name string the case's own name for its files, starting `office-`
---@param window_command string
local function show_the_office_with_the_cursor_in(name, window_command)
  entry_tabs.use_own_state(child, name)
  entry.use_fake(child, claude_session.fake(name, 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  child.cmd(window_command)
  entry.command(child, 'Aineo office')
end

--- The number of floating windows the child has, over every tab page.
---
---@return integer
local function floats()
  return child.lua_get([[#vim.tbl_filter(function(window)
    return vim.api.nvim_win_get_config(window).relative ~= ''
  end, vim.api.nvim_list_wins())]])
end

--- Waits `QUIET_MS` for the floats to change from `count`, and says whether
--- they stayed.
---
---@param count integer
---@return boolean
local function floats_stay_at(count)
  return not vim.wait(QUIET_MS, function()
    return floats() ~= count
  end, 20)
end

--- The cases: which window the cursor is in as the office shows.
local CURSOR_PLACES = {
  { 'in the left column', 'wincmd t' },
  { 'in the right column the office covers', 'wincmd b' },
}

T['the office through a tab page switch'] = MiniTest.new_set({ parametrize = CURSOR_PLACES })

T['the office through a tab page switch']['stays when the user goes to a tab page of no layout with gt and comes back with gT'] = function(
  place,
  window_command
)
  show_the_office_with_the_cursor_in('office-tabs-plain-' .. place:gsub('%W', ''), window_command)
  child.cmd('tabnew')
  child.type_keys('gT')
  child.type_keys('gt')
  child.type_keys('gT')

  eq(floats(), 1)
  eq(floats_stay_at(1), true)
end

T['the office through a tab page switch']['stays when the user goes to another aineo tab, whose office shows too, with :tabnext and comes back with :tabprevious'] = function(
  place,
  window_command
)
  show_the_office_with_the_cursor_in('office-tabs-two-' .. place:gsub('%W', ''), window_command)
  child.cmd('Aineo tab new')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get([[#vim.api.nvim_list_tabpages()]]) == 2
  end, 20)
  entry.command(child, 'Aineo office')
  eq(floats(), 2)

  child.cmd('tabnext')
  child.cmd('tabnext')
  child.cmd('tabprevious')
  child.cmd('tabprevious')

  eq(floats(), 2)
  eq(floats_stay_at(2), true)
end

return T
