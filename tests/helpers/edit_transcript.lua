--- The lines of a Claude Code transcript that tell of a call of a tool: the
--- recorded `Bash` call of `tests/fixtures/transcripts/turn-with-a-command-2.1.308.jsonl`
--- with the tool's name and input replaced, so that the line keeps the shape
--- Claude Code wrote it in.

local fake_transcript = dofile('tests/helpers/fake_transcript.lua')

local M = {}

--- The recorded assistant line that holds a `tool_use` block.
local RECORDED_CALL = vim
  .iter(fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl'))
  :find(function(line)
    return line:find('"tool_use"', 1, true) ~= nil
  end)

--- The line of a call of the tool `tool` with `input`, numbered `number`: the
--- call's id is `toolu_edit<number>`.
---
---@param tool string
---@param input table
---@param number integer
---@return string line
function M.call(tool, input, number)
  local record = vim.json.decode(RECORDED_CALL)
  local block = record.message.content[1]
  block.id = 'toolu_edit' .. number
  block.name = tool
  block.input = input
  return vim.json.encode(record)
end

--- The line of an `Edit` call of the file `path`.
---
---@param path string
---@param number integer
---@return string line
function M.edit(path, number)
  return M.call('Edit', { file_path = path, old_string = 'one', new_string = 'two' }, number)
end

return M
