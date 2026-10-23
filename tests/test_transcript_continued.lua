local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local transcript = require('aineo.transcript')

local RECORDED_TURN = fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 3000

--- The kinds of signal the recorded turn gives.
local KINDS_OF_THE_RECORDED_TURN = { 'prompt', 'tool_started', 'tool_finished', 'turn_ended' }

--- Three sessions of the form Claude Code gives: the one followed, the one it
--- is continued in, and the one that continues.
local FIRST = '11111111-1111-4111-8111-111111111111'
local SECOND = '22222222-2222-4222-8222-222222222222'
local THIRD = '33333333-3333-4333-8333-333333333333'

--- The id of the session numbered `number`, of the form Claude Code gives.
---
---@param number integer
---@return string
local function session_numbered(number)
  return ('aaaaaaaa-aaaa-4aaa-8aaa-%012d'):format(number)
end

--- The moment the tab began following the session, as the cases hand the
--- follower it: 2026-01-01T00:00:00Z, in seconds since 1970.
local ANCHOR = 1767225600

--- Stamps of `continued-in` lines: three seconds after the anchor, and a
--- minute before it.
local AFTER_THE_ANCHOR = '2026-01-01T00:00:03.000Z'
local BEFORE_THE_ANCHOR = '2025-12-31T23:59:00.000Z'

--- The followers the case started, which its end stops.
---@type aineo.transcript.Follower[]
local started_followers = {}

--- The directory of the case's transcript files, emptied as the case starts.
local directory = nil

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      directory = fixture.directory('office_transcript_continued')
    end,
    post_case = function()
      for _, follower in ipairs(started_followers) do
        follower.stop()
      end
      started_followers = {}
      vim.fn.delete(directory, 'rf')
    end,
  },
})

--- The hand-built shape of a session Claude Code 2.1.309 continued in another:
--- the kinds of line measured in it, the last of which is the
--- `continued-in` line that names the session it goes on in.
local CONTINUED_SHAPE = fake_transcript.lines_of('session-continued-shape-2.1.309.jsonl')

--- The `continued-in` line of the shape.
local CONTINUED_IN_LINE = CONTINUED_SHAPE[#CONTINUED_SHAPE]

--- The session the shape's `continued-in` line names.
local CONTINUED_IN = '22222222-2222-4222-8222-222222222222'

--- The transcript file of `session` in the directory of the case.
---
---@param session string
---@return string path
local function transcript_of(session)
  return vim.fs.joinpath(directory, session .. '.jsonl')
end

--- A `continued-in` line of the session `from` that names `to`, stamped
--- `timestamp`, three seconds after the anchor unless told.
---
---@param from string
---@param to string
---@param timestamp? string
---@return string
local function continued_in_line(from, to, timestamp)
  return vim.json.encode({
    type = 'continued-in',
    timestamp = timestamp or AFTER_THE_ANCHOR,
    sessionId = from,
    continuedInSessionId = to,
  })
end

--- Follows the transcript file `path`, with the signals it delivered so far.
---
---@param path string
---@param since? number|false when the tab began following the session; the anchor of the cases unless `false`, which hands the follower none
---@return { signals: aineo.transcript.Signal[], follower: aineo.transcript.Follower }
local function follow_path(path, since)
  local following = { signals = {} }
  following.follower = transcript.follow({
    path = path,
    since = since == nil and ANCHOR or since or nil,
    on_signal = function(signal)
      table.insert(following.signals, signal)
    end,
  })
  table.insert(started_followers, following.follower)
  return following
end

--- The signals of `signals` of the kind `kind`.
---
---@param signals aineo.transcript.Signal[]
---@param kind string
---@return aineo.transcript.Signal[]
local function of_kind(signals, kind)
  return vim.tbl_filter(function(signal)
    return signal.kind == kind
  end, signals)
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

T['signals_of_line()'] = MiniTest.new_set()

T['signals_of_line()']['gives a session_continued signal for the line that names the session it goes on in'] = function()
  local signals = transcript.signals_of_line(CONTINUED_IN_LINE, 'main')

  eq(signals, {
    { agent = 'main', kind = 'session_continued', session = CONTINUED_IN, at = 1767225603 },
  })
end

T['signals_of_line()']['gives no signal for the line of a subagent'] = function()
  local signals = transcript.signals_of_line(CONTINUED_IN_LINE, 'a0000000000000001')

  eq(signals, {})
end

T['signals_of_line()']['gives no signal when the session it names is not a session id'] =
  MiniTest.new_set({
    parametrize = {
      { '"continuedInSessionId":"../../elsewhere/22222222-2222-4222-8222-222222222222"' },
      { '"continuedInSessionId":"22222222-2222-4222-8222-22222222222"' },
      { '"continuedInSessionId":"22222222-2222-4222-8222-2222222222222"' },
      { '"continuedInSessionId":"22222222-2222-4222-8222-22222222222g"' },
      { '"continuedInSessionId":""' },
      { '"continuedInSessionId":7' },
      { '"continuedInSessionId":null' },
      { '"continuedInSessionId":["22222222-2222-4222-8222-222222222222"]' },
      { '"somethingElse":null' },
    },
  })

T['signals_of_line()']['gives no signal when the session it names is not a session id']['field'] = function(
  field
)
  local line = ('{"type":"continued-in",%s}'):format(field)

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, {})
end

