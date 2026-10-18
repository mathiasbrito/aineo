local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- The expression, run in the child, that tells the mode it is in, as
--- `nvim_get_mode()` names it.
local MODE = 'vim.api.nvim_get_mode().mode'

--- The expression, run in the child, that gives the line numbers the
--- child's window numbered by the argument shows.
local NUMBERS_OF_WINDOW = [[(function(number)
  local window = vim.fn.win_getid(number)
  return { number = vim.wo[window].number, relativenumber = vim.wo[window].relativenumber }
end)(...)]]

--- What the layout's windows show under the agent pane, as `entry.windows()`
--- lists them.
local AGENT_PANE = { 'terminal', 'aineo://report', 'aineo://input' }

--- What the layout's windows show under the changes pane.
local CHANGES_PANE = { 'terminal', 'aineo://changes-files', 'aineo://changes-commits' }

--- Every key that follows the terminal prefix, with the `<Plug>` mapping it
--- runs: the prefix keys but Send's.
local TWIN_KEYS = {
  { 'o', '<Plug>(aineo-open)' },
  { 'r', '<Plug>(aineo-report)' },
  { 'i', '<Plug>(aineo-input)' },
  { 'c', '<Plug>(aineo-claude)' },
  { 'tcn', '<Plug>(aineo-claude-numbers)' },
  { 'S', '<Plug>(aineo-sessions)' },
  { 'N', '<Plug>(aineo-new)' },
  { 'pa', '<Plug>(aineo-pane-agent)' },
  { 'g', '<Plug>(aineo-pane-changes)' },
  { 'pt', '<Plug>(aineo-pane-terminal)' },
  { 'T', '<Plug>(aineo-tab-new)' },
  { 'Q', '<Plug>(aineo-tab-close)' },
  { '1', '<Plug>(aineo-tab-1)' },
  { '2', '<Plug>(aineo-tab-2)' },
  { '3', '<Plug>(aineo-tab-3)' },
  { '4', '<Plug>(aineo-tab-4)' },
  { '5', '<Plug>(aineo-tab-5)' },
  { '6', '<Plug>(aineo-tab-6)' },
  { '7', '<Plug>(aineo-tab-7)' },
  { '8', '<Plug>(aineo-tab-8)' },
  { '9', '<Plug>(aineo-tab-9)' },
  { 'd', '<Plug>(aineo-diff-close)' },
  { 'f', '<Plug>(aineo-find)' },
  { 'z', '<Plug>(aineo-zoom)' },
}

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      entry.restart(child)
    end,
    post_once = child.stop,
  },
})

--- Every case of `cases` once for each mode a twin is pressed in, `t` for
--- Terminal mode and `i` for Insert mode, the mode first in its arguments.
---
---@param cases table[]
---@return table[]
local function in_each_mode(cases)
  local across = {}
  for _, mode in ipairs({ 't', 'i' }) do
    for _, case in ipairs(cases) do
      table.insert(across, vim.list_extend({ mode }, case))
    end
  end
  return across
