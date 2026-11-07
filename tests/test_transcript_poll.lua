local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- How many timers that repeat every `period` milliseconds are open.
---
---@param period integer
---@return integer
local function timers_repeating_every(period)
  local count = 0
  vim.uv.walk(function(handle)
    if
      handle:get_type() == 'timer'
      and not handle:is_closing()
      and handle:get_repeat() == period
    then
      count = count + 1
    end
  end)
  return count
end

--- Follows the transcript `path`, ignoring what it says, with `options` besides.
---
---@param path string
---@param options? table
---@return aineo.transcript.SessionFollower
local function follow(path, options)
  return require('aineo.transcript').follow(
    vim.tbl_extend('force', { path = path, on_signal = function() end }, options or {})
  )
end

T['a follower'] = MiniTest.new_set()

T['a follower']['of a transcript and a subagents folder not there looks at both every 500 ms by default'] = function()
  local folder = fixture.directory('transcript_poll_default')
  local follower = follow(vim.fs.joinpath(folder, 'session.jsonl'))

  eq(timers_repeating_every(500), 2)

  follower.stop()
  eq(timers_repeating_every(500), 0)
end

T['a follower']['told how often to look uses one timer for what is not there, every so often'] = function()
  local folder = fixture.directory('transcript_poll_slow')
  local follower = follow(vim.fs.joinpath(folder, 'session.jsonl'), { poll_ms = 2000 })

  eq({ timers_repeating_every(2000), timers_repeating_every(500) }, { 1, 0 })

  follower.stop()
  eq(timers_repeating_every(2000), 0)
end

T['a follower']['told how often to look uses one timer for a missing subagents folder alone'] = function()
  local folder = fixture.directory('transcript_poll_folder')
  vim.fn.writefile({}, vim.fs.joinpath(folder, 'session.jsonl'))
  local follower = follow(vim.fs.joinpath(folder, 'session.jsonl'), { poll_ms = 2000 })

  eq(timers_repeating_every(2000), 1)

  follower.stop()
end

T['a follower']['told how often to look uses no timer once what it follows is there'] = function()
  local folder = fixture.directory('transcript_poll_there')
  vim.fn.writefile({}, vim.fs.joinpath(folder, 'session.jsonl'))
  vim.fn.mkdir(vim.fs.joinpath(folder, 'session', 'subagents'), 'p')
  local follower = follow(vim.fs.joinpath(folder, 'session.jsonl'), { poll_ms = 2000 })

  eq(timers_repeating_every(2000), 0)

  follower.stop()
end

T['a follower']['told how often to look starts to follow a transcript made later, within that time'] = function()
  local folder = fixture.directory('transcript_poll_later')
  local path = vim.fs.joinpath(folder, 'session.jsonl')
  local signals = {}
  local follower = follow(path, {
    poll_ms = 300,
    on_signal = function(signal)
      table.insert(signals, signal.kind)
    end,
  })
  vim.fn.writefile({
    vim.json.encode({
      type = 'assistant',
      message = { content = { { type = 'tool_use', id = 't', name = 'Edit', input = {} } } },
    }),
  }, path)

  local seen = vim.wait(3000, function()
    return #signals > 0
  end, 20)

  follower.stop()
  eq(seen, true)
end

return T
