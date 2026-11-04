--- The walkthrough tool's side of the report server: what `tools/list`
--- says of `walkthrough_step`, which of its arguments are a step the editor
--- can be offered, and the offer of that step to the editor that started
--- Claude Code. What a step needs of the editor's files and windows is the
--- editor's to check: the relay checks the shape of the call alone.

local editor = require('aineo.mcp.editor')
local names = require('aineo.mcp.names')

local M = {}

--- How the agent plans a walkthrough: in the order the solution is built.
--- The server's instructions repeat it, since a tool's description may not
--- be in the agent's context until the tool is called.
M.PLAN_ORDER = 'Plan the walkthrough the way the solution is built: introduce a concept'
  .. ' (a type, a module, a data shape, a rule) in a step before any step whose code relies on it;'
  .. ' start from what the rest stands on, then follow the flow;'
  .. " when that order cannot hold (a cycle, a forward use), say so in that step's explanation"
  .. ' in a sentence and name the step that explains it.'

--- What the agent is told of when a step is shown.
M.PACE = 'Show one step per call, only after the user asks to move; never two steps in one turn.'

--- What the tool says of itself.
local DESCRIPTION = "Shows one step of a code walkthrough in the user's editor: opens `file` in the"
  .. ' middle window and puts an explanation above each of `ranges`, in the look of the explanations'
  .. ' the user asks for, labelled `walk`, with the step heading on the first. '
  .. M.PACE
  .. ' After a step, stop and talk it over with the user. '
  .. M.PLAN_ORDER
  .. ' `file` is an absolute path to a regular file of at most 1 MiB inside a repository the editor'
  .. ' has open or a worktree an agent reported with announce_work, no link leading out of it and'
  .. ' nothing under `.git`. Walk through checked-out work only: a branch no worktree has checked'
  .. ' out has no file on disk. `title` names the step, `step`'
  .. ' is its number from 1 and `total` how many steps there will be. `ranges` holds 1 to 16 of'
  .. ' `{ start, end, text, first_line? }`: `start` and `end` the first and last line the explanation'
  .. ' is about, from 1; `text` its Markdown, at most 8 KiB, and 32 KiB in all; `first_line` the'
  .. ' expected text of line `start`, checked: a mismatch is refused and nothing is shown.'
  .. ' A call with no `ranges` ends the walkthrough and clears what it showed.'
  .. ' It needs no approval; if it refuses, correct the call as the refusal says and call again.'

--- The walkthrough tool, as `tools/list` describes it: an object of `file`,
--- `title` and `step`, required, `total` and `ranges`; no other property.
---
---@return table
function M.tool()
  return {
    name = names.WALKTHROUGH_TOOL,
    description = DESCRIPTION,
    inputSchema = {
      type = 'object',
      properties = {
        file = { type = 'string', description = 'The absolute path of the file to show.' },
        title = { type = 'string', description = 'What the step is about, in a few words.' },
        step = { type = 'integer', description = 'The number of the step, from 1.' },
        total = { type = 'integer', description = 'How many steps the walkthrough has.' },
        ranges = {
          type = 'array',
          description = 'The explanations of the step; none ends the walkthrough.',
          items = {
            type = 'object',
            properties = {
              start = { type = 'integer' },
              ['end'] = { type = 'integer' },
              text = { type = 'string' },
              first_line = { type = 'string' },
            },
            required = { 'start', 'end', 'text' },
            additionalProperties = false,
          },
        },
      },
      required = { 'file', 'title', 'step' },
      additionalProperties = false,
    },
  }
end

--- A step of a walkthrough: what an agent shows of one file.
---@class aineo.mcp.WalkthroughRange
---@field start integer the first line the explanation is about, from 1
---@field end integer the last line, not before `start`
---@field text string the explanation, Markdown
---@field first_line? string the expected text of line `start`

--- A call of the walkthrough tool.
---@class aineo.mcp.WalkthroughCall
---@field file string an absolute path
---@field title string
---@field step integer from 1
---@field total? integer not below `step`
---@field ranges aineo.mcp.WalkthroughRange[] none ends the walkthrough

--- The fields a call may give.
local FIELDS = { file = true, title = true, step = true, total = true, ranges = true }

