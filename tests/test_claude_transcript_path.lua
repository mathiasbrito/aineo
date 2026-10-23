local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude = dofile('tests/helpers/claude_session.lua')
local fixture = dofile('tests/helpers/fixture.lua')

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

--- The hook relay script.
local RELAY = vim.fs.joinpath(vim.fn.getcwd(), 'lua', 'aineo', 'claude', 'hook_relay.lua')

--- The start token the hook relay is given in the relay cases.
local TOKEN = 'start-token-transcript'

--- The `SessionStart` input Claude Code 2.1.308 wrote, recorded once and
--- scrubbed, and the session and transcript it names.
local RECORDED_START = vim.fn.readfile('tests/fixtures/transcripts/hook-inputs-2.1.308.jsonl')[2]
local RECORDED_SESSION = '00000000-0000-4000-8000-000000000001'
local RECORDED_TRANSCRIPT = '/claude/projects/-project/00000000-0000-4000-8000-000000000001.jsonl'

--- Makes the child an editor whose `receive_session_event()` keeps what the
--- hook relay tells it in `_G.told`, each call as the list of its arguments.
local KEEP_SESSION_EVENTS = [[
  _G.told = {}
  require('aineo.claude').receive_session_event = function(...)
    table.insert(_G.told, { ... })
  end
]]

T['the hook relay'] = MiniTest.new_set()

T['the hook relay']['tells the editor the transcript a SessionStart input names, after the session event'] = function()
  child.lua(KEEP_SESSION_EVENTS)
  local state = fixture.directory('transcript-path-relay-state')

  vim
    .system({
      vim.v.progpath,
      '--headless',
      '--clean',
      '--cmd',
      'set noloadplugins',
      '-l',
      RELAY,
      child.job.address,
      TOKEN,
      'SessionStart',
      '4242',
      '/project',
    }, { stdin = RECORDED_START, env = { XDG_STATE_HOME = state } })
    :wait(claude.PATIENCE_MS)
  vim.wait(claude.PATIENCE_MS, function()
    return #child.lua_get('_G.told') > 0
  end, 20)

  local told = child.lua_get('_G.told')[1]
  eq(
    { told[1], told[2], told[3], told[4], told[6], told[7] },
    { 'SessionStart', RECORDED_SESSION, 'scrubbed', TOKEN, 4242, RECORDED_TRANSCRIPT }
  )
end

--- Starts the session in the child against `fake`, whose hooks the fake
--- runs, with an `on_transcript` that appends what it is told to
--- `_G.transcripts`, each as `{ session id, path }`.
---
---@param fake { environment: table<string, string> }
---@param state string
local function start_noting_transcripts(fake, state)
  child.lua(
    [[
      local helper, environment, state = dofile(...), select(2, ...)
      for name, value in pairs(environment) do
        vim.env[name] = value
      end
      _G.transcripts = {}
      local settings = helper.stand_in_settings({ new_session = true, state_directory = state })
      settings.on_transcript = function(session_id, path)
        table.insert(_G.transcripts, { session_id, path })
      end
      require('aineo.claude').start_session(settings)
    ]],
    { 'tests/helpers/claude_session.lua', fake.environment, state }
  )
end

T['the session'] = MiniTest.new_set()

T['the session']['is told the transcript its SessionStart hook names, with the session'] = function()
  local state = fixture.directory('transcript-path-session-state')
  child.lua('vim.env.XDG_STATE_HOME = ...', { vim.fs.dirname(state) })
  local fake = claude.fake('transcript-path-session', 'ready', { AINEO_FAKE_CLAUDE_HOOKS = '1' })

  start_noting_transcripts(fake, state)

  local session = claude.words_after(claude.arguments(fake), '--session-id')[1]
  vim.wait(claude.PATIENCE_MS, function()
    return #child.lua_get('_G.transcripts') > 0
  end, 20)
  eq(
    child.lua_get('_G.transcripts'),
    { { session, '/tmp/aineo-fake-claude/' .. session .. '.jsonl' } }
  )
end

T['the session']['is told no transcript by a hook that names none, a path that is not absolute, or a SessionEnd'] = function()
  local fake = claude.fake('transcript-path-refused', 'ready')
  start_noting_transcripts(fake, fixture.directory('transcript-path-refused-state'))
  local token = claude.start_token(fake, 1)
  local session = claude.words_after(claude.arguments(fake), '--session-id')[1]

  for _, told in ipairs({
    { 'SessionStart', session, 'startup', token, nil, nil, nil },
    { 'SessionStart', session, 'startup', token, nil, nil, 'relative/session.jsonl' },
    { 'SessionStart', session, 'startup', token, nil, nil, '' },
    { 'SessionStart', session, 'startup', token, nil, nil, '~/session.jsonl' },
    { 'SessionStart', 'not-a-session', 'startup', token, nil, nil, '/tmp/aineo/other.jsonl' },
    { 'SessionEnd', session, 'clear', token, nil, nil, '/tmp/aineo/session.jsonl' },
  }) do
    child.lua("require('aineo.claude').receive_session_event(...)", told)
  end
  child.lua('_G.flushed = false; vim.schedule(function() _G.flushed = true end)')
  vim.wait(claude.PATIENCE_MS, function()
    return child.lua_get('_G.flushed')
  end, 20)

  eq(child.lua_get('_G.transcripts'), {})
end

return T
