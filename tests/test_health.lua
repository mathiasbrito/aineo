local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry_editor = dofile('tests/helpers/entry_editor.lua')
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

T['the check'] = MiniTest.new_set()

--- What a check could change in a Neovim: the aineo modules it has loaded,
--- its terminal buffers, its windows and its Normal-mode mappings.
local EDITOR_STATE = [[(function()
  local modules = vim.tbl_filter(function(name)
    return vim.startswith(name, 'aineo')
  end, vim.tbl_keys(package.loaded))
  table.sort(modules)
  local terminals = vim.tbl_filter(function(buffer)
    return vim.bo[buffer].buftype == 'terminal'
  end, vim.api.nvim_list_bufs())
  local mappings = vim.tbl_map(function(mapping)
    return mapping.lhs
  end, vim.api.nvim_get_keymap('n'))
  table.sort(mappings)
  return {
    modules = modules,
    terminals = #terminals,
    windows = #vim.api.nvim_tabpage_list_wins(1),
    mappings = mappings,
  }
end)()]]

T['the check']['starts nothing, maps nothing and loads only the configuration'] = function()
  start_with({ autostart = false })
  local before = child.lua_get(EDITOR_STATE)

  health.report(child)

  eq(
    child.lua_get(EDITOR_STATE),
    vim.tbl_extend('force', before, {
      modules = { 'aineo.config', 'aineo.health' },
    })
  )
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

T['the autostart'] = MiniTest.new_set()

T['the autostart']['has no record when aineo did not load at startup'] = function()
  children.restart(child, { '--cmd', 'let g:loaded_aineo = 1' })

  local report = health.report(child)

  eq(health.section(report, 'Autostart'), {
    '- no record of the autostart: plugin/aineo.lua did not run at startup (vim.g.loaded_aineo set before it, or --noplugin)',
  })
end

T['the autostart']['has no record when vim.g.aineo_startup holds something aineo did not write'] = function()
  start_with({ autostart = false })
  child.lua([[vim.g.aineo_startup = 42]])

  local report = health.report(child)

  eq(health.section(report, 'Autostart'), {
    '- no record of the autostart: plugin/aineo.lua did not run at startup (vim.g.loaded_aineo set before it, or --noplugin)',
  })
end

T['the autostart']['did not run because autostart is false'] = function()
  start_with({ autostart = false })

  local report = health.report(child)

  eq(health.section(report, 'Autostart'), {
    '- the autostart did not run: autostart is false',
  })
end

T['the autostart']['did not run because no user interface was attached'] = function()
  start_with({})

  local report = health.report(child)

  eq(health.section(report, 'Autostart'), {
    '- the autostart did not run: no user interface was attached (a headless start)',
  })
end

T['the autostart']['did not run because a setting was wrong'] = function()
  start_with({ prefix = 1 })

  local report = health.report(child)

  eq(health.section(report, 'Autostart'), {
    '- ⚠️ WARNING the autostart did not run: a setting was wrong at startup',
  })
end

T['the autostart']['did not run because aineo was loaded after startup'] = function()
  children.restart(child, { '--cmd', 'let g:loaded_aineo = 1' })
  child.lua([[
    vim.g.loaded_aineo = nil
    vim.cmd.runtime('plugin/aineo.lua')
  ]])

  local report = health.report(child)

  eq(health.section(report, 'Autostart'), {
    '- the autostart did not run: aineo was loaded after startup, as a plugin manager that loads it lazily does',
  })
end

--- Starts an editor as a user starts `nvim`, in a terminal of `child`
--- (`tests/helpers/entry_editor.lua`), with aineo set to run the fake
--- `claude` and `start`'s settings, arguments, variables and piped input on
--- top, and returns it once it has settled. `claude.cmd --version` runs the
--- fake too, which exits 1 over a pipe: the editor's Claude Code line is a
--- warning.
---
---@param name string the test's own name for the fake's files
---@param start? { settings?: table, args?: string[], environment?: table<string, string>, stdin?: string }
---@return aineo.test.Editor
local function start_editor(name, start)
  start = start or {}
  local fake = claude_session.fake('health-' .. name, 'ready')
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

T['the autostart']['is reported to have opened the layout at a bare start'] = function()
  local editor = start_editor('opened')

  local report = health.editor_report(editor)

  eq(health.section(report, 'Autostart'), {
    '- ✅ OK the autostart opened the layout at startup',
  })
end

--- Interactive starts that are not bare, each with the line the health
--- check reports for it.
local NOT_BARE_STARTS = {
  {
    'file-argument',
    { args = { vim.fs.joinpath(vim.uv.cwd(), '.tests', 'fixtures', 'health-file.txt') } },
    '- the autostart did not run: Neovim was given a file to edit',
  },
  {
    'stdin',
    { stdin = 'piped text' },
    '- the autostart did not run: Neovim read its standard input',
  },
  {
    'startup-task',
    { args = { '-c', 'let g:health_command = 1' } },
    '- the autostart did not run: Neovim was given something to do besides edit (-c, -S, -e, -s, -E or a + command)',
  },
  {
    'inside-claude',
    { environment = { AINEO_ENTRY_AINEO_CHILD = '1' } },
    "- the autostart did not run: this Neovim runs inside aineo's own Claude terminal ($AINEO_CHILD is set)",
  },
}

T['the autostart']['names why a start was not bare'] = MiniTest.new_set({
  parametrize = NOT_BARE_STARTS,
})

T['the autostart']['names why a start was not bare']['in its report'] = function(name, start, line)
  local editor = start_editor(name, start)

  local report = health.editor_report(editor)

  eq(health.section(report, 'Autostart'), { line })
end

T['the autostart']['did not run because a plugin restored a session'] = function()
  local editor = start_editor('session-restored', {
    args = {
      '--cmd',
      'let g:entry_session_file = '
        .. vim.fn.string(vim.fs.joinpath(vim.uv.cwd(), 'tests', 'fixtures', 'entry', 'session.vim')),
      '--cmd',
      'set runtimepath+='
        .. vim.fs.joinpath(vim.uv.cwd(), 'tests', 'fixtures', 'entry', 'session_restore'),
    },
  })

  local report = health.editor_report(editor)

  eq(health.section(report, 'Autostart'), {
    '- the autostart did not run: a session was restored at startup (v:this_session is set)',
  })
end

T['the autostart']['is reported to have failed, with its error, when the open raised'] = function()
  local editor = start_editor('open-failed', {
    settings = { claude = { cmd = { 'aineo-no-such-claude' } } },
  })

  local report = health.editor_report(editor)

  eq(health.section(report, 'Autostart'), {
    "- ⚠️ WARNING the autostart tried to open the layout and failed: claude.cmd: 'aineo-no-such-claude' is not executable",
  })
end

T['the limits'] = MiniTest.new_set()

T['the limits']['name the stop on quit an earlier VimLeavePre handler can skip'] = function()
  start_with({ autostart = false })

  local report = health.report(child)

  eq(health.section(report, 'Limits'), {
    "- aineo stops Claude Code from its own VimLeavePre handler when Neovim quits; a VimLeavePre handler registered before it that raises an error makes Neovim skip aineo's, and a Claude Code that hangs then outlives the editor; aineo cannot detect this: :help |aineo-limits|",
  })
end

return T
