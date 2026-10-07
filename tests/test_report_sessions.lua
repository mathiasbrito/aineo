local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local report_editor = dofile('tests/helpers/report_editor.lua')

local eq = MiniTest.expect.equality

--- The working directory the cases' editors are in: any path names one, and
--- nothing is written there.
local WORKING_DIRECTORY = '/projects/alpha'

local child = MiniTest.new_child_neovim()

--- The file that keeps the records of the reports received in
--- `WORKING_DIRECTORY` under the state directory `state`.
---
---@param state string
---@return string
local function directory_records_file(state)
  return vim.fs.joinpath(state, 'aineo', 'reports', vim.fn.sha256(WORKING_DIRECTORY) .. '.jsonl')
end

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

--- A records line holding a report received at 09:00 whose summary is
--- `summary`.
---
---@param summary string
---@return string
local function record_line(summary)
  return vim.json.encode({
    time = '2026-10-07T09:00:00',
    report = { task = 'Task', status = 'done', summary = summary },
  })
end

--- Writes `file`, a records file under the fixtures' directory `state`,
--- holding one record for each of `summaries` (`record_line()`).
---
---@param file string
---@param summaries string[]
local function plant_records(file, summaries)
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  vim.fn.writefile(vim.tbl_map(record_line, summaries), file)
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

--- Restarts the child's report home with its clock at 10:00, the state
--- directory `state` and `WORKING_DIRECTORY`.
---
---@param state string
local function start_editor(state)
  report_editor.start(child, {
    times = { '2026-10-07T10:00:00' },
    state_directory = state,
    working_directory = WORKING_DIRECTORY,
  })
end

--- Gives the child's running report home, as `start_editor()` does without
--- restarting it, its clock at 10:00, the state directory `state` and
--- `WORKING_DIRECTORY`.
---
---@param state string
local function give_environment(state)
  child.lua(
    [[
      local state, working_directory = ...
      require('aineo.report').set_report_environment({
        clock = function()
          return '2026-10-07T10:00:00'
        end,
        state_directory = state,
        working_directory = working_directory,
      })
    ]],
    { state, WORKING_DIRECTORY }
  )
end

--- Tells the child's report home to follow the Claude session `session`.
---
---@param session string
local function follow(session)
  child.lua("require('aineo.report').follow_report_session(...)", { session })
end

--- Hands the child's report home a report whose summary is `summary`.
---
---@param summary string
local function receive(summary)
  report_editor.receive(child, { task = 'Task', status = 'done', summary = summary })
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

--- The expression, run in the child, that counts the warnings it gave that
--- records could not be moved.
local MOVE_WARNINGS = [[#vim.tbl_filter(function(message)
  return message:find('cannot move the report records', 1, true) ~= nil
end, _G.warnings)]]

--- How long a case waits for the child to reach a state.
local PATIENCE_MS = 5000

--- Ways an expression mapping holds textlock while the child's main loop
--- runs, as a set's `parametrize`: the name of the hold, the Lua call that
--- waits, and the keys that end the wait. `SafeState` fires inside
--- `input()`'s wait, and Neovim refuses a change there too.
local TEXTLOCK_HOLDS = {
  { 'an expression mapping waiting for a key', 'vim.fn.getcharstr()', 'q' },
  { 'an expression mapping waiting in input()', "vim.fn.input('> ')", '<CR>' },
}

--- Maps `X`, in the child's Normal mode, to an expression that makes the
--- Lua call `wait`, holding textlock until it returns, and presses it;
--- waits, at most `PATIENCE_MS`, until it holds. `_G.holding` is true while
--- it holds.
---
---@param wait string
local function begin_hold(wait)
  child.lua(([[
    vim.keymap.set('n', 'X', function()
      _G.holding = true
      %s
      _G.holding = false
      return ''
    end, { expr = true })
  ]]):format(wait))
  child.api.nvim_input('X')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.holding == true')
  end, 10)
end

