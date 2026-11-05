--- The walkthrough plan tool's side of the report server: what `tools/list`
--- says of `walkthrough_plan`, which of its arguments are a plan the editor
--- can be offered, and the offer of that plan to the editor that started
--- Claude Code. What the editor does with a plan — it shows it in the
--- walkthrough pane, after checking its files — is the editor's: the relay
--- checks the shape of the call alone.

local editor = require('aineo.mcp.editor')
local names = require('aineo.mcp.names')
local walkthrough_tool = require('aineo.mcp.walkthrough_tool')

local M = {}

--- What the agent is told of when a plan is sent.
M.WHEN_TO_SEND = 'Once the user agrees to the plan, send it with this tool before showing step 1.'

--- What the tool says of itself.
local DESCRIPTION = "Gives the plan of a code walkthrough to the user's walkthrough pane in Neovim,"
  .. ' which shows it beside the code and marks the step on show. '
  .. M.WHEN_TO_SEND
  .. ' Sending a plan again replaces the one shown. `title` names the walkthrough and `summary`'
  .. ' says in prose what it is about; `covers` lists the features and changes it goes through'
  .. ' (1 to 16 short items); `steps` lists its steps in order (1 to 64), each `{ title, file,'
  .. ' introduces? }`, `file` the absolute path of the file the step shows and `introduces` the'
  .. ' concepts the step explains for the first time (at most 8 names). '
  .. walkthrough_tool.PLAN_ORDER
  .. ' The tool shows the plan and nothing else: it moves nowhere. It needs no approval; if it'
  .. ' refuses, correct the call as the refusal says and call again.'

--- The walkthrough plan tool, as `tools/list` describes it: an object of
--- `title`, `summary`, `covers` and `steps`, all required; no other property.
---
---@return table
function M.tool()
  return {
    name = names.WALKTHROUGH_PLAN_TOOL,
    description = DESCRIPTION,
    inputSchema = {
      type = 'object',
      properties = {
        title = { type = 'string', description = 'What the walkthrough is about, in a few words.' },
        summary = {
          type = 'string',
          description = 'What the walkthrough is about, in prose.',
        },
        covers = {
          type = 'array',
          description = 'The features and changes the walkthrough goes through, 1 to 16 items.',
          items = { type = 'string' },
        },
        steps = {
          type = 'array',
          description = 'The steps, in order, 1 to 64.',
          items = {
            type = 'object',
            properties = {
              title = { type = 'string' },
              file = { type = 'string', description = 'The absolute path of the file shown.' },
              introduces = {
                type = 'array',
                description = 'The concepts the step introduces, at most 8.',
                items = { type = 'string' },
              },
            },
            required = { 'title', 'file' },
            additionalProperties = false,
          },
        },
      },
      required = { 'title', 'summary', 'covers', 'steps' },
      additionalProperties = false,
    },
  }
end

--- A step of a plan: where the user is taken, and what it explains.
---@class aineo.mcp.WalkthroughPlanStep
---@field title string
---@field file string an absolute path
---@field introduces string[] the concepts the step introduces, none when it introduces none

--- A call of the walkthrough plan tool.
---@class aineo.mcp.WalkthroughPlanCall
---@field title string
---@field summary string what the walkthrough is about, in prose
---@field covers string[] the features and changes it goes through, 1 to 16
---@field steps aineo.mcp.WalkthroughPlanStep[] 1 to 64

--- The fields a call may give.
local FIELDS = { title = true, summary = true, covers = true, steps = true }

--- The fields of a step.
local STEP_FIELDS = { title = true, file = true, introduces = true }

--- The longest file path a step may give, in bytes.
local LONGEST_FILE_BYTES = 4096

--- The longest title, cover item or step title a call may give, in bytes.
local LONGEST_LINE_BYTES = 200

--- The longest summary a call may give, in bytes: 4 KiB.
local LONGEST_SUMMARY_BYTES = 4 * 1024

--- The longest name of a concept a step may introduce, in bytes.
local LONGEST_NAME_BYTES = 80

--- The most items `covers` has.
local MOST_COVERS = 16

--- The most steps a plan has.
local MOST_STEPS = 64

--- The most concepts a step introduces.
local MOST_NAMES = 8

--- Whether `value` is a JSON object: a table that is no non-empty list.
---
---@param value any
---@return boolean
local function is_object(value)
  return type(value) == 'table' and not (vim.islist(value) and next(value) ~= nil)
end

--- Whether `value` is a JSON array: a table that is a list, or empty.
---
---@param value any
---@return boolean
local function is_array(value)
  return type(value) == 'table' and (vim.islist(value) or next(value) == nil)
end

--- Why `value`, the field `field`, is no line of text of at most `longest`
--- bytes: no non-empty string, holding a NUL or a line break, or longer.
---
---@param value any
---@param field string
---@param longest integer
---@return string?
local function line_problem(value, field, longest)
  if type(value) ~= 'string' or value == '' then
    return field .. ': expected a non-empty string'
  end
  if value:find('[%z\n\r]') then
    return field .. ': holds a NUL or a line break'
  end
  if #value > longest then
    return ('%s: longer than %d bytes'):format(field, longest)
  end
  return nil
end

