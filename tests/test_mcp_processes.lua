local MiniTest = require('mini.test')
local mcp = require('aineo.mcp')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- Session ids of the form Claude Code gives.
local FIRST_SESSION_ID = 'c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31'
local SECOND_SESSION_ID = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'
local THIRD_SESSION_ID = '7d0e3a4f-8e1a-4d2f-b5c7-91d0e3a4f853'

--- The start tokens of two starts of Claude Code.
local TOKEN = '5b1c0f5e-2d7a-4c1b-9e3f-6a8d2c4b1e07'
local OTHER_TOKEN = '9e3f6a8d-2c4b-4e07-8b1c-0f5e2d7a4c1b'

--- The pid the cases record a Claude Code process under: this Neovim's, which
--- runs.
local PID = vim.fn.getpid()

--- The directory the cases' Claude Code runs in.
local WORKING_DIRECTORY = '/projects/alpha'

--- What a session hook of the start `token` told: `event` of `session`,
--- its hook begun at `ran`.
---
---@param event string
---@param session string
---@param ran integer
---@param token? string
---@return table
local function hook(event, session, ran, token)
  return {
    pid = PID,
    token = token or TOKEN,
    event = event,
    session = session,
    ran = ran,
    working_directory = WORKING_DIRECTORY,
  }
end

--- Records each of `hooks` in turn under `state`, and returns the switches
--- each record made, in order.
---
---@param state string
---@param hooks table[]
---@return table[]
local function record_all(state, hooks)
  local switches = {}
  for _, told in ipairs(hooks) do
    vim.list_extend(switches, mcp.record_session_event(state, told))
  end
  return switches
end

T['the record of a Claude Code process'] = MiniTest.new_set()

T['the record of a Claude Code process']['holds the session of its token’s first SessionStart'] = function()
  local state = fixture.directory('mcp-processes-first')

  local switches = record_all(state, { hook('SessionStart', FIRST_SESSION_ID, 1000) })

  eq({ switches, mcp.process_session(state, PID, TOKEN) }, { {}, FIRST_SESSION_ID })
end

T['the record of a Claude Code process']['moves to the session a SessionStart begins after the SessionEnd of its own, and says so'] = function()
  local state = fixture.directory('mcp-processes-switch')

  local switches = record_all(state, {
    hook('SessionStart', FIRST_SESSION_ID, 1000),
    hook('SessionEnd', FIRST_SESSION_ID, 2000),
    hook('SessionStart', SECOND_SESSION_ID, 3000),
  })

  eq(
    { switches, mcp.process_session(state, PID, TOKEN) },
    { { { left = FIRST_SESSION_ID, new = SECOND_SESSION_ID } }, SECOND_SESSION_ID }
  )
end

T['the record of a Claude Code process']['stays on its session at a SessionStart of another with no SessionEnd before it'] = function()
  local state = fixture.directory('mcp-processes-unpaired')

  local switches = record_all(state, {
    hook('SessionStart', FIRST_SESSION_ID, 1000),
    hook('SessionStart', SECOND_SESSION_ID, 2000),
  })

  eq({ switches, mcp.process_session(state, PID, TOKEN) }, { {}, FIRST_SESSION_ID })
end

T['the record of a Claude Code process']['moves when the SessionEnd is recorded after the SessionStart that began after it, and that write says so'] = function()
  local state = fixture.directory('mcp-processes-reversed')
  record_all(state, { hook('SessionStart', FIRST_SESSION_ID, 1000) })

  local by_start = mcp.record_session_event(state, hook('SessionStart', SECOND_SESSION_ID, 3000))
  local by_end = mcp.record_session_event(state, hook('SessionEnd', FIRST_SESSION_ID, 2000))

  eq({ by_start, by_end, mcp.process_session(state, PID, TOKEN) }, {
    {},
    { { left = FIRST_SESSION_ID, new = SECOND_SESSION_ID } },
    SECOND_SESSION_ID,
  })
end

T['the record of a Claude Code process']['begun by a SessionEnd pairs it with the SessionStart after it'] = function()
  local state = fixture.directory('mcp-processes-end-first')

  local switches = record_all(state, {
    hook('SessionEnd', FIRST_SESSION_ID, 1000),
    hook('SessionStart', SECOND_SESSION_ID, 2000),
  })

  eq(
    { switches, mcp.process_session(state, PID, TOKEN) },
    { { { left = FIRST_SESSION_ID, new = SECOND_SESSION_ID } }, SECOND_SESSION_ID }
  )
