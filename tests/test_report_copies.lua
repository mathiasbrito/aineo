local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local report_editor = dofile('tests/helpers/report_editor.lua')

local eq = MiniTest.expect.equality

--- The working directory the cases' editors are in: any path names one, and
--- nothing is written there.
local WORKING_DIRECTORY = '/projects/alpha'

--- The functions a report home offers as fields, as the module's own do.
local REPORT_FUNCTIONS = {
  { 'set_report_environment' },
  { 'report_buffer' },
  { 'receive_report' },
  { 'follow_report_session' },
  { 'hand_over_report_session' },
}

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The file that keeps the records of the reports kept for the Claude
--- session `session` under the state directory `state`.
---
---@param state string
---@param session string
---@return string
local function session_records_file(state, session)
  return vim.fs.joinpath(
    state,
    'aineo',
    'reports',
    'session-' .. vim.fn.sha256(session) .. '.jsonl'
  )
end

--- Writes `file`, a records file, holding one record received at 09:00 for
--- each of `summaries`.
---
---@param file string
---@param summaries string[]
local function plant_records(file, summaries)
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  vim.fn.writefile(
    vim.tbl_map(function(summary)
      return vim.json.encode({
        time = '2026-10-07T09:00:00',
        report = { task = 'Task', status = 'done', summary = summary },
      })
    end, summaries),
    file
  )
end

--- The summaries of the records `file` holds, oldest first, or nil when
--- there is no such file.
---
---@param file string
---@return string[]|nil
local function summaries_in(file)
  if not vim.uv.fs_stat(file) then
    return nil
  end
  return vim.tbl_map(function(line)
    return vim.json.decode(line).report.summary
  end, vim.fn.readfile(file))
end

--- How long a case waits for the child to reach a state.
local PATIENCE_MS = 5000

--- Restarts the child with the module's report home, its clock at 10:00,
--- the state directory `state` and `WORKING_DIRECTORY`.
---
---@param state string
local function start_editor(state)
  report_editor.start(child, {
    times = { '2026-10-07T10:00:00' },
    state_directory = state,
    working_directory = WORKING_DIRECTORY,
  })
end

--- Makes, in the child, a report home of its own, held as `_G.second`, with
--- its clock at 11:00, the state directory `state` and `WORKING_DIRECTORY`.
---
---@param state string
local function make_second_home(state)
  child.lua(
    [[
      local state, working_directory = ...
      _G.second = require('aineo.report').new()
      _G.second.set_report_environment({
        clock = function()
          return '2026-10-07T11:00:00'
        end,
        state_directory = state,
        working_directory = working_directory,
      })
    ]],
    { state, WORKING_DIRECTORY }
  )
end

--- The lines of the second home's Report (`make_second_home()`).
---
---@return string[]
local function second_lines()
  return child.lua_get([[vim.api.nvim_buf_get_lines(_G.second.report_buffer(), 0, -1, false)]])
end

--- A report whose summary is `summary`, as the report tool's arguments.
---
---@param summary string
---@return table
local function report_of(summary)
  return { task = 'Task', status = 'done', summary = summary }
end

T['a report home of its own'] = MiniTest.new_set()

T['a report home of its own']['offers the per-view functions as fields'] = MiniTest.new_set({
  parametrize = REPORT_FUNCTIONS,
})

T['a report home of its own']['offers the per-view functions as fields']['of'] = function(name)
  children.restart(child)

  local kinds = child.lua_get(
    [[(function(name)
      local first, second = require('aineo.report').new(), require('aineo.report').new()
      return {
        first = type(first[name]),
        second = type(second[name]),
        shared = first[name] == second[name] or first[name] == require('aineo.report')[name],
      }
    end)(...)]],
    { name }
  )

  eq(kinds, { first = 'function', second = 'function', shared = false })
end