--- Why `summary` is refused: no non-empty string, holding a NUL, or longer
--- than 4 KiB.
---
---@param summary any
---@return string?
local function summary_problem(summary)
  if type(summary) ~= 'string' or summary == '' then
    return 'summary: expected a non-empty string'
  end
  if summary:find('%z') then
    return 'summary: holds a NUL'
  end
  if #summary > LONGEST_SUMMARY_BYTES then
    return ('summary: longer than %d bytes'):format(LONGEST_SUMMARY_BYTES)
  end
  return nil
end

--- Why the list `items`, the field `field`, is refused: no array of 1 to
--- `most` items, or an item that `item_problem()` refuses, given its field.
---
---@param items any
---@param field string
---@param most integer
---@param item_problem fun(item: any, item_field: string): string?
---@return string?
local function list_problem(items, field, most, item_problem)
  if not is_array(items) or #items == 0 then
    return ('%s: expected an array of 1 to %d items'):format(field, most)
  end
  if #items > most then
    return ('%s: more than %d'):format(field, most)
  end
  for position, item in ipairs(items) do
    local problem = item_problem(item, ('%s[%d]'):format(field, position))
    if problem then
      return problem
    end
  end
  return nil
end

--- Why `file`, the field `field`, is refused: no non-empty string, longer
--- than 4096 bytes, holding a NUL or a line break, or no absolute path.
---
---@param file any
---@param field string
---@return string?
local function file_problem(file, field)
  if type(file) ~= 'string' or file == '' then
    return field .. ': expected a non-empty string'
  end
  if #file > LONGEST_FILE_BYTES then
    return ('%s: longer than %d bytes'):format(field, LONGEST_FILE_BYTES)
  end
  if file:find('[%z\n\r]') then
    return field .. ': holds a NUL or a line break'
  end
  if not vim.startswith(file, '/') then
    return field .. ': expected an absolute path'
  end
  return nil
end

--- Why `introduces`, the field `field` of a step, is refused: when given, no
--- array of at most 8 names, or a name that is no line of at most 80 bytes.
---
---@param introduces any
---@param field string
---@return string?
local function introduces_problem(introduces, field)
  if introduces == nil then
    return nil
  end
  if not is_array(introduces) then
    return field .. (': expected an array of at most %d names'):format(MOST_NAMES)
  end
  if #introduces > MOST_NAMES then
    return ('%s: more than %d'):format(field, MOST_NAMES)
  end
  for position, name in ipairs(introduces) do
    local problem = line_problem(name, ('%s[%d]'):format(field, position), LONGEST_NAME_BYTES)
    if problem then
      return problem
    end
  end
  return nil
end

--- Why the step `step`, the field `field`, is refused, naming the field at
--- fault.
---
---@param step any
---@param field string
---@return string?
local function step_problem(step, field)
  if not is_object(step) then
    return field .. ': expected an object'
  end
  local problem = line_problem(step.title, field .. '.title', LONGEST_LINE_BYTES)
    or file_problem(step.file, field .. '.file')
    or introduces_problem(step.introduces, field .. '.introduces')
  if problem then
    return problem
  end
  for key in pairs(step) do
    if not STEP_FIELDS[key] then
      return ('%s.%s: not a field of a step'):format(field, tostring(key))
    end
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
  local problem = line_problem(arguments.title, 'title', LONGEST_LINE_BYTES)
    or summary_problem(arguments.summary)
    or list_problem(arguments.covers, 'covers', MOST_COVERS, function(item, field)
      return line_problem(item, field, LONGEST_LINE_BYTES)
    end)
    or list_problem(arguments.steps, 'steps', MOST_STEPS, step_problem)
  if problem then
    return problem
  end
  for key in pairs(arguments) do
    if not FIELDS[key] then
      return tostring(key) .. ': not a field of ' .. names.WALKTHROUGH_PLAN_TOOL
    end
  end
  return nil
end

--- The call `arguments` describe, or nil and why they are refused: an object
--- of `title`, `summary`, `covers` and `steps`, as the tool's description
--- says. A step that introduces nothing gets an empty `introduces`.
---
---@param arguments any
---@return aineo.mcp.WalkthroughPlanCall? call
---@return string? refusal
function M.validate(arguments)
  local refusal = refusal_of(arguments)
  if refusal then
    return nil, refusal
  end
  return {
    title = arguments.title,
    summary = arguments.summary,
    covers = arguments.covers,
    steps = vim.tbl_map(function(step)
      return { title = step.title, file = step.file, introduces = step.introduces or {} }
    end, arguments.steps),
  }
end

--- The Lua the editor runs for a call, its arguments the call and the start
--- token: `aineo.mcp`'s `receive_walkthrough_plan()` answers the words for
--- Claude, or `false` when no handler took it. Both travel as data.
local RECEIVE_WALKTHROUGH_PLAN = [[
  local call, start_token = ...
  return require('aineo.mcp').receive_walkthrough_plan(call, start_token)
]]

--- What the relay tells Claude when the editor did not take a call.
M.NOT_TAKEN = 'not taken: the editor that started Claude Code shows no walkthrough plan'

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
---@param call aineo.mcp.WalkthroughPlanCall
---@return string text
---@return boolean is_error
function M.offer(context, call)
  if not (context.editor_address and context.token) then
    return M.NOT_TAKEN, true
  end
  local kind, explanation, answer = editor.offer_report(context.editor_address, {
    lua = RECEIVE_WALKTHROUGH_PLAN,
    arguments = { call, context.token },
    subject = 'walkthrough plan',
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
