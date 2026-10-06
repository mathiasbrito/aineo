--- aineo's Send home, `require('aineo.send')`: the Input buffer's text, or
--- a Visual selection of it, into Claude Code's prompt.

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

--- What Send and the Visual Send tell the user when they send nothing, by
--- the reason: no Input, Input empty, the selection empty, a selection made
--- outside Input, or the session's status (`claude.session_status()`),
--- `not_started` when there is no session.
local REFUSALS = {
  no_input = 'aineo: nothing sent — there is no Input; open aineo’s layout to make one',
  empty = 'aineo: nothing sent — Input is empty',
  empty_selection = 'aineo: nothing sent — the selection is empty',
  not_in_input = 'aineo: nothing sent — Visual Send works in Input only',
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

--- Writes `text` to Claude Code's terminal as one bracketed paste followed
--- by Enter, in one write. When the write fails, calls `put_back()`, which
--- puts Input back as it was before Send changed it, and raises the write's
--- error as it is.
---
---@param text string
---@param put_back fun()
local function write_or_put_back(text, put_back)
  local written, failure = pcall(claude.write_to_session, PASTE_START .. text .. PASTE_END .. ENTER)
  if not written then
    put_back()
    error(failure, 0)
  end
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
  write_or_put_back(text, function()
    vim.api.nvim_buf_set_lines(input, 0, -1, false, lines)
  end)
end

--- The line `lnum` of the current buffer, a NUL byte in it kept as one.
---
---@param lnum integer 1-based
---@return string
local function buffer_line(lnum)
  return vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1]
end

--- The last byte of the character of `line` that its byte `byte` lies in,
--- counting as one character what Neovim draws as one — a character with
--- its composing ones, an emoji with its modifiers, or a sequence of emoji
--- joined by U+200D — as `"_d` does when it removes the whole of one a
--- selection cuts.
---
---@param line string as `nvim_buf_get_lines()` gives it
---@param byte integer 1-based
---@return integer
local function character_end(line, byte)
  -- A Lua string holding a NUL reaches Vimscript as a Blob, which charidx()
  -- refuses; Vimscript holds a NUL in a line as a line feed, of one byte too.
  local as_vimscript = line:gsub('%z', '\n')
  return vim.fn.byteidx(as_vimscript, vim.fn.charidx(as_vimscript, byte - 1) + 1)
end

--- The part of `line` from its byte `first_byte` through its byte
--- `last_byte`: empty when `first_byte` is 0, where `getregionpos()` puts
--- a selection that lies past the line's end.
---
---@param line string
---@param first_byte integer 1-based, or 0
---@param last_byte integer 1-based
---@return string
local function line_part(line, first_byte, last_byte)
  if first_byte == 0 then
    return ''
  end
  return line:sub(first_byte, last_byte)
end

--- `a` and `b`, positions as `getpos()` gives them, the one nearer the
--- buffer's start first.
---
---@param a integer[] `[bufnum, lnum, col, off]`
---@param b integer[] `[bufnum, lnum, col, off]`
---@return integer[] first
---@return integer[] last
local function in_buffer_order(a, b)
  if b[2] < a[2] or (b[2] == a[2] and b[3] < a[3]) then
    return b, a
  end
  return a, b
end