end

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, waits until that Claude Code is ready, and
--- opens a file of the user's in the file column.
---
---@param name string the case's own name for its files
---@return table fake
---@return string file the file's path, as its window names it
local function open_layout(name)
  local fake = claude_session.fake(name, 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  local file = fixture.write(name .. '/file.txt', { 'text' })
  child.cmd('edit ' .. file)
  return fake, file
end

--- What the layout's windows show under `pane`, as `entry.windows()` lists
--- them, once `file` is open in the file column between Claude's window and
--- the right column.
---
---@param pane string[] what the windows show under the pane without the file
---@param file string
---@return string[]
local function with_file(pane, file)
  return { pane[1], file, pane[2], pane[3] }
end

--- How each mode a twin is pressed in is entered, by its name in
--- `nvim_get_mode()`.
local ENTER = {
  t = function()
    entry.press(child, '\\c')
  end,
  i = function()
    child.cmd('startinsert')
  end,
}

--- Puts the child in `mode` the way a user is when a twin is pressed in it:
--- `t`, Terminal mode in Claude's window, by `\c`; `i`, Insert mode in the
--- current window.
---
---@param mode 't'|'i'
local function enter(mode)
  ENTER[mode]()
  eq(child.lua_get(MODE), mode)
end

--- Types the terminal prefix followed by `keys`, as a user does.
---
---@param keys string
local function press_twin(keys)
  child.type_keys('<C-\\>' .. keys)
end

T['a twin'] = MiniTest.new_set()

T['a twin']['moves to the window of its action, in Normal mode but for \\c'] = MiniTest.new_set({
  parametrize = in_each_mode({
    { 'r', 'aineo://report', 'n' },
    { 'i', 'aineo://input', 'n' },
    { 'c', 'terminal', 't' },
  }),
})

T['a twin']['moves to the window of its action, in Normal mode but for \\c']['from'] = function(
  mode,
  key,
  window,
  resulting_mode
)
  open_layout('terminal-keys-window-' .. mode .. key)
  enter(mode)

  press_twin(key)

  eq({ entry.current_window(child), child.lua_get(MODE) }, { window, resulting_mode })
end

T['a twin']['<C-\\>o restores the window of the layout that was closed'] = MiniTest.new_set({
  parametrize = in_each_mode({ {} }),
})

T['a twin']['<C-\\>o restores the window of the layout that was closed']['from'] = function(mode)
  local _, file = open_layout('terminal-keys-open-' .. mode)
  child.lua("vim.api.nvim_win_close(vim.fn.bufwinid('aineo://input'), true)")
  enter(mode)

  press_twin('o')

  eq(entry.windows(child), with_file(AGENT_PANE, file))
end

T['a twin']['<C-\\>tcn hides the line numbers of Claude’s window'] = MiniTest.new_set({
  parametrize = in_each_mode({ {} }),
})

T['a twin']['<C-\\>tcn hides the line numbers of Claude’s window']['from'] = function(mode)
  local fake = claude_session.fake('terminal-keys-numbers-' .. mode, 'ready')
  entry.use_fake(child, fake)
  child.o.number = true
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  child.cmd('edit ' .. fixture.write('terminal-keys-numbers-' .. mode .. '/file.txt', { 'text' }))
  enter(mode)

  press_twin('tcn')

  eq(child.lua_get(NUMBERS_OF_WINDOW, { 1 }), { number = false, relativenumber = false })
end

T['a twin']['shows the pane of its action'] = MiniTest.new_set({
  parametrize = in_each_mode({
    { 'pa', 'changes', AGENT_PANE },
    { 'g', 'agent', CHANGES_PANE },
  }),
})

T['a twin']['shows the pane of its action']['from'] = function(mode, key, shown_before, shown)
  local _, file = open_layout('terminal-keys-pane-' .. mode .. key)
  entry.command(child, 'Aineo pane ' .. shown_before)
  enter(mode)

  press_twin(key)

  eq(entry.windows(child), with_file(shown, file))
end

T['a twin']['moves the cursor into the window of the pane of its action, in Normal mode'] =
  MiniTest.new_set({
    parametrize = in_each_mode({
      { 'pa', 'changes', 'aineo://report' },
      { 'g', 'agent', 'aineo://changes-commits' },
    }),
  })

T['a twin']['moves the cursor into the window of the pane of its action, in Normal mode']['from'] = function(
  mode,
  key,
  shown_before,
  window
)
  open_layout('terminal-keys-pane-cursor-' .. mode .. key)
  entry.command(child, 'Aineo pane ' .. shown_before)
  enter(mode)

  press_twin(key)

  eq({ entry.current_window(child), child.lua_get(MODE) }, { window, 'n' })
end

T['a twin']['<C-\\>S asks for the session list'] = MiniTest.new_set({
  parametrize = { { 't', 'terminal cat' }, { 'i', 'enew' } },
})

T['a twin']['<C-\\>S asks for the session list']['from'] = function(mode, buffer_command)
  child.cmd(buffer_command)
  child.cmd('startinsert')
  eq(child.lua_get(MODE), mode)

  press_twin('S')

  eq(entry.messages(child), {
    { message = 'aineo: no session list — Claude has not started', level = vim.log.levels.WARN },
  })
end

T['a twin']['has no Send among them'] = MiniTest.new_set({
  parametrize = { { 't' }, { 'i' }, { 'n' }, { 'x' } },
})

T['a twin']['has no Send among them']['in mode'] = function(mode)
  eq(child.fn.maparg('<C-\\>s', mode), '')
end

T['a twin']['is mapped in no other mode'] = MiniTest.new_set({
  parametrize = vim.list_extend(
    vim.tbl_map(function(twin)
      return { 'n', twin[1] }
    end, TWIN_KEYS),
    vim.tbl_map(function(twin)
      return { 'x', twin[1] }
    end, TWIN_KEYS)
  ),
})

T['a twin']['is mapped in no other mode']['in mode'] = function(mode, key)
  eq(child.fn.maparg('<C-\\>' .. key, mode), '')
  eq(child.cmd_capture('messages'), '')
end

T['Neovim’s own keys'] = MiniTest.new_set()

T['Neovim’s own keys']['<C-\\><C-n> leaves Terminal mode, the twins mapped'] = function()
  open_layout('terminal-keys-ctrl-n')
  enter('t')

  child.type_keys('<C-\\><C-n>')

  eq({ entry.current_window(child), child.lua_get(MODE) }, { 'terminal', 'nt' })
end

T['Neovim’s own keys']['<C-\\><C-o> runs one Normal-mode command from Insert mode, the twins mapped'] = function()
  open_layout('terminal-keys-ctrl-o')
  enter('i')

  child.type_keys('<C-\\><C-o>')

  eq(child.lua_get(MODE), 'niI')
end

--- What the terminal wrote to Claude Code that a user typed: `received`
--- without the terminal's own device replies and focus reports.
---
---@param received string
---@return string
local function typed_text(received)
  local without_replies = received:gsub('\27P.-\27\\', ''):gsub('\27%[[%d;?$]*%a', '')
  return without_replies
end

T['a twin']['sends Claude Code nothing of its keys'] = function()
  local fake = open_layout('terminal-keys-sends-nothing')
  enter('t')

  press_twin('c')
  press_twin('r')
  enter('t')
  child.type_keys('after')

  vim.wait(claude_session.PATIENCE_MS, function()
    return vim.endswith(claude_session.received(fake), 'after')
  end, 20)
  eq(typed_text(claude_session.received(fake)), 'after')
end

T['a twin']['from Insert mode expands an abbreviation before the cursor, as <Esc> does'] = function()
  child.cmd('enew')
  child.cmd('iabbrev teh the')
  child.api.nvim_buf_set_lines(0, 0, -1, true, { 'text' })

  child.type_keys('A teh')
  press_twin('S')

  eq(child.api.nvim_buf_get_lines(0, 0, -1, true), { 'text the' })
end

T['a twin']['from Insert mode repeats the insert by its count, as <Esc> does'] = function()
  child.cmd('enew')
  child.api.nvim_buf_set_lines(0, 0, -1, true, { 'text' })

  child.type_keys('3A x')
  press_twin('S')

  eq(child.api.nvim_buf_get_lines(0, 0, -1, true), { 'text x x x' })
end

T['the terminal prefix'] = MiniTest.new_set()

T['the terminal prefix']['is <C-\\> by default, each key mapped in Terminal and Insert mode'] =
  MiniTest.new_set({ parametrize = in_each_mode(TWIN_KEYS) })

T['the terminal prefix']['is <C-\\> by default, each key mapped in Terminal and Insert mode']['for'] = function(
  mode,
  key,
  plug
)
  eq(vim.endswith(child.fn.maparg('<C-\\>' .. key, mode), plug), true)
end

T['the terminal prefix']['is the one vim.g.aineo names'] = MiniTest.new_set({
  parametrize = in_each_mode(TWIN_KEYS),
})

T['the terminal prefix']['is the one vim.g.aineo names']['for'] = function(mode, key, plug)
  entry.restart(child, { '--cmd', "lua vim.g.aineo = { terminal_prefix = '<C-q>' }" })

  eq({
    vim.endswith(child.fn.maparg('<C-q>' .. key, mode), plug),
    child.fn.maparg('<C-\\>' .. key, mode),
  }, { true, '' })
end

T['the terminal prefix']['maps nothing, and says nothing, when it is false'] = MiniTest.new_set({
  parametrize = in_each_mode(TWIN_KEYS),
})

T['the terminal prefix']['maps nothing, and says nothing, when it is false']['for'] = function(
  mode,
  key
)
  entry.restart(child, { '--cmd', 'lua vim.g.aineo = { terminal_prefix = false }' })

  eq(child.fn.maparg('<C-\\>' .. key, mode), '')
  eq(child.cmd_capture('messages'), '')
end

T['the terminal prefix']['leaves the \\ keys mapped when it is false'] = function()
  entry.restart(child, { '--cmd', 'lua vim.g.aineo = { terminal_prefix = false }' })

  eq(child.fn.maparg('\\i', 'n'), '<Plug>(aineo-input)')
end

T['the terminal prefix']['is told to the user, naming it, when wrong, and nothing is mapped'] = function()
  entry.restart(child, { '--cmd', 'lua vim.g.aineo = { terminal_prefix = 1 }' })

  eq(
    child.cmd_capture('messages'),
    'aineo: terminal_prefix: expected a non-empty string, or false, got 1'
  )
  eq(child.fn.maparg('<C-\\>i', 't'), '')
end

T["the user's own mapping"] = MiniTest.new_set()

T["the user's own mapping"]['of a twin’s keys in one mode stays, and aineo maps the other mode'] =
  MiniTest.new_set({ parametrize = { { 't', 'i' }, { 'i', 't' } } })

T["the user's own mapping"]['of a twin’s keys in one mode stays, and aineo maps the other mode']['mapped in'] = function(
  own_mode,
  other_mode
)
  entry.restart(child, { '--cmd', own_mode .. 'noremap <C-\\>i <Cmd>let g:mine = 1<CR>' })

  eq({
    own = child.fn.maparg('<C-\\>i', own_mode),
    other = vim.endswith(child.fn.maparg('<C-\\>i', other_mode), '<Plug>(aineo-input)'),
  }, { own = '<Cmd>let g:mine = 1<CR>', other = true })
end

T["the user's own mapping"]['of a twin’s keys stays, and the other twins are mapped'] = function()
  entry.restart(child, { '--cmd', 'tnoremap <C-\\>r <Cmd>let g:mine = 1<CR>' })

  eq(child.fn.maparg('<C-\\>r', 't'), '<Cmd>let g:mine = 1<CR>')
  eq(vim.endswith(child.fn.maparg('<C-\\>i', 't'), '<Plug>(aineo-input)'), true)
end

T["the user's own mapping"]['of the terminal prefix alone in one mode leaves no twin there, and runs at once'] =
  MiniTest.new_set({ parametrize = { { 't', 'terminal cat', 'i' }, { 'i', 'enew', 't' } } })

T["the user's own mapping"]['of the terminal prefix alone in one mode leaves no twin there, and runs at once']['mapped in'] = function(
  own_mode,
  buffer_command,
  other_mode
)
  entry.restart(child, {
    '--cmd',
    'set timeoutlen=5000',
    '--cmd',
    own_mode .. 'noremap <C-\\> <Cmd>let g:mine = 1<CR>',
  })
  child.cmd(buffer_command)
  child.cmd('startinsert')
  eq(child.lua_get(MODE), own_mode)

  local own_twin = child.fn.maparg('<C-\\>i', own_mode)
  local other_twin = child.fn.maparg('<C-\\>i', other_mode)

  child.type_keys('<C-\\>')

  eq({
    vim.wait(1000, function()
      return not child.is_blocked() and child.g.mine == 1
    end, 20),
    own_twin,
    vim.endswith(other_twin, '<Plug>(aineo-input)'),
  }, { true, '', true })
end

return T
