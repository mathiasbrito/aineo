--- The codec of `aineo.transcript`: one line of a Claude Code transcript as the
--- signals the office reads from it. Pure: it holds no editor state.
---
--- A transcript line is a JSON object with a `type`. Only the lines that tell
--- what an agent does are read:
--- - an `assistant` line: its tool calls (`tool_use` blocks) and its thinking,
---   and, in a subagent's transcript, the text that ends its turn;
--- - a `user` line: the user's prompt, a tool's result (`tool_result` blocks),
---   the user's interruption, and the notice of a finished background task;
--- - a `system` line: the end of a turn (`turn_duration`) and a compaction
---   (`compact_boundary`).
--- Every other line, known or not, gives no signal. The format is not
--- documented by Claude Code; the recordings under
--- `tests/fixtures/transcripts/` pin the shapes read here.

local timestamp = require('aineo.transcript.timestamp')

local M = {}

--- A decoded null in an object is an absent field; one in a list stays
--- `vim.NIL`, so that a list keeps its length and the blocks after it.
local DECODE_OPTIONS = { luanil = { object = true } }

--- The agent of the session's own transcript; a subagent's is its id.
M.MAIN_AGENT = 'main'

--- What `signals_of_line()` says of a line that is not JSON.
M.NOT_JSON = 'not JSON'

---@alias aineo.transcript.SignalKind 'prompt'|'thinking'|'tool_started'|'tool_finished'|'turn_ended'|'interrupted'|'compacted'|'background_done'

--- What an agent did, in plain words.
---@class aineo.transcript.Signal
---@field agent string 'main', or a subagent's id
---@field kind aineo.transcript.SignalKind
---@field tool? string the tool's name, for `tool_started`
---@field input? table the tool's input, for `tool_started`
---@field call? string the tool call's id, for `tool_started` and `tool_finished`
---@field failed? boolean whether the tool's result was an error, for `tool_finished`
---@field at? number seconds since 1970 of the line the signal came from, when the line is stamped
---@field replayed? boolean set by the follower on what it read from the file's tail at the start

--- What the text of a user line begins with when a background task or agent
--- has finished.
local TASK_NOTICE = '<task-notification'

--- What the text of a user line begins with when the user interrupted the
--- agent.
local INTERRUPTION = '[Request interrupted by user'

--- `value` when it is a string, else nothing.
---
---@param value any
---@return string|nil
local function string_or_nil(value)
  if type(value) == 'string' then
    return value
  end
  return nil
end

--- The content of a message line: a string for the user's own text, a list of
--- blocks otherwise; `nil` when the line holds none.
---
---@param record table a decoded line
---@return string|table|nil content
local function message_content(record)
  local message = record.message
  return type(message) == 'table' and message.content or nil
end

--- The blocks of a message line's content that are tables, in order; none for
--- a content that is not a list of blocks, such as the user's own prompt.
---
---@param record table a decoded line
---@return table[] blocks
local function content_blocks(record)
  local content = message_content(record)
  if type(content) ~= 'table' then
    return {}
  end
  return vim.tbl_filter(function(block)
    return type(block) == 'table'
  end, content)
end

--- The signals of the blocks of `record`, in order: each block of a type
--- `signal_of_block` has an entry for gives the signal that entry makes of it,
--- if it makes one.
---
---@param record table
---@param agent string
---@param signal_of_block table<string, fun(block: table, agent: string): aineo.transcript.Signal|nil> by the block's `type`
---@return aineo.transcript.Signal[]
local function signals_of_blocks(record, agent, signal_of_block)
  local signals = {}
  for _, block in ipairs(content_blocks(record)) do
    local make_signal = signal_of_block[block.type]
    local signal = make_signal and make_signal(block, agent)
    if signal then
      table.insert(signals, signal)
    end
  end
  return signals
end

---@param block table a `tool_use` block
---@param agent string
---@return aineo.transcript.Signal
local function tool_started(block, agent)
  return {
    agent = agent,
    kind = 'tool_started',
    tool = string_or_nil(block.name),
    input = type(block.input) == 'table' and block.input or {},
    call = string_or_nil(block.id),
  }
end

---@param block table a `tool_result` block
---@param agent string
---@return aineo.transcript.Signal
local function tool_finished(block, agent)
  return {
    agent = agent,
    kind = 'tool_finished',
    call = string_or_nil(block.tool_use_id),
    failed = block.is_error == true,
  }
