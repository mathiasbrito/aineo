local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry_editor = dofile('tests/helpers/entry_editor.lua')
local find_pickers = dofile('tests/helpers/find_pickers.lua')
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

--- What a check could change in a Neovim: the aineo homes whose modules it
--- has loaded, each named by its entry point, its terminal buffers, its
--- windows, its Normal-mode mappings and aineo's record of the autostart.
local EDITOR_STATE = [[(function()
  local homes = {}
  for name in pairs(package.loaded) do
    local home = name:match('^aineo%.[%w_]+') or name:match('^aineo$')
    if home then
      homes[home] = true
    end
  end
  local modules = vim.tbl_keys(homes)
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
    startup = vim.g.aineo_startup,
  }
end)()]]

T['the check']['starts nothing, maps nothing and loads only the configuration, the Claude session, the file finder and the shell home'] = function()
  start_with({ autostart = false })
  local before = child.lua_get(EDITOR_STATE)

  health.report(child)

  eq(
    child.lua_get(EDITOR_STATE),
    vim.tbl_extend('force', before, {
      modules = { 'aineo.claude', 'aineo.config', 'aineo.find', 'aineo.health', 'aineo.shell' },
    })
  )
end

T['Neovim'] = MiniTest.new_set()

--- The child code that makes the child's `has()` say it is not Neovim 0.12
--- or later, as an older Neovim does, and leaves every other feature to the
--- real `has()`.
local OLDER_THAN_0_12 = [[
  local has = vim.fn.has
  vim.fn.has = function(feature)
    if feature == 'nvim-0.12' then
      return 0
    end
    return has(feature)
  end
]]

T['Neovim']['names the version that runs aineo'] = function()
  start_with({ autostart = false })
  local version = child.lua_get('tostring(vim.version())')

  local report = health.report(child)

  eq(health.section(report, 'Neovim'), { '- ✅ OK Neovim ' .. version })
end

T['Neovim']['is an error, naming the oldest version aineo supports, when older than 0.12'] = function()
  start_with({ autostart = false })
  child.lua(OLDER_THAN_0_12)

  local report = health.report(child)

  eq(health.section(report, 'Neovim'), {
    '- ❌ ERROR Neovim is older than 0.12, the oldest version aineo supports',
  })
  eq(health.advice(report, 'Neovim'), { 'Update Neovim to 0.12 or later: :help |aineo-install|' })
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

T['the configuration']['is reported wrong, naming claude.hide_multiplexer, when it is not a boolean'] = function()
  start_with({ autostart = false, claude = { hide_multiplexer = 'yes' } })

  local report = health.report(child)

  eq(health.section(report, 'Configuration'), {
    '- ❌ ERROR claude.hide_multiplexer: expected boolean, got string',
  })
end

