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

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      send.restart(child)
    end,
    post_once = child.stop,
  },
})

--- The Lua that ends, in the child, the process of the terminal `...` by a
--- hangup, and waits for it to end, at most 5 s.
local END_TERMINAL = [[
  local job = vim.bo[...].channel
  vim.fn.jobstop(job)
  vim.fn.jobwait({ job }, 5000)
]]

--- Starts the session in `child` against a fake `claude` in `mode`, its
--- files under `name` prefixed `selection-`, with the layout around it, has
--- the session end by a hangup once the case is over (`END_TERMINAL`), and
--- moves the cursor to Input; returns the fake and the session's terminal
--- buffer.
---
---@param name string the case's own name for its files
---@param mode string one of the fake's modes
---@return { environment: table<string, string>, record: string } fake
---@return integer buffer
local function start_session(name, mode)
  local fake = claude.fake('selection-' .. name, mode)
  local buffer = send.start_with_layout(child, fake)
  MiniTest.finally(function()
    child.lua(END_TERMINAL, { buffer })
  end)
  send.enter_input(child)
  return fake, buffer
end

--- Starts the session as `start_session()` does in the fake's `ready` mode,
--- and waits for it to be ready; returns the fake and its terminal buffer.
---
---@param name string
---@return { environment: table<string, string>, record: string } fake
---@return integer buffer
local function start_ready_session(name)
  local fake, buffer = start_session(name, 'ready')
  claude.wait_for_status(child, 'ready')
  return fake, buffer
end

--- The bytes Send writes for `message`: one bracketed paste and its Enter.
---
---@param message string
---@return string
local function paste(message)
  return '\27[200~' .. message .. '\27[201~\r'
end

--- Two emoji joined by a zero-width joiner, U+200D, which Neovim draws as
--- one double-width character.
local FAMILY = '👨\226\128\141👩'

