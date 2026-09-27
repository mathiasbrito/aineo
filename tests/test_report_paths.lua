local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local report_editor = dofile('tests/helpers/report_editor.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The group a file path in a report shows in.
local PATH_GROUP = 'AineoReportPath'

--- The Report's working directory in these tests, under `.tests/fixtures/`,
--- holding the files and directories `make_project()` writes.
local PROJECT = 'report-paths-project'

--- The absolute path of `name` in the Report's working directory.
---
---@param name string
---@return string
local function in_project(name)
  return vim.fs.joinpath(vim.fn.fnamemodify('.tests/fixtures', ':p'), PROJECT, name)
end

--- Makes the Report's working directory afresh, holding the files the tests
--- name.
local function make_project()
  fixture.directory(PROJECT)
  fixture.write(PROJECT .. '/lua/x.lua', { 'return {}' })
  fixture.write(PROJECT .. '/lua/foo.lua~', { 'return {}' })
  fixture.write(PROJECT .. '/notes.txt', { 'one', 'two', 'three', 'four' })
  fixture.write(PROJECT .. '/lua/x.lua:https:/x.y/a', { 'a line' })
  for _, name in ipairs({ 'Makefile', 'Makefile.', 'README.md', '.gitignore', '.luarc.json' }) do
    fixture.write(PROJECT .. '/' .. name, { 'a line' })
  end
  fixture.write(PROJECT .. '/inj/p%q.lua', { 'a line' })
  fixture.write(PROJECT .. '/~/x.lua', { 'a line' })
  assert(vim.uv.fs_symlink(in_project('notes.txt'), in_project('link.lua')))
  local made = vim.system({ 'mkfifo', in_project('pipe.lua') }):wait()
  assert(made.code == 0, made.stderr)
end

--- Starts the child's report home with the clock at `times`, a fresh state
--- directory and the working directory `PROJECT`.
---
---@param times string[]
local function start_editor(times)
  report_editor.start(child, {
    times = times,
    state_directory = fixture.directory('report-paths-state'),
    working_directory = in_project(''),
  })
end

--- The group `group` links to in the child, or nil when it links to none.
---
---@param group string
---@return string?
local function link_of(group)
  return child.lua_get(('vim.api.nvim_get_hl(0, { name = %q }).link'):format(group))
end

--- The expression, run in the child, that lists every extmark in its Report
--- drawn in `PATH_GROUP`, of every namespace, as `{ line, first column, end
--- column }`, counted as the API counts them — from 0, the end column
--- excluded — in buffer order.
local REPORT_PATHS = ([[(function()
  local buffer = require('aineo.report').report_buffer()
  local marks = vim.api.nvim_buf_get_extmarks(buffer, -1, 0, -1, { details = true })
  local paths = {}
  for _, mark in ipairs(marks) do
    if mark[4].hl_group == %q then
      table.insert(paths, { mark[2], mark[3], mark[4].end_col })
    end
  end
  return paths
end)()]]):format(PATH_GROUP)

--- Every path the child's Report draws (`REPORT_PATHS`).
---
---@return integer[][]
local function report_paths()
  return child.lua_get(REPORT_PATHS)
end

--- The text of every path the child's Report draws (`REPORT_PATHS`), in
--- buffer order.
---
---@return string[]
local function drawn_paths()
  return child.lua_get(
    [[(function(paths)
      local buffer = require('aineo.report').report_buffer()
      return vim.tbl_map(function(path)
        return vim.api.nvim_buf_get_text(buffer, path[1], path[2], path[1], path[3], {})[1]
      end, paths)
    end)(...)]],
    { report_paths() }
  )
end

--- Hands the child's report home a report whose details are `details`.
---
---@param details string
local function receive_details(details)
  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = details }
  )
end

local T = MiniTest.new_set({
  hooks = {
    pre_once = make_project,
    post_once = function()
      child.stop()
    end,
  },
})

T['the path group'] = MiniTest.new_set()

