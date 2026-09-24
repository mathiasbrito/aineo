--- aineo's Send home, `require('aineo.send')`: the Input buffer's text into
--- Claude Code's prompt.

local claude = require('aineo.claude')
local layout = require('aineo.layout')

local M = {}

--- The bytes that open and close a bracketed paste, and the Enter key's.
local PASTE_START = '\27[200~'
local PASTE_END = '\27[201~'
local ENTER = '\r'

--- The escape byte, and U+009B — the one-character form of the escape
--- sequence `ESC [` — in UTF-8: the bytes that can open a control sequence,
--- `PASTE_END` among them.
local ESCAPE = '\27'
local SINGLE_CHARACTER_INTRODUCER = '\194\155'

--- What Send tells the user when it sends nothing, by the reason: the
--- session's status (`claude.session_status()`), or `not_started` when there
--- is no session.
local REFUSALS = {
  no_input = 'aineo: nothing sent — there is no Input; open aineo’s layout to make one',
  empty = 'aineo: nothing sent — Input is empty',
  not_started = 'aineo: nothing sent — Claude has not started',
  starting = 'aineo: nothing sent — Claude is not ready: it is starting, or a dialog in its window awaits your answer',
  exited = 'aineo: nothing sent — Claude has exited',
}

--- Tells the user, once, why Send sent nothing.
---
---@param reason string a key of `REFUSALS`
local function refuse(reason)
  vim.notify(REFUSALS[reason], vim.log.levels.WARN)
end

--- The Input buffer, while there is one: `nil` before the layout has made
--- it, and once it has been wiped.
---
---@return integer? input
local function existing_input()
  local input = layout.input_buffer()
  if input and vim.api.nvim_buf_is_valid(input) then
    return input
  end
  return nil
end

--- `text` with nothing left in it that can open a control sequence, so that
--- no part of it can end the paste it is sent in: every escape byte removed,
--- then every U+009B, again until none is left, since removing one can join
--- the bytes around it into another.
---
---@param text string
---@return string
local function without_control_sequences(text)
  local stripped = text:gsub(ESCAPE, '')
  local removed
  repeat
    stripped, removed = stripped:gsub(SINGLE_CHARACTER_INTRODUCER, '')
  until removed == 0
  return stripped
end

--- The text of `input` as Send pastes it: its lines joined by line feeds,
--- without the bytes that can open a control sequence
--- (`without_control_sequences()`).
---
---@param input integer the Input buffer
---@return string
local function pasteable_text(input)
  local lines = vim.api.nvim_buf_get_lines(input, 0, -1, false)
  return without_control_sequences(table.concat(lines, '\n'))
end

--- Writes the Input buffer's text — its lines joined by line feeds — to
--- Claude Code's terminal as one bracketed paste followed by Enter, in one
--- write, then empties Input. Claude Code 2.1.281 took that as one message,
--- and during a turn queued it; a draft already in its prompt is sent with
--- it, as one message. Nothing in the text can end the paste early
--- (`without_control_sequences()`).
---
--- Sends nothing, and tells the user why with one `vim.notify()` warning,
--- when there is no Input — before the layout has made it, or once it has
--- been wiped — when the text it would paste holds nothing but white space,
--- and when Claude Code is not ready for input as `claude.session_status()`
--- reports it at that moment: not started, starting or behind a dialog, or
--- exited.
function M.send()
  local input = existing_input()
  if not input then
    return refuse('no_input')
  end
  local text = pasteable_text(input)
  if not text:find('%S') then
    return refuse('empty')
  end
  local status = claude.session_status()
  if status ~= 'ready' then
    return refuse(status or 'not_started')
  end
  claude.write_to_session(PASTE_START .. text .. PASTE_END .. ENTER)
  vim.api.nvim_buf_set_lines(input, 0, -1, false, {})
end

return M