T['the configuration']['knows changes.working_branch: valid for a branch name, wrong for any other value'] = function()
  start_with({ autostart = false, changes = { working_branch = 'origin/dev' } })
  local valid = health.section(health.report(child), 'Configuration')
  start_with({ autostart = false, changes = { working_branch = 3 } })

  local wrong = health.section(health.report(child), 'Configuration')

  eq(valid, { '- ✅ OK the configuration is valid' })
  eq(wrong, {
    '- ❌ ERROR changes.working_branch: expected a non-empty string naming a branch, got 3',
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

--- The report's Claude Code section when `claude.cmd --version` was stopped at
--- the bound.
local TIMED_OUT_SECTION = {
  '- ⚠️ WARNING claude.cmd --version did not finish within 3 s',
  "- aineo's behaviour was measured on Claude Code 2.1.281",
}

--- How long the check may take when `claude.cmd --version` is stopped at its
--- 3 s bound: the bound, and what the rest of the check and a loaded host
--- add to it — less than the bound again, so a check that waits twice the
--- bound fails.
local BOUND_WITH_MARGIN_MS = 4000

--- Whether a check that took `elapsed_ms` kept to the bound.
---
---@param elapsed_ms number
---@return boolean
local function kept_to_bound(elapsed_ms)
  return elapsed_ms < BOUND_WITH_MARGIN_MS
end

T['Claude Code']['warns when claude.cmd --version runs past 3 s, and its output stays open'] = function()
  start_with_stand_in('holding')

  local check = health.timed_report(child)

  eq(health.section(check.report, 'Claude Code'), TIMED_OUT_SECTION)
  eq(kept_to_bound(check.elapsed_ms), true)
end

T['Claude Code']['warns when claude.cmd --version runs past 3 s'] = function()
  start_with_stand_in('hanging')

  local check = health.timed_report(child)

  eq(health.section(check.report, 'Claude Code'), TIMED_OUT_SECTION)
  eq(kept_to_bound(check.elapsed_ms), true)
end

T['Claude Code']['stops claude.cmd --version at 3 s while it writes without end'] = function()
  start_with_stand_in('flooding')

  local check = health.timed_report(child)

  eq(health.section(check.report, 'Claude Code'), TIMED_OUT_SECTION)
  eq(kept_to_bound(check.elapsed_ms), true)
end

T['Claude Code']['leaves no process of a wrapper that ignores TERM behind once it is stopped'] = function()
  local child_pid_file = vim.fs.joinpath(fixture.directory('health-wrapping'), 'child-pid')
  start_with_stand_in('wrapping')
  child.lua('vim.env.AINEO_HEALTH_CLAUDE_CHILD_PID = ...', { child_pid_file })

  local check = health.timed_report(child)

  local wrapped_pid = tonumber(vim.fn.readfile(child_pid_file)[1])
  eq(health.section(check.report, 'Claude Code'), TIMED_OUT_SECTION)
  eq(kept_to_bound(check.elapsed_ms), true)
  eq(
    vim.wait(1000, function()
      return vim.uv.kill(wrapped_pid, 0) == nil
    end, 20),
    true
  )
end

T['Claude Code']['leaves no process of claude.cmd --version behind when Ctrl-C ends the check early'] = function()
  local child_pid_file = vim.fs.joinpath(fixture.directory('health-interrupted'), 'child-pid')
  start_with_stand_in('wrapping')
  child.lua('vim.env.AINEO_HEALTH_CLAUDE_CHILD_PID = ...', { child_pid_file })
  child.lua_notify([[
    vim.cmd('checkhealth aineo')
    vim.g.health_checked = true
  ]])
  vim.wait(1000, function()
    return vim.uv.fs_stat(child_pid_file) ~= nil
  end, 20)

  child.api.nvim_input('<C-c>')

  eq(
    vim.wait(BOUND_WITH_MARGIN_MS, function()
      return child.lua_get('vim.g.health_checked') == true
    end, 50),
    true
  )
  local wrapped_pid = tonumber(vim.fn.readfile(child_pid_file)[1])
  eq(
    vim.wait(1000, function()
      return vim.uv.kill(wrapped_pid, 0) == nil
    end, 20),
    true
  )
end

T['Claude Code']['leaves the editor free to wait when Ctrl-C ends a check of a command that writes without end'] = function()
  local record = vim.fs.joinpath(fixture.directory('health-interrupted-flood'), 'arguments')
  start_with_stand_in('pouring')
  child.lua('vim.env.AINEO_HEALTH_CLAUDE_RECORD = ...', { record })
  child.lua_notify([[
    vim.cmd('checkhealth aineo')
    vim.g.health_checked = true
  ]])
  vim.wait(1000, function()
    return vim.uv.fs_stat(record) ~= nil
  end, 20)
  child.api.nvim_input('<C-c>')
  vim.wait(BOUND_WITH_MARGIN_MS, function()
    return child.lua_get('vim.g.health_checked') == true
  end, 50)

  local waited_ms = child.lua([[
    local started = vim.uv.hrtime()
    vim.wait(100)
    return (vim.uv.hrtime() - started) / 1e6
  ]])

  eq(waited_ms < 1000, true)
end

T['Claude Code']['reports the version of a command that finished within 3 s while the loop was busy past it'] = function()
  start_with_stand_in('finishing-late')
  child.lua([[
    local busy = vim.uv.new_timer()
    busy:start(2800, 0, function()
      local started = vim.uv.hrtime()
      while vim.uv.hrtime() - started < 400e6 do
      end
      busy:close()
    end)
  ]])

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ✅ OK claude.cmd --version: 9.9.9 (health stand-in)',
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
end

T['Claude Code']['reads an exit status of 124 as an exit, not as a time-out'] = function()
  start_with_stand_in('exiting-124')

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ⚠️ WARNING claude.cmd --version exited with 124',
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
end

T['Claude Code']['hands claude.cmd its words as they are, never to a shell'] = function()
  local record = vim.fs.joinpath(fixture.directory('health-words'), 'arguments')
  start_with({
    autostart = false,
    claude = { cmd = { HEALTH_CLAUDE, 'two words', '$(echo shell); "quoted" *' } },
  })
  child.lua('vim.env.AINEO_HEALTH_CLAUDE_RECORD = ...', { record })

  health.report(child)

  eq(vim.fn.readfile(record), { 'two words', '$(echo shell); "quoted" *', '--version' })
end

T['Claude Code']['reports the first line that holds more than white space'] = function()
  start_with_stand_in('several-lines')

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ✅ OK claude.cmd --version: 9.9.9 (health stand-in)',
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
end

T['Claude Code']['reports the first line without the carriage return a CR LF line ends in'] = function()
  start_with_stand_in('crlf')

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ✅ OK claude.cmd --version: 9.9.9 (health stand-in)',
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
end

T['Claude Code']['keeps the first 1024 bytes of what claude.cmd --version prints'] = function()
  start_with_stand_in('long-line')

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ✅ OK claude.cmd --version: ' .. string.rep('x', 1024),
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
end

T['Claude Code']['keeps no part of a character the 1024-byte cut falls inside'] = MiniTest.new_set({
  parametrize = { { 'wide-at-1024', 1023 }, { 'wider-at-1024', 1022 } },
})

T['Claude Code']['keeps no part of a character the 1024-byte cut falls inside']['of'] = function(
  mode,
  kept_x
)
  start_with_stand_in(mode)

  local report = health.report(child)

  eq(
    health.section(report, 'Claude Code')[1],
    '- ✅ OK claude.cmd --version: ' .. string.rep('x', kept_x)
  )
end

T['Claude Code']['keeps the first 1024 bytes of what claude.cmd --version writes on stderr'] = function()
  start_with_stand_in('failing-at-length')

  local report = health.report(child)

  eq(health.advice(report, 'Claude Code'), { string.rep('x', 1024) })
end

T['Claude Code']['reports that a --settings in claude.cmd takes aineo’s hooks'] = function()
  local file = vim.fs.joinpath(fixture.directory('health-settings'), 'settings.json')
  vim.fn.writefile({ '{"permissions":{"deny":["Bash(rm:*)"]}}' }, file)
  start_with({ autostart = false, claude = { cmd = { HEALTH_CLAUDE, '--settings', file } } })

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ✅ OK claude.cmd --version: 9.9.9 (health stand-in)',
    "- ✅ OK claude.cmd's --settings takes aineo's hooks",
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
end

T['Claude Code']['reads a relative --settings in claude.cmd from the editor’s working directory'] = function()
  local directory = fixture.directory('health-relative-settings')
  vim.fn.writefile({ '{"hooks":[]}' }, vim.fs.joinpath(directory, 'settings.json'))
  start_with({
    autostart = false,
    claude = { cmd = { HEALTH_CLAUDE, '--settings', 'settings.json' } },
  })
  child.lua('vim.cmd.cd(...)', { directory })

  local report = health.report(child)

  eq(
    health.section(report, 'Claude Code')[2],
    "- ⚠️ WARNING claude.cmd's --settings cannot take aineo's hooks: the hooks in "
      .. vim.fs.joinpath(directory, 'settings.json')
      .. ' are not an object'
  )
end

--- The fixture directory of the cases on a `--settings` aineo cannot add
--- its hooks to, and the files they name in it.
local UNUSABLE_SETTINGS = fixture.directory('health-unusable-settings')
local SETTINGS_LIST = vim.fs.joinpath(UNUSABLE_SETTINGS, 'list.json')
local SETTINGS_BROKEN = vim.fs.joinpath(UNUSABLE_SETTINGS, 'broken.json')
local SETTINGS_MISSING = vim.fs.joinpath(UNUSABLE_SETTINGS, 'missing.json')

T['Claude Code']['warns of a --settings in claude.cmd that cannot take aineo’s hooks, saying why'] =
  MiniTest.new_set({
    parametrize = {
      {
        { '--settings', SETTINGS_MISSING },
        'ENOENT: no such file or directory: ' .. SETTINGS_MISSING,
      },
      {
        { '--settings', UNUSABLE_SETTINGS },
        UNUSABLE_SETTINGS .. ' is not a regular file (directory)',
      },
      { { '--settings', '/dev/null' }, '/dev/null is not a regular file (char)' },
      {
        { '--settings', SETTINGS_BROKEN },
        SETTINGS_BROKEN .. ' is not valid JSON: Expected value but found T_OBJ_END at character 16',
      },
      {
        { '--settings={"permissions":}' },
        'the inline value is not valid JSON: Expected value but found T_OBJ_END at character 16',
      },
      { { '--settings', SETTINGS_LIST }, SETTINGS_LIST .. ' holds no JSON object' },
      { { '--settings', '{"hooks":[]}' }, 'the hooks in the inline value are not an object' },
      {
        { '--settings', '{"hooks":{"SessionEnd":{}}}' },
        'the SessionEnd hooks in the inline value are not a list',
      },
      { { '--settings' }, 'no value follows it' },
    },
  })

T['Claude Code']['warns of a --settings in claude.cmd that cannot take aineo’s hooks, saying why']['given'] = function(
  words,
  why
)
  vim.fn.writefile({ '["settings", "in a list"]' }, SETTINGS_LIST)
  vim.fn.writefile({ '{"permissions":}' }, SETTINGS_BROKEN)
  start_with({ autostart = false, claude = { cmd = vim.list_extend({ HEALTH_CLAUDE }, words) } })

  local report = health.report(child)

  eq(health.section(report, 'Claude Code'), {
    '- ✅ OK claude.cmd --version: 9.9.9 (health stand-in)',
    "- ⚠️ WARNING claude.cmd's --settings cannot take aineo's hooks: " .. why,
    "- aineo's behaviour was measured on Claude Code 2.1.281",
  })
  eq(health.advice(report, 'Claude Code'), {
    "Claude Code starts with them as they are, without aineo's hooks, so a session switch inside it is not followed, its subagents are not told of announce_work, and the branches and worktrees its Bash tool makes are not caught by the PostToolUse hook: :help |aineo-config-claude.cmd|",
  })
end

T['the shell terminal'] = MiniTest.new_set()

--- Starts `child` afresh with autostart off and 'shell' set to `shell`.
---
---@param shell string
local function start_with_shell(shell)
  children.restart(
    child,
    vim.list_extend(
      settings_arguments({ autostart = false }),
      { '--cmd', 'let &shell = ' .. vim.fn.string(shell) }
    )
  )
end

T['the shell terminal']["names the 'shell' the terminal pane and the run pane run"] =
  MiniTest.new_set({
    parametrize = {
      { '/bin/sh' },
      { '/bin/sh -l' },
      { '"/bin/sh" -l' },
      { '/bin/s"h"' },
    },
  })

T['the shell terminal']["names the 'shell' the terminal pane and the run pane run"]['set to'] = function(
  shell
)
  start_with_shell(shell)

  local report = health.report(child)

  eq(health.section(report, 'Shell terminal'), {
    ("- ✅ OK the terminal pane and the run pane run 'shell': %s"):format(shell),
  })
end

T['the shell terminal']["warns when the program of 'shell' is not executable"] = function()
  start_with_shell('/nonexistent/aineo-t70-shell -l')

  local report = health.report(child)

  eq(health.section(report, 'Shell terminal'), {
    "- ⚠️ WARNING 'shell' is /nonexistent/aineo-t70-shell -l: '/nonexistent/aineo-t70-shell' is not executable, so the terminal pane and the run pane cannot start a shell",
  })
  eq(health.advice(report, 'Shell terminal'), {
    "Set 'shell' to a program that exists: :help |'shell'|",
  })
end

T['the shell terminal']["warns, naming the program Neovim runs, when quotes shape the first word of 'shell'"] =
  MiniTest.new_set({
    parametrize = {
      { '"/bin/sh"x', '/bin/shx' },
      { '"/bin/s\\"h"', '/bin/s"h' },
    },
  })

T['the shell terminal']["warns, naming the program Neovim runs, when quotes shape the first word of 'shell'"]['set to'] = function(
  shell,
  program
)
  start_with_shell(shell)

  local report = health.report(child)

  eq(health.section(report, 'Shell terminal'), {
    ("- ⚠️ WARNING 'shell' is %s: '%s' is not executable, so the terminal pane and the run pane cannot start a shell"):format(
      shell,
      program
    ),
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

--- The warning a prefix equal to the leader gives, the leader unset.
local LEADER_WARNING = '- ⚠️ WARNING the leader is the prefix, \\'

--- The advice under `LEADER_WARNING`.
local LEADER_ADVICE =
  "A filetype plugin's <Leader> mapping shadows aineo's key in its buffer, as Neovim's own ChangeLog plugin does with <Leader>o; set mapleader to another key: :help |aineo-config-prefix|"

T['the prefix mappings']['are reported in place when aineo mapped each key'] = function()
  start_with_local_leader({ autostart = false }, ',')

  local report = health.report(child)

  eq(health.section(report, 'Prefix mappings'), {
    '- ✅ OK \\s runs <Plug>(aineo-send)',
    '- ✅ OK \\o runs <Plug>(aineo-open)',
    '- ✅ OK \\r runs <Plug>(aineo-report)',
    '- ✅ OK \\i runs <Plug>(aineo-input)',
    '- ✅ OK \\c runs <Plug>(aineo-claude)',
    '- ✅ OK \\tcn runs <Plug>(aineo-claude-numbers)',
    '- ✅ OK \\S runs <Plug>(aineo-sessions)',
    '- ✅ OK \\N runs <Plug>(aineo-new)',
    '- ✅ OK \\pa runs <Plug>(aineo-pane-agent)',
    '- ✅ OK \\g runs <Plug>(aineo-pane-changes)',
    '- ✅ OK \\pt runs <Plug>(aineo-pane-terminal)',
    '- ✅ OK \\x runs <Plug>(aineo-pane-run)',
    '- ✅ OK \\e runs <Plug>(aineo-pane-explorer)',
    '- ✅ OK \\X runs <Plug>(aineo-run-shell)',
    '- ✅ OK \\T runs <Plug>(aineo-tab-new)',
    '- ✅ OK \\Q runs <Plug>(aineo-tab-close)',
    '- ✅ OK \\1 runs <Plug>(aineo-tab-1)',
    '- ✅ OK \\2 runs <Plug>(aineo-tab-2)',
    '- ✅ OK \\3 runs <Plug>(aineo-tab-3)',
    '- ✅ OK \\4 runs <Plug>(aineo-tab-4)',
    '- ✅ OK \\5 runs <Plug>(aineo-tab-5)',
    '- ✅ OK \\6 runs <Plug>(aineo-tab-6)',
    '- ✅ OK \\7 runs <Plug>(aineo-tab-7)',
    '- ✅ OK \\8 runs <Plug>(aineo-tab-8)',
    '- ✅ OK \\9 runs <Plug>(aineo-tab-9)',
    '- ✅ OK \\d runs <Plug>(aineo-diff-close)',
    '- ✅ OK \\f runs <Plug>(aineo-find)',
    '- ✅ OK \\z runs <Plug>(aineo-zoom)',
    '- ✅ OK \\Z runs <Plug>(aineo-zoom-full)',
    '- ✅ OK \\s in Visual mode runs <Plug>(aineo-send)',
    '- ✅ OK \\v runs <Plug>(aineo-explain)',
    '- ✅ OK \\V runs <Plug>(aineo-explain-tools)',
    '- ✅ OK \\vi runs <Plug>(aineo-explain-issues)',
    '- ✅ OK \\VI runs <Plug>(aineo-explain-issues-tools)',
    '- ✅ OK \\vm runs <Plug>(aineo-explain-mark)',
    '- ✅ OK \\v in Visual mode runs <Plug>(aineo-explain)',
    '- ✅ OK \\V in Visual mode runs <Plug>(aineo-explain-tools)',
    '- ✅ OK \\vi in Visual mode runs <Plug>(aineo-explain-issues)',
    '- ✅ OK \\VI in Visual mode runs <Plug>(aineo-explain-issues-tools)',
    '- ✅ OK \\vm in Visual mode runs <Plug>(aineo-explain-mark)',
    LEADER_WARNING,
  })
end

T['the prefix mappings']['warn that the leader, unset and so a backslash, is the prefix'] = function()
  start_with_local_leader({ autostart = false }, ',')

  local report = health.report(child)

  eq(health.section(report, 'Prefix mappings')[41], LEADER_WARNING)
  eq(health.advice(report, 'Prefix mappings'), { LEADER_ADVICE })
end

T['the prefix mappings']['warn that the leader, a Number, is the prefix'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false, prefix = '1' }), {
      '--cmd',
      'let g:maplocalleader = ","',
      '--cmd',
      'let g:mapleader = 1',
    })
  )

  local report = health.report(child)

  eq(health.section(report, 'Prefix mappings')[41], '- ⚠️ WARNING the leader is the prefix, 1')
end

T['the prefix mappings']['warn that a leader longer than 48 bytes, which Neovim maps as a backslash, is the prefix'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), {
      '--cmd',
      'let g:maplocalleader = ","',
      '--cmd',
      'let g:mapleader = ' .. vim.fn.string(string.rep('a', 49)),
    })
  )

  local report = health.report(child)

  eq(health.section(report, 'Prefix mappings')[41], LEADER_WARNING)