--- Each kind of selection, as a set's `parametrize`: its name, Input's
--- lines, the keys that select from Normal mode, Input's lines once Vim's
--- own `"_d` has removed the selection, and the text it removed.
local SELECTIONS = {
  {
    'charwise, across two lines',
    { 'alpha beta', 'gamma delta' },
    'gg0wvj',
    { 'alpha elta' },
    'beta\ngamma d',
  },
  { 'linewise', { 'a1', 'a2', 'a3', 'a4' }, 'ggjVj', { 'a1', 'a4' }, 'a2\na3' },
  { 'blockwise', { 'abcdef', 'abcdef' }, 'gg0l<C-v>jl', { 'adef', 'adef' }, 'bc\nbc' },
  {
    'blockwise to each line’s end, the cursor on a shorter line',
    { 'abcdef', 'abc' },
    'gg0l<C-v>j$',
    { 'a', 'a' },
    'bcdef\nbc',
  },
  {
    'blockwise, its left edge two columns past a short line’s end',
    { 'abcdef', 'ab', 'abcdef' },
    'gg0llll<C-v>jjl',
    { 'abcd', 'ab', 'abcd' },
    'ef\n\nef',
  },
  {
    'charwise past a line’s end, which joins the lines',
    { 'one', 'two', 'three' },
    'gg0lv$',
    { 'otwo', 'three' },
    'ne\n',
  },
  {
    'blockwise, its right edge on a double-width character’s left half',
    { 'abcdef', 'a漢字b', 'abcdef' },
    'gg0l<C-v>jj',
    { 'acdef', 'a 字b', 'acdef' },
    'b\n漢\nb',
  },
  {
    'blockwise, its right edge on an emoji with a skin tone’s left half',
    { 'abcdef', 'a👍🏽b', 'abcdef' },
    'gg0l<C-v>jj',
    { 'acdef', 'a b', 'acdef' },
    'b\n👍🏽\nb',
  },
  {
    'blockwise, its right edge on a flag’s left half',
    { 'abcdef', 'a🇫🇷b', 'abcdef' },
    'gg0l<C-v>jj',
    { 'acdef', 'a b', 'acdef' },
    'b\n🇫🇷\nb',
  },
  {
    'blockwise, its right edge on a joined emoji sequence’s left half',
    { 'abcdef', 'a' .. FAMILY .. 'b', 'abcdef' },
    'gg0l<C-v>jj',
    { 'acdef', 'a b', 'acdef' },
    'b\n' .. FAMILY .. '\nb',
  },
  {
    'blockwise, its left edge on a joined emoji sequence’s right half',
    { 'abcdef', 'a' .. FAMILY .. 'b', 'abcdef' },
    'gg0ll<C-v>jj',
    { 'abdef', 'a b', 'abdef' },
    'c\n' .. FAMILY .. '\nc',
  },
  {
    'blockwise, its right edge on a double-width character with a combining mark',
    { 'abcdef', 'a漢\204\129b', 'abcdef' },
    'gg0l<C-v>jj',
    { 'acdef', 'a b', 'acdef' },
    'b\n漢\204\129\nb',
  },
  {
    'blockwise, its left edge one column past a short line’s end',
    { 'abcdef', 'ab', 'abcdef' },
    'gg0ll<C-v>jjl',
    { 'abef', 'ab', 'abef' },
    'cd\n\ncd',
  },
  {
    'blockwise, cutting a tab',
    { 'abcdefghij', 'a\tb' },
    'gg0lll<C-v>jl',
    { 'abcj', 'a  ' },
    'defghi\n\tb',
  },
  {
    'charwise past a line’s end under virtualedit=all',
    { 'abc', 'def' },
    'gg0lv5l',
    { 'a', 'def' },
    'bc',
    { virtualedit = 'all' },
  },
  {
    'blockwise past each line’s end under virtualedit=block',
    { 'abc', 'abcd' },
    'gg0lll<C-v>jlll',
    { 'ab', 'ab' },
    'c\ncd',
    { virtualedit = 'block' },
  },
  { 'charwise, multibyte', { 'héllo wörld' }, 'gg0fwv3l', { 'héllo d' }, 'wörl' },
  {
    'charwise, selection=exclusive',
    { 'hello world' },
    'gg0v4l',
    { 'o world' },
    'hell',
    { selection = 'exclusive' },
  },
  { 'linewise, all of Input', { 'x', 'y' }, 'ggVG', { '' }, 'x\ny' },
  {
    'charwise to an empty line, selection=old, which ends it on the line above',
    { 'abc', '', 'def' },
    'gg0lvj',
    { 'a', '', 'def' },
    'bc',
    { selection = 'old' },
  },
  {
    'charwise to an empty line, selection=old, made backwards',
    { 'abc', '', 'def' },
    'jvk0l',
    { 'a', '', 'def' },
    'bc',
    { selection = 'old' },
  },
  {
    'charwise to an empty line two lines down, selection=old',
    { 'abc', 'de', '' },
    'gg0lvjj',
    { 'a', '' },
    'bc\nde',
    { selection = 'old' },
  },
  {
    'charwise to an empty line below an empty line, selection=old',
    { 'abc', '', '', 'def' },
    'gg0lvjj',
    { 'a', '', 'def' },
    'bc\n',
    { selection = 'old' },
  },
  {
    'charwise from the indent to an empty line, selection=old, which removes whole lines',
    { '  abc', 'x', '' },
    'gg0lvjj',
    { '' },
    '  abc\nx\n',
    { selection = 'old' },
  },
  {
    'charwise from a line’s first non-blank to an empty line, selection=old',
    { '  abc', 'x', '' },
    'gg0llvjj',
    { '' },
    '  abc\nx\n',
    { selection = 'old' },
  },
}

T['a Visual Send'] = MiniTest.new_set()

T['a Visual Send']['writes what it removes from Input as one paste and Enter, in one write,'] =
  MiniTest.new_set({ parametrize = SELECTIONS })

