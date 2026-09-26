local MiniTest = require('mini.test')
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
  fixture.write(PROJECT .. '/lua/x.lua:https:/x.y/a', { 'a line' })
  for _, name in ipairs({ 'Makefile', 'README.md', '.gitignore', '.luarc.json' }) do
    fixture.write(PROJECT .. '/' .. name, { 'a line' })
  end
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

return T
