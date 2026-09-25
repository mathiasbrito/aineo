local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local health = dofile('tests/helpers/health.lua')

local eq = MiniTest.expect.equality

--- The stand-in for Claude Code the health check runs (`tests/helpers/health_claude`).
local HEALTH_CLAUDE = vim.fs.joinpath(vim.uv.cwd(), 'tests', 'helpers', 'health_claude')

--- An executable file whose interpreter does not exist, so no process can start from it.
local CLAUDE_WITHOUT_INTERPRETER =
  vim.fs.joinpath(vim.uv.cwd(), 'tests', 'fixtures', 'health', 'claude_without_interpreter')

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_case = child.stop } })

--- The start arguments that set `vim.g.aineo` to `settings` before startup.
---
---@param settings table
---@return string[]
local function settings_arguments(settings)
  return { '--cmd', 'lua vim.g.aineo = ' .. vim.inspect(settings, { newline = '', indent = '' }) }
end

--- Starts `child` afresh, headless, with `vim.g.aineo` set to `settings`.
---
---@param settings table
local function start_with(settings)
  children.restart(child, settings_arguments(settings))
end

T['the configuration'] = MiniTest.new_set()

T['the configuration']['is reported valid when every setting is'] = function()
  start_with({ autostart = false })

  local report = health.report(child)

  eq(health.section(report, 'Configuration'), { '- ✅ OK the configuration is valid' })
end

T['the configuration']['is reported wrong, naming the setting, when a value is'] = function()
  start_with({ autostart = false, layout = { report_height = 2 } })

  local report = health.report(child)

  eq(health.section(report, 'Configuration'), {
    '- ❌ ERROR layout.report_height: expected a number strictly between 0 and 1, got 2',
  })
end

T['the configuration']['warns of each unknown key, in vim.g.aineo and setup() alike'] = function()
  start_with({ autostart = false, promt = '\\', claude = { command = { 'claude' } } })
  child.lua([[require('aineo').setup({ auto_start = true })]])

  local report = health.report(child)

  eq(health.section(report, 'Configuration'), {
    '- ✅ OK the configuration is valid',
    "- ⚠️ WARNING unknown setting 'auto_start', which aineo ignores",
    "- ⚠️ WARNING unknown setting 'claude.command', which aineo ignores",
    "- ⚠️ WARNING unknown setting 'promt', which aineo ignores",
  })
end

T['Claude Code'] = MiniTest.new_set()

T['Claude Code']['names the version aineo was measured on'] = function()
  start_with({ autostart = false })

  local report = health.report(child)

  eq(
    vim.tbl_contains(
      health.section(report, 'Claude Code'),
      "- aineo's behaviour was measured on Claude Code 2.1.281"
    ),
    true
  )
end

T['Claude Code']['is an error when the first word of claude.cmd is not executable'] = function()
  start_with({ autostart = false, claude = { cmd = { 'aineo-no-such-claude', '--flag' } } })

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    "- ❌ ERROR claude.cmd: 'aineo-no-such-claude' is not executable",
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
  eq(health.advice(report, 'Claude Code'), {
    'Install Claude Code, or set claude.cmd to the command that runs it: :help |aineo-config-claude.cmd|',
  })
end

T['Claude Code']['runs the whole of claude.cmd with --version, and reports what it prints'] = function()
  local record = vim.fs.joinpath(fixture.directory('health-version'), 'arguments')
  start_with({ autostart = false, claude = { cmd = { HEALTH_CLAUDE, 'wrapped', 'words' } } })
  child.lua('vim.env.AINEO_HEALTH_CLAUDE_RECORD = ...', { record })

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ✅ OK claude.cmd --version: 9.9.9 (health stand-in)',
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
  eq(vim.fn.readfile(record), { 'wrapped', 'words', '--version' })
end

--- Starts `child` afresh with `claude.cmd` running the stand-in in `mode`.
---
---@param mode string one of `tests/helpers/health_claude`'s modes
local function start_with_stand_in(mode)
  start_with({ autostart = false, claude = { cmd = { HEALTH_CLAUDE } } })
  child.lua('vim.env.AINEO_HEALTH_CLAUDE_MODE = ...', { mode })
