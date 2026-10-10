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

--- The Lua that interleaves another editor's first follow with the child's,
--- one call at a time: the other editor links the file being moved to its
--- own session's file, given as the chunk's argument, just before the
--- child's link, and removes the moved file's name just before the child's
--- removal of it.
local OTHER_EDITOR_INTERLEAVED = [[
  local other = ...
  local real_link, real_unlink = vim.uv.fs_link, vim.uv.fs_unlink
  vim.uv.fs_link = function(from, to)
    vim.uv.fs_link = real_link
    assert(real_link(from, other))
    return real_link(from, to)
  end
  vim.uv.fs_unlink = function(path)
    vim.uv.fs_unlink = real_unlink
    assert(real_unlink(path))
    return real_unlink(path)
  end
]]

T["the working directory's records"]['moved by another editor at the same moment stay that session file alone'] = function()
  local state = fixture.directory('report-sessions-race-interleaved')
  plant_records(directory_records_file(state), { 'Directory' })
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  child.lua(OTHER_EDITOR_INTERLEAVED, { session_records_file(state, 'session-other') })

  follow('session-a')
  receive('Kept for session a only')
  local a = session_records_file(state, 'session-a')
  local other = session_records_file(state, 'session-other')
  local same_file = vim.uv.fs_stat(a).ino == vim.uv.fs_stat(other).ino
  local warnings = child.lua_get('_G.warnings')
  start_editor(state)
  follow('session-other')

  eq({
    warnings = warnings,
    same_file = same_file,
    other = summaries_in(other),
    other_report = report_editor.lines(child),
  }, {
    warnings = {},
    same_file = false,
    other = { 'Directory' },
    other_report = { '09:00 [done] Task — Directory' },
  })
end

T["the working directory's records"]['removed between the link and its removal stay the session file'] = function()
  local state = fixture.directory('report-sessions-race-removed')
  plant_records(directory_records_file(state), { 'Directory' })
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  child.lua([[
    local real_unlink = vim.uv.fs_unlink
    vim.uv.fs_unlink = function(path)
      vim.uv.fs_unlink = real_unlink
      assert(real_unlink(path))
      return real_unlink(path)
    end
  ]])

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    session = summaries_in(session_records_file(state, 'session-a')),
    lines = report_editor.lines(child),
  }, {
    warnings = {},
    session = { 'Directory' },
    lines = { '09:00 [done] Task — Directory' },
  })
end

T["the working directory's records"]['moved by another editor at the same moment are told so when the link cannot be removed'] = function()
  local state = fixture.directory('report-sessions-race-unremovable')
  plant_records(directory_records_file(state), { 'Directory' })
  local from = directory_records_file(state)
  local to = session_records_file(state, 'session-a')
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  child.lua(OTHER_EDITOR_INTERLEAVED, { session_records_file(state, 'session-other') })
  child.lua([[
    local interleaved = vim.uv.fs_unlink
    vim.uv.fs_unlink = function(path)
      local result = { interleaved(path) }
      vim.uv.fs_unlink = function(refused)
        return nil, 'EACCES: permission denied: ' .. refused, 'EACCES'
      end
      return unpack(result)
    end
  ]])

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    session = summaries_in(to),
  }, {
    warnings = {
      ('aineo cannot move the report records in %s to %s: another editor moved them to its session at the same moment, and %s cannot be removed, so both sessions keep them: EACCES: permission denied: %s'):format(
        from,
        to,
        to,
        to
      ),
    },
    session = { 'Directory' },
  })
end

--- The Lua that makes the child's every hard link fail as a file system
--- refuses one, with the code given as the chunk's argument, as libuv
--- returns it.
local LINKS_REFUSED = [[
  local code = ...
  vim.uv.fs_link = function(from)
    return nil, code .. ': hard links refused: ' .. from, code
  end
]]

--- The codes a file system refuses a hard link with, as a set's
--- `parametrize`: no hard links on it (exFAT, FAT, some network and FUSE
--- mounts), a file on another device, or too many links.
local LINK_REFUSALS = { { 'ENOTSUP' }, { 'EPERM' }, { 'EXDEV' }, { 'EMLINK' }, { 'ENOSYS' } }

T["the working directory's records"]['where hard links are refused'] = MiniTest.new_set({
  parametrize = LINK_REFUSALS,
})

