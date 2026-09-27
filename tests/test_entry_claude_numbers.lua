local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- The expression, run in the child, that gives the line numbers the
--- child's window numbered by the argument shows: its `'number'` and
--- `'relativenumber'`.
local NUMBERS_OF_WINDOW = [[(function(number)
  local window = vim.fn.win_getid(number)
  return { number = vim.wo[window].number, relativenumber = vim.wo[window].relativenumber }
end)(...)]]

--- The line numbers Claude's window shows once they are hidden.
local HIDDEN = { number = false, relativenumber = false }

--- The expression, run in the child, that gives the terminal shown in the
--- child's first window, which is Claude's in the layout.
local CLAUDE_WINDOW_BUFFER = 'vim.api.nvim_win_get_buf(vim.fn.win_getid(1))'

--- Gives `child` the user's `:set number` and a state directory of its own
--- under `name`, then opens the layout in it with aineo running the fake
--- `claude` in its `ready` mode under `name`, with `extra_environment`, and
--- waits until that Claude Code has started.
---
---@param child table
---@param name string the test's own name for its files
---@param extra_environment? table<string, string> more of the fake's variables
---@return { record: string, environment: table<string, string> } fake
local function open_with_number(child, name, extra_environment)
  local fake = claude_session.fake(name, 'ready', extra_environment)
  child.lua('vim.env.XDG_STATE_HOME = ...', { fixture.directory(name .. '-state') })
  entry.use_fake(child, fake)
  child.o.number = true
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  return fake
end

--- Ends Claude Code in `child` as a hangup does, by stopping the job of the
--- terminal Claude's window shows, and fails the test unless the session has
--- exited within `claude_session.PATIENCE_MS`.
---
---@param child table
local function end_claude_code(child)
  child.lua(('vim.fn.jobstop(vim.bo[%s].channel)'):format(CLAUDE_WINDOW_BUFFER))
  eq(claude_session.wait_for_status(child, 'exited')[1], 'exited')
end

--- The line numbers `child`'s window numbered `number` shows — its first
--- is Claude's in the layout.
---
---@param child table
---@param number integer
---@return { number: boolean, relativenumber: boolean }
local function numbers_of_window(child, number)
  return child.lua_get(NUMBERS_OF_WINDOW, { number })
end

--- The code, run in the child, that shows in Claude's window, the child's
--- first, a scratch buffer that is not a file, as `:help` would show one,
--- which the layout leaves there.
local OTHER_BUFFER_IN_CLAUDE_WINDOW = [[
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buffer, 'claude-numbers://other')
  vim.api.nvim_win_set_buf(vim.fn.win_getid(1), buffer)
]]

--- The expression, run in the child, that lists its terminal buffers.
local TERMINALS = [[vim.tbl_filter(function(buffer)
  return vim.bo[buffer].buftype == 'terminal'
end, vim.api.nvim_list_bufs())]]

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      entry.restart(child)
    end,
    post_once = child.stop,
  },
})

T["Claude's line numbers"] = MiniTest.new_set({
  parametrize = {
    {
      'pressing \\tcn',
      function()
        entry.press(child, '\\tcn')
      end,
    },
    {
      'pressing <Plug>(aineo-claude-numbers)',
      function()
        entry.press(child, '<Plug>(aineo-claude-numbers)')
      end,
    },
    {
      'running :Aineo claude-numbers',
      function()
        entry.command(child, 'Aineo claude-numbers')
      end,
    },
  },
})

T["Claude's line numbers"]['are hidden, telling the user nothing, by'] = function(_, toggle)
  open_with_number(child, 'claude-numbers-doors')

  toggle()

  eq(numbers_of_window(child, 1), HIDDEN)
  eq(entry.messages(child), {})
end

T["Claude's line numbers, once hidden,"] = MiniTest.new_set()