end

T['Claude Code']['warns when claude.cmd --version fails, with what it wrote on stderr'] = function()
  start_with_stand_in('failing')

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ⚠️ WARNING claude.cmd --version exited with 3',
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
  eq(health.advice(report, 'Claude Code'), { 'health stand-in: no version today' })
end

T['Claude Code']['gives no advice when claude.cmd --version fails without a word'] = function()
  start_with_stand_in('failing-silently')

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ⚠️ WARNING claude.cmd --version exited with 3',
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
  eq(health.advice(report, 'Claude Code'), {})
end

T['Claude Code']['warns when claude.cmd --version prints nothing'] = function()
  start_with_stand_in('silent')

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ⚠️ WARNING claude.cmd --version printed nothing',
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
end

T['Claude Code']['is not checked while the configuration is wrong'] = function()
  start_with({ autostart = false, claude = { cmd = 'claude' } })

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- claude.cmd is not checked while the configuration is wrong',
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
end

T['Claude Code']['warns when claude.cmd cannot be run, although it is executable'] = function()
  start_with({ autostart = false, claude = { cmd = { CLAUDE_WITHOUT_INTERPRETER } } })

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ⚠️ WARNING claude.cmd --version could not run: ENOENT: no such file or directory',
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
end

T['Claude Code']['warns when claude.cmd --version runs past 3 s, and its output stays open'] = function()
  start_with_stand_in('holding')

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ⚠️ WARNING claude.cmd --version did not finish within 3 s',
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
end

T['Claude Code']['warns when claude.cmd --version runs past 3 s'] = function()
  start_with_stand_in('hanging')

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ⚠️ WARNING claude.cmd --version did not finish within 3 s',
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
end

T['the server socket'] = MiniTest.new_set()

T['the server socket']['names the address the editor listens at'] = function()
  start_with({ autostart = false })
  local address = child.lua_get('vim.v.servername')

  local report = health.report(child)

  eq(health.section(report, 'Server socket'), {
    '- ✅ OK the editor listens at ' .. address,
  })
end

T['the server socket']['is an error when the editor listens nowhere'] = function()
  start_with({ autostart = false })
  child.lua('vim.fn.serverstop(vim.v.servername)')

  local report = health.report(child)

  eq(health.section(report, 'Server socket'), {
    '- ❌ ERROR the editor listens nowhere (v:servername is empty)',
  })
  eq(health.advice(report, 'Server socket'), {
    "Claude's reports cannot reach this editor; start one with :call serverstart()",
  })
end

T['the prefix mappings'] = MiniTest.new_set()

--- Starts `child` afresh with `vim.g.aineo` set to `settings` and
--- `maplocalleader` set to `local_leader`, both before startup.
---
---@param settings table
---@param local_leader string
local function start_with_local_leader(settings, local_leader)
  children.restart(
    child,
    vim.list_extend(
      settings_arguments(settings),
      { '--cmd', 'let g:maplocalleader = ' .. vim.fn.string(local_leader) }
    )
  )
end

T['the prefix mappings']['are reported in place when aineo mapped each key'] = function()
  start_with_local_leader({ autostart = false }, ',')

  local report = health.report(child)

  eq(health.section(report, 'Prefix mappings'), {
    '- ✅ OK \\s runs <Plug>(aineo-send)',
    '- ✅ OK \\o runs <Plug>(aineo-open)',
    '- ✅ OK \\r runs <Plug>(aineo-report)',
    '- ✅ OK \\i runs <Plug>(aineo-input)',
    '- ✅ OK \\c runs <Plug>(aineo-claude)',
  })
end

T['the prefix mappings']['warn of a key the user mapped, naming what it runs'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), {
      '--cmd',
      'let g:maplocalleader = ","',
      '--cmd',
      'nnoremap \\s :echo "mine"<CR>',
    })
  )

  local report = health.report(child)

  eq(health.section(report, 'Prefix mappings'), {
    '- ⚠️ WARNING \\s runs \':echo "mine"<CR>\', not <Plug>(aineo-send)',
    '- ✅ OK \\o runs <Plug>(aineo-open)',
    '- ✅ OK \\r runs <Plug>(aineo-report)',
    '- ✅ OK \\i runs <Plug>(aineo-input)',
    '- ✅ OK \\c runs <Plug>(aineo-claude)',
  })
  eq(health.advice(report, 'Prefix mappings'), {
    'aineo leaves a key you mapped alone; map <Plug>(aineo-send) to a key of your own: :help |aineo-mappings|',
  })