T['a Visual Send']['writes what it removes from Input as one paste and Enter, in one write,']['for'] = function(
  _,
  lines,
  keys,
  remaining,
  removed,
  options
)
  start_ready_session('removes')
  send.set_options(child, options)
  send.set_input(child, lines)
  send.watch_writes(child)

  send.send_selection(child, keys)

  eq({
    writes = send.writes(child),
    input = send.input(child).lines,
    messages = send.messages(child),
  }, { writes = { paste(removed) }, input = remaining, messages = {} })
end

T['a Visual Send']['writes the selection without its control bytes, nothing of it able to end the paste'] = function()
  start_ready_session('control-bytes')
  send.set_input(child, { 'a\3b\27[201~c', 'kept' })
  send.watch_writes(child)

  send.send_selection(child, 'ggV')

  eq(send.writes(child), { paste('ab[201~c') })
end

T['a Visual Send']['writes a NUL byte in the selection as Send writes it: not at all'] = function()
  start_ready_session('nul')
  send.set_input(child, { 'a\0b', 'kept' })
  send.watch_writes(child)

  send.send_selection(child, 'ggV')

  eq(
    { writes = send.writes(child), input = send.input(child).lines },
    { writes = { paste('ab') }, input = { 'kept' } }
  )
end

T['a Visual Send']['writes the selection made last, not the one made before it'] = function()
  start_ready_session('last-selection')
  send.set_input(child, { 'first part', 'second part' })
  send.watch_writes(child)

  send.send_selection(child, 'gg0vl<Esc>j0ve')

  eq(
    { writes = send.writes(child), input = send.input(child).lines },
    { writes = { paste('second') }, input = { 'first part', ' part' } }
  )
end

--- The expression, run in a Neovim, that gives the text of the unnamed
--- register, the yank and small delete registers, the first numbered one
--- and register `a`.
local REGISTERS = [[{
  unnamed = vim.fn.getreg('"'),
  yank = vim.fn.getreg('0'),
  small_delete = vim.fn.getreg('-'),
  first_delete = vim.fn.getreg('1'),
  a = vim.fn.getreg('a'),
}]]

T['a Visual Send']['leaves every register as it was, the unnamed one included'] = function()
  start_ready_session('registers')
  child.lua([[
    vim.fn.setreg('1', 'deleted before')
    vim.fn.setreg('-', 'small')
    vim.fn.setreg('a', 'the user’s a')
    vim.fn.setreg('0', 'yanked before')
  ]])
  local before = child.lua_get(REGISTERS)
  send.set_input(child, { 'some text to send' })
  send.watch_writes(child)

  send.send_selection(child, 'gg0wve')

  eq({
    registers = child.lua_get(REGISTERS),
    writes = send.writes(child),
    input = send.input(child).lines,
  }, { registers = before, writes = { paste('text') }, input = { 'some  to send' } })
end

T['a Visual Send']['removes the selection as Vim’s own "_d does, whatever d is mapped to in Visual mode'] = function()
  start_ready_session('own-d')
  child.cmd('xnoremap d "ad')
  child.fn.setreg('a', 'the user’s a')
  send.set_input(child, { 'alpha beta' })
  send.watch_writes(child)

  send.send_selection(child, '0wve')

  eq(
    { writes = send.writes(child), input = send.input(child).lines, a = child.fn.getreg('a') },
    { writes = { paste('beta') }, input = { 'alpha ' }, a = 'the user’s a' }
  )
end

T['a Visual Send']['leaves . to repeat its removal, which sends nothing, and u to bring it back'] = function()
  start_ready_session('dot')
  child.o.undolevels = 1000
  send.set_input(child, { 'alpha beta gamma delta' })
  send.watch_writes(child)
  send.send_selection(child, '0wve')

  send.type_keys(child, '.')
  local after_dot = send.input(child).lines
  send.type_keys(child, 'u')

  eq({ writes = send.writes(child), after_dot = after_dot, after_u = send.input(child).lines }, {
    writes = { paste('beta') },
    after_dot = { 'alpha ma delta' },
    after_u = { 'alpha  gamma delta' },
  })
end