--- Ends the child's hold (`begin_hold()`) with `keys`, and waits, at most
--- `PATIENCE_MS`, until it has ended.
---
---@param keys string
local function end_hold(keys)
  child.api.nvim_input(keys)
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.holding == false')
  end, 10)
end

--- The expression, run in the child, that counts the autocommands waiting
--- for its `SafeState`.
local RETRIES = "#vim.api.nvim_get_autocmds({ event = 'SafeState' })"

local T = MiniTest.new_set({
  hooks = {
    post_once = child.stop,
  },
})

T['following a session'] = MiniTest.new_set()

T['following a session']["shows that session's records and keeps the next report there"] = function()
  local state = fixture.directory('report-sessions-shows')
  plant_records(session_records_file(state, 'session-a'), { 'Kept before' })
  start_editor(state)

  follow('session-a')
  receive('Received now')

  eq({
    lines = report_editor.lines(child),
    kept = summaries_in(session_records_file(state, 'session-a')),
    directory = summaries_in(directory_records_file(state)),
  }, {
    lines = { '09:00 [done] Task — Kept before', '10:00 [done] Task — Received now' },
    kept = { 'Kept before', 'Received now' },
    directory = nil,
  })
end

T['following a session']["replaces the Report's lines with another session's, keeping the next report there only"] = function()
  local state = fixture.directory('report-sessions-another')
  plant_records(session_records_file(state, 'session-a'), { 'Alpha' })
  plant_records(session_records_file(state, 'session-b'), { 'Beta' })
  start_editor(state)
  follow('session-a')
  report_editor.lines(child)

  follow('session-b')
  receive('Received now')

  eq({
    lines = report_editor.lines(child),
    first = summaries_in(session_records_file(state, 'session-a')),
    second = summaries_in(session_records_file(state, 'session-b')),
  }, {
    lines = { '09:00 [done] Task — Beta', '10:00 [done] Task — Received now' },
    first = { 'Alpha' },
    second = { 'Beta', 'Received now' },
  })
end

T['following a session']["already followed leaves the Report's lines and cursor as they were"] = function()
  local state = fixture.directory('report-sessions-same')
  plant_records(session_records_file(state, 'session-a'), { 'First', 'Second', 'Third' })
  start_editor(state)
  follow('session-a')
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])
  child.api.nvim_win_set_cursor(0, { 3, 4 })

  follow('session-a')

  eq({ lines = report_editor.lines(child), cursor = child.api.nvim_win_get_cursor(0) }, {
    lines = {
      '09:00 [done] Task — First',
      '09:00 [done] Task — Second',
      '09:00 [done] Task — Third',
    },
    cursor = { 3, 4 },
  })
end

T['following a session']["shows that session's records in a Report wiped out and made again"] = function()
  local state = fixture.directory('report-sessions-wiped')
  plant_records(session_records_file(state, 'session-b'), { 'Beta' })
  start_editor(state)
  receive('In the directory')
  follow('session-a')
  follow('session-b')
  child.lua([[vim.api.nvim_buf_delete(require('aineo.report').report_buffer(), { force = true })]])

  local lines = report_editor.lines(child)

  eq(lines, { '09:00 [done] Task — Beta' })
end

T['following a session']["shows that session's records when the user edits the Report again"] = function()
  local state = fixture.directory('report-sessions-edit')
  plant_records(session_records_file(state, 'session-a'), { 'Alpha' })
  plant_records(session_records_file(state, 'session-b'), { 'Beta' })
  start_editor(state)
  follow('session-a')
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])
  follow('session-b')

  child.cmd('edit')

  eq(report_editor.lines(child), { '09:00 [done] Task — Beta' })
end

T['following a session']['refuses an id that is not a string, naming it, and keeps the session followed'] =
  MiniTest.new_set({
    parametrize = { { 'nil' }, { '{}' }, { '7' } },
  })

