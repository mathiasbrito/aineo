local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that ends, in the child, the process of every terminal by a
--- hangup, and waits for each to end, at most 5 s each.
local END_TERMINALS = [[
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      local job = vim.b[buffer].terminal_job_id
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 5000)
    end
  end
]]

--- Stops the child, once the fake Claude Code it runs, if any, has ended by a
--- hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      entry.restart(child)
    end,
    post_once = stop_the_child,
  },
})

--- The recorded turn, whose first five lines end with a call that runs.
local RECORDED_TURN = fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')

--- A session of the form Claude Code gives that the case's tab does not run.
local OTHER_SESSION = 'c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31'

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, and waits until Claude Code is ready.
---
---@param name string the case's own name for its files, starting `office-`
local function open_layout(name)
  entry.use_fake(child, claude_session.fake(name, 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

--- Runs `lua` in the child, then waits until the callbacks scheduled by then
--- have run, as the hook relay's notifications are handled.
---
---@param lua string
---@param arguments? any[]
local function run_and_settle(lua, arguments)
  child.lua(lua, arguments or {})
  child.lua('_G.settled = false; vim.schedule(function() _G.settled = true end)')
  vim.wait(claude_session.PATIENCE_MS, function()
    return child.lua_get('_G.settled')
  end, 20)
end

--- Tells the child's Claude home, as the hook relay does for a `SessionStart`
--- of `session`, that Claude Code writes the transcript of `session` in
--- `path`, the tab's own start token with it.
---
---@param session string
---@param path string
local function tell_transcript(session, path)
  run_and_settle(
    [[
      local claude = require('aineo.claude')
      claude.receive_session_event('SessionStart', ..., 'startup', claude.start_token(), nil, nil, select(2, ...))
    ]],
    { session, path }
  )
end

--- Tells the child's Claude home, as the hook relay does for a
--- `PermissionRequest`, that the agent `agent` of `session` waits for the
--- user, the tab's own start token with it.
---
---@param session string
---@param agent string|userdata the subagent that asks, or `vim.NIL`
local function tell_permission_wait(session, agent)
  run_and_settle(
    [[
      local claude = require('aineo.claude')
      claude.receive_permission_wait(claude.start_token(), ...)
    ]],
    { session, agent }
  )
end

--- The session the child's tab runs.
---
---@return string
local function tab_session()
  return child.lua_get([[require('aineo.claude').session_id()]])
end

--- Writes `lines` as a transcript in a file of its own, where Claude Code's
--- folder rule would not look for it, and returns its path.
---
---@param session string
---@param lines string[]
---@return string
local function write_transcript_elsewhere(session, lines)
  local directory = vim.fs.joinpath(child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]]), 'elsewhere')
  vim.fn.mkdir(directory, 'p')
  local path = vim.fs.joinpath(directory, session .. '.jsonl')
  fake_transcript.append(path, lines)
  return path
end

T['the transcript a SessionStart hook named'] = MiniTest.new_set()

T['the transcript a SessionStart hook named']['is the one the office follows, wherever Claude Code wrote it'] = function()
  open_layout('office-hook-path')
  local session = tab_session()
  tell_transcript(session, write_transcript_elsewhere(session, vim.list_slice(RECORDED_TURN, 1, 5)))

  entry.command(child, 'Aineo office')

  eq(office_cells.is_typing(child), true)
end

T['the transcript a SessionStart hook named']['is not followed for a session the tab does not run'] = function()
  open_layout('office-hook-other')
  tell_transcript(
    OTHER_SESSION,
    write_transcript_elsewhere(OTHER_SESSION, vim.list_slice(RECORDED_TURN, 1, 5))
  )

  entry.command(child, 'Aineo office')

  eq(office_cells.is_standing(child), true)
end

--- Makes the office module of the child a stand-in whose offices keep what
--- they are told in `_G.office_told`: the transcript path of each
--- `follow_session()` and the agent of each `permission_wait()`.
local STAND_IN_OFFICE = [[
  _G.office_told = { follows = {}, waits = {} }
  package.loaded['aineo.office'] = {
    new_office = function()
      return {
        follow_session = function(path)
          table.insert(_G.office_told.follows, path or vim.NIL)
        end,
        permission_wait = function(agent)
          table.insert(_G.office_told.waits, agent)
        end,
        show_now = function() end,
        let_go = function() end,
      }
    end,
  }
]]

--- What the stand-in office (`STAND_IN_OFFICE`) was told.
---
---@return { follows: any[], waits: string[] }
local function office_told()
  return child.lua_get('_G.office_told')
end

T['a permission wait'] = MiniTest.new_set()

T['a permission wait']['reaches the office of the tab, as the main agent or as the subagent that asks'] = function()
  open_layout('office-wait')
  child.lua(STAND_IN_OFFICE)
  entry.command(child, 'Aineo office')
  local session = tab_session()

  tell_permission_wait(session, vim.NIL)
  tell_permission_wait(session, 'a0000000000000001')

  eq(office_told().waits, { 'main', 'a0000000000000001' })
end

T['a permission wait']['is not told to the office when it is of a session the tab does not run'] = function()
  open_layout('office-wait-other')
  child.lua(STAND_IN_OFFICE)
  entry.command(child, 'Aineo office')

  tell_permission_wait(OTHER_SESSION, vim.NIL)

  eq(office_told().waits, {})
end

T['a permission wait']['asks for no office when the tab has none yet'] = function()
  open_layout('office-wait-none')
  child.lua(STAND_IN_OFFICE)

  tell_permission_wait(tab_session(), vim.NIL)

  eq({ office_told(), entry.messages(child) }, { { follows = {}, waits = {} }, {} })
end

T['a permission wait']['raises nothing in an office that takes none'] = function()
  open_layout('office-wait-real')
  entry.command(child, 'Aineo office')

  tell_permission_wait(tab_session(), vim.NIL)

  eq(entry.messages(child), {})
end

return T