--- The fields of a range.
local RANGE_FIELDS = { start = true, ['end'] = true, text = true, first_line = true }

--- The longest file path a call may give, in bytes.
local LONGEST_FILE_BYTES = 4096

--- The longest title a call may give, in bytes.
local LONGEST_TITLE_BYTES = 200

--- The most ranges a step may have.
local MOST_RANGES = 16

--- The longest text of a range, in bytes: 8 KiB.
local LONGEST_TEXT_BYTES = 8 * 1024

--- The longest text of all the ranges of a step together, in bytes: 32 KiB.
local LONGEST_TEXTS_BYTES = 32 * 1024

--- The longest `first_line` of a range, in bytes.
local LONGEST_FIRST_LINE_BYTES = 1024

--- Whether `value` is a JSON object: a table that is no non-empty list.
---
---@param value any
---@return boolean
local function is_object(value)
  return type(value) == 'table' and not (vim.islist(value) and next(value) ~= nil)
end

--- Whether `value` is a whole number of at least `least`.
---
---@param value any
---@param least integer
---@return boolean
local function is_whole_number_from(value, least)
  return type(value) == 'number' and value % 1 == 0 and value >= least
end

--- Why `file` is refused: no non-empty string, longer than 4096 bytes,
--- holding a NUL or a line break, or no absolute path.
---
---@param file any
---@return string?
local function file_problem(file)
  if type(file) ~= 'string' or file == '' then
    return 'file: expected a non-empty string'
  end
  if #file > LONGEST_FILE_BYTES then
    return ('file: longer than %d bytes'):format(LONGEST_FILE_BYTES)
  end
  if file:find('[%z\n\r]') then
    return 'file: holds a NUL or a line break'
  end
  if not vim.startswith(file, '/') then
    return 'file: expected an absolute path'
  end
  return nil
end

--- Why `title` is refused: no non-empty string, holding a NUL or a line
--- break, or longer than 200 bytes.
---
---@param title any
---@return string?
local function title_problem(title)
  if type(title) ~= 'string' or title == '' then
    return 'title: expected a non-empty string'
  end
  if title:find('[%z\n\r]') then
    return 'title: holds a NUL or a line break'
  end
  if #title > LONGEST_TITLE_BYTES then
    return ('title: longer than %d bytes'):format(LONGEST_TITLE_BYTES)
  end
  return nil
end

--- Why `step` and `total` are refused: a step that is no whole number from
--- 1, a total, when given, that is no whole number or lies below the step.
---
---@param step any
---@param total any
---@return string?
local function numbering_problem(step, total)
  if not is_whole_number_from(step, 1) then
    return 'step: expected a whole number from 1'
  end
  if total ~= nil and not is_whole_number_from(total, step) then
    return 'total: expected a whole number not below step'
  end
  return nil
end

--- Why the range numbered `position` is refused, naming the field at
--- fault.
---
---@param range any
---@param position integer
---@return string?
local function range_problem(range, position)
  local where = ('ranges[%d]'):format(position)
  if not is_object(range) then
    return where .. ': expected an object'
  end
  if not is_whole_number_from(range.start, 1) then
    return where .. '.start: expected a whole number from 1'
  end
  if not is_whole_number_from(range['end'], range.start) then
    return where .. '.end: expected a whole number not below start'
  end
  if type(range.text) ~= 'string' or range.text == '' then
    return where .. '.text: expected a non-empty string'
  end
  if #range.text > LONGEST_TEXT_BYTES then
    return ('%s.text: longer than %d bytes'):format(where, LONGEST_TEXT_BYTES)
  end
  if range.text:find('%z') then
    return where .. '.text: holds a NUL'
  end
  local first_line = range.first_line
  if first_line ~= nil and type(first_line) ~= 'string' then
    return where .. '.first_line: expected a string'
  end
  if first_line and #first_line > LONGEST_FIRST_LINE_BYTES then
    return ('%s.first_line: longer than %d bytes'):format(where, LONGEST_FIRST_LINE_BYTES)
  end
  for key in pairs(range) do
    if not RANGE_FIELDS[key] then
      return ('%s.%s: not a field of a range'):format(where, tostring(key))
    end
  end
  return nil