T['following a session']['refuses an id that is not a string, naming it, and keeps the session followed']['as the id'] = function(
  id
)
  local state = fixture.directory('report-sessions-not-an-id')
  start_editor(state)
  follow('session-a')

  local refusal = child.lua_get(([[(function()
    local followed, failure = pcall(require('aineo.report').follow_report_session, %s)
    return { followed = followed, named = tostring(failure):find('session_id', 1, true) ~= nil }
  end)()]]):format(id))
  child.lua(
    "pcall(require('aineo.report').receive_report, ...)",
    { { task = 'Task', status = 'done', summary = 'After the refusal' } }
  )

  eq({
    refusal = refusal,
    session = summaries_in(session_records_file(state, 'session-a')),
    directory = summaries_in(directory_records_file(state)),
  }, {
    refusal = { followed = false, named = true },
    session = { 'After the refusal' },
    directory = nil,
  })
end

T['following a session']['with no records shows an empty Report'] = function()
  local state = fixture.directory('report-sessions-none')
  plant_records(session_records_file(state, 'session-a'), { 'Alpha' })
  start_editor(state)
  follow('session-a')
  local before = report_editor.lines(child)

  follow('session-new')

  eq({ before = before, after = report_editor.lines(child) }, {
    before = { '09:00 [done] Task — Alpha' },
    after = { '' },
  })
end

T['following a session']['back shows the reports another editor kept for that session meanwhile'] = function()
  local state = fixture.directory('report-sessions-other-editor')
  plant_records(session_records_file(state, 'session-a'), { 'Alpha' })
  start_editor(state)
  follow('session-a')
  report_editor.lines(child)
  follow('session-b')
  vim.fn.writefile(
    { record_line('From another editor') },
    session_records_file(state, 'session-a'),
    'a'
  )

  follow('session-a')

  eq(report_editor.lines(child), {
    '09:00 [done] Task — Alpha',
    '09:00 [done] Task — From another editor',
  })
end

T["the working directory's records"] = MiniTest.new_set()

T["the working directory's records"]['become the first session followed'] = function()
  local state = fixture.directory('report-sessions-moved')
  start_editor(state)
  receive('Before any session')

  follow('session-a')

  eq({
    lines = report_editor.lines(child),
    directory = summaries_in(directory_records_file(state)),
    session = summaries_in(session_records_file(state, 'session-a')),
  }, {
    lines = { '10:00 [done] Task — Before any session' },
    directory = nil,
    session = { 'Before any session' },
  })
end

T["the working directory's records"]['are left as they are when the session has records, which are shown'] = function()
  local state = fixture.directory('report-sessions-both')
  plant_records(directory_records_file(state), { 'Directory' })
  plant_records(session_records_file(state, 'session-a'), { 'Session' })
  start_editor(state)
  child.lua(KEEP_WARNINGS)

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    lines = report_editor.lines(child),
    directory = summaries_in(directory_records_file(state)),
    session = summaries_in(session_records_file(state, 'session-a')),
  }, {
    warnings = {},
    lines = { '09:00 [done] Task — Session' },
    directory = { 'Directory' },
    session = { 'Session' },
  })
end

T["the working directory's records"]['planted again are not moved at a later follow'] = function()
  local state = fixture.directory('report-sessions-later')
  start_editor(state)
  follow('session-a')
  plant_records(directory_records_file(state), { 'Written by an older aineo' })

  follow('session-b')

  eq({
    lines = report_editor.lines(child),
    directory = summaries_in(directory_records_file(state)),
    session = summaries_in(session_records_file(state, 'session-b')),
  }, {
    lines = { '' },
    directory = { 'Written by an older aineo' },
    session = nil,
  })
end

