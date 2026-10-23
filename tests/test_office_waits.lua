local MiniTest = require('mini.test')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')
local office_child = dofile('tests/helpers/office_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 4000

--- The recorded turn: a prompt, a call, its result and the turn's end.
local RECORDED_TURN = fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')

--- Makes the tracker the office makes, in the child, be kept in `_G.tracker`.
local KEEP_THE_TRACKER = [[
  local office_states = require('aineo.office_states')
  local new_tracker = office_states.new_tracker
  office_states.new_tracker = function(options)
    _G.tracker = new_tracker(options)
    return _G.tracker
  end
]]

--- Opens the layout and makes an office that follows `path`, if given, and
--- whose tracker is kept.
---
---@param path? string
---@param more_options? string the source of a table of options of the office over the usual
local function open_office(path, more_options)
  office_child.open_layout(child)
  child.lua(KEEP_THE_TRACKER)
  office_child.make_office(child, nil, more_options)
  if path then
    office_child.follow_transcript(child, path)
  end
end

--- The state of the agent `agent` as the office's tracker has it now.
---
---@param agent string
---@return string|nil
local function state_of(agent)
  return child.lua_get(
    [[(function(agent)
      for _, each in ipairs(_G.tracker.agents(vim.uv.hrtime() / 1e9)) do
        if each.id == agent then
          return each.state
        end
      end
    end)(...)]],
    { agent }
  )
end

--- The text of a transcript, in a directory of the case's own.
---
---@return string path
local function transcript_path()
  return vim.fs.joinpath(fixture.directory('office_waits'), 'session.jsonl')
end

T['a permission wait'] = MiniTest.new_set()

T['a permission wait']['has the main agent need permission'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])

  child.lua([[_G.office.permission_wait('main')]])

  eq(state_of('main'), 'needs_permission')
end

T['a permission wait']['has the subagent that asks need permission, and no other agent'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])

  child.lua([[_G.office.permission_wait('a0000000000000001')]])

  eq(state_of('a0000000000000001'), 'needs_permission')
  eq(state_of('main') == 'needs_permission', false)
end

T['a permission wait']['ends with the next line of the agent in the transcript'] = function()
  local path = transcript_path()
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 1, 5))
  open_office(path)
  child.lua([[_G.office.show_now()]])
  child.lua([[_G.office.permission_wait('main')]])
  local waiting = vim.wait(PATIENCE_MS, function()
    return state_of('main') == 'needs_permission'
  end, 10)

  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 6, 10))

  eq(waiting, true)
  eq(
    vim.wait(PATIENCE_MS, function()
      return state_of('main') ~= 'needs_permission'
    end, 10),
    true
  )
end

--- Seconds since 1970 of 2026-01-01T00:00:28Z: after the recorded turn's
--- call (27.5 s into its stamps), before its result (28.8 s).
local WHEN_THE_WAIT_IS_TOLD = 1767225628

--- Opens the layout and makes an office that follows `path` and whose wall
--- clock says it is `WHEN_THE_WAIT_IS_TOLD`.
---
---@param path string
local function open_office_at_the_time_of_the_wait(path)
  open_office(path, '{ wall_clock = function() return _G.wall_now end }')
  child.lua('_G.wall_now = ...', { WHEN_THE_WAIT_IS_TOLD })
end

T['a permission wait']['told while the office is hidden is shown once it shows, for a call still open'] = function()
  local path = transcript_path()
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 1, 5))
  open_office_at_the_time_of_the_wait(path)

  child.lua([[_G.office.permission_wait('main')]])
  child.lua([[_G.office.show_now()]])

  eq(
    vim.wait(PATIENCE_MS, function()
      return state_of('main') == 'needs_permission'
    end, 10),
    true
  )
end

T['a permission wait']['told while the office is hidden is dropped once it shows, when the agent went on since'] = function()
  local path = transcript_path()
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 1, 10))
  open_office_at_the_time_of_the_wait(path)

  child.lua([[_G.office.permission_wait('main')]])
  child.lua([[_G.office.show_now()]])
  vim.wait(1800)

  eq(state_of('main') == 'needs_permission', false)
end

T['a permission wait']['stays up when the office is closed and shown again while the call is still open'] = function()
  local path = transcript_path()
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 1, 5))
  open_office_at_the_time_of_the_wait(path)
  child.lua([[_G.office.show_now()]])
  child.lua([[_G.office.permission_wait('main')]])
  vim.wait(PATIENCE_MS, function()
    return state_of('main') == 'needs_permission'
  end, 10)
  child.lua([[vim.api.nvim_win_close(..., true)]], { office_cells.window(child) })
  vim.wait(PATIENCE_MS, function()
    return office_cells.window(child) == vim.NIL
  end, 10)

  child.lua([[_G.office.show_now()]])

  eq(
    vim.wait(PATIENCE_MS, function()
      return state_of('main') == 'needs_permission'
    end, 10),
    true
  )
end

T['a permission wait']['told before the start of the call that asked is read still counts, though that start is stamped later'] = function()
  local path = transcript_path()
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 1, 5))
  open_office_at_the_time_of_the_wait(path)
  child.lua('_G.wall_now = ...', { WHEN_THE_WAIT_IS_TOLD - 1 })

  child.lua([[_G.office.permission_wait('main')]])
  child.lua([[_G.office.show_now()]])

  eq(
    vim.wait(PATIENCE_MS, function()
      return state_of('main') == 'needs_permission'
    end, 10),
    true
  )
end

T['a permission wait']['told while the office is hidden is kept for 64 agents at most'] = function()
  open_office()

  child.lua([[for index = 1, 70 do
    _G.office.permission_wait(('a%016d'):format(index))
  end]])
  child.lua([[_G.office.show_now()]])

  eq(child.lua_get([[#_G.tracker.agents(vim.uv.hrtime() / 1e9)]]), 65)
end

T['a permission wait']['told while its tab page is left is shown when the tab page is entered again'] = function()
  local path = transcript_path()
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 1, 5))
  open_office_at_the_time_of_the_wait(path)
  child.lua([[_G.office.show_now()]])
  child.cmd('tabnew')

  child.lua([[_G.office.permission_wait('main')]])
  child.cmd('tabprevious')

  eq(
    vim.wait(PATIENCE_MS, function()
      return state_of('main') == 'needs_permission'
    end, 10),
    true
  )
end

return T
