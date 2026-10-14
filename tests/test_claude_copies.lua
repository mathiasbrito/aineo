local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude = dofile('tests/helpers/claude_session.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The child's screen: two windows side by side each hold a Claude Code
--- screen as the recordings drew it, 120 columns by 40 rows.
local SCREEN_COLUMNS = 241
local SCREEN_LINES = 42

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
      child.o.columns = SCREEN_COLUMNS
      child.o.lines = SCREEN_LINES
    end,
    post_once = child.stop,
  },
})

--- The type of each of `names` in the table `require('aineo.claude')` gives,
--- or, with `from_new`, in the one `require('aineo.claude').new()` returns.
---
---@param names string[]
---@param from_new boolean
---@return table<string, string>
local function types_of(names, from_new)
  return child.lua(
    [[
      local names, from_new = ...
      local home = from_new and require('aineo.claude').new() or require('aineo.claude')
      local types = {}
      for _, name in ipairs(names) do
        types[name] = type(home[name])
      end
      return types
    ]],
    { names, from_new }
  )
end

--- What `types_of()` gives when each of `names` has the type `kind`.
---
---@param names string[]
---@param kind string
---@return table<string, string>
local function all_of_type(names, kind)
  local types = {}
  for _, name in ipairs(names) do
    types[name] = kind
  end
  return types
end

--- The functions of a session home that keep a session's state.
local PER_SESSION_FUNCTIONS = {
  'start_session',
  'join_session',
  'can_join_session',
  'replace_session',
  'is_attached',
  'session_status',
  'session_id',
  'session_directory',
  'prompt_shows_text',
  'write_to_session',
  'stop_session',
  'start_token',
}

--- The functions that keep no state and stay on the module only.
local STATELESS_FUNCTIONS = {
  'is_session_id',
  'list_sessions',
  'session_standing',
  'listed_session_name',
  'session_row',
  'session_statusline',
  'session_statusline_format',
  'given_settings_verdict',
}

--- Starts the session of copy number `number` in `child` — made by `new()`
--- on its first call — with `fake`'s environment and the stand-in settings
--- overridden by `overrides`, shows its terminal in a window of its own, beside the others, and
--- returns that terminal. A start is on a new session id (`new_session`)
--- unless `overrides` says otherwise: a start that resumes the folder's kept
--- session launches Claude Code only once the list of sessions has answered,
--- by when the environment this sets may be another copy's.
---
---@param number integer
---@param fake { environment: table<string, string> }
---@param overrides? table
---@return integer
local function start_copy(number, fake, overrides)
  return child.lua(
    [[
      local helper, number, environment, overrides = dofile(...), select(2, ...)
      for name, value in pairs(environment) do
        vim.env[name] = value
      end
      _G.copies = _G.copies or {}
      _G.copies[number] = _G.copies[number] or require('aineo.claude').new()
      local settings = helper.stand_in_settings(overrides)
      if settings.new_session == nil then
        settings.new_session = true
      end
      _G.switches = _G.switches or {}
      _G.switches[number] = {}
      settings.on_session_switched = function(id, source, left, reason)
        table.insert(_G.switches[number], { id = id, source = source, left = left, reason = reason })
      end
      local buffer = _G.copies[number].start_session(settings)
      vim.cmd.vnew()
      vim.api.nvim_win_set_buf(0, buffer)
      return buffer
    ]],
    { 'tests/helpers/claude_session.lua', number, fake.environment, overrides or vim.empty_dict() }
  )
end

--- The switches copy number `number` of `child` has been told of, each
--- `{ id, source, left, reason }`, once there are `count` of them — waiting
--- for that at most `claude.PATIENCE_MS` — or when the wait runs out.
---
---@param number integer
---@param count integer
---@return table[]
local function wait_for_copy_switches(number, count)
  local switches
  vim.wait(claude.PATIENCE_MS, function()
    switches = child.lua_get('_G.switches[...]', { number })
    return #switches >= count
  end, 20)
  return switches
end