T['a report home of its own']["has a Report under a name no other buffer holds, and making it leaves the module's Report alone"] = function()
  local state = fixture.directory('report-copies-names')
  start_editor(state)
  local first = child.lua_get([[require('aineo.report').report_buffer()]])
  report_editor.receive(child, report_of('Kept in the first'))

  local made = child.lua_get(
    [[(function(first, state, working_directory)
      local made, second = pcall(function()
        local second = require('aineo.report').new()
        second.set_report_environment({
          clock = function()
            return '2026-10-07T11:00:00'
          end,
          state_directory = state,
          working_directory = working_directory,
        })
        return second.report_buffer()
      end)
      local first_valid = vim.api.nvim_buf_is_valid(first)
      return {
        made = made,
        first_valid = first_valid,
        first_name = first_valid and vim.api.nvim_buf_get_name(first) or '',
        first_lines = first_valid and vim.api.nvim_buf_get_lines(first, 0, -1, false) or {},
        second_has_other_name = made
          and vim.api.nvim_buf_get_name(second) ~= ''
          and vim.api.nvim_buf_get_name(second) ~= 'aineo://report',
      }
    end)(...)]],
    { first, state, WORKING_DIRECTORY }
  )

  eq(made, {
    made = true,
    first_valid = true,
    first_name = 'aineo://report',
    first_lines = { '10:00 [done] Task — Kept in the first' },
    second_has_other_name = true,
  })
end

T['a report home of its own']["makes the handlers of its Report apart from the module's: the module's Report still shows its records again after :edit"] = function()
  local state = fixture.directory('report-copies-handlers')
  plant_records(session_records_file(state, 'session-a'), { 'Alpha' })
  start_editor(state)
  child.lua("require('aineo.report').follow_report_session(...)", { 'session-a' })
  local first = child.lua_get([[require('aineo.report').report_buffer()]])
  make_second_home(state)
  second_lines()

  child.cmd(('buffer %d | edit'):format(first))

  eq(report_editor.lines(child), { '09:00 [done] Task — Alpha' })
end

T['a report home of its own']['keeps its names when the module is loaded again before its Report exists'] = function()
  local state = fixture.directory('report-copies-reload')
  children.restart(child)

  local names = child.lua_get(
    [[(function(state, working_directory)
      local environment = {
        clock = function()
          return '2026-10-07T11:00:00'
        end,
        state_directory = state,
        working_directory = working_directory,
      }
      local old = require('aineo.report').new()
      package.loaded['aineo.report'] = nil
      local new = require('aineo.report').new()
      old.set_report_environment(environment)
      new.set_report_environment(environment)
      local old_buffer, new_buffer = old.report_buffer(), new.report_buffer()
      return {
        old_valid = vim.api.nvim_buf_is_valid(old_buffer),
        old_name = vim.api.nvim_buf_is_valid(old_buffer) and vim.api.nvim_buf_get_name(old_buffer) or '',
        new_name = vim.api.nvim_buf_get_name(new_buffer),
      }
    end)(...)]],
    { state, WORKING_DIRECTORY }
  )

  eq(names, { old_valid = true, old_name = 'aineo://report-2', new_name = 'aineo://report-3' })
end

T['two report homes'] = MiniTest.new_set()

T['two report homes']['each show the records of the session they follow, and keep the reports they receive there'] = function()
  local state = fixture.directory('report-copies-sessions')
  plant_records(session_records_file(state, 'session-a'), { 'Alpha' })
  plant_records(session_records_file(state, 'session-b'), { 'Beta' })
  start_editor(state)
  make_second_home(state)
  child.lua("require('aineo.report').follow_report_session(...)", { 'session-a' })
  child.lua('_G.second.follow_report_session(...)', { 'session-b' })

  report_editor.receive(child, report_of('For alpha'))
  child.lua('_G.second.receive_report(...)', { report_of('For beta') })

  eq({
    first_lines = report_editor.lines(child),
    second_lines = second_lines(),
    first_kept = summaries_in(session_records_file(state, 'session-a')),
    second_kept = summaries_in(session_records_file(state, 'session-b')),
  }, {
    first_lines = { '09:00 [done] Task — Alpha', '10:00 [done] Task — For alpha' },
    second_lines = { '09:00 [done] Task — Beta', '11:00 [done] Task — For beta' },
    first_kept = { 'Alpha', 'For alpha' },
    second_kept = { 'Beta', 'For beta' },
  })
