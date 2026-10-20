--- The relay's offer of an announcement to the editor that started its
--- Claude Code, and how it went.

local editor = require('aineo.mcp.editor')
local work = require('aineo.mcp.work')

local M = {}

--- The Lua the editor runs for an announcement, its arguments the
--- announcement and the start token: `aineo.mcp`'s
--- `receive_work_announcement()` answers whether a tab took it, or why it
--- refuses it. Both travel
--- as data: nothing of them becomes code.
local RECEIVE_WORK = [[
  local work, start_token = ...
  return require('aineo.mcp').receive_work_announcement(work, start_token)
]]

--- What the relay knows of where an announcement goes.
---@class aineo.mcp.AnnouncementContext
---@field editor_address? string the address of the editor that started Claude Code
---@field token? string the token of that start
---@field working_directory? string the relay's working directory, Claude Code's, against which a relative path is made absolute; nil when it cannot be read

--- Offers `work` to the editor that started Claude Code, and to no other,
--- with the token of that start (`editor.offer_report()`, bounded), its path
--- made absolute against the relay's working directory
--- (`work.with_absolute_path()`), and says how it went: `'taken'` when a
--- tab of the editor took it; `'refused'`, with the editor's words, when the
--- tab refused it — a base git cannot resolve, say; `'declined'` otherwise —
--- no tab whose Claude Code has the token, no handler, an aineo older than
--- the relay, an editor that cannot be reached, closes the connection,
--- raises or does not answer in time — and at once, offering nothing, with
--- no editor address, no token, or a relative path and no working directory
--- to make it absolute against.
---
---@param context aineo.mcp.AnnouncementContext
---@param announced aineo.mcp.Work
---@return 'taken'|'refused'|'declined' outcome
---@return string? refusal the editor's words, for `'refused'`
function M.announce(context, announced)
  if not (context.editor_address and context.token) then
    return 'declined'
  end
  local relative = announced.path and not vim.startswith(announced.path, '/')
  if relative and not context.working_directory then
    return 'declined'
  end
  local offered = work.with_absolute_path(announced, context.working_directory)
  local kind, _, answer = editor.offer_report(
    context.editor_address,
    { lua = RECEIVE_WORK, arguments = { offered, context.token } }
  )
  if kind == 'taken' and type(answer) == 'string' then
    return 'refused', answer
  end
  return kind == 'taken' and 'taken' or 'declined'
end

return M