--- What copy number `number` of `child` answers to `call`, one of its
--- functions that takes no argument, as the list of everything it returns.
---
---@param number integer
---@param call string
---@return any[]
local function copy_answers(number, call)
  return child.lua(
    'local number, call = ...; return { _G.copies[number][call]() }',
    { number, call }
  )
end

--- What `session_status()` of copy number `number` says, once its first
--- value is `state` — waiting for that at most `claude.PATIENCE_MS` — or
--- when the wait runs out; as the list of everything it returns.
---
---@param number integer
---@param state string
---@return any[]
local function wait_for_copy_status(number, state)
  local status
  vim.wait(claude.PATIENCE_MS, function()
    status = copy_answers(number, 'session_status')
    return status[1] == state
  end, 20)
  return status
end

--- Has the session of copy number `number` end by a double Ctrl-C in its
--- `terminal` once the case is over, so that quitting the editor stops
--- nothing. It presses nothing when the session has exited already or the
--- terminal is gone: it runs from `MiniTest.finally()`, where an error would
--- stop the whole run rather than fail the case.
---
---@param number integer
---@param terminal integer
---@param fake { record: string }
local function end_copy_after_case(number, terminal, fake)
  MiniTest.finally(function()
    claude.wait_for_start(fake)
    claude.wait_for_launch(child, terminal)
    child.lua(
      [[
        local number, terminal = ...
        local running = _G.copies[number].session_status() ~= 'exited'
        if running and vim.api.nvim_buf_is_valid(terminal) then
          pcall(vim.api.nvim_chan_send, vim.bo[terminal].channel, '\3\3')
        end
      ]],
      { number, terminal }
    )
    wait_for_copy_status(number, 'exited')
  end)
end

T['new()'] = MiniTest.new_set()

T['new()']['returns a session home with each per-session function as a field'] = function()
  eq(types_of(PER_SESSION_FUNCTIONS, true), all_of_type(PER_SESSION_FUNCTIONS, 'function'))
end

T['new()']['leaves the functions that keep no state on the module'] = function()
  eq(types_of(STATELESS_FUNCTIONS, true), all_of_type(STATELESS_FUNCTIONS, 'nil'))
  eq(types_of(STATELESS_FUNCTIONS, false), all_of_type(STATELESS_FUNCTIONS, 'function'))
end

T['new()']['gives each call a copy of its own'] = function()
  local distinct = child.lua([[
    local claude = require('aineo.claude')
    local first, second = claude.new(), claude.new()
    return {
      copies = first ~= second,
      from_the_module = first ~= claude and second ~= claude,
      start = first.start_session ~= second.start_session,
    }
  ]])

  eq(distinct, { copies = true, from_the_module = true, start = true })
end

T['two copies'] = MiniTest.new_set()

T['two copies']['each start a Claude Code of their own, with a terminal, a status and a session id of their own'] = function()
  local first_fake = claude.fake('copies-first', 'ready')
  local second_fake = claude.fake('copies-second', 'ready')
  local first = start_copy(1, first_fake)
  end_copy_after_case(1, first, first_fake)
  local second = start_copy(2, second_fake)
  end_copy_after_case(2, second, second_fake)
  claude.wait_for_start(first_fake)
  claude.wait_for_start(second_fake)

  eq(first ~= second, true)
  eq(wait_for_copy_status(1, 'ready'), { 'ready' })
  eq(wait_for_copy_status(2, 'ready'), { 'ready' })
  eq(
    copy_answers(1, 'session_id'),
    { claude.words_after(claude.arguments(first_fake), '--session-id')[1] }
  )
  eq(
    copy_answers(2, 'session_id'),
    { claude.words_after(claude.arguments(second_fake), '--session-id')[1] }
  )
end

