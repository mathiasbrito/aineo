local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
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
    end,
    post_once = stop_the_child,
  },
})

--- Makes the repository `layout-mirror-<name>`, starts the child in it with
--- the fake `claude` and every layout setting at aineo's default but those
--- `settings` names, opens the layout once Claude Code is ready, and opens
--- `README.md` in the file column; returns its path.
---
---@param name string
---@param settings? table more of `vim.g.aineo`
---@return string readme
local function open_with_a_file(name, settings)
  local top = git_repo.create('layout-mirror-' .. name, { ['README.md'] = { 'readme' } })
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { git_repo.ENVIRONMENT })
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake_with_default_layout(
    child,
    claude_session.fake('layout-mirror-' .. name, 'ready'),
    settings
  )
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  local readme = vim.fs.joinpath(top, 'README.md')
  child.cmd('edit ' .. vim.fn.fnameescape(readme))
  return readme
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

--- What the windows show in the default layout, then mirrored.
local function default_layout(readme)
  return { 'terminal', 'aineo://report', 'aineo://input', readme, 'aineo://explorer' }
end

local function mirrored_layout(readme)
  return { 'aineo://explorer', readme, 'aineo://report', 'aineo://input', 'terminal' }
end

--- Each way to mirror the layout, as a set's `parametrize`: its name, and the
--- function that does it.
local WAYS = {
  {
    'running :Aineo layout mirror',
    function()
      entry.command(child, 'Aineo layout mirror')
    end,
  },
  {
    'pressing <Plug>(aineo-layout-mirror)',
    function()
      entry.press(child, '<Plug>(aineo-layout-mirror)')
    end,
  },
}

T['mirroring the layout'] = MiniTest.new_set({ parametrize = WAYS })

T['mirroring the layout']['flips the default layout end to end, and back, by'] = function(_, way)
  local readme = open_with_a_file('flip')
  wait_for_windows(default_layout(readme))

  way()
  local mirrored = wait_for_windows(mirrored_layout(readme))
  way()

  eq(mirrored, mirrored_layout(readme))
  eq(wait_for_windows(default_layout(readme)), default_layout(readme))
  eq(entry.messages(child), {})
end

T['mirroring the layout']['acts as a swap with no explorer column'] = function()
  local readme = open_with_a_file('no-column', { layout = { explorer_column = false } })
  local expected = { 'terminal', readme, 'aineo://report', 'aineo://input' }
  wait_for_windows(expected)

  entry.command(child, 'Aineo layout mirror')

  local swapped = { 'aineo://report', 'aineo://input', readme, 'terminal' }
  eq(wait_for_windows(swapped), swapped)
end

T['mirroring the layout']['keeps Claude Code running in the same terminal'] = function()
  local readme = open_with_a_file('job')
  wait_for_windows(default_layout(readme))
  local terminal = tabs.claude_terminal_of_tab(child, 1)
  local job = child.lua_get('vim.bo[...].channel', { terminal })

  entry.command(child, 'Aineo layout mirror')

  eq(wait_for_windows(mirrored_layout(readme)), mirrored_layout(readme))
  eq(child.lua_get('vim.bo[...].channel', { terminal }), job)
end

T['mirroring the layout']['gives \\E the side it set'] = function()
  local readme = open_with_a_file('key')
  wait_for_windows(default_layout(readme))

  entry.command(child, 'Aineo layout mirror')
  wait_for_windows(mirrored_layout(readme))
  entry.press(child, '\\E')
  wait_for_windows({ 'terminal', 'aineo://report', 'aineo://input' })
  entry.press(child, '\\E')

  eq(
    wait_for_windows({ 'aineo://explorer', readme, 'aineo://report', 'aineo://input', 'terminal' }),
    mirrored_layout(readme)
  )
end

T['mirroring the layout']['yields to a setup() that names another side for the explorer column'] = function()
  local readme = open_with_a_file('setup')
  wait_for_windows(default_layout(readme))
  entry.command(child, 'Aineo layout mirror')
  entry.command(child, 'Aineo layout mirror')
  wait_for_windows(default_layout(readme))

  child.lua([[require('aineo').setup({ layout = { explorer_column = 'left' } })]])
  local on_the_left = { 'aineo://explorer', readme, 'terminal', 'aineo://report', 'aineo://input' }
  wait_for_windows(on_the_left)
  entry.press(child, '\\E')
  wait_for_windows({ 'terminal', 'aineo://report', 'aineo://input', readme })
  entry.press(child, '\\E')

  eq(wait_for_windows(on_the_left), on_the_left)
end

T['a tab opened after mirroring'] = MiniTest.new_set()

T['a tab opened after mirroring']['opens on the mirrored layout'] = function()
  local readme = open_with_a_file('tab')
  wait_for_windows(default_layout(readme))
  entry.command(child, 'Aineo layout mirror')
  wait_for_windows(mirrored_layout(readme))

  entry.command(child, 'Aineo tab new')

  eq(
    vim.wait(10000, function()
      return vim.deep_equal(
        tabs.windows_of_tab(child, 2),
        { 'aineo://explorer', 'aineo://report', 'aineo://input', 'terminal' }
      )
    end, 20),
    true
  )
end

T[':Aineo layout'] = MiniTest.new_set()

T[':Aineo layout']['completes swap, left, right and mirror'] = function()
  eq(
    child.lua_get([[vim.fn.getcompletion('Aineo layout ', 'cmdline')]]),
    { 'swap', 'left', 'right', 'mirror' }
  )
end

return T
