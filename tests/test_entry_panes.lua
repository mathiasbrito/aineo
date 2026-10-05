local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- What the layout's windows show under the agent pane, as `entry.windows()`
--- lists them.
local AGENT_PANE = { 'terminal', 'aineo://report', 'aineo://input' }

--- What the layout's windows show under the changes pane, as
--- `entry.windows()` lists them.
local CHANGES_PANE = { 'terminal', 'aineo://changes-files', 'aineo://changes-commits' }

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      entry.restart(child)
    end,
    post_once = child.stop,
  },
})

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, and returns the fake.
---
---@param name string the case's own name for its files, starting `panes-`
---@return table fake
local function open_layout(name)
  local fake = claude_session.fake(name, 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  return fake
end

--- Each door to a pane, as a set's `parametrize`: its name, and the
--- function that opens it.
---
---@param pane string `agent` or `changes`
---@param key string the key after the prefix
---@return table
local function doors_to(pane, key)
  return {
    {
      'pressing \\' .. key,
      function()
        entry.press(child, '\\' .. key)
      end,
    },
    {
      ('pressing <Plug>(aineo-pane-%s)'):format(pane),
      function()
        entry.press(child, ('<Plug>(aineo-pane-%s)'):format(pane))
      end,
    },
    {
      'running :Aineo pane ' .. pane,
      function()
        entry.command(child, 'Aineo pane ' .. pane)
      end,
    },
  }
end

T['the changes pane'] = MiniTest.new_set({ parametrize = doors_to('changes', 'pc') })

T['the changes pane']['shows in the right column, telling the user nothing, by'] = function(_, door)
  open_layout('panes-doors-changes')

  door()

  eq({ entry.windows(child), entry.messages(child) }, { CHANGES_PANE, {} })
end

T['the agent pane'] = MiniTest.new_set({ parametrize = doors_to('agent', 'pa') })

T['the agent pane']['shows again in the right column, telling the user nothing, by'] = function(
  _,
  door
)
  open_layout('panes-doors-agent')
  entry.command(child, 'Aineo pane changes')

  door()

  eq({ entry.windows(child), entry.messages(child) }, { AGENT_PANE, {} })
end

--- What the buffer whose name is the argument is, read in the child: its
--- options and its lines.
local PLACEHOLDER = [[(function(name)
  local buffer = vim.fn.bufnr(name)
  return {
    buftype = vim.bo[buffer].buftype,
    buflisted = vim.bo[buffer].buflisted,
    bufhidden = vim.bo[buffer].bufhidden,
    swapfile = vim.bo[buffer].swapfile,
    modifiable = vim.bo[buffer].modifiable,
    lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, true),
  }
end)(...)]]

--- What a placeholder of the changes pane is, but for its line.
local SCRATCH = {
  buftype = 'nofile',
  buflisted = false,
  bufhidden = 'hide',
  swapfile = false,
  modifiable = false,
}

T['the changes pane’s windows'] = MiniTest.new_set()

T['the changes pane’s windows']['show a scratch buffer each, saying it lists nothing yet'] = function()
  open_layout('panes-placeholders')

  entry.press(child, '\\pc')

  eq({
    child.lua_get(PLACEHOLDER, { 'aineo://changes-files' }),
    child.lua_get(PLACEHOLDER, { 'aineo://changes-commits' }),
  }, {
    vim.tbl_extend('error', SCRATCH, {
      lines = { "aineo does not list the session's changed files here yet" },
    }),
    vim.tbl_extend('error', SCRATCH, {
      lines = { "aineo does not list the session's commits here yet" },
    }),
  })
end

--- The name of each window of the changes pane's buffer, with the line it
--- holds, as a set's `parametrize`.
local PLACEHOLDERS = {
  { 'aineo://changes-files', { "aineo does not list the session's changed files here yet" } },
  { 'aineo://changes-commits', { "aineo does not list the session's commits here yet" } },
}

T['a buffer already named as a buffer of the changes pane'] =
  MiniTest.new_set({ parametrize = PLACEHOLDERS })

T['a buffer already named as a buffer of the changes pane']['gives the name up, and the pane key shows the placeholder, for'] = function(
  name,
  line
)
  entry.use_fake(child, claude_session.fake('panes-namesake', 'ready'))
  child.lua('vim.api.nvim_buf_set_name(vim.api.nvim_create_buf(false, true), ...)', { name })

  entry.command(child, 'Aineo open')
  local opened = entry.windows(child)
  entry.press(child, '\\pc')

  eq(
    { opened, entry.windows(child), entry.messages(child), child.lua_get(PLACEHOLDER, { name }) },
    { AGENT_PANE, CHANGES_PANE, {}, vim.tbl_extend('error', SCRATCH, { lines = line }) }
  )