end

T['the prefix mappings']['take a leader of 48 bytes as the characters Neovim maps it to'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), {
      '--cmd',
      'let g:maplocalleader = ","',
      '--cmd',
      'let g:mapleader = ' .. vim.fn.string(string.rep('a', 48)),
    })
  )

  local report = health.report(child)

  eq(#health.section(report, 'Prefix mappings'), 40)
end

T['the prefix mappings']['warn that the leader, the same key as a prefix in key notation, is the prefix'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false, prefix = '<space>' }), {
      '--cmd',
      'let g:maplocalleader = ","',
      '--cmd',
      'let g:mapleader = " "',
    })
  )

  local report = health.report(child)

  eq(
    health.section(report, 'Prefix mappings')[41],
    '- ⚠️ WARNING the leader is the prefix, <space>'
  )
end

T['the prefix mappings']['take a leader written in key notation as the characters Neovim maps it to'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false, prefix = '<Space>' }), {
      '--cmd',
      'let g:maplocalleader = ","',
      '--cmd',
      'let g:mapleader = "<Space>"',
    })
  )

  local report = health.report(child)

  eq(#health.section(report, 'Prefix mappings'), 40)
end

T['the prefix mappings']['report the keys plugin/aineo.lua mapped to aineo, no more and no fewer'] = function()
  start_with_local_leader({ autostart = false }, ',')
  local mapped = health.keys_mapped_to_aineo(child)

  local report = health.report(child)

  eq(health.keys_reported_in_place(report), mapped)
end

T['the prefix mappings']['warn that the local leader, the same key as a prefix in key notation, is the prefix'] = function()
  start_with_local_leader({ autostart = false, prefix = '<space>' }, ' ')

  local report = health.report(child)

  eq(health.section(report, 'Prefix mappings'), {
    '- ✅ OK <space>s runs <Plug>(aineo-send)',
    '- ✅ OK <space>o runs <Plug>(aineo-open)',
    '- ✅ OK <space>r runs <Plug>(aineo-report)',
    '- ✅ OK <space>i runs <Plug>(aineo-input)',
    '- ✅ OK <space>c runs <Plug>(aineo-claude)',
    '- ✅ OK <space>tcn runs <Plug>(aineo-claude-numbers)',
    '- ✅ OK <space>S runs <Plug>(aineo-sessions)',
    '- ✅ OK <space>N runs <Plug>(aineo-new)',
    '- ✅ OK <space>pa runs <Plug>(aineo-pane-agent)',
    '- ✅ OK <space>g runs <Plug>(aineo-pane-changes)',
    '- ✅ OK <space>pt runs <Plug>(aineo-pane-terminal)',
    '- ✅ OK <space>x runs <Plug>(aineo-pane-run)',
    '- ✅ OK <space>e runs <Plug>(aineo-pane-explorer)',
    '- ✅ OK <space>X runs <Plug>(aineo-run-shell)',
    '- ✅ OK <space>T runs <Plug>(aineo-tab-new)',
    '- ✅ OK <space>Q runs <Plug>(aineo-tab-close)',
    '- ✅ OK <space>1 runs <Plug>(aineo-tab-1)',
    '- ✅ OK <space>2 runs <Plug>(aineo-tab-2)',
    '- ✅ OK <space>3 runs <Plug>(aineo-tab-3)',
    '- ✅ OK <space>4 runs <Plug>(aineo-tab-4)',
    '- ✅ OK <space>5 runs <Plug>(aineo-tab-5)',
    '- ✅ OK <space>6 runs <Plug>(aineo-tab-6)',
    '- ✅ OK <space>7 runs <Plug>(aineo-tab-7)',
    '- ✅ OK <space>8 runs <Plug>(aineo-tab-8)',
    '- ✅ OK <space>9 runs <Plug>(aineo-tab-9)',
    '- ✅ OK <space>d runs <Plug>(aineo-diff-close)',
    '- ✅ OK <space>f runs <Plug>(aineo-find)',
    '- ✅ OK <space>z runs <Plug>(aineo-zoom)',
    '- ✅ OK <space>Z runs <Plug>(aineo-zoom-full)',
    '- ✅ OK <space>s in Visual mode runs <Plug>(aineo-send)',
    '- ✅ OK <space>v runs <Plug>(aineo-explain)',
    '- ✅ OK <space>V runs <Plug>(aineo-explain-tools)',
    '- ✅ OK <space>vi runs <Plug>(aineo-explain-issues)',
    '- ✅ OK <space>VI runs <Plug>(aineo-explain-issues-tools)',
    '- ✅ OK <space>vm runs <Plug>(aineo-explain-mark)',
    '- ✅ OK <space>v in Visual mode runs <Plug>(aineo-explain)',
    '- ✅ OK <space>V in Visual mode runs <Plug>(aineo-explain-tools)',
    '- ✅ OK <space>vi in Visual mode runs <Plug>(aineo-explain-issues)',
    '- ✅ OK <space>VI in Visual mode runs <Plug>(aineo-explain-issues-tools)',
    '- ✅ OK <space>vm in Visual mode runs <Plug>(aineo-explain-mark)',
    '- ⚠️ WARNING the local leader is the prefix, <space>',
  })
end

T['the prefix mappings']['take a local leader written in key notation as the characters Neovim maps it to'] = function()
  start_with_local_leader({ autostart = false, prefix = '<Space>' }, '<Space>')

  local report = health.report(child)

  eq(health.section(report, 'Prefix mappings'), {
    '- ✅ OK <Space>s runs <Plug>(aineo-send)',
    '- ✅ OK <Space>o runs <Plug>(aineo-open)',
    '- ✅ OK <Space>r runs <Plug>(aineo-report)',
    '- ✅ OK <Space>i runs <Plug>(aineo-input)',
    '- ✅ OK <Space>c runs <Plug>(aineo-claude)',
    '- ✅ OK <Space>tcn runs <Plug>(aineo-claude-numbers)',
    '- ✅ OK <Space>S runs <Plug>(aineo-sessions)',
    '- ✅ OK <Space>N runs <Plug>(aineo-new)',
    '- ✅ OK <Space>pa runs <Plug>(aineo-pane-agent)',
    '- ✅ OK <Space>g runs <Plug>(aineo-pane-changes)',
    '- ✅ OK <Space>pt runs <Plug>(aineo-pane-terminal)',
    '- ✅ OK <Space>x runs <Plug>(aineo-pane-run)',
    '- ✅ OK <Space>e runs <Plug>(aineo-pane-explorer)',
    '- ✅ OK <Space>X runs <Plug>(aineo-run-shell)',
    '- ✅ OK <Space>T runs <Plug>(aineo-tab-new)',
    '- ✅ OK <Space>Q runs <Plug>(aineo-tab-close)',
    '- ✅ OK <Space>1 runs <Plug>(aineo-tab-1)',
    '- ✅ OK <Space>2 runs <Plug>(aineo-tab-2)',
    '- ✅ OK <Space>3 runs <Plug>(aineo-tab-3)',
    '- ✅ OK <Space>4 runs <Plug>(aineo-tab-4)',
    '- ✅ OK <Space>5 runs <Plug>(aineo-tab-5)',
    '- ✅ OK <Space>6 runs <Plug>(aineo-tab-6)',
    '- ✅ OK <Space>7 runs <Plug>(aineo-tab-7)',
    '- ✅ OK <Space>8 runs <Plug>(aineo-tab-8)',
    '- ✅ OK <Space>9 runs <Plug>(aineo-tab-9)',
    '- ✅ OK <Space>d runs <Plug>(aineo-diff-close)',
    '- ✅ OK <Space>f runs <Plug>(aineo-find)',
    '- ✅ OK <Space>z runs <Plug>(aineo-zoom)',
    '- ✅ OK <Space>Z runs <Plug>(aineo-zoom-full)',
    '- ✅ OK <Space>s in Visual mode runs <Plug>(aineo-send)',
    '- ✅ OK <Space>v runs <Plug>(aineo-explain)',
    '- ✅ OK <Space>V runs <Plug>(aineo-explain-tools)',
    '- ✅ OK <Space>vi runs <Plug>(aineo-explain-issues)',
    '- ✅ OK <Space>VI runs <Plug>(aineo-explain-issues-tools)',
    '- ✅ OK <Space>vm runs <Plug>(aineo-explain-mark)',
    '- ✅ OK <Space>v in Visual mode runs <Plug>(aineo-explain)',
    '- ✅ OK <Space>V in Visual mode runs <Plug>(aineo-explain-tools)',
    '- ✅ OK <Space>vi in Visual mode runs <Plug>(aineo-explain-issues)',
    '- ✅ OK <Space>VI in Visual mode runs <Plug>(aineo-explain-issues-tools)',
    '- ✅ OK <Space>vm in Visual mode runs <Plug>(aineo-explain-mark)',
  })
end

T['the prefix mappings']['warn that the local leader, a Number, is the prefix'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false, prefix = '1' }), {
      '--cmd',
      'let g:maplocalleader = 1',
    })
  )

  local report = health.report(child)

  eq(
    health.section(report, 'Prefix mappings')[41],
    '- ⚠️ WARNING the local leader is the prefix, 1'
  )
  eq(#health.section(report, 'Limits'), 1)
end

T['the prefix mappings']['warn that a List local leader, which Neovim maps as a backslash, is the prefix'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), {
      '--cmd',
      'let g:mapleader = ","',
      '--cmd',
      'let g:maplocalleader = [1]',
    })
  )

  local report = health.report(child)

  eq(
    health.section(report, 'Prefix mappings')[41],
    '- ⚠️ WARNING the local leader is the prefix, \\'
  )
  eq(#health.section(report, 'Limits'), 1)
end

T['the prefix mappings']['say the keys are mapped once the editor has started, when checked before'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), { '-c', health.CAPTURE })
  )

  local report = child.lua_get('vim.g.health_report')

  eq(health.section(report, 'Prefix mappings'), {
    health.VIM_ENTER_PENDING_KEYS,
    '- ⚠️ WARNING the local leader is the prefix, \\',
    LEADER_WARNING,
  })