end

--- Why `ranges` are refused: no list, more than 16, a range that is
--- refused (`range_problem()`), or texts longer than 32 KiB in all.
---
---@param ranges any
---@return string?
local function ranges_problem(ranges)
  if ranges == nil then
    return nil
  end
  if type(ranges) ~= 'table' or not vim.islist(ranges) then
    return 'ranges: expected an array'
  end
  if #ranges > MOST_RANGES then
    return ('ranges: more than %d'):format(MOST_RANGES)
  end
  local bytes = 0
  for position, range in ipairs(ranges) do
    local problem = range_problem(range, position)
    if problem then
      return problem
    end
    bytes = bytes + #range.text
  end
  if bytes > LONGEST_TEXTS_BYTES then
    return ('ranges: the texts are longer than %d bytes in all'):format(LONGEST_TEXTS_BYTES)
  end
  return nil
end

--- Why `arguments` are no call of the tool, naming the field at fault; nil
--- when they are one.
---
---@param arguments any
---@return string?
local function refusal_of(arguments)
  if not is_object(arguments) then
    return 'arguments: expected an object'
  end
  local problem = file_problem(arguments.file)
    or title_problem(arguments.title)
    or numbering_problem(arguments.step, arguments.total)
    or ranges_problem(arguments.ranges)
  if problem then
    return problem
  end
  for key in pairs(arguments) do
    if not FIELDS[key] then
      return tostring(key) .. ': not a field of ' .. names.WALKTHROUGH_TOOL
    end
  end
  return nil
end

--- The call `arguments` describe, or nil and why they are refused: an
--- object of `file`, an absolute path, `title`, `step` and, optionally,
--- `total` and `ranges`, as the tool's description says. What the files and
--- windows of the editor allow of them is the editor's to check.
---
---@param arguments any
---@return aineo.mcp.WalkthroughCall? call
---@return string? refusal
function M.validate(arguments)
  local refusal = refusal_of(arguments)
  if refusal then
    return nil, refusal
  end
  return {
    file = arguments.file,
    title = arguments.title,
    step = arguments.step,
    total = arguments.total,
    ranges = arguments.ranges or {},
  }
end

--- The Lua the editor runs for a call, its arguments the call and the start
--- token: `aineo.mcp`'s `receive_walkthrough_step()` answers the words for
--- Claude, or `false` when no handler took it. Both travel as data.
local RECEIVE_WALKTHROUGH_STEP = [[
  local call, start_token = ...
  return require('aineo.mcp').receive_walkthrough_step(call, start_token)
]]

--- What the relay tells Claude when the editor did not take a call.
M.NOT_TAKEN = 'not taken: the editor that started Claude Code shows no walkthrough'

--- What the relay tells Claude when the editor answered a call with
--- something that is not words for it.
local UNREADABLE_ANSWER = 'the editor answered the call with something aineo cannot read'

--- Offers `call` to the editor that started Claude Code, and to no other,
--- with the token of that start (`editor.offer_report()`, bounded), and
--- answers with the words for Claude and whether they are an error: the
--- editor's; `NOT_TAKEN` when it did not take the call, and at once,
--- offering nothing, with no editor address or no token; why not, in words,
--- when the editor cannot be reached, closes the connection, refuses the
--- call or does not answer in time.
---
---@param context { editor_address?: string, token?: string }
---@param call aineo.mcp.WalkthroughCall
---@return string text
---@return boolean is_error
function M.offer(context, call)
  if not (context.editor_address and context.token) then
    return M.NOT_TAKEN, true
  end
  local kind, explanation, answer = editor.offer_report(context.editor_address, {
    lua = RECEIVE_WALKTHROUGH_STEP,
    arguments = { call, context.token },
    subject = 'walkthrough step',
  })
  if kind == 'declined' then
    return M.NOT_TAKEN, true
  end
  if kind ~= 'taken' then
    return explanation, true
  end
  if
    type(answer) ~= 'table'
    or type(answer.text) ~= 'string'
    or type(answer.is_error) ~= 'boolean'
  then
    return UNREADABLE_ANSWER, true
  end
  return answer.text, answer.is_error
end

return M