end

---@param _ table a `thinking` block
---@param agent string
---@return aineo.transcript.Signal
local function thought(_, agent)
  return { agent = agent, kind = 'thinking' }
end

---@param block table a `text` block of a user line
---@param agent string
---@return aineo.transcript.Signal|nil
local function interruption(block, agent)
  local text = string_or_nil(block.text)
  if text and text:sub(1, #INTERRUPTION) == INTERRUPTION then
    return { agent = agent, kind = 'interrupted' }
  end
  return nil
end

--- The signals of a user line whose content is a text: a background task's
--- notice of having finished; else a prompt, unless the text opens another
--- notice (`<`) or a bracketed message (`[`), or is the summary a compaction
--- leaves.
---
---@param record table the decoded line
---@param text string
---@param agent string
---@return aineo.transcript.Signal[]
local function signals_of_text(record, text, agent)
  if text:sub(1, #TASK_NOTICE) == TASK_NOTICE then
    return { { agent = agent, kind = 'background_done' } }
  end
  local opening = text:sub(1, 1)
  if text == '' or opening == '<' or opening == '[' or record.isCompactSummary == true then
    return {}
  end
  return { { agent = agent, kind = 'prompt' } }
end

--- Whether `record` is an assistant line whose text block ends the agent's
--- turn: a text block with the stop reason `end_turn`. A block of thinking
--- can carry the same stop reason, and is followed by the text.
---
---@param record table an assistant line
---@return boolean
local function ends_turn_with_text(record)
  local message = record.message
  return type(message) == 'table'
    and message.stop_reason == 'end_turn'
    and vim.iter(content_blocks(record)):any(function(block)
      return block.type == 'text'
    end)
end

--- The signals of an assistant line: its tool calls and thoughts, in order.
--- A subagent's transcript holds no line that times its turns, so its turn
--- ends with the text that stops it; the main agent's ends with the `system`
--- line that times it.
---
---@param record table
---@param agent string
---@return aineo.transcript.Signal[]
local function signals_of_assistant(record, agent)
  local signals = signals_of_blocks(record, agent, { tool_use = tool_started, thinking = thought })
  if agent ~= M.MAIN_AGENT and ends_turn_with_text(record) then
    table.insert(signals, { agent = agent, kind = 'turn_ended' })
  end
  return signals
end

--- The kind of signal a `system` line gives, by the line's `subtype`.
---@type table<string, aineo.transcript.SignalKind>
local SYSTEM_SUBTYPE_KINDS = {
  turn_duration = 'turn_ended',
  compact_boundary = 'compacted',
}

--- What each type of line gives, by the line's `type`.
---@type table<string, fun(record: table, agent: string): aineo.transcript.Signal[]>
local READERS = {
  assistant = signals_of_assistant,
  user = function(record, agent)
    local content = message_content(record)
    if type(content) == 'string' then
      return signals_of_text(record, content, agent)
    end
    return signals_of_blocks(record, agent, { tool_result = tool_finished, text = interruption })
  end,
  system = function(record, agent)
    local kind = SYSTEM_SUBTYPE_KINDS[record.subtype]
    return kind and { { agent = agent, kind = kind } } or {}
  end,
}

--- The signals one line of a transcript gives, in the order of its blocks;
--- none for a line the office does not read, whatever its `type`, and none for
--- a field that is null or of another JSON type than expected.
---
--- A line that is not JSON gives `nil` and `M.NOT_JSON`: the caller counts it,
--- and never quotes it.
---
---@param line string one line, without its newline
---@param agent string 'main', or the id of the subagent whose transcript the line is in
---@return aineo.transcript.Signal[]|nil signals
---@return string|nil problem
function M.signals_of_line(line, agent)
  local decoded, record = pcall(vim.json.decode, line, DECODE_OPTIONS)
  if not decoded then
    return nil, M.NOT_JSON
  end
  if type(record) ~= 'table' then
    return {}
  end
  local read = READERS[record.type]
  local line_signals = read and read(record, agent) or {}
  local at = timestamp.seconds_of(record.timestamp)
  for _, signal in ipairs(line_signals) do
    signal.at = at
  end
  return line_signals
end

return M