T['signals_of_line()']['gives only the prompt for the other lines of the shape, the kinds measured in it'] = function()
  local others = vim.list_slice(CONTINUED_SHAPE, 1, #CONTINUED_SHAPE - 1)

  local kinds = vim
    .iter(others)
    :map(function(line)
      return vim.tbl_map(function(signal)
        return signal.kind
      end, transcript.signals_of_line(line, 'main'))
    end)
    :totable()

  eq(kinds, { {}, {}, {}, {}, {}, { 'prompt' }, {}, {}, {}, {} })
end

T['follow()'] = MiniTest.new_set()

T['follow()']['follows the session a transcript says it was continued in, in place of the transcript'] = function()
  fake_transcript.append(transcript_of(FIRST), { continued_in_line(FIRST, SECOND) })
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), KINDS_OF_THE_RECORDED_TURN)
end

T['follow()']['follows the transcript of the session it was continued in before that file is written, and delivers its lines as news'] = function()
  fake_transcript.append(transcript_of(FIRST), { continued_in_line(FIRST, SECOND) })
  local following = follow_path(transcript_of(FIRST))

  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)
  vim.wait(PATIENCE_MS, function()
    return #following.signals >= 4
  end, 10)

  eq(kinds_of(following.signals), KINDS_OF_THE_RECORDED_TURN)
  eq(
    vim.tbl_map(function(signal)
      return signal.replayed
    end, following.signals),
    {}
  )
end

T['follow()']['follows the transcript itself when it says nothing of a continuation'] = function()
  fake_transcript.append(transcript_of(FIRST), RECORDED_TURN)
  fake_transcript.append(transcript_of(SECOND), vim.list_slice(RECORDED_TURN, 1, 2))

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), KINDS_OF_THE_RECORDED_TURN)
end

T['follow()']['follows the target of the first continued-in line stamped after the anchor, not the last'] = function()
  fake_transcript.append(transcript_of(FIRST), {
    continued_in_line(FIRST, SECOND),
    continued_in_line(FIRST, THIRD),
  })
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)
  fake_transcript.append(transcript_of(THIRD), vim.list_slice(RECORDED_TURN, 1, 2))

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), KINDS_OF_THE_RECORDED_TURN)
end

T['follow()']['skips the continued-in lines stamped before the anchor, as the lines of earlier resumes are'] = function()
  local lines = {}
  for number = 1, 12 do
    table.insert(lines, continued_in_line(FIRST, session_numbered(number), BEFORE_THE_ANCHOR))
  end
  table.insert(lines, continued_in_line(FIRST, session_numbered(13)))
  table.insert(lines, continued_in_line(FIRST, session_numbered(14)))
  fake_transcript.append(transcript_of(FIRST), lines)
  fake_transcript.append(transcript_of(session_numbered(13)), RECORDED_TURN)
  fake_transcript.append(transcript_of(session_numbered(14)), vim.list_slice(RECORDED_TURN, 1, 2))
  fake_transcript.append(transcript_of(session_numbered(5)), vim.list_slice(RECORDED_TURN, 1, 2))

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), KINDS_OF_THE_RECORDED_TURN)
end