T["Claude's line numbers, once hidden,"]['stay hidden in the terminal \\o restarts Claude Code in'] = function()
  local fake = open_with_number(child, 'claude-numbers-restart')
  local ended = child.lua_get(CLAUDE_WINDOW_BUFFER)
  entry.press(child, '\\tcn')
  end_claude_code(child)

  entry.press(child, '\\o')

  eq(#claude_session.wait_for_starts(fake, 2), 2)
  eq(child.api.nvim_buf_is_valid(ended), false)
  eq(numbers_of_window(child, 1), HIDDEN)
end

T["Claude's line numbers, once hidden,"]['stay hidden in the terminal of the new session that takes the place of a resume with no conversation'] = function()
  local name = 'claude-numbers-fallback'
  local fake = open_with_number(child, name, {
    AINEO_FAKE_CLAUDE_CONVERSATIONS = fixture.directory(name .. '-conversations'),
  })
  entry.press(child, '\\tcn')
  end_claude_code(child)

  child.cmd('Aineo open')

  eq(#claude_session.wait_for_starts(fake, 3), 3)
  eq(claude_session.wait_for_status(child, 'ready'), { 'ready' })
  eq(numbers_of_window(child, 1), HIDDEN)
end

T["Claude's line numbers, once hidden,"]["stay hidden in the terminal \\c starts once Claude's terminal was wiped"] = function()
  local fake = open_with_number(child, 'claude-numbers-wiped')
  entry.press(child, '\\tcn')
  child.type_keys('\\c', [[<C-\><C-n>]])
  entry.command(child, 'bwipeout!')
  eq(entry.windows(child), { 'aineo://report', 'aineo://input' })

  child.type_keys('\\c')

  eq(#claude_session.wait_for_starts(fake, 2), 2)
  eq(numbers_of_window(child, 1), HIDDEN)
end

T["Claude's line numbers, once hidden,"]["stay hidden in Claude's window that \\o opens again once it was closed"] = function()
  open_with_number(child, 'claude-numbers-reopened')
  entry.press(child, '\\tcn')
  child.cmd('1close')

  entry.press(child, '\\o')

  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(numbers_of_window(child, 1), HIDDEN)
end

T["Claude's line numbers, once hidden,"]["are not given to a file opened from Claude's window, which shows the user's own"] = function()
  local file = fixture.write('claude-numbers-file/file.txt', { 'text' })
  open_with_number(child, 'claude-numbers-file')
  entry.press(child, '\\tcn')
  child.type_keys('\\c', [[<C-\><C-n>]])

  entry.command(child, 'edit ' .. file)

  eq(entry.windows(child), { 'terminal', file, 'aineo://report', 'aineo://input' })
  eq(numbers_of_window(child, 2), { number = true, relativenumber = false })
end

T["Claude's line numbers, once hidden,"]["stay hidden in Claude's window that \\o opens again, once its terminal showed numbers in another window"] = function()
  open_with_number(child, 'claude-numbers-elsewhere')
  entry.press(child, '\\tcn')
  local terminal = child.lua_get(CLAUDE_WINDOW_BUFFER)
  child.cmd('1close')
  child.cmd('tab sbuffer ' .. terminal)
  child.cmd('setlocal number norelativenumber')
  child.cmd('tabclose')

  entry.press(child, '\\o')

  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(numbers_of_window(child, 1), HIDDEN)
end

T["Claude's line numbers, once hidden,"]["stay hidden in the terminal \\o restarts Claude Code in, once the layout's tab was closed"] = function()
  local fake = open_with_number(child, 'claude-numbers-rebuilt')
  local ended = child.lua_get(CLAUDE_WINDOW_BUFFER)
  entry.press(child, '\\tcn')
  end_claude_code(child)
  child.cmd('tabnew')
  child.cmd('1tabclose')
  eq(entry.windows(child), { '' })

  entry.press(child, '\\o')

  eq(#claude_session.wait_for_starts(fake, 2), 2)
  eq(child.api.nvim_buf_is_valid(ended), false)
  eq(entry.windows(child), { 'terminal', '', 'aineo://report', 'aineo://input' })
  eq(numbers_of_window(child, 1), HIDDEN)
end

T["Claude's line numbers, once hidden,"]["stay hidden in the new session's terminal the user brings back by hand to Claude's window, after the fallback started it while another buffer showed there"] = function()
  local name = 'claude-numbers-fallback-by-hand'
  local fake = open_with_number(child, name, {
    AINEO_FAKE_CLAUDE_CONVERSATIONS = fixture.directory(name .. '-conversations'),
  })
  entry.press(child, '\\tcn')
  end_claude_code(child)
  child.cmd('Aineo open')
  eq(#claude_session.wait_for_starts(fake, 2), 2)
  child.lua(OTHER_BUFFER_IN_CLAUDE_WINDOW)
  eq(#claude_session.wait_for_starts(fake, 3), 3)
  local terminals = child.lua_get(TERMINALS)
  eq({ #terminals, child.fn.win_findbuf(terminals[1]) }, { 1, {} })

  child.lua(
    'local terminal = ...; vim.api.nvim_win_call(vim.fn.win_getid(1), function() vim.cmd.buffer(terminal) end)',
    { terminals[1] }
  )

  eq(numbers_of_window(child, 1), HIDDEN)
end

T["Claude's line numbers, once shown in a Claude window that had none,"] = MiniTest.new_set()

T["Claude's line numbers, once shown in a Claude window that had none,"]['stay shown in the terminal \\o restarts Claude Code in'] = function()
  local fake = claude_session.fake('claude-numbers-shown', 'ready')
  child.lua('vim.env.XDG_STATE_HOME = ...', { fixture.directory('claude-numbers-shown-state') })
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  local ended = child.lua_get(CLAUDE_WINDOW_BUFFER)
  eq(numbers_of_window(child, 1), HIDDEN)
  entry.press(child, '\\tcn')
  eq(numbers_of_window(child, 1), { number = true, relativenumber = false })
  end_claude_code(child)

  entry.press(child, '\\o')

  eq(#claude_session.wait_for_starts(fake, 2), 2)
  eq(child.api.nvim_buf_is_valid(ended), false)
  eq(numbers_of_window(child, 1), { number = true, relativenumber = false })
end

T["Claude's line numbers, set by hand after \\tcn,"] = MiniTest.new_set({
  parametrize = {
    { '\\o', 'echo "the layout stays whole"' },
    { '\\i', '3close' },
    { '\\r', '2close' },
    {
      '\\o',
      'lua vim.api.nvim_win_set_buf(vim.fn.win_getid(1), vim.api.nvim_create_buf(false, true))',
    },
  },
})

T["Claude's line numbers, set by hand after \\tcn,"]['stay as the user set them, the terminal unchanged, on the key that opens the layout again, after'] = function(
  keys,
  closing
)
  open_with_number(child, 'claude-numbers-by-hand')
  entry.press(child, '\\tcn')
  child.lua("vim.api.nvim_win_call(vim.fn.win_getid(1), function() vim.cmd('setlocal number') end)")
  child.cmd(closing)

  entry.press(child, keys)

  eq(numbers_of_window(child, 1), { number = true, relativenumber = false })
end

T["Claude's line numbers, with no layout,"] = MiniTest.new_set()

T["Claude's line numbers, with no layout,"]['are not toggled on \\tcn, which warns the user once'] = function()
  child.o.number = true

  entry.press(child, '\\tcn')

  eq(numbers_of_window(child, 1), { number = true, relativenumber = false })
  eq(entry.messages(child), {
    {
      message = 'aineo: no line numbers toggled — there is no Claude window; open aineo’s layout to make one',
      level = vim.log.levels.WARN,
    },
  })
end

return T
