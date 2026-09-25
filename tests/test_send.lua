local MiniTest = require('mini.test')
local claude = dofile('tests/helpers/claude_session.lua')
local send = dofile('tests/helpers/send.lua')

local eq = MiniTest.expect.equality

--- Expects `text` to be a string holding `part`, character for character.
local contains = MiniTest.new_expectation('a string containing a part', function(text, part)
  return type(text) == 'string' and text:find(part, 1, true) ~= nil
end, function(text, part)
  return string.format('Text: %s\nPart: %s', vim.inspect(text), vim.inspect(part))
end)

local WARN = vim.log.levels.WARN

--- What Send tells the user while Claude is not ready for input.
local NOT_READY =
  'aineo: nothing sent — Claude is not ready: it is starting, or a dialog in its window awaits your answer'

--- Longer than the fake takes to exit on a double Ctrl-C at an idle prompt:
--- 1.6 s after the second press.
local DOUBLE_CTRL_C_EXIT_MS = 2500

--- Every C0 control byte but tab, line feed and carriage return, and DEL.
local EVERY_C0_CONTROL_BUT_TAB_LF_CR =
  '\0\1\2\3\4\5\6\7\8\11\12\14\15\16\17\18\19\20\21\22\23\24\25\26\27\28\29\30\31\127'

--- Every C1 control character, U+0080 to U+009F, in UTF-8.
local EVERY_C1_CONTROL = '\194\128\194\129\194\130\194\131\194\132\194\133\194\134\194\135'
  .. '\194\136\194\137\194\138\194\139\194\140\194\141\194\142\194\143'
  .. '\194\144\194\145\194\146\194\147\194\148\194\149\194\150\194\151'
  .. '\194\152\194\153\194\154\194\155\194\156\194\157\194\158\194\159'

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      send.restart(child)
    end,
    post_once = child.stop,
  },
})

--- Starts the session in `child` against `fake` with the layout around it,
--- and has the session end by its keys once the case is over; returns its
--- terminal buffer.
---
---@param fake { environment: table<string, string>, record: string }
---@return integer buffer
local function start_session(fake)
  local buffer = send.start_with_layout(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)
  return buffer
end

--- Starts the session as `start_session()` does and waits for it to be
--- ready; returns its terminal buffer.
---
---@param fake { environment: table<string, string>, record: string }
---@return integer buffer
local function start_ready_session(fake)
  local buffer = start_session(fake)
  claude.wait_for_status(child, 'ready')
  return buffer
end

--- How long a case waits for bytes it expects Send not to write: Send
--- writes in the call itself, and the fake records what it receives within
--- milliseconds.
local NOTHING_SENT_PATIENCE_MS = 300

--- How long a case watches the fake's input for a write that comes after
--- Send's own: longer than any delay a later write could plausibly take.
local ONE_WRITE_PATIENCE_MS = 1000

--- What `fake` receives, after its first `before` bytes of input, within
--- `NOTHING_SENT_PATIENCE_MS`: empty when Send wrote nothing.
---
---@param fake { record: string }
---@param before integer
---@return string
local function sent_after(fake, before)
  return claude.wait_for_received_after(fake, before, 1, NOTHING_SENT_PATIENCE_MS)
end

--- What a refused Send leaves behind: what `fake` received after its first
--- `before` bytes of input (`sent_after()`), Input's lines, and what the
--- user was told (`send.messages()`).
---
---@param fake { record: string }
---@param before integer
---@return { sent: string, input: string[], messages: table[] }
local function refusal(fake, before)
  return {
    sent = sent_after(fake, before),
    input = send.input(child).lines,
    messages = send.messages(child),
  }
end

T['send()'] = MiniTest.new_set()