end

--- Starts `child` afresh with the local leader `,` and aineo not loaded,
--- then loads aineo, as a plugin manager that loads it lazily does, and runs
--- the check in the same tick; returns the report.
---
---@return string[]
local function check_in_the_tick_aineo_is_loaded_late()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), {
      '--cmd',
      'let g:maplocalleader = ","',
      '--cmd',
      'let g:loaded_aineo = 1',
    })
  )
  return child.lua([[
    vim.g.loaded_aineo = nil
    vim.cmd.runtime('plugin/aineo.lua')
    vim.cmd('checkhealth aineo')
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
  ]])
end

T['the prefix mappings']['say the keys are mapped in the next tick, when checked in the tick aineo is loaded late'] = function()
  local report = check_in_the_tick_aineo_is_loaded_late()

  eq(health.section(report, 'Prefix mappings'), {
    '- the prefix keys are not mapped yet: aineo was loaded after startup, and maps them in the next event-loop tick',
    LEADER_WARNING,
  })
end

T['the prefix mappings']['are reported in place once the tick after aineo is loaded late has run'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), {
      '--cmd',
      'let g:maplocalleader = ","',
      '--cmd',
      'let g:loaded_aineo = 1',
    })
  )
  child.lua([[
    vim.g.loaded_aineo = nil
    vim.cmd.runtime('plugin/aineo.lua')
  ]])
  child.lua('vim.wait(0)')

  local report = health.report(child)

  eq(health.section(report, 'Prefix mappings')[1], '- ✅ OK \\s runs <Plug>(aineo-send)')
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
    '- ✅ OK \\tcn runs <Plug>(aineo-claude-numbers)',
    '- ✅ OK \\S runs <Plug>(aineo-sessions)',
    '- ✅ OK \\N runs <Plug>(aineo-new)',
    '- ✅ OK \\pa runs <Plug>(aineo-pane-agent)',
    '- ✅ OK \\g runs <Plug>(aineo-pane-changes)',
    '- ✅ OK \\pt runs <Plug>(aineo-pane-terminal)',
    '- ✅ OK \\x runs <Plug>(aineo-pane-run)',
    '- ✅ OK \\e runs <Plug>(aineo-pane-explorer)',
    '- ✅ OK \\X runs <Plug>(aineo-run-shell)',
    '- ✅ OK \\T runs <Plug>(aineo-tab-new)',
    '- ✅ OK \\Q runs <Plug>(aineo-tab-close)',
    '- ✅ OK \\1 runs <Plug>(aineo-tab-1)',
    '- ✅ OK \\2 runs <Plug>(aineo-tab-2)',
    '- ✅ OK \\3 runs <Plug>(aineo-tab-3)',
    '- ✅ OK \\4 runs <Plug>(aineo-tab-4)',
    '- ✅ OK \\5 runs <Plug>(aineo-tab-5)',
    '- ✅ OK \\6 runs <Plug>(aineo-tab-6)',
    '- ✅ OK \\7 runs <Plug>(aineo-tab-7)',
    '- ✅ OK \\8 runs <Plug>(aineo-tab-8)',
    '- ✅ OK \\9 runs <Plug>(aineo-tab-9)',
    '- ✅ OK \\d runs <Plug>(aineo-diff-close)',
    '- ✅ OK \\f runs <Plug>(aineo-find)',
    '- ✅ OK \\z runs <Plug>(aineo-zoom)',
    '- ✅ OK \\Z runs <Plug>(aineo-zoom-full)',
    '- ✅ OK \\s in Visual mode runs <Plug>(aineo-send)',
    '- ✅ OK \\v runs <Plug>(aineo-explain)',
    '- ✅ OK \\V runs <Plug>(aineo-explain-tools)',
    '- ✅ OK \\vi runs <Plug>(aineo-explain-issues)',
    '- ✅ OK \\VI runs <Plug>(aineo-explain-issues-tools)',
    '- ✅ OK \\vm runs <Plug>(aineo-explain-mark)',
    '- ✅ OK \\v in Visual mode runs <Plug>(aineo-explain)',
    '- ✅ OK \\V in Visual mode runs <Plug>(aineo-explain-tools)',
    '- ✅ OK \\vi in Visual mode runs <Plug>(aineo-explain-issues)',
    '- ✅ OK \\VI in Visual mode runs <Plug>(aineo-explain-issues-tools)',
    '- ✅ OK \\vm in Visual mode runs <Plug>(aineo-explain-mark)',
    LEADER_WARNING,
  })
  eq(health.advice(report, 'Prefix mappings'), {
    'aineo leaves a key you mapped alone; map <Plug>(aineo-send) to a key of your own: :help |aineo-mappings|',
    LEADER_ADVICE,
  })
end

