local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local entry_editor = dofile('tests/helpers/entry_editor.lua')

local eq = MiniTest.expect.equality

--- The expression, run in the editor, that counts its terminal buffers: one
--- once Claude's session has started, none before.
local TERMINAL_COUNT = [[#vim.tbl_filter(function(buffer)
  return vim.bo[buffer].buftype == 'terminal'
end, vim.api.nvim_list_bufs())]]

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_case = child.stop } })

--- The start arguments that set `vim.g.aineo` to `settings` before startup.
---
---@param settings table
---@return string[]
local function settings_arguments(settings)
  return { '--cmd', 'lua vim.g.aineo = ' .. vim.inspect(settings, { newline = '', indent = '' }) }
end

--- Starts an editor in a terminal of `child` as a user starts `nvim`, with
--- aineo set to run `fake` as Claude, and `start`'s arguments, variables,
--- piped input and settings on top; returns it once it has settled
--- (`entry_editor.start()`).
---
---@param fake { environment: table<string, string> }
---@param start? { args?: string[], environment?: table<string, string>, stdin?: string, settings?: table }
---@return aineo.test.Editor
local function start_editor(fake, start)
  start = start or {}
  local settings = vim.tbl_deep_extend(
    'force',
    { claude = { cmd = claude_session.fake_command() } },
    start.settings or {}
  )
  return entry_editor.start(child, children.restart, {
    args = vim.list_extend(settings_arguments(settings), start.args or {}),
    environment = vim.tbl_extend('force', fake.environment, start.environment or {}),
    stdin = start.stdin,
  })
end

T['a bare interactive start'] = MiniTest.new_set()