end

--- The expression, run in the child, that counts the autocommands waiting
--- for its `SafeState`.
local RETRIES = "#vim.api.nvim_get_autocmds({ event = 'SafeState' })"

--- Maps `X`, in the child's Normal mode, to an expression that waits for a
--- key, holding textlock until it is pressed, and presses it; waits, at
--- most `PATIENCE_MS`, until it holds.
local function begin_hold()
  child.lua([[
    vim.keymap.set('n', 'X', function()
      _G.holding = true
      vim.fn.getcharstr()
      _G.holding = false
      return ''
    end, { expr = true })
  ]])
  child.api.nvim_input('X')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.holding == true')
  end, 10)
end

--- Ends the child's hold (`begin_hold()`) and waits, at most `PATIENCE_MS`,
--- until it has ended.
local function end_hold()
  child.api.nvim_input('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.holding == false')
  end, 10)
end

T['two report homes']["keep the retries of their swaps apart: clearing the module's group leaves the other home's retry to land"] = function()
  local state = fixture.directory('report-copies-retries')
  for session, summary in pairs({ a = 'Alpha', b = 'Beta', c = 'Gamma', d = 'Delta' }) do
    plant_records(session_records_file(state, 'session-' .. session), { summary })
  end
  start_editor(state)
  make_second_home(state)
  child.lua("require('aineo.report').follow_report_session(...)", { 'session-a' })
  child.lua('_G.second.follow_report_session(...)', { 'session-c' })
  report_editor.lines(child)
  second_lines()
  begin_hold()
  child.lua("require('aineo.report').follow_report_session(...)", { 'session-b' })
  child.lua('_G.second.follow_report_session(...)', { 'session-d' })
  local waiting = child.lua_get(RETRIES)

  child.cmd('autocmd! aineo.report')
  end_hold()
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)

  eq(
    { waiting = waiting, first_lines = report_editor.lines(child), second_lines = second_lines() },
    {
      waiting = 2,
      first_lines = { '09:00 [done] Task — Alpha' },
      second_lines = { '09:00 [done] Task — Delta' },
    }
  )
end

--- The file that keeps the records of the reports received in
--- `WORKING_DIRECTORY` under the state directory `state`.
---
---@param state string
---@return string
local function directory_records_file(state)
  return vim.fs.joinpath(state, 'aineo', 'reports', vim.fn.sha256(WORKING_DIRECTORY) .. '.jsonl')
end

--- The environment, as a Lua table constructor run in the child, that gives
--- a home the state directory `state` and `WORKING_DIRECTORY`.
---
---@param state string
---@return string
local function environment_in(state)
  return ([[{
    clock = function()
      return '2026-10-07T12:00:00'
    end,
    state_directory = %q,
    working_directory = %q,
  }]]):format(state, WORKING_DIRECTORY)
end

T['two report homes']["hold a claim apart: a home told a claimed session leaves the directory's records whatever the other is told"] = function()
  local state = fixture.directory('report-copies-claims')
  plant_records(directory_records_file(state), { 'Directory' })
  children.restart(child)
  child.lua(([[
    local first = require('aineo.report')
    local second = first.new()
    first.follow_report_session('session-a', { claim = true })
    second.follow_report_session('session-b')
    first.set_report_environment(%s)
  ]]):format(environment_in(state)))

  eq({
    directory = summaries_in(directory_records_file(state)),
    claimed = summaries_in(session_records_file(state, 'session-a')),
  }, { directory = { 'Directory' }, claimed = nil })
end

T['two report homes']['each move what they kept before their first follow to the first session they follow'] = function()
  local state = fixture.directory('report-copies-directory')
  plant_records(directory_records_file(state), { 'Directory' })
  start_editor(state)
  make_second_home(state)
  child.lua('_G.second.receive_report(...)', { report_of('Kept by the second') })
  child.lua("require('aineo.report').follow_report_session(...)", { 'session-a' })
  plant_records(directory_records_file(state), { 'Directory again' })

  child.lua('_G.second.follow_report_session(...)', { 'session-b' })

  eq({
    first = summaries_in(session_records_file(state, 'session-a')),
    second = summaries_in(session_records_file(state, 'session-b')),
    directory = summaries_in(directory_records_file(state)),
  }, {
    first = { 'Directory' },
    second = { 'Kept by the second' },
    directory = { 'Directory again' },
  })