T['the prefix mappings']['warn of a Visual-mode key the user mapped, saying Visual mode'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), {
      '--cmd',
      'let g:maplocalleader = ","',
      '--cmd',
      'xnoremap \\s :echo "mine"<CR>',
    })
  )

  local report = health.report(child)

  eq({
    normal = health.section(report, 'Prefix mappings')[1],
    visual = health.section(report, 'Prefix mappings')[30],
  }, {
    normal = '- ✅ OK \\s runs <Plug>(aineo-send)',
    visual = '- ⚠️ WARNING \\s in Visual mode runs \':echo "mine"<CR>\', not <Plug>(aineo-send)',
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
    '- ⚠️ WARNING ,tcn is not mapped',
    '- ⚠️ WARNING ,S is not mapped',
    '- ⚠️ WARNING ,N is not mapped',
    '- ⚠️ WARNING ,pa is not mapped',
    '- ⚠️ WARNING ,g is not mapped',
    '- ⚠️ WARNING ,pt is not mapped',
    '- ⚠️ WARNING ,x is not mapped',
    '- ⚠️ WARNING ,e is not mapped',
    '- ⚠️ WARNING ,X is not mapped',
    '- ⚠️ WARNING ,T is not mapped',
    '- ⚠️ WARNING ,Q is not mapped',
    '- ⚠️ WARNING ,1 is not mapped',
    '- ⚠️ WARNING ,2 is not mapped',
    '- ⚠️ WARNING ,3 is not mapped',
    '- ⚠️ WARNING ,4 is not mapped',
    '- ⚠️ WARNING ,5 is not mapped',
    '- ⚠️ WARNING ,6 is not mapped',
    '- ⚠️ WARNING ,7 is not mapped',
    '- ⚠️ WARNING ,8 is not mapped',
    '- ⚠️ WARNING ,9 is not mapped',
    '- ⚠️ WARNING ,d is not mapped',
    '- ⚠️ WARNING ,f is not mapped',
    '- ⚠️ WARNING ,z is not mapped',
    '- ⚠️ WARNING ,Z is not mapped',
    '- ⚠️ WARNING ,s in Visual mode is not mapped',
    '- ⚠️ WARNING ,v is not mapped',
    '- ⚠️ WARNING ,V is not mapped',
    '- ⚠️ WARNING ,vi is not mapped',
    '- ⚠️ WARNING ,VI is not mapped',
    '- ⚠️ WARNING ,vm is not mapped',
    '- ⚠️ WARNING ,v in Visual mode is not mapped',
    '- ⚠️ WARNING ,V in Visual mode is not mapped',
    '- ⚠️ WARNING ,vi in Visual mode is not mapped',
    '- ⚠️ WARNING ,VI in Visual mode is not mapped',
    '- ⚠️ WARNING ,vm in Visual mode is not mapped',
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
    health.section(report, 'Prefix mappings')[41],
    '- ⚠️ WARNING the local leader is the prefix, \\'
  )
  eq(health.advice(report, 'Prefix mappings'), {
    "A filetype plugin's <LocalLeader> mapping shadows aineo's key in its buffer; set maplocalleader to another key: :help |aineo-config-prefix|",
    LEADER_ADVICE,
  })
end

T['the prefix mappings']['warn that the local leader, empty and so a backslash, is the prefix'] = function()
  start_with_local_leader({ autostart = false }, '')

  local report = health.report(child)

  eq(
    health.section(report, 'Prefix mappings')[41],
    '- ⚠️ WARNING the local leader is the prefix, \\'
  )
end

T['the prefix mappings']['warn that the local leader, set, is the prefix set'] = function()
  start_with_local_leader({ autostart = false, prefix = ',' }, ',')

  local report = health.report(child)

  eq(
    health.section(report, 'Prefix mappings')[41],
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

T['the terminal prefix mappings'] = MiniTest.new_set()

--- The lines of the Terminal prefix mappings section when aineo mapped each
--- twin, for the default terminal prefix: one per key and mode, Terminal
--- mode first.
local TWIN_LINES = {
  '- ✅ OK <C-\\>o in Terminal mode runs <C-\\><C-n><Plug>(aineo-open)',
  '- ✅ OK <C-\\>o in Insert mode runs <C-]><Esc><Plug>(aineo-open)',
  '- ✅ OK <C-\\>r in Terminal mode runs <C-\\><C-n><Plug>(aineo-report)',
  '- ✅ OK <C-\\>r in Insert mode runs <C-]><Esc><Plug>(aineo-report)',
  '- ✅ OK <C-\\>i in Terminal mode runs <C-\\><C-n><Plug>(aineo-input)',
  '- ✅ OK <C-\\>i in Insert mode runs <C-]><Esc><Plug>(aineo-input)',
  '- ✅ OK <C-\\>c in Terminal mode runs <C-\\><C-n><Plug>(aineo-claude)',
  '- ✅ OK <C-\\>c in Insert mode runs <C-]><Esc><Plug>(aineo-claude)',
  '- ✅ OK <C-\\>tcn in Terminal mode runs <C-\\><C-n><Plug>(aineo-claude-numbers)',
  '- ✅ OK <C-\\>tcn in Insert mode runs <C-]><Esc><Plug>(aineo-claude-numbers)',
  '- ✅ OK <C-\\>S in Terminal mode runs <C-\\><C-n><Plug>(aineo-sessions)',
  '- ✅ OK <C-\\>S in Insert mode runs <C-]><Esc><Plug>(aineo-sessions)',
  '- ✅ OK <C-\\>N in Terminal mode runs <C-\\><C-n><Plug>(aineo-new)',
  '- ✅ OK <C-\\>N in Insert mode runs <C-]><Esc><Plug>(aineo-new)',
  '- ✅ OK <C-\\>pa in Terminal mode runs <C-\\><C-n><Plug>(aineo-pane-agent)',
  '- ✅ OK <C-\\>pa in Insert mode runs <C-]><Esc><Plug>(aineo-pane-agent)',
  '- ✅ OK <C-\\>g in Terminal mode runs <C-\\><C-n><Plug>(aineo-pane-changes)',
  '- ✅ OK <C-\\>g in Insert mode runs <C-]><Esc><Plug>(aineo-pane-changes)',
  '- ✅ OK <C-\\>pt in Terminal mode runs <C-\\><C-n><Plug>(aineo-pane-terminal)',
  '- ✅ OK <C-\\>pt in Insert mode runs <C-]><Esc><Plug>(aineo-pane-terminal)',
  '- ✅ OK <C-\\>x in Terminal mode runs <C-\\><C-n><Plug>(aineo-pane-run)',
  '- ✅ OK <C-\\>x in Insert mode runs <C-]><Esc><Plug>(aineo-pane-run)',
  '- ✅ OK <C-\\>e in Terminal mode runs <C-\\><C-n><Plug>(aineo-pane-explorer)',
  '- ✅ OK <C-\\>e in Insert mode runs <C-]><Esc><Plug>(aineo-pane-explorer)',
  '- ✅ OK <C-\\>X in Terminal mode runs <C-\\><C-n><Plug>(aineo-run-shell)',
  '- ✅ OK <C-\\>X in Insert mode runs <C-]><Esc><Plug>(aineo-run-shell)',
  '- ✅ OK <C-\\>T in Terminal mode runs <C-\\><C-n><Plug>(aineo-tab-new)',
  '- ✅ OK <C-\\>T in Insert mode runs <C-]><Esc><Plug>(aineo-tab-new)',
  '- ✅ OK <C-\\>Q in Terminal mode runs <C-\\><C-n><Plug>(aineo-tab-close)',
  '- ✅ OK <C-\\>Q in Insert mode runs <C-]><Esc><Plug>(aineo-tab-close)',
  '- ✅ OK <C-\\>1 in Terminal mode runs <C-\\><C-n><Plug>(aineo-tab-1)',
  '- ✅ OK <C-\\>1 in Insert mode runs <C-]><Esc><Plug>(aineo-tab-1)',
  '- ✅ OK <C-\\>2 in Terminal mode runs <C-\\><C-n><Plug>(aineo-tab-2)',
  '- ✅ OK <C-\\>2 in Insert mode runs <C-]><Esc><Plug>(aineo-tab-2)',
  '- ✅ OK <C-\\>3 in Terminal mode runs <C-\\><C-n><Plug>(aineo-tab-3)',
  '- ✅ OK <C-\\>3 in Insert mode runs <C-]><Esc><Plug>(aineo-tab-3)',
  '- ✅ OK <C-\\>4 in Terminal mode runs <C-\\><C-n><Plug>(aineo-tab-4)',
  '- ✅ OK <C-\\>4 in Insert mode runs <C-]><Esc><Plug>(aineo-tab-4)',
  '- ✅ OK <C-\\>5 in Terminal mode runs <C-\\><C-n><Plug>(aineo-tab-5)',
  '- ✅ OK <C-\\>5 in Insert mode runs <C-]><Esc><Plug>(aineo-tab-5)',
  '- ✅ OK <C-\\>6 in Terminal mode runs <C-\\><C-n><Plug>(aineo-tab-6)',
  '- ✅ OK <C-\\>6 in Insert mode runs <C-]><Esc><Plug>(aineo-tab-6)',
  '- ✅ OK <C-\\>7 in Terminal mode runs <C-\\><C-n><Plug>(aineo-tab-7)',
  '- ✅ OK <C-\\>7 in Insert mode runs <C-]><Esc><Plug>(aineo-tab-7)',
  '- ✅ OK <C-\\>8 in Terminal mode runs <C-\\><C-n><Plug>(aineo-tab-8)',
  '- ✅ OK <C-\\>8 in Insert mode runs <C-]><Esc><Plug>(aineo-tab-8)',
  '- ✅ OK <C-\\>9 in Terminal mode runs <C-\\><C-n><Plug>(aineo-tab-9)',
  '- ✅ OK <C-\\>9 in Insert mode runs <C-]><Esc><Plug>(aineo-tab-9)',
  '- ✅ OK <C-\\>d in Terminal mode runs <C-\\><C-n><Plug>(aineo-diff-close)',
  '- ✅ OK <C-\\>d in Insert mode runs <C-]><Esc><Plug>(aineo-diff-close)',
  '- ✅ OK <C-\\>f in Terminal mode runs <C-\\><C-n><Plug>(aineo-find)',
  '- ✅ OK <C-\\>f in Insert mode runs <C-]><Esc><Plug>(aineo-find)',
  '- ✅ OK <C-\\>z in Terminal mode runs <C-\\><C-n><Plug>(aineo-zoom)',
  '- ✅ OK <C-\\>z in Insert mode runs <C-]><Esc><Plug>(aineo-zoom)',
  '- ✅ OK <C-\\>Z in Terminal mode runs <C-\\><C-n><Plug>(aineo-zoom-full)',
  '- ✅ OK <C-\\>Z in Insert mode runs <C-]><Esc><Plug>(aineo-zoom-full)',
}

T['the terminal prefix mappings']['are reported in place when aineo mapped each twin'] = function()
  start_with({ autostart = false })

  local report = health.report(child)

  eq(health.section(report, 'Terminal prefix mappings'), TWIN_LINES)
end

T['the terminal prefix mappings']['warn of a twin the user mapped, naming what it runs'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), {
      '--cmd',
      'tnoremap <C-\\>r :echo "mine"<CR>',
    })
  )

  local report = health.report(child)

  eq(
    health.section(report, 'Terminal prefix mappings')[3],
    '- ⚠️ WARNING <C-\\>r in Terminal mode runs \':echo "mine"<CR>\', not <C-\\><C-n><Plug>(aineo-report)'
  )
  eq(health.advice(report, 'Terminal prefix mappings'), {
    'aineo leaves a key you mapped alone; map <Plug>(aineo-report) to a key of your own: :help |aineo-mappings|',
  })
