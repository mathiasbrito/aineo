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

--- The name and the lines of the child's buffer that is the argument, or
--- `'wiped'` once it was wiped out.
local NAME_AND_LINES = [[(function(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return 'wiped'
  end
  return { name = vim.api.nvim_buf_get_name(buffer), lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, true) }
end)(...)]]

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

  eq(
    { entry.windows(child), entry.messages(child), child.lua_get(NAME_AND_LINES, { namesake }) },
    { CHANGES_PANE, {}, { name = '', lines = { 'my own notes' } } }
  )
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

--- The group of the autocommands a case makes fail.
local FAILING_GROUP = 'panes-failing'

--- Makes every `BufWinEnter` for the buffer named `name` fail in the child
--- with the error `words`, as a user's own autocommand that raises does, in
--- `FAILING_GROUP` beside those made before.
---
---@param name string
---@param words string
local function fail_as_shown(name, words)
  child.lua(
    [[
      local group, name, words = ...
      vim.api.nvim_create_autocmd('BufWinEnter', {
        group = vim.api.nvim_create_augroup(group, { clear = false }),
        pattern = name,
        callback = function()
          error(words, 0)
        end,
      })
    ]],
    { FAILING_GROUP, name, words }
  )
end

--- What `fail_as_shown()` makes a user's own autocommand raise when a case
--- does not tell its errors apart.
local USER_AUTOCOMMAND_FAILED = 'the user’s own autocommand failed'

T['a switch a window refuses'] = MiniTest.new_set({
  parametrize = {
    {
      'winfixbuf on Input’s window',
      function()
        child.lua([[vim.wo[vim.fn.bufwinid('aineo://input')].winfixbuf = true]])
      end,
      function()
        child.lua([[vim.wo[vim.fn.bufwinid('aineo://input')].winfixbuf = false]])
      end,
    },
    {
      'a failing BufWinEnter for the files buffer',
      function()
        fail_as_shown('aineo://changes-files', USER_AUTOCOMMAND_FAILED)
      end,
      function()
        child.api.nvim_del_augroup_by_name(FAILING_GROUP)
      end,
    },
    {
      'a failing BufWinEnter for the commits buffer',
      function()
        fail_as_shown('aineo://changes-commits', USER_AUTOCOMMAND_FAILED)
      end,
      function()
        child.api.nvim_del_augroup_by_name(FAILING_GROUP)
      end,
    },
  },
})

