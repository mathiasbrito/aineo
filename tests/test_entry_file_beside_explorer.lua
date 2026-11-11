local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local find_pickers = dofile('tests/helpers/find_pickers.lua')
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

--- The files of the repository the cases open files from.
local FILES = {
  ['README.md'] = { 'readme' },
  ['src/main.lua'] = { 'main' },
}

--- Makes the repository `file-beside-<name>` of `FILES`, starts the child in
--- it with the fake `claude`, a fake file picker that opens `README.md`, and
--- `settings` as `vim.g.aineo`, and opens the layout once Claude Code is
--- ready; returns the path of `README.md`.
---
---@param name string
---@param settings? table
---@return string readme
local function open_in_repository(name, settings)
  local top = git_repo.create('file-beside-' .. name, FILES)
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { git_repo.ENVIRONMENT })
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake('file-beside-' .. name, 'ready'), settings)
  local readme = vim.fs.joinpath(top, 'README.md')
  find_pickers.install(child, { 'snacks' }, readme)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  return readme
end

--- Opens `readme` in the child's current window with `:edit`.
---
---@param readme string
local function edit(readme)
  child.cmd('edit ' .. vim.fn.fnameescape(readme))
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

--- What the windows show with the file column beside the explorer column on
--- the left, Claude Code on the left.
local function beside_left(readme)
  return { 'aineo://explorer', readme, 'terminal', 'aineo://report', 'aineo://input' }
end

--- The same, the explorer column on the right.
local function beside_right(readme)
  return { 'terminal', 'aineo://report', 'aineo://input', readme, 'aineo://explorer' }
end

--- With the file column between Claude Code and the panes, the explorer
--- column on the left.
local function centre_left(readme)
  return { 'aineo://explorer', 'terminal', readme, 'aineo://report', 'aineo://input' }
end

--- The same, the explorer column on the right.
local function centre_right(readme)
  return { 'terminal', readme, 'aineo://report', 'aineo://input', 'aineo://explorer' }
end

--- With no explorer column.
local function no_column(readme)
  return { 'terminal', readme, 'aineo://report', 'aineo://input' }
end

T['a file opened from Input'] = MiniTest.new_set()

T['a file opened from Input']['lies beside the explorer column on the left by default'] = function()
  local readme = open_in_repository('left', { layout = { explorer_column = 'left' } })

  edit(readme)

  eq(wait_for_windows(beside_left(readme)), beside_left(readme))
end

T['a file opened from Input']['lies beside the explorer column on the right by default'] = function()
  local readme = open_in_repository('right', { layout = { explorer_column = 'right' } })

  edit(readme)

  eq(wait_for_windows(beside_right(readme)), beside_right(readme))
end

T['a file opened from Input']['lies between Claude Code and the panes with the option off'] = function()
  local readme = open_in_repository(
    'off',
    { layout = { explorer_column = 'left', file_beside_explorer = false } }
  )

  edit(readme)

  eq(wait_for_windows(centre_left(readme)), centre_left(readme))
end

T['a file opened from Input']['lies between Claude Code and the panes without an explorer column'] = function()
  local readme = open_in_repository('none')

  edit(readme)

  eq(wait_for_windows(no_column(readme)), no_column(readme))
end

T['a file found with \\f'] = MiniTest.new_set()

T['a file found with \\f']['opens beside the explorer column'] = function()
  local readme = open_in_repository('find', { layout = { explorer_column = 'left' } })

  entry.press(child, '\\f')

  eq(wait_for_windows(beside_left(readme)), beside_left(readme))
end

T['the explorer column key'] = MiniTest.new_set()

T['the explorer column key']['moves the open file column beside the column and back'] = function()
  local readme = open_in_repository('key')
  edit(readme)

  entry.press(child, '\\E')
  local turned_on = wait_for_windows(beside_left(readme))
  entry.press(child, '\\E')

  eq(turned_on, beside_left(readme))
  eq(wait_for_windows(no_column(readme)), no_column(readme))
end

T['the explorer column key']['keeps the current window'] = function()
  local readme = open_in_repository('key-current')
  edit(readme)
  local before = entry.current_window(child)

  entry.press(child, '\\E')
  wait_for_windows(beside_left(readme))

  eq(entry.current_window(child), before)
end

T['setup()'] = MiniTest.new_set()

--- Calls `setup()` in the child with `layout` as the layout settings.
---
---@param layout_settings table
local function setup_layout(layout_settings)
  child.lua([[require('aineo').setup({ layout = ... })]], { layout_settings })
end

T['setup()']['moves the file column to the centre when it turns the option off, and back when it turns it on'] = function()
  local readme = open_in_repository('setup', { layout = { explorer_column = 'right' } })
  edit(readme)
  wait_for_windows(beside_right(readme))

  setup_layout({ explorer_column = 'right', file_beside_explorer = false })
  local centred = wait_for_windows(centre_right(readme))
  setup_layout({ explorer_column = 'right', file_beside_explorer = true })

  eq(centred, centre_right(readme))
  eq(wait_for_windows(beside_right(readme)), beside_right(readme))
end

T['restoring the layout'] = MiniTest.new_set()

T['restoring the layout']['keeps the file column beside the explorer column'] = function()
  local readme = open_in_repository('restore', { layout = { explorer_column = 'left' } })
  edit(readme)
  wait_for_windows(beside_left(readme))
  child.lua('vim.api.nvim_win_close(vim.fn.win_findbuf(vim.fn.bufnr("aineo://report"))[1], false)')

  entry.press(child, '\\o')

  eq(wait_for_windows(beside_left(readme)), beside_left(readme))
end

return T