T['the path group']['links to Underlined once the Report shows a report'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  eq(link_of(PATH_GROUP), 'Underlined')
end

T['a path'] = MiniTest.new_set()

T['a path']['to a file in the working directory, in the details, is drawn in AineoReportPath'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = 'See lua/x.lua now' }
  )

  eq(report_paths(), { { 1, 10, 19 } })
end

T['a path']['in the task or the summary is drawn at its place in the header'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(
    child,
    { task = 'See lua/x.lua now', status = 'done', summary = 'at lua/x.lua' }
  )

  eq(report_paths(), { { 0, 17, 26 }, { 0, 38, 47 } })
end

T['a path']['that names no file is not drawn'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = 'lua/missing.lua' }
  )

  eq(report_paths(), {})
end

T['a path']["is looked up in the Report's working directory, not in Neovim's current directory"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  child.fn.chdir(fixture.directory('report-paths-elsewhere'))
  fixture.write('report-paths-elsewhere/lua/y.lua', { 'return {}' })

  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = 'lua/y.lua lua/x.lua' }
  )

  eq(report_paths(), { { 1, 16, 25 } })
end

T['a path']['that is absolute is drawn'] = function()
  start_editor({ '2026-09-24T09:05:00' })
  local absolute = in_project('lua/x.lua')

  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = absolute }
  )

  eq(report_paths(), { { 1, 6, 6 + #absolute } })
end

T['a path']['that names a directory is not drawn'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = 'See ./lua now' }
  )

  eq(report_paths(), {})
end

T['a path']['that names a FIFO is not drawn'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  receive_details('See pipe.lua now')

  eq(report_paths(), {})
end

T['a path']['that names a symbolic link to a file is drawn'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  receive_details('See link.lua now')

  eq(drawn_paths(), { 'link.lua' })
end

T['a path']['that starts with ~ is looked up in a directory named ~ in the working directory'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  receive_details('See ~/x.lua now')

  eq(drawn_paths(), { '~/x.lua' })
end

T['a stop'] = MiniTest.new_set({
  parametrize = {
    { '\1' },
    { '\t' },
    { '\31' },
    { '\127' },
    { '<' },
    { '>' },
    { '"' },
    { "'" },
    { '|' },
    { '`' },
    { '(' },
    { ')' },
    { '[' },
    { ']' },
    { '{' },
    { '}' },
    { ',' },
    { '*' },
  },
})

T['a stop']['on each side of a path leaves it out of the path'] = function(stop)
  start_editor({ '2026-09-24T09:05:00' })

  receive_details('See' .. stop .. 'lua/x.lua' .. stop .. 'now')

  eq(drawn_paths(), { 'lua/x.lua' })
end

T['trailing punctuation'] = MiniTest.new_set({
  parametrize = {
    { 'lua/x.lua.', 'lua/x.lua' },
    { 'lua/x.lua:', 'lua/x.lua' },
    { 'lua/x.lua;', 'lua/x.lua' },
    { 'lua/x.lua!', 'lua/x.lua' },
    { 'lua/x.lua?', 'lua/x.lua' },
    { 'lua/x.lua?!.', 'lua/x.lua' },
    { 'lua/x.lua:12.', 'lua/x.lua:12' },
  },
})

T['trailing punctuation']['is left out of the path'] = function(text, path)
  start_editor({ '2026-09-24T09:05:00' })

  receive_details('See ' .. text)

  eq(drawn_paths(), { path })
end

T['a trailing ~'] = MiniTest.new_set({
  parametrize = { { 'lua/foo.lua~', { 'lua/foo.lua~' } }, { 'lua/x.lua~', {} } },
})

T['a trailing ~']['is kept in the path'] = function(text, drawn)
  start_editor({ '2026-09-24T09:05:00' })

  receive_details('See ' .. text)

  eq(drawn_paths(), drawn)
end

T['a name'] = MiniTest.new_set({
  parametrize = {
    { 'README.md', { 'README.md' } },
    { '.luarc.json', { '.luarc.json' } },
    { './.gitignore', { './.gitignore' } },
    { './Makefile', { './Makefile' } },
    { 'Makefile', {} },
    { 'Makefile.', {} },
    { 'Makefile.:3', {} },
    { '.gitignore', {} },
  },
})

T['a name']['is a path when it holds a / or a . that neither starts nor ends it'] = function(
  text,
  drawn
)
  start_editor({ '2026-09-24T09:05:00' })

  receive_details('See ' .. text)

  eq(drawn_paths(), drawn)
end

T['a web link'] = MiniTest.new_set({
  parametrize = {
    { 'https://x.y/a,lua/x.lua', {} },
    { 'https://x.y/wiki/(lua/x.lua)', {} },
    { 'lua/x.lua:https://x.y/a', {} },
    { 'lua/x.lua https://x.y/a', { 'lua/x.lua' } },
    { 'https://x.y/a lua/x.lua', { 'lua/x.lua' } },
  },
})

T['a web link']['takes the place of any path inside it or across it'] = function(text, drawn)
  start_editor({ '2026-09-24T09:05:00' })

  receive_details(text)

  eq(drawn_paths(), drawn)
end

T['the file checks'] = MiniTest.new_set()

--- Makes the child's `vim.uv.fs_stat` count, in `_G.checks`, the times it is
--- asked about a file under `directory`, then do what it does.
---
---@param directory string
local function count_checks_under(directory)
  child.lua(
    [[
      local directory = ...
      local fs_stat = vim.uv.fs_stat
      _G.checks = 0
      vim.uv.fs_stat = function(path, ...)
        if vim.startswith(path, directory) then
          _G.checks = _G.checks + 1
        end
        return fs_stat(path, ...)
      end
    ]],
    { directory }
  )
end

T['the file checks']['are one for each distinct path, however often it occurs'] = function()
  start_editor({ '2026-09-24T09:05:00' })
  count_checks_under(in_project(''))

  report_editor.receive(child, {
    task = 'a/1 b/2',
    status = 'done',
    summary = 'a/1 c.d',
    details = 'a/1 b/2 lua/x.lua\nlua/x.lua c.d a/1',
  })

  eq(child.lua_get('_G.checks'), 4)
end

T['the file checks']['on :edit are one for each distinct path, however often it occurs'] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(
    child,
    { task = 'a/1 a/1', status = 'done', summary = 'a/1', details = 'a/1 a/1' }
  )
  report_editor.receive(child, { task = 'a/1', status = 'done', summary = 'a/1', details = 'a/1' })
  count_checks_under(in_project(''))
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])

  child.cmd('edit')

  eq(child.lua_get('_G.checks'), 1)
end

--- The expression, run in the child, that hands its report home a report
--- whose details are `count` distinct paths of four bytes, `xy/z` with `x`,
--- `y` and `z` each one of 62 letters and digits, one space apart, then
--- edits the Report again (`:edit`), and says of each step whether it took
--- at most `limit` seconds, or else how long it took.
local TIMED_DISTINCT_PATHS = [[
  local count, limit = ...
  local symbols = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
  local function symbol(index)
    return symbols:sub(index % 62 + 1, index % 62 + 1)
  end
  local paths = {}
  for index = 0, count - 1 do
    paths[#paths + 1] = symbol(math.floor(index / 3844)) .. symbol(math.floor(index / 62)) .. '/' .. symbol(index)
  end
  local details = table.concat(paths, ' ')
  local report = require('aineo.report')
  local function timed(step)
    local start = vim.uv.hrtime()
    step()
    local seconds = (vim.uv.hrtime() - start) / 1e9
    return seconds <= limit and 'within the limit' or ('%.1f s'):format(seconds)
  end
  local arrival = timed(function()
    report.receive_report({ task = 'Task', status = 'done', summary = 'Summary', details = details })
  end)
  vim.api.nvim_set_current_buf(report.report_buffer())
  local edit = timed(function()
    vim.cmd('edit')
  end)
  return { arrival = arrival, edit = edit }
]]

--- How many distinct four-byte paths, one space apart, fill the details of a
--- report the relay takes: its line limit of 1 MiB, less the report's
--- envelope, in five bytes a path.
local DISTINCT_PATHS_IN_A_LINE = 209674

--- How long a report may take to show, and to show again on `:edit`.
local TIME_LIMIT_SECONDS = 2

T['the file checks']['of a line of distinct paths take at most the time limit, on arrival and on :edit'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  local timings = child.lua(TIMED_DISTINCT_PATHS, { DISTINCT_PATHS_IN_A_LINE, TIME_LIMIT_SECONDS })

  eq(timings, { arrival = 'within the limit', edit = 'within the limit' })
end

T['the paths'] = MiniTest.new_set()

--- A report naming `lua/x.lua` in its details, and the paths it draws in the
--- Report, alone there.
local REPORT_WITH_A_PATH =
  { task = 'Task', status = 'done', summary = 'Summary', details = 'See lua/x.lua' }
local PATHS_OF_REPORT_WITH_A_PATH = { { 1, 10, 19 } }

T['the paths']['show again when the Report opens on the saved reports'] = function()
  local environment = {
    times = { '2026-09-24T09:05:00' },
    state_directory = fixture.directory('report-paths-kept-state'),
    working_directory = in_project(''),
  }
  report_editor.start(child, environment)
  report_editor.receive(child, REPORT_WITH_A_PATH)

  report_editor.start(child, environment)

  eq(report_paths(), PATHS_OF_REPORT_WITH_A_PATH)
end

T['the paths']['show once again when the user edits the Report again'] = MiniTest.new_set({
  parametrize = { { 'edit' }, { 'edit!' } },
})

T['the paths']['show once again when the user edits the Report again']['with'] = function(command)
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, REPORT_WITH_A_PATH)
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])

  child.cmd(command)

  eq(report_paths(), PATHS_OF_REPORT_WITH_A_PATH)
end

T['the paths']['show once again when the Report is made anew after the user deletes it'] =
  MiniTest.new_set({
    parametrize = { { 'bdelete' }, { 'bwipeout' }, { 'bunload' } },
  })

T['the paths']['show once again when the Report is made anew after the user deletes it']['with the command'] = function(
  command
)
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, REPORT_WITH_A_PATH)

  child.cmd(('%s %d'):format(command, child.lua_get([[require('aineo.report').report_buffer()]])))

  eq(report_paths(), PATHS_OF_REPORT_WITH_A_PATH)
end

T['a line'] = MiniTest.new_set({
  parametrize = { { 'lua/x.lua:12' }, { 'lua/x.lua:12:5' } },
})

T['a line']['after a path is drawn with it'] = function(text)
  start_editor({ '2026-09-24T09:05:00' })

  receive_details('At ' .. text .. ' now')

  eq(drawn_paths(), { text })
end

--- Starts the child as a user's editor in the Report's working directory,
--- `PROJECT`, with a fresh state directory, and opens aineo's layout there
--- around the fake `claude` (`:Aineo open`): the Report's working directory
--- is the editor's current directory when the layout first opens.
local function open_layout()
  entry.restart(child)
  child.lua('vim.env.XDG_STATE_HOME = ...', { fixture.directory('report-paths-layout-state') })
  entry.use_fake(child, claude_session.fake('report-paths', 'ready'))
  child.fn.chdir(in_project(''))
  child.cmd('Aineo open')
end

--- Double-clicks, in the child, with the left button, on byte `byte`, from
--- 0, of line `line`, from 1, of the first window showing the Report: two
--- presses and releases on its screen cell, as a mouse sends them.
---
---@param line integer
---@param byte integer
local function double_click_in_report(line, byte)
  local cell = child.lua_get(
    [[(function(line, byte)
      local window = vim.fn.win_findbuf(require('aineo.report').report_buffer())[1]
      local position = vim.fn.screenpos(window, line, byte + 1)
      return { row = position.row - 1, col = position.col - 1 }
    end)(...)]],
    { line, byte }
  )
  for _ = 1, 2 do
    child.api.nvim_input_mouse('left', 'press', '', 0, cell.row, cell.col)
    child.api.nvim_input_mouse('left', 'release', '', 0, cell.row, cell.col)
  end
end

--- How long a test waits for what a double-click does: typed keys run when
--- the child reads its input, and the file column is arranged from a
--- scheduled callback.
local CLICK_PATIENCE_MS = 5000

--- Waits, at most `CLICK_PATIENCE_MS`, until the child's current window
--- shows the file `file`.
---
---@param file string
local function wait_until_current_file_is(file)
  vim.wait(CLICK_PATIENCE_MS, function()
    return entry.current_window(child) == file
  end, 20)
end

--- What the child shows once a file opened: what each window shows, left to
--- right (`entry.windows()`), what the current window shows, its cursor's
--- line, the mode, and the last error message it gave (`v:errmsg`).
---
---@return { windows: string[], current: string, line: integer, mode: string, error: string }
local function where_the_file_opened()
  return {
    windows = entry.windows(child),
    current = entry.current_window(child),
    line = child.lua_get([[vim.fn.line('.')]]),
    mode = child.lua_get([[vim.fn.mode()]]),
    error = child.lua_get([[vim.v.errmsg]]),
  }
end

--- The file `file` open in the layout's file column and current, at line
--- `line`, in Normal mode, with no error given, as `where_the_file_opened()`
--- tells it.
---
---@param file string
---@param line integer
---@return { windows: string[], current: string, line: integer, mode: string, error: string }
local function opened_in_file_column(file, line)
  return {
    windows = { 'terminal', file, 'aineo://report', 'aineo://input' },
    current = file,
    line = line,
    mode = 'n',
    error = '',
  }
end

--- Runs `command` in the child's current window, such as `startinsert`, and
--- waits, at most `CLICK_PATIENCE_MS`, until the child is in `mode`
--- (`mode()`). Raises an error when it is not by then.
---
---@param command string
---@param mode string
local function enter_mode(command, mode)
  child.cmd(command)
  local entered = vim.wait(CLICK_PATIENCE_MS, function()
    return child.lua_get([[vim.fn.mode()]]) == mode
  end, 20)
  assert(entered, ('the child did not enter mode %s'):format(mode))
end

--- Where a double-click can come from, each by the name a case gives it:
--- puts the child's cursor there, in the mode named.
local PLACES_A_CLICK_COMES_FROM = {
  ['the Report in Normal mode'] = function()
    child.lua(
      [[vim.api.nvim_set_current_win(vim.fn.win_findbuf(require('aineo.report').report_buffer())[1])]]
    )
  end,
  ['Input in Insert mode'] = function()
    child.lua(
      [[vim.api.nvim_set_current_win(vim.fn.win_findbuf(require('aineo.layout').input_buffer())[1])]]
    )
    enter_mode('startinsert', 'i')
  end,
  ["Claude's terminal in Terminal mode"] = function()
    claude_session.wait_for_status(child, 'ready')
    child.lua([[vim.api.nvim_set_current_win(vim.fn.win_findbuf(vim.fn.bufnr('term://*'))[1])]])
    enter_mode('startinsert', 't')
  end,
}

--- Waits, at most `CLICK_PATIENCE_MS`, until the child is in Visual mode,
--- then tells what it selects: the mode, the first and last column of the
--- selection, from 1, and its line.
---
---@return { [1]: string, [2]: integer, [3]: integer, [4]: integer }
local function selection()
  vim.wait(CLICK_PATIENCE_MS, function()
    return child.lua_get([[vim.fn.mode()]]) == 'v'
  end, 20)
  return child.lua_get(
    [[{ vim.fn.mode(), vim.fn.getpos('v')[3], vim.fn.col('.'), vim.fn.line('.') }]]
  )
end

T['a double-click'] = MiniTest.new_set()

T['a double-click']['on a path with a line'] = MiniTest.new_set({
  parametrize = {
    { 'the Report in Normal mode' },
    { 'Input in Insert mode' },
    { "Claude's terminal in Terminal mode" },
  },
})

T['a double-click']['on a path with a line']['opens its file in the file column, at the line, in Normal mode, from'] = function(
  place
)
  open_layout()
  receive_details('See notes.txt:3 now')
  PLACES_A_CLICK_COMES_FROM[place]()

  double_click_in_report(2, 12)

  wait_until_current_file_is(in_project('notes.txt'))
  eq(where_the_file_opened(), opened_in_file_column(in_project('notes.txt'), 3))
end

T['a double-click']['on a path with no line opens its file in the file column'] = function()
  open_layout()
  receive_details('See lua/x.lua now')
  PLACES_A_CLICK_COMES_FROM['the Report in Normal mode']()

  double_click_in_report(2, 12)

  wait_until_current_file_is(in_project('lua/x.lua'))
  eq(where_the_file_opened(), opened_in_file_column(in_project('lua/x.lua'), 1))
end

T['a double-click']['on a path after a comma opens that path, not the one before it'] = function()
  open_layout()
  receive_details('lua/x.lua,notes.txt:3')
  PLACES_A_CLICK_COMES_FROM['the Report in Normal mode']()

  double_click_in_report(2, 20)

  wait_until_current_file_is(in_project('notes.txt'))
  eq(where_the_file_opened(), opened_in_file_column(in_project('notes.txt'), 3))
end

T['a double-click']['on a path holding a % opens the file it names'] = function()
  open_layout()
  receive_details('See inj/p%q.lua now')
  PLACES_A_CLICK_COMES_FROM['the Report in Normal mode']()

  double_click_in_report(2, 12)

  wait_until_current_file_is(in_project('inj/p%q.lua'))
  eq(where_the_file_opened(), opened_in_file_column(in_project('inj/p%q.lua'), 1))
end

T['a double-click']['on a path with a line outside the file'] = MiniTest.new_set({
  parametrize = {
    { 'notes.txt:0', 1 },
    { 'notes.txt:99', 4 },
    { 'notes.txt:99999999999999999999', 4 },
  },
})

T['a double-click']['on a path with a line outside the file']['opens it at its nearest line'] = function(
  path,
  line
)
  open_layout()
  receive_details('See ' .. path .. ' now')
  PLACES_A_CLICK_COMES_FROM['the Report in Normal mode']()

  double_click_in_report(2, 12)

  wait_until_current_file_is(in_project('notes.txt'))
  eq(where_the_file_opened(), opened_in_file_column(in_project('notes.txt'), line))
end

T['a double-click']['on the Report made anew after the user deletes it'] = MiniTest.new_set({
  parametrize = { { 'bdelete' }, { 'bwipeout' }, { 'bunload' } },
})

T['a double-click']['on the Report made anew after the user deletes it']['opens the file'] = function(
  command
)
  open_layout()
  receive_details('See notes.txt:3 now')
  child.cmd(('%s %d'):format(command, child.lua_get([[require('aineo.report').report_buffer()]])))
  child.cmd('Aineo report')
  PLACES_A_CLICK_COMES_FROM['the Report in Normal mode']()

  double_click_in_report(2, 12)

  wait_until_current_file_is(in_project('notes.txt'))
  eq(where_the_file_opened(), opened_in_file_column(in_project('notes.txt'), 3))
end

T['a double-click']["opens the file in the Report's working directory, after Neovim's current directory changed"] = function()
  open_layout()
  receive_details('See notes.txt:3 now')
  child.fn.chdir(fixture.directory('report-paths-elsewhere'))
  fixture.write('report-paths-elsewhere/notes.txt', { 'elsewhere' })
  PLACES_A_CLICK_COMES_FROM['the Report in Normal mode']()

  double_click_in_report(2, 12)

  wait_until_current_file_is(in_project('notes.txt'))
  eq(entry.current_window(child), in_project('notes.txt'))
end

T['a double-click']['elsewhere in the Report'] = MiniTest.new_set({
  parametrize = { { 'the Report in Normal mode' }, { 'Input in Insert mode' } },
})

T['a double-click']['elsewhere in the Report']['selects the word, as Neovim does, from'] = function(
  place
)
  open_layout()
  receive_details('See notes.txt:3 now')
  PLACES_A_CLICK_COMES_FROM[place]()

  double_click_in_report(2, 7)

  eq(selection(), { 'v', 7, 9, 2 })
end

T['a double-click']['on the first or the last byte of a path'] = MiniTest.new_set({
  parametrize = { { 10 }, { 20 } },
})

T['a double-click']['on the first or the last byte of a path']['opens its file, on byte'] = function(
  byte
)
  open_layout()
  receive_details('See notes.txt:3 now')
  PLACES_A_CLICK_COMES_FROM['the Report in Normal mode']()

  double_click_in_report(2, byte)

  wait_until_current_file_is(in_project('notes.txt'))
  eq(where_the_file_opened(), opened_in_file_column(in_project('notes.txt'), 3))
end

T['a double-click']['on the space just before or after a path'] = MiniTest.new_set({
  parametrize = { { 9 }, { 21 } },
})

T['a double-click']['on the space just before or after a path']['opens nothing, on byte'] = function(
  byte
)
  open_layout()
  receive_details('See notes.txt:3 now')
  PLACES_A_CLICK_COMES_FROM['the Report in Normal mode']()

  double_click_in_report(2, byte)

  eq(
    { selection()[1], entry.windows(child) },
    { 'v', { 'terminal', 'aineo://report', 'aineo://input' } }
  )
end

--- What the child shows after a double-click that opens nothing: what each
--- window shows, left to right (`entry.windows()`), and the last error
--- message it gave (`v:errmsg`).
---
---@return { windows: string[], error: string }
local function what_the_layout_shows()
  return { windows = entry.windows(child), error = child.lua_get([[vim.v.errmsg]]) }
end

--- The layout as `what_the_layout_shows()` tells it when a double-click
--- opened nothing and gave no error.
local NOTHING_OPENED = { windows = { 'terminal', 'aineo://report', 'aineo://input' }, error = '' }

T['a double-click']['past the end of a line that ends in a path opens nothing'] = function()
  open_layout()
  receive_details('See notes.txt:3')
  PLACES_A_CLICK_COMES_FROM['the Report in Normal mode']()

  double_click_in_report(2, 30)

  selection()
  eq(what_the_layout_shows(), NOTHING_OPENED)
end

T['a double-click']['on a web link opens no file and selects the word, as Neovim does'] = function()
  open_layout()
  receive_details('See https://x.y/a now')
  PLACES_A_CLICK_COMES_FROM['the Report in Normal mode']()

  double_click_in_report(2, 14)

  eq(
    { mode = selection()[1], shown = what_the_layout_shows(), told = entry.messages(child) },
    { mode = 'v', shown = NOTHING_OPENED, told = {} }
  )
end

T['a double-click']["on the Report's status line opens nothing"] = function()
  open_layout()
  receive_details('See notes.txt:3')
  PLACES_A_CLICK_COMES_FROM['the Report in Normal mode']()
  local status_line = child.lua_get([[(function()
    local window = vim.fn.win_findbuf(require('aineo.report').report_buffer())[1]
    local position = vim.api.nvim_win_get_position(window)
    return { row = position[1] + vim.api.nvim_win_get_height(window), col = position[2] + 12 }
  end)()]])

  for _ = 1, 2 do
    child.api.nvim_input_mouse('left', 'press', '', 0, status_line.row, status_line.col)
    child.api.nvim_input_mouse('left', 'release', '', 0, status_line.row, status_line.col)
  end

  vim.wait(CLICK_PATIENCE_MS, function()
    return child.lua_get([[vim.api.nvim_get_mode().blocking]]) == false
  end, 20)
  eq(what_the_layout_shows(), NOTHING_OPENED)
end

--- Whether a reader holds the FIFO `fifo` open: tries, without waiting, to
--- open it for writing, which succeeds only then, and writes it a line and
--- closes it, so the reader reads that line and the end of the file and
--- goes on.
---
---@param fifo string
---@return boolean
local function release_reader_of(fifo)
  local writer = vim.uv.fs_open(
    fifo,
    require('bit').bor(vim.uv.constants.O_WRONLY, vim.uv.constants.O_NONBLOCK),
    tonumber('644', 8)
  )
  if not writer then
    return false
  end
  vim.uv.fs_write(writer, 'written by the test\n')
  vim.uv.fs_close(writer)
  return true
end

--- How often a case releases the readers of a FIFO.
local RELEASE_INTERVAL_MS = 20

--- Releases any reader of the FIFO `fifo` (`release_reader_of()`) every
--- `RELEASE_INTERVAL_MS`, from now until the case ends, while the test waits
--- on the child too: a child that opened the FIFO is held in `open(2)` until
--- a writer comes, and would hold the test with it. Returns a function that
--- tells whether a reader was released so far.
---
---@param fifo string
---@return fun(): boolean
local function keep_releasing_readers_of(fifo)
  local released = false
  local timer = assert(vim.uv.new_timer())
  timer:start(0, RELEASE_INTERVAL_MS, function()
    released = release_reader_of(fifo) or released
  end)
  MiniTest.finally(function()
    timer:stop()
    timer:close()
  end)
  return function()
    return released
  end
end

--- Replaces the file `file` with a FIFO of the same name.
---
---@param file string
local function replace_with_fifo(file)
  assert(os.remove(file))
  local made = vim.system({ 'mkfifo', file }):wait()
  assert(made.code == 0, made.stderr)
end

--- Waits, at most `CLICK_PATIENCE_MS`, until the child has told the user
--- something (`entry.messages()`).
local function wait_until_told()
  vim.wait(CLICK_PATIENCE_MS, function()
    return #entry.messages(child) > 0
  end, 20)
end

T['a double-click']['on a path whose file became a FIFO since it was drawn opens nothing and says why'] = function()
  open_layout()
  fixture.write(PROJECT .. '/swap.lua', { 'a line' })
  receive_details('See swap.lua now')
  replace_with_fifo(in_project('swap.lua'))
  local fifo_was_read = keep_releasing_readers_of(in_project('swap.lua'))
  PLACES_A_CLICK_COMES_FROM['the Report in Normal mode']()

  double_click_in_report(2, 12)

  wait_until_told()
  eq(
    { fifo_read = fifo_was_read(), shown = what_the_layout_shows(), told = entry.messages(child) },
    {
      fifo_read = false,
      shown = NOTHING_OPENED,
      told = { { message = 'aineo: swap.lua names no file now', level = vim.log.levels.WARN } },
    }
  )
end

T['a double-click']['on a path whose file was removed since it was drawn opens nothing and says why'] = function()
  open_layout()
  fixture.write(PROJECT .. '/gone.lua', { 'a line' })
  receive_details('See gone.lua now')
  assert(os.remove(in_project('gone.lua')))
  PLACES_A_CLICK_COMES_FROM['the Report in Normal mode']()

  double_click_in_report(2, 12)

  wait_until_told()
  eq({ shown = what_the_layout_shows(), told = entry.messages(child) }, {
    shown = NOTHING_OPENED,
    told = { { message = 'aineo: gone.lua names no file now', level = vim.log.levels.WARN } },
  })
end

return T