end

T['the record of a Claude Code process']['of another start’s token is replaced whole by a hook of this one'] = function()
  local state = fixture.directory('mcp-processes-other-token')
  record_all(state, {
    hook('SessionStart', FIRST_SESSION_ID, 1000, OTHER_TOKEN),
    hook('SessionEnd', FIRST_SESSION_ID, 2000, OTHER_TOKEN),
  })

  local switches = record_all(state, { hook('SessionStart', SECOND_SESSION_ID, 3000) })

  eq({
    switches = switches,
    session = mcp.process_session(state, PID, TOKEN),
    other = mcp.process_session(state, PID, OTHER_TOKEN),
  }, { switches = {}, session = SECOND_SESSION_ID })
end

--- The checkout, put on the 'runtimepath' of the Neovims a case starts.
local CHECKOUT = vim.fn.getcwd()

--- How long a recorder that is not held back takes to write the record once
--- it has marked its start (`record_in_another_process()`): a few
--- milliseconds on an idle host; 1.5 s leaves a loaded host room. A recorder
--- still running when it is over was held back.
local RECORDER_WRITE_MS = 1500

--- Starts a Neovim of its own that records `told` under `state`, as a hook
--- relay does, writing the file `marker` just before it records; returns it
--- with a check of whether it has started recording and one of whether it
--- has ended.
---
---@param state string
---@param told table
---@return vim.SystemObj recorder
---@return fun(): boolean has_started
---@return fun(): boolean has_ended
local function record_in_another_process(state, told)
  local script = fixture.write('mcp-processes-recorder.lua', {
    'vim.opt.runtimepath:prepend(arg[1])',
    'vim.fn.writefile({}, arg[4])',
    "require('aineo.mcp').record_session_event(arg[2], vim.json.decode(arg[3]))",
  })
  local marker = vim.fs.joinpath(state, 'recorder-started')
  local ended = false
  local recorder = vim.system({
    vim.v.progpath,
    '--headless',
    '--clean',
    '-l',
    script,
    CHECKOUT,
    state,
    vim.json.encode(told),
    marker,
  }, {}, function()
    ended = true
  end)
  return recorder,
    function()
      return vim.uv.fs_stat(marker) ~= nil
    end,
    function()
      return ended
    end
end

--- Makes the lock of the record of `PID` under `state`, as a hook holds it
--- while it writes the record: naming `holder`, its pid, and made
--- `age_seconds` ago.
---
---@param state string
---@param holder integer
---@param age_seconds integer
---@return string lock
local function hold_lock(state, holder, age_seconds)
  local lock = vim.fs.joinpath(state, 'aineo', 'claude-processes', ('%d.lock'):format(PID))
  local descriptor = assert(vim.uv.fs_open(lock, 'wx', tonumber('600', 8)))
  vim.uv.fs_write(descriptor, tostring(holder))
  vim.uv.fs_close(descriptor)
  local made = os.time() - age_seconds
  assert(vim.uv.fs_utime(lock, made, made))
  return lock
end

T['the record of a Claude Code process']['is written by one hook at a time: a hook waits while another holds the record, however long it holds it'] = function()
  local state = fixture.directory('mcp-processes-lock')
  record_all(state, { hook('SessionStart', FIRST_SESSION_ID, 1000) })
  local lock = hold_lock(state, vim.fn.getpid(), 5)

  local recorder, has_started, has_ended =
    record_in_another_process(state, hook('SessionEnd', FIRST_SESSION_ID, 2000))
  local started = vim.wait(10000, has_started, 10)
  local done_while_held = vim.wait(RECORDER_WRITE_MS, has_ended, 10)
  vim.uv.fs_unlink(lock)
  local ended = recorder:wait(5000)
  local switches = record_all(state, { hook('SessionStart', SECOND_SESSION_ID, 3000) })

  eq({ started, done_while_held, ended.code, switches }, {
    true,
    false,
    0,
    { { left = FIRST_SESSION_ID, new = SECOND_SESSION_ID } },
  })
end

