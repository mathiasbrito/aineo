local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local entry_tabs = dofile('tests/helpers/entry_tabs.lua')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')
local office_child = dofile('tests/helpers/office_child.lua')
local stand_in = dofile('tests/helpers/office_stand_in.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that ends, in the child, the process of every terminal by a
--- hangup, and waits for each to end, at most 5 s each.
local END_TERMINALS = [[
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      local job = vim.b[buffer].terminal_job_id
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 5000)
    end
  end
]]

--- Stops the child, once the fake Claude Code it runs, if any, has ended by a
--- hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      entry.restart(child)
      child.o.termguicolors = true
    end,
    post_once = stop_the_child,
  },
})

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 4000

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, and waits until Claude Code is ready.
---
---@param name string the case's own name for its files, starting `office-`
---@param settings? table more of `vim.g.aineo`
local function open_layout(name, settings)
  entry_tabs.use_own_state(child, name)
  entry.use_fake(child, claude_session.fake(name, 'ready'), settings)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

--- Delivers the report `{ status, summary }` of the session the child's tab
--- runs, as the report relay does for the Claude Code with the tab's start
--- token.
---
---@param status string
---@param summary string
local function deliver_report(status, summary)
  child.lua(
    [[
      local claude = require('aineo.claude')
      require('aineo.report').receive_session_report(
        { status = ..., summary = select(2, ...), task = 'Tag the release' },
        claude.session_id(),
        { start_token = claude.start_token() }
      )
    ]],
    { status, summary }
  )
end

--- The recorded turn, whose first five lines end with a call that runs.
local RECORDED_TURN = fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')

--- Writes `lines` as the transcript of the session the child's Claude Code
--- runs, where Claude Code keeps it.
---
---@param lines string[]
local function write_transcript(lines)
  local session = child.lua_get([[require('aineo.claude').session_id()]])
  local directory = child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]])
  local path = vim.fs.joinpath(directory, 'projects', 'office-life', session .. '.jsonl')
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  fake_transcript.append(path, lines)
end

--- Whether the office shows.
---
---@return boolean
local function shows()
  return office_cells.window(child) ~= vim.NIL
end

T['the office of a tab'] = MiniTest.new_set()

T['the office of a tab']['is made as the tab opens, with the settings of the configuration'] = function()
  stand_in.install(child)

  open_layout('office-life-made', { office = { idle_ms = 9000 } })

  eq(stand_in.told(child).made, 1)
  eq(stand_in.told(child).settings.idle_ms, 9000)
end

T['the office of a tab']['counts 180000 milliseconds of idleness unless the configuration says otherwise'] = function()
  stand_in.install(child)

  open_layout('office-life-default')

  eq(stand_in.told(child).settings.idle_ms, 180000)
end

T['the office of a tab']['counts no idleness when the configuration says false'] = function()
  stand_in.install(child)

  open_layout('office-life-off', { office = { idle_ms = false } })

  eq(stand_in.told(child).settings.idle_ms, false)
end

T['the office of a tab']['is let go when the tab closes'] = function()
  stand_in.install(child)
  open_layout('office-life-closing')
  child.cmd('Aineo tab new')
  eq(stand_in.told(child).made, 2)

  child.cmd('Aineo tab close')

  eq(stand_in.told(child).let_go, 1)
end

T['the office of a tab']['shows by itself once the cursor has stayed out of the right side'] = function()
  open_layout('office-life-idle', { office = { idle_ms = 300 } })

  office_child.enter_the_left_window(child)

  eq(
    vim.wait(PATIENCE_MS, function()
      return shows()
    end, 20),
    true
  )
end

T['the office of a tab']['that shows by itself acts out what the session does, as the one shown on request does'] = function()
  open_layout('office-life-idle-follows', { office = { idle_ms = 300 } })
  write_transcript(vim.list_slice(RECORDED_TURN, 1, 5))

  office_child.enter_the_left_window(child)
  vim.wait(PATIENCE_MS, shows, 20)

  eq(
    vim.wait(PATIENCE_MS, function()
      return office_cells.is_at(child, 'file_cabinet')
    end, 20),
    true
  )
end

T['the office of a tab']['does not show by itself when the configuration says false'] = function()
  open_layout('office-life-never', { office = { idle_ms = false } })

  office_child.enter_the_left_window(child)
  vim.wait(800)

  eq(shows(), false)
end

T['the office of a tab']['loads none of the office’s engine until the office first shows'] = function()
  open_layout('office-life-lazy')

  local before =
    child.lua_get([[vim.tbl_filter(function(name) return package.loaded[name] ~= nil end, {
      'aineo.office', 'aineo.office_scene', 'aineo.office_states', 'aineo.office_pack', 'aineo.transcript',
    })]])
  entry.command(child, 'Aineo office')
  local after =
    child.lua_get([[vim.tbl_filter(function(name) return package.loaded[name] ~= nil end, {
      'aineo.office_scene', 'aineo.office_states', 'aineo.office_pack', 'aineo.transcript',
    })]])

  eq(before, { 'aineo.office' })
  eq(
    after,
    { 'aineo.office_scene', 'aineo.office_states', 'aineo.office_pack', 'aineo.transcript' }
  )
