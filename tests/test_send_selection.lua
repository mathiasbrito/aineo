local MiniTest = require('mini.test')
local claude = dofile('tests/helpers/claude_session.lua')
local send = dofile('tests/helpers/send.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      send.restart(child)
    end,
    post_once = child.stop,
  },
})

--- Starts the session in `child` against a fake `claude` in `mode`, its
--- files under `name` prefixed `selection-`, with the layout around it, has
--- the session end by its keys once the case is over, and moves the cursor
--- to Input; returns the fake and the session's terminal buffer.
---
---@param name string the case's own name for its files
---@param mode string one of the fake's modes
---@return { environment: table<string, string>, record: string } fake
---@return integer buffer
local function start_session(name, mode)
  local fake = claude.fake('selection-' .. name, mode)
  local buffer = send.start_with_layout(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
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

  eq(
    { writes = send.writes(child), input = send.input(child).lines },
    { writes = { paste(removed) }, input = remaining }
  )
end

T['a Visual Send']['writes the selection without its control bytes, nothing of it able to end the paste'] = function()
  start_ready_session('control-bytes')
  send.set_input(child, { 'a\3b\27[201~c', 'kept' })
  send.watch_writes(child)

  send.send_selection(child, 'ggV')

  eq(send.writes(child), { paste('ab[201~c') })
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

  send.send_selection(child, 'gg0wve')

  eq(child.lua_get(REGISTERS), before)
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

return T