end

T['the terminal prefix mappings']['warn of a twin nobody mapped, as after one is unmapped'] = function()
  start_with({ autostart = false })
  child.cmd([[iunmap <C-\>i]])

  local report = health.report(child)

  eq(
    health.section(report, 'Terminal prefix mappings')[6],
    '- ⚠️ WARNING <C-\\>i in Insert mode is not mapped'
  )
  eq(health.advice(report, 'Terminal prefix mappings'), {
    'aineo maps its keys once, when the editor has started; a terminal_prefix changed or a key unmapped since stays so until the next start: :help |aineo-config-terminal_prefix|',
  })
end

--- The Insert-mode lines of `TWIN_LINES`, without the Terminal-mode ones.
local INSERT_TWIN_LINES = vim.tbl_filter(function(line)
  return line:find('in Insert mode', 1, true) ~= nil
end, TWIN_LINES)

T['the terminal prefix mappings']['say a mode is skipped when the user mapped the terminal prefix alone in it'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), {
      '--cmd',
      'tnoremap <C-\\> <Nop>',
    })
  )

  local report = health.report(child)

  eq(
    health.section(report, 'Terminal prefix mappings'),
    vim.list_extend(
      { '- ⚠️ WARNING <C-\\> is mapped in Terminal mode: aineo maps no twin there' },
      INSERT_TWIN_LINES
    )
  )
  eq(health.advice(report, 'Terminal prefix mappings'), {
    'A key you mapped alone makes the twins ambiguous with it, and aineo leaves it yours; set terminal_prefix to another key to have twins in that mode: :help |aineo-terminal-keys|',
  })
end

T['the terminal prefix mappings']['warn of a mapping of the terminal prefix alone local to a buffer'] = function()
  start_with({ autostart = false })
  child.cmd('enew')
  child.cmd([[inoremap <buffer> <C-\> <Nop>]])
  local buffer = child.api.nvim_get_current_buf()

  local report = health.report(child)

  eq(
    health.section(report, 'Terminal prefix mappings')[1],
    ("- ⚠️ WARNING <C-\\> is mapped in Insert mode, local to buffers %d: it waits for 'timeoutlen', and a twin's letter typed then runs aineo's action"):format(
      buffer
    )
  )
  eq(health.advice(report, 'Terminal prefix mappings'), {
    'Set terminal_prefix to another key, or map the keys of your buffer yourself: :help |aineo-terminal-keys|',
  })
end

T['the terminal prefix mappings']['warn of a terminal prefix that is a single printable key'] = function()
  start_with({ autostart = false, terminal_prefix = 'x' })

  local report = health.report(child)

  eq(
    health.section(report, 'Terminal prefix mappings')[57],
    '- ⚠️ WARNING terminal_prefix is x, a printable key: typing it in Insert mode runs a twin'
  )
  eq(health.advice(report, 'Terminal prefix mappings'), {
    'Choose a key with a modifier, such as <C-\\>: :help |aineo-config-terminal_prefix|',
  })
end

T['the terminal prefix mappings']['warn of a terminal prefix that starts with a key pair of Neovim'] =
  MiniTest.new_set({
    parametrize = { { '<C-\\><C-n>x' }, { '<C-\\><C-o>x' } },
  })

T['the terminal prefix mappings']['warn of a terminal prefix that starts with a key pair of Neovim']['such as'] = function(
  prefix
)
  start_with({ autostart = false, terminal_prefix = prefix })

  local report = health.report(child)

  eq(
    health.section(report, 'Terminal prefix mappings')[57],
    ('- ⚠️ WARNING terminal_prefix %s starts with a key pair of Neovim: it waits for the next key'):format(
      prefix
    )
  )
  eq(health.advice(report, 'Terminal prefix mappings'), {
    "Neovim's own <C-\\><C-n> and <C-\\><C-o> would no longer act at once: :help |aineo-config-terminal_prefix|",
  })
end

T['the terminal prefix mappings']['report the keys of the terminal prefix the setting names'] = function()
  start_with({ autostart = false, terminal_prefix = '<C-q>' })

  local report = health.report(child)

  eq(
    health.section(report, 'Terminal prefix mappings')[1],
    '- ✅ OK <C-q>o in Terminal mode runs <C-\\><C-n><Plug>(aineo-open)'
  )
end

T['the terminal prefix mappings']['are none when terminal_prefix is false'] = function()
  start_with({ autostart = false, terminal_prefix = false })

  local report = health.report(child)

  eq(health.section(report, 'Terminal prefix mappings'), {
    '- terminal_prefix is false: aineo maps no key in Terminal and Insert mode',
  })
end

T['the terminal prefix mappings']['are not checked while the configuration is wrong'] = function()
  start_with({ autostart = false, terminal_prefix = 1 })

  local report = health.report(child)

  eq(health.section(report, 'Terminal prefix mappings'), {
    '- the terminal prefix mappings are not checked while the configuration is wrong',
  })
end

T['the terminal prefix mappings']['say the keys are mapped once the editor has started, when checked before'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), { '-c', health.CAPTURE })
  )

  local report = child.lua_get('vim.g.health_report')

  eq(health.section(report, 'Terminal prefix mappings'), {
    '- the terminal prefix keys are not mapped: aineo maps them from its VimEnter handler, which has not run — the editor is still starting, or a VimEnter autocommand before it threw an exception',
  })
end

T['the terminal prefix mappings']['say the keys are mapped in the next tick, when checked in the tick aineo is loaded late'] = function()
  local report = check_in_the_tick_aineo_is_loaded_late()

  eq(health.section(report, 'Terminal prefix mappings'), {
    '- the terminal prefix keys are not mapped yet: aineo was loaded after startup, and maps them in the next event-loop tick',
  })
end

T['the tab line'] = MiniTest.new_set()

--- The line the Tab line section shows while 'showtabline' is not 2 and
--- `tabs.always_show` holds its default, `true`, before any aineo tab has
--- opened: 'showtabline' is Neovim's 1.
local TAB_LINE_SHOWN_WHEN_A_TAB_OPENS =
  "- 'showtabline' is 1 now; aineo sets it to 2 once, when the first aineo tab opens, and leaves it after (tabs.always_show): :help |aineo-tabs|"

--- The line the Tab line section shows, whichever tab line is in use, about
--- what the activity indicator reads.
local INDICATOR_READS_THE_TITLE =
  '- the activity indicator on a tab reads the title Claude Code sets on its terminal: :help |aineo-tabs|'

--- The line the Tab line section shows while `claude.hide_multiplexer` holds
--- its default, `true`.
local AINEO_HIDES_THE_MULTIPLEXER =
  '- aineo starts Claude Code without TMUX, TMUX_PANE, STY and ZELLIJ (claude.hide_multiplexer), so the activity indicator works inside tmux, screen and zellij: :help |aineo-limits|'

--- The variables that make the Tab line section warn that no tab shows
--- activity.
local TITLE_VARIABLES = {
  'CLAUDE_CODE_DISABLE_TERMINAL_TITLE',
  'TMUX',
  'STY',
  'ZELLIJ',
}

