local MiniTest = require('mini.test')
local claude = dofile('tests/helpers/claude_session.lua')
local send = dofile('tests/helpers/send.lua')

local eq = MiniTest.expect.equality

local WARN = vim.log.levels.WARN

--- What Send tells the user while Claude is not ready for input.
local NOT_READY =
  'aineo: nothing sent — Claude is not ready: it is starting, or a dialog in its window awaits your answer'

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
  send.send(child)
  claude.press_keys(child, buffer, '\r')
  claude.wait_for_status(child, 'starting')
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
  send.start_with_layout(child, fake)
  MiniTest.finally(function()
    claude.quit(child)
    claude.wait_for_end(fake)
  end)
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

return T
