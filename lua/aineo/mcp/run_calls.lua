--- The relay's offer of a call of a run tool to the editor that started its
--- Claude Code, and the words that answer Claude.

local editor = require('aineo.mcp.editor')

local M = {}

--- The Lua the editor runs for a call, its arguments the call and the start
--- token: `aineo.mcp`'s `receive_run_call()` answers the words for Claude, or
--- `false` when no tab took the call. Both travel as data: nothing of them
--- becomes code.
local RECEIVE_RUN_CALL = [[
  local call, start_token = ...
  return require('aineo.mcp').receive_run_call(call, start_token)
]]

--- What the relay tells Claude when no tab took a call.
M.NOT_TAKEN = 'not taken: no tab of the editor runs the Claude Code that made the call'

--- What the relay tells Claude when the editor answered a call with
--- something that is not words for it.
local UNREADABLE_ANSWER = 'the editor answered the call with something aineo cannot read'

--- What the relay knows of where a call goes.
---@class aineo.mcp.RunCallContext
---@field editor_address? string the address of the editor that started Claude Code
---@field token? string the token of that start

--- Whether `answer`, what an editor returned for a call it took, is words
--- for Claude: a table of `text`, a string, and `is_error`, a boolean.
---
---@param answer any
---@return boolean
local function is_words(answer)
  return type(answer) == 'table'
    and type(answer.text) == 'string'
    and type(answer.is_error) == 'boolean'
end

--- Offers `run_call` to the editor that started Claude Code, and to no
--- other, with the token of that start (`editor.offer_report()`, bounded),
--- and answers with the words for Claude and whether they are an error: what
--- the tab that took the call says; `NOT_TAKEN` when no tab did, and at once,
--- offering nothing, with no editor address or no token; why not, in words,
--- when the editor cannot be reached, closes the connection, refuses the call
--- or does not answer in time (the call then stays with the editor, which
--- runs it when it is free).
---
---@param context aineo.mcp.RunCallContext
---@param run_call aineo.mcp.RunCall
---@return string text
---@return boolean is_error
function M.offer(context, run_call)
  if not (context.editor_address and context.token) then
    return M.NOT_TAKEN, true
  end
  local kind, explanation, answer = editor.offer_report(context.editor_address, {
    lua = RECEIVE_RUN_CALL,
    arguments = { run_call, context.token },
    subject = 'call',
  })
  if kind == 'declined' then
    return M.NOT_TAKEN, true
  end
  if kind ~= 'taken' then
    return explanation, true
  end
  if not is_words(answer) then
    return UNREADABLE_ANSWER, true
  end
  return answer.text, answer.is_error
end

return M