end

T['two report homes']['hold the hand-overs told before their environment apart'] = function()
  local state = fixture.directory('report-copies-hand-overs')
  plant_records(session_records_file(state, 'session-x'), { 'Held' })
  children.restart(child)
  child.lua(([[
    local first = require('aineo.report')
    local second = first.new()
    first.hand_over_report_session('session-x', 'session-y')
    second.set_report_environment(%s)
  ]]):format(environment_in(state)))

  eq({
    handed_from = summaries_in(session_records_file(state, 'session-x')),
    handed_to = summaries_in(session_records_file(state, 'session-y')),
  }, { handed_from = { 'Held' }, handed_to = nil })
end

--- Keeps in the child the message of every warning it gives, in
--- `_G.warnings`, rather than showing it.
local KEEP_WARNINGS = [[
  _G.warnings = {}
  vim.notify = function(message, level)
    if level == vim.log.levels.WARN then
      table.insert(_G.warnings, message)
    end
  end
]]

--- Waits, at most `PATIENCE_MS`, until the child has given `count` warnings,
--- and returns them.
---
---@param count integer
---@return string[]
local function warnings_given(count)
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('#_G.warnings') >= count
  end, 10)
  return child.lua_get('_G.warnings')
end

--- Offers the child's module a report of the session `session`, with
--- `options`, as the report server does, and returns what it answers.
---
---@param summary string
---@param session string
---@param options? table
---@return boolean|string taken
local function offer(summary, session, options)
  return child.lua_get(
    "(function(...) return require('aineo.report').receive_session_report(...) end)(...)",
    { report_of(summary), session, options or {} }
  )
end

--- Offers the child's module a report of the session `session` as `offer()`
--- does, and returns whether it raised, and what it answered when it did not.
---
---@param summary string
---@param session string
---@return { raised: boolean, taken: boolean? }
local function try_offer(summary, session)
  return child.lua_get(
    [[(function(...)
      local offered, taken = pcall(require('aineo.report').receive_session_report, ...)
      return { raised = not offered, taken = taken }
    end)(...)]],
    { report_of(summary), session, {} }
  )
end

--- Gives the child's module a router that chooses the second home
--- (`make_second_home()`) and keeps what it was asked in `_G.asked`.
local function route_to_second_home()
  child.lua([[
    _G.asked = {}
    require('aineo.report').set_report_router(function(session_id, options)
      table.insert(_G.asked, { session_id = session_id, options = options })
      return _G.second
    end)
  ]])
end

T['a router for received reports'] = MiniTest.new_set()

T['a router for received reports']["hands an offer at the start to the home it chooses before it follows, which keeps it with its own session and not with the module's"] = function()
  local state = fixture.directory('report-copies-router-at-start')
  start_editor(state)
  make_second_home(state)
  route_to_second_home()

  local taken = offer('B at start', 'session-b', { at_start = true, start_token = 'tab-2' })
  local kept_at_once = summaries_in(session_records_file(state, 'session-b'))
  child.lua("require('aineo.report').follow_report_session(...)", { 'session-a' })
  child.lua('_G.second.follow_report_session(...)', { 'session-b' })

  eq({
    taken = taken,
    kept_at_once = kept_at_once,
    first_lines = report_editor.lines(child),
    second_lines = second_lines(),
    first_kept = summaries_in(session_records_file(state, 'session-a')),
    second_kept = summaries_in(session_records_file(state, 'session-b')),
    directory = summaries_in(directory_records_file(state)),
  }, {
    taken = true,
    kept_at_once = { 'B at start' },
    first_lines = { '' },
    second_lines = { '11:00 [done] Task — B at start' },
    first_kept = nil,
    second_kept = { 'B at start' },
    directory = nil,
  })