T['follow()']['keeps following the transcript when no continued-in line is stamped after the anchor'] = function()
  fake_transcript.append(transcript_of(FIRST), {
    RECORDED_TURN[3],
    continued_in_line(FIRST, SECOND, BEFORE_THE_ANCHOR),
  })
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), { 'prompt', 'session_continued' })
end

T['follow()']['keeps following the transcript when it is given no anchor'] = function()
  fake_transcript.append(transcript_of(FIRST), {
    RECORDED_TURN[3],
    continued_in_line(FIRST, SECOND),
  })
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST), false)

  eq(kinds_of(following.signals), { 'prompt', 'session_continued' })
end

T['follow()']['follows a continued-in line stamped up to 10 seconds before the anchor, the resume having written it as it began'] = function()
  fake_transcript.append(transcript_of(FIRST), {
    continued_in_line(FIRST, SECOND, '2025-12-31T23:59:51.000Z'),
  })
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), KINDS_OF_THE_RECORDED_TURN)
end

T['follow()']['does not follow a continued-in line stamped more than 10 seconds before the anchor'] = function()
  fake_transcript.append(transcript_of(FIRST), {
    RECORDED_TURN[3],
    continued_in_line(FIRST, SECOND, '2025-12-31T23:59:49.000Z'),
  })
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), { 'prompt', 'session_continued' })
end

T['follow()']['follows a continuation of a continuation to the end of the chain'] = function()
  fake_transcript.append(transcript_of(FIRST), { continued_in_line(FIRST, SECOND) })
  fake_transcript.append(transcript_of(SECOND), { continued_in_line(SECOND, THIRD) })
  fake_transcript.append(transcript_of(THIRD), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), KINDS_OF_THE_RECORDED_TURN)
end

T['follow()']['stops at the file that continues in one already passed'] = function()
  fake_transcript.append(transcript_of(FIRST), { continued_in_line(FIRST, SECOND) })
  fake_transcript.append(
    transcript_of(SECOND),
    vim.list_extend(vim.list_slice(RECORDED_TURN, 1, 5), { continued_in_line(SECOND, FIRST) })
  )

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), { 'prompt', 'tool_started', 'session_continued' })
end

T['follow()']['finds a continued-in line further back than the tail it replays'] = function()
  local filler = vim.json.encode({ type = 'api-request-blob', blob = ('x'):rep(1000) })
  local lines = { continued_in_line(FIRST, SECOND) }
  for _ = 1, 700 do
    table.insert(lines, filler)
  end
  fake_transcript.append(transcript_of(FIRST), lines)
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), KINDS_OF_THE_RECORDED_TURN)
end

--- A line that gives no signal, to fill a file with.
local FILLER_LINE = vim.json.encode({ type = 'padding', text = ('z'):rep(80) })

T['follow()']['finds a continued-in line wherever it lies in the file, at the edges of what is read at a time'] =
  MiniTest.new_set({
    parametrize = {
      { 1000 },
      { 1048576 - 300 },
      { 1048576 - 100 },
      { 1048576 },
      { 1048576 + 50 },
      { 1048576 + 150 },
      { 1048576 + 250 },
      { 2 * 1048576 + 50 },
      { 3 * 1048576 + 5000 },
    },
  })

T['follow()']['finds a continued-in line wherever it lies in the file, at the edges of what is read at a time']['from the end'] = function(
  bytes_from_end
)
  local continued_in = continued_in_line(FIRST, SECOND)
  local after = math.floor((bytes_from_end - #continued_in - 1) / (#FILLER_LINE + 1))
  local lines = {}
  for _ = 1, 10 do
    table.insert(lines, FILLER_LINE)
  end
  table.insert(lines, continued_in)
  for _ = 1, after do
    table.insert(lines, FILLER_LINE)
  end
  fake_transcript.append(transcript_of(FIRST), lines)
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), KINDS_OF_THE_RECORDED_TURN)
end

