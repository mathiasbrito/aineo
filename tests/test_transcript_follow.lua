local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local transcript = require('aineo.transcript')

local RECORDED_TURN = fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 3000

--- How long a wait for something that should not happen lasts, in milliseconds.
local QUIET_MS = 250

--- The number of handles of the kind `kind` (`'fs_event'`, `'timer'`) that are
--- open in this Neovim.
---
---@param kind string
---@return integer
local function open_handles(kind)
  local count = 0
  vim.uv.walk(function(handle)
    if handle:get_type() == kind and not handle:is_closing() then
      count = count + 1
    end
  end)
  return count
end

--- A follower of a new transcript file in a directory of its own, with the
--- signals and the unreadable lines it reported so far.
---
---@param initial_lines? string[] the lines the file holds when the follower starts
---@return table follow { path, signals, unreadable, follower }
local function follow_new_transcript(initial_lines)
  local path = vim.fs.joinpath(fixture.directory('office_transcript'), 'session.jsonl')
  if initial_lines then
    fake_transcript.append(path, initial_lines)
  else
    fake_transcript.append_text(path, '')
  end
  local following = { path = path, signals = {}, unreadable = {} }
  following.follower = assert(transcript.follow({
    path = path,
    on_signal = function(signal)
      table.insert(following.signals, signal)
    end,
    on_unreadable_line = function(length)
      table.insert(following.unreadable, length)
    end,
  }))
  return following
end

--- The kinds of `signals`, in order.
---
---@param signals aineo.transcript.Signal[]
---@return string[]
local function kinds_of(signals)
  return vim.tbl_map(function(signal)
    return signal.kind
  end, signals)
end

--- A line of a transcript with one tool call, `call` its id.
---
---@param call string
---@param command? string
---@return string
local function tool_line(call, command)
  return vim.json.encode({
    type = 'assistant',
    message = {
      content = {
        { type = 'tool_use', id = call, name = 'Bash', input = { command = command or 'ls' } },
      },
    },
  })
end

local T = MiniTest.new_set({
  hooks = {
    post_case = function()
      vim.fn.delete(fixture.directory('office_transcript'), 'rf')
    end,
  },
})

T['follow()'] = MiniTest.new_set()

T['follow()']['replays the lines the file holds as replayed signals, in order'] = function()
  local following = follow_new_transcript(RECORDED_TURN)

  eq(kinds_of(following.signals), { 'tool_started', 'tool_finished', 'turn_ended' })
  eq(
    vim.tbl_map(function(signal)
      return signal.replayed
    end, following.signals),
    { true, true, true }
  )
  following.follower.stop()
end

T['follow()']['delivers a line appended later, as it is not a replay'] = function()
  local following = follow_new_transcript(RECORDED_TURN)
  local replayed = #following.signals

  fake_transcript.append(following.path, { tool_line('toolu_later') })
  local arrived = vim.wait(PATIENCE_MS, function()
    return #following.signals > replayed
  end, 10)

  eq(arrived, true)
  eq(following.signals[replayed + 1].call, 'toolu_later')
  eq(following.signals[replayed + 1].replayed, nil)
  following.follower.stop()
end

T['follow()']['delivers each appended line once, in the order they were written'] = function()
  local following = follow_new_transcript()

  fake_transcript.append(following.path, { tool_line('a'), tool_line('b') })
  fake_transcript.append(following.path, { tool_line('c') })
  vim.wait(PATIENCE_MS, function()
    return #following.signals >= 3
  end, 10)
  vim.wait(QUIET_MS)

  eq(
    vim.tbl_map(function(signal)
      return signal.call
    end, following.signals),
    { 'a', 'b', 'c' }
  )
  following.follower.stop()
end

T['follow()']['waits for the rest of a line that is not whole, even inside a character'] = function()
  local following = follow_new_transcript()
  local line = tool_line('toolu_split', 'echo €') .. '\n'
  local cut = line:find('€', 1, true) + 1

  fake_transcript.append_text(following.path, line:sub(1, cut))
  vim.wait(QUIET_MS)
  local before = #following.signals
  fake_transcript.append_text(following.path, line:sub(cut + 1))
  vim.wait(PATIENCE_MS, function()
    return #following.signals > 0
  end, 10)

  eq(before, 0)
  eq(#following.signals, 1)
  eq(following.signals[1].input.command, 'echo €')
  eq(following.unreadable, {})
  following.follower.stop()
end

T['follow()']['replays a line the file holds without its newline once the newline arrives'] = function()
  local path = vim.fs.joinpath(fixture.directory('office_transcript'), 'session.jsonl')
  fake_transcript.append_text(path, tool_line('toolu_open'))
  local signals = {}
  local follower = assert(transcript.follow({
    path = path,
    on_signal = function(signal)
      table.insert(signals, signal)
    end,
  }))

  eq(#signals, 0)
  fake_transcript.append_text(path, '\n')
  vim.wait(PATIENCE_MS, function()
    return #signals > 0
  end, 10)

  eq(#signals, 1)
  eq(signals[1].call, 'toolu_open')
  follower.stop()
end

T['follow()']['reports the length of a line that is not JSON and goes on'] = function()
  local following = follow_new_transcript()

  fake_transcript.append(following.path, { '{"type": "assist', tool_line('after') })
  vim.wait(PATIENCE_MS, function()
    return #following.signals > 0
  end, 10)

  eq(following.unreadable, { 16 })
  eq(following.signals[1].call, 'after')
  following.follower.stop()
end

T['follow()']['replays only the last 256 KiB of a long file, from a whole line'] = function()
  local lines = {}
  for number = 1, 600 do
    table.insert(lines, tool_line(('call%d'):format(number), ('x'):rep(1000)))
  end

  local following = follow_new_transcript(lines)

  eq(following.unreadable, {})
  eq(following.signals[#following.signals].call, 'call600')
  eq(#following.signals < 600, true)
  eq(#following.signals >= 200, true)
  following.follower.stop()
end

T['follow()']['skips a line longer than a megabyte, reports it and goes on'] = function()
  local following = follow_new_transcript()

  fake_transcript.append(following.path, { tool_line('huge', ('y'):rep(1100 * 1024)) })
  fake_transcript.append(following.path, { tool_line('after_the_huge') })
  vim.wait(PATIENCE_MS, function()
    return #following.signals > 0 and #following.unreadable > 0
  end, 10)
  vim.wait(QUIET_MS)

  eq(
    vim.tbl_map(function(signal)
      return signal.call
    end, following.signals),
    { 'after_the_huge' }
  )
  eq(#following.unreadable >= 1, true)
  following.follower.stop()
end

T['follow()']['stops delivering and releases its watch once stopped'] = function()
  local watches_before = open_handles('fs_event')
  local following = follow_new_transcript()
  local watching = open_handles('fs_event')

  following.follower.stop()
  fake_transcript.append(following.path, { tool_line('late') })
  vim.wait(QUIET_MS)

  eq(watching, watches_before + 1)
  eq(following.signals, {})
  eq(open_handles('fs_event'), watches_before)
end

T['follow()']['says why it follows nothing when there is no file'] = function()
  local follower, problem = transcript.follow({
    path = vim.fs.joinpath(fixture.directory('office_transcript'), 'nothing.jsonl'),
    on_signal = function() end,
  })

  eq(follower, nil)
  eq(type(problem), 'string')
end

return T
