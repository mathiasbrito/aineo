local MiniTest = require('mini.test')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local fixture = dofile('tests/helpers/fixture.lua')
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
local function open_office(path)
  office_child.open_layout(child)
  child.lua(KEEP_THE_TRACKER)
  office_child.make_office(child)
  if path then
    child.lua([[_G.office.follow_session(...)]], { path })
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

T['a permission wait']['is not kept for an office that is hidden'] = function()
  open_office()

  child.lua([[_G.office.permission_wait('main')]])
  child.lua([[_G.office.show_now()]])

  eq(state_of('main') == 'needs_permission', false)
end

T['a permission wait']['is not kept for an office that is paused while its tab page is left'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])
  child.cmd('tabnew')

  child.lua([[_G.office.permission_wait('main')]])
  child.cmd('tabprevious')

  eq(state_of('main') == 'needs_permission', false)
end

return T