T['a Visual Send']['leaves the cursor where Vim’s own "_d leaves it, in Normal mode'] = function()
  start_ready_session('cursor')
  send.set_input(child, { 'alpha beta', 'gamma delta' })

  send.send_selection(child, 'gg0wvj')

  eq(
    { cursor = child.api.nvim_win_get_cursor(0), mode = child.fn.mode() },
    { cursor = { 1, 6 }, mode = 'n' }
  )
end

local WARN = vim.log.levels.WARN

--- What a refused Visual Send leaves behind: the writes `child` made since
--- `send.watch_writes()`, Input's lines, and what the user was told.
---
---@return { writes: string[], input: string[], messages: table[] }
local function refusal()
  return {
    writes = send.writes(child),
    input = send.input(child).lines,
    messages = send.messages(child),
  }
end

T['a refused Visual Send'] = MiniTest.new_set()

T['a refused Visual Send']['removes and writes nothing, saying once, of a selection of white space alone, that it is empty'] = function()
  start_ready_session('blank')
  send.set_input(child, { 'text', ' \t ', 'more' })
  send.watch_writes(child)

  send.send_selection(child, 'ggjV')

  eq(refusal(), {
    writes = {},
    input = { 'text', ' \t ', 'more' },
    messages = { { message = 'aineo: nothing sent — the selection is empty', level = WARN } },
  })
end

T['a refused Visual Send']['removes and writes nothing, saying once, of a selection of control bytes alone, that it is empty'] = function()
  start_ready_session('control-bytes-alone')
  send.set_input(child, { '\27\3', 'kept' })
  send.watch_writes(child)

  send.send_selection(child, 'ggV')

  eq(refusal(), {
    writes = {},
    input = { '\27\3', 'kept' },
    messages = { { message = 'aineo: nothing sent — the selection is empty', level = WARN } },
  })
end

T['a refused Visual Send']['says the selection is empty before saying Claude has not started'] = function()
  send.open_layout_without_session(child)
  send.enter_input(child)
  send.set_input(child, { 'text', '   ', 'more' })

  send.send_selection(child, 'ggjV')

  eq(send.messages(child), {
    { message = 'aineo: nothing sent — the selection is empty', level = WARN },
  })
end

T['a refused Visual Send']['removes and writes nothing, saying so once, before Claude has started'] = function()
  send.open_layout_without_session(child)
  send.enter_input(child)
  send.set_input(child, { 'a message' })
  send.watch_writes(child)

  send.send_selection(child, 'ggV')

  eq(refusal(), {
    writes = {},
    input = { 'a message' },
    messages = { { message = 'aineo: nothing sent — Claude has not started', level = WARN } },
  })
end

T['a refused Visual Send']['removes and writes nothing, saying so once, behind the workspace-trust dialog'] = function()
  local _, buffer = start_session('trust', 'trust')
  claude.wait_for_screen(child, buffer, 'Yes, I trust this folder')
  send.set_input(child, { 'a message' })
  send.watch_writes(child)

  send.send_selection(child, 'ggV')

  eq(refusal(), {
    writes = {},
    input = { 'a message' },
    messages = {
      {
        message = 'aineo: nothing sent — Claude is not ready: it is starting, or a dialog in its window awaits your answer',
        level = WARN,
      },
    },
  })
end

T['a refused Visual Send']['removes and writes nothing, saying so once, once Claude has exited'] = function()
  start_session('exited', 'exit')
  claude.wait_for_status(child, 'exited')
  send.set_input(child, { 'a message' })
  send.watch_writes(child)

  send.send_selection(child, 'ggV')

  eq(refusal(), {
    writes = {},
    input = { 'a message' },
    messages = { { message = 'aineo: nothing sent — Claude has exited', level = WARN } },
  })
end

--- What a Visual Send tells the user outside Input.
local NOT_IN_INPUT = 'aineo: nothing sent — Visual Send works in Input only'