end

--- The session the child's tab runs, as `write_transcript()` names its file.
---
---@return string
local function tab_session()
  return child.lua_get([[require('aineo.claude').session_id()]])
end

--- Writes `lines` as the transcript of `session`, where Claude Code keeps it.
---
---@param session string
---@param lines string[]
local function write_transcript_of(session, lines)
  local directory = child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]])
  local path = vim.fs.joinpath(directory, 'projects', 'office-life', session .. '.jsonl')
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  fake_transcript.append(path, lines)
  return path
end

--- Tells the child's Claude home, as the hook relay does when the session
--- Claude Code runs switches to `new` (a `/resume`, say): the `SessionEnd`
--- of the session followed, then the `SessionStart` of `new`, the tab's own
--- start token with both.
---
---@param new string
local function switch_session_to(new)
  child.lua(
    [[
      local claude = require('aineo.claude')
      local left, new = ...
      claude.receive_session_event('SessionEnd', left, 'resume', claude.start_token(), 1, nil, nil)
      claude.receive_session_event('SessionStart', new, 'resume', claude.start_token(), 2, nil, nil)
    ]],
    { tab_session(), new }
  )
  vim.wait(PATIENCE_MS, function()
    return tab_session() == new
  end, 20)
end

--- Whether the main agent goes to the file cabinet, as it does for a call
--- that reads, waiting for it.
---
---@return boolean
local function goes_to_the_cabinet()
  return vim.wait(PATIENCE_MS, function()
    return office_cells.is_at(child, 'file_cabinet')
  end, 20)
end

--- A session of the form Claude Code gives that a case's tab switches to,
--- one for each case: the session a start last followed is kept for the
--- folder, and the cases share the folder's state.
---
---@param number integer the case's own number
---@return string
local function session_numbered(number)
  return ('9a1c2b3d-4e5f-4a6b-8c7d-0e1f2a3b%04d'):format(number)
end

T['a switch of the tab’s session'] = MiniTest.new_set()

T['a switch of the tab’s session']['has the office that shows act out the new session’s transcript'] = function()
  local switched_to = session_numbered(1)
  open_layout('office-life-switch')
  write_transcript_of(tab_session(), vim.list_slice(RECORDED_TURN, 6, 10))
  write_transcript_of(switched_to, vim.list_slice(RECORDED_TURN, 1, 5))
  entry.command(child, 'Aineo office')
  eq(office_cells.is_on_the_sofa(child), true)

  switch_session_to(switched_to)

  eq(goes_to_the_cabinet(), true)
end

T['a switch of the tab’s session']['has the office that is hidden follow the new session’s transcript when it shows'] = function()
  local switched_to = session_numbered(2)
  open_layout('office-life-switch-hidden')
  write_transcript_of(tab_session(), vim.list_slice(RECORDED_TURN, 6, 10))
  write_transcript_of(switched_to, vim.list_slice(RECORDED_TURN, 1, 5))

  switch_session_to(switched_to)
  entry.command(child, 'Aineo office')

  eq(goes_to_the_cabinet(), true)
end

T['a switch of the tab’s session']['has the office follow the transcript a hook names for the new session afterwards'] = function()
  local switched_to = session_numbered(3)
  open_layout('office-life-switch-hook')
  local named = write_transcript_of('named-elsewhere', vim.list_slice(RECORDED_TURN, 1, 5))
  entry.command(child, 'Aineo office')
  switch_session_to(switched_to)

  child.lua(
    [[
      local claude = require('aineo.claude')
      claude.receive_session_event('SessionStart', ..., 'resume', claude.start_token(), nil, nil, select(2, ...))
    ]],
    { switched_to, named }
  )

  eq(goes_to_the_cabinet(), true)
end

T['a report'] = MiniTest.new_set()

T['a report']['reaches the office of the tab whose Report took it'] = function()
  stand_in.install(child)
  open_layout('office-life-report')

  deliver_report('done', 'tagged')

  eq(
    stand_in.told(child).reports,
    { { status = 'done', summary = 'tagged', task = 'Tag the release' } }
  )
end

T['a report']['reaches no office when the Report does not take it'] = function()
  stand_in.install(child)
  open_layout('office-life-report-untaken')

  child.lua([[require('aineo.report').receive_session_report(
    { status = 'done', summary = 'tagged', task = 'Tag the release' },
    'c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31',
    { start_token = 'no-such-token' }
  )]])

  eq(stand_in.told(child).reports, {})
end

T['a report']['draws a card in the office that shows, which stays open'] = function()
  open_layout('office-life-card')
  office_child.enter_the_left_window(child)
  entry.command(child, 'Aineo office')

  deliver_report('blocked', 'needs a decision')

  eq(
    vim.wait(PATIENCE_MS, function()
      return child
        .lua_get(
          [[table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(...), 0, -1, false), '\n')]],
          { office_cells.window(child) }
        )
        :find('blocked · needs a decision', 1, true) ~= nil
    end, 20),
    true
  )
  eq(shows(), true)
end

return T