T['a bare interactive start']['opens the layout around a new Claude'] = function()
  local fake = claude_session.fake('entry-autostart', 'ready')

  local editor = start_editor(fake)

  eq(entry_editor.get(editor, entry.WINDOWS), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(#claude_session.wait_for_starts(fake, 1), 1)
end

--- Starts that differ from a bare interactive one in exactly one way, each
--- named for it.
local NOT_BARE_STARTS = {
  { 'headless', { args = { '--headless' } } },
  { 'file', { args = { vim.fs.joinpath(vim.uv.cwd(), '.tests', 'fixtures', 'entry-file.txt') } } },
  { 'piped-stdin', { stdin = 'piped text' } },
  { 'in-aineos-claude', { environment = { AINEO_ENTRY_AINEO_CHILD = '1' } } },
  { 'autostart-off', { settings = { autostart = false } } },
  { 'command', { args = { '-c', 'let g:entry_command = 1' } } },
  { 'plus-command', { args = { '+let g:entry_command = 1' } } },
  {
    'session',
    { args = { '-S', vim.fs.joinpath(vim.uv.cwd(), 'tests', 'fixtures', 'entry', 'session.vim') } },
  },
}

T['a start that is not bare and interactive'] = MiniTest.new_set({ parametrize = NOT_BARE_STARTS })

T['a start that is not bare and interactive']['starts no Claude'] = function(name, start)
  local fake = claude_session.fake('entry-no-autostart-' .. name, 'ready')

  local editor = start_editor(fake, start)

  eq(entry_editor.get(editor, TERMINAL_COUNT), 0)
end

--- The code, run in the editor with a filetype, that counts the windows
--- showing a buffer of that filetype, in every tab, floating ones included.
local WINDOWS_OF_FILETYPE = [[
  local filetype = ...
  return #vim.tbl_filter(function(window)
    return vim.bo[vim.api.nvim_win_get_buf(window)].filetype == filetype
  end, vim.api.nvim_list_wins())
]]

--- The directory that holds the stand-in dashboard plugin.
local DASHBOARD_PLUGIN = vim.fs.joinpath(vim.uv.cwd(), 'tests', 'fixtures', 'entry', 'dashboard')

--- The start arguments that load the stand-in dashboard `dashboard` after
--- aineo (`tests/fixtures/entry/dashboard/plugin/entry_dashboard.lua`).
---
---@param dashboard { filetype: string, moment: string, autocommands: boolean, buffer: string }
---@return string[]
local function dashboard_arguments(dashboard)
  return {
    '--cmd',
    'lua vim.g.entry_dashboard = ' .. vim.inspect(dashboard, { newline = '', indent = '' }),
    '--cmd',
    'set runtimepath+=' .. DASHBOARD_PLUGIN,
  }
end

--- Stand-in dashboards, each named for the one it is modelled on and when it
--- shows; together they show at `VimEnter`, at `UIEnter` and from a callback
--- scheduled at `VimEnter`, each with and without autocommands.
local DASHBOARDS = {
  {
    'snacks-at-UIEnter-without-autocommands',
    { filetype = 'snacks_dashboard', moment = 'UIEnter', autocommands = false, buffer = 'first' },
  },
  {
    'alpha-at-VimEnter',
    { filetype = 'alpha', moment = 'VimEnter', autocommands = true, buffer = 'first' },
  },
  {
    'alpha-at-VimEnter-without-autocommands',
    { filetype = 'alpha', moment = 'VimEnter', autocommands = false, buffer = 'first' },
  },
  {
    'dashboard-nvim-at-UIEnter',
    { filetype = 'dashboard', moment = 'UIEnter', autocommands = true, buffer = 'new' },
  },
  {
    'dashboard-nvim-scheduled',
    { filetype = 'dashboard', moment = 'scheduled', autocommands = true, buffer = 'new' },
  },
  {
    'snacks-scheduled-without-autocommands',
    { filetype = 'snacks_dashboard', moment = 'scheduled', autocommands = false, buffer = 'first' },
  },
}

T['a startup dashboard'] = MiniTest.new_set({ parametrize = DASHBOARDS })

T['a startup dashboard']['gives way to the layout around a new Claude'] = function(name, dashboard)
  local fake = claude_session.fake('entry-dashboard-' .. name, 'ready')

  local editor = start_editor(fake, { args = dashboard_arguments(dashboard) })

  eq(entry_editor.get(editor, entry.WINDOWS), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(entry_editor.request(editor, WINDOWS_OF_FILETYPE, { dashboard.filetype }), 0)
end

--- The start arguments that set mini.starter up, from the pinned mini.nvim,
--- before aineo, so that it opens its dashboard at `VimEnter`.
local MINI_STARTER = {
  '--cmd',
  'set runtimepath^=' .. vim.fs.joinpath(vim.uv.cwd(), 'deps', 'mini.nvim'),
  '--cmd',
  "lua require('mini.starter').setup()",
}

T['mini.starter'] = MiniTest.new_set()

T['mini.starter']['gives way to the layout around a new Claude'] = function()
  local fake = claude_session.fake('entry-mini-starter', 'ready')

  local editor = start_editor(fake, { args = MINI_STARTER })

  eq(entry_editor.get(editor, entry.WINDOWS), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(entry_editor.request(editor, WINDOWS_OF_FILETYPE, { 'ministarter' }), 0)
end

T['mini.starter']['stays on screen when autostart is off'] = function()
  local fake = claude_session.fake('entry-mini-starter-autostart-off', 'ready')

  local editor = start_editor(fake, { args = MINI_STARTER, settings = { autostart = false } })

  eq(entry_editor.get(editor, 'vim.bo.filetype'), 'ministarter')
  eq(entry_editor.get(editor, TERMINAL_COUNT), 0)
end

T['sourced after a bare interactive start'] = MiniTest.new_set()

T['sourced after a bare interactive start']['maps the prefix and starts no Claude'] = function()
  local fake = claude_session.fake('entry-late', 'ready')
  local editor = start_editor(fake, { args = { '--cmd', 'let g:loaded_aineo = 1' } })

  entry_editor.request(editor, "vim.g.loaded_aineo = nil vim.cmd.runtime('plugin/aineo.lua')")
  entry_editor.settle(editor)

  eq(entry_editor.get(editor, TERMINAL_COUNT), 0)
  eq(entry_editor.get(editor, "vim.fn.maparg('\\\\o', 'n')"), '<Plug>(aineo-open)')
end

return T