--- What a Visual Send outside Input leaves behind: the writes `child` made
--- since `send.watch_writes()`, the current buffer's lines, and what the
--- user was told.
---
---@return { writes: string[], lines: string[], messages: table[] }
local function refusal_outside_input()
  return {
    writes = send.writes(child),
    lines = child.api.nvim_buf_get_lines(0, 0, -1, false),
    messages = send.messages(child),
  }
end

T['a refused Visual Send']['removes and writes nothing outside Input, saying once that it works in Input'] = function()
  start_ready_session('outside')
  child.cmd('enew')
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'a file’s text' })
  send.watch_writes(child)

  send.send_selection(child, 'ggV')

  eq(refusal_outside_input(), {
    writes = {},
    lines = { 'a file’s text' },
    messages = { { message = NOT_IN_INPUT, level = WARN } },
  })
end

T['a refused Visual Send']['removes and writes nothing before the layout has made Input, saying once that it works in Input'] = function()
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'a file’s text' })
  send.watch_writes(child)

  send.send_selection(child, 'ggV')

  eq(refusal_outside_input(), {
    writes = {},
    lines = { 'a file’s text' },
    messages = { { message = NOT_IN_INPUT, level = WARN } },
  })
end

T['a refused Visual Send']['ends Visual mode, gv selecting again what was selected'] = function()
  send.open_layout_without_session(child)
  send.enter_input(child)
  send.set_input(child, { 'a message' })
  send.send_selection(child, 'gg0wv$')
  local mode_after = child.fn.mode()

  send.type_keys(child, 'gv')

  eq({
    mode_after = mode_after,
    selected = child.lua_get("vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.'))"),
  }, { mode_after = 'n', selected = { 'message' } })
end

T['a Visual Send in an Input that cannot be changed'] = MiniTest.new_set()

T['a Visual Send in an Input that cannot be changed']['writes nothing and raises Neovim’s error'] = function()
  start_ready_session('not-modifiable')
  send.set_input(child, { 'a message' })
  child.lua("vim.bo[require('aineo.layout').input_buffer()].modifiable = false")
  send.watch_writes(child)

  send.send_selection(child, 'ggV')

  eq({ writes = send.writes(child), input = send.input(child).lines }, {
    writes = {},
    input = { 'a message' },
  })
  contains(send.raised(child), 'E21')
end

T['a Visual Send whose write fails'] = MiniTest.new_set()

T['a Visual Send whose write fails']['puts Input back as it was and raises the write’s error'] = function()
  local _, buffer = start_ready_session('write-fails')
  send.set_input(child, { 'abc def', 'ghi' })

  local status = send.send_selection_after_closing_stream(child, buffer, 'gg0wvj')
  claude.wait_for_status(child, 'exited')

  eq({ status = status, input = send.input(child).lines }, {
    status = 'ready',
    input = { 'abc def', 'ghi' },
  })
  contains(send.raised(child), "Can't send data to closed stream")
end

T['a Visual Send whose write fails']['ends Visual mode, gv selecting again what was selected'] = function()
  local _, buffer = start_ready_session('write-fails-gv')
  send.set_input(child, { 'abc def', 'ghi' })
  send.send_selection_after_closing_stream(child, buffer, 'gg0wvj')
  claude.wait_for_status(child, 'exited')
  local mode_after = child.fn.mode()

  send.type_keys(child, 'gv')

  eq({
    mode_after = mode_after,
    selected = child.lua_get("vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.'))"),
  }, { mode_after = 'n', selected = { 'def', 'ghi' } })
end

T['a Visual Send whose write fails']['leaves one undo block, so that the first u changes nothing visible'] = function()
  local _, buffer = start_ready_session('write-fails-undo')
  child.o.undolevels = 1000
  send.type_keys(child, 'iabc def<Esc>')

  send.send_selection_after_closing_stream(child, buffer, '0wve')
  claude.wait_for_status(child, 'exited')
  local after_failure = send.input(child).lines
  send.type_keys(child, 'u')
  local after_u = send.input(child).lines
  send.type_keys(child, 'u')

  eq(
    { after_failure = after_failure, after_u = after_u, after_u_u = send.input(child).lines },
    { after_failure = { 'abc def' }, after_u = { 'abc def' }, after_u_u = { '' } }
  )