end

T['a router for received reports']["leaves the working directory's records to the module: a home that follows only a claimed session does not keep a report there"] = function()
  local state = fixture.directory('report-copies-router-keep-with-directory')
  start_editor(state)
  make_second_home(state)
  child.lua('_G.second.follow_report_session(..., { claim = true })', { 'session-c' })
  route_to_second_home()

  local taken = offer('B kept', 'session-b', { at_start = true, keep_with_directory = true })

  eq({ taken = taken, directory = summaries_in(directory_records_file(state)) }, {
    taken = false,
    directory = nil,
  })
end

T['a router for received reports']['hands the report to the home it chooses, and shows it there only'] = function()
  local state = fixture.directory('report-copies-router')
  start_editor(state)
  make_second_home(state)
  child.lua("require('aineo.report').follow_report_session(...)", { 'session-a' })
  child.lua('_G.second.follow_report_session(...)', { 'session-b' })
  route_to_second_home()

  local taken = offer('For beta', 'session-b')

  eq({
    taken = taken,
    first_lines = report_editor.lines(child),
    second_lines = second_lines(),
    first_kept = summaries_in(session_records_file(state, 'session-a')),
    second_kept = summaries_in(session_records_file(state, 'session-b')),
  }, {
    taken = true,
    first_lines = { '' },
    second_lines = { '11:00 [done] Task — For beta' },
    first_kept = nil,
    second_kept = { 'For beta' },
  })
end

T['a router for received reports']['leaves the rules of the home it chooses to decide: one following another session does not take it'] = function()
  local state = fixture.directory('report-copies-router-rules')
  start_editor(state)
  make_second_home(state)
  child.lua('_G.second.follow_report_session(...)', { 'session-b' })
  route_to_second_home()

  local taken = offer('For alpha', 'session-a')

  eq({ taken = taken, second_lines = second_lines() }, { taken = false, second_lines = { '' } })
end

T['a router for received reports']['answers false, taking nothing, when it chooses no home'] = function()
  local state = fixture.directory('report-copies-router-none')
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  child.lua("require('aineo.report').follow_report_session(...)", { 'session-a' })
  child.lua("require('aineo.report').set_report_router(function() return nil end)")

  local taken = offer('For alpha', 'session-a')

  eq(
    { taken = taken, lines = report_editor.lines(child), warnings = child.lua_get('_G.warnings') },
    {
      taken = false,
      lines = { '' },
      warnings = {},
    }
  )
end

T['a router for received reports']['leaves the module taking the report when no router is given'] = function()
  local state = fixture.directory('report-copies-router-absent')
  start_editor(state)
  child.lua("require('aineo.report').follow_report_session(...)", { 'session-a' })

  local taken = offer('For alpha', 'session-a')

  eq({ taken = taken, lines = report_editor.lines(child) }, {
    taken = true,
    lines = { '10:00 [done] Task — For alpha' },
  })
end

T['a router for received reports']['goes back to the module taking the report when it is cleared'] = function()
  local state = fixture.directory('report-copies-router-cleared')
  start_editor(state)
  child.lua("require('aineo.report').follow_report_session(...)", { 'session-a' })
  child.lua("require('aineo.report').set_report_router(function() return nil end)")
  child.lua("require('aineo.report').set_report_router(nil)")

  local taken = offer('For alpha', 'session-a')

  eq(taken, true)
end

T['a router for received reports']["is asked the report's session and the offer's options, the start token unchanged"] = function()
  local state = fixture.directory('report-copies-router-asked')
  start_editor(state)
  make_second_home(state)
  route_to_second_home()

  offer('For beta', 'session-b', { at_start = true, start_token = 'token-1' })

  eq(child.lua_get('_G.asked'), {
    { session_id = 'session-b', options = { at_start = true, start_token = 'token-1' } },
  })
end