--- The report `:checkhealth aineo` shows in `child` with the environment of
--- its editor holding the variables of `environment` and none other of
--- `TITLE_VARIABLES`.
---
---@param environment table<string, string>
---@return string[]
local function report_with_environment(environment)
  child.lua(
    [[
    for _, name in ipairs(...) do
      vim.env[name] = nil
    end
    for name, value in pairs(select(2, ...)) do
      vim.env[name] = value
    end
  ]],
    { TITLE_VARIABLES, environment }
  )
  return health.report(child)
end

T['the tab line']['is said to be Neovim’s own while no aineo tab has drawn one'] = function()
  start_with({ autostart = false })

  local report = report_with_environment({})

  eq(health.section(report, 'Tab line'), {
    "- the tab line is Neovim's own: aineo draws its own when the first aineo tab opens, while 'tabline' is empty: :help |aineo-tabs|",
    TAB_LINE_SHOWN_WHEN_A_TAB_OPENS,
    INDICATOR_READS_THE_TITLE,
    AINEO_HIDES_THE_MULTIPLEXER,
  })
end

T['the tab line']['is said to be aineo’s once the tabs home draws it'] = function()
  start_with({ autostart = false })
  child.lua("require('aineo.tabs').draw_tabline()")

  local report = report_with_environment({})

  eq(health.section(report, 'Tab line'), {
    '- ✅ OK aineo draws the tab line: each tab shows its place and, for an aineo tab, its session’s name',
    TAB_LINE_SHOWN_WHEN_A_TAB_OPENS,
    INDICATOR_READS_THE_TITLE,
    AINEO_HIDES_THE_MULTIPLEXER,
  })
end

T['the tab line']['is said to be the user’s own when they set one'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), {
      '--cmd',
      'set tabline=%t',
    })
  )

  local report = report_with_environment({})

  eq(health.section(report, 'Tab line'), {
    "- the tab line is yours ('tabline' is %t): aineo draws none; require('aineo').tab_title({n}) gives the title it would draw for a tab page: :help |aineo-tabs|",
    TAB_LINE_SHOWN_WHEN_A_TAB_OPENS,
    INDICATOR_READS_THE_TITLE,
    AINEO_HIDES_THE_MULTIPLEXER,
  })
end

T['the tab line']["says the tab line shows with one tab page, with 'showtabline' as it is, once an aineo tab has opened"] = function()
  start_with({ autostart = false })
  child.lua("require('aineo.tabs').show_tabline_once()")

  local report = report_with_environment({})

  eq(
    health.section(report, 'Tab line')[2],
    "- aineo shows the tab line with one tab page: 'showtabline' is 2 (tabs.always_show): :help |aineo-tabs|"
  )
end

T['the tab line']["says what 'showtabline' is now, and that aineo sets it once, when the user changed it after the first open"] = function()
  start_with({ autostart = false })
  child.lua("require('aineo.tabs').show_tabline_once() vim.o.showtabline = 0")

  local report = report_with_environment({})

  eq(
    health.section(report, 'Tab line')[2],
    "- 'showtabline' is 0 now; aineo sets it to 2 once, when the first aineo tab opens, and leaves it after (tabs.always_show): :help |aineo-tabs|"
  )
end

T['the tab line']["says aineo leaves 'showtabline' as the user has it when tabs.always_show is false"] = function()
  start_with({ autostart = false, tabs = { always_show = false } })

  local report = report_with_environment({})

  eq(
    health.section(report, 'Tab line')[2],
    "- aineo leaves 'showtabline' as you have it (tabs.always_show is false): it is 1 now: :help |aineo-tabs|"
  )
end

T['the tab line']['says nothing of tabs.always_show while the configuration is wrong'] = function()
  start_with({ autostart = false, tabs = { always_show = 'yes' } })

  local report = report_with_environment({})

  eq(health.section(report, 'Tab line')[2], INDICATOR_READS_THE_TITLE)
end

T['the tab line']['warns, naming the variable, that no tab shows activity when'] =
  MiniTest.new_set({
    parametrize = {
      {
        'CLAUDE_CODE_DISABLE_TERMINAL_TITLE',
        'Claude Code sets no terminal title',
        'unset CLAUDE_CODE_DISABLE_TERMINAL_TITLE before starting Neovim',

        '',
      },
      {
        'TMUX',
        'Claude Code keeps its terminal title still under a terminal multiplexer',
        'set claude.hide_multiplexer to true, or start Neovim outside tmux, screen and zellij',
        ', and a copy made in the Claude window prints 52;c;<base64> there',
      },
      {
        'STY',
        'Claude Code keeps its terminal title still under a terminal multiplexer',
        'set claude.hide_multiplexer to true, or start Neovim outside tmux, screen and zellij',

        '',
      },
      {
        'ZELLIJ',
        'Claude Code keeps its terminal title still under a terminal multiplexer',
        'set claude.hide_multiplexer to true, or start Neovim outside tmux, screen and zellij',

        '',
      },
    },
  })

T['the tab line']['warns, naming the variable, that no tab shows activity when']['is set'] = function(
  variable,
  reason,
  advice,
  also
)
  start_with({ autostart = false, claude = { hide_multiplexer = false } })

  local report = report_with_environment({ [variable] = '1' })

  eq(health.section(report, 'Tab line')[3], INDICATOR_READS_THE_TITLE)
  eq(
    health.section(report, 'Tab line')[4],
    ('- ⚠️ WARNING %s is set: %s, so no tab shows activity%s'):format(variable, reason, also)
  )
  eq(
    health.advice(report, 'Tab line'),
    { ('%s for the tabs to show activity: :help |aineo-limits|'):format(advice) }
  )
end

T['the tab line']['warns of no multiplexer variable, and says aineo hides them, while claude.hide_multiplexer is true'] = function()
  start_with({ autostart = false })

  local report = report_with_environment({ TMUX = '1', STY = '1', ZELLIJ = '1' })

  eq(health.advice(report, 'Tab line'), {})
  eq(health.section(report, 'Tab line')[4], AINEO_HIDES_THE_MULTIPLEXER)
end

