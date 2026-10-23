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

--- What the code under test reads of the files it opens: the paths it opens
--- and the bytes it reads.
---@class transcript_follow.Reads
---@field opened string[]
---@field bytes integer
---@field largest integer the most bytes one read returned
---@field stop fun() puts the functions back

--- Counts what is opened and read through `vim.uv` from now until `stop()`.
---
---@return transcript_follow.Reads
local function count_reads()
  local reads = { opened = {}, bytes = 0, largest = 0 }
  local open, read = vim.uv.fs_open, vim.uv.fs_read
  vim.uv.fs_open = function(path, ...)
    table.insert(reads.opened, path)
    return open(path, ...)
  end
  vim.uv.fs_read = function(...)
    local data, problem = read(...)
    reads.bytes = reads.bytes + #(data or '')
    reads.largest = math.max(reads.largest, #(data or ''))
    return data, problem
  end
  reads.stop = function()
    vim.uv.fs_open, vim.uv.fs_read = open, read
  end
  return reads
end

--- How many signals a follower of a case may deliver before the case stops it.
--- No case delivers so many; a follower that reads the same bytes again and
--- again would deliver them for ever, and the case would hang, not fail.
local MOST_SIGNALS = 1000

--- The number of timers open in this Neovim that repeat.
---
---@return integer
local function open_repeating_timers()
  local count = 0
  vim.uv.walk(function(handle)
    if handle:get_type() == 'timer' and not handle:is_closing() and handle:get_repeat() > 0 then
      count = count + 1
    end
  end)
  return count
end

--- The followers the case started, which its end stops, whether or not the
--- case did.
---@type aineo.transcript.Follower[]
local started_followers = {}

--- A follower of the transcript file `path`, with the signals and the
--- unreadable lines it reported so far.
---
---@param path string
---@return table following { path, signals, unreadable, follower }
local function follow_path(path)
  local following = { path = path, signals = {}, unreadable = {} }
  following.follower = assert(transcript.follow({
    path = path,
    on_signal = function(signal)
      table.insert(following.signals, signal)
      if #following.signals > MOST_SIGNALS and following.follower then
        following.follower.stop()
      end
    end,
    on_unreadable_line = function(length)
      table.insert(following.unreadable, length)
    end,
  }))
  table.insert(started_followers, following.follower)
  return following
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
  return follow_path(path)
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

--- The ids of the calls of `signals`, in order.
---
---@param signals aineo.transcript.Signal[]
---@return string[]
local function calls_of(signals)
  return vim.tbl_map(function(signal)
    return signal.call
  end, signals)
end

--- The signals of `signals` that are marked as replayed.
---
---@param signals aineo.transcript.Signal[]
---@return aineo.transcript.Signal[]
local function replayed_among(signals)
  return vim.tbl_filter(function(signal)
    return signal.replayed
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

--- How many files a case may open before the case stops its followers. A
--- follower that reads again what it has read opens the file for ever, and
--- the case would hang, not fail; no case opens so many.
local MOST_OPENS = 500

--- The notifications the case's code gave through `vim.notify`; the hooks put
--- the function back.
---@type { message: string, level: integer }[]
local notified = {}
local notify = vim.notify

--- The function `vim.uv.fs_open` is while the case runs: the one the hooks
--- found, which they put back.
local opener = nil

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      notified = {}
      vim.notify = function(message, level)
        table.insert(notified, { message = message, level = level })
      end
      local open = vim.uv.fs_open
      local opens = 0
      opener = open
      vim.uv.fs_open = function(...)
        opens = opens + 1
        if opens > MOST_OPENS then
          for _, follower in ipairs(started_followers) do
            follower.stop()
          end
        end
        return open(...)
      end
    end,
    post_case = function()
      vim.notify = notify
      vim.uv.fs_open = opener
      for _, follower in ipairs(started_followers) do
        follower.stop()
      end
      started_followers = {}
      vim.fn.delete(fixture.directory('office_transcript'), 'rf')
    end,
  },
})

T['follow()'] = MiniTest.new_set()