T['the record of a Claude Code process']['is written past a lock whose hook has ended'] = function()
  local state = fixture.directory('mcp-processes-lock-ended')
  record_all(state, { hook('SessionStart', FIRST_SESSION_ID, 1000) })
  local ended_holder = vim.system({ 'true' })
  ended_holder:wait()
  hold_lock(state, ended_holder.pid, 0)

  local recorder = record_in_another_process(state, hook('SessionEnd', FIRST_SESSION_ID, 2000))
  local ended = recorder:wait(5000)

  eq({ ended.code, mcp.process_session(state, PID, TOKEN) }, { 0, FIRST_SESSION_ID })
end

--- What the report server of the start `token` records at its start: its
--- Claude Code process, its own first session and its directory.
---
---@param session string
---@param token? string
---@return table
local function server_start(session, token)
  return {
    pid = PID,
    token = token or TOKEN,
    session = session,
    working_directory = WORKING_DIRECTORY,
  }
end

T['the record of a Claude Code process']['is written by the report server at its start when there is none'] = function()
  local state = fixture.directory('mcp-processes-server')

  mcp.record_server_start(state, server_start(FIRST_SESSION_ID))

  eq(mcp.process_session(state, PID, TOKEN), FIRST_SESSION_ID)
end

T['the record of a Claude Code process']['written by a hook is left as it is by the report server, whichever session it holds'] = function()
  local state = fixture.directory('mcp-processes-server-after-hooks')
  record_all(state, {
    hook('SessionStart', FIRST_SESSION_ID, 1000),
    hook('SessionEnd', FIRST_SESSION_ID, 2000),
    hook('SessionStart', SECOND_SESSION_ID, 3000),
  })

  mcp.record_server_start(state, server_start(FIRST_SESSION_ID))

  eq(mcp.process_session(state, PID, TOKEN), SECOND_SESSION_ID)
end

T['the record of a Claude Code process']['of another start’s token is replaced by the report server’s'] = function()
  local state = fixture.directory('mcp-processes-server-other-token')
  record_all(state, { hook('SessionStart', SECOND_SESSION_ID, 1000, OTHER_TOKEN) })

  mcp.record_server_start(state, server_start(FIRST_SESSION_ID))

  eq(
    { mcp.process_session(state, PID, TOKEN), mcp.process_session(state, PID, OTHER_TOKEN) },
    { FIRST_SESSION_ID, nil }
  )
end

T['the record of a Claude Code process']['written by the report server moves to the session of its start’s first SessionStart'] = function()
  local state = fixture.directory('mcp-processes-hook-after-server')
  mcp.record_server_start(state, server_start(FIRST_SESSION_ID))

  local switches = record_all(state, { hook('SessionStart', SECOND_SESSION_ID, 3000) })

  eq({ switches, mcp.process_session(state, PID, TOKEN) }, { {}, SECOND_SESSION_ID })
end

--- The pid of a process that has ended.
---
---@return integer
local function ended_pid()
  local process = vim.system({ 'true' })
  process:wait()
  return process.pid
end

T['the record of a Claude Code process']['of another start’s token is no record of this start’s, and is removed when read'] = function()
  local state = fixture.directory('mcp-processes-stale')
  record_all(state, { hook('SessionStart', SECOND_SESSION_ID, 1000, OTHER_TOKEN) })

  local session = mcp.process_session(state, PID, TOKEN)

  eq({
    session = session,
    file = vim.uv.fs_stat(
      vim.fs.joinpath(state, 'aineo', 'claude-processes', ('%d.json'):format(PID))
    ),
  }, {})
end

T['the running sessions'] = MiniTest.new_set()

T['the running sessions']['are those of the records of this directory whose process runs, the others’ records of ended processes removed'] = function()
  local state = fixture.directory('mcp-processes-running')
  local ended = ended_pid()
  mcp.record_server_start(state, server_start(FIRST_SESSION_ID))
  mcp.record_server_start(state, {
    pid = ended,
    token = OTHER_TOKEN,
    session = SECOND_SESSION_ID,
    working_directory = WORKING_DIRECTORY,
  })
  mcp.record_server_start(state, {
    pid = vim.uv.os_getppid(),
    token = OTHER_TOKEN,
    session = THIRD_SESSION_ID,
    working_directory = '/projects/beta',
  })

  local running = mcp.running_sessions(state, WORKING_DIRECTORY)

  eq({
    running = running,
    ended_record = vim.uv.fs_stat(
      vim.fs.joinpath(state, 'aineo', 'claude-processes', ('%d.json'):format(ended))
    ),
  }, { running = { FIRST_SESSION_ID } })