T['the tab line']['still warns of CLAUDE_CODE_DISABLE_TERMINAL_TITLE while claude.hide_multiplexer is true'] = function()
  start_with({ autostart = false })

  local report = report_with_environment({ CLAUDE_CODE_DISABLE_TERMINAL_TITLE = '1' })

  eq(#health.advice(report, 'Tab line'), 1)
end

T['the tab line']['does not say aineo hides the multiplexer while claude.hide_multiplexer is false'] = function()
  start_with({ autostart = false, claude = { hide_multiplexer = false } })

  local report = report_with_environment({})

  eq(health.section(report, 'Tab line'), {
    "- the tab line is Neovim's own: aineo draws its own when the first aineo tab opens, while 'tabline' is empty: :help |aineo-tabs|",
    TAB_LINE_SHOWN_WHEN_A_TAB_OPENS,
    INDICATOR_READS_THE_TITLE,
  })
end

T['the tab line']['warns that no tab shows activity when CLAUDE_CODE_DISABLE_TERMINAL_TITLE is'] =
  MiniTest.new_set({
    parametrize = { { '1' }, { 'true' }, { 'yes' }, { 'on' }, { 'TRUE' }, { ' On ' } },
  })

T['the tab line']['warns that no tab shows activity when CLAUDE_CODE_DISABLE_TERMINAL_TITLE is']['set to'] = function(
  value
)
  start_with({ autostart = false })

  local report = report_with_environment({ CLAUDE_CODE_DISABLE_TERMINAL_TITLE = value })

  eq(#health.advice(report, 'Tab line'), 1)
end

T['the tab line']['does not warn about activity when'] = MiniTest.new_set({
  parametrize = {
    { 'CLAUDE_CODE_DISABLE_TERMINAL_TITLE', '0' },
    { 'CLAUDE_CODE_DISABLE_TERMINAL_TITLE', 'false' },
    { 'CLAUDE_CODE_DISABLE_TERMINAL_TITLE', 'no' },
    { 'CLAUDE_CODE_DISABLE_TERMINAL_TITLE', '2' },
    { 'TMUX', ' ' },
    { 'STY', '  ' },
    { 'ZELLIJ', ' ' },
  },
})

T['the tab line']['does not warn about activity when']['a variable Claude Code does not act on is set'] = function(
  variable,
  value
)
  start_with({ autostart = false, claude = { hide_multiplexer = false } })

  local report = report_with_environment({ [variable] = value })

  eq(health.advice(report, 'Tab line'), {})
end

T['the tab line']['does not warn about activity when none of the variables is set'] = function()
  start_with({ autostart = false })

  local report = report_with_environment({})

  eq(health.advice(report, 'Tab line'), {})
end

T['the file finder'] = MiniTest.new_set()

T['the file finder']['says which picker auto takes, the first installed'] = function()
  start_with({ autostart = false })
  find_pickers.install(child, { 'fzf-lua', 'telescope' })

  local report = health.report(child)

  eq(
    health.section(report, 'Find a file'),
    { '- ✅ OK the file finder uses fzf-lua (find.picker is auto)' }
  )
end

T['the file finder']['says which picker is forced, when it is installed'] = function()
  start_with({ autostart = false, find = { picker = 'telescope' } })
  find_pickers.install(child, find_pickers.NAMES)

  local report = health.report(child)

  eq(
    health.section(report, 'Find a file'),
    { '- ✅ OK the file finder uses telescope (find.picker is telescope)' }
  )
end

T['the file finder']['says it lists the files itself when auto finds no picker installed'] = function()
  start_with({ autostart = false })
  find_pickers.install(child, {})

  local report = health.report(child)

  eq(health.section(report, 'Find a file'), {
    '- the file finder lists the files through vim.ui.select: none of snacks, fzf-lua, telescope or mini.pick is installed (find.picker is auto): :help |aineo-find|',
  })
end

T['the file finder']['warns when the picker forced is not installed, though another is'] = function()
  start_with({ autostart = false, find = { picker = 'snacks' } })
  find_pickers.install(child, { 'telescope' })

  local report = health.report(child)

  eq(health.section(report, 'Find a file'), {
    '- ⚠️ WARNING find.picker is snacks, which is not installed: the file finder lists the files through vim.ui.select',
  })
  eq(
    health.advice(report, 'Find a file'),
    { "Install it, or set find.picker to 'auto': :help |aineo-config-find.picker|" }
  )
end

T['the file finder']['counts a snacks without a picker module as not installed, and the check goes on to its last section'] = function()
  start_with({ autostart = false })
  find_pickers.install(child, { 'snacks-without-picker' })

  local report = health.report(child)

  eq(health.section(report, 'Find a file'), {
    '- the file finder lists the files through vim.ui.select: none of snacks, fzf-lua, telescope or mini.pick is installed (find.picker is auto): :help |aineo-find|',
  })
  eq(#health.section(report, 'Limits'), 1)
end

T['the file finder']['says nothing while the configuration is wrong'] = function()
  start_with({ autostart = false, find = { picker = 'ctrlp' } })

  local report = health.report(child)

  eq(health.section(report, 'Find a file'), {})
end

T['explaining code'] = MiniTest.new_set()

T['explaining code']['says what Claude Code explains with, and what it may use'] = function()
  start_with({ autostart = false, explain = { model = 'opus', timeout_ms = 90000 } })

  local report = health.report(child)

  eq(health.section(report, 'Explain code'), {
    '- \\v and \\V start a Claude Code of their own for each request, with the program of claude.cmd (the words before its first flag, none of its flags), and end it with the answer: model opus (explain.model), stopped after 90 s (explain.timeout_ms): :help |aineo-explain|',
    "- \\v hands it the code alone, with no tool; \\V lets it read the project with Read, Grep and Glob, without asking; it gets no other tool, no MCP server and no settings of aineo, loads your own settings but never the project's (--setting-sources user), and asks no permission",
    "- \\vi and \\VI ask the same Claude Code for potential issues instead of explanations, \\vi with the code alone and \\VI with the read-only tools; \\v waits for 'timeoutlen' for a following i or m, and \\V for a following I",
    '- \\vm marks the issues on a line (on each selected line in Visual mode), and \\s then sends the marked issues to the session\'s Claude Code in place of Input, after "Some issues were found in this code, can you check and propose a fix if the issue holds:" (explain.issues_prompt): :help |aineo-explain-mark|',
    '- ]v and [v jump to the next and the previous explanation or issue of a buffer that shows any, in Normal, Visual and Operator-pending mode, and are never mapped over a key of yours: :help |aineo-explain-jump|',
  })
end

T['explaining code']['says nothing while the configuration is wrong'] = function()
  start_with({ autostart = false, explain = { model = '' } })

  local report = health.report(child)

  eq(health.section(report, 'Explain code'), {})
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
    '- no record of the autostart: vim.g.aineo_startup holds something aineo did not write',
  })
end

T['the autostart']['has no record when vim.g.aineo_startup holds a reason aineo does not write'] = function()
  start_with({ autostart = false })
  child.lua([[vim.g.aineo_startup = { reason = 'bogus' }]])

  local report = health.report(child)

  eq(health.section(report, 'Autostart'), {
    '- no record of the autostart: vim.g.aineo_startup holds something aineo did not write',
  })
end

T['the autostart']['reports a failed open without its error when the error is not text'] = function()
  start_with({ autostart = false })
  child.lua([[vim.g.aineo_startup = { reason = 'open-failed', failure = { 'x' } }]])

  local report = health.report(child)

  eq(health.section(report, 'Autostart'), {
    '- ⚠️ WARNING the autostart tried to open the layout and failed',
  })
  eq(#health.section(report, 'Limits'), 1)
end

--- The line the Autostart section shows while aineo's `VimEnter` handler
--- has not run.
local VIM_ENTER_PENDING =
  "- the autostart has not decided: aineo's VimEnter handler, which decides it, has not run — the editor is still starting, or a VimEnter autocommand before it threw an exception"

T['the autostart']['has not decided yet when the check runs from -c'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({ autostart = false }), { '-c', health.CAPTURE })
  )

  local report = child.lua_get('vim.g.health_report')

  eq(health.section(report, 'Autostart'), { VIM_ENTER_PENDING })
end

T['the autostart']['has not decided yet when a VimEnter autocommand before aineo runs the check'] = function()
  children.restart(
    child,
    vim.list_extend(
      settings_arguments({ autostart = false }),
      { '--cmd', 'autocmd VimEnter * ++once ' .. health.CAPTURE }
    )
  )

  local report = child.lua_get('vim.g.health_report')

  eq(health.section(report, 'Autostart'), { VIM_ENTER_PENDING })
  eq(health.section(report, 'Prefix mappings')[1], health.VIM_ENTER_PENDING_KEYS)
end

T['the autostart']['has not decided once the editor started, when a VimEnter autocommand before aineo threw'] = function()
  children.restart(
    child,
    vim.list_extend(
      settings_arguments({ autostart = false }),
      { '--cmd', "autocmd VimEnter * throw 'an earlier VimEnter handler threw'" }
    )
  )

  local report = health.report(child)

  eq(child.lua_get('vim.v.vim_did_enter'), 1)
  eq(health.section(report, 'Autostart'), { VIM_ENTER_PENDING })
  eq(health.section(report, 'Prefix mappings')[1], health.VIM_ENTER_PENDING_KEYS)
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

T['the autostart']['did not run because aineo was loaded after startup, when checked in the same tick'] = function()
  local report = check_in_the_tick_aineo_is_loaded_late()

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
    "- the autostart did not run: this Neovim runs inside aineo's own Claude terminal or shell terminal ($AINEO_CHILD is set)",
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

--- A file to start an editor with.
local FILE_ARGUMENT = vim.fs.joinpath(vim.uv.cwd(), '.tests', 'fixtures', 'health-file.txt')

--- Interactive starts where several reasons hold, each dropping the first
--- reason of the one before, with the line the health check reports.
local STARTS_WITH_SEVERAL_REASONS = {
  {
    'file-stdin-task-child',
    {
      args = { FILE_ARGUMENT, '-c', 'let g:health_command = 1' },
      stdin = 'piped text',
      environment = { AINEO_ENTRY_AINEO_CHILD = '1' },
    },
    '- the autostart did not run: Neovim was given a file to edit',
  },
  {
    'stdin-task-child',
    {
      args = { '-c', 'let g:health_command = 1' },
      stdin = 'piped text',
      environment = { AINEO_ENTRY_AINEO_CHILD = '1' },
    },
    '- the autostart did not run: Neovim read its standard input',
  },
  {
    'task-child',
    {
      args = { '-c', 'let g:health_command = 1' },
      environment = { AINEO_ENTRY_AINEO_CHILD = '1' },
    },
    '- the autostart did not run: Neovim was given something to do besides edit (-c, -S, -e, -s, -E or a + command)',
  },
}

T['the autostart']['names the first reason when several hold'] = MiniTest.new_set({
  parametrize = STARTS_WITH_SEVERAL_REASONS,
})

T['the autostart']['names the first reason when several hold']['in its report'] = function(
  name,
  start,
  line
)
  local editor = start_editor(name, start)

  local report = health.editor_report(editor)

  eq(health.section(report, 'Autostart'), { line })
end

T['the autostart']['names no user interface before a file and a startup task'] = function()
  children.restart(
    child,
    vim.list_extend(settings_arguments({}), { FILE_ARGUMENT, '-c', 'let g:health_command = 1' })
  )

  local report = health.report(child)

  eq(health.section(report, 'Autostart'), {
    '- the autostart did not run: no user interface was attached (a headless start)',
  })
end

T['the autostart']['has decided to open, when checked before the layout opens'] = function()
  local editor = start_editor('opening', {
    args = {
      '--cmd',
      'set runtimepath+='
        .. vim.fs.joinpath(vim.uv.cwd(), 'tests', 'fixtures', 'health', 'check_at_vim_enter'),
    },
  })

  local report = entry_editor.get(editor, 'vim.g.health_report')

  eq(health.section(report, 'Autostart'), {
    '- the autostart decided to open the layout, which opens once startup has settled',
  })
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
    "- aineo stops Claude Code, and the processes of the run pane, from its own VimLeavePre handlers when Neovim quits; a VimLeavePre handler registered before them that raises an error makes Neovim skip aineo's when the error is a Vimscript throw, or a Lua error and the quit runs from Lua, as aineo's \\Q in the last tab does, but not when the quit is typed, and a Claude Code that hangs then outlives the editor; aineo cannot detect this: :help |aineo-limits|",
  })
end

return T
