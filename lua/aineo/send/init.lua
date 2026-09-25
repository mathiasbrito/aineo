--- aineo's Send home, `require('aineo.send')`: the Input buffer's text into
--- Claude Code's prompt.

local claude = require('aineo.claude')
local layout = require('aineo.layout')

local M = {}

--- The bytes that open and close a bracketed paste, and the Enter key's.
local PASTE_START = '\27[200~'
local PASTE_END = '\27[201~'
local ENTER = '\r'

--- The C0 control bytes — those below 0x20, and DEL — but tab, line feed
--- and carriage return, which are text in a paste: among them the escape
--- byte, which opens a control sequence such as `PASTE_END`, and the bytes a
--- terminal sends for keys such as Ctrl-C.
local C0_CONTROLS = '[%z\1-\8\11\12\14-\31\127]'

--- The C1 control characters, U+0080 to U+009F, in UTF-8: among them
--- U+009B, the one-character form of the escape sequence `ESC [`.
local C1_CONTROLS = '\194[\128-\159]'

--- What Send tells the user when it sends nothing, by the reason: no
--- Input, Input empty, or the session's status (`claude.session_status()`),
--- `not_started` when there is no session.
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

--- `text` with no control byte left in it, so that no part of it can end the
--- paste it is sent in or reach Claude Code as a key: every C0 control but
--- tab, line feed and carriage return removed (`C0_CONTROLS`), then every C1
--- control (`C1_CONTROLS`), again until none is left, since removing one can
--- join the bytes around it into another. The order matters: an escape byte
--- between the two bytes of a C1 control hides it until it is gone.
---
---@param text string
---@return string
local function without_control_bytes(text)
  local stripped = text:gsub(C0_CONTROLS, '')
  local removed
  repeat
    stripped, removed = stripped:gsub(C1_CONTROLS, '')
  until removed == 0
  return stripped
end

--- The text of `input` as Send pastes it: its lines joined by line feeds,
--- without control bytes (`without_control_bytes()`).
---
---@param input integer the Input buffer
---@return string
local function pasteable_text(input)
  local lines = vim.api.nvim_buf_get_lines(input, 0, -1, false)
  return without_control_bytes(table.concat(lines, '\n'))
end

--- Empties Input, then writes its text — its lines joined by line feeds,
--- without control bytes (`without_control_bytes()`), every other byte
--- kept — to Claude Code's terminal as one bracketed paste followed by
--- Enter, in one write. Claude Code 2.1.281 took that as one message, and
--- during a turn queued it. A draft already in its prompt is left as it is,
--- and the paste joins it. Nothing in the text can end the paste early.
---
--- Sends nothing, and tells the user why with one `vim.notify()` warning,
--- when there is no Input — before the layout has made it, or once it has
--- been wiped — when the text it would paste holds nothing but white space,
--- and when Claude Code is not ready for input as `claude.session_status()`
--- reports it at that moment: not started, starting or behind a dialog, or
--- exited — checked in that order. When Input cannot be emptied — it is not
--- modifiable, or a text lock holds, as in an `<expr>` mapping — raises
--- Neovim's error and writes nothing, Input keeping its text.
---
--- The status is as fresh as the last event Neovim processed, so Claude Code
--- may have died while it still reads `'ready'`. When the write then fails —
--- the terminal's stream has closed — Send puts Input's lines back and
--- raises the write's error as it is (`Can't send data to closed stream`).
--- While the stream is still open the write succeeds into the dead terminal:
--- Input is emptied and nothing is raised.
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
  local lines = vim.api.nvim_buf_get_lines(input, 0, -1, false)
  vim.api.nvim_buf_set_lines(input, 0, -1, false, {})
  local written, failure = pcall(claude.write_to_session, PASTE_START .. text .. PASTE_END .. ENTER)
  if not written then
    vim.api.nvim_buf_set_lines(input, 0, -1, false, lines)
    error(failure, 0)
  end
end

return M
