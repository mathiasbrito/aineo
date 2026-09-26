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
    state_directory = fixture.directory('report-links-state'),
    working_directory = '/projects/alpha',
  })
end

--- The group `group` links to in the child, or nil when it links to none.
---
---@param group string
---@return string?
local function link_of(group)
  return child.lua_get(('vim.api.nvim_get_hl(0, { name = %q }).link'):format(group))
end

--- The expression, run in the child, that lists every extmark with a `url`
--- in its Report, of every namespace, as `{ line, first column, end column,
--- url, group }`, counted as the API counts them — from 0, the end column
--- excluded — in buffer order.
local REPORT_LINKS = [[(function()
  local buffer = require('aineo.report').report_buffer()
  local marks = vim.api.nvim_buf_get_extmarks(buffer, -1, 0, -1, { details = true })
  local links = {}
  for _, mark in ipairs(marks) do
    if mark[4].url ~= nil then
      table.insert(links, { mark[2], mark[3], mark[4].end_col, mark[4].url, mark[4].hl_group })
    end
  end
  return links
end)()]]

--- Every link the child's Report carries (`REPORT_LINKS`).
---
---@return any[][]
local function report_links()
  return child.lua_get(REPORT_LINKS)
end

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      child.stop()
    end,
  },
})

T['the link group'] = MiniTest.new_set()

T['the link group']['links to Underlined once the Report shows a report'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  eq(link_of('AineoReportLink'), 'Underlined')
end

T['the link group']["keeps a user's colour made before the first report"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  child.cmd('highlight AineoReportLink guifg=#ff0000')

  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  eq(child.lua_get([[vim.api.nvim_get_hl(0, { name = 'AineoReportLink' })]]), { fg = 0xff0000 })
end

T['the link group']["links to Underlined again when :highlight clear drops a user's colour made before the first report"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  child.cmd('highlight AineoReportLink guifg=#ff0000')
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  child.cmd('highlight clear')

  eq(
    child.lua_get([[vim.api.nvim_get_hl(0, { name = 'AineoReportLink' })]]),
    { link = 'Underlined' }
  )
end

T['a link'] = MiniTest.new_set()

T['a link']['in the details is drawn in AineoReportLink and carries its address'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = 'https://example.com' }
  )

  eq(report_links(), { { 1, 8, 27, 'https://example.com', 'AineoReportLink' } })
end

T['a link']['in the task or the summary is drawn at its place in the header'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(
    child,
    { task = 'See https://x.y/t now', status = 'done', summary = 'at https://x.y/s' }
  )

  eq(report_links(), {
    { 0, 21, 34, 'https://x.y/t', 'AineoReportLink' },
    { 0, 46, 59, 'https://x.y/s', 'AineoReportLink' },
  })
end

--- A link in the details of a report of 09:05 starts 8 bytes into its line,
--- after the indent that puts it under the `[status]`: each row gives the
--- details, then the links the Report shows on that line.
T['a link in the details'] = MiniTest.new_set({
  parametrize = {
    { 'https://example.com', { { 1, 8, 27, 'https://example.com', 'AineoReportLink' } } },
    {
      'See https://example.com/docs.',
      { { 1, 12, 36, 'https://example.com/docs', 'AineoReportLink' } },
    },
    { '(https://x.y/a)', { { 1, 9, 22, 'https://x.y/a', 'AineoReportLink' } } },
    {
      'https://en.wikipedia.org/wiki/Lua_(programming_language)',
      {
        {
          1,
          8,
          64,
          'https://en.wikipedia.org/wiki/Lua_(programming_language)',
          'AineoReportLink',
        },
      },
    },
    { '[docs](https://x.y/z)', { { 1, 15, 28, 'https://x.y/z', 'AineoReportLink' } } },
    {
      'http://localhost:8080/a?b=c&d=e#f',
      { { 1, 8, 41, 'http://localhost:8080/a?b=c&d=e#f', 'AineoReportLink' } },
    },
    {
      'https://x.y/a, https://x.y/b;',
      {
        { 1, 8, 21, 'https://x.y/a', 'AineoReportLink' },
        { 1, 23, 36, 'https://x.y/b', 'AineoReportLink' },
      },
    },
    { '"https://x.y/q"', { { 1, 9, 22, 'https://x.y/q', 'AineoReportLink' } } },
    { 'https://x.y/café', { { 1, 8, 25, 'https://x.y/café', 'AineoReportLink' } } },
    { 'Done: https://x.y/p! Next?', { { 1, 14, 27, 'https://x.y/p', 'AineoReportLink' } } },
    { "it's https://x.y/r'", { { 1, 13, 26, 'https://x.y/r', 'AineoReportLink' } } },
    { 'https://x.y/a—b', { { 1, 8, 25, 'https://x.y/a—b', 'AineoReportLink' } } },
    { 'See **https://x.y/docs** now', { { 1, 14, 30, 'https://x.y/docs', 'AineoReportLink' } } },
    { 'See *https://x.y/docs* now', { { 1, 13, 29, 'https://x.y/docs', 'AineoReportLink' } } },
    { 'See ~~https://x.y/a~~ now', { { 1, 14, 27, 'https://x.y/a', 'AineoReportLink' } } },
    { '(see https://x.y/a).', { { 1, 13, 26, 'https://x.y/a', 'AineoReportLink' } } },
    { '(see https://x.y/a.)', { { 1, 13, 26, 'https://x.y/a', 'AineoReportLink' } } },
    {
      'https://x.y/a,https://x.y/b',
      { { 1, 8, 35, 'https://x.y/a,https://x.y/b', 'AineoReportLink' } },
    },
    { '<https://x.y/z>', { { 1, 9, 22, 'https://x.y/z', 'AineoReportLink' } } },
    { '`https://x.y/code`', { { 1, 9, 25, 'https://x.y/code', 'AineoReportLink' } } },
    { '|https://x.y/a|b|', { { 1, 9, 22, 'https://x.y/a', 'AineoReportLink' } } },
    {
      'https://x.y/a\27\\\27]0;title\7z',
      { { 1, 8, 21, 'https://x.y/a', 'AineoReportLink' } },
    },
    { 'https://x.y/\27]52;c;cHduZWQ=\7', { { 1, 8, 20, 'https://x.y/', 'AineoReportLink' } } },
    {
      'https://x.y/a\194\157' .. '52;c;x\194\156z',
      { { 1, 8, 21, 'https://x.y/a', 'AineoReportLink' } },
    },
    { 'ftp://x.y', {} },
    { 'file:///etc/hosts', {} },
    { 'mailto:a@b.c', {} },
    { 'www.example.com', {} },
    { 'https://', {} },
    { 'See https://.', {} },
    { 'HTTPS://X.Y/A', { { 1, 8, 21, 'HTTPS://X.Y/A', 'AineoReportLink' } } },
    { 'nothttps://a.b', {} },
  },
})

T['a link in the details']['is found by the rule of web links'] = function(details, links)
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = details }
  )

  eq(report_links(), links)
end

--- Two reports, each with a link in its details, and the links the Report
--- shows for them.
local TWO_REPORTS = {
  { task = 'First', status = 'started', summary = 'Began', details = 'https://x.y/1' },
  { task = 'First', status = 'done', summary = 'Ended', details = 'https://x.y/2' },
}
local LINKS_OF_TWO_REPORTS = {
  { 1, 8, 21, 'https://x.y/1', 'AineoReportLink' },
  { 3, 8, 21, 'https://x.y/2', 'AineoReportLink' },
}

T['the links'] = MiniTest.new_set()

T['the links']['of the records show when the Report opens'] = function()
  local state_directory = fixture.directory('report-links-state')
  local environment = { state_directory = state_directory, working_directory = '/projects/alpha' }
  report_editor.start(
    child,
    vim.tbl_extend(
      'error',
      environment,
      { times = { '2026-09-24T09:05:00', '2026-09-24T09:06:00' } }
    )
  )
  report_editor.receive(child, TWO_REPORTS[1])
  report_editor.receive(child, TWO_REPORTS[2])

  report_editor.start(
    child,
    vim.tbl_extend('error', environment, { times = { '2026-09-24T10:00:00' } })
  )

  eq(report_links(), LINKS_OF_TWO_REPORTS)
end

T['the links']['show once again when the user edits the Report again'] = MiniTest.new_set({
  parametrize = { { 'edit' }, { 'edit!' } },
})

T['the links']['show once again when the user edits the Report again']['with'] = function(command)
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(child, TWO_REPORTS[1])
  report_editor.receive(child, TWO_REPORTS[2])
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])

  child.cmd(command)

  eq(report_links(), LINKS_OF_TWO_REPORTS)