end

--- Starts `child` afresh, with the local leader `,`, after running `command`
--- before startup.
---
---@param command string
local function start_after_command(command)
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), {
      '--cmd',
      'let g:maplocalleader = ","',
      '--cmd',
      command,
    })
  )
end

T['the prefix mappings']['warn of a key the user mapped to a Lua function, naming its description'] = function()
  start_after_command([[lua vim.keymap.set('n', '\\o', function() end, { desc = 'my open' })]])

  local report = health.report(child)

  eq(
    health.section(report, 'Prefix mappings')[2],
    '- ⚠️ WARNING \\o runs a Lua function (my open), not <Plug>(aineo-open)'
  )
end

T['the prefix mappings']['warn of a key the user mapped to a Lua function without a description'] = function()
  start_after_command([[lua vim.keymap.set('n', '\\o', function() end)]])

  local report = health.report(child)

  eq(
    health.section(report, 'Prefix mappings')[2],
    '- ⚠️ WARNING \\o runs a Lua function, not <Plug>(aineo-open)'
  )
end

T['the prefix mappings']['warn of each key nobody mapped, as after setup() changes the prefix late'] = function()
  start_with_local_leader({ autostart = false }, ';')
  child.lua([[require('aineo').setup({ prefix = ',' })]])

  local report = health.report(child)

  eq(health.section(report, 'Prefix mappings'), {
    '- ⚠️ WARNING ,s is not mapped',
    '- ⚠️ WARNING ,o is not mapped',
    '- ⚠️ WARNING ,r is not mapped',
    '- ⚠️ WARNING ,i is not mapped',
    '- ⚠️ WARNING ,c is not mapped',
  })
  eq(
    health.advice(report, 'Prefix mappings')[1],
    'aineo maps its keys once, when the editor has started; a prefix changed or a key unmapped since stays so until the next start: :help |aineo-config-prefix|'
  )
end

T['the prefix mappings']['warn that the local leader, unset and so a backslash, is the prefix'] = function()
  start_with({ autostart = false })

  local report = health.report(child)

  eq(
    health.section(report, 'Prefix mappings')[6],
    '- ⚠️ WARNING the local leader is the prefix, \\'
  )
  eq(health.advice(report, 'Prefix mappings'), {
    "A filetype plugin's <LocalLeader> mapping shadows aineo's key in its buffer; set maplocalleader to another key: :help |aineo-config-prefix|",
  })
end

T['the prefix mappings']['warn that the local leader, empty and so a backslash, is the prefix'] = function()
  start_with_local_leader({ autostart = false }, '')

  local report = health.report(child)

  eq(
    health.section(report, 'Prefix mappings')[6],
    '- ⚠️ WARNING the local leader is the prefix, \\'
  )
end

T['the prefix mappings']['warn that the local leader, set, is the prefix set'] = function()
  start_with_local_leader({ autostart = false, prefix = ',' }, ',')

  local report = health.report(child)

  eq(
    health.section(report, 'Prefix mappings')[6],
    '- ⚠️ WARNING the local leader is the prefix, ,'
  )
end

T['the prefix mappings']['are none when prefix is false'] = function()
  start_with({ autostart = false, prefix = false })

  local report = health.report(child)

  eq(health.section(report, 'Prefix mappings'), {
    '- prefix is false: aineo maps no key; :Aineo and the <Plug>(aineo-…) mappings remain',
  })
end

T['the prefix mappings']['are not checked while the configuration is wrong'] = function()
  start_with({ autostart = false, prefix = 1 })

  local report = health.report(child)

  eq(health.section(report, 'Prefix mappings'), {
    '- the prefix mappings are not checked while the configuration is wrong',
  })
end

return T