end

T['the running sessions']['lose the records of ended processes at each report server’s start'] = function()
  local state = fixture.directory('mcp-processes-server-prunes')
  local ended = ended_pid()
  record_all(state, {
    {
      pid = ended,
      token = OTHER_TOKEN,
      event = 'SessionStart',
      session = SECOND_SESSION_ID,
      ran = 1000,
      working_directory = WORKING_DIRECTORY,
    },
  })

  mcp.record_server_start(state, server_start(FIRST_SESSION_ID))

  eq(
    vim.uv.fs_stat(vim.fs.joinpath(state, 'aineo', 'claude-processes', ('%d.json'):format(ended))),
    nil
  )
end

T['the record of a Claude Code process']['follows two switches whose hooks are recorded out of order'] = function()
  local state = fixture.directory('mcp-processes-two-switches')
  record_all(state, { hook('SessionStart', FIRST_SESSION_ID, 1000) })

  local switches = record_all(state, {
    hook('SessionStart', THIRD_SESSION_ID, 5000),
    hook('SessionEnd', SECOND_SESSION_ID, 4000),
    hook('SessionStart', SECOND_SESSION_ID, 3000),
    hook('SessionEnd', FIRST_SESSION_ID, 2000),
  })

  eq({ switches, mcp.process_session(state, PID, TOKEN) }, {
    {
      { left = FIRST_SESSION_ID, new = SECOND_SESSION_ID },
      { left = SECOND_SESSION_ID, new = THIRD_SESSION_ID },
    },
    THIRD_SESSION_ID,
  })
end

--- Runs `work` with `vim.uv.fs_link` refusing every link, as a file system
--- without hard links does; returns whether `work` raised nothing.
---
---@param work fun()
---@return boolean
local function with_links_refused(work)
  local link = vim.uv.fs_link
  vim.uv.fs_link = function()
    return nil, 'EPERM: operation not permitted', 'EPERM'
  end
  local worked = pcall(work)
  vim.uv.fs_link = link
  return worked
end

T['the record of a Claude Code process']['is not written by the report server where the file system refuses hard links'] = function()
  local state = fixture.directory('mcp-processes-links-refused')

  local worked = with_links_refused(function()
    mcp.record_server_start(state, server_start(FIRST_SESSION_ID))
  end)

  eq({ worked, mcp.process_session(state, PID, TOKEN) }, { true, nil })
end

T['the record of a Claude Code process']['written by a hook is left as it is by the report server where the file system refuses hard links'] = function()
  local state = fixture.directory('mcp-processes-links-refused-hooked')
  record_all(state, {
    hook('SessionStart', FIRST_SESSION_ID, 1000),
    hook('SessionEnd', FIRST_SESSION_ID, 2000),
    hook('SessionStart', SECOND_SESSION_ID, 3000),
  })

  local worked = with_links_refused(function()
    mcp.record_server_start(state, server_start(FIRST_SESSION_ID))
  end)

  eq({ worked, mcp.process_session(state, PID, TOKEN) }, { true, SECOND_SESSION_ID })
end

--- The permission bits of the records' folder under `state`, as octal
--- digits.
---
---@param state string
---@return string
local function records_folder_mode(state)
  return ('%o'):format(
    vim.uv.fs_stat(vim.fs.joinpath(state, 'aineo', 'claude-processes')).mode % 512
  )
end

T['the record of a Claude Code process']['lives in a folder only the user can enter, written by a hook or by the report server'] = function()
  local by_hook = fixture.directory('mcp-processes-mode-hook')
  local by_server = fixture.directory('mcp-processes-mode-server')

  record_all(by_hook, { hook('SessionStart', FIRST_SESSION_ID, 1000) })
  mcp.record_server_start(by_server, server_start(FIRST_SESSION_ID))

  eq({ records_folder_mode(by_hook), records_folder_mode(by_server) }, { '700', '700' })
end

T['the running sessions']['leave out a record whose pid another user’s process took'] = function()
  local state = fixture.directory('mcp-processes-eperm')
  mcp.record_server_start(state, {
    pid = 1,
    token = OTHER_TOKEN,
    session = SECOND_SESSION_ID,
    working_directory = WORKING_DIRECTORY,
  })

  eq(mcp.running_sessions(state, WORKING_DIRECTORY), {})
end

return T