T['a switch a window refuses']['leaves the column as it was, says why once, and the key switches once the cause is gone, under'] = function(
  _,
  refuse,
  stop_refusing
)
  open_layout('panes-refused')
  refuse()

  entry.press(child, '\\pc')
  local refused = { entry.windows(child), #entry.messages(child) }
  stop_refusing()
  entry.press(child, '\\pc')

  eq({ refused, entry.windows(child) }, { { AGENT_PANE, 1 }, CHANGES_PANE })
end

T['a switch refused in the command-line window'] = MiniTest.new_set()

T['a switch refused in the command-line window']['leaves the column as it was, and the key switches once it is closed'] = function()
  open_layout('panes-refused-cmdwin')
  enter_window_showing('aineo://input')

  child.type_keys('q:', '\\pc')
  local told = #entry.messages(child)
  child.type_keys('<C-c>', '<Esc>')
  local after_closing = entry.windows(child)
  entry.press(child, '\\pc')

  eq({ told, after_closing, entry.windows(child) }, { 1, AGENT_PANE, CHANGES_PANE })
end

--- What the user's own autocommand raises as the commits buffer is shown.
local COMMITS_REFUSED = 'the commits buffer was refused'

--- What the user's own autocommand raises as the Report is shown.
local REPORT_REFUSED = 'the Report was refused'

--- What aineo tells the user of `COMMITS_REFUSED`, framed as Neovim frames
--- an autocommand's error.
local TOLD_COMMITS_REFUSED = 'aineo: BufWinEnter Autocommands for "aineo://changes-commits": '
  .. 'Vim(append):Lua callback: '
  .. COMMITS_REFUSED

--- Makes a switch to the changes pane fail in the child at Input's window,
--- and the Report raise as it is shown there again, each with words of its
--- own: `COMMITS_REFUSED`, then `REPORT_REFUSED`.
local function refuse_switch_and_report()
  fail_as_shown('aineo://changes-commits', COMMITS_REFUSED)
  fail_as_shown('aineo://report', REPORT_REFUSED)
end

T['a switch refused, the Report raising as it is shown again,'] = MiniTest.new_set()

T['a switch refused, the Report raising as it is shown again,']['leaves the agent pane in both windows, telling the user once'] = function()
  open_layout('panes-refused-back')
  refuse_switch_and_report()

  entry.press(child, '\\pc')

  eq({ entry.windows(child), #entry.messages(child) }, { AGENT_PANE, 1 })
end

T['a switch refused, the Report raising as it is shown again,']['tells the user the switch’s own error, not the Report’s'] = function()
  open_layout('panes-refused-back-told')
  refuse_switch_and_report()

  entry.press(child, '\\pc')

  eq(entry.messages(child), { { message = TOLD_COMMITS_REFUSED, level = vim.log.levels.ERROR } })
end

T['the changes pane key from another tab page'] = MiniTest.new_set({
  parametrize = {
    { 'the layout whole', function() end },
    {
      'Input’s window closed',
      function()
        child.api.nvim_win_close(child.fn.bufwinid('aineo://input'), false)
      end,
    },
  },
})

T['the changes pane key from another tab page']['shows the pane in the layout’s tab page and leaves the cursor where it is, with'] = function(
  _,
  arrange_layout
)
  open_layout('panes-other-tab')
  arrange_layout()
  child.cmd('tabnew')
  local window = child.api.nvim_get_current_win()

  entry.press(child, '\\pc')
  local where = { child.api.nvim_get_current_win(), entry.messages(child) }
  child.cmd('tabfirst')

  eq({ where, entry.windows(child) }, { { window, {} }, CHANGES_PANE })
end

T['the changes pane key, a buffer named as its files buffer in the current window,'] =
  MiniTest.new_set()

T['the changes pane key, a buffer named as its files buffer in the current window,']['shows the pane in the layout’s tab page, telling nothing, when freeing the name closes that window'] = function()
  open_layout('panes-namesake-here')
  entry.press(child, '\\pc')
  entry.press(child, '\\pa')
  child.lua([[vim.cmd.bwipeout(vim.fn.bufnr('aineo://changes-files'))]])
  child.cmd('tabnew')
  child.cmd('split')
  child.cmd('edit aineo://changes-files')

  entry.press(child, '\\pc')
  local told = entry.messages(child)
  child.cmd('tabfirst')

  eq({ told, entry.windows(child) }, { {}, CHANGES_PANE })
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

T['the pane key, with the layout never opened,']['from a window showing a file, keeps the file beside the layout and starts the cursor in Input’s window, for'] = function(
  _,
  key,
  windows
)
  local file = fixture.write('panes-from-a-file/file.txt', { 'a file' })
  entry.use_fake(child, claude_session.fake('panes-from-a-file', 'ready'))
  child.cmd('edit ' .. file)

  entry.press(child, '\\' .. key)

  eq(
    { entry.windows(child), entry.current_window(child), entry.messages(child) },
    { { windows[1], file, windows[2], windows[3] }, windows[3], {} }
  )
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
  local before = entry.windows(child)

  entry.press(child, '\\' .. key)

  eq(
    { before, where_the_cursor_is(), entry.messages(child) },
    { CHANGES_PANE, { name, AGENT_PANE }, {} }
  )
end

T['while the changes pane shows']['the key of a window of the agent pane, the other’s buffer wiped, opens the layout and moves there'] =
  MiniTest.new_set({
    parametrize = {
      { 'r', 'aineo://input', 'aineo://report' },
      { 'i', 'aineo://report', 'aineo://input' },
    },
  })

T['while the changes pane shows']['the key of a window of the agent pane, the other’s buffer wiped, opens the layout and moves there']['for'] = function(
  key,
  wiped,
  name
)
  open_layout('panes-focus-wiped')
  entry.press(child, '\\pc')
  child.cmd('bwipeout ' .. wiped)

  entry.press(child, '\\' .. key)

  eq({ where_the_cursor_is(), entry.messages(child) }, { { name, AGENT_PANE }, {} })
end

T['while the agent pane shows'] = MiniTest.new_set()

T['while the agent pane shows']['the key of a window of the agent pane, the other’s buffer wiped, moves there and leaves the layout as it is'] =
  MiniTest.new_set({
    parametrize = {
      { 'r', 'aineo://input', 'aineo://report' },
      { 'i', 'aineo://report', 'aineo://input' },
    },
  })

T['while the agent pane shows']['the key of a window of the agent pane, the other’s buffer wiped, moves there and leaves the layout as it is']['for'] = function(
  key,
  wiped,
  name
)
  open_layout('panes-agent-wiped')
  child.cmd('bwipeout ' .. wiped)
  local left = entry.windows(child)

  entry.press(child, '\\' .. key)

  eq({ where_the_cursor_is(), entry.messages(child) }, { { name, left }, {} })
end

--- Gives the child a state directory of its own, `.tests/fixtures/<name>`,
--- so that it holds no record a case before it kept.
---
---@param name string
local function own_state(name)
  child.lua('vim.env.XDG_STATE_HOME = ...', { fixture.directory(name) })
end

--- Has `count` reports arrive in the child, through the report home as the
--- report tool hands them, each a few lines long.
---
---@param count integer
local function receive_reports(count)
  child.lua(
    [[
      for number = 1, ... do
        require('aineo.report').receive_report({
          task = 'Task ' .. number,
          status = 'done',
          summary = 'Summary ' .. number,
          details = string.rep('a line of details\n', 20),
        })
      end
    ]],
    { count }
  )
end

--- The cursor's line in the child's window showing the Report, and the
--- Report's last line.
local REPORT_CURSOR_AND_LAST_LINE = [[(function()
  local report = vim.fn.bufnr('aineo://report')
  return { vim.api.nvim_win_get_cursor(vim.fn.bufwinid(report))[1], vim.api.nvim_buf_line_count(report) }
end)()]]

T['a report arrived while the changes pane showed'] = MiniTest.new_set({
  parametrize = { { 'o' }, { 'pa' } },
})

T['a report arrived while the changes pane showed']['is on the Report’s last line once \\i, the Report’s window closed, then the key brings that window back,'] = function(
  key
)
  own_state('panes-follow-state')
  open_layout('panes-follow')
  receive_reports(2)
  entry.press(child, '\\r')
  child.api.nvim_win_set_cursor(0, { 3, 0 })
  entry.press(child, '\\pc')
  receive_reports(3)
  child.api.nvim_win_close(child.fn.bufwinid('aineo://changes-files'), false)
  entry.press(child, '\\i')

  entry.press(child, '\\' .. key)

  local cursor, last_line = unpack(child.lua_get(REPORT_CURSOR_AND_LAST_LINE))
  eq({ entry.windows(child), entry.messages(child), cursor }, { AGENT_PANE, {}, last_line })
end

T['a report arriving while the changes pane shows'] = MiniTest.new_set()

T['a report arriving while the changes pane shows']['shows nothing then, and \\pa shows it on the Report’s last line'] = function()
  own_state('panes-arrival-state')
  open_layout('panes-arrival')
  entry.press(child, '\\pc')

  receive_reports(1)
  local on_arrival = { entry.windows(child), entry.messages(child) }
  entry.press(child, '\\pa')

  local cursor, last_line = unpack(child.lua_get(REPORT_CURSOR_AND_LAST_LINE))
  eq(
    { on_arrival, entry.windows(child), entry.messages(child), cursor },
    { { CHANGES_PANE, {} }, AGENT_PANE, {}, last_line }
  )
end

T['a report arriving while the changes pane shows, the Report wiped before,'] =
  MiniTest.new_set({ parametrize = { { 1 }, { 2 } } })

T['a report arriving while the changes pane shows, the Report wiped before,']['is on the Report’s last line once \\pa shows the agent pane, as many having arrived as the Report held:'] = function(
  count
)
  own_state('panes-report-wiped-arrival-state')
  open_layout('panes-report-wiped-arrival')
  receive_reports(count)
  entry.press(child, '\\pc')
  child.lua([[vim.cmd.bwipeout(vim.fn.bufnr('aineo://report'))]])
  receive_reports(count)

  entry.press(child, '\\pa')

  local cursor, last_line = unpack(child.lua_get(REPORT_CURSOR_AND_LAST_LINE))
  eq({ entry.windows(child), entry.messages(child), cursor }, { AGENT_PANE, {}, last_line })
end

--- The child's Report's `'buftype'`.
local REPORT_BUFTYPE = [[vim.bo[vim.fn.bufnr('aineo://report')].buftype]]

T['while the changes pane shows']['the key of a window of the agent pane, the Report deleted, shows a Report anew that the next report keeps,'] =
  MiniTest.new_set({ parametrize = { { 'r' }, { 'i' } } })

T['while the changes pane shows']['the key of a window of the agent pane, the Report deleted, shows a Report anew that the next report keeps,']['for'] = function(
  key
)
  own_state('panes-report-deleted-state')
  open_layout('panes-report-deleted')
  receive_reports(1)
  entry.press(child, '\\pc')
  child.lua([[vim.cmd.bdelete(vim.fn.bufnr('aineo://report'))]])

  entry.press(child, '\\' .. key)
  local shown = { entry.windows(child), child.lua_get(REPORT_BUFTYPE) }
  receive_reports(1)

  eq(
    { shown, entry.windows(child), child.lua_get(REPORT_BUFTYPE) },
    { { AGENT_PANE, 'nofile' }, AGENT_PANE, 'nofile' }
  )
end

T['a switch to the changes pane, refused'] = MiniTest.new_set({
  parametrize = {
    {
      'in the command-line window',
      function()
        child.type_keys('q:', '\\pc')
        child.type_keys('<C-c>', '<Esc>')
      end,
    },
    {
      'by winfixbuf on Input’s window',
      function()
        child.lua([[vim.wo[vim.fn.bufwinid('aineo://input')].winfixbuf = true]])
        entry.press(child, '\\pc')
        child.lua([[vim.wo[vim.fn.bufwinid('aineo://input')].winfixbuf = false]])
      end,
    },
  },
})

T['a switch to the changes pane, refused']['leaves the Report’s cursor to the user when the layout is restored after a report arrived,'] = function(
  _,
  refuse_switch
)
  own_state('panes-refused-follow-state')
  open_layout('panes-refused-follow')
  receive_reports(2)
  entry.press(child, '\\r')
  refuse_switch()
  receive_reports(1)
  child.api.nvim_win_set_cursor(child.fn.bufwinid('aineo://report'), { 3, 0 })

  entry.press(child, '\\o')

  local cursor = child.lua_get(REPORT_CURSOR_AND_LAST_LINE)[1]
  eq({ entry.windows(child), cursor }, { AGENT_PANE, 3 })
end

T['a switch to the changes pane, refused']['keeps the agent pane the pane shown, which restoring the layout shows,'] = function(
  _,
  refuse_switch
)
  open_layout('panes-refused-kept')
  refuse_switch()

  entry.press(child, '\\o')

  eq(entry.windows(child), AGENT_PANE)
end

T['while the changes pane shows']['the key of a window of the agent pane, the other’s window closed, shows its buffer there alone, telling nothing'] =
  MiniTest.new_set({
    parametrize = {
      { 'r', 'aineo://changes-commits', 'aineo://report' },
      { 'i', 'aineo://changes-files', 'aineo://input' },
    },
  })

T['while the changes pane shows']['the key of a window of the agent pane, the other’s window closed, shows its buffer there alone, telling nothing']['for'] = function(
  key,
  closed,
  name
)
  own_state('panes-focus-closed-state')
  open_layout('panes-focus-closed')
  entry.press(child, '\\pc')
  child.api.nvim_win_close(child.fn.bufwinid(closed), false)
  receive_reports(1)

  entry.press(child, '\\' .. key)

  eq({ where_the_cursor_is(), entry.messages(child) }, { { name, { 'terminal', name } }, {} })
end

--- The buffers of the changes pane, read in the child by their names.
local CHANGES_PANE_BUFFERS =
  [[{ vim.fn.bufnr('aineo://changes-files'), vim.fn.bufnr('aineo://changes-commits') }]]

T['while the changes pane shows']['restoring the layout keeps its buffers, telling nothing, by'] =
  MiniTest.new_set({
    parametrize = {
      {
        'pressing \\o',
        function()
          entry.press(child, '\\o')
        end,
      },
      {
        'running :Aineo open',
        function()
          entry.command(child, 'Aineo open')
        end,
      },
    },
  })

T['while the changes pane shows']['restoring the layout keeps its buffers, telling nothing, by']['door'] = function(
  _,
  restore
)
  open_layout('panes-restore')
  entry.press(child, '\\pc')
  local buffers = child.lua_get(CHANGES_PANE_BUFFERS)
  child.api.nvim_win_close(child.fn.bufwinid('aineo://changes-commits'), false)

  restore()

  eq(
    { entry.windows(child), child.lua_get(CHANGES_PANE_BUFFERS), entry.messages(child) },
    { CHANGES_PANE, buffers, {} }
  )
end

T['the pane key, with its pane shown,'] = MiniTest.new_set({ parametrize = PANES })

T['the pane key, with its pane shown,']['changes nothing and tells the user nothing, for'] = function(
  _,
  key,
  windows
)
  open_layout('panes-shown-already')
  entry.press(child, '\\' .. key)
  local before = where_the_cursor_is()

  entry.press(child, '\\' .. key)

  eq({ before[2], where_the_cursor_is(), entry.messages(child) }, { windows, before, {} })
end

--- Makes a switch to the changes pane fail in the child at Input's window,
--- after the Report's window took the files buffer and, by the user's own
--- autocommand, `'winfixbuf'`: that window then refuses the Report back.
local function refuse_switch_and_files_back()
  child.lua(
    [[
      vim.api.nvim_create_autocmd('BufWinEnter', {
        group = vim.api.nvim_create_augroup(..., { clear = false }),
        pattern = 'aineo://changes-files',
        callback = function(event)
          vim.wo[vim.fn.bufwinid(event.buf)].winfixbuf = true
        end,
      })
    ]],
    { FAILING_GROUP }
  )
  fail_as_shown('aineo://changes-commits', COMMITS_REFUSED)
end

--- Ends, in the child, what `refuse_switch_and_files_back()` made refuse.
local function stop_refusing_files_back()
  child.api.nvim_del_augroup_by_name(FAILING_GROUP)
  child.lua([[vim.wo[vim.fn.bufwinid('aineo://changes-files')].winfixbuf = false]])
end

T['a switch refused, the Report’s window refusing the Report back,'] =
  MiniTest.new_set({ parametrize = PANES })

T['a switch refused, the Report’s window refusing the Report back,']['leaves both panes shown, and the pane key then shows its pane, for'] = function(
  _,
  key,
  windows
)
  open_layout('panes-refused-files-back')
  refuse_switch_and_files_back()
  entry.press(child, '\\pc')
  local refused = { entry.windows(child), #entry.messages(child) }
  stop_refusing_files_back()

  entry.press(child, '\\' .. key)

  eq(
    { refused, entry.windows(child) },
    { { { 'terminal', 'aineo://changes-files', 'aineo://input' }, 1 }, windows }
  )
end

T['a switch refused, the Report’s window refusing the Report back, a report arriving then,'] =
  MiniTest.new_set()

T['a switch refused, the Report’s window refusing the Report back, a report arriving then,']['is on the Report’s last line once \\pa shows the agent pane'] = function()
  own_state('panes-refused-files-back-follow-state')
  open_layout('panes-refused-files-back-follow')
  receive_reports(2)
  child.api.nvim_win_set_cursor(child.fn.bufwinid('aineo://report'), { 3, 0 })
  refuse_switch_and_files_back()
  entry.press(child, '\\pc')
  stop_refusing_files_back()
  receive_reports(1)

  entry.press(child, '\\pa')

  local cursor, last_line = unpack(child.lua_get(REPORT_CURSOR_AND_LAST_LINE))
  eq({ entry.windows(child), cursor }, { AGENT_PANE, last_line })
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
      { 'silent 5Aineo pane ', { 'agent', 'changes' } },
      { "'A Aineo pane ", { 'agent', 'changes' } },
    },
  })

T[':Aineo pane']['completes after an earlier command and a bar as it does alone'] =
  MiniTest.new_set({
    parametrize = {
      { 'Aineo open | Aineo ', SUBCOMMANDS },
      { 'Aineo pane changes | Aineo pane ', { 'agent', 'changes' } },
    },
  })

T[':Aineo pane']['completes after an earlier command and a bar as it does alone']['after'] = function(
  typed,
  completed
)
  eq(child.fn.getcompletion(typed, 'cmdline'), completed)
end

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

--- Shows the changes pane, then the agent pane, in the child, `times`
--- times, and returns what the layout's windows showed after each press,
--- as `entry.windows()` lists them.
---
---@param times integer
---@return string[][]
local function switch(times)
  local shown = {}
  for _ = 1, times do
    entry.press(child, '\\pc')
    table.insert(shown, entry.windows(child))
    entry.press(child, '\\pa')
    table.insert(shown, entry.windows(child))
  end
  return shown
end

T['switching ten times'] = MiniTest.new_set()

T['switching ten times']['shows each pane at each press, and leaves the windows, buffers and autocommands switching twice leaves'] = function()
  open_layout('panes-ten-times')
  local shown_by_two = switch(2)
  local after_two = child.lua_get(HELD)

  local shown_by_eight = switch(8)

  eq({ shown_by_two, shown_by_eight, child.lua_get(HELD), entry.messages(child) }, {
    vim.fn['repeat']({ CHANGES_PANE, AGENT_PANE }, 2),
    vim.fn['repeat']({ CHANGES_PANE, AGENT_PANE }, 8),
    after_two,
    {},
  })
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
