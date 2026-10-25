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

--- Starts the session in the child against `fake`, with an
--- `on_session_ended` that appends what it is told to `_G.ended`, each as
--- `{ session id, reason }`, and returns the session it starts on.
---
---@param fake { environment: table<string, string> }
---@param name string the case's own name for its state directory
---@return string session
local function start_noting_ends(fake, name)
  child.lua(
    [[
      local helper, environment, state = dofile(...), select(2, ...)
      for variable, value in pairs(environment) do
        vim.env[variable] = value
      end
      _G.ended = {}
      local settings = helper.stand_in_settings({ new_session = true, state_directory = state })
      settings.on_session_ended = function(session_id, reason)
        table.insert(_G.ended, { session_id, reason })
      end
      _G.terminal = require('aineo.claude').start_session(settings)
    ]],
    { 'tests/helpers/claude_session.lua', fake.environment, fixture.directory(name) }
  )
  return claude.words_after(claude.arguments(fake), '--session-id')[1]
end

--- Tells the child's Claude home each of `hooks`, as the hook relay does,
--- then waits until the callbacks scheduled by then have run.
---
---@param hooks any[][] the arguments of each `receive_session_event()`
local function tell_hooks(hooks)
  for _, hook in ipairs(hooks) do
    child.lua("require('aineo.claude').receive_session_event(...)", hook)
  end
  child.lua('_G.flushed = false; vim.schedule(function() _G.flushed = true end)')
  vim.wait(claude.PATIENCE_MS, function()
    return child.lua_get('_G.flushed')
  end, 20)
end

T['the session'] = MiniTest.new_set()

T['the session']['is told the end its SessionEnd hook tells, with the session and the reason'] = function()
  local fake = claude.fake('session-end-hook', 'ready')
  local session = start_noting_ends(fake, 'session-end-hook-state')
  local token = claude.start_token(fake, 1)

  tell_hooks({ { 'SessionEnd', session, 'prompt_input_exit', token, 5, nil, nil } })

  eq(child.lua_get('_G.ended'), { { session, 'prompt_input_exit' } })
end

T['the session']['is not told an end whose hook ran before a SessionStart of the session told already, in any order'] = function()
  local fake = claude.fake('session-end-late', 'ready')
  local session = start_noting_ends(fake, 'session-end-late-state')
  local token = claude.start_token(fake, 1)

  tell_hooks({
    { 'SessionStart', session, 'resume', token, 10, nil, nil },
    { 'SessionStart', session, 'startup', token, 3, nil, nil },
    { 'SessionEnd', session, 'resume', token, 5, nil, nil },
  })

  eq(child.lua_get('_G.ended'), {})
end

T['the session']['is told the end of its Claude Code, with the session it followed, when the process exits'] = function()
  local fake = claude.fake('session-end-exit', 'ready')
  local session = start_noting_ends(fake, 'session-end-exit-state')
  claude.wait_for_status(child, 'ready')

  child.lua([[
    local job = vim.b[_G.terminal].terminal_job_id
    vim.fn.jobstop(job)
    vim.fn.jobwait({ job }, 5000)
  ]])
  vim.wait(claude.PATIENCE_MS, function()
    return #child.lua_get('_G.ended') > 0
  end, 20)

  eq(child.lua_get('_G.ended'), { { session } })
end

T['the session']['is not told the exit of a Claude Code another start took the place of'] = function()
  local fake = claude.fake('session-end-replaced', 'ready')
  start_noting_ends(fake, 'session-end-replaced-state')
  claude.wait_for_status(child, 'ready')

  child.lua([[
    local job = vim.b[_G.terminal].terminal_job_id
    local claude = require('aineo.claude')
    local settings = dofile('tests/helpers/claude_session.lua').stand_in_settings({
      state_directory = vim.fn.stdpath('state'),
    })
    settings.on_session_ended = function(session_id, reason)
      table.insert(_G.ended, { session_id, reason })
    end
    claude.replace_session(settings, nil)
    vim.fn.jobwait({ job }, 5000)
  ]])
  child.lua('_G.flushed = false; vim.schedule(function() _G.flushed = true end)')
  vim.wait(claude.PATIENCE_MS, function()
    return child.lua_get('_G.flushed')
  end, 20)

  eq(child.lua_get('_G.ended'), {})
end

return T
