local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude_session = dofile('tests/helpers/claude_session.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

--- An entry of `claude agents --json` for an interactive session that runs,
--- as Claude Code 2.1.296 documents it (`id` and `state` are a background
--- session's).
---
---@param overrides? table
---@return table
local function running_entry(overrides)
  return vim.tbl_extend('force', {
    cwd = '/work/project',
    kind = 'interactive',
    startedAt = 1790000000000,
    sessionId = '11111111-1111-4111-8111-111111111111',
    name = 'refactor',
    pid = 4242,
    status = 'idle',
  }, overrides or {})
end

--- An entry of `claude agents --json` for a background session whose process
--- has ended, as the user's M7 showed one: no `pid` and no `status`.
---
---@param overrides? table
---@return table
local function ended_background_entry(overrides)
  return vim.tbl_extend('force', {
    id = 'a1b2c3d4',
    cwd = '/work/project',
    kind = 'background',
    startedAt = 1790000100000,
    sessionId = '22222222-2222-4222-8222-222222222222',
    name = 'tests',
    state = 'blocked',
  }, overrides or {})
end

--- A fake `claude` for one case that answers `agents --json` with `entries`,
--- written as the JSON array the fake prints, and the extra environment
--- `extra_environment` names.
---
---@param name string the case's own name for its files
---@param entries table[]|string the entries, or the text the fake prints as it is
---@param extra_environment? table<string, string>
---@return { record: string, environment: table<string, string> }
local function fake_listing(name, entries, extra_environment)
  local fake = claude_session.fake(name, 'ready', extra_environment)
  local listing = vim.fs.joinpath(vim.fs.dirname(fake.record), 'agents.json')
  assert(
    vim.fn.writefile({ type(entries) == 'string' and entries or vim.json.encode(entries) }, listing)
      == 0,
    'cannot write ' .. listing
  )
  fake.environment.AINEO_FAKE_CLAUDE_AGENTS = listing
  return fake
end

--- Lists the folder's sessions in the child through the Claude home with
--- `fake`'s environment and the fake as `claude.cmd` followed by `extra_words`,
--- waits for the answer, and returns it.
---
---@param fake { environment: table<string, string> }
---@param folder string
---@param command? string[] replaces the fake as `claude.cmd`
---@return { sessions: table[]?, problem: string? }
local function list_sessions(fake, folder, command)
  return child.lua(
    [[
      local environment, command, folder = ...
      for name, value in pairs(environment) do
        vim.env[name] = value
      end
      local answer
      require('aineo.claude').list_sessions(command, folder, function(sessions, problem)
        answer = { sessions = sessions, problem = problem }
      end)
      vim.wait(10000, function()
        return answer ~= nil
      end, 20)
      return answer
    ]],
    { fake.environment, command or claude_session.fake_command(), folder }
  )
end

T['a listed session'] = MiniTest.new_set()

--- The session of the child's own terminal in these cases.
local OWN_SESSION_ID = '99999999-9999-4999-8999-999999999999'

--- The folder the rows are listed for in these cases.
local FOLDER = '/work/project'

--- A session as `list_sessions()` delivers it, running elsewhere.
local RUNNING_ELSEWHERE = {
  session_id = '11111111-1111-4111-8111-111111111111',
  name = 'refactor',
  kind = 'interactive',
  status = 'idle',
  running = true,
  cwd = FOLDER,
}

--- `RUNNING_ELSEWHERE` with `overrides` on top.
---
---@param overrides table
---@return table
local function running_elsewhere_with(overrides)
  return vim.tbl_extend('force', RUNNING_ELSEWHERE, overrides)
end

T['a listed session']['row'] = MiniTest.new_set({
  parametrize = {
    { RUNNING_ELSEWHERE, 'refactor  interactive  idle  [running elsewhere]' },
    {
      running_elsewhere_with({ session_id = OWN_SESSION_ID }),
      'refactor  interactive  idle  [this terminal]',
    },
    {
      {
        session_id = RUNNING_ELSEWHERE.session_id,
        status = 'blocked',
        kind = 'background',
        cwd = FOLDER,
      },
      '11111111  background  blocked',
    },
    { { session_id = RUNNING_ELSEWHERE.session_id, name = 'tests', cwd = FOLDER }, 'tests' },
    {
      { session_id = RUNNING_ELSEWHERE.session_id, name = 'tests', cwd = '/work/other' },
      'tests  [another folder]',
    },
  },
})

T['a listed session']['row']['names the session, its kind and its status, and marks it'] = function(
  listed,
  expected
)
  eq(
    child.lua_get("require('aineo.claude').session_row(...)", { listed, OWN_SESSION_ID, FOLDER }),
    expected
  )
end

T['a listed session']['standing'] = MiniTest.new_set({
  parametrize = {
    { running_elsewhere_with({ session_id = OWN_SESSION_ID }), 'own' },
    { RUNNING_ELSEWHERE, 'elsewhere' },
    {
      { session_id = RUNNING_ELSEWHERE.session_id, kind = 'background', cwd = FOLDER },
      'switchable',
    },
    {
      { session_id = RUNNING_ELSEWHERE.session_id, kind = 'background', cwd = '/work/other' },
      'another_folder',
    },
    { { session_id = RUNNING_ELSEWHERE.session_id, kind = 'background' }, 'another_folder' },
    {
      running_elsewhere_with({ session_id = OWN_SESSION_ID, cwd = '/work/other' }),
      'own',
    },
  },
})

T['a listed session']['standing']['tells whether a pick may switch to it'] = function(
  listed,
  expected
)
  eq(
    child.lua_get(
      "require('aineo.claude').session_standing(...)",
      { listed, OWN_SESSION_ID, FOLDER }
    ),
    expected
  )
end

T['the session’s directory'] = MiniTest.new_set()

T['the session’s directory']['is none before a session has started'] = function()
  eq(child.lua_get("require('aineo.claude').session_directory()"), vim.NIL)
end

T['the session’s directory']['is the directory Claude Code started in, whatever :cd did since'] = function()
  local fake = claude_session.fake('agents-directory', 'ready')
  local started_in = child.fn.getcwd()
  claude_session.start(child, fake)
  child.cmd('cd /')

  eq(child.lua_get("require('aineo.claude').session_directory()"), started_in)
end

T['the listing'] = MiniTest.new_set()

T['the listing']['asks claude.cmd for agents --json scoped to the folder, finished sessions included'] = function()
  local fake = fake_listing('agents-argv', { running_entry() })

  list_sessions(fake, '/work/project')

  local asked = vim
    .iter(claude_session.record(fake))
    :map(function(entry)
      return entry.argv
    end)
    :totable()
  eq(asked, { { 'agents', '--json', '--cwd', '/work/project', '--all' } })
end

T['the listing']['delivers each session that carries an id, a running one and an ended background one, and drops the rest'] = function()
  local fake = fake_listing('agents-entries', {
    running_entry(),
    ended_background_entry(),
    {
      cwd = '/work/project',
      kind = 'interactive',
      startedAt = 1790000200000,
      pid = 7,
      status = 'busy',
    },
  })

  local answer = list_sessions(fake, '/work/project')

  eq(answer, {
    sessions = {
      {
        session_id = '11111111-1111-4111-8111-111111111111',
        name = 'refactor',
        kind = 'interactive',
        status = 'idle',
        running = true,
        cwd = '/work/project',
      },
      {
        session_id = '22222222-2222-4222-8222-222222222222',
        name = 'tests',
        kind = 'background',
        status = 'blocked',
        cwd = '/work/project',
      },
    },
  })
end

T['the listing']['says so when claude.cmd exits with a failure'] = function()
  local fake = fake_listing('agents-exit', {}, { AINEO_FAKE_CLAUDE_AGENTS_EXIT = '3' })

  local answer = list_sessions(fake, '/work/project')

  eq(answer, { problem = 'claude agents --json exited with 3' })
end

T['the listing']['says so when claude.cmd prints what is not JSON'] = function()
  local fake = fake_listing('agents-not-json', 'No sessions yet.')

  local answer = list_sessions(fake, '/work/project')

  eq(answer, { problem = 'claude agents --json printed something that is not JSON' })
end

T['the listing']['keeps the fields of an entry that have the type Claude Code documents, and skips an entry that is not an object'] = function()
  local fake = fake_listing(
    'agents-malformed',
    '[null, 5, "text", {"sessionId": 7}, {"sessionId": "33333333-3333-4333-8333-333333333333",'
      .. ' "name": null, "kind": "interactive", "status": 5, "state": "blocked", "pid": "4242"}]'
  )

  local answer = list_sessions(fake, '/work/project')

  eq(answer, {
    sessions = {
      {
        session_id = '33333333-3333-4333-8333-333333333333',
        kind = 'interactive',
        status = 'blocked',
        running = true,
      },
    },
  })
end

T['the listing']['keeps an entry running when it has a pid or a status, whatever their types'] = function()
  local fake = fake_listing(
    'agents-running',
    '[{"sessionId": "11111111-1111-4111-8111-111111111111", "pid": "4242"},'
      .. ' {"sessionId": "22222222-2222-4222-8222-222222222222", "status": 5},'
      .. ' {"sessionId": "33333333-3333-4333-8333-333333333333", "pid": null, "state": "blocked"}]'
  )

  local answer = list_sessions(fake, '/work/project')

  eq(answer, {
    sessions = {
      { session_id = '11111111-1111-4111-8111-111111111111', running = true },
      { session_id = '22222222-2222-4222-8222-222222222222', running = true },
      { session_id = '33333333-3333-4333-8333-333333333333', status = 'blocked' },
    },
  })
end

T['the listing']['drops an entry whose session id is not a session id, whatever else it holds'] = function()
  local fake = fake_listing(
    'agents-bad-ids',
    '[{"sessionId": "x\\r!touch pwned\\r", "kind": "background", "state": "blocked"},'
      .. ' {"sessionId": "not-a-uuid"},'
      .. ' {"sessionId": "11111111-1111-1111-8111-111111111111"},'
      .. ' {"sessionId": "22222222-2222-4222-8222-222222222222"}]'
  )

  local answer = list_sessions(fake, '/work/project')

  eq(answer, { sessions = { { session_id = '22222222-2222-4222-8222-222222222222' } } })
end

T['the listing']['adds the first line claude.cmd writes to its standard error to a failure'] = function()
  local fake = fake_listing('agents-stderr', {})
  local failing = { 'sh', '-c', 'echo "unknown option --add-dir" >&2; exit 2', 'sh' }

  local answer = list_sessions(fake, '/work/project', failing)

  eq(answer, { problem = 'claude agents --json exited with 2: unknown option --add-dir' })
end

T['the listing']['says so when claude.cmd is ended by a signal'] = function()
  local fake = fake_listing('agents-signal', {})
  local killed = { 'sh', '-c', 'kill -9 $$', 'sh' }

  local answer = list_sessions(fake, '/work/project', killed)

  eq(answer, { problem = 'claude agents --json was ended by signal 9' })
end

T['the listing']['says so when claude.cmd cannot be run'] = function()
  local fake = fake_listing('agents-missing', {})

  local answer = list_sessions(fake, '/work/project', { '/nonexistent/aineo-claude' })

  eq(answer, {
    problem = "could not run claude agents --json: ENOENT: no such file or directory (cmd): '/nonexistent/aineo-claude'",
  })
end

--- Whether the process `pid` runs.
---
---@param pid integer
---@return boolean
local function process_runs(pid)
  return vim.uv.kill(pid, 0) == 0
end

--- The process ids a script of `listing_stuck_command()` wrote, once both
--- files hold one.
---
---@param pidfile string
---@return integer[]
local function written_pids(pidfile)
  vim.wait(5000, function()
    return vim.fn.filereadable(pidfile .. '.child') == 1
      and #vim.fn.readfile(pidfile .. '.child') > 0
  end, 20)
  return {
    tonumber(vim.fn.readfile(pidfile)[1]),
    tonumber(vim.fn.readfile(pidfile .. '.child')[1]),
  }
end

--- A `claude.cmd` that never answers: a shell that writes its own process id
--- to `pidfile` and its child's to `pidfile .. '.child'`, and waits for the
--- child.
---
---@param pidfile string
---@return string[]
local function listing_stuck_command(pidfile)
  return { 'sh', '-c', 'sleep 30 & echo $$ > "$0"; echo $! > "$0.child"; wait', pidfile }
end

T['the listing']['stops a claude.cmd that does not answer within 5 s, with every process of its group'] = function()
  local fake = fake_listing('agents-stuck', {})
  local pidfile = vim.fs.joinpath(vim.fs.dirname(fake.record), 'stuck.pid')

  local answer = list_sessions(fake, '/work/project', listing_stuck_command(pidfile))

  eq(answer, { problem = 'claude agents --json did not finish within 5 s' })
  local pids = written_pids(pidfile)
  vim.wait(2000, function()
    return not process_runs(pids[1]) and not process_runs(pids[2])
  end, 20)
  eq({ process_runs(pids[1]), process_runs(pids[2]) }, { false, false })
end

T['the listing']['stops a claude.cmd that prints more than 1 MiB'] = function()
  local fake = fake_listing('agents-endless', {})
  local pidfile = vim.fs.joinpath(vim.fs.dirname(fake.record), 'endless.pid')
  local endless = { 'sh', '-c', 'echo $$ > "$0"; exec yes', pidfile }

  local answer = list_sessions(fake, '/work/project', endless)

  eq(answer, { problem = 'claude agents --json printed more than 1048576 bytes' })
  local pid = tonumber(vim.fn.readfile(pidfile)[1])
  vim.wait(2000, function()
    return not process_runs(pid)
  end, 20)
  eq(process_runs(pid), false)
end

T['the listing']['stops a claude.cmd still running when the editor quits'] = function()
  local fake = fake_listing('agents-quit', {})
  local pidfile = vim.fs.joinpath(vim.fs.dirname(fake.record), 'quit.pid')
  child.lua(
    [[
      local command, folder = ...
      require('aineo.claude').list_sessions(command, folder, function() end)
    ]],
    { listing_stuck_command(pidfile), '/work/project' }
  )
  local pids = written_pids(pidfile)

  child.stop()

  vim.wait(2000, function()
    return not process_runs(pids[1]) and not process_runs(pids[2])
  end, 20)
  eq({ process_runs(pids[1]), process_runs(pids[2]) }, { false, false })
end

T['the listing']['kills no process group once its process has ended, when the editor quits before the cleanup'] = function()
  local kills_sent = child.lua([[
    local kills = {}
    local real_kill = vim.uv.kill
    vim.uv.kill = function(pid, signal)
      if signal == 'sigkill' then
        table.insert(kills, pid)
      end
      return real_kill(pid, signal)
    end
    local held = {}
    local real_schedule = vim.schedule
    vim.schedule = function(callback)
      table.insert(held, callback)
    end
    require('aineo.claude').list_sessions({ 'sh', '-c', 'exit 0' }, '/tmp', function() end)
    vim.wait(2000, function()
      return #held > 0
    end, 10)
    vim.api.nvim_exec_autocmds('VimLeavePre', {})
    vim.schedule = real_schedule
    vim.uv.kill = real_kill
    for _, callback in ipairs(held) do
      callback()
    end
    return #kills
  ]])

  eq(kills_sent, 0)
end

T['the listing']['JSON that is not a list'] = MiniTest.new_set({
  parametrize = { { '{"sessions": []}' }, { 'null' }, { '"sessions"' }, { '42' }, { 'true' } },
})

T['the listing']['JSON that is not a list']['is told as such'] = function(printed)
  local fake = fake_listing('agents-not-a-list', printed)

  local answer = list_sessions(fake, '/work/project')

  eq(answer, { problem = 'claude agents --json printed JSON that is not a list of sessions' })
end

return T