end

T['a buffer already named as a buffer of the changes pane']['keeps the text the user typed in it, unnamed, for'] = function(
  name
)
  entry.use_fake(child, claude_session.fake('panes-namesake-typed', 'ready'))
  local namesake = child.lua(
    [[
      local buffer = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_name(buffer, ...)
      vim.api.nvim_buf_set_lines(buffer, 0, -1, true, { 'my own notes' })
      return buffer
    ]],
    { name }
  )

  entry.command(child, 'Aineo open')
  entry.press(child, '\\pc')

  eq({
    entry.windows(child),
    entry.messages(child),
    child.api.nvim_buf_get_name(namesake),
    child.api.nvim_buf_get_lines(namesake, 0, -1, true),
  }, { CHANGES_PANE, {}, '', { 'my own notes' } })
end

--- Moves the child's cursor to the window showing the buffer named `name`.
---
---@param name string
local function enter_window_showing(name)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { name })
end

--- What the child's right column shows, top first: the last two windows
--- `entry.windows()` lists, whatever a file column beside it holds.
---
---@return string[]
local function right_column()
  local windows = entry.windows(child)
  return { windows[#windows - 1], windows[#windows] }
end

T['a buffer of the changes pane'] = MiniTest.new_set()

T['a buffer of the changes pane']['holds its line again once a command run in its window emptied it'] =
  MiniTest.new_set({
    parametrize = {
      { 'edit', PLACEHOLDERS[1][1], PLACEHOLDERS[1][2] },
      { 'edit', PLACEHOLDERS[2][1], PLACEHOLDERS[2][2] },
      { 'edit!', PLACEHOLDERS[1][1], PLACEHOLDERS[1][2] },
      { 'edit!', PLACEHOLDERS[2][1], PLACEHOLDERS[2][2] },
    },
  })

T['a buffer of the changes pane']['holds its line again once a command run in its window emptied it']['by'] = function(
  command,
  name,
  line
)
  open_layout('panes-edited')
  entry.press(child, '\\pc')
  enter_window_showing(name)

  entry.command(child, command)

  eq(
    { entry.windows(child), entry.messages(child), child.lua_get(PLACEHOLDER, { name }) },
    { CHANGES_PANE, {}, vim.tbl_extend('error', SCRATCH, { lines = line }) }
  )
end

T['a buffer of the changes pane']['deleted from its own window, is shown by the pane key holding its line,'] =
  MiniTest.new_set({ parametrize = PLACEHOLDERS })

T['a buffer of the changes pane']['deleted from its own window, is shown by the pane key holding its line,']['for'] = function(
  name,
  line
)
  open_layout('panes-deleted-in-place')
  entry.press(child, '\\pc')
  enter_window_showing(name)
  child.cmd('bdelete')

  entry.press(child, '\\pc')

  eq({ right_column(), entry.messages(child), child.lua_get(PLACEHOLDER, { name }) }, {
    { 'aineo://changes-files', 'aineo://changes-commits' },
    {},
    vim.tbl_extend('error', SCRATCH, { lines = line }),
  })
end

T['a session saved while the changes pane shows'] = MiniTest.new_set()

T['a session saved while the changes pane shows']['restored, lets the layout open and the pane key show the changes pane'] = function()
  local session = vim.fs.joinpath(fixture.directory('panes-session'), 'Session.vim')
  open_layout('panes-session-saved')
  entry.press(child, '\\pc')
  child.cmd('mksession! ' .. session)
  entry.restart(child, { '-S', session })
  entry.use_fake(child, claude_session.fake('panes-session-restored', 'ready'))

  entry.command(child, 'Aineo open')
  local opened = { entry.windows(child), entry.messages(child) }
  entry.press(child, '\\pc')

  eq(
    { opened, entry.windows(child), entry.messages(child) },
    { { AGENT_PANE, {} }, CHANGES_PANE, {} }
  )
end

--- Each pane, with its key after the prefix and what the layout's windows
--- show under it, as a set's `parametrize`.
local PANES = { { 'agent', 'pa', AGENT_PANE }, { 'changes', 'pc', CHANGES_PANE } }

T['the pane key, with the layout never opened,'] = MiniTest.new_set({ parametrize = PANES })

T['the pane key, with the layout never opened,']['opens the layout, showing the pane, for'] = function(
  _,
  key,
  windows
)
  local fake = claude_session.fake('panes-never-opened', 'ready')
  entry.use_fake(child, fake)

  entry.press(child, '\\' .. key)

  eq({ entry.windows(child), entry.messages(child) }, { windows, {} })
  eq(#claude_session.wait_for_starts(fake, 1), 1)
end

--- Gives the child a state directory of its own, `.tests/fixtures/<name>`,
--- and returns the file that keeps its draft for its working directory
--- there.
---
---@param name string
---@return string
local function own_draft(name)
  local state = fixture.directory(name)
  child.lua('vim.env.XDG_STATE_HOME = ...', { state })
  return vim.fs.joinpath(
    state,
    'nvim',
    'aineo',
    'drafts',
    vim.fn.sha256(child.fn.getcwd()) .. '.txt'
  )
end

--- The whole text of the file `draft`, or nil when it cannot be read.
---
---@param draft string
---@return string|nil
local function read_draft(draft)
  local file = io.open(draft, 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  return text
end

--- How long a case waits for the draft to hold what it waits for: longer
--- than the delay after which a change is saved.
local DRAFT_PATIENCE_MS = 5000

--- The lines of the layout's Input, read in the child.
local INPUT_LINES =
  "vim.api.nvim_buf_get_lines(require('aineo.layout').input_buffer(), 0, -1, true)"

T['the changes pane key, with the layout never opened,'] = MiniTest.new_set()

T['the changes pane key, with the layout never opened,']['hands Input to the draft, which the agent pane then shows and keeps'] = function()
  local draft = own_draft('panes-draft-state')
  vim.fn.mkdir(vim.fs.dirname(draft), 'p')
  assert(vim.fn.writefile({ 'Refactor the parser' }, draft) == 0, 'cannot write ' .. draft)
  entry.use_fake(child, claude_session.fake('panes-draft', 'ready'))

  entry.press(child, '\\pc')
  entry.press(child, '\\pa')
  local restored = child.lua_get(INPUT_LINES)
  entry.set_input(child, { 'then run the tests' })

  eq(restored, { 'Refactor the parser' })
  eq(
    vim.wait(DRAFT_PATIENCE_MS, function()
      return read_draft(draft) == 'then run the tests\n'
    end, 20),
    true
  )
end

--- What the child's current window shows, by name, and what each window of
--- its layout shows, as `entry.windows()` lists them.
---
---@return { string, string[] }
local function where_the_cursor_is()
  return { entry.current_window(child), entry.windows(child) }
end

T['while the changes pane shows'] = MiniTest.new_set()

T['while the changes pane shows']['the key of a window of the agent pane shows that pane, then moves there'] =
  MiniTest.new_set({
    parametrize = { { 'r', 'aineo://report' }, { 'i', 'aineo://input' } },
  })

T['while the changes pane shows']['the key of a window of the agent pane shows that pane, then moves there']['for'] = function(
  key,
  name
)
  open_layout('panes-focus')
  entry.press(child, '\\pc')

  entry.press(child, '\\' .. key)

  eq({ where_the_cursor_is(), entry.messages(child) }, { { name, AGENT_PANE }, {} })
end

--- What Claude's terminal receives when Send sends an Input holding `hello`:
--- one bracketed paste, then Enter.
local SENT_HELLO = '\27[200~hello\27[201~\r'

T['while the changes pane shows']['Send sends Input, unseen, and the changes pane stays'] = function()
  local fake = open_layout('panes-send')
  claude_session.wait_for_status(child, 'ready')
  entry.set_input(child, { 'hello' })
  entry.press(child, '\\pc')
  local received_before = #claude_session.received(fake)

  entry.press(child, '\\s')

  eq(claude_session.wait_for_received_after(fake, received_before, #SENT_HELLO), SENT_HELLO)
  eq(entry.windows(child), CHANGES_PANE)
end

T['while the changes pane shows']['the key of Claude moves to Claude, and the changes pane stays'] = function()
  open_layout('panes-claude')
  entry.press(child, '\\pc')

  entry.press(child, '\\c')

  eq(where_the_cursor_is(), { 'terminal', CHANGES_PANE })
end

T['while the changes pane shows']['the key of Claude’s line numbers toggles them, and the changes pane stays'] = function()
  child.o.number = true
  open_layout('panes-claude-numbers')
  entry.press(child, '\\pc')

  entry.press(child, '\\tcn')

  eq(
    { child.lua_get('vim.wo[vim.fn.win_getid(1)].number'), entry.windows(child) },
    { false, CHANGES_PANE }
  )
end

--- What `:Aineo pane` tells the user when it is not given one of its panes.
local PANE_USAGE = 'aineo: :Aineo pane takes one of agent, changes'

T[':Aineo pane'] = MiniTest.new_set()

T[':Aineo pane']['tells the user once, with one error, which panes it takes, and does nothing else,'] =
  MiniTest.new_set({
    parametrize = {
      { 'without a pane', 'Aineo pane' },
      { 'with another word', 'Aineo pane files' },
      { 'with more words after the pane', 'Aineo pane changes now' },
    },
  })

T[':Aineo pane']['tells the user once, with one error, which panes it takes, and does nothing else,']['given'] = function(
  _,
  command
)
  entry.use_fake(child, claude_session.fake('panes-usage', 'ready'))

  child.cmd(command)

  eq(
    { entry.messages(child), entry.windows(child) },
    { { { message = PANE_USAGE, level = vim.log.levels.ERROR } }, { '' } }
  )
end

T[':Aineo pane']['completes its pane, filtered by what is typed, and nothing after it'] =
  MiniTest.new_set({
    parametrize = {
      { 'Aineo pane ', { 'agent', 'changes' } },
      { 'Aineo pane c', { 'changes' } },
      { 'Aineo  pane  a', { 'agent' } },
      { 'Aineo pane agent ', {} },
    },
  })

T[':Aineo pane']['completes its pane, filtered by what is typed, and nothing after it']['after'] = function(
  typed,
  completed
)
  eq(child.fn.getcompletion(typed, 'cmdline'), completed)
end

--- `:Aineo`'s subcommands, in the order completion offers them.
local SUBCOMMANDS = { 'send', 'open', 'report', 'input', 'claude', 'claude-numbers', 'pane' }

T[':Aineo pane']['completes after a command modifier or a range as it does without one'] =
  MiniTest.new_set({
    parametrize = {
      { 'silent Aineo ', SUBCOMMANDS },
      { 'silent Aineo pane ', { 'agent', 'changes' } },
      { 'vertical Aineo p', { 'pane' } },
      { 'keepalt botright Aineo pane c', { 'changes' } },
      { 'silent! Ain pane a', { 'agent' } },
      { '5Aineo pane ', { 'agent', 'changes' } },
    },
  })

T[':Aineo pane']['completes after a command modifier or a range as it does without one']['after'] = function(
  typed,
  completed
)
  eq(child.fn.getcompletion(typed, 'cmdline'), completed)
end

--- What the child holds that a switch could leave behind: the windows of its
--- tab, its buffers, and the number of `aineo.layout` autocommands.
local HELD = [[{
  windows = vim.api.nvim_tabpage_list_wins(0),
  buffers = vim.api.nvim_list_bufs(),
  autocommands = #vim.api.nvim_get_autocmds({ group = 'aineo.layout' }),
}]]

--- Shows the changes pane, restores the layout and shows the agent pane in
--- the child, `times` times.
---
---@param times integer
local function switch_and_restore(times)
  for _ = 1, times do
    entry.press(child, '\\pc')
    entry.press(child, '\\o')
    entry.press(child, '\\pa')
  end
end

T['switching ten times'] = MiniTest.new_set()

T['switching ten times']['leaves the windows, buffers and autocommands switching twice leaves'] = function()
  open_layout('panes-ten-times')
  switch_and_restore(2)
  local after_two = child.lua_get(HELD)

  switch_and_restore(8)

  eq({ child.lua_get(HELD), entry.messages(child) }, { after_two, {} })
end

T['the changes pane key'] = MiniTest.new_set()

T['the changes pane key']['shows a wiped buffer of the changes pane anew, with no error'] =
  MiniTest.new_set({
    parametrize = { { 'aineo://changes-files' }, { 'aineo://changes-commits' } },
  })

T['the changes pane key']['shows a wiped buffer of the changes pane anew, with no error']['for'] = function(
  name
)
  open_layout('panes-wiped')
  entry.press(child, '\\pc')
  local wiped = child.fn.bufnr(name)
  child.cmd('bwipeout ' .. name)

  entry.press(child, '\\pc')

  eq(
    { entry.windows(child), entry.messages(child), child.fn.bufnr(name) ~= wiped },
    { CHANGES_PANE, {}, true }
  )
end

T['the changes pane key']['shows a deleted buffer of the changes pane anew, as a placeholder,'] =
  MiniTest.new_set({
    parametrize = { { 'deleted while shown', 'pc' }, { 'deleted while hidden', 'pa' } },
  })

T['the changes pane key']['shows a deleted buffer of the changes pane anew, as a placeholder,']['when'] = function(
  _,
  key_before_deleting
)
  open_layout('panes-deleted')
  entry.press(child, '\\pc')
  entry.press(child, '\\' .. key_before_deleting)
  child.cmd('bdelete ' .. child.fn.bufnr('aineo://changes-files'))

  entry.press(child, '\\pc')

  eq({
    entry.windows(child),
    entry.messages(child),
    child.lua_get(PLACEHOLDER, { 'aineo://changes-files' }),
  }, {
    CHANGES_PANE,
    {},
    vim.tbl_extend('error', SCRATCH, {
      lines = { "aineo does not list the session's changed files here yet" },
    }),
  })
end

return T
