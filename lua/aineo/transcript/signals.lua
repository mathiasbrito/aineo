--- The codec of `aineo.transcript`: one line of a Claude Code transcript as the
--- signals the office reads from it. Pure: it holds no editor state.
---
--- A transcript line is a JSON object with a `type`. Only the lines that tell
--- what an agent does are read: a tool call (an `assistant` line holding
--- `tool_use` blocks), a tool's result (a `user` line holding `tool_result`
--- blocks) and the end of a turn (a `system` line of the subtype
--- `turn_duration`). Every other line, known or not, gives no signal. The
--- format is not documented by Claude Code; the recordings under
--- `tests/fixtures/transcripts/` pin the shapes read here.

local M = {}

--- A decoded null in an object is an absent field; one in a list stays
--- `vim.NIL`, so that a list keeps its length and the blocks after it.
local DECODE_OPTIONS = { luanil = { object = true } }

--- What `signals_of_line()` says of a line that is not JSON.
M.NOT_JSON = 'not JSON'

---@alias aineo.transcript.SignalKind 'tool_started'|'tool_finished'|'turn_ended'

--- What an agent did, in plain words.
---@class aineo.transcript.Signal
---@field agent string 'main', or a subagent's id
---@field kind aineo.transcript.SignalKind
---@field tool? string the tool's name, for `tool_started`
---@field input? table the tool's input, for `tool_started`
---@field call? string the tool call's id, for `tool_started` and `tool_finished`
---@field failed? boolean whether the tool's result was an error, for `tool_finished`
---@field replayed? boolean set by the follower on what it read from the file's tail at the start

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

--- The blocks of a message line's content that are tables, in order; none for
--- a content that is not a list of blocks, such as the user's own prompt.
---
---@param record table a decoded line
---@return table[] blocks
local function content_blocks(record)
  local message = record.message
  local content = type(message) == 'table' and message.content
  if type(content) ~= 'table' then
    return {}
  end
  return vim.tbl_filter(function(block)
    return type(block) == 'table'
  end, content)
end

--- The signals of the blocks of `record` that are of the type `block_type`,
--- each made by `signal_of_block`.
---
---@param record table
---@param block_type string
---@param agent string
---@param signal_of_block fun(block: table, agent: string): aineo.transcript.Signal
---@return aineo.transcript.Signal[]
local function signals_of_blocks(record, block_type, agent, signal_of_block)
  local signals = {}
  for _, block in ipairs(content_blocks(record)) do
    if block.type == block_type then
      table.insert(signals, signal_of_block(block, agent))
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

--- What each type of line gives, by the line's `type`.
---@type table<string, fun(record: table, agent: string): aineo.transcript.Signal[]>
local READERS = {
  assistant = function(record, agent)
    return signals_of_blocks(record, 'tool_use', agent, tool_started)
  end,
  user = function(record, agent)
    return signals_of_blocks(record, 'tool_result', agent, tool_finished)
  end,
  system = function(record, agent)
    if record.subtype == 'turn_duration' then
      return { { agent = agent, kind = 'turn_ended' } }
    end
    return {}
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
  return read and read(record, agent) or {}
end

return M