T["the working directory's records"]['where hard links are refused']['become the first session followed by a rename'] = function(
  code
)
  local state = fixture.directory('report-sessions-no-links')
  plant_records(directory_records_file(state), { 'Directory' })
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  child.lua(LINKS_REFUSED, { code })

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    lines = report_editor.lines(child),
    directory = summaries_in(directory_records_file(state)),
    session = summaries_in(session_records_file(state, 'session-a')),
  }, {
    warnings = {},
    lines = { '09:00 [done] Task — Directory' },
    directory = nil,
    session = { 'Directory' },
  })
end

T["the working directory's records"]['where hard links are refused']['are left as they are when the session has records'] = function(
  code
)
  local state = fixture.directory('report-sessions-no-links-both')
  plant_records(directory_records_file(state), { 'Directory' })
  plant_records(session_records_file(state, 'session-a'), { 'Session' })
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  child.lua(LINKS_REFUSED, { code })

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    directory = summaries_in(directory_records_file(state)),
    session = summaries_in(session_records_file(state, 'session-a')),
  }, {
    warnings = {},
    directory = { 'Directory' },
    session = { 'Session' },
  })
end

T["the working directory's records"]['where hard links are refused']['taken by another editor first are told as no failure'] = function(
  code
)
  local state = fixture.directory('report-sessions-no-links-taken')
  plant_records(directory_records_file(state), { 'Directory' })
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  child.lua(LINKS_REFUSED, { code })
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
    session = summaries_in(session_records_file(state, 'session-a')),
  }, { warnings = {}, other = { 'Directory' }, session = nil })
end

T["the working directory's records"]['where hard links are refused']['that cannot be renamed are told once'] = function(
  code
)
  local state = fixture.directory('report-sessions-no-links-unmovable')
  plant_records(directory_records_file(state), { 'Directory' })
  local reports = vim.fs.dirname(directory_records_file(state))
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  child.lua(LINKS_REFUSED, { code })
  vim.uv.fs_chmod(reports, tonumber('500', 8))
  MiniTest.finally(function()
    vim.uv.fs_chmod(reports, tonumber('700', 8))
  end)

  follow('session-a')
  vim.uv.fs_chmod(reports, tonumber('700', 8))

  eq({
    moves = child.lua_get(MOVE_WARNINGS),
    directory = summaries_in(directory_records_file(state)),
    session = summaries_in(session_records_file(state, 'session-a')),
  }, {
    moves = 1,
    directory = { 'Directory' },
    session = nil,
  })
end