T['follow()']['does not look for a continued-in line further back than 8 MiB from the end'] = function()
  local lines = { continued_in_line(FIRST, SECOND) }
  for _ = 1, 9 * 1048576 / (#FILLER_LINE + 1) do
    table.insert(lines, FILLER_LINE)
  end
  fake_transcript.append(transcript_of(FIRST), lines)
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), {})
end

T['follow()']['reads no more than the tail and 8 MiB twice of a long file that holds no continued-in line, 1 MiB at a time'] = function()
  local lines = {}
  for _ = 1, 12 * 1048576 / (#FILLER_LINE + 1) do
    table.insert(lines, FILLER_LINE)
  end
  fake_transcript.append(transcript_of(FIRST), lines)
  local bytes, largest = 0, 0
  local read = vim.uv.fs_read
  vim.uv.fs_read = function(...)
    local data, problem = read(...)
    bytes = bytes + #(data or '')
    largest = math.max(largest, #(data or ''))
    return data, problem
  end

  local followed, failure = pcall(follow_path, transcript_of(FIRST))
  vim.uv.fs_read = read

  assert(followed, failure)
  eq(bytes <= 256 * 1024 + 2 * (8 * 1048576 + 8 * 4096) + 1, true)
  eq(largest <= 1048576 + 4096, true)
end

T['follow()']['does not follow a session named by text that only holds the field'] = function()
  local mention = vim.json.encode({
    type = 'user',
    message = { role = 'user', content = ('{"continuedInSessionId":"%s"}'):format(SECOND) },
  })
  fake_transcript.append(transcript_of(FIRST), { mention })
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), { 'prompt' })
end

T['follow()']['does not follow a session named by a line that is cut short'] = function()
  fake_transcript.append(transcript_of(FIRST), { RECORDED_TURN[2] })
  fake_transcript.append_text(transcript_of(FIRST), continued_in_line(FIRST, SECOND):sub(1, -3))
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(#following.signals < 4, true)
  eq(vim.tbl_contains(kinds_of(following.signals), 'turn_ended'), false)
end

T['follow()']['does not follow a name that would leave the folder of the transcript'] = function()
  fake_transcript.append(transcript_of(FIRST), { continued_in_line(FIRST, '../' .. SECOND) })
  fake_transcript.append(vim.fs.joinpath(directory, '..', SECOND .. '.jsonl'), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), {})
  vim.fn.delete(vim.fs.joinpath(directory, '..', SECOND .. '.jsonl'))
end

T['follow()']['follows the subagents of the session it was continued in'] = function()
  fake_transcript.append(transcript_of(FIRST), { continued_in_line(FIRST, SECOND) })
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)
  local folder = vim.fs.joinpath(directory, SECOND, 'subagents')
  fake_transcript.write_subagent_meta(
    vim.fs.joinpath(folder, 'agent-a0000000000000001.meta.json'),
    'running'
  )
  fake_transcript.append(
    vim.fs.joinpath(folder, 'agent-a0000000000000001.jsonl'),
    fake_transcript.lines_of('subagent-explore-2.1.308.jsonl')
  )

  local following = follow_path(transcript_of(FIRST))
  vim.wait(PATIENCE_MS, function()
    return vim.tbl_contains(kinds_of(following.signals), 'subagent_started')
  end, 10)

  eq(vim.tbl_contains(kinds_of(following.signals), 'subagent_started'), true)
end

T['follow()']['delivers a continued-in line appended later as news, for the follower of the session to act on'] = function()
  fake_transcript.append(transcript_of(FIRST), RECORDED_TURN)
  local following = follow_path(transcript_of(FIRST))
  local before = #following.signals

  fake_transcript.append(transcript_of(FIRST), { continued_in_line(FIRST, SECOND) })
  vim.wait(PATIENCE_MS, function()
    return #following.signals > before
  end, 10)

  eq(following.signals[before + 1], {
    agent = 'main',
    kind = 'session_continued',
    session = SECOND,
    at = 1767225603,
  })
end