T["the working directory's records"]['that cannot be moved are told once, and the session keeps its own'] = function()
  local state = fixture.directory('report-sessions-unmovable')
  plant_records(directory_records_file(state), { 'Directory' })
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  local reports = vim.fs.dirname(directory_records_file(state))
  vim.uv.fs_chmod(reports, tonumber('500', 8))
  MiniTest.finally(function()
    vim.uv.fs_chmod(reports, tonumber('700', 8))
  end)
  follow('session-a')
  vim.uv.fs_chmod(reports, tonumber('700', 8))

  receive('After the move failed')

  eq({
    warnings = child.lua_get('#_G.warnings'),
    moves = child.lua_get(MOVE_WARNINGS),
    lines = report_editor.lines(child),
    directory = summaries_in(directory_records_file(state)),
    session = summaries_in(session_records_file(state, 'session-a')),
  }, {
    warnings = 1,
    moves = 1,
    lines = { '10:00 [done] Task — After the move failed' },
    directory = { 'Directory' },
    session = { 'After the move failed' },
  })
end

--- The Lua that makes the child's next file move — its first call of
--- `vim.uv.fs_rename` or `vim.uv.fs_link` — first run
--- `_G.other_editor(from, to)`, what another editor does at that moment,
--- and then the call itself.
local OTHER_EDITOR_FIRST = [[
  local real = { fs_rename = vim.uv.fs_rename, fs_link = vim.uv.fs_link }
  for name, call in pairs(real) do
    vim.uv[name] = function(from, to)
      vim.uv.fs_rename, vim.uv.fs_link = real.fs_rename, real.fs_link
      _G.other_editor(from, to)
      return call(from, to)
    end
  end
]]

T["the working directory's records"]['whose file cannot be removed once linked are told once'] = function()
  local state = fixture.directory('report-sessions-unremovable')
  plant_records(directory_records_file(state), { 'Directory' })
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  child.lua([[
    vim.uv.fs_unlink = function(path)
      return nil, 'EACCES: permission denied: ' .. path, 'EACCES'
    end
  ]])

  follow('session-a')

  eq({
    moves = child.lua_get(MOVE_WARNINGS),
    session = summaries_in(session_records_file(state, 'session-a')),
  }, { moves = 1, session = { 'Directory' } })
end

T["the working directory's records"]['taken by another editor first are told as no failure'] = function()
  local state = fixture.directory('report-sessions-race-taken')
  plant_records(directory_records_file(state), { 'Directory' })
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  child.lua(
    [[
      local other = ...
      _G.other_editor = function(from)
        assert(vim.uv.fs_rename(from, other))
      end
    ]],
    { session_records_file(state, 'session-other') }
  )
  child.lua(OTHER_EDITOR_FIRST)

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    other = summaries_in(session_records_file(state, 'session-other')),
  }, { warnings = {}, other = { 'Directory' } })
end

T["the working directory's records"]["never replace a session's file another editor made meanwhile"] = function()
  local state = fixture.directory('report-sessions-race-made')
  plant_records(directory_records_file(state), { 'Directory' })
  start_editor(state)
  child.lua(
    [[
      local older_line, other_line = ...
      _G.other_editor = function(from, to)
        assert(vim.uv.fs_rename(from, to))
        vim.fn.writefile({ other_line }, to, 'a')
        vim.fn.writefile({ older_line }, from)
      end
    ]],
    { record_line('Written by an older aineo'), record_line('Kept by the other editor') }
  )
  child.lua(OTHER_EDITOR_FIRST)

  follow('session-a')

  eq({
    session = summaries_in(session_records_file(state, 'session-a')),
    directory = summaries_in(directory_records_file(state)),
  }, {
    session = { 'Directory', 'Kept by the other editor' },
    directory = { 'Written by an older aineo' },
  })
end

T['a session told before the environment'] = MiniTest.new_set()

T['a session told before the environment']["is held: once it comes, the directory's records move to it and the next report is kept there"] = function()
  local state = fixture.directory('report-sessions-held')
  plant_records(directory_records_file(state), { 'Directory' })
  children.restart(child)
  follow('session-a')

  give_environment(state)
  receive('After the environment')

  eq({
    lines = report_editor.lines(child),
    directory = summaries_in(directory_records_file(state)),
    session = summaries_in(session_records_file(state, 'session-a')),
  }, {
    lines = { '09:00 [done] Task — Directory', '10:00 [done] Task — After the environment' },
    directory = nil,
    session = { 'Directory', 'After the environment' },
  })