T["the working directory's records"]['that are a symbolic link stay one at the first session followed, and the next report reaches the file it leads to'] = function()
  local state = fixture.directory('report-sessions-symbolic-link')
  local target = vim.fs.joinpath(state, 'kept-elsewhere.jsonl')
  plant_records(target, { 'Directory' })
  local directory = directory_records_file(state)
  vim.fn.mkdir(vim.fs.dirname(directory), 'p')
  assert(vim.uv.fs_symlink(target, directory))
  start_editor(state)
  child.lua(KEEP_WARNINGS)

  follow('session-a')
  receive('After the follow')

  eq({
    warnings = child.lua_get('_G.warnings'),
    session = vim.fn.getftype(session_records_file(state, 'session-a')),
    target = summaries_in(target),
  }, {
    warnings = {},
    session = 'link',
    target = { 'Directory', 'After the follow' },
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

T['a follow refused while textlock holds']['is made still when every SafeState autocommand in no group is cleared while it waits'] = function()
  local state = fixture.directory('report-sessions-safestate-cleared')
  plant_records(session_records_file(state, 'session-a'), { 'Alpha' })
  plant_records(session_records_file(state, 'session-b'), { 'Beta' })
  plant_records(session_records_file(state, 'session-c'), { 'Gamma' })
  start_editor(state)
  follow('session-a')
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])
  begin_hold('vim.fn.getcharstr()')
  follow('session-b')
  local waiting = child.lua_get(RETRIES)
  child.cmd('autocmd! SafeState')
  end_hold('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)

  follow('session-c')

  eq({ waiting = waiting, lines = report_editor.lines(child) }, {
    waiting = 1,
    lines = { '09:00 [done] Task — Gamma' },
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

--- Tells the child's report home to follow the Claude session `session` as
--- a claim of it.
---
---@param session string
local function follow_as_claim(session)
  child.lua("require('aineo.report').follow_report_session(..., { claim = true })", { session })
end

T['a claim’s follow'] = MiniTest.new_set()

T['a claim’s follow']['leaves the directory’s records where they are, and keeps the next report under the claimed session'] = function()
  local state = fixture.directory('report-sessions-claim')
  plant_records(directory_records_file(state), { 'Directory' })
  start_editor(state)

  follow_as_claim('session-a')
  receive('After the claim')

  eq({
    lines = report_editor.lines(child),
    directory = summaries_in(directory_records_file(state)),
    session = summaries_in(session_records_file(state, 'session-a')),
  }, {
    lines = { '10:00 [done] Task — After the claim' },
    directory = { 'Directory' },
    session = { 'After the claim' },
  })
end

T['a claim’s follow']['told before the environment moves nothing once the environment comes'] = function()
  local state = fixture.directory('report-sessions-claim-held')
  plant_records(directory_records_file(state), { 'Directory' })
  children.restart(child)
  follow_as_claim('session-a')

  give_environment(state)

  eq({
    directory = summaries_in(directory_records_file(state)),
    session = summaries_in(session_records_file(state, 'session-a')),
  }, { directory = { 'Directory' } })
end

T['a claim’s follow']['leaves the directory’s records to the first follow that is not a claim’s'] = function()
  local state = fixture.directory('report-sessions-claim-then-own')
  plant_records(directory_records_file(state), { 'Directory' })
  start_editor(state)
  follow_as_claim('session-a')

  follow('session-b')

  eq({
    lines = report_editor.lines(child),
    directory = summaries_in(directory_records_file(state)),
    claimed = summaries_in(session_records_file(state, 'session-a')),
    own = summaries_in(session_records_file(state, 'session-b')),
  }, {
    lines = { '09:00 [done] Task — Directory' },
    own = { 'Directory' },
  })
end

T['a claim’s follow']['of a session followed as this editor’s own next leaves that follow to take the directory’s records'] = function()
  local state = fixture.directory('report-sessions-claim-then-same')
  plant_records(directory_records_file(state), { 'Directory' })
  start_editor(state)
  follow_as_claim('session-a')

  follow('session-a')

  eq({
    directory = summaries_in(directory_records_file(state)),
    own = summaries_in(session_records_file(state, 'session-a')),
  }, { own = { 'Directory' } })
end

--- Tells the child's report home to hand the records of the Claude session
--- `from`, which Claude Code found no conversation for, over to `to`, the
--- session that took its place.
---
---@param from string
---@param to string
local function hand_over(from, to)
  child.lua("require('aineo.report').hand_over_report_session(...)", { from, to })
end

T['a hand-over'] = MiniTest.new_set()

T['a hand-over']["makes the dead session's records the new one's, whole, and leaves none under the dead one"] = function()
  local state = fixture.directory('report-sessions-hand-over')
  plant_records(session_records_file(state, 'session-dead'), { 'First', 'Second' })
  start_editor(state)

  hand_over('session-dead', 'session-new')

  eq({
    dead = summaries_in(session_records_file(state, 'session-dead')),
    new = summaries_in(session_records_file(state, 'session-new')),
  }, { new = { 'First', 'Second' } })
end

T['a hand-over']["of the session followed keeps the next report in the new session's records"] = function()
  local state = fixture.directory('report-sessions-hand-over-next')
  plant_records(session_records_file(state, 'session-dead'), { 'Before' })
  start_editor(state)
  follow('session-dead')
  report_editor.lines(child)

  hand_over('session-dead', 'session-new')
  receive('After')

  eq({
    dead = summaries_in(session_records_file(state, 'session-dead')),
    new = summaries_in(session_records_file(state, 'session-new')),
  }, { new = { 'Before', 'After' } })
end

T['a hand-over']['to a session with records of its own moves nothing, and the session followed stays followed'] = function()
  local state = fixture.directory('report-sessions-hand-over-own')
  plant_records(session_records_file(state, 'session-dead'), { 'Dead' })
  plant_records(session_records_file(state, 'session-new'), { 'Own' })
  start_editor(state)
  follow('session-dead')
  report_editor.lines(child)

  hand_over('session-dead', 'session-new')
  receive('After')

  eq({
    dead = summaries_in(session_records_file(state, 'session-dead')),
    new = summaries_in(session_records_file(state, 'session-new')),
  }, { dead = { 'Dead', 'After' }, new = { 'Own' } })
end

--- The expression, run in the child, that counts the warnings it gave that
--- records could not be read.
local READ_WARNINGS = [[#vim.tbl_filter(function(message)
  return message:find('cannot read the report records', 1, true) ~= nil
end, _G.warnings)]]

T['a hand-over']['of records that cannot be read moves them as they are, and a follow of the new session tells it'] = function()
  local state = fixture.directory('report-sessions-hand-over-unreadable')
  local dead = session_records_file(state, 'session-dead')
  local new = session_records_file(state, 'session-new')
  plant_records(dead, { 'Unreadable' })
  vim.uv.fs_chmod(dead, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(new, tonumber('600', 8))
  end)
  start_editor(state)
  child.lua(KEEP_WARNINGS)

  hand_over('session-dead', 'session-new')
  follow('session-new')
  local lines = report_editor.lines(child)
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(READ_WARNINGS) > 0
  end, 10)

  eq({
    dead = vim.uv.fs_stat(dead) ~= nil,
    new_mode = vim.uv.fs_stat(new).mode % 512,
    lines = lines,
    read_warnings = child.lua_get(READ_WARNINGS),
  }, { dead = false, new_mode = 0, lines = { '' }, read_warnings = 1 })
end

T['a hand-over']['when neither session has records makes none'] = function()
  local state = fixture.directory('report-sessions-hand-over-none')
  start_editor(state)

  hand_over('session-dead', 'session-new')

  eq(vim.fn.glob(vim.fs.joinpath(state, 'aineo', 'reports', '*'), false, true), {})
end

--- Shows the child's Report in its current window, with the cursor at
--- `cursor`.
---
---@param cursor integer[]
local function show_report_at(cursor)
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])
  child.api.nvim_win_set_cursor(0, cursor)