T['follow()']['skips a line that holds the field of a continued-in line but is none, and reads the lines after it'] = function()
  local tool_call_holding_the_field = vim.json.encode({
    type = 'assistant',
    message = {
      content = {
        {
          type = 'tool_use',
          id = 'toolu_x',
          name = 'Bash',
          input = { continuedInSessionId = THIRD },
        },
      },
    },
  })
  fake_transcript.append(transcript_of(FIRST), {
    continued_in_line(FIRST, SECOND),
    tool_call_holding_the_field,
  })
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(kinds_of(following.signals), KINDS_OF_THE_RECORDED_TURN)
end

T['follow()']['follows eight continuations in a row and no more'] = function()
  for number = 0, 10 do
    local lines = { continued_in_line(session_numbered(number), session_numbered(number + 1)) }
    if number == 8 then
      lines = RECORDED_TURN
    end
    fake_transcript.append(transcript_of(session_numbered(number)), lines)
  end

  local following = follow_path(transcript_of(session_numbered(0)))

  eq(kinds_of(following.signals), KINDS_OF_THE_RECORDED_TURN)
end

T['follow()']['finds the continued-in line in a time that does not grow with the lines that hold the field'] = function()
  local tool_call_holding_the_field = vim.json.encode({
    type = 'assistant',
    message = {
      content = {
        {
          type = 'tool_use',
          id = 'toolu_x',
          name = 'Bash',
          input = { continuedInSessionId = 'x' },
        },
      },
    },
  })
  local lines = { continued_in_line(FIRST, SECOND) }
  for _ = 1, 7000 do
    table.insert(lines, tool_call_holding_the_field)
  end
  fake_transcript.append(transcript_of(FIRST), lines)
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)

  local started = vim.uv.hrtime()
  local following = follow_path(transcript_of(FIRST))
  local milliseconds = (vim.uv.hrtime() - started) / 1e6

  eq(kinds_of(following.signals), KINDS_OF_THE_RECORDED_TURN)
  eq(milliseconds < 1000, true)
end

T['follow()']['finds the continued-in line in a time that does not grow with the fields in one line'] = function()
  local one_line = '{"type":"assistant","x":"' .. ('"continuedInSessionId" '):rep(4000) .. '"}'
  fake_transcript.append(transcript_of(FIRST), { continued_in_line(FIRST, SECOND), one_line })
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)

  local started = vim.uv.hrtime()
  local following = follow_path(transcript_of(FIRST))
  local milliseconds = (vim.uv.hrtime() - started) / 1e6

  eq(kinds_of(following.signals), KINDS_OF_THE_RECORDED_TURN)
  eq(milliseconds < 1000, true)
end

T['follow()']['tells of a continued-in line written between the search and the replay of the tail, as news'] = function()
  fake_transcript.append(transcript_of(FIRST), { RECORDED_TURN[3] })
  fake_transcript.append(transcript_of(SECOND), RECORDED_TURN)
  local continuation = require('aineo.transcript.continuation')
  local resolve = continuation.resolve
  local searches = 0
  continuation.resolve = function(...)
    local resolved = resolve(...)
    searches = searches + 1
    if searches == 1 then
      fake_transcript.append(transcript_of(FIRST), { continued_in_line(FIRST, SECOND) })
    end
    return resolved
  end

  local followed, following = pcall(follow_path, transcript_of(FIRST))
  continuation.resolve = resolve

  assert(followed, following)
  eq(searches, 2)
  eq(of_kind(following.signals, 'session_continued'), {
    {
      agent = 'main',
      kind = 'session_continued',
      session = SECOND,
      replayed = true,
      at = 1767225603,
    },
    { agent = 'main', kind = 'session_continued', session = SECOND },
  })
end

T['follow()']['names the sessions of the chain it follows, the transcript first and the file followed last'] = function()
  fake_transcript.append(transcript_of(FIRST), { continued_in_line(FIRST, SECOND) })
  fake_transcript.append(transcript_of(SECOND), { continued_in_line(SECOND, THIRD) })
  fake_transcript.append(transcript_of(THIRD), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(following.follower.sessions, { FIRST, SECOND, THIRD })
end

T['follow()']['names the session of the transcript alone when it follows no continuation'] = function()
  fake_transcript.append(transcript_of(FIRST), RECORDED_TURN)

  local following = follow_path(transcript_of(FIRST))

  eq(following.follower.sessions, { FIRST })
end

return T