T['a router for received reports']['is asked with an empty table when the offer gave no options'] = function()
  local state = fixture.directory('report-copies-router-no-options')
  start_editor(state)
  child.lua([[
    require('aineo.report').set_report_router(function(_, options)
      _G.options_given = options
    end)
  ]])

  child.lua("require('aineo.report').receive_session_report(..., 'session-b')", { report_of('X') })

  eq(child.lua_get('_G.options_given'), vim.empty_dict())
end

T['a router for received reports']['gives a home taking the module, which is asked once'] = function()
  local state = fixture.directory('report-copies-router-module')
  start_editor(state)
  child.lua("require('aineo.report').follow_report_session(...)", { 'session-a' })
  child.lua([[
    _G.calls = 0
    require('aineo.report').set_report_router(function()
      _G.calls = _G.calls + 1
      if _G.calls == 1 then
        return require('aineo.report')
      end
    end)
  ]])

  local taken = offer('For alpha', 'session-a')

  eq({ taken = taken, calls = child.lua_get('_G.calls'), lines = report_editor.lines(child) }, {
    taken = true,
    calls = 1,
    lines = { '10:00 [done] Task — For alpha' },
  })
end

T['a router for received reports']['that chooses what only looks like a home takes nothing, answers false and warns the user once'] =
  MiniTest.new_set({
    parametrize = {
      { 'a proxy of the module', "return setmetatable({}, { __index = require('aineo.report') })" },
      {
        'an object that delegates to the module',
        "return { receive_session_report = function(...) return require('aineo.report').receive_session_report(...) end }",
      },
      {
        'a shallow copy of the module',
        "return vim.tbl_extend('force', {}, require('aineo.report'))",
      },
    },
  })

T['a router for received reports']['that chooses what only looks like a home takes nothing, answers false and warns the user once']['of'] = function(
  _,
  choice
)
  local state = fixture.directory('report-copies-router-look-alike')
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  child.lua("require('aineo.report').follow_report_session(...)", { 'session-a' })
  child.lua(("require('aineo.report').set_report_router(function() %s end)"):format(choice))

  local offered = try_offer('For alpha', 'session-a')
  warnings_given(1)

  eq({
    offered = offered,
    lines = report_editor.lines(child),
    warnings = child.lua_get(
      "#vim.tbl_filter(function(message) return vim.startswith(message, 'aineo: the report router chose no report home') end, _G.warnings)"
    ),
    all_warnings = child.lua_get('#_G.warnings'),
  }, {
    offered = { raised = false, taken = false },
    lines = { '' },
    warnings = 1,
    all_warnings = 1,
  })
end

T['a router for received reports']['that raises takes nothing, answers false and warns the user for each report'] = function()
  local state = fixture.directory('report-copies-router-raises')
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  child.lua("require('aineo.report').follow_report_session(...)", { 'session-a' })
  child.lua("require('aineo.report').set_report_router(function() error('no tab for this', 0) end)")

  local offered = { try_offer('For alpha', 'session-a'), try_offer('For alpha', 'session-a') }
  local warnings = warnings_given(2)

  eq({ offered = offered, lines = report_editor.lines(child), warnings = warnings }, {
    offered = { { raised = false, taken = false }, { raised = false, taken = false } },
    lines = { '' },
    warnings = {
      'aineo: the report router failed: no tab for this',
      'aineo: the report router failed: no tab for this',
    },
  })
end

T['a router for received reports']['that chooses what is no home takes nothing, answers false and warns the user once'] = function()
  local state = fixture.directory('report-copies-router-not-a-home')
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  child.lua("require('aineo.report').set_report_router(function() return 7 end)")

  local offered = try_offer('For alpha', 'session-a')
  local warnings = warnings_given(1)

  eq({ offered = offered, warnings = warnings }, {
    offered = { raised = false, taken = false },
    warnings = { 'aineo: the report router chose no report home: 7' },
  })
end

T['a router for received reports']['is refused when it is not a function'] = function()
  children.restart(child)

  local refusal_names_router = child.lua_get([[(function()
    local set, message = pcall(require('aineo.report').set_report_router, 'tab')
    return not set and tostring(message):find('router', 1, true) ~= nil
  end)()]])

  eq(refusal_names_router, true)
end

return T