end

T['a hand-over']["of the session followed leaves the Report's lines and cursor as they were"] = function()
  local state = fixture.directory('report-sessions-hand-over-lines')
  plant_records(session_records_file(state, 'session-dead'), { 'First', 'Second', 'Third' })
  start_editor(state)
  follow('session-dead')
  show_report_at({ 3, 4 })

  hand_over('session-dead', 'session-new')

  eq({ lines = report_editor.lines(child), cursor = child.api.nvim_win_get_cursor(0) }, {
    lines = {
      '09:00 [done] Task — First',
      '09:00 [done] Task — Second',
      '09:00 [done] Task — Third',
    },
    cursor = { 3, 4 },
  })
end

T['a hand-over']["of the session followed, then a follow of the new session, leaves the Report's lines and cursor as they were"] = function()
  local state = fixture.directory('report-sessions-hand-over-then-follow')
  plant_records(session_records_file(state, 'session-dead'), { 'First', 'Second' })
  start_editor(state)
  follow('session-dead')
  show_report_at({ 2, 4 })
  hand_over('session-dead', 'session-new')
  receive('Third')
  child.api.nvim_win_set_cursor(0, { 2, 4 })

  follow('session-new')

  eq({ lines = report_editor.lines(child), cursor = child.api.nvim_win_get_cursor(0) }, {
    lines = {
      '09:00 [done] Task — First',
      '09:00 [done] Task — Second',
      '10:00 [done] Task — Third',
    },
    cursor = { 2, 4 },
  })
end

T['a hand-over']['of a session not followed leaves the Report and the session followed as they were'] = function()
  local state = fixture.directory('report-sessions-hand-over-other')
  plant_records(session_records_file(state, 'session-dead'), { 'Dead' })
  plant_records(session_records_file(state, 'session-other'), { 'Other' })
  start_editor(state)
  follow('session-other')
  report_editor.lines(child)

  hand_over('session-dead', 'session-new')
  receive('After')

  eq({
    lines = report_editor.lines(child),
    other = summaries_in(session_records_file(state, 'session-other')),
    new = summaries_in(session_records_file(state, 'session-new')),
  }, {
    lines = { '09:00 [done] Task — Other', '10:00 [done] Task — After' },
    other = { 'Other', 'After' },
    new = { 'Dead' },
  })
