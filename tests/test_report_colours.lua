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

  eq({ spans_of('AineoReportTime'), link_of('AineoReportTime') }, { { { 0, 4, 9 } }, 'Comment' })
end

T['the icon'] = MiniTest.new_set({
  parametrize = {
    { 'started', 'AineoReportStarted', 19 },
    { 'progress', 'AineoReportProgress', 20 },
    { 'blocked', 'AineoReportBlocked', 19 },
    { 'done', 'AineoReportDone', 16 },
    { 'failed', 'AineoReportFailed', 18 },
  },
})

T['the icon']['shows in the group of its status, and the space after it in none'] = function(
  status,
  group,
  status_end_column
)
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, { task = 'Task', status = status, summary = 'Summary' })

  eq(all_colours(), {
    { 0, 0, 3, group },
    { 0, 4, 9, 'AineoReportTime' },
    { 0, 10, status_end_column, group },
  })
end

T['the status'] = MiniTest.new_set({
  parametrize = {
    { 'started', 'AineoReportStarted', 19, 'DiagnosticInfo' },
    { 'progress', 'AineoReportProgress', 20, 'DiagnosticHint' },
    { 'blocked', 'AineoReportBlocked', 19, 'DiagnosticWarn' },
    { 'done', 'AineoReportDone', 16, 'DiagnosticOk' },
    { 'failed', 'AineoReportFailed', 18, 'DiagnosticError' },
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

  eq({ spans_of(group), link_of(group) }, { { { 0, 0, 3 }, { 0, 10, end_column } }, link })
end

T['the colours'] = MiniTest.new_set()

T['the colours']['cover only the icon, the time and the status the render placed, not their like in the text'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, {
    task = '12:34 [done]',
    status = 'done',
    summary = '[failed] at 10:00',
    details = '09:05 [done]',
  })

  eq(all_colours(), {
    { 0, 0, 3, 'AineoReportDone' },
    { 0, 4, 9, 'AineoReportTime' },
    { 0, 10, 16, 'AineoReportDone' },
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
    { 0, 0, 3, 'AineoReportDone' },
    { 0, 4, 9, 'AineoReportTime' },
    { 0, 10, 16, 'AineoReportDone' },
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
    { 0, 0, 3, 'AineoReportStarted' },
    { 0, 4, 9, 'AineoReportTime' },
    { 0, 10, 19, 'AineoReportStarted' },
    { 2, 0, 3, 'AineoReportDone' },
    { 2, 4, 9, 'AineoReportTime' },
    { 2, 10, 16, 'AineoReportDone' },
  })
end

T['the records'] = MiniTest.new_set()

T['the records']['show their icon, time and status coloured when the Report opens'] = function()
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

  eq(
    { spans_of('AineoReportTime'), spans_of('AineoReportStarted'), spans_of('AineoReportDone') },
    { { { 0, 4, 9 }, { 2, 4, 9 } }, { { 0, 0, 3 }, { 0, 10, 19 } }, { { 2, 0, 3 }, { 2, 10, 16 } } }
  )
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

  eq({ link_of('AineoReportTime'), link_of('AineoReportDone') }, { 'Comment', 'DiagnosticOk' })
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

  eq(
    { spans_of('AineoReportTime'), spans_of('AineoReportStarted'), spans_of('AineoReportDone') },
    { { { 0, 4, 9 }, { 1, 4, 9 } }, { { 0, 0, 3 }, { 0, 10, 19 } }, { { 1, 0, 3 }, { 1, 10, 16 } } }
  )
end

T['the groups'] = MiniTest.new_set()

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
      }),
      #vim.api.nvim_get_autocmds({ event = 'ColorScheme' }),
    }]]),
    { { 0, 0, 0, 0, 0, 0 }, 0 }
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
