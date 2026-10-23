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

--- The `--settings` the fake `claude` was given, inline, decoded.
---
---@param fake { record: string }
---@return table
local function settings_of(fake)
  return claude.decoded_words_after(claude.arguments(fake), '--settings')[1]
end

T['aineo’s settings'] = MiniTest.new_set()

T['aineo’s settings']['carry one PermissionRequest hook with no matcher, run in the background'] = function()
  local fake = claude.fake('permission-hook-entry', 'exit')

  claude.start(child, fake, { state_directory = fixture.directory('permission-hook-state') })

  local entries = settings_of(fake).hooks.PermissionRequest or {}
  local entry = entries[1] or {}
  local hook = (entry.hooks or {})[1] or {}
  eq({ #entries, entry.matcher, #(entry.hooks or {}) }, { 1, nil, 1 })
  eq({ hook.type, hook.async }, { 'command', true })
end

T['aineo’s settings']['run the hook relay for PermissionRequest, told the start token'] = function()
  local fake = claude.fake('permission-hook-command', 'exit')

  claude.start(child, fake, { state_directory = fixture.directory('permission-hook-state') })

  local command = claude.hook_command(fake, 1, 'PermissionRequest')
  eq(command:match("'([^']*)' 'PermissionRequest'"), claude.start_token(fake, 1))
end

--- The session every wait of these cases is about.
local SESSION = 'c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31'

--- Starts two copies of the Claude home in the child (`new()`, kept in
--- `_G.copies`), each on a new session against the fake `claude`, each with
--- an `on_permission_wait` that appends what it is told to
--- `_G.waits[<copy's number>]`; waits until the fake has recorded both
--- starts and returns the start token of each copy's start, found by the
--- session id the start was given, not by the order the fake recorded the
--- starts in.
---
---@param fake { record: string, environment: table<string, string> }
---@return string[] tokens by the copy's number
local function start_two_copies(fake)
  child.lua(
    [[
      local helper, environment = dofile(...), select(2, ...)
      for name, value in pairs(environment) do
        vim.env[name] = value
      end
      _G.copies = {}
      _G.waits = { {}, {} }
      for number = 1, 2 do
        local settings = helper.stand_in_settings({ new_session = true })
        settings.on_permission_wait = function(...)
          table.insert(_G.waits[number], { ... })
        end
        _G.copies[number] = require('aineo.claude').new()
        _G.copies[number].start_session(settings)
      end
    ]],
    { 'tests/helpers/claude_session.lua', fake.environment }
  )
  local starts = claude.wait_for_starts(fake, 2)
  local tokens = {}
  for number = 1, 2 do
    local session = child.lua_get(('_G.copies[%d].session_id()'):format(number))
    for index, start in ipairs(starts) do
      if claude.words_after(start.argv, '--session-id')[1] == session then
        tokens[number] = claude.start_token(fake, index)
      end
    end
  end
  return tokens
end

--- Tells the child's Claude home a permission wait, as the hook relay does,
--- and waits until the callbacks scheduled by then have run.
---
---@param token string
---@param session string
---@param agent string|userdata the subagent that asks, or `vim.NIL`
local function tell_permission_wait(token, session, agent)
  child.lua("require('aineo.claude').receive_permission_wait(...)", { token, session, agent })
  child.lua('_G.flushed = false; vim.schedule(function() _G.flushed = true end)')
  vim.wait(claude.PATIENCE_MS, function()
    return child.lua_get('_G.flushed')
  end, 20)
end

T['a permission wait'] = MiniTest.new_set()

T['a permission wait']['reaches the copy whose start has its token, with the session and the subagent'] = function()
  local fake = claude.fake('permission-wait-routed', 'ready')
  local tokens = start_two_copies(fake)

  tell_permission_wait(tokens[2], SESSION, 'a0000000000000001')

  eq(child.lua_get('_G.waits'), { {}, { { SESSION, 'a0000000000000001' } } })
end

T['a permission wait']['reaches no copy when its token is no start’s'] = function()
  local fake = claude.fake('permission-wait-unknown', 'ready')
  start_two_copies(fake)

  tell_permission_wait('no-such-token', SESSION, vim.NIL)

  eq(child.lua_get('_G.waits'), { {}, {} })
end

T['a permission wait']['reaches no copy whose Claude Code has ended'] = function()
  local fake = claude.fake('permission-wait-ended', 'exit')
  local tokens = start_two_copies(fake)
  vim.wait(claude.PATIENCE_MS, function()
    return child.lua_get('{ _G.copies[1].session_status() }')[1] == 'exited'
  end, 20)

  tell_permission_wait(tokens[1], SESSION, vim.NIL)

  eq(child.lua_get('_G.waits'), { {}, {} })
end

T['a permission wait']['reaches no copy when its session is not of the form Claude Code gives'] = function()
  local fake = claude.fake('permission-wait-session', 'ready')
  local tokens = start_two_copies(fake)

  tell_permission_wait(tokens[1], 'not-a-session', vim.NIL)

  eq(child.lua_get('_G.waits'), { {}, {} })
end

return T
