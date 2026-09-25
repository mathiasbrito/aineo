local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- How long the test waits for a report to travel from the fake `claude`,
--- through the relay it starts, into the Report.
local REPORT_PATIENCE_MS = 10000

--- The expression, run in the child, that gives the Report's lines, each
--- time of day written `HH:MM`.
local REPORT_LINES = [[vim.tbl_map(function(line)
  return (line:gsub('^%d%d:%d%d ', 'HH:MM '))
end, vim.api.nvim_buf_get_lines(vim.fn.bufnr('aineo://report'), 0, -1, true))]]

local child = MiniTest.new_child_neovim()

--- Waits, at most `REPORT_PATIENCE_MS`, until the child's Report shows the
--- report the fake sends.
local function wait_for_report()
  vim.wait(REPORT_PATIENCE_MS, function()
    return table.concat(child.lua_get(REPORT_LINES), '\n'):find('Refactor the parser', 1, true)
      ~= nil
  end, 50)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      entry.restart(child)
    end,
    post_once = child.stop,
  },
})

T['the report tool'] = MiniTest.new_set()

T['the report tool']['called by Claude shows its report in the Report'] = function()
  child.lua('vim.env.XDG_STATE_HOME = ...', { fixture.directory('entry-report-state') })
  local fake = claude_session.fake('entry-report', 'mcp-client')
  entry.use_fake(child, fake)

  child.cmd('Aineo open')

  wait_for_report()
  eq(child.lua_get(REPORT_LINES), { 'HH:MM [done] Refactor the parser — All tests pass' })
end

T['the report tool']["stamps Claude's report with the editor's local time"] = function()
  child.lua('vim.env.XDG_STATE_HOME = ...', { fixture.directory('entry-report-time-state') })
  child.lua([[
    local real_date = os.date
    os.date = function(format, ...)
      if format == '%Y-%m-%dT%H:%M:%S' then
        return '2026-09-25T09:05:00'
      end
      return real_date(format, ...)
    end
  ]])
  local fake = claude_session.fake('entry-report-time', 'mcp-client')
  entry.use_fake(child, fake)

  child.cmd('Aineo open')

  wait_for_report()
  eq(
    child.lua_get("vim.api.nvim_buf_get_lines(vim.fn.bufnr('aineo://report'), 0, -1, true)"),
    { '09:05 [done] Refactor the parser — All tests pass' }
  )
end

T['the report tool']["keeps Claude's report under the editor's state directory, for its working directory"] = function()
  local state = fixture.directory('entry-report-kept-state')
  child.lua('vim.env.XDG_STATE_HOME = ...', { state })
  local fake = claude_session.fake('entry-report-kept', 'mcp-client')
  entry.use_fake(child, fake)

  child.cmd('Aineo open')

  wait_for_report()
  eq(vim.fn.glob(vim.fs.joinpath(state, '**', '*.jsonl'), true, true), {
    vim.fs.joinpath(
      state,
      'nvim',
      'aineo',
      'reports',
      vim.fn.sha256(child.fn.getcwd()) .. '.jsonl'
    ),
  })
end

T['the report tool']["keeps Claude's report for the working directory of the first Open, after a :cd"] = function()
  local state = fixture.directory('entry-report-first-cwd-state')
  child.lua('vim.env.XDG_STATE_HOME = ...', { state })
  local first_fake = claude_session.fake('entry-report-first-cwd-exit', 'exit')
  entry.use_fake(child, first_fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'exited')
  local first_directory = child.fn.getcwd()
  child.fn.chdir(fixture.directory('entry-report-first-cwd-later'))
  entry.use_fake(child, claude_session.fake('entry-report-first-cwd', 'mcp-client'))

  child.cmd('Aineo open')

  wait_for_report()
  eq(vim.fn.glob(vim.fs.joinpath(state, '**', '*.jsonl'), true, true), {
    vim.fs.joinpath(state, 'nvim', 'aineo', 'reports', vim.fn.sha256(first_directory) .. '.jsonl'),
  })
end

return T