end

--- Each kind of selection undo is pinned for, as a set's `parametrize`: its
--- name, Input's lines, the keys that select, and the text sent.
local UNDONE_SELECTIONS = {
  { 'charwise', { 'alpha beta', 'gamma delta' }, 'gg0wvj', 'beta\ngamma d' },
  { 'linewise', { 'a1', 'a2', 'a3' }, 'ggjV', 'a2' },
  { 'blockwise', { 'abcdef', 'ab', 'abcdef' }, 'gg0llll<C-v>jjl', 'ef\n\nef' },
}

T['u after a Visual Send'] = MiniTest.new_set()

T['u after a Visual Send']['brings the selection back where it was, writing nothing more, for'] =
  MiniTest.new_set({ parametrize = UNDONE_SELECTIONS })

T['u after a Visual Send']['brings the selection back where it was, writing nothing more, for']['the kind'] = function(
  _,
  lines,
  keys,
  sent
)
  start_ready_session('undo')
  child.o.undolevels = 1000
  send.set_input(child, lines)
  send.watch_writes(child)
  send.send_selection(child, keys)

  send.type_keys(child, 'u')

  eq(
    { input = send.input(child).lines, writes = send.writes(child) },
    { input = lines, writes = { paste(sent) } }
  )
end

T['u after Sends, as the user’s undolevels allow'] = MiniTest.new_set()

T['u after Sends, as the user’s undolevels allow']['brings back only the last Send’s text, and toggles it, with undolevels 0'] = function()
  start_ready_session('undolevels-0')
  child.o.undolevels = 0
  send.type_keys(child, 'ifirst<Esc>')
  send.type_keys(child, '\\s')
  send.type_keys(child, 'isecond<Esc>')
  send.type_keys(child, '\\s')

  send.type_keys(child, 'u')
  local after_u = send.input(child).lines
  send.type_keys(child, 'u')
  local after_u_u = send.input(child).lines
  send.type_keys(child, 'u')

  eq(
    { after_u = after_u, after_u_u = after_u_u, after_u_u_u = send.input(child).lines },
    { after_u = { 'second' }, after_u_u = { '' }, after_u_u_u = { 'second' } }
  )
end

T['u after Sends, as the user’s undolevels allow']['brings nothing back with undolevels -1'] = function()
  start_ready_session('undolevels-off')
  child.o.undolevels = -1
  send.type_keys(child, 'ia message<Esc>')
  send.type_keys(child, '\\s')

  send.type_keys(child, 'u')

  eq(send.input(child).lines, { '' })
end

T['u after Sends, as the user’s undolevels allow']['brings back only the last Visual Send’s selection, and toggles it, with undolevels 0'] = function()
  start_ready_session('undolevels-0-visual')
  child.o.undolevels = 0
  send.set_input(child, { 'a1', 'a2', 'a3' })
  send.send_selection(child, 'ggV')
  send.send_selection(child, 'ggV')

  send.type_keys(child, 'u')
  local after_u = send.input(child).lines
  send.type_keys(child, 'u')
  local after_u_u = send.input(child).lines
  send.type_keys(child, 'u')

  eq(
    { after_u = after_u, after_u_u = after_u_u, after_u_u_u = send.input(child).lines },
    { after_u = { 'a2', 'a3' }, after_u_u = { 'a3' }, after_u_u_u = { 'a2', 'a3' } }
  )
end

T['u after Sends, as the user’s undolevels allow']['brings no Visual Send’s selection back with undolevels -1'] = function()
  start_ready_session('undolevels-off-visual')
  child.o.undolevels = -1
  send.set_input(child, { 'a1', 'a2' })
  send.send_selection(child, 'ggV')

  send.type_keys(child, 'u')

  eq(send.input(child).lines, { 'a2' })
end

return T