end

T['a follow refused while textlock holds'] = MiniTest.new_set()

T['a follow refused while textlock holds']["shows the session's records once the hold ends, with no retry left"] =
  MiniTest.new_set({ parametrize = TEXTLOCK_HOLDS })

T['a follow refused while textlock holds']["shows the session's records once the hold ends, with no retry left"]['under'] = function(
  _,
  wait,
  release
)
  local state = fixture.directory('report-sessions-textlock')
  plant_records(session_records_file(state, 'session-a'), { 'Alpha' })
  plant_records(session_records_file(state, 'session-b'), { 'Beta' })
  start_editor(state)
  follow('session-a')
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])
  begin_hold(wait)

  local raised_nothing =
    child.lua_get("(pcall(require('aineo.report').follow_report_session, ...))", { 'session-b' })
  local meanwhile = { lines = report_editor.lines(child), retries = child.lua_get(RETRIES) }
  end_hold(release)

  vim.wait(PATIENCE_MS, function()
    return vim.deep_equal(report_editor.lines(child), { '09:00 [done] Task — Beta' })
  end, 10)
  eq({
    raised_nothing = raised_nothing,
    meanwhile = meanwhile,
    lines = report_editor.lines(child),
    retries = child.lua_get(RETRIES),
  }, {
    raised_nothing = true,
    meanwhile = { lines = { '09:00 [done] Task — Alpha' }, retries = 1 },
    lines = { '09:00 [done] Task — Beta' },
    retries = 0,
  })
end

T['a follow refused while textlock holds']['keeps a report arriving meanwhile in the new session'] = function()
  local state = fixture.directory('report-sessions-textlock-report')
  plant_records(session_records_file(state, 'session-a'), { 'Alpha' })
  plant_records(session_records_file(state, 'session-b'), { 'Beta' })
  start_editor(state)
  follow('session-a')
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])
  begin_hold('vim.fn.getcharstr()')
  follow('session-b')
  local waiting = child.lua_get(RETRIES)

  child.lua(
    "pcall(require('aineo.report').receive_report, ...)",
    { { task = 'Task', status = 'done', summary = 'Meanwhile' } }
  )
  end_hold('q')

  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)
  eq({
    waiting = waiting,
    lines = report_editor.lines(child),
    first = summaries_in(session_records_file(state, 'session-a')),
    second = summaries_in(session_records_file(state, 'session-b')),
  }, {
    waiting = 1,
    lines = { '09:00 [done] Task — Beta', '10:00 [done] Task — Meanwhile' },
    first = { 'Alpha' },
    second = { 'Beta', 'Meanwhile' },
  })
end

T['a follow refused while textlock holds']["followed twice, shows the last session's records and keeps the next report there"] = function()
  local state = fixture.directory('report-sessions-textlock-twice')
  plant_records(session_records_file(state, 'session-a'), { 'Alpha' })
  plant_records(session_records_file(state, 'session-b'), { 'Beta' })
  plant_records(session_records_file(state, 'session-c'), { 'Gamma' })
  start_editor(state)
  follow('session-a')
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])
  begin_hold('vim.fn.getcharstr()')
  follow('session-b')
  follow('session-c')
  local meanwhile = { lines = report_editor.lines(child), retries = child.lua_get(RETRIES) }
  end_hold('q')

  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)
  local lines = report_editor.lines(child)
  receive('After the hold')

  eq({
    meanwhile = meanwhile,
    lines = lines,
    second = summaries_in(session_records_file(state, 'session-b')),
    third = summaries_in(session_records_file(state, 'session-c')),
  }, {
    meanwhile = { lines = { '09:00 [done] Task — Alpha' }, retries = 1 },
    lines = { '09:00 [done] Task — Gamma' },
    second = { 'Beta' },
    third = { 'Gamma', 'After the hold' },
  })
end

return T