T['two copies']['leave the other running when one’s Claude Code exits, and the first then starts anew'] = function()
  local first_fake = claude.fake('copies-exit-first', 'ready')
  local second_fake = claude.fake('copies-exit-second', 'ready')
  local first = start_copy(1, first_fake)
  local second = start_copy(2, second_fake)
  end_copy_after_case(2, second, second_fake)
  wait_for_copy_status(1, 'ready')
  wait_for_copy_status(2, 'ready')
  claude.press_keys(child, first, '\3\3')
  wait_for_copy_status(1, 'exited')

  local second_status = copy_answers(2, 'session_status')
  local restarted = start_copy(1, first_fake)
  end_copy_after_case(1, restarted, first_fake)

  eq(second_status, { 'ready' })
  eq(restarted ~= first, true)
  eq(#claude.wait_for_starts(first_fake, 2), 2)
  eq(wait_for_copy_status(1, 'ready'), { 'ready' })
  eq(#claude.wait_for_starts(second_fake, 1), 1)
  eq(copy_answers(2, 'session_status'), { 'ready' })
end

T['session hooks'] = MiniTest.new_set()

--- The id kept as the folder's session under the state directory `state`,
--- or nil when none is kept.
---
---@param state string
---@return string?
local function id_kept_for_the_folder(state)
  local file =
    vim.fs.joinpath(state, 'aineo', 'claude-sessions', vim.fn.sha256(child.fn.getcwd()) .. '.txt')
  return vim.fn.filereadable(file) == 1 and table.concat(vim.fn.readfile(file), '') or nil
end

--- Starts two copies against fakes that run Claude Code's session hooks,
--- both on the state directory `state`, and waits for both to be ready.
---
---@param name string
---@param state string
---@return table terminals the two terminals, by copy number
---@return table started_on the two session ids the copies started on, by copy number
local function two_copies_running_hooks(name, state)
  local first_fake = claude.fake(name .. '-first', 'ready', { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  local second_fake = claude.fake(name .. '-second', 'ready', { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  local first = start_copy(1, first_fake, { state_directory = state })
  end_copy_after_case(1, first, first_fake)
  local second = start_copy(2, second_fake, { state_directory = state })
  end_copy_after_case(2, second, second_fake)
  wait_for_copy_status(1, 'ready')
  wait_for_copy_status(2, 'ready')
  return { first, second }, {
    claude.words_after(claude.arguments(first_fake), '--session-id')[1],
    claude.words_after(claude.arguments(second_fake), '--session-id')[1],
  }
end

T['session hooks']['reach the copy whose start has the hook’s token, and no other'] = function()
  local state = fixture.directory('copies-hooks-state')
  local terminals, started_on = two_copies_running_hooks('copies-hooks', state)

  claude.press_keys(child, terminals[2], '/clear\r')
  local switches = wait_for_copy_switches(2, 1)
  claude.wait_for_deliveries(child)

  local cleared_to = copy_answers(2, 'session_id')[1]
  eq(switches, {
    { id = cleared_to, source = 'clear', left = started_on[2], reason = 'clear' },
  })
  eq(cleared_to ~= started_on[2], true)
  eq(id_kept_for_the_folder(state), cleared_to)
  eq(copy_answers(1, 'session_id'), { started_on[1] })
  eq(wait_for_copy_switches(1, 0), {})
end

T['session hooks']['reach the copy that started first as well'] = function()
  local state = fixture.directory('copies-hooks-first-state')
  local terminals, started_on = two_copies_running_hooks('copies-hooks-first-copy', state)

  claude.press_keys(child, terminals[1], '/clear\r')
  local switches = wait_for_copy_switches(1, 1)
  claude.wait_for_deliveries(child)

  local cleared_to = copy_answers(1, 'session_id')[1]
  eq(switches, {
    { id = cleared_to, source = 'clear', left = started_on[1], reason = 'clear' },
  })
  eq(cleared_to ~= started_on[1], true)
  eq(copy_answers(2, 'session_id'), { started_on[2] })
  eq(wait_for_copy_switches(2, 0), {})
end

--- Session ids of the form Claude Code gives, for the hooks a case tells.
local NEW_ID = '11111111-2222-4333-8444-555555555555'

--- Starts copy number `number` of `child` in place of what it runs, by
--- `replace_session()` resuming the session `id`, against `fake`; shows its
--- terminal beside the others, and returns it.
---
---@param number integer
---@param fake { environment: table<string, string> }
---@param id string
---@return integer
local function resume_copy_in_place(number, fake, id)
  return child.lua(
    [[
      local helper, number, environment, id = dofile(...), select(2, ...)
      for name, value in pairs(environment) do
        vim.env[name] = value
      end
      _G.copies = _G.copies or {}
      _G.copies[number] = _G.copies[number] or require('aineo.claude').new()
      _G.switches = _G.switches or {}
      _G.switches[number] = {}
      local settings = helper.stand_in_settings({})
      settings.on_session_switched = function(switched_to, source, left, reason)
        table.insert(_G.switches[number], { id = switched_to, source = source, left = left, reason = reason })
      end
      local buffer = _G.copies[number].replace_session(settings, { id = id, resumed = true })
      vim.cmd.vnew()
      vim.api.nvim_win_set_buf(0, buffer)
      return buffer
    ]],
    { 'tests/helpers/claude_session.lua', number, fake.environment, id }
  )
end

T['session hooks']['follow the start’s token and not the session when two copies are on one session'] = function()
  local first_fake = claude.fake('copies-hooks-shared-first', 'ready')
  local second_fake = claude.fake('copies-hooks-shared-second', 'ready')
  local first = start_copy(1, first_fake)
  end_copy_after_case(1, first, first_fake)
  wait_for_copy_status(1, 'ready')
  local shared = copy_answers(1, 'session_id')[1]
  local second = resume_copy_in_place(2, second_fake, shared)
  end_copy_after_case(2, second, second_fake)
  wait_for_copy_status(2, 'ready')

  child.lua(
    [[
      local left, id, token = ...
      local ran = vim.uv.hrtime()
      local claude = require('aineo.claude')
      claude.receive_session_event('SessionEnd', left, 'clear', token, ran)
      claude.receive_session_event('SessionStart', id, 'clear', token, ran + 1)
    ]],
    { shared, NEW_ID, copy_answers(2, 'start_token')[1] }
  )
  wait_for_copy_switches(2, 1)

  eq(copy_answers(2, 'session_id'), { NEW_ID })
  eq(copy_answers(1, 'session_id'), { shared })
  eq(wait_for_copy_switches(1, 0), {})
end

--- The ids of the handlers of Neovim's quit (`VimLeavePre`) in the group
--- `aineo.claude`, in `child`.
---
---@return integer[]
local function quit_handler_ids()
  return child.lua([[
    return vim.tbl_map(function(handler)
      return handler.id
    end, vim.api.nvim_get_autocmds({ group = 'aineo.claude', event = 'VimLeavePre' }))
  ]])
end

--- The session a background Claude Code runs, and its short id as `claude
--- agents --json` gives it.
local BACKGROUND_SESSION_ID = '0f9e7c2a-1b3d-4e5f-8a9b-0c1d2e3f4a5b'
local BACKGROUND_SHORT_ID = 'a1b2c3d4'

--- A fake `claude` for one case whose `agents --json` lists the session
--- `BACKGROUND_SESSION_ID` as running in Claude Code's background service,
--- and the settings overrides that keep that session for the editor's
--- folder under a state directory of the case's own, so that a start of a
--- copy resumes it and attaches to it.
---
---@param name string
---@return { record: string, environment: table<string, string> } fake
---@return table settings the overrides for `start_copy()`
local function fake_listing_a_background_session(name)
  local fake = claude.fake(name, 'ready')
  local listing = vim.fs.joinpath(vim.fs.dirname(fake.record), 'agents.json')
  vim.fn.writefile({
    vim.json.encode({
      {
        id = BACKGROUND_SHORT_ID,
        cwd = '/work/project',
        kind = 'background',
        startedAt = 1790000100000,
        sessionId = BACKGROUND_SESSION_ID,
        name = 'tests',
        state = 'working',
        pid = 4343,
        status = 'busy',
      },
    }),
  }, listing)
  fake.environment.AINEO_FAKE_CLAUDE_AGENTS = listing
  local state_directory = fixture.directory(name .. '-state')
  local kept = vim.fs.joinpath(state_directory, 'aineo', 'claude-sessions')
  vim.fn.mkdir(kept, 'p')
  vim.fn.writefile(
    { BACKGROUND_SESSION_ID },
    vim.fs.joinpath(kept, vim.fn.sha256(vim.fn.getcwd()) .. '.txt'),
    'b'
  )
  return fake, { state_directory = state_directory, new_session = false }
end

T['quitting Neovim with two copies running'] = MiniTest.new_set()

--- How long a quit may take with two Claude Codes that each exit only on
--- the last key of the stop: one stop takes about 4.4 s with the fake, and
--- the stops of two, one after the other, 8.8 s.
local ONE_STOP_PLUS_SLACK_MS = 7500

--- Starts two copies against fakes in `mode`, each of its own record, waits
--- for both to be ready, and returns the two fakes and the two terminals.
---
---@param name string
---@param mode string
---@return { record: string } first_fake
---@return { record: string } second_fake
---@return integer first_terminal
---@return integer second_terminal
local function two_ready_copies(name, mode)
  local first_fake = claude.fake(name .. '-first', mode)
  local second_fake = claude.fake(name .. '-second', mode)
  local first_terminal = start_copy(1, first_fake)
  local second_terminal = start_copy(2, second_fake)
  wait_for_copy_status(1, 'ready')
  wait_for_copy_status(2, 'ready')
  return first_fake, second_fake, first_terminal, second_terminal
end

T['quitting Neovim with two copies running']['stops each copy’s Claude Code by its keys'] = function()
  local first_fake, second_fake = two_ready_copies('copies-quit-keys', 'ready')

  claude.quit(child)

  eq(claude.wait_for_end(first_fake), { { ended = 'keys', code = 0 } })
  eq(claude.wait_for_end(second_fake), { { ended = 'keys', code = 0 } })
end

T['quitting Neovim with two copies running']['takes about the time of one stop, not of two'] = function()
  two_ready_copies('copies-quit-time', 'ready')
  local quit_at = vim.uv.hrtime()

  claude.quit(child)
  local exited = vim.fn.jobwait({ child.job.id }, claude.STOP_PATIENCE_MS)
  local quit_ms = (vim.uv.hrtime() - quit_at) / 1e6

  eq(exited, { 0 })
  eq(quit_ms < ONE_STOP_PLUS_SLACK_MS, true)
end

T['quitting Neovim with two copies running']['presses Ctrl+Z and never Ctrl-C to an attached copy, and stops the other by its keys'] = function()
  local attached_fake, attached_settings = fake_listing_a_background_session('copies-quit-attached')
  local other_fake = claude.fake('copies-quit-attached-other', 'ready')
  start_copy(1, attached_fake, attached_settings)
  wait_for_copy_status(1, 'ready')
  start_copy(2, other_fake)
  wait_for_copy_status(2, 'ready')

  claude.quit(child)
  local attached_events = claude.wait_for_end(attached_fake)

  eq(claude.ctrl_c_count(attached_fake), 0)
  eq(attached_events[#attached_events], { ended = 'detach', code = 0 })
  eq(claude.wait_for_end(other_fake), { { ended = 'keys', code = 0 } })
end

T['quitting Neovim with two copies running']['presses each key of the stop once to a copy that started twice'] = function()
  local exited_fake = claude.fake('copies-twice-exited', 'ready')
  local running_fake = claude.fake('copies-twice-running', 'ready')
  local first = start_copy(1, exited_fake)
  wait_for_copy_status(1, 'ready')
  claude.press_keys(child, first, '\3\3')
  wait_for_copy_status(1, 'exited')
  start_copy(1, running_fake)
  wait_for_copy_status(1, 'ready')

  claude.quit(child)

  eq(claude.wait_for_end(running_fake), { { ended = 'keys', code = 0 } })
  eq(claude.ctrl_c_count(running_fake), 3)
end

T['quitting Neovim with two copies running']['keeps the one handler the first copy’s start made, whichever copy starts after it'] = function()
  local first_fake = claude.fake('copies-handler-first', 'ready')
  local second_fake = claude.fake('copies-handler-second', 'ready')
  local first = start_copy(1, first_fake)
  end_copy_after_case(1, first, first_fake)
  local handlers_after_the_first = quit_handler_ids()
  local second = start_copy(2, second_fake)
  end_copy_after_case(2, second, second_fake)

  local handlers_after_the_second = quit_handler_ids()

  eq(#handlers_after_the_first, 1)
  eq(handlers_after_the_second, handlers_after_the_first)
end

T['stop_session()'] = MiniTest.new_set()

--- Calls `stop_session()` of copy number `number` in `child` and returns how
--- long it blocked the editor, in milliseconds.
---
---@param number integer
---@return number
local function milliseconds_to_stop_copy(number)
  local before = vim.uv.hrtime()
  child.lua('_G.copies[...].stop_session()', { number })
  return (vim.uv.hrtime() - before) / 1e6
end

T['stop_session()']['stops its own Claude Code as quitting does and leaves the other copy running'] = function()
  local first_fake, second_fake, _, second = two_ready_copies('copies-stop-one', 'ready')
  end_copy_after_case(2, second, second_fake)

  local blocked_ms = milliseconds_to_stop_copy(1)

  eq(claude.wait_for_end(first_fake), { { ended = 'keys', code = 0 } })
  eq(copy_answers(1, 'session_status'), { 'exited', 0 })
  eq(copy_answers(2, 'session_status'), { 'ready' })
  eq(blocked_ms < ONE_STOP_PLUS_SLACK_MS, true)
end

T['stop_session()']['presses Ctrl+Z and never Ctrl-C to an attached copy'] = function()
  local fake, settings = fake_listing_a_background_session('copies-stop-attached')
  start_copy(1, fake, settings)
  wait_for_copy_status(1, 'ready')

  child.lua('_G.copies[1].stop_session()')
  local events = claude.wait_for_end(fake)

  eq(claude.ctrl_c_count(fake), 0)
  eq(events[#events], { ended = 'detach', code = 0 })
end

--- How long `stop_session()` may block for a copy with no Claude Code to
--- stop.
local NOTHING_TO_STOP_MS = 1000

--- How long a case waits to be sure that no new start follows a stop: longer
--- than the fake takes to find no conversation and exit.
local NOTHING_STARTS_PATIENCE_MS = 1500

T['stop_session()']['does nothing for a copy that has not started'] = function()
  child.lua('_G.copies = { require("aineo.claude").new() }')

  eq(milliseconds_to_stop_copy(1) < NOTHING_TO_STOP_MS, true)
end

T['stop_session()']['does nothing for a copy whose Claude Code has exited'] = function()
  local fake = claude.fake('copies-stop-exited', 'ready')
  local terminal = start_copy(1, fake)
  wait_for_copy_status(1, 'ready')
  claude.press_keys(child, terminal, '\3\3')
  wait_for_copy_status(1, 'exited')

  eq(milliseconds_to_stop_copy(1) < NOTHING_TO_STOP_MS, true)
end

--- The session id kept for the editor's folder under the state directory
--- `state`, as the session a start that resumes lands in.
local KEPT_ID = '11111111-2222-4333-8444-555555555555'

--- Keeps `KEPT_ID` for the folder of `child` under `state`.
---
---@param state string
local function keep_id_under(state)
  local kept = vim.fs.joinpath(state, 'aineo', 'claude-sessions')
  vim.fn.mkdir(kept, 'p')
  vim.fn.writefile(
    { KEPT_ID },
    vim.fs.joinpath(kept, vim.fn.sha256(child.fn.getcwd()) .. '.txt'),
    'b'
  )
end

T['stop_session()']['keeps a start that waits for the list of sessions from launching'] = function()
  local gate = claude.list_gate('copies-stop-waiting')
  local fake = claude.fake('copies-stop-waiting', 'ready')
  local state = fixture.directory('copies-stop-waiting-state')
  keep_id_under(state)
  local terminal =
    start_copy(1, fake, { cmd = gate.cmd, state_directory = state, new_session = false })
  vim.wait(claude.PATIENCE_MS, function()
    return gate.lists_started() >= 1
  end, 20)
  local status_before = copy_answers(1, 'session_status')

  child.lua('_G.copies[1].stop_session()')
  gate.open()
  end_copy_after_case(1, terminal, fake)

  eq(status_before, { 'starting' })
  eq(claude.wait_for_start(fake).argv, nil)
  eq(copy_answers(1, 'session_status')[1], 'exited')
end

T['stop_session()']['starts nothing in place of a Claude Code that found no conversation'] = function()
  local conversations = fixture.directory('copies-stop-noconversation-conversations')
  local fake = claude.fake(
    'copies-stop-noconversation',
    'ready',
    { AINEO_FAKE_CLAUDE_CONVERSATIONS = conversations }
  )
  local state = fixture.directory('copies-stop-noconversation-state')
  keep_id_under(state)
  start_copy(1, fake, { state_directory = state, new_session = false })
  claude.wait_for_start(fake)

  child.lua('_G.copies[1].stop_session()')
  vim.wait(NOTHING_STARTS_PATIENCE_MS)

  eq(#claude.wait_for_starts(fake, 2), 1)
  eq(copy_answers(1, 'session_status'), { 'exited', 1 })
end

T['start_token()'] = MiniTest.new_set()

T['start_token()']['is nil before the copy has started'] = function()
  child.lua('_G.copies = { require("aineo.claude").new() }')

  eq(copy_answers(1, 'start_token'), {})
end

T['start_token()']['is the token the hooks of the copy’s last start name'] = function()
  local fake = claude.fake('copies-token', 'ready')
  local first = start_copy(1, fake)
  wait_for_copy_status(1, 'ready')
  local first_token = copy_answers(1, 'start_token')[1]
  claude.press_keys(child, first, '\3\3')
  wait_for_copy_status(1, 'exited')
  local second = start_copy(1, fake)
  end_copy_after_case(1, second, fake)
  claude.wait_for_starts(fake, 2)

  local second_token = copy_answers(1, 'start_token')[1]

  eq(first_token, claude.start_token(fake, 1))
  eq(second_token, claude.start_token(fake, 2))
  eq(first_token ~= second_token, true)
end

T['stop_together()'] = MiniTest.new_set()

T['stop_together()']['presses the first key to every stop before it looks at an exit'] = function()
  local pressed = child.lua([[
    local pressed = {}
    vim.api.nvim_chan_send = function(job)
      table.insert(pressed, job)
      return 1
    end
    local function has_exited()
      return vim.tbl_contains(pressed, 1)
    end
    require('aineo.claude.stop').stop_together({
      { job = 1, has_exited = has_exited, way = 'keys' },
      { job = 2, has_exited = has_exited, way = 'keys' },
    })
    return pressed
  ]])

  eq(pressed, { 1, 2 })
end

T['Send with a given copy and Input'] = MiniTest.new_set()

T['Send with a given copy and Input']['refuses a target of the wrong kind'] = MiniTest.new_set({
  parametrize = {
    { 'send', '5', 'target: expected table' },
    { 'send', "{ input = 'x' }", 'target.input: expected number' },
    { 'send', '{ session = 3 }', 'target.session: expected table' },
    { 'send_selection', '5', 'target: expected table' },
    { 'send_selection', "{ input = 'x' }", 'target.input: expected number' },
    { 'send_selection', '{ session = 3 }', 'target.session: expected table' },
  },
})

T['Send with a given copy and Input']['refuses a target of the wrong kind']['and names it'] = function(
  name,
  target,
  parameter
)
  local result = child.lua(
    "local name = ...; return { pcall(require('aineo.send')[name], " .. target .. ') }',
    { name }
  )

  eq(result[1], false)
  eq(result[2]:find(parameter, 1, true) ~= nil, true)
end

--- The bytes Send writes for `message`: one bracketed paste and its Enter.
---
---@param message string
---@return string
local function paste(message)
  return '\27[200~' .. message .. '\27[201~\r'
end

--- Makes an Input of its own in `child` — a scratch buffer holding `lines`,
--- kept in `_G.input` — and has every notification kept in `_G.told` as
--- `{ message, level }`, rather than shown.
---
---@param lines string[]
local function make_input_of_its_own(lines)
  child.lua(
    [[
      _G.input = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(_G.input, 0, -1, false, ...)
      _G.told = {}
      vim.notify = function(message, level)
        table.insert(_G.told, { message, level })
      end
    ]],
    { lines }
  )
end

--- The lines of the Input made by `make_input_of_its_own()`.
---
---@return string[]
local function lines_of_input()
  return child.lua('return vim.api.nvim_buf_get_lines(_G.input, 0, -1, false)')
end

--- Waits, at most `claude.PATIENCE_MS`, until `fake` has received `bytes`
--- whole, and returns whether it has.
---
---@param fake { record: string }
---@param bytes string
---@return boolean
local function wait_until_received(fake, bytes)
  return vim.wait(claude.PATIENCE_MS, function()
    return claude.received(fake):find(bytes, 1, true) ~= nil
  end, 20)
end

--- How long a case waits for bytes it expects Send not to write.
local NOTHING_SENT_PATIENCE_MS = 300

T['Send with a given copy and Input']['sends the given Input’s text to the given copy’s Claude Code only'] = function()
  local first_fake, second_fake, first, second = two_ready_copies('copies-send', 'ready')
  end_copy_after_case(1, first, first_fake)
  end_copy_after_case(2, second, second_fake)
  make_input_of_its_own({ 'for the second' })

  local sent = child.lua(
    "return { pcall(require('aineo.send').send, { session = _G.copies[2], input = _G.input }) }"
  )

  eq(sent, { true })
  eq(wait_until_received(second_fake, paste('for the second')), true)
  vim.wait(NOTHING_SENT_PATIENCE_MS)
  eq(claude.received(first_fake):find('for the second', 1, true), nil)
  eq(lines_of_input(), { '' })
end

T['Send with a given copy and Input']['refuses a copy that is not ready as it does today, whatever the state of the module’s own Claude Code'] = function()
  local modules_fake = claude.fake('copies-send-refused', 'ready')
  local modules_terminal = claude.start(child, modules_fake, { new_session = true })
  MiniTest.finally(function()
    claude.end_by_keys(child, modules_fake, modules_terminal)
  end)
  claude.wait_for_status(child, 'ready')
  make_input_of_its_own({ 'for nobody' })
  child.lua('_G.copies = { require("aineo.claude").new() }')

  local sent = child.lua(
    "return { pcall(require('aineo.send').send, { session = _G.copies[1], input = _G.input }) }"
  )

  vim.wait(NOTHING_SENT_PATIENCE_MS)
  eq(sent, { true })
  eq(child.lua_get('_G.told'), {
    { 'aineo: nothing sent — Claude has not started', vim.log.levels.WARN },
  })
  eq(lines_of_input(), { 'for nobody' })
  eq(claude.received(modules_fake):find('for nobody', 1, true), nil)
end

T['Send with a given copy and Input']['sends the selection of the given Input to the given copy’s Claude Code only'] = function()
  local first_fake, second_fake, first, second = two_ready_copies('copies-send-selection', 'ready')
  end_copy_after_case(1, first, first_fake)
  end_copy_after_case(2, second, second_fake)
  make_input_of_its_own({ 'selected for the second' })
  child.lua([[
    vim.keymap.set('x', '<Plug>(aineo-test-copy-send-selection)', function()
      require('aineo.send').send_selection({ session = _G.copies[2], input = _G.input })
    end)
    vim.api.nvim_set_current_buf(_G.input)
    vim.api.nvim_feedkeys(
      vim.keycode('ggVG<Plug>(aineo-test-copy-send-selection)'),
      'mtx',
      false
    )
  ]])

  eq(wait_until_received(second_fake, paste('selected for the second')), true)
  vim.wait(NOTHING_SENT_PATIENCE_MS)
  eq(claude.received(first_fake):find('selected for the second', 1, true), nil)
  eq(lines_of_input(), { '' })
end

return T