T['follow()']['replays the lines the file holds as replayed signals, in order'] = function()
  local following = follow_new_transcript(RECORDED_TURN)

  eq(kinds_of(following.signals), { 'prompt', 'tool_started', 'tool_finished', 'turn_ended' })
  eq(
    vim.tbl_map(function(signal)
      return signal.replayed
    end, following.signals),
    { true, true, true, true }
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
  local following = follow_path(path)

  eq(#following.signals, 0)
  fake_transcript.append_text(path, '\n')
  vim.wait(PATIENCE_MS, function()
    return #following.signals > 0
  end, 10)

  eq(calls_of(following.signals), { 'toolu_open' })
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

T['follow()']['replays a last line longer than the tail window by reading further back'] = function()
  local following = follow_new_transcript({
    tool_line('before'),
    tool_line('long', ('x'):rep(300 * 1024)),
  })

  eq(calls_of(following.signals), { 'before', 'long' })
  eq(following.unreadable, {})
  following.follower.stop()
end

T['follow()']['replays the lines before a last line too long to read, and reports that one'] = function()
  local too_long = tool_line('too_long', ('x'):rep(1536 * 1024))

  local following = follow_new_transcript({ tool_line('before'), too_long })

  eq(calls_of(following.signals), { 'before' })
  eq(following.unreadable, { #too_long })
  following.follower.stop()
end

T['follow()']['follows from the end of a file whose last line is longer than the longest window'] = function()
  local path = vim.fs.joinpath(fixture.directory('office_transcript'), 'session.jsonl')
  fake_transcript.append(path, { tool_line('huge', ('x'):rep(5 * 1024 * 1024)) })
  local following = follow_path(path)

  fake_transcript.append(path, { tool_line('after_the_huge') })
  vim.wait(PATIENCE_MS, function()
    return #following.signals > 0
  end, 10)

  eq(calls_of(following.signals), { 'after_the_huge' })
  eq(following.unreadable, {})
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
  eq(following.unreadable, { #tool_line('huge', ('y'):rep(1100 * 1024)) })
  following.follower.stop()
end

T['follow()']['counts a line of exactly a megabyte once, and delivers the line after it'] = function()
  local following = follow_new_transcript()
  local padding = 1024 * 1024 - #tool_line('exact', '')
  local exact = tool_line('exact', ('y'):rep(padding))

  fake_transcript.append(following.path, { exact, tool_line('after_the_exact') })
  vim.wait(PATIENCE_MS, function()
    return #following.signals > 0
  end, 10)
  vim.wait(QUIET_MS)

  eq(#exact, 1024 * 1024)
  eq(following.unreadable, { 1024 * 1024 })
  eq(
    vim.tbl_map(function(signal)
      return signal.call
    end, following.signals),
    { 'after_the_exact' }
  )
  following.follower.stop()
end

T['follow()']['replays a first line of the tail that starts on a line boundary'] = function()
  local first = vim.json.encode({ type = 'mode', padding = ('z'):rep(300) })
  local call = tool_line('toolu_on_the_boundary')
  local rest = 256 * 1024 - #call - 1
  local padding = vim.json.encode({ type = 'mode', padding = '' })
  local filler = vim.json.encode({ type = 'mode', padding = ('z'):rep(rest - #padding - 1) })

  local following = follow_new_transcript({ first, call, filler })

  eq(#call + 1 + #filler + 1, 256 * 1024)
  eq(
    vim.tbl_map(function(signal)
      return signal.call
    end, following.signals),
    { 'toolu_on_the_boundary' }
  )
  following.follower.stop()
end

T['follow()']['reads the lines of a file that was cut and written again, and those added after'] = function()
  local following = follow_new_transcript({
    tool_line('first', ('x'):rep(500)),
    tool_line('second', ('x'):rep(500)),
  })
  local replayed = #following.signals

  fake_transcript.rewrite(following.path, { tool_line('rewritten') })
  vim.wait(PATIENCE_MS, function()
    return #following.signals > replayed
  end, 10)
  fake_transcript.append(following.path, { tool_line('and_after') })
  vim.wait(PATIENCE_MS, function()
    return #following.signals > replayed + 1
  end, 10)

  eq(calls_of(vim.list_slice(following.signals, replayed + 1)), { 'rewritten', 'and_after' })
  following.follower.stop()
end

T['follow()']['reads the lines of a file replaced by a longer one, and those added after'] = function()
  local following = follow_new_transcript({ tool_line('first', ('x'):rep(500)) })
  local replayed = #following.signals

  fake_transcript.replace(following.path, { tool_line('swapped', ('y'):rep(2000)) })
  vim.wait(PATIENCE_MS, function()
    return #following.signals > replayed
  end, 10)
  fake_transcript.append(following.path, { tool_line('and_after') })
  vim.wait(PATIENCE_MS, function()
    return #following.signals > replayed + 1
  end, 10)

  eq(calls_of(vim.list_slice(following.signals, replayed + 1)), { 'swapped', 'and_after' })
  eq(following.unreadable, {})
  following.follower.stop()
end

T['follow()']['waits for a folder that is not there yet either'] = function()
  local folder = vim.fs.joinpath(fixture.directory('office_transcript'), 'projects', 'later')
  local following = follow_path(vim.fs.joinpath(folder, 'session.jsonl'))

  vim.fn.mkdir(folder, 'p')
  fake_transcript.append(following.path, { tool_line('in_a_new_folder') })
  vim.wait(PATIENCE_MS, function()
    return #following.signals > 0
  end, 10)

  eq(calls_of(following.signals), { 'in_a_new_folder' })
  following.follower.stop()
end

T['follow()']['delivers a line only whole, once, with a line cut short after it'] = function()
  local following = follow_new_transcript()
  local cut = tool_line('cut_short')

  fake_transcript.append_text(following.path, tool_line('whole') .. '\n' .. cut:sub(1, 30))
  vim.wait(PATIENCE_MS, function()
    return #following.signals > 0
  end, 10)
  vim.wait(QUIET_MS)
  local before = calls_of(following.signals)
  fake_transcript.append_text(following.path, cut:sub(31) .. '\n')
  vim.wait(PATIENCE_MS, function()
    return #following.signals > 1
  end, 10)
  vim.wait(QUIET_MS)

  eq(before, { 'whole' })
  eq(calls_of(following.signals), { 'whole', 'cut_short' })
  eq(following.unreadable, {})
  following.follower.stop()
end

T['follow()']['replays no more than the tail of a long file when it starts'] = function()
  local lines = {}
  for number = 1, 600 do
    table.insert(lines, tool_line(('call%d'):format(number), ('x'):rep(1000)))
  end
  local path = vim.fs.joinpath(fixture.directory('office_transcript'), 'session.jsonl')
  fake_transcript.append(path, lines)

  local following = follow_path(path)

  eq(#following.signals > 200 and #following.signals <= 256 * 1024 / 1000, true)
  following.follower.stop()
end

T['follow()']['finds appended lines by looking every half second where the system gives no events'] = function()
  local new_fs_event = vim.uv.new_fs_event
  vim.uv.new_fs_event = function()
    return {
      start = function()
        return nil, 'ENOSYS'
      end,
      close = function() end,
      is_closing = function()
        return false
      end,
    }
  end
  local following = follow_new_transcript()
  vim.uv.new_fs_event = new_fs_event

  fake_transcript.append(following.path, { tool_line('found_by_looking') })
  local found = vim.wait(PATIENCE_MS, function()
    return #following.signals > 0
  end, 10)

  eq(found, true)
  eq(calls_of(following.signals), { 'found_by_looking' })
  following.follower.stop()
end

T['follow()']['reads nothing and holds no timer or watch once stopped'] = function()
  local timers_before = open_handles('timer')
  local following = follow_new_transcript({ tool_line('first') })
  local reads = count_reads()

  following.follower.stop()
  fake_transcript.append(following.path, { tool_line('late') })
  vim.wait(1200)
  reads.stop()

  eq(reads.opened, {})
  eq(following.signals[#following.signals].call, 'first')
  eq(open_handles('timer'), timers_before)
  eq(open_handles('fs_event'), 0)
end

T['follow()']['delivers nothing more and reads nothing more once stopped from its own callback'] = function()
  local path = vim.fs.joinpath(fixture.directory('office_transcript'), 'session.jsonl')
  fake_transcript.append_text(path, '')
  local calls = {}
  local follower
  follower = transcript.follow({
    path = path,
    on_signal = function(signal)
      table.insert(calls, signal.call)
      follower.stop()
    end,
  })
  table.insert(started_followers, follower)
  local lines = {}
  for number = 1, 1200 do
    table.insert(lines, tool_line(('call%d'):format(number), ('x'):rep(1000)))
  end
  local reads = count_reads()

  fake_transcript.append(path, lines)
  vim.wait(PATIENCE_MS, function()
    return #calls > 0
  end, 10)
  vim.wait(QUIET_MS)
  reads.stop()

  eq(calls, { 'call1' })
  eq(#reads.opened, 1)
end

T['follow()']['delivers none of the other calls of a line once stopped from the callback of its first'] = function()
  local path = vim.fs.joinpath(fixture.directory('office_transcript'), 'session.jsonl')
  fake_transcript.append_text(path, '')
  local calls = {}
  local follower
  follower = transcript.follow({
    path = path,
    on_signal = function(signal)
      table.insert(calls, signal.call)
      follower.stop()
    end,
  })
  table.insert(started_followers, follower)
  local two_calls = vim.json.encode({
    type = 'assistant',
    message = {
      content = {
        { type = 'tool_use', id = 'first', name = 'Bash', input = {} },
        { type = 'tool_use', id = 'second', name = 'Bash', input = {} },
      },
    },
  })

  fake_transcript.append(path, { two_calls })
  vim.wait(PATIENCE_MS, function()
    return #calls > 0
  end, 10)
  vim.wait(QUIET_MS)

  eq(calls, { 'first' })
end

T['follow()']['reads a megabyte at most in one pass of what is appended'] = function()
  local following = follow_new_transcript()
  local reads = count_reads()
  local filler = vim.json.encode({ type = 'progress', padding = ('x'):rep(1000) })
  local lines = {}
  for number = 1, 3 * 1024 do
    lines[number] = filler
  end
  table.insert(lines, tool_line('after_the_burst'))

  fake_transcript.append(following.path, lines)
  vim.wait(PATIENCE_MS, function()
    return #following.signals > 0
  end, 10)
  reads.stop()

  eq(calls_of(following.signals), { 'after_the_burst' })
  eq(reads.largest <= 1024 * 1024, true)
end

T['follow()']['lets the event loop turn between the passes of a burst it reads'] = function()
  local following = follow_new_transcript()
  local turns = 0
  local turn_counter = assert(vim.uv.new_check())
  turn_counter:start(function()
    turns = turns + 1
  end)
  local turns_at_reads = {}
  local read = vim.uv.fs_read
  vim.uv.fs_read = function(...)
    turns_at_reads[turns] = true
    return read(...)
  end
  local filler = vim.json.encode({ type = 'progress', padding = ('x'):rep(1000) })
  local lines = {}
  for number = 1, 6 * 1024 do
    lines[number] = filler
  end
  table.insert(lines, tool_line('after_the_burst'))

  fake_transcript.append(following.path, lines)
  vim.wait(PATIENCE_MS, function()
    return #following.signals > 0
  end, 10)
  vim.uv.fs_read = read
  turn_counter:stop()
  turn_counter:close()

  eq(calls_of(following.signals), { 'after_the_burst' })
  eq(vim.tbl_count(turns_at_reads) >= 4, true)
end

T['follow()']['stops looking every half second at a file once it is there to watch'] = function()
  local path = vim.fs.joinpath(fixture.directory('office_transcript'), 'late', 'session.jsonl')
  local following = follow_path(path)
  local while_missing = open_repeating_timers()

  fake_transcript.append(path, { tool_line('first') })
  vim.wait(PATIENCE_MS, function()
    return #following.signals > 0
  end, 10)

  eq({ while_missing, open_repeating_timers() }, { 2, 1 })
end

T['follow()']['goes on, delivering no line twice, after a callback that raised, and says so once without the line'] = function()
  local path = vim.fs.joinpath(fixture.directory('office_transcript'), 'session.jsonl')
  fake_transcript.append_text(path, '')
  local heard = {}
  local follower = transcript.follow({
    path = path,
    on_signal = function(signal)
      table.insert(heard, signal.call)
      if signal.call == 'raises_secret' or signal.call == 'three' then
        error('the consumer failed')
      end
    end,
  })
  table.insert(started_followers, follower)

  fake_transcript.append(path, { tool_line('one'), tool_line('raises_secret'), tool_line('three') })
  vim.wait(PATIENCE_MS, function()
    return #heard >= 3
  end, 10)
  fake_transcript.append(path, { tool_line('four') })
  vim.wait(PATIENCE_MS, function()
    return #heard >= 4
  end, 10)

  eq(heard, { 'one', 'raises_secret', 'three', 'four' })
  eq(#notified, 1)
  eq(notified[1].message:find('tool_started', 1, true) ~= nil, true)
  eq(notified[1].message:find('raises_secret', 1, true), nil)
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

T['follow()']['waits for a file that is not there yet and delivers its lines, none of them a replay'] = function()
  local path = vim.fs.joinpath(fixture.directory('office_transcript'), 'later.jsonl')
  local following = follow_path(path)
  vim.wait(QUIET_MS)
  local before = #following.signals

  fake_transcript.append(path, RECORDED_TURN)
  vim.wait(PATIENCE_MS, function()
    return #following.signals >= 4
  end, 10)

  eq(before, 0)
  eq(kinds_of(following.signals), { 'prompt', 'tool_started', 'tool_finished', 'turn_ended' })
  eq(replayed_among(following.signals), {})
  following.follower.stop()
end

return T
