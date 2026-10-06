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
}

T['a Visual Send'] = MiniTest.new_set()

T['a Visual Send']['writes what it removes from Input as one paste and Enter, in one write,'] =
  MiniTest.new_set({ parametrize = SELECTIONS })

T['a Visual Send']['writes what it removes from Input as one paste and Enter, in one write,']['for'] = function(
  _,
  lines,
  keys,
  remaining,
  removed
)
  start_ready_session('removes')
  send.set_input(child, lines)
  send.watch_writes(child)

  send.send_selection(child, keys)

  eq(
    { writes = send.writes(child), input = send.input(child).lines },
    { writes = { paste(removed) }, input = remaining }
  )
end

return T