end

T['the links']['show once again when the Report is made anew after the user deletes it'] =
  MiniTest.new_set({
    parametrize = { { 'bdelete' }, { 'bwipeout' }, { 'bunload' } },
  })

T['the links']['show once again when the Report is made anew after the user deletes it']['with the command'] = function(
  command
)
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(child, TWO_REPORTS[1])
  child.cmd(('%s %d'):format(command, child.lua_get([[require('aineo.report').report_buffer()]])))

  report_editor.receive(child, TWO_REPORTS[2])

  eq(report_links(), LINKS_OF_TWO_REPORTS)
end

--- The expression, run in the child, that makes `vim.ui.open` record what it
--- is given in `_G.opened` instead of opening it: no browser opens.
local RECORD_OPENED = [[
  _G.opened = {}
  vim.ui.open = function(path)
    table.insert(_G.opened, path)
    return nil, nil
  end
]]

T['gx'] = MiniTest.new_set({
  parametrize = {
    {
      'https://en.wikipedia.org/wiki/Lua_(programming_language)',
      8,
      'https://en.wikipedia.org/wiki/Lua_(programming_language)',
    },
    { 'See **https://x.y/docs** now', 14, 'https://x.y/docs' },
    { 'See *https://x.y/docs* now', 13, 'https://x.y/docs' },
    { 'See ~~https://x.y/a~~ now', 14, 'https://x.y/a' },
    { '(see https://x.y/a).', 13, 'https://x.y/a' },
  },
})

T['gx']['on a link in the Report opens exactly the link'] = function(details, column, url)
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = details }
  )
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])
  child.lua(RECORD_OPENED)
  child.api.nvim_win_set_cursor(0, { 2, column })

  child.cmd('normal gx')

  eq(child.lua_get('_G.opened'), { url })
end

return T