end

T['a hand-over']['of a session whose records wait to be shown while textlock holds shows them once it ends'] = function()
  local state = fixture.directory('report-sessions-hand-over-textlock')
  plant_records(session_records_file(state, 'session-a'), { 'Alpha' })
  plant_records(session_records_file(state, 'session-dead'), { 'Dead' })
  start_editor(state)
  follow('session-a')
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])
  begin_hold('vim.fn.getcharstr()')
  follow('session-dead')

  hand_over('session-dead', 'session-new')
  end_hold('q')

  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)
  eq(report_editor.lines(child), { '09:00 [done] Task — Dead' })
end

T['a hand-over']['told before the environment is made once it comes, and the next report is kept for the new session'] = function()
  local state = fixture.directory('report-sessions-hand-over-held')
  plant_records(session_records_file(state, 'session-dead'), { 'Dead' })
  children.restart(child)
  follow('session-dead')

  hand_over('session-dead', 'session-new')
  give_environment(state)
  receive('After')

  eq({
    lines = report_editor.lines(child),
    dead = summaries_in(session_records_file(state, 'session-dead')),
    new = summaries_in(session_records_file(state, 'session-new')),
  }, {
    lines = { '09:00 [done] Task — Dead', '10:00 [done] Task — After' },
    new = { 'Dead', 'After' },
  })
end

T['a hand-over']['refuses an id that is not a string, naming it, and moves nothing'] =
  MiniTest.new_set({
    parametrize = {
      { 'nil', "'session-new'", 'from' },
      { '{}', "'session-new'", 'from' },
      { "'session-dead'", '7', 'to' },
    },
  })

T['a hand-over']['refuses an id that is not a string, naming it, and moves nothing']['as'] = function(
  from,
  to,
  named
)
  local state = fixture.directory('report-sessions-hand-over-not-an-id')
  plant_records(session_records_file(state, 'session-dead'), { 'Dead' })
  start_editor(state)

  local refusal = child.lua_get(([[(function()
    local handed, failure = pcall(require('aineo.report').hand_over_report_session, %s, %s)
    return { handed = handed, named = tostring(failure):find(%q, 1, true) ~= nil }
  end)()]]):format(from, to, named))

  eq({
    refusal = refusal,
    dead = summaries_in(session_records_file(state, 'session-dead')),
  }, { refusal = { handed = false, named = true }, dead = { 'Dead' } })
end

T['a hand-over']['that cannot move the records tells it once, and raises nothing'] = function()
  local state = fixture.directory('report-sessions-hand-over-unmovable')
  plant_records(session_records_file(state, 'session-dead'), { 'Dead' })
  start_editor(state)
  child.lua(KEEP_WARNINGS)
  local reports = vim.fs.dirname(session_records_file(state, 'session-dead'))
  vim.uv.fs_chmod(reports, tonumber('500', 8))
  MiniTest.finally(function()
    vim.uv.fs_chmod(reports, tonumber('700', 8))
  end)

  local raised_nothing = child.lua_get(
    "(pcall(require('aineo.report').hand_over_report_session, ...))",
    { 'session-dead', 'session-new' }
  )
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('#_G.warnings') > 0
  end, 10)
  vim.uv.fs_chmod(reports, tonumber('700', 8))

  eq({
    raised_nothing = raised_nothing,
    warnings = child.lua_get('#_G.warnings'),
    moves = child.lua_get(MOVE_WARNINGS),
    dead = summaries_in(session_records_file(state, 'session-dead')),
  }, { raised_nothing = true, warnings = 1, moves = 1, dead = { 'Dead' } })
end

T['a hand-over']["of a session followed as a claim's makes the new session followed as the editor's own"] = function()
  local state = fixture.directory('report-sessions-hand-over-claim')
  plant_records(session_records_file(state, 'session-dead'), { 'First', 'Second' })
  start_editor(state)
  follow_as_claim('session-dead')
  show_report_at({ 2, 4 })
  hand_over('session-dead', 'session-new')

  follow('session-new')

  eq({ lines = report_editor.lines(child), cursor = child.api.nvim_win_get_cursor(0) }, {
    lines = { '09:00 [done] Task — First', '09:00 [done] Task — Second' },
    cursor = { 2, 4 },
  })
end

return T