--- The region `"_d` removes for a Visual selection of `mode` between `from`
--- and `to`, as `getregionpos()` takes it: its ends, the one nearer the
--- buffer's start first, and its kind, `getregionpos()`'s `type`. That is
--- the selection itself, but for a charwise one under `'selection'` old
--- whose end lies on an empty line below its start, unless `'virtualedit'`
--- is exactly `all`, which keeps the end: Vim then ends it as an exclusive
--- motion that ends in column 1 (`:h exclusive`) — on the line above,
--- through its last character, or, when the start lies at or before its
--- line's first non-blank, linewise, through the line above
--- (`:h exclusive-linewise`). Returns nothing when that last character lies
--- before the start, as it does for a start past its line's end on the
--- line above: `"_d` then removes nothing.
---
---@param mode string `mode()` in Visual mode
---@param from integer[] `getpos('v')`
---@param to integer[] `getpos('.')`
---@return integer[]? first
---@return integer[]? last
---@return string? kind
local function removed_region(mode, from, to)
  local first, last = in_buffer_order(from, to)
  local ends_on_empty_line = last[2] > first[2] and buffer_line(last[2]) == ''
  local operator_is_virtual = vim.o.virtualedit == 'all'
  if mode ~= 'v' or vim.o.selection ~= 'old' or not ends_on_empty_line or operator_is_virtual then
    return first, last, mode
  end
  local above = last[2] - 1
  if #buffer_line(first[2]):match('^[ \t]*') >= first[3] - 1 then
    return first, { 0, above, 1, 0 }, 'V'
  end
  local above_end = math.max(#buffer_line(above), 1)
  if first[2] == above and first[3] > above_end then
    return nil
  end
  return first, { 0, above, above_end, 0 }, mode
end

--- The part of each line `"_d` removes the Visual selection between
--- `from` and `to` from, top to bottom (`removed_region()`), and whether
--- the selection is charwise. A part runs from the region's edge on its
--- line through the character its other edge lies in (`character_end()`)
--- — or, for a block made with `$`, to the line's own end — and is empty
--- on a line the region lies past. There are no parts when there is no
--- region.
---
---@param from integer[] `getpos('v')`
---@param to integer[] `getpos('.')`
---@return { parts: string[], charwise: boolean }
local function visual_selection(from, to)
  local mode = vim.fn.mode()
  local to_line_end = mode == '\22' and vim.fn.winsaveview().curswant == vim.v.maxcol
  local first, last, kind = removed_region(mode, from, to)
  if not first then
    return { parts = {}, charwise = true }
  end
  local parts = {}
  for _, span in ipairs(vim.fn.getregionpos(first, last, { type = kind })) do
    local line = buffer_line(span[1][2])
    local last_byte = to_line_end and #line or character_end(line, span[2][3])
    table.insert(parts, line_part(line, span[1][3], last_byte))
  end
  return { parts = parts, charwise = mode == 'v' }
end

--- The text a removal of `selection` took from Input: its parts joined by
--- line feeds, then, for a charwise selection whose removal took a line
--- break for each line it spans — its last line's too, as `v$` takes it on
--- a line that has one, or `'selection'` old with whole lines — a final
--- line feed. A linewise selection's text ends with none.
---
---@param selection { parts: string[], charwise: boolean }
---@param line_breaks_removed integer
---@return string
local function removed_text(selection, line_breaks_removed)
  local text = table.concat(selection.parts, '\n')
  if selection.charwise and line_breaks_removed == #selection.parts then
    return text .. '\n'
  end
  return text
end

--- Ends Visual mode, the selection kept for `gv`, as Vim ends it after a
--- command that fails, and tells the user, once, why the Visual Send sent
--- nothing.
---
---@param reason string a key of `REFUSALS`
local function refuse_selection(reason)
  vim.cmd.normal({ args = { vim.keycode('<Esc>') }, bang = true })
  refuse(reason)
end

--- Sends the Visual selection in Input to Claude Code's terminal, called in
--- Visual mode: removes it from Input as Vim's own `"_d` does — writing no
--- register, and leaving the cursor where `"_d` leaves it, in Normal mode —
--- then writes exactly the text that removal took, without control bytes
--- (`without_control_bytes()`), as one bracketed paste followed by Enter, in
--- one write, as `send()` writes Input. That text is each line's removed
--- part joined by line feeds (`visual_selection()`, `removed_text()`): a
--- `$` block's part runs to each line's own end, a line the block lies past
--- gives an empty part and no padding, a character the selection cuts — a
--- tab, a double-width one, an emoji with its modifiers — is sent whole, a
--- charwise selection whose removal took its last line's break ends with
--- that line break, and a linewise one ends with none. A NUL byte is sent
--- as `send()` sends it: not at all.
---
--- Sends and removes nothing, ending Visual mode with the selection kept
--- for `gv`, and tells the user why with one `vim.notify()` warning, when
--- the current buffer is not Input — Input missing too — when the text it
--- would send holds nothing but white space, and when Claude Code is not
--- ready, as `send()` tells it — checked in that order. When Input cannot
--- be changed, raises Neovim's error and writes nothing.
---
--- When the write fails — the terminal's stream has closed — puts Input's
--- lines back as they were before the removal, and the selection's marks
--- `'<` and `'>`, so that `gv` selects it again, and raises the write's
--- error as it is, as `send()` does: the removal and the put-back are then
--- one undo block, which `u` undoes with no change to see.
function M.send_selection()
  local input = vim.api.nvim_get_current_buf()
  if input ~= existing_input() then
    return refuse_selection('not_in_input')
  end
  local from, to = vim.fn.getpos('v'), vim.fn.getpos('.')
  local selection = visual_selection(from, to)
  if not without_control_bytes(table.concat(selection.parts, '\n')):find('%S') then
    return refuse_selection('empty_selection')
  end
  local status = claude.session_status()
  if status ~= 'ready' then
    return refuse_selection(status or 'not_started')
  end
  local lines = vim.api.nvim_buf_get_lines(input, 0, -1, false)
  vim.cmd.normal({ args = { '"_d' }, bang = true })
  local removed = removed_text(selection, #lines - vim.api.nvim_buf_line_count(input))
  write_or_put_back(without_control_bytes(removed), function()
    vim.api.nvim_buf_set_lines(input, 0, -1, false, lines)
    vim.fn.setpos("'<", from)
    vim.fn.setpos("'>", to)
  end)
end

return M
