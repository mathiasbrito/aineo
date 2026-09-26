local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local report_editor = dofile('tests/helpers/report_editor.lua')
local children = dofile('tests/helpers/child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- Starts the child's report home with the clock at `times`, a fresh state
--- directory and the working directory `/projects/alpha`.
---
---@param times string[]
local function start_editor(times)
  report_editor.start(child, {
    times = times,
    state_directory = fixture.directory('report-colours-state'),
    working_directory = '/projects/alpha',
  })
end

--- The expression, run in the child, that lists every colour its Report
--- shows as `{ line, first column, end column, group }`, counted as the API
--- counts them — from 0, the end column excluded — in buffer order.
local REPORT_COLOURS = [[(function()
  local buffer = require('aineo.report').report_buffer()
  local marks = vim.api.nvim_buf_get_extmarks(buffer, -1, 0, -1, { details = true })
  return vim.tbl_map(function(mark)
    return { mark[2], mark[3], mark[4].end_col, mark[4].hl_group }
  end, marks)
end)()]]

--- Every colour the child's Report shows (`REPORT_COLOURS`).
---
---@return any[][]
local function all_colours()
  return child.lua_get(REPORT_COLOURS)
end

--- Where the child's Report shows `group`: each span as `{ line, first
--- column, end column }`, counted as `all_colours()` counts them.
---
---@param group string
---@return integer[][]
local function spans_of(group)
  local spans = {}
  for _, colour in ipairs(all_colours()) do
    if colour[4] == group then
      table.insert(spans, { colour[1], colour[2], colour[3] })
    end
  end
  return spans
end

--- The group `group` links to in the child, or nil when it links to none.
---
---@param group string
---@return string?
local function link_of(group)
  return child.lua_get(('vim.api.nvim_get_hl(0, { name = %q }).link'):format(group))
end

--- The foreground `group` gives the child's text, as RGB, the links it
--- follows resolved.
---
---@param group string
---@return integer?
local function foreground_of(group)
  return child.lua_get(('vim.api.nvim_get_hl(0, { name = %q, link = false }).fg'):format(group))
end

--- The expression, run in the child, that reads the cell of its screen at
--- the row and column it is given, as `{ foreground, bold }`: the RGB
--- foreground, and whether it is bold.
local SCREEN_CELL = [[(function(row, column)
  local attributes = vim.api.nvim__inspect_cell(1, row, column)[2]
  return { foreground = attributes.foreground, bold = attributes.bold == true }
end)(...)]]

--- Shows the child's Report in its only window, from its first line, and
--- reads on the screen the `[` and the `]` of the `[status]` of its first
--- report, a `[status]` ending before `end_column`: each as `SCREEN_CELL`
--- reads it. A child's first `nvim__inspect_cell()` misreads every cell read
--- in the same request, and cells read after the next redraw are right, so
--- one read is made and dropped, and the screen redrawn, first.
---
---@param end_column integer the byte the `[status]` ends before, from 0
---@return { foreground: integer?, bold: boolean }[]
local function first_status_on_screen(end_column)
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])
  child.lua([[vim.api.nvim__inspect_cell(1, 0, 0)]])
  child.cmd('redraw')
  return {
    child.lua_get(SCREEN_CELL, { 0, 6 }),
    child.lua_get(SCREEN_CELL, { 0, end_column - 1 }),
  }
end

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      child.stop()
    end,
  },
})

T['the time'] = MiniTest.new_set()

T['the time']['shows in AineoReportTime, which links to Comment'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  eq({ spans_of('AineoReportTime'), link_of('AineoReportTime') }, { { { 0, 0, 5 } }, 'Comment' })
end

T['the header'] = MiniTest.new_set({
  parametrize = {
    { 'started', 'AineoReportStarted', 15 },
    { 'progress', 'AineoReportProgress', 16 },
    { 'blocked', 'AineoReportBlocked', 15 },
    { 'done', 'AineoReportDone', 12 },
    { 'failed', 'AineoReportFailed', 14 },
  },
})

T['the header']['colours its time and its status, the status bold beneath its colour, and no icon nor the space between them'] = function(
  status,
  group,
  status_end_column
)
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, { task = 'Task', status = status, summary = 'Summary' })

  eq(all_colours(), {
    { 0, 0, 5, 'AineoReportTime' },
    { 0, 6, status_end_column, 'AineoReportStatusBold' },
    { 0, 6, status_end_column, group },
  })
end

T['the status'] = MiniTest.new_set({
  parametrize = {
    { 'started', 'AineoReportStarted', 15, 'DiagnosticInfo' },
    { 'progress', 'AineoReportProgress', 16, 'DiagnosticHint' },
    { 'blocked', 'AineoReportBlocked', 15, 'DiagnosticWarn' },
    { 'done', 'AineoReportDone', 12, 'DiagnosticOk' },
    { 'failed', 'AineoReportFailed', 14, 'DiagnosticError' },
  },
})

T['the status']['shows, brackets included, in the group of its status, linked to its default'] = function(
  status,
  group,
  end_column,
  link
)
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, { task = 'Task', status = status, summary = 'Summary' })

  eq({ spans_of(group), link_of(group) }, { { { 0, 6, end_column } }, link })
end

T['the status']['shows, brackets included, in AineoReportStatusBold as well, linked to @markup.strong'] = function(
  status,
  _,
  end_column
)
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, { task = 'Task', status = status, summary = 'Summary' })

  eq(
    { spans_of('AineoReportStatusBold'), link_of('AineoReportStatusBold') },
    { { { 0, 6, end_column } }, '@markup.strong' }
  )
end

T['the status']['shows bold on the screen, brackets included, in the colour of its status'] = function(
  status,
  _,
  end_column,
  link
)
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, { task = 'Task', status = status, summary = 'Summary' })

  eq(first_status_on_screen(end_column), {
    { foreground = foreground_of(link), bold = true },
    { foreground = foreground_of(link), bold = true },
  })
end

T['the status']['keeps the colour of its status, bold, when a colour scheme colours @markup.strong'] = function(
  status,
  _,
  end_column,
  link
)
  start_editor({ '2026-09-24T09:05:00' })
  child.cmd('highlight @markup.strong guifg=#ff00ff')

  report_editor.receive(child, { task = 'Task', status = status, summary = 'Summary' })

  eq(first_status_on_screen(end_column), {
    { foreground = foreground_of(link), bold = true },
    { foreground = foreground_of(link), bold = true },
  })
end

T['the colours'] = MiniTest.new_set()

T['the colours']['cover the time and the status only where the render placed them, not their like in the text'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, {
    task = '12:34 [done]',
    status = 'done',
    summary = '[failed] at 10:00',
    details = '09:05 [done]',
  })

  eq(all_colours(), {
    { 0, 0, 5, 'AineoReportTime' },
    { 0, 6, 12, 'AineoReportStatusBold' },
    { 0, 6, 12, 'AineoReportDone' },
  })
end

T['the colours']['cover no icon in the text'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, {
    task = '✓ Task',
    status = 'done',
    summary = 'Summary ✓',
    details = '✓ Detail',
  })

  eq(all_colours(), {
    { 0, 0, 5, 'AineoReportTime' },
    { 0, 6, 12, 'AineoReportStatusBold' },
    { 0, 6, 12, 'AineoReportDone' },
  })
end

T['the colours']['of a report that follows another are on its own header'] = function()
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(
    child,
    { task = 'First', status = 'started', summary = 'Began', details = 'One detail' }
  )

  report_editor.receive(child, { task = 'First', status = 'done', summary = 'Ended' })

  eq(all_colours(), {
    { 0, 0, 5, 'AineoReportTime' },
    { 0, 6, 15, 'AineoReportStatusBold' },
    { 0, 6, 15, 'AineoReportStarted' },
    { 2, 0, 5, 'AineoReportTime' },
    { 2, 6, 12, 'AineoReportStatusBold' },
    { 2, 6, 12, 'AineoReportDone' },
  })
end

T['the records'] = MiniTest.new_set()

T['the records']['show their time and status coloured when the Report opens'] = function()
  local state_directory = fixture.directory('report-colours-state')
  local environment = { state_directory = state_directory, working_directory = '/projects/alpha' }
  report_editor.start(
    child,
    vim.tbl_extend(
      'error',
      environment,
      { times = { '2026-09-24T09:05:00', '2026-09-24T09:06:00' } }
    )
  )
  report_editor.receive(
    child,
    { task = 'First', status = 'started', summary = 'Began', details = 'One detail' }
  )
  report_editor.receive(child, { task = 'First', status = 'done', summary = 'Ended' })

  report_editor.start(
    child,
    vim.tbl_extend('error', environment, { times = { '2026-09-24T10:00:00' } })
  )

  eq({
    spans_of('AineoReportTime'),
    spans_of('AineoReportStarted'),
    spans_of('AineoReportDone'),
    spans_of('AineoReportStatusBold'),
  }, {
    { { 0, 0, 5 }, { 2, 0, 5 } },
    { { 0, 6, 15 } },
    { { 2, 6, 12 } },
    { { 0, 6, 15 }, { 2, 6, 12 } },
  })
end

T['the records']['show in groups linked to their defaults when the Report opens'] = function()
  local state_directory = fixture.directory('report-colours-state')
  local environment = { state_directory = state_directory, working_directory = '/projects/alpha' }
  report_editor.start(
    child,
    vim.tbl_extend('error', environment, { times = { '2026-09-24T09:05:00' } })
  )
  report_editor.receive(child, { task = 'First', status = 'done', summary = 'Ended' })
  report_editor.start(
    child,
    vim.tbl_extend('error', environment, { times = { '2026-09-24T10:00:00' } })
  )

  child.lua([[require('aineo.report').report_buffer()]])

  eq(
    { link_of('AineoReportTime'), link_of('AineoReportDone'), link_of('AineoReportStatusBold') },
    { 'Comment', 'DiagnosticOk', '@markup.strong' }
  )
end

T['the records']['show their colours once again when the user edits the Report again'] =
  MiniTest.new_set({
    parametrize = { { 'edit' }, { 'edit!' } },
  })

T['the records']['show their colours once again when the user edits the Report again']['with'] = function(
  command
)
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(child, { task = 'First', status = 'started', summary = 'Began' })
  report_editor.receive(child, { task = 'First', status = 'done', summary = 'Ended' })
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])

  child.cmd(command)

  eq({
    spans_of('AineoReportTime'),
    spans_of('AineoReportStarted'),
    spans_of('AineoReportDone'),
    spans_of('AineoReportStatusBold'),
  }, {
    { { 0, 0, 5 }, { 1, 0, 5 } },
    { { 0, 6, 15 } },
    { { 1, 6, 12 } },
    { { 0, 6, 15 }, { 1, 6, 12 } },
  })
end

T['the records']['show their colours once again when the Report is made anew after the user deletes it'] =
  MiniTest.new_set({
    parametrize = { { 'bdelete' }, { 'bwipeout' }, { 'bunload' } },
  })

T['the records']['show their colours once again when the Report is made anew after the user deletes it']['with the command'] = function(
  command
)
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(child, { task = 'First', status = 'started', summary = 'Began' })
  child.cmd(('%s %d'):format(command, child.lua_get([[require('aineo.report').report_buffer()]])))

  report_editor.receive(child, { task = 'First', status = 'done', summary = 'Ended' })

  eq({
    spans_of('AineoReportTime'),
    spans_of('AineoReportStarted'),
    spans_of('AineoReportDone'),
    spans_of('AineoReportStatusBold'),
  }, {
    { { 0, 0, 5 }, { 1, 0, 5 } },
    { { 0, 6, 15 } },
    { { 1, 6, 12 } },
    { { 0, 6, 15 }, { 1, 6, 12 } },
  })
end

T['the groups'] = MiniTest.new_set()

T['the groups']["show a user's colour for a status made before the first report on its [status], bold"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  child.cmd('highlight AineoReportDone guifg=#ff0000')

  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  eq(first_status_on_screen(12), {
    { foreground = 0xff0000, bold = true },
    { foreground = 0xff0000, bold = true },
  })
end

T['the groups']["show a user's colour for a status made after a report on its [status], bold"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  child.cmd('highlight AineoReportDone guifg=#ff0000')

  eq(first_status_on_screen(12), {
    { foreground = 0xff0000, bold = true },
    { foreground = 0xff0000, bold = true },
  })
end

T['the groups']["show a [status] bold, in its status's default colour, once :highlight clear drops a user's colour"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  child.cmd('highlight AineoReportDone guifg=#ff0000')
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  child.cmd('highlight clear')

  eq(first_status_on_screen(12), {
    { foreground = foreground_of('DiagnosticOk'), bold = true },
    { foreground = foreground_of('DiagnosticOk'), bold = true },
  })
end

T['the groups']["let the user turn a [status]'s bold off, its colour kept, through the next report"] =
  MiniTest.new_set({
    parametrize = {
      { 'highlight AineoReportStatusBold gui=NONE cterm=NONE' },
      { 'highlight link AineoReportStatusBold NONE' },
    },
  })

T['the groups']["let the user turn a [status]'s bold off, its colour kept, through the next report"]['with'] = function(
  command
)
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })
  child.cmd(command)

  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  eq(first_status_on_screen(12), {
    { foreground = foreground_of('DiagnosticOk'), bold = false },
    { foreground = foreground_of('DiagnosticOk'), bold = false },
  })
end

T['the groups']["keep a user's colour made before the first report"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  child.cmd('highlight AineoReportDone guifg=#ff0000')

  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  eq(child.lua_get([[vim.api.nvim_get_hl(0, { name = 'AineoReportDone' })]]), { fg = 0xff0000 })
end

T['the groups']["link to their defaults again when :highlight clear drops a user's colour made before the first report"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  child.cmd('highlight AineoReportDone guifg=#ff0000')
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  child.cmd('highlight clear')

  eq(
    child.lua_get([[vim.api.nvim_get_hl(0, { name = 'AineoReportDone' })]]),
    { link = 'DiagnosticOk' }
  )
end

T['the groups']['are not defined, nor any ColorScheme autocommand, until the Report shows a report'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  child.lua([[require('aineo.report').report_buffer()]])

  eq(
    child.lua_get([[{
      vim.tbl_map(vim.fn.hlexists, {
        'AineoReportTime', 'AineoReportStarted', 'AineoReportProgress',
        'AineoReportBlocked', 'AineoReportDone', 'AineoReportFailed',
        'AineoReportStatusBold',
      }),
      #vim.api.nvim_get_autocmds({ event = 'ColorScheme' }),
    }]]),
    { { 0, 0, 0, 0, 0, 0, 0 }, 0 }
  )
end

T['the groups']['need no ColorScheme autocommand, however many reports came'] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  eq(child.lua_get([[#vim.api.nvim_get_autocmds({ event = 'ColorScheme' })]]), 0)
end

--- The expression, run in the child, that counts its autocommands that are
--- not local to a buffer, of every event.
local GLOBAL_AUTOCOMMANDS = [[#vim.tbl_filter(function(autocommand)
  return not autocommand.buflocal
end, vim.api.nvim_get_autocmds({}))]]

T['the groups']['add no autocommand of any event until the Report shows a report'] = function()
  children.restart(child)
  local without_the_report_home = child.lua_get(GLOBAL_AUTOCOMMANDS)
  start_editor({ '2026-09-24T09:05:00' })

  child.lua([[require('aineo.report').report_buffer()]])

  eq(child.lua_get(GLOBAL_AUTOCOMMANDS), without_the_report_home)
end

T['the groups']['add no autocommand of any event as more reports come'] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })
  local after_one = child.lua_get([[#vim.api.nvim_get_autocmds({})]])

  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  eq(child.lua_get([[#vim.api.nvim_get_autocmds({})]]), after_one)
end

--- Puts three colour schemes on the child's 'runtimepath': `colours_done`,
--- which colours `AineoReportDone`, `colours_done_linked`, which gives it a
--- default link of its own to `Title`, and `colours_none`, which colours none
--- of aineo's groups. Each clears every group first, as colour schemes do.
local function add_colour_schemes()
  fixture.write('report-colour-schemes/colors/colours_done.vim', {
    'highlight clear',
    'highlight AineoReportDone guifg=#ff0000',
    "let g:colors_name = 'colours_done'",
  })
  fixture.write('report-colour-schemes/colors/colours_done_linked.vim', {
    'highlight clear',
    'highlight default link AineoReportDone Title',
    "let g:colors_name = 'colours_done_linked'",
  })
  local schemes_file = fixture.write('report-colour-schemes/colors/colours_none.vim', {
    'highlight clear',
    "let g:colors_name = 'colours_none'",
  })
  local schemes_directory = vim.fn.fnamemodify(schemes_file, ':h:h')
  child.lua('vim.opt.runtimepath:prepend(...)', { schemes_directory })
end

T['the groups']['link to their defaults again when a colour scheme that colours none of them follows one that did'] = function()
  start_editor({ '2026-09-24T09:05:00' })
  add_colour_schemes()
  child.cmd('colorscheme colours_done')
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  child.cmd('colorscheme colours_none')

  eq(
    child.lua_get([[vim.api.nvim_get_hl(0, { name = 'AineoReportDone' })]]),
    { link = 'DiagnosticOk' }
  )
end

T['the groups']["go back to a colour scheme's default link made before the first report whenever :highlight clear runs"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  add_colour_schemes()
  child.cmd('colorscheme colours_done_linked')
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  child.cmd('colorscheme colours_none')
  local after_the_colour_scheme = link_of('AineoReportDone')
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })
  local after_the_next_report = link_of('AineoReportDone')
  child.cmd('highlight clear')

  eq(
    { after_the_colour_scheme, after_the_next_report, link_of('AineoReportDone') },
    { 'Title', 'DiagnosticOk', 'Title' }
  )
end

return T