T['send()']['writes Input to Claude as one bracketed paste followed by Enter'] = function()
  local fake = claude.fake('send', 'ready')
  start_ready_session(fake)
  send.set_input(child, { 'first line', 'second line' })
  local before = #claude.received(fake)
  local expected = '\27[200~first line\nsecond line\27[201~\r'

  send.send(child)

  eq(claude.wait_for_received_after(fake, before, #expected), expected)
end

T['send()']['empties Input, which stays aineo’s scratch Input'] = function()
  local fake = claude.fake('send-clears', 'ready')
  start_ready_session(fake)
  send.set_input(child, { 'a message' })

  send.send(child)

  eq(send.input(child), { lines = { '' }, name = 'aineo://input', buftype = 'nofile' })
end

T['send()']['refuses, saying so once, before the layout has made Input'] = function()
  send.send(child)

  eq(send.messages(child), {
    {
      message = 'aineo: nothing sent — there is no Input; open aineo’s layout to make one',
      level = WARN,
    },
  })
end

T['send()']['refuses, saying so once, once Input has been wiped'] = function()
  local input = send.open_layout_without_session(child)
  child.cmd('bwipeout! ' .. input)

  send.send(child)

  eq(send.messages(child), {
    {
      message = 'aineo: nothing sent — there is no Input; open aineo’s layout to make one',
      level = WARN,
    },
  })
end

T['send()']['refuses, saying so once, while Input is empty'] = function()
  local fake = claude.fake('send-empty', 'ready')
  start_ready_session(fake)
  local before = #claude.received(fake)

  send.send(child)

  eq(refusal(fake, before), {
    sent = '',
    input = { '' },
    messages = { { message = 'aineo: nothing sent — Input is empty', level = WARN } },
  })
end

T['send()']['refuses, saying so once, while Input holds only blank lines'] = function()
  local fake = claude.fake('send-blank', 'ready')
  start_ready_session(fake)
  send.set_input(child, { '  ', '\t', '' })
  local before = #claude.received(fake)

  send.send(child)

  eq(refusal(fake, before), {
    sent = '',
    input = { '  ', '\t', '' },
    messages = { { message = 'aineo: nothing sent — Input is empty', level = WARN } },
  })
end

T['send()']['refuses, saying so once, while Input holds only escape bytes and blanks'] = function()
  local fake = claude.fake('send-escapes-only', 'ready')
  start_ready_session(fake)
  send.set_input(child, { '\27\27', ' ' })
  local before = #claude.received(fake)

  send.send(child)

  eq(refusal(fake, before), {
    sent = '',
    input = { '\27\27', ' ' },
    messages = { { message = 'aineo: nothing sent — Input is empty', level = WARN } },
  })
end

T['send()']['refuses, saying so once and keeping Input, before Claude has started'] = function()
  send.open_layout_without_session(child)
  send.set_input(child, { 'a message' })

  send.send(child)

  eq({ input = send.input(child).lines, messages = send.messages(child) }, {
    input = { 'a message' },
    messages = { { message = 'aineo: nothing sent — Claude has not started', level = WARN } },
  })
end

T['send()']['refuses, saying so once and keeping Input, behind the workspace-trust dialog'] = function()
  local fake = claude.fake('send-trust', 'trust')
  local buffer = start_session(fake)
  claude.wait_for_screen(child, buffer, 'Yes, I trust this folder')
  send.set_input(child, { 'a message' })
  local before = #claude.received(fake)

  send.send(child)

  eq(refusal(fake, before), {
    sent = '',
    input = { 'a message' },
    messages = { { message = NOT_READY, level = WARN } },
  })
end

T['send()']['refuses, saying so once and keeping Input, once Claude has exited'] = function()
  local fake = claude.fake('send-exited', 'exit')
  start_session(fake)
  claude.wait_for_status(child, 'exited')
  send.set_input(child, { 'a message' })
  local before = #claude.received(fake)

  send.send(child)

  eq(refusal(fake, before), {
    sent = '',
    input = { 'a message' },
    messages = { { message = 'aineo: nothing sent — Claude has exited', level = WARN } },
  })
end

T['send()']['refuses while a permission dialog asks, though Claude was ready at the send before'] = function()
  local fake = claude.fake('send-asks', 'asks')
  local buffer = start_ready_session(fake)
  send.set_input(child, { 'a first message' })
  local first_before = #claude.received(fake)
  local first = '\27[200~a first message\27[201~\r'
  send.send(child)
  eq(claude.wait_for_received_after(fake, first_before, #first), first)
  claude.press_keys(child, buffer, '\r')
  eq(claude.wait_for_status(child, 'starting'), { 'starting' })
  send.set_input(child, { 'a message' })
  local before = #claude.received(fake)

  send.send(child)

  eq(refusal(fake, before), {
    sent = '',
    input = { 'a message' },
    messages = { { message = NOT_READY, level = WARN } },
  })
end

T['send()']['writes Input while Claude works on a turn, for Claude to queue it'] = function()
  local fake = claude.fake('send-turn', 'turn')
  local buffer = send.start_with_layout(child, fake)
  MiniTest.finally(function()
    claude.quit(child)
    claude.wait_for_end(fake)
  end)
  contains(claude.wait_for_screen(child, buffer, 'esc to interrupt'), 'esc to interrupt')
  claude.wait_for_status(child, 'ready')
  send.set_input(child, { 'a queued message' })
  local before = #claude.received(fake)
  local expected = '\27[200~a queued message\27[201~\r'

  send.send(child)

  eq(claude.wait_for_received_after(fake, before, #expected), expected)
end

T['send()']['keeps a paste’s end marker in Input from ending the paste early'] = function()
  local fake = claude.fake('send-paste-end', 'ready')
  start_ready_session(fake)
  send.set_input(child, { 'before\27[201~\rafter' })
  local before = #claude.received(fake)
  local expected = '\27[200~before[201~\rafter\27[201~\r'

  send.send(child)

  eq(claude.wait_for_received_after(fake, before, #expected), expected)
end

T['send()']['keeps an end marker nested in another from ending the paste early'] =
  MiniTest.new_set({
    parametrize = {
      { '\27[20\27[201~1~\rafter', '\27[200~[20[201~1~\rafter\27[201~\r' },
      { '\27\27[201~[201~\rafter', '\27[200~[201~[201~\rafter\27[201~\r' },
    },
  })

T['send()']['keeps an end marker nested in another from ending the paste early']['as it writes'] = function(
  line,
  expected
)
  local fake = claude.fake('send-nested-end', 'ready')
  start_ready_session(fake)
  send.set_input(child, { line })
  local before = #claude.received(fake)

  send.send(child)

  eq(claude.wait_for_received_after(fake, before, #expected), expected)
end

T['send()']['keeps an end marker in its one-character form from ending the paste early'] = function()
  local fake = claude.fake('send-c1-end', 'ready')
  start_ready_session(fake)
  send.set_input(child, { 'before\194\155201~\rafter' })
  local before = #claude.received(fake)
  local expected = '\27[200~before201~\rafter\27[201~\r'

  send.send(child)

  eq(claude.wait_for_received_after(fake, before, #expected), expected)
end

T['send()']['keeps a one-character end marker nested in another from ending the paste early'] = function()
  local fake = claude.fake('send-c1-nested-end', 'ready')
  start_ready_session(fake)
  send.set_input(child, { 'before\194\194\155\155201~\rafter' })
  local before = #claude.received(fake)
  local expected = '\27[200~before201~\rafter\27[201~\r'

  send.send(child)

  eq(claude.wait_for_received_after(fake, before, #expected), expected)
end

T['send()']['writes multibyte characters byte for byte'] = function()
  local fake = claude.fake('send-multibyte', 'ready')
  start_ready_session(fake)
  send.set_input(child, { 'é £ ❯ 😛', 'naïve' })
  local before = #claude.received(fake)
  local expected = '\27[200~é £ ❯ 😛\nnaïve\27[201~\r'

  send.send(child)

  eq(claude.wait_for_received_after(fake, before, #expected), expected)
end

T['send()']['writes a text of more than 100 KiB whole'] = function()
  local fake = claude.fake('send-long', 'ready')
  start_ready_session(fake)
  local line = string.rep('0123456789', 10)
  local text = string.rep(line .. '\n', 1023) .. line
  send.set_input(child, vim.split(text, '\n'))
  local before = #claude.received(fake)
  local expected = '\27[200~' .. text .. '\27[201~\r'

  send.send(child)

  eq(claude.wait_for_received_after(fake, before, #expected), expected)
end

T['send()']['writes Input after a draft in Claude’s prompt, leaving the draft as it is'] = function()
  local fake = claude.fake('send-draft', 'draft')
  start_ready_session(fake)
  send.set_input(child, { 'a message' })
  local before = #claude.received(fake)
  local expected = '\27[200~a message\27[201~\r'
  local more_than_expected = #expected + 1

  send.send(child)

  eq(claude.wait_for_received_after(fake, before, more_than_expected), expected)
end

T['send()']['keeps Ctrl-C bytes in Input from reaching an idle Claude as keys'] = function()
  local fake = claude.fake('send-ctrl-c-idle', 'ready')
  start_ready_session(fake)
  send.set_input(child, { 'a\3\3b' })
  local before = #claude.received(fake)
  local expected = '\27[200~ab\27[201~\r'

  send.send(child)

  eq({
    sent = claude.wait_for_received_after(fake, before, #expected),
    status = claude.wait_for_status(child, 'exited', DOUBLE_CTRL_C_EXIT_MS),
  }, { sent = expected, status = { 'ready' } })
end

T['send()']['keeps every byte but the control ones, blank lines and indentation included'] = function()
  local fake = claude.fake('send-every-byte', 'ready')
  start_ready_session(fake)
  send.set_input(child, { '', '  indented\t\1\127\194\144 kept\rtoo', '' })
  local before = #claude.received(fake)
  local expected = '\27[200~\n  indented\t kept\rtoo\n\27[201~\r'

  send.send(child)

  eq(claude.wait_for_received_after(fake, before, #expected), expected)
end

T['send()']['removes every control byte and keeps the characters just past each range'] = function()
  local fake = claude.fake('send-every-control', 'ready')
  start_ready_session(fake)
  send.set_input(
    child,
    { ' ~<' .. EVERY_C0_CONTROL_BUT_TAB_LF_CR .. EVERY_C1_CONTROL .. '>\194\160\194\191' }
  )
  local before = #claude.received(fake)
  local expected = '\27[200~ ~<>\194\160\194\191\27[201~\r'

  send.send(child)

  eq(claude.wait_for_received_after(fake, before, #expected + 1, ONE_WRITE_PATIENCE_MS), expected)
end

T['send()']['keeps a Ctrl-C byte in Input from interrupting Claude’s turn'] = function()
  local fake = claude.fake('send-ctrl-c-turn', 'turn')
  local buffer = send.start_with_layout(child, fake)
  MiniTest.finally(function()
    claude.quit(child)
    claude.wait_for_end(fake)
  end)
  contains(claude.wait_for_screen(child, buffer, 'esc to interrupt'), 'esc to interrupt')
  claude.wait_for_status(child, 'ready')
  send.set_input(child, { 'x\3y' })
  local before = #claude.received(fake)
  local expected = '\27[200~xy\27[201~\r'

  send.send(child)

  eq({
    sent = claude.wait_for_received_after(fake, before, #expected),
    interrupted_turns = claude.wait_for_interrupted_turns(fake, NOTHING_SENT_PATIENCE_MS),
  }, { sent = expected, interrupted_turns = 0 })
end

T['send()']['refuses, saying so once, while Input holds only a NUL byte'] = function()
  local fake = claude.fake('send-nul-only', 'ready')
  start_ready_session(fake)
  send.set_input(child, { '\0' })
  local before = #claude.received(fake)

  send.send(child)

  eq(refusal(fake, before), {
    sent = '',
    input = { '\0' },
    messages = { { message = 'aineo: nothing sent — Input is empty', level = WARN } },
  })
end

T['send()']['keeps an escape byte inside a one-character end marker from hiding it'] = function()
  local fake = claude.fake('send-c1-split-by-escape', 'ready')
  start_ready_session(fake)
  send.set_input(child, { 'before\194\27\155201~\rafter' })
  local before = #claude.received(fake)
  local expected = '\27[200~before201~\rafter\27[201~\r'

  send.send(child)

  eq(claude.wait_for_received_after(fake, before, #expected), expected)
end

T['send()']['writes nothing when Input cannot be emptied, keeping its text'] = function()
  local fake = claude.fake('send-unmodifiable', 'ready')
  start_ready_session(fake)
  send.set_input(child, { 'a message' })
  child.lua("vim.bo[require('aineo.layout').input_buffer()].modifiable = false")
  local before = #claude.received(fake)

  send.send(child)

  eq({ sent = sent_after(fake, before), input = send.input(child).lines }, {
    sent = '',
    input = { 'a message' },
  })
  contains(send.raised(child), "Buffer is not 'modifiable'")
end

T['send()']['writes nothing when a text lock keeps Input from being emptied'] = function()
  local fake = claude.fake('send-textlock', 'ready')
  start_ready_session(fake)
  send.set_input(child, { 'a message' })
  local before = #claude.received(fake)

  send.send_from_expression_mapping(child)

  eq({ sent = sent_after(fake, before), input = send.input(child).lines }, {
    sent = '',
    input = { 'a message' },
  })
  contains(send.raised(child), 'E565')
end

T['send()']['keeps Input and raises when the write fails after Input is emptied'] = function()
  local fake = claude.fake('send-write-fails', 'ready')
  local buffer = start_ready_session(fake)
  send.set_input(child, { 'a message', 'second line' })
  local before = #claude.received(fake)

  local status = send.send_after_closing_stream(child, buffer)

  eq({ status = status, sent = sent_after(fake, before), input = send.input(child).lines }, {
    status = 'ready',
    sent = '',
    input = { 'a message', 'second line' },
  })
  contains(send.raised(child), "Can't send data to closed stream")
end

T['send()']['writes the paste and its Enter in one write'] = function()
  local fake = claude.fake('send-one-write', 'ready')
  start_ready_session(fake)
  send.set_input(child, { 'a message' })
  send.watch_writes(child)

  send.send(child)

  eq(send.writes(child), { '\27[200~a message\27[201~\r' })
end

T['send()']['writes no Enter on its own, which a dialog would read as an answer'] = function()
  local fake = claude.fake('send-no-lone-enter', 'asks')
  start_ready_session(fake)
  send.set_input(child, { 'a message' })
  local before = #claude.received_chunks(fake)
  local expected = '\27[200~a message\27[201~\r'
  local more_than_expected = #expected + 1

  send.send(child)

  eq(
    claude.wait_for_chunks_after(fake, before, more_than_expected, ONE_WRITE_PATIENCE_MS),
    { expected }
  )
end

T['send()']['says Input is empty before saying Claude is not ready'] = function()
  local fake = claude.fake('send-empty-behind-trust', 'trust')
  local buffer = start_session(fake)
  claude.wait_for_screen(child, buffer, 'Yes, I trust this folder')
  local before = #claude.received(fake)

  send.send(child)

  eq(refusal(fake, before), {
    sent = '',
    input = { '' },
    messages = { { message = 'aineo: nothing sent — Input is empty', level = WARN } },
  })
end

return T
