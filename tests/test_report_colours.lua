local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local report_editor = dofile('tests/helpers/report_editor.lua')

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

  eq({ spans_of('AineoReportTime'), link_of('AineoReportTime') }, { { { 0, 0, 5 } }, 'Comment' })
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

T['the colours'] = MiniTest.new_set()

T['the colours']['cover only the time and the status the render placed, not their like in the text'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, {
    task = '12:34 [done]',
    status = 'done',
    summary = '[failed] at 10:00',
    details = '09:05 [done]',
  })

  eq(all_colours(), { { 0, 0, 5, 'AineoReportTime' }, { 0, 6, 12, 'AineoReportDone' } })
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
    { 0, 6, 15, 'AineoReportStarted' },
    { 2, 0, 5, 'AineoReportTime' },
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

  eq(
    { spans_of('AineoReportTime'), spans_of('AineoReportStarted'), spans_of('AineoReportDone') },
    { { { 0, 0, 5 }, { 2, 0, 5 } }, { { 0, 6, 15 } }, { { 2, 6, 12 } } }
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

  eq(
    { spans_of('AineoReportTime'), spans_of('AineoReportStarted'), spans_of('AineoReportDone') },
    { { { 0, 0, 5 }, { 1, 0, 5 } }, { { 0, 6, 15 } }, { { 1, 6, 12 } } }
  )
end

T['the groups'] = MiniTest.new_set()

T['the groups']["keep a user's colour made before the first report"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  child.cmd('highlight AineoReportDone guifg=#ff0000')

  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  eq(child.lua_get([[vim.api.nvim_get_hl(0, { name = 'AineoReportDone' })]]), { fg = 0xff0000 })
end

T['the groups']['are not defined, nor their autocommand, until the Report shows a report'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  child.lua([[require('aineo.report').report_buffer()]])

  eq(
    child.lua_get([[{
      vim.tbl_map(vim.fn.hlexists, {
        'AineoReportTime', 'AineoReportStarted', 'AineoReportProgress',
        'AineoReportBlocked', 'AineoReportDone', 'AineoReportFailed',
      }),
      vim.fn.exists('#aineo_report_colours'),
    }]]),
    { { 0, 0, 0, 0, 0, 0 }, 0 }
  )
end

--- Puts two colour schemes on the child's 'runtimepath': `colours_done`,
--- which colours `AineoReportDone`, and `colours_none`, which colours none of
--- aineo's groups. Each clears every group first, as colour schemes do.
local function add_colour_schemes()
  fixture.write('report-colour-schemes/colors/colours_done.vim', {
    'highlight clear',
    'highlight AineoReportDone guifg=#ff0000',
    "let g:colors_name = 'colours_done'",
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
    { link = 'DiagnosticOk', default = true }
  )
end

return T
