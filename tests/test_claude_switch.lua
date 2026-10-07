local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude = dofile('tests/helpers/claude_session.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- The settings overrides that make a session keep its id under the state
--- directory `.tests/fixtures/<name>`, emptied, with `extra` on top.
---
---@param name string
---@param extra? table
---@return table
local function kept_in(name, extra)
  return vim.tbl_extend('force', { state_directory = fixture.directory(name) }, extra or {})
end

--- `hook_settings`, the `--settings` a start was given, decoded, with the
--- command of every hook replaced by the word `command`: its shape.
---
---@param hook_settings table
---@return table
local function shape_of(hook_settings)
  local shape = vim.deepcopy(hook_settings)
  for _, entries in pairs(shape.hooks or {}) do
    for _, entry in ipairs(entries) do
      for _, hook in ipairs(entry.hooks or {}) do
        hook.command = type(hook.command) == 'string' and 'command' or hook.command
      end
    end
  end
  return shape
end

--- What every `--settings` word of `argv` gives, in order: the word after a
--- `--settings`, and what follows `--settings=` in one word.
---
---@param argv string[]
---@return string[]
local function settings_given(argv)
  local given = {}
  for index, word in ipairs(argv) do
    if word == '--settings' then
      table.insert(given, argv[index + 1])
    elseif vim.startswith(word, '--settings=') then
      table.insert(given, word:sub(#'--settings=' + 1))
    end
  end
  return given
end

--- The settings in the file at `path`, decoded.
---
---@param path string
---@return table
local function settings_in_file(path)
  return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
end

--- The shape of aineo's own hooks in its `--settings` (`shape_of()`): a
--- `SessionStart` and a `SessionEnd` command hook, with no matcher.
local AINEO_HOOKS_SHAPE = {
  SessionStart = { { hooks = { { type = 'command', command = 'command', timeout = 5 } } } },
  SessionEnd = { { hooks = { { type = 'command', command = 'command', timeout = 5 } } } },
}

--- What aineo tells the user when it cannot add its hooks to a `--settings`
--- of `claude.cmd`, as `NOTE_NOTIFICATIONS` keeps it: one line of 60
--- characters, which fits an 80-column screen at startup.
local UNREAD_SETTINGS_WARNINGS = {
  {
    message = "aineo: claude.cmd's --settings unread; switches not followed",
    level = vim.log.levels.WARN,
  },
}

--- The Lua, run in a child, that keeps every notification from then on in
--- `_G.notified`, as `{ message, level }`, rather than showing it.
local NOTE_NOTIFICATIONS = [[
  _G.notified = {}
  vim.notify = function(message, level)
    table.insert(_G.notified, { message = message, level = level })
  end
]]

--- The Lua, run in a child, that keeps every notification
--- (`NOTE_NOTIFICATIONS`), starts the session with the stand-in settings
--- overridden by `...` and an `on_session_switched` that raises, shows its
--- terminal in the current window, and returns whether `start_session()`
--- raised nothing, as `started`, and the notifications by then.
local START_WITH_RAISING_CALLBACK = NOTE_NOTIFICATIONS
  .. [[
  local helper = dofile('tests/helpers/claude_session.lua')
  local settings = helper.stand_in_settings(...)
  settings.on_session_switched = function()
    error('a callback that raises', 0)
  end
  local started, terminal = pcall(require('aineo.claude').start_session, settings)
  if started then
    vim.api.nvim_win_set_buf(0, terminal)
  end
  return { started = started, notified = _G.notified }
]]

--- What aineo tells the user when the `on_session_switched` of
--- `START_WITH_RAISING_CALLBACK` raises.
local RAISED_WARNING = 'aineo: on_session_switched failed: a callback that raises'

--- The hook relay, as the checkout holds it.
local HOOK_RELAY = vim.fs.joinpath(vim.fn.getcwd(), 'lua', 'aineo', 'claude', 'hook_relay.lua')

--- Session ids of the form Claude Code gives.
local CLAUDE_SESSION_ID = 'c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31'
local OTHER_SESSION_ID = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'
local THIRD_SESSION_ID = '7d0e3a4f-8e1a-4d2f-b5c7-91d0e3a4f853'

--- The Lua, run in a Neovim, that stands in for the claude home where the
--- hook relay's notification lands: it keeps the event, the session, the
--- source or reason and the start token of each call of
--- `receive_session_event()` in `_G.session_events`, and the time its hook
--- ran, its fifth argument, at the same index of `_G.hook_times`.
local NOTE_SESSION_EVENTS = [[
  _G.session_events = {}
  _G.hook_times = {}
  package.loaded['aineo.claude'] = {
    receive_session_event = function(event, session_id, cause, start_token, ran)
      table.insert(_G.session_events, { event, session_id, cause, start_token })
      _G.hook_times[#_G.session_events] = ran
    end,
  }
]]

local hook_input = claude.hook_input

--- Runs the hook relay for `event` as aineo's hook does, telling the editor
--- at `address` with the start token `token`, `input` on its stdin, with
--- `options` for `vim.system()`; returns how it ended, once it has.
---
---@param address string
---@param token string
---@param event string
---@param input string
---@param options? table
---@return vim.SystemCompleted
local function run_relay(address, token, event, input, options)
  local command = {
    vim.v.progpath,
    '--headless',
    '--clean',
    '--cmd',
    'set noloadplugins',
    '-l',
    HOOK_RELAY,
    address,
    token,
    event,
  }
  local relay_options = vim.tbl_extend('force', { stdin = input }, options or {})
  return vim.system(command, relay_options):wait(claude.PATIENCE_MS)
end

--- The calls `NOTE_SESSION_EVENTS` noted in `editor`, once there are
--- `count` of them, waiting for that at most `claude.PATIENCE_MS`.
---
---@param editor table
---@param count integer
---@return any[][]
local function wait_for_session_events(editor, count)
  local events
  vim.wait(claude.PATIENCE_MS, function()
    events = editor.lua_get('_G.session_events')
    return #events >= count
  end, 20)
  return events
end

--- Runs the hooks of the fake's `count`th start for a switch, as Claude Code
--- 2.1.292 ran them (M1): the `SessionEnd` of `from` with `reason`, then the
--- `SessionStart` of `to` with `source`, each once the last has ended.
---
---@param child table
---@param fake { record: string }
---@param count integer
---@param switch { from: string, to: string, source: string, reason: string }
local function switch_by_hooks(child, fake, count, switch)
  claude.run_session_hook(
    child,
    fake,
    count,
    'SessionEnd',
    hook_input('SessionEnd', switch.from, switch.reason)
  )
  claude.run_session_hook(
    child,
    fake,
    count,
    'SessionStart',
    hook_input('SessionStart', switch.to, switch.source)
  )
end

--- Calls, in `child`, `aineo.claude`'s `receive_session_event()` with
--- each of `calls` in order, as deliverers reaching the editor in that order
--- would, then waits until the work they scheduled has run.
---
---@param child table
---@param calls any[][] each the arguments of one call
local function receive_in_order(child, calls)
  child.lua(
    [[
      for _, call in ipairs(...) do
        require('aineo.claude').receive_session_event(unpack(call))
      end
    ]],
    { calls }
  )
  claude.wait_for_deliveries(child)
end

--- Forwards everything `from` reads to `to` once `open()` is called — what
--- comes before is held — and closes `to` when `from` ends.
---
---@param from uv.uv_pipe_t
---@param to uv.uv_pipe_t
---@return fun() open
local function forward_when_open(from, to)
  local held, is_open = {}, false
  from:read_start(function(_, data)
    if not data then
      if not to:is_closing() then
        to:close()
      end
    elseif is_open then
      to:write(data)
    else
      table.insert(held, data)
    end
  end)
  return function()
    is_open = true
    for _, data in ipairs(held) do
      to:write(data)
    end
  end
end

--- Listens, in this Neovim, on the local socket `address` and forwards each
--- connection both ways to the editor at `target`, holding what the first
--- connection sends for `delay_ms` — as the deliverer of a hook the system
--- started late would send it. Stops when the case ends.
---
---@param address string
---@param target string
---@param delay_ms integer
local function hold_first_connection(address, target, delay_ms)
  local server = assert(vim.uv.new_pipe(false))
  local handles = { server }
  MiniTest.finally(function()
    for _, handle in ipairs(handles) do
      if not handle:is_closing() then
        handle:close()
      end
    end
  end)
  local accepted = 0
  assert(server:bind(address))
  assert(server:listen(16, function()
    accepted = accepted + 1
    local delay = accepted == 1 and delay_ms or 0
    local client, upstream = assert(vim.uv.new_pipe(false)), assert(vim.uv.new_pipe(false))
    vim.list_extend(handles, { client, upstream })
    server:accept(client)
    local open_upstream = forward_when_open(client, upstream)
    upstream:connect(target, function()
      forward_when_open(upstream, client)()
      vim.defer_fn(open_upstream, delay)
    end)
  end))
end

--- An RPC channel to the Neovim that listens on the local socket
--- `address`, once it accepts a connection, waiting for that at most
--- `claude.PATIENCE_MS`: its socket file is there from before it listens,
--- when a connection is refused. Raises the last refusal when the wait runs
--- out.
---
---@param address string
---@return integer channel
local function connect_when_listening(address)
  local connected, channel
  vim.wait(claude.PATIENCE_MS, function()
    connected, channel = pcall(vim.fn.sockconnect, 'pipe', address, { rpc = true })
    return connected
  end, 20)
  return connected and channel or error(channel, 0)
end

--- The id the fake's first start was started on, as a new session.
---
---@param fake { record: string }
---@return string
local function first_session_id(fake)
  return claude.words_after(claude.arguments(fake), '--session-id')[1]
end

--- The `event` hooks the fake has run, in order, each `{ hook, session_id,
--- cause, code }`, once there are `count` of them — waiting for that at most
--- `claude.PATIENCE_MS` — or when the wait runs out.
---
---@param fake { record: string }
---@param event string
---@param count integer
---@return table[]
local function wait_for_hook_runs(fake, event, count)
  local runs
  vim.wait(claude.PATIENCE_MS, function()
    runs = vim.tbl_filter(function(entry)
      return entry.hook == event
    end, claude.record(fake))
    return #runs >= count
  end, 20)
  return runs
end

--- The source or reason of each `event` hook the fake has run, in order,
--- once there are `count` of them, or when the wait runs out
--- (`wait_for_hook_runs()`).
---
---@param fake { record: string }
---@param event string
---@param count integer
---@return string[]
local function wait_for_hook_causes(fake, event, count)
  return vim.tbl_map(function(run)
    return run.cause
  end, wait_for_hook_runs(fake, event, count))
end

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

T['start_session()'] = MiniTest.new_set()

T['start_session()']['gives Claude Code a SessionStart and a SessionEnd command hook as --settings, and no other setting'] = function()
  local fake = claude.fake('switch-settings', 'exit')

  claude.start(child, fake, kept_in('switch-settings-state'))

  local given = claude.decoded_words_after(claude.arguments(fake), '--settings')
  eq(vim.tbl_map(shape_of, given), { { hooks = AINEO_HOOKS_SHAPE } })
end

--- Settings of the user's own, as a `--settings` of `claude.cmd` gives them.
local USER_SETTINGS = '{"permissions":{"deny":["Bash(rm:*)"]},"env":{}}'

T['start_session()']['adds its hooks to the settings that claude.cmd gives, and passes one --settings'] =
  MiniTest.new_set({
    parametrize = {
      {
        'in a file',
        function(file)
          return { '--settings', file }
        end,
      },
      {
        'in a file named from the working directory',
        function()
          return { '--settings', 'settings.json' }
        end,
      },
      {
        'as JSON',
        function()
          return { '--settings', USER_SETTINGS }
        end,
      },
      {
        'as JSON joined to the flag',
        function()
          return { '--settings=' .. USER_SETTINGS }
        end,
      },
      {
        'as JSON with blanks around it',
        function()
          return { '--settings', ' ' .. USER_SETTINGS .. '\n' }
        end,
      },
    },
  })

T['start_session()']['adds its hooks to the settings that claude.cmd gives, and passes one --settings']['given'] = function(
  _,
  words_for
)
  local directory = fixture.directory('switch-user-settings')
  local file = vim.fs.joinpath(directory, 'settings.json')
  vim.fn.writefile({ USER_SETTINGS }, file)
  local fake = claude.fake('switch-user-settings', 'exit')
  local cmd = claude.fake_command(words_for(file))
  child.lua(NOTE_NOTIFICATIONS)

  claude.start(child, fake, kept_in('switch-user-settings-state', { cmd = cmd, cwd = directory }))

  local given = settings_given(claude.arguments(fake))
  eq({ #given, child.lua_get('_G.notified') }, { 1, {} })
  eq(shape_of(settings_in_file(given[1])), {
    permissions = { deny = { 'Bash(rm:*)' } },
    env = {},
    hooks = AINEO_HOOKS_SHAPE,
  })
end

T['start_session()']['leaves no word of the --settings of claude.cmd before the session’s'] =
  MiniTest.new_set({
    parametrize = {
      {
        'in a file',
        function(file)
          return { '--settings', file }
        end,
      },
      {
        'as JSON',
        function()
          return { '--settings', USER_SETTINGS }
        end,
      },
      {
        'as JSON joined to the flag',
        function()
          return { '--settings=' .. USER_SETTINGS }
        end,
      },
    },
  })

T['start_session()']['leaves no word of the --settings of claude.cmd before the session’s']['given'] = function(
  _,
  words_for
)
  local file = vim.fs.joinpath(fixture.directory('switch-settings-words'), 'settings.json')
  vim.fn.writefile({ USER_SETTINGS }, file)
  local fake = claude.fake('switch-settings-words', 'exit')

  claude.start(
    child,
    fake,
    kept_in('switch-settings-words-state', { cmd = claude.fake_command(words_for(file)) })
  )

  eq(claude.arguments(fake)[1], '--session-id')
end

T['start_session()']['merges the last --settings of claude.cmd, the one Claude Code reads'] = function()
  local fake = claude.fake('switch-settings-last', 'exit')
  local cmd = claude.fake_command({
    '--settings',
    '{"env":{"FIRST":"1"}}',
    '--settings',
    '{"env":{"LAST":"1"}}',
  })

  claude.start(child, fake, kept_in('switch-settings-last-state', { cmd = cmd }))

  local given = settings_given(claude.arguments(fake))
  eq(settings_in_file(given[#given]).env, { LAST = '1' })
end

--- Settings of the user's own that hold a secret, and the secret.
local SECRET = 'aineo-secret-1234'
local SETTINGS_WITH_SECRET = '{"env":{"API_TOKEN":"' .. SECRET .. '"}}'

T['start_session()']['puts nothing of the settings claude.cmd gives on Claude Code’s command line'] =
  MiniTest.new_set({
    parametrize = {
      {
        'in a file',
        function(file)
          return { '--settings', file }
        end,
      },
      {
        'as JSON',
        function()
          return { '--settings', SETTINGS_WITH_SECRET }
        end,
      },
    },
  })

T['start_session()']['puts nothing of the settings claude.cmd gives on Claude Code’s command line']['given'] = function(
  _,
  words_for
)
  local file = vim.fs.joinpath(fixture.directory('switch-secret-settings'), 'settings.json')
  vim.fn.writefile({ SETTINGS_WITH_SECRET }, file)
  local fake = claude.fake('switch-secret-settings', 'exit')

  claude.start(
    child,
    fake,
    kept_in('switch-secret-settings-state', { cmd = claude.fake_command(words_for(file)) })
  )

  eq(table.concat(claude.arguments(fake), '\n'):find(SECRET, 1, true), nil)
end

T['start_session()']['passes the settings it merges in a file only the user can read and write'] = function()
  local fake = claude.fake('switch-private-settings', 'exit')

  claude.start(
    child,
    fake,
    kept_in(
      'switch-private-settings-state',
      { cmd = claude.fake_command({ '--settings', USER_SETTINGS }) }
    )
  )

  eq(vim.fn.getfperm(settings_given(claude.arguments(fake))[1]), 'rw-------')
end

T['start_session()']['leaves no file of the settings it merges once Neovim has exited'] = function()
  local fake = claude.fake('switch-settings-removed', 'exit')
  claude.start(
    child,
    fake,
    kept_in(
      'switch-settings-removed-state',
      { cmd = claude.fake_command({ '--settings', USER_SETTINGS }) }
    )
  )
  local file = settings_given(claude.arguments(fake))[1]
  local before = vim.fn.filereadable(file)

  child.stop()

  vim.wait(claude.PATIENCE_MS, function()
    return vim.fn.filereadable(file) == 0
  end, 20)
  eq({ before, vim.fn.filereadable(file) }, { 1, 0 })
end

T['start_session()']['passes the settings of claude.cmd as they are, without its hooks, and says so once, when it cannot write the settings it merges'] = function()
  local temporary = child.lua([[
    local directory = vim.fs.dirname(vim.fn.tempname())
    vim.uv.fs_chmod(directory, tonumber('500', 8))
    return directory
  ]])
  MiniTest.finally(function()
    vim.uv.fs_chmod(temporary, tonumber('700', 8))
  end)
  local fake = claude.fake('switch-settings-unwritable', 'exit')
  child.lua(NOTE_NOTIFICATIONS)

  claude.start_silently(
    child,
    fake,
    kept_in(
      'switch-settings-unwritable-state',
      { cmd = claude.fake_command({ '--settings', USER_SETTINGS }) }
    )
  )

  eq(
    { settings_given(claude.arguments(fake)), child.lua_get('_G.notified') },
    { { USER_SETTINGS }, UNREAD_SETTINGS_WARNINGS }
  )
end

T['start_session()']['writes nothing through a symbolic link planted at the next temporary name'] = function()
  local target = vim.fs.joinpath(fixture.directory('switch-planted-link'), 'target.json')
  vim.fn.writefile({ 'original' }, target)
  vim.fn.setfperm(target, 'rw-r--r--')
  child.lua(
    [[
      local name = vim.fn.tempname()
      local next_name = vim.fs.joinpath(vim.fs.dirname(name), tostring(tonumber(vim.fs.basename(name)) + 1))
      assert(vim.uv.fs_symlink(..., next_name))
    ]],
    { target }
  )
  local fake = claude.fake('switch-planted-link', 'exit')
  child.lua(NOTE_NOTIFICATIONS)

  claude.start(
    child,
    fake,
    kept_in(
      'switch-planted-link-state',
      { cmd = claude.fake_command({ '--settings', SETTINGS_WITH_SECRET }) }
    )
  )

  eq({
    target = vim.fn.readfile(target),
    mode = vim.fn.getfperm(target),
    given = settings_given(claude.arguments(fake)),
    notified = child.lua_get('_G.notified'),
  }, {
    target = { 'original' },
    mode = 'rw-r--r--',
    given = { SETTINGS_WITH_SECRET },
    notified = UNREAD_SETTINGS_WARNINGS,
  })
end

--- The Lua, run in a child, that limits the size of a file the child writes
--- to 256 KiB (`RLIMIT_FSIZE`, 1 on macOS and Linux) and ignores the
--- `SIGXFSZ` (25) a longer write raises, so that the write is cut short
--- instead; returns what `setrlimit()` returned, 0 when it held.
local LIMIT_FILE_SIZE = [[
  local ffi = require('ffi')
  pcall(ffi.cdef, [=[
    struct aineo_rlimit { uint64_t cur; uint64_t max; };
    int setrlimit(int resource, const struct aineo_rlimit *limit);
    typedef void (*aineo_handler)(int);
    aineo_handler signal(int number, aineo_handler handler);
  ]=])
  ffi.C.signal(25, ffi.cast('aineo_handler', 1))
  return ffi.C.setrlimit(1, ffi.new('struct aineo_rlimit', { 262144, 262144 }))
]]

--- Writes, in `name`'s fixture directory, a settings file of 1.5 MB that
--- denies nothing, and returns its path.
---
---@param name string
---@return string
local function large_settings_file(name)
  local file = vim.fs.joinpath(fixture.directory(name), 'settings.json')
  local rules = string.rep('"Bash(echo aineo:*)",', 75000) .. '"Bash(true)"'
  vim.fn.writefile({ '{"permissions":{"allow":[' .. rules .. ']}}' }, file)
  return file
end

T['start_session()']['passes the settings of claude.cmd as they are, and says so once, when a write of them is cut short'] = function()
  local file = large_settings_file('switch-short-write')
  local limited = child.lua(LIMIT_FILE_SIZE)
  local fake = claude.fake('switch-short-write', 'exit')
  child.lua(NOTE_NOTIFICATIONS)

  claude.start(
    child,
    fake,
    kept_in('switch-short-write-state', { cmd = claude.fake_command({ '--settings', file }) })
  )

  eq(
    { limited, settings_given(claude.arguments(fake)), child.lua_get('_G.notified') },
    { 0, { file }, UNREAD_SETTINGS_WARNINGS }
  )
end

T['start_session()']['merges the settings of a symbolic link to a regular file in claude.cmd'] = function()
  local directory = fixture.directory('switch-settings-link')
  local real = vim.fs.joinpath(directory, 'real.json')
  local link = vim.fs.joinpath(directory, 'link.json')
  vim.fn.writefile({ USER_SETTINGS }, real)
  assert(vim.uv.fs_symlink(real, link))
  local fake = claude.fake('switch-settings-link', 'exit')
  child.lua(NOTE_NOTIFICATIONS)

  claude.start(
    child,
    fake,
    kept_in('switch-settings-link-state', { cmd = claude.fake_command({ '--settings', link }) })
  )

  local given = settings_given(claude.arguments(fake))
  eq(
    { #given, settings_in_file(given[1]).permissions, child.lua_get('_G.notified') },
    { 1, { deny = { 'Bash(rm:*)' } }, {} }
  )
end

T['start_session()']['starts Claude Code with a settings file of 1.5 MB in claude.cmd'] = function()
  local file = large_settings_file('switch-large-settings')
  local fake = claude.fake('switch-large-settings', 'exit')

  claude.start(
    child,
    fake,
    kept_in('switch-large-settings-state', { cmd = claude.fake_command({ '--settings', file }) })
  )

  eq(#claude.wait_for_starts(fake, 1), 1)
end

T['start_session()']['keeps the user’s own session hooks beside its own'] = function()
  local settings = vim.json.encode({
    hooks = {
      SessionStart = {
        { matcher = 'startup', hooks = { { type = 'command', command = 'true' } } },
      },
    },
  })
  local fake = claude.fake('switch-user-hooks', 'exit')
  child.lua(NOTE_NOTIFICATIONS)

  claude.start(
    child,
    fake,
    kept_in('switch-user-hooks-state', { cmd = claude.fake_command({ '--settings', settings }) })
  )

  local given = settings_given(claude.arguments(fake))
  eq({ #given, child.lua_get('_G.notified') }, { 1, {} })
  eq(shape_of(settings_in_file(given[1])).hooks, {
    SessionStart = {
      { matcher = 'startup', hooks = { { type = 'command', command = 'command' } } },
      AINEO_HOOKS_SHAPE.SessionStart[1],
    },
    SessionEnd = AINEO_HOOKS_SHAPE.SessionEnd,
  })
end

T['start_session()']['passes settings of claude.cmd it cannot read as they are, without its hooks, and says so once'] =
  MiniTest.new_set({
    parametrize = {
      { 'a file that does not exist', 'no-such-settings.json' },
      { 'a file that holds no JSON object', 'list.json' },
      { 'JSON that does not parse', '{"permissions":}' },
      { 'hooks that are not an object', '{"hooks":[]}' },
      { 'an event whose hooks are not a list', '{"hooks":{"SessionEnd":{}}}' },
      { 'a directory', '.' },
      { 'a device', '/dev/null' },
    },
  })

T['start_session()']['passes settings of claude.cmd it cannot read as they are, without its hooks, and says so once']['given'] = function(
  _,
  value
)
  local directory = fixture.directory('switch-unread-settings')
  vim.fn.writefile({ '["settings", "in a list"]' }, vim.fs.joinpath(directory, 'list.json'))
  local fake = claude.fake('switch-unread-settings', 'exit')
  local cmd = claude.fake_command({ '--settings', value })
  child.lua(NOTE_NOTIFICATIONS)

  claude.start(child, fake, kept_in('switch-unread-settings-state', { cmd = cmd, cwd = directory }))

  eq(
    { settings_given(claude.arguments(fake)), child.lua_get('_G.notified') },
    { { value }, UNREAD_SETTINGS_WARNINGS }
  )
end

T['start_session()']['passes a FIFO named as the settings of claude.cmd as it is, unread, and says so once'] = function()
  local fifo = vim.fs.joinpath(fixture.directory('switch-settings-fifo'), 'settings.json')
  vim.system({ 'mkfifo', fifo }):wait()
  local fake = claude.fake('switch-settings-fifo', 'exit')
  child.lua(NOTE_NOTIFICATIONS)

  child.lua_notify(
    [[
      local helper, environment, overrides = dofile(...), select(2, ...)
      for name, value in pairs(environment) do
        vim.env[name] = value
      end
      require('aineo.claude').start_session(helper.stand_in_settings(overrides))
    ]],
    {
      'tests/helpers/claude_session.lua',
      fake.environment,
      kept_in('switch-settings-fifo-state', { cmd = claude.fake_command({ '--settings', fifo }) }),
    }
  )
  local started = #claude.wait_for_starts(fake, 1)
  vim.system({ 'sh', '-c', 'exec : > "$1"', 'sh', fifo }):wait(1000)

  eq(
    { started, settings_given(claude.arguments(fake)), child.lua_get('_G.notified') },
    { 1, { fifo }, UNREAD_SETTINGS_WARNINGS }
  )
end

T['start_session()']['puts --settings right before --allowedTools'] = MiniTest.new_set({
  parametrize = { { 'a new session', 1 }, { 'a resumed session', 2 } },
})

T['start_session()']['puts --settings right before --allowedTools']['starting'] = function(_, count)
  local fake = claude.fake('switch-settings-place', 'exit')
  local settings = kept_in('switch-settings-place-state')
  claude.start(child, fake, settings)
  claude.wait_for_status(child, 'exited')

  claude.start_again(child, settings)

  local arguments = claude.start_arguments(fake, count)
  local before_tools = vim.list_slice(arguments, #arguments - 4, #arguments - 2)
  eq({ before_tools[1], before_tools[3] }, { '--settings', '--allowedTools' })
end

T['start_session()']['gives hooks that reach the editor when its program’s path and the relay’s path hold a space, quotes and a dollar sign'] = function()
  local root = fixture.directory('switch-quoted it\'s $HOME "here"')
  vim.system({ 'cp', '-R', vim.fs.joinpath(vim.fn.getcwd(), 'lua'), root }):wait()
  local program = vim.fs.joinpath(root, "nvim it's")
  vim.fn.writefile({ '#!/bin/sh', ('exec \'%s\' "$@"'):format(vim.v.progpath) }, program)
  vim.fn.setfperm(program, 'rwxr-xr-x')
  child.lua('vim.opt.runtimepath:prepend(...)', { root })
  local fake = claude.fake('switch-quoted', 'ready')
  claude.start_noting_switches(
    child,
    fake,
    kept_in('switch-quoted-state', { editor_program = program })
  )
  local started_on = first_session_id(fake)

  switch_by_hooks(
    child,
    fake,
    1,
    { from = started_on, to = OTHER_SESSION_ID, source = 'clear', reason = 'clear' }
  )

  eq(claude.wait_for_session_switches(child, 1), {
    { id = OTHER_SESSION_ID, source = 'clear', left = started_on, reason = 'clear' },
  })
  eq(
    vim.startswith(
      child.lua_get("debug.getinfo(require('aineo.claude').session_id, 'S').source"),
      '@' .. root .. '/'
    ),
    true
  )
end

T['the hook relay'] = MiniTest.new_set()

T['the hook relay']['tells its editor the event, the session, its source or reason and the start token'] =
  MiniTest.new_set({
    parametrize = { { 'SessionStart', 'resume' }, { 'SessionEnd', 'clear' } },
  })

T['the hook relay']['tells its editor the event, the session, its source or reason and the start token']['for'] = function(
  event,
  cause
)
  child.lua(NOTE_SESSION_EVENTS)

  run_relay(child.v.servername, '7', event, hook_input(event, CLAUDE_SESSION_ID, cause))

  eq(wait_for_session_events(child, 1), { { event, CLAUDE_SESSION_ID, cause, '7' } })
end

T['the hook relay']['tells its editor when its hook began, by the clock every process on the host shares'] = function()
  child.lua(NOTE_SESSION_EVENTS)
  local before = vim.uv.hrtime()

  run_relay(
    child.v.servername,
    '7',
    'SessionEnd',
    hook_input('SessionEnd', CLAUDE_SESSION_ID, 'clear')
  )

  local after = vim.uv.hrtime()
  wait_for_session_events(child, 1)
  local ran = child.lua_get('_G.hook_times[1]')
  eq(type(ran), 'number')
  eq({ ran >= before, ran <= after }, { true, true })
end

T['the hook relay']['writes nothing on its stdout'] = function()
  child.lua(NOTE_SESSION_EVENTS)

  local ended = run_relay(
    child.v.servername,
    '7',
    'SessionStart',
    hook_input('SessionStart', CLAUDE_SESSION_ID, 'startup')
  )

  eq({ ended.code, ended.stdout }, { 0, '' })
end

T['the hook relay']['tells nothing of an input that is not an object with a string session_id, and exits 0'] =
  MiniTest.new_set({
    parametrize = {
      { 'not JSON' },
      { '' },
      { '[]' },
      { '"c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31"' },
      { '{}' },
      { '{"session_id":7,"source":"startup"}' },
      { '{"session_id":null,"source":"startup"}' },
    },
  })

T['the hook relay']['tells nothing of an input that is not an object with a string session_id, and exits 0']['given'] = function(
  input
)
  child.lua(NOTE_SESSION_EVENTS)

  local ended = run_relay(child.v.servername, '7', 'SessionStart', input)
  run_relay(
    child.v.servername,
    '8',
    'SessionStart',
    hook_input('SessionStart', CLAUDE_SESSION_ID, 'startup')
  )

  eq(ended.code, 0)
  eq(wait_for_session_events(child, 1), { { 'SessionStart', CLAUDE_SESSION_ID, 'startup', '8' } })
end

T['the hook relay']['tells the editor on its command line, not the one NVIM names'] = function()
  local other = MiniTest.new_child_neovim()
  MiniTest.finally(other.stop)
  children.restart(other)
  child.lua(NOTE_SESSION_EVENTS)
  other.lua(NOTE_SESSION_EVENTS)

  run_relay(
    child.v.servername,
    '7',
    'SessionStart',
    hook_input('SessionStart', CLAUDE_SESSION_ID, 'clear'),
    { env = { NVIM = other.v.servername } }
  )

  eq(wait_for_session_events(child, 1), { { 'SessionStart', CLAUDE_SESSION_ID, 'clear', '7' } })
  eq(other.lua_get('_G.session_events'), {})
end

T['the hook relay']['tells the editor on its command line when NVIM is unset'] = function()
  child.lua(NOTE_SESSION_EVENTS)
  local environment = vim.fn.environ()
  environment.NVIM = nil

  run_relay(
    child.v.servername,
    '7',
    'SessionStart',
    hook_input('SessionStart', CLAUDE_SESSION_ID, 'clear'),
    { env = environment, clear_env = true }
  )

  eq(wait_for_session_events(child, 1), { { 'SessionStart', CLAUDE_SESSION_ID, 'clear', '7' } })
end

T['the hook relay']['exits 0 and writes nothing when its editor cannot be reached'] = function()
  local gone = vim.fn.tempname() .. '.sock'

  local ended = run_relay(
    gone,
    '7',
    'SessionEnd',
    hook_input('SessionEnd', CLAUDE_SESSION_ID, 'prompt_input_exit')
  )

  eq({ ended.code, ended.stdout, ended.stderr }, { 0, '', '' })
end

T['the hook relay']['ends at once when its editor is busy, which is told once it is free'] = function()
  child.lua(NOTE_SESSION_EVENTS)
  local address = child.v.servername
  child.lua_notify('vim.uv.sleep(...)', { 3000 })
  local started = vim.uv.hrtime()

  run_relay(address, '7', 'SessionStart', hook_input('SessionStart', CLAUDE_SESSION_ID, 'resume'))

  eq((vim.uv.hrtime() - started) / 1e6 < 1500, true)
  eq(wait_for_session_events(child, 1), { { 'SessionStart', CLAUDE_SESSION_ID, 'resume', '7' } })
end

T['the hook relay']['leaves nothing running once its busy editor has ended'] = function()
  child.lua(NOTE_SESSION_EVENTS)
  local address = child.v.servername
  child.lua_notify('vim.uv.sleep(...)', { 3000 })
  run_relay(address, '7', 'SessionStart', hook_input('SessionStart', CLAUDE_SESSION_ID, 'resume'))
  local delivering = vim.system({ 'pgrep', '-f', '--', '--deliver ' .. address }):wait().code

  child.stop()

  eq(delivering, 0)
  eq(
    vim.wait(claude.PATIENCE_MS, function()
      return vim.system({ 'pgrep', '-f', '--', '--deliver ' .. address }):wait().code == 1
    end, 50),
    true
  )
end

T['the hook relay']['tells an editor that listens on a TCP address'] = function()
  child.lua(NOTE_SESSION_EVENTS)
  local address = child.lua_get("vim.fn.serverstart('127.0.0.1:0')")

  run_relay(address, '7', 'SessionStart', hook_input('SessionStart', CLAUDE_SESSION_ID, 'startup'))

  eq(wait_for_session_events(child, 1), { { 'SessionStart', CLAUDE_SESSION_ID, 'startup', '7' } })
end

T['the hook relay']['tells an editor held at a hit-enter prompt, once the prompt is left'] = function()
  local address = vim.fn.tempname()
  local job = child.lua(
    [[
      vim.cmd('enew')
      return vim.fn.jobstart({ vim.v.progpath, '--clean', '--listen', ... }, { term = true })
    ]],
    { address }
  )
  MiniTest.finally(function()
    child.lua('vim.fn.chansend(..., "\\27:qa!\\r"); vim.fn.jobwait({ ... }, 5000)', { job })
  end)
  local editor = connect_when_listening(address)
  vim.rpcrequest(editor, 'nvim_exec_lua', NOTE_SESSION_EVENTS, {})
  vim.fn.chanclose(editor)
  child.lua([[vim.fn.chansend(..., ':echo "a\\nb"\r')]], { job })
  local held = vim.wait(claude.PATIENCE_MS, function()
    return child.lua_get(
      [[table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('Press ENTER', 1, true) ~= nil]]
    )
  end, 20)

  run_relay(address, '7', 'SessionStart', hook_input('SessionStart', CLAUDE_SESSION_ID, 'resume'))
  vim.wait(1000, function()
    return vim.system({ 'pgrep', '-f', '--', '--deliver ' .. address }):wait().code == 1
  end, 20)
  child.lua('vim.fn.chansend(..., "\\r")', { job })

  local free = vim.fn.sockconnect('pipe', address, { rpc = true })
  local events
  vim.wait(claude.PATIENCE_MS, function()
    events = vim.rpcrequest(free, 'nvim_exec_lua', 'return _G.session_events', {})
    return #events > 0
  end, 50)
  vim.fn.chanclose(free)
  eq({ held, events }, { true, { { 'SessionStart', CLAUDE_SESSION_ID, 'resume', '7' } } })
end

T['session_id()'] = MiniTest.new_set()

T['session_id()']['is nil before any session has started'] = function()
  eq(claude.followed_session_id(child), vim.NIL)
end

T['session_id()']['is the new session’s id from its start, with no hook run'] = function()
  local fake = claude.fake('switch-followed-new', 'ready')

  claude.start(child, fake, kept_in('switch-followed-new-state'))

  eq(
    { claude.followed_session_id(child) },
    claude.words_after(claude.arguments(fake), '--session-id')
  )
end

T['session_id()']['is the resumed session’s id from its start, with no hook run'] = function()
  local fake = claude.fake('switch-followed-resumed', 'exit')
  local settings = kept_in('switch-followed-resumed-state')
  claude.start(child, fake, settings)
  claude.wait_for_status(child, 'exited')

  claude.start_again(child, settings)

  eq(
    { claude.followed_session_id(child) },
    claude.words_after(claude.start_arguments(fake, 2), '--resume')
  )
end

T['a session switch'] = MiniTest.new_set({
  hooks = {
    post_case = function()
      eq(child.lua_get('vim.v.errmsg'), '')
    end,
  },
})

T['a session switch']['is told once to on_session_switched, naming the session left and why'] = function()
  local fake = claude.fake('switch-told', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-told-state'))
  local started_on = first_session_id(fake)

  switch_by_hooks(
    child,
    fake,
    1,
    { from = started_on, to = OTHER_SESSION_ID, source = 'clear', reason = 'clear' }
  )

  eq(claude.wait_for_session_switches(child, 1), {
    { id = OTHER_SESSION_ID, source = 'clear', left = started_on, reason = 'clear' },
  })
end

T['a session switch']['makes the session switched to the one followed'] = function()
  local fake = claude.fake('switch-followed', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-followed-state'))

  switch_by_hooks(
    child,
    fake,
    1,
    { from = first_session_id(fake), to = OTHER_SESSION_ID, source = 'resume', reason = 'resume' }
  )

  claude.wait_for_session_switches(child, 1)
  eq(claude.followed_session_id(child), OTHER_SESSION_ID)
end

T['a session switch']['keeps the session switched to for the directory, so that the next start resumes it'] = function()
  local fake = claude.fake('switch-kept', 'ready')
  local settings = kept_in('switch-kept-state')
  local terminal = claude.start_noting_switches(child, fake, settings)
  switch_by_hooks(
    child,
    fake,
    1,
    { from = first_session_id(fake), to = OTHER_SESSION_ID, source = 'fork', reason = 'resume' }
  )
  claude.wait_for_session_switches(child, 1)
  child.lua('vim.fn.jobstop(vim.bo[...].channel)', { terminal })
  claude.wait_for_status(child, 'exited')

  claude.start_again(child, settings)

  eq(claude.words_after(claude.start_arguments(fake, 2), '--resume'), { OTHER_SESSION_ID })
end

T['a session switch']['is not made by a SessionStart of the session followed'] = function()
  local fake = claude.fake('switch-same', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-same-state'))
  local started_on = first_session_id(fake)

  claude.run_session_hook(
    child,
    fake,
    1,
    'SessionStart',
    hook_input('SessionStart', started_on, 'compact')
  )
  switch_by_hooks(
    child,
    fake,
    1,
    { from = started_on, to = OTHER_SESSION_ID, source = 'clear', reason = 'clear' }
  )

  eq(claude.wait_for_session_switches(child, 1), {
    { id = OTHER_SESSION_ID, source = 'clear', left = started_on, reason = 'clear' },
  })
end

T['a session switch']['is not made by a SessionStart of the session followed after its own SessionEnd'] = function()
  local fake = claude.fake('switch-same-after-end', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-same-after-end-state'))
  local started_on = first_session_id(fake)

  switch_by_hooks(
    child,
    fake,
    1,
    { from = started_on, to = started_on, source = 'resume', reason = 'resume' }
  )
  switch_by_hooks(
    child,
    fake,
    1,
    { from = started_on, to = OTHER_SESSION_ID, source = 'clear', reason = 'clear' }
  )

  eq(claude.wait_for_session_switches(child, 1), {
    { id = OTHER_SESSION_ID, source = 'clear', left = started_on, reason = 'clear' },
  })
end

T['a session switch']['is not made by a SessionStart alone after a resume of the session followed'] = function()
  local fake = claude.fake('switch-same-resumed', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-same-resumed-state'))
  local started_on = first_session_id(fake)
  switch_by_hooks(
    child,
    fake,
    1,
    { from = started_on, to = started_on, source = 'resume', reason = 'resume' }
  )

  claude.run_session_hook(
    child,
    fake,
    1,
    'SessionStart',
    hook_input('SessionStart', OTHER_SESSION_ID, 'fork')
  )
  claude.wait_for_deliveries(child)

  eq(
    { child.lua_get('_G.session_switches'), claude.followed_session_id(child) },
    { {}, started_on }
  )
end

T['a session switch']['is not made by a SessionStart alone after a resume of the session followed whose SessionStart reached the editor first'] = function()
  local fake = claude.fake('switch-same-resumed-reversed', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-same-resumed-reversed-state'))
  local started_on = first_session_id(fake)

  receive_in_order(child, {
    { 'SessionStart', started_on, 'resume', '1', 2000 },
    { 'SessionEnd', started_on, 'resume', '1', 1000 },
    { 'SessionStart', OTHER_SESSION_ID, 'fork', '1', 3000 },
  })

  eq(
    { child.lua_get('_G.session_switches'), claude.followed_session_id(child) },
    { {}, started_on }
  )
end

T['a session switch']['is not made by a SessionStart of another session with no SessionEnd before it'] = function()
  local fake = claude.fake('switch-no-end', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-no-end-state'))
  local started_on = first_session_id(fake)

  claude.run_session_hook(
    child,
    fake,
    1,
    'SessionStart',
    hook_input('SessionStart', OTHER_SESSION_ID, 'fork')
  )
  switch_by_hooks(
    child,
    fake,
    1,
    { from = started_on, to = CLAUDE_SESSION_ID, source = 'clear', reason = 'clear' }
  )

  eq(claude.wait_for_session_switches(child, 1), {
    { id = CLAUDE_SESSION_ID, source = 'clear', left = started_on, reason = 'clear' },
  })
end

T['a session switch']['is followed when the SessionEnd’s deliverer reaches the editor after the SessionStart’s'] = function()
  local address = vim.fn.tempname() .. '.sock'
  hold_first_connection(address, child.v.servername, 1000)
  local fake = claude.fake('switch-late-end', 'ready')
  claude.start_noting_switches(
    child,
    fake,
    kept_in('switch-late-end-state', { editor_address = address })
  )
  local started_on = first_session_id(fake)

  switch_by_hooks(
    child,
    fake,
    1,
    { from = started_on, to = OTHER_SESSION_ID, source = 'clear', reason = 'clear' }
  )

  eq(claude.wait_for_session_switches(child, 1), {
    { id = OTHER_SESSION_ID, source = 'clear', left = started_on, reason = 'clear' },
  })
end

T['a session switch']['is followed when its SessionStart reaches the editor before its SessionEnd, whose hook ran first'] = function()
  local fake = claude.fake('switch-reversed', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-reversed-state'))
  local started_on = first_session_id(fake)

  receive_in_order(child, {
    { 'SessionStart', OTHER_SESSION_ID, 'clear', '1', 2000 },
    { 'SessionEnd', started_on, 'clear', '1', 1000 },
  })

  eq(child.lua_get('_G.session_switches'), {
    { id = OTHER_SESSION_ID, source = 'clear', left = started_on, reason = 'clear' },
  })
end

T['a session switch']['is not made by a SessionStart whose hook ran before the SessionEnd'] =
  MiniTest.new_set({
    parametrize = { { 'the SessionStart first' }, { 'the SessionEnd first' } },
  })

T['a session switch']['is not made by a SessionStart whose hook ran before the SessionEnd']['reaching the editor with'] = function(
  first
)
  local fake = claude.fake('switch-start-ran-first', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-start-ran-first-state'))
  local started_on = first_session_id(fake)
  local events = {
    ['the SessionStart first'] = {
      { 'SessionStart', OTHER_SESSION_ID, 'fork', '1', 1000 },
      { 'SessionEnd', started_on, 'prompt_input_exit', '1', 2000 },
    },
    ['the SessionEnd first'] = {
      { 'SessionEnd', started_on, 'prompt_input_exit', '1', 2000 },
      { 'SessionStart', OTHER_SESSION_ID, 'fork', '1', 1000 },
    },
  }

  receive_in_order(child, events[first])

  eq(
    { child.lua_get('_G.session_switches'), claude.followed_session_id(child) },
    { {}, started_on }
  )
end

T['a session switch']['ends on the last session of two switches whose hooks reach the editor out of order'] =
  MiniTest.new_set({
    parametrize = {
      {
        'their SessionStarts first',
        function(started_on)
          return {
            { 'SessionStart', OTHER_SESSION_ID, 'clear', '1', 2000 },
            { 'SessionStart', THIRD_SESSION_ID, 'clear', '1', 4000 },
            { 'SessionEnd', started_on, 'clear', '1', 1000 },
            { 'SessionEnd', OTHER_SESSION_ID, 'clear', '1', 3000 },
          }
        end,
      },
      {
        'the second SessionEnd before the first SessionStart',
        function(started_on)
          return {
            { 'SessionEnd', started_on, 'clear', '1', 1000 },
            { 'SessionEnd', OTHER_SESSION_ID, 'clear', '1', 3000 },
            { 'SessionStart', OTHER_SESSION_ID, 'clear', '1', 2000 },
            { 'SessionStart', THIRD_SESSION_ID, 'clear', '1', 4000 },
          }
        end,
      },
      {
        'every hook in the reverse of the order it ran',
        function(started_on)
          return {
            { 'SessionStart', THIRD_SESSION_ID, 'clear', '1', 4000 },
            { 'SessionEnd', OTHER_SESSION_ID, 'clear', '1', 3000 },
            { 'SessionStart', OTHER_SESSION_ID, 'clear', '1', 2000 },
            { 'SessionEnd', started_on, 'clear', '1', 1000 },
          }
        end,
      },
    },
  })

T['a session switch']['ends on the last session of two switches whose hooks reach the editor out of order']['with'] = function(
  _,
  hooks_for
)
  local fake = claude.fake('switch-two-out-of-order', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-two-out-of-order-state'))
  local started_on = first_session_id(fake)

  receive_in_order(child, hooks_for(started_on))

  eq({ child.lua_get('_G.session_switches'), claude.followed_session_id(child) }, {
    {
      { id = OTHER_SESSION_ID, source = 'clear', left = started_on, reason = 'clear' },
      { id = THIRD_SESSION_ID, source = 'clear', left = OTHER_SESSION_ID, reason = 'clear' },
    },
    THIRD_SESSION_ID,
  })
end

T['a session switch']['pairs hooks by the order they reach the editor when one does not tell when it ran'] =
  MiniTest.new_set({
    parametrize = {
      {
        'the SessionEnd first, a switch',
        function(started_on)
          return {
            { 'SessionEnd', started_on, 'clear', '1', vim.NIL },
            { 'SessionStart', OTHER_SESSION_ID, 'clear', '1', 2000 },
          }
        end,
        { OTHER_SESSION_ID },
      },
      {
        'the SessionStart first, none',
        function(started_on)
          return {
            { 'SessionStart', OTHER_SESSION_ID, 'clear', '1', 2000 },
            { 'SessionEnd', started_on, 'clear', '1', vim.NIL },
          }
        end,
        {},
      },
    },
  })

T['a session switch']['pairs hooks by the order they reach the editor when one does not tell when it ran']['with'] = function(
  _,
  hooks_for,
  switched_to
)
  local fake = claude.fake('switch-untimed', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-untimed-state'))

  receive_in_order(child, hooks_for(first_session_id(fake)))

  eq(
    vim.tbl_map(function(switch)
      return switch.id
    end, child.lua_get('_G.session_switches')),
    switched_to
  )
end

T['a session switch']['is not made by a SessionStart whose hook ran at the same moment as the SessionEnd'] = function()
  local fake = claude.fake('switch-same-moment', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-same-moment-state'))
  local started_on = first_session_id(fake)

  receive_in_order(child, {
    { 'SessionEnd', started_on, 'clear', '1', 1000 },
    { 'SessionStart', OTHER_SESSION_ID, 'clear', '1', 1000 },
  })

  eq(
    { child.lua_get('_G.session_switches'), claude.followed_session_id(child) },
    { {}, started_on }
  )
end

T['a session switch']['is followed when on_session_switched raises, which is told the user'] = function()
  local fake = claude.fake('switch-raising-hook', 'ready')
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { fake.environment })
  child.lua(START_WITH_RAISING_CALLBACK, { kept_in('switch-raising-hook-state') })
  local started_on = first_session_id(fake)

  switch_by_hooks(
    child,
    fake,
    1,
    { from = started_on, to = OTHER_SESSION_ID, source = 'clear', reason = 'clear' }
  )
  claude.wait_for_deliveries(child)

  eq(
    { claude.followed_session_id(child), child.lua_get('_G.notified') },
    { OTHER_SESSION_ID, { { message = RAISED_WARNING, level = vim.log.levels.WARN } } }
  )
end

T['a session switch']['is not made by a SessionStart after a SessionEnd of another session'] = function()
  local fake = claude.fake('switch-other-end', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-other-end-state'))
  local started_on = first_session_id(fake)

  switch_by_hooks(
    child,
    fake,
    1,
    { from = CLAUDE_SESSION_ID, to = OTHER_SESSION_ID, source = 'fork', reason = 'other' }
  )
  claude.wait_for_deliveries(child)

  eq(
    { child.lua_get('_G.session_switches'), claude.followed_session_id(child) },
    { {}, started_on }
  )
end

T['a session switch']['leaves no mark of the SessionEnd it followed, so that a later SessionStart alone is no switch'] = function()
  local fake = claude.fake('switch-mark-cleared', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-mark-cleared-state'))
  switch_by_hooks(
    child,
    fake,
    1,
    { from = first_session_id(fake), to = OTHER_SESSION_ID, source = 'clear', reason = 'clear' }
  )
  claude.wait_for_session_switches(child, 1)

  claude.run_session_hook(
    child,
    fake,
    1,
    'SessionStart',
    hook_input('SessionStart', CLAUDE_SESSION_ID, 'fork')
  )
  claude.wait_for_deliveries(child)

  eq(
    { #child.lua_get('_G.session_switches'), claude.followed_session_id(child) },
    { 1, OTHER_SESSION_ID }
  )
end

T['a session switch']['is not made by a SessionEnd alone, as at Claude Code’s exit'] = function()
  local fake = claude.fake('switch-end-alone', 'ready')
  claude.start_noting_switches(child, fake, kept_in('switch-end-alone-state'))

  claude.run_session_hook(
    child,
    fake,
    1,
    'SessionEnd',
    hook_input('SessionEnd', first_session_id(fake), 'prompt_input_exit')
  )
  claude.wait_for_deliveries(child)

  eq({ child.lua_get('_G.session_switches'), claude.followed_session_id(child) }, {
    {},
    first_session_id(fake),
  })
end

T['a session switch']['is not made by a SessionStart whose hook ran after Claude Code exited'] = function()
  local fake = claude.fake('switch-after-exit', 'ready')
  local settings = kept_in('switch-after-exit-state')
  local terminal = claude.start_noting_switches(child, fake, settings)
  local started_on = first_session_id(fake)
  claude.run_session_hook(
    child,
    fake,
    1,
    'SessionEnd',
    hook_input('SessionEnd', started_on, 'prompt_input_exit')
  )
  child.lua('vim.fn.jobstop(vim.bo[...].channel)', { terminal })
  claude.wait_for_status(child, 'exited')

  claude.run_session_hook(
    child,
    fake,
    1,
    'SessionStart',
    hook_input('SessionStart', OTHER_SESSION_ID, 'compact')
  )
  claude.wait_for_deliveries(child)
  local switches = child.lua_get('_G.session_switches')
  claude.start_again(child, settings)

  eq({
    switches = switches,
    followed = claude.followed_session_id(child),
    resumed = claude.words_after(claude.start_arguments(fake, 2), '--resume'),
  }, { switches = {}, followed = started_on, resumed = { started_on } })
end

T['a session switch']['is not made to an id of another form than Claude Code’s'] =
  MiniTest.new_set({
    parametrize = {
      { '063CC43C-8E1A-4D2F-B5C7-91D0E3A4F852' },
      { '063cc43c-8e1a-1d2f-b5c7-91d0e3a4f852' },
      { 'not a session id' },
    },
  })

T['a session switch']['is not made to an id of another form than Claude Code’s']['such as'] = function(
  malformed
)
  local fake = claude.fake('switch-malformed', 'ready')
  local settings = kept_in('switch-malformed-state')
  local terminal = claude.start_noting_switches(child, fake, settings)
  local started_on = first_session_id(fake)

  switch_by_hooks(
    child,
    fake,
    1,
    { from = started_on, to = malformed, source = 'clear', reason = 'clear' }
  )
  claude.wait_for_deliveries(child)
  local switches, followed = child.lua_get('_G.session_switches'), claude.followed_session_id(child)
  child.lua('vim.fn.jobstop(vim.bo[...].channel)', { terminal })
  claude.wait_for_status(child, 'exited')
  claude.start_again(child, settings)

  eq({ switches, followed }, { {}, started_on })
  eq(claude.words_after(claude.start_arguments(fake, 2), '--resume'), { started_on })
end

T['a session switch']['is not made by a hook of an earlier start'] = function()
  local fake = claude.fake('switch-late-hook', 'exit')
  local settings = kept_in('switch-late-hook-state')
  claude.start(child, fake, settings)
  claude.wait_for_status(child, 'exited')
  claude.start_again_noting_switches(child, settings)
  local started_on = first_session_id(fake)
  claude.wait_for_starts(fake, 2)

  switch_by_hooks(
    child,
    fake,
    1,
    { from = started_on, to = OTHER_SESSION_ID, source = 'clear', reason = 'clear' }
  )
  claude.wait_for_deliveries(child)

  eq(
    { child.lua_get('_G.session_switches'), claude.followed_session_id(child) },
    { {}, started_on }
  )
end

T['a session switch']['is not followed while Neovim quits'] = function()
  local fake = claude.fake('switch-quitting', 'ready')
  local settings = kept_in('switch-quitting-state')
  claude.start_noting_switches(child, fake, settings)
  local started_on = first_session_id(fake)
  local hooks = {
    {
      command = claude.hook_command(fake, 1, 'SessionEnd'),
      input = hook_input('SessionEnd', started_on, 'clear'),
    },
    {
      command = claude.hook_command(fake, 1, 'SessionStart'),
      input = hook_input('SessionStart', OTHER_SESSION_ID, 'clear'),
    },
  }
  child.lua(
    [[
      local hooks = ...
      vim.api.nvim_create_autocmd('VimLeavePre', {
        desc = 'Run a switch’s hooks as Neovim quits, then wait, as another plugin might',
        callback = function()
          for _, hook in ipairs(hooks) do
            vim.system({ 'sh', '-c', hook.command }, { stdin = hook.input }):wait(5000)
          end
          vim.wait(5000, function()
            return vim.system({ 'pgrep', '-f', '--', '--deliver ' .. vim.v.servername }):wait().code == 1
          end, 20)
          local flushed = false
          vim.schedule(function()
            flushed = true
          end)
          vim.wait(5000, function()
            return flushed
          end, 10)
        end,
      })
    ]],
    { hooks }
  )

  claude.quit(child)
  eq(vim.fn.jobwait({ child.job.id }, claude.STOP_PATIENCE_MS), { 0 })
  children.restart(child)
  claude.start(child, fake, settings)

  eq(claude.words_after(claude.start_arguments(fake, 2), '--resume'), { started_on })
end

T['through Claude Code’s keys'] = MiniTest.new_set()

T['through Claude Code’s keys']['a switch reaches on_session_switched'] = MiniTest.new_set({
  parametrize = {
    { '/clear\r', 'clear', 'clear' },
    { '/resume ' .. CLAUDE_SESSION_ID .. '\r', 'resume', 'resume' },
    { '/branch\r', 'fork', 'resume' },
  },
})

T['through Claude Code’s keys']['a switch reaches on_session_switched']['by'] = function(
  keys,
  source,
  reason
)
  local fake = claude.fake('switch-keys', 'ready', { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  local terminal = claude.start_noting_switches(child, fake, kept_in('switch-keys-state'))
  wait_for_hook_runs(fake, 'SessionStart', 1)

  claude.press_keys(child, terminal, keys)

  local switches = claude.wait_for_session_switches(child, 1)
  local switched_to = wait_for_hook_runs(fake, 'SessionStart', 2)[2].session_id
  eq(switches, {
    { id = switched_to, source = source, left = first_session_id(fake), reason = reason },
  })
end

T['through Claude Code’s keys']['a /clear reaches on_session_switched with the hooks in a file of claude.cmd’s --settings'] = function()
  local file = vim.fs.joinpath(fixture.directory('switch-keys-file'), 'settings.json')
  vim.fn.writefile({ USER_SETTINGS }, file)
  local fake = claude.fake('switch-keys-file', 'ready', { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  local terminal = claude.start_noting_switches(
    child,
    fake,
    kept_in('switch-keys-file-state', { cmd = claude.fake_command({ '--settings', file }) })
  )
  eq(#wait_for_hook_runs(fake, 'SessionStart', 1), 1)

  claude.press_keys(child, terminal, '/clear\r')

  local switches = claude.wait_for_session_switches(child, 1)
  local cleared_to = wait_for_hook_runs(fake, 'SessionStart', 2)[2].session_id
  eq(switches, {
    { id = cleared_to, source = 'clear', left = first_session_id(fake), reason = 'clear' },
  })
end

T['through Claude Code’s keys']['/compact reaches nothing'] = function()
  local fake = claude.fake('switch-compact', 'ready', { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  local terminal = claude.start_noting_switches(child, fake, kept_in('switch-compact-state'))
  wait_for_hook_runs(fake, 'SessionStart', 1)

  claude.press_keys(child, terminal, '/compact\r')
  wait_for_hook_runs(fake, 'SessionStart', 2)
  claude.press_keys(child, terminal, '/clear\r')

  local switches = claude.wait_for_session_switches(child, 1)
  local cleared_to = wait_for_hook_runs(fake, 'SessionStart', 3)[3].session_id
  eq(switches, {
    { id = cleared_to, source = 'clear', left = first_session_id(fake), reason = 'clear' },
  })
end

T['through Claude Code’s keys']['an exit reaches nothing'] = function()
  local fake = claude.fake('switch-exit', 'ready', { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  local terminal = claude.start_noting_switches(child, fake, kept_in('switch-exit-state'))

  claude.end_by_keys(child, fake, terminal)
  claude.wait_for_deliveries(child)

  eq(wait_for_hook_causes(fake, 'SessionEnd', 1), { 'prompt_input_exit' })
  eq(child.lua_get('_G.session_switches'), {})
end

T['a start in place of the session followed'] = MiniTest.new_set()

--- Starts, in `child`, a session on a new id with `fake` and `settings`,
--- stops it before anything was sent, so that the fake has no conversation
--- for that id, and starts again noting switches, which resumes that id and
--- is refused; returns once the fake has started a third time, in its place.
---
---@param fake { record: string, environment: table<string, string> }
---@param settings table
local function resume_with_no_conversation(fake, settings)
  local first = claude.start(child, fake, settings)
  claude.wait_for_start(fake)
  child.lua('vim.fn.jobstop(vim.bo[...].channel)', { first })
  claude.wait_for_status(child, 'exited')
  claude.start_again_noting_switches(child, settings)
  claude.wait_for_starts(fake, 3)
end

--- A fake `claude` for one test that keeps conversations as Claude Code
--- does (`AINEO_FAKE_CLAUDE_CONVERSATIONS`), in a directory of its own.
---
---@param name string
---@return { record: string, environment: table<string, string> }
local function fake_keeping_conversations(name)
  return claude.fake(name, 'ready', {
    AINEO_FAKE_CLAUDE_CONVERSATIONS = fixture.directory(name .. '-conversations'),
  })
end

T['a start in place of the session followed']['that a resume with no conversation makes is told once, naming the id it could not resume'] = function()
  local fake = fake_keeping_conversations('switch-fallback-told')

  resume_with_no_conversation(fake, kept_in('switch-fallback-told-state'))

  eq(claude.wait_for_session_switches(child, 1), {
    {
      id = claude.words_after(claude.start_arguments(fake, 3), '--session-id')[1],
      source = 'startup',
      left = first_session_id(fake),
    },
  })
end

T['a start in place of the session followed']['that a resume with no conversation makes warns no more of settings that start warned of'] = function()
  local fake = fake_keeping_conversations('switch-fallback-unread')
  local cmd = claude.fake_command({ '--settings', 'aineo-no-such-settings.json' })
  local settings = kept_in('switch-fallback-unread-state', { cmd = cmd })
  local first = claude.start(child, fake, settings)
  claude.wait_for_start(fake)
  child.lua('vim.fn.jobstop(vim.bo[...].channel)', { first })
  claude.wait_for_status(child, 'exited')
  child.lua(NOTE_NOTIFICATIONS)

  claude.start_again(child, settings)
  claude.wait_for_starts(fake, 3)
  claude.wait_for_status(child, 'ready')

  eq(child.lua_get('_G.notified'), UNREAD_SETTINGS_WARNINGS)
end

T['a start in place of the session followed']['that a resume with no conversation makes is followed'] = function()
  local fake = fake_keeping_conversations('switch-fallback-followed')

  resume_with_no_conversation(fake, kept_in('switch-fallback-followed-state'))

  claude.wait_for_session_switches(child, 1)
  eq(
    { claude.followed_session_id(child) },
    claude.words_after(claude.start_arguments(fake, 3), '--session-id')
  )
end

T['a start in place of the session followed']['in another directory is told as a switch to the session it resumes'] = function()
  local fake = claude.fake('switch-other-directory', 'exit')
  local state = kept_in('switch-other-directory-state')
  local here = vim.tbl_extend('force', state, { cwd = fixture.directory('switch-directory-a') })
  local there = vim.tbl_extend('force', state, { cwd = fixture.directory('switch-directory-b') })
  claude.start(child, fake, there)
  claude.wait_for_status(child, 'exited')
  claude.start_again(child, here)
  claude.wait_for_starts(fake, 2)
  claude.wait_for_status(child, 'exited')

  claude.start_again_noting_switches(child, there)

  eq(child.lua_get('_G.session_switches'), {
    {
      id = first_session_id(fake),
      source = 'resume',
      left = claude.words_after(claude.start_arguments(fake, 2), '--session-id')[1],
    },
  })
end

T['a start in place of the session followed']['raises nothing once Claude Code has started when on_session_switched raises, and says so'] = function()
  local fake = claude.fake('switch-raising-start', 'exit')
  local state = kept_in('switch-raising-start-state')
  claude.start(child, fake, state)
  claude.wait_for_status(child, 'exited')
  local elsewhere = vim.tbl_extend('force', state, { cwd = fixture.directory('switch-raising-b') })

  local outcome = child.lua(START_WITH_RAISING_CALLBACK, { elsewhere })

  claude.wait_for_starts(fake, 2)
  eq(outcome.started, true)
  eq(outcome.notified, { { message = RAISED_WARNING, level = vim.log.levels.WARN } })
end

T['a start in place of the session followed']['that resumes the session followed tells nothing'] = function()
  local fake = claude.fake('switch-same-start', 'exit')
  local settings = kept_in('switch-same-start-state')
  claude.start(child, fake, settings)
  claude.wait_for_status(child, 'exited')

  claude.start_again_noting_switches(child, settings)

  claude.wait_for_starts(fake, 2)
  eq(child.lua_get('_G.session_switches'), {})
end

return T
