local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')
local projects = dofile('tests/helpers/projects_session.lua')
local walkthrough_session = dofile('tests/helpers/walkthrough_session.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_once = projects.use_isolated_git,
    pre_case = function()
      projects.stop(child)
      entry.restart(child)
    end,
    post_once = function()
      projects.stop(child)
    end,
  },
})

local CHOSEN = '%#AineoChangesProjectChosen#'
local OTHER = '%#AineoChangesProject#'
local TWO_TABS = CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-api 0 %*'
local CODE = { 'local a = 1', 'local b = 2', 'local c = 3', 'return a' }

--- Opens aineo in the repository `aineo` of the group `name`, with the
--- repository `notes-api` beside it, which holds `src/code.lua`; makes
--- `notes-api` join by an edit when `joined`.
---
---@param name string
---@param joined boolean
---@return { main: string, other: string, transcript: string, session: string, token: string, state_home: string }
local function open(name, joined)
  local state_home = fixture.directory(name .. '-state')
  child.lua('vim.env.XDG_STATE_HOME = ...', { state_home })
  local main = projects.repository(name, 'aineo', { ['a.txt'] = { 'one' } })
  local other = projects.repository(name, 'notes-api', { ['src/code.lua'] = CODE })
  local fake, session = projects.open_in(child, name, main, { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  local transcript = projects.name_transcript(child, session)
  projects.show_changes_pane(child)
  if joined then
    projects.edit(transcript, vim.fs.joinpath(other, 'src/code.lua'))
    projects.wait_until('notes-api has its tab', function()
      return projects.tab_line(child) == TWO_TABS
    end)
  end
  return {
    main = main,
    other = other,
    transcript = transcript,
    session = session,
    token = claude_session.start_token(fake, 1),
    state_home = state_home,
    fake = fake,
  }
end

--- Ends the child and starts it again in the same state directory and the
--- same folder, as an editor the user closed and opened, and opens aineo
--- there; returns the session it follows.
---
---@param here { main: string, state_home: string }
---@param name string the second editor's own name for the fake's files
---@return string session
local function open_again(here, name)
  projects.stop(child)
  entry.restart(child)
  child.lua('vim.env.XDG_STATE_HOME = ...', { here.state_home })
  local _, session = projects.open_in(child, name, here.main, { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  projects.name_transcript(child, session)
  projects.show_changes_pane(child)
  return session
end

--- Waits until the line of tabs is `expected`, then asserts it is.
---
---@param expected string
local function expect_tab_line(expected)
  vim.wait(projects.PATIENCE_MS, function()
    return projects.tab_line(child) == expected
  end, 20)
  eq(projects.tab_line(child), expected)
end

--- The messages the child told the user, as their text.
---
---@return string[]
local function told()
  return vim.tbl_map(function(each)
    return each.message
  end, entry.messages(child))
end

--- Whether any message the child told contains `part`.
---
---@param part string
---@return boolean
local function was_told(part)
  return vim.iter(told()):any(function(message)
    return message ~= nil and message:find(part, 1, true) ~= nil
  end)
end

--- The number of valid buffers the child has whose names hold `part`.
---
---@param part string
---@return integer
local function buffers_named(part)
  return child.lua_get(
    [[(function(part)
      return #vim.tbl_filter(function(buffer)
        return vim.api.nvim_buf_get_name(buffer):find(part, 1, true) ~= nil
      end, vim.api.nvim_list_bufs())
    end)(...)]],
    { part }
  )
end

--- The session the child's Claude home follows.
---
---@return string
local function followed_session()
  return child.lua_get([[require('aineo.claude').session_id()]])
end

--- Moves the child's Claude Code from the session `from` to `to` as a fork
--- does: a `SessionEnd` of `from` and a `SessionStart` of `to` with the source
--- `fork`, run as the fake's hooks; waits until the tab follows `to`.
---
---@param fake table
---@param from string
---@param to string
local function fork_the_session(fake, from, to)
  claude_session.run_session_hook(
    child,
    fake,
    1,
    'SessionEnd',
    claude_session.hook_input('SessionEnd', from, 'resume')
  )
  claude_session.run_session_hook(
    child,
    fake,
    1,
    'SessionStart',
    claude_session.hook_input('SessionStart', to, 'fork')
  )
  vim.wait(projects.PATIENCE_MS, function()
    return followed_session() == to
  end, 20)
end

--- Types `/clear` in the child's running Claude Code and waits until the
--- tab follows another session than before; returns it.
---
---@return string session
local function clear_the_session()
  local before = followed_session()
  local terminal = child.lua_get([[vim.iter(vim.api.nvim_list_bufs()):find(function(buffer)
    return vim.bo[buffer].buftype == 'terminal'
      and vim.fn.jobwait({ vim.b[buffer].terminal_job_id }, 0)[1] == -1
  end)]])
  claude_session.press_keys(child, terminal, '/clear\r')
  vim.wait(projects.PATIENCE_MS, function()
    return followed_session() ~= before
  end, 20)
  return followed_session()
end

--- Offers the child a call of the walkthrough tool for `file`, as the relay
--- of the Claude Code with `token` does.
---
---@param token string
---@param file string
---@return table
local function step_for(token, file)
  return walkthrough_session.offer(child, 'receive_walkthrough_step', token, {
    file = file,
    title = 'The values',
    step = 1,
    total = 2,
    ranges = { { start = 2, ['end'] = 3, text = 'Two values.' } },
  })
end

--- Offers the child a walkthrough plan with one step, `file`.
---
---@param token string
---@param file string
---@return table
local function plan_for(token, file)
  return walkthrough_session.offer(child, 'receive_walkthrough_plan', token, {
    title = 'The values',
    summary = 'How the values are defined.',
    covers = { 'Defining the values' },
    steps = { { title = 'The definitions', file = file, introduces = { 'value' } } },
  })
end

T['closing a project'] = MiniTest.new_set()

T['closing a project']['with X drops its tab and shows the session’s project'] = function()
  open('projects-session-close', true)
  projects.enter_commits_window(child)
  child.type_keys('<Tab>')
  expect_tab_line(CHOSEN and (OTHER .. ' aineo 0 %* ' .. CHOSEN .. ' notes-api 0 %*'))

  child.type_keys('X')

  expect_tab_line('')
  eq(vim.tbl_contains(projects.shown_buffer_names(child), 'aineo://changes-commits'), true)
end

T['closing a project']['wipes the buffers of its pane'] = function()
  open('projects-session-wipe', true)
  eq(buffers_named('aineo://copy'), 2)
  projects.enter_commits_window(child)
  child.type_keys('<Tab>')

  child.type_keys('X')

  projects.wait_until('the project’s buffers are gone', function()
    return buffers_named('aineo://copy') == 0
  end)
end

T['closing a project']['with X works from the files window too'] = function()
  open('projects-session-close-files', true)
  projects.enter_commits_window(child)
  child.type_keys('<Tab>')
  projects.enter_files_window(child)

  child.type_keys('X')

  expect_tab_line('')
end

T['closing a project']['does not close the session’s own, and says so'] = function()
  open('projects-session-keep-own', true)
  projects.enter_commits_window(child)

  child.type_keys('X')

  eq(projects.tab_line(child), TWO_TABS)
  projects.wait_until('the user was told', function()
    return was_told("the session's own project stays")
  end)
end

T['closing a project']['lets the project join again, its base the commit then'] = function()
  local here = open('projects-session-rejoin', true)
  projects.enter_commits_window(child)
  child.type_keys('<Tab>X')
  expect_tab_line('')
  git_repo.write(here.other, 'later.txt', { 'later' })
  local later = git_repo.commit_all(here.other, 'Later')

  projects.edit(here.transcript, vim.fs.joinpath(here.other, 'src/code.lua'))
  expect_tab_line(TWO_TABS)
  child.type_keys('<Tab>')

  projects.wait_until('the project’s base is the commit made while it was closed', function()
    return (projects.files_lines(child)[2] or ''):find(later:sub(1, 7), 1, true) ~= nil
  end)
end

T['closing a project']['is kept: a project closed does not come back when the session is resumed'] = function()
  local here = open('projects-session-close-kept', true)
  projects.enter_commits_window(child)
  child.type_keys('<Tab>X')
  expect_tab_line('')

  local resumed = open_again(here, 'projects-session-close-kept-again')

  eq(resumed, here.session)
  vim.wait(projects.QUIET_MS)
  eq(projects.tab_line(child), '')
end

T['a project joined by an edit'] = MiniTest.new_set()

T['a project joined by an edit']['tells the user, naming the key of the changes pane'] = function()
  open('projects-session-notice', true)

  eq(was_told("aineo: Claude Code changed notes-api; it's now a tab in \\g"), true)
end

T['a project joined by an edit']['leaves the view and the cursor of the project shown'] = function()
  local here = open('projects-session-view', false)
  projects.wait_until('the pane lists the session', function()
    return vim.tbl_contains(projects.commits_lines(child), 'No commits on this session')
  end)
  projects.enter_commits_window(child)
  local before =
    child.lua_get([[{ vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0) }]])

  projects.edit(here.transcript, vim.fs.joinpath(here.other, 'src/code.lua'))
  expect_tab_line(TWO_TABS)

  eq(child.lua_get([[{ vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0) }]]), before)
end

T['a project joined by an edit']['does not tell the user again for more edits of it'] = function()
  local here = open('projects-session-notice-once', true)

  projects.edit(here.transcript, vim.fs.joinpath(here.other, 'src/code.lua'))
  vim.wait(projects.QUIET_MS)

  eq(#vim.tbl_filter(function(message)
    return message ~= nil and message:find('Claude Code changed notes-api', 1, true) ~= nil
  end, told()), 1)
end

T['the walkthrough'] = MiniTest.new_set()

T['the walkthrough']['refuses a step in a repository that is no project of the tab'] = function()
  local here = open('projects-session-step-refused', false)

  local answer = step_for(here.token, vim.fs.joinpath(here.other, 'src/code.lua'))

  eq(answer.is_error, true)
end

T['the walkthrough']['shows a step in a project of the tab'] = function()
  local here = open('projects-session-step', true)

  local answer = step_for(here.token, vim.fs.joinpath(here.other, 'src/code.lua'))

  eq(answer.is_error, false)
end

T['the walkthrough']['takes a plan whose file is in a project of the tab'] = function()
  local here = open('projects-session-plan', true)

  local answer = plan_for(here.token, vim.fs.joinpath(here.other, 'src/code.lua'))

  eq(answer.is_error, false)
end

T['the walkthrough']['refuses a plan whose file is in a repository that is no project of the tab'] = function()
  local here = open('projects-session-plan-refused', false)

  local answer = plan_for(here.token, vim.fs.joinpath(here.other, 'src/code.lua'))

  eq(answer.is_error, true)
end

T['the walkthrough']['refuses a step in a project once it is closed'] = function()
  local here = open('projects-session-step-closed', true)
  projects.enter_commits_window(child)
  child.type_keys('<Tab>X')
  expect_tab_line('')

  local answer = step_for(here.token, vim.fs.joinpath(here.other, 'src/code.lua'))

  eq(answer.is_error, true)
end

T['the cap'] = MiniTest.new_set()

T['the cap']['takes no more than eight projects, and tells the user once'] = function()
  local main = projects.repository('projects-session-cap', 'p1', { ['f.txt'] = { 'one' } })
  local _, session = projects.open_in(child, 'projects-session-cap', main)
  local transcript = projects.name_transcript(child, session)
  projects.show_changes_pane(child)
  for number = 2, 10 do
    local top =
      projects.repository('projects-session-cap', 'p' .. number, { ['f.txt'] = { 'one' } })
    projects.edit(transcript, vim.fs.joinpath(top, 'f.txt'))
  end

  projects.wait_until('the user was told the tab is full', function()
    return was_told('holds 8 projects already')
  end)

  eq(#vim.tbl_filter(function(message)
    return message ~= nil and message:find('holds 8 projects already', 1, true) ~= nil
  end, told()), 1)
  local line = projects.tab_line(child)
  eq(select(2, line:gsub('%%%*', '')), 8)
end

T['a session'] = MiniTest.new_set()

T['a session']['resumed brings back the projects it had'] = function()
  local here = open('projects-session-resume', true)

  local resumed = open_again(here, 'projects-session-resume-again')

  eq(resumed, here.session)
  expect_tab_line(TWO_TABS)
end

T['a session']['resumed brings a project back with the base it had, not HEAD of the day it is resumed'] = function()
  local here = open('projects-session-resume-base', true)
  local base = git_repo.git(here.other, { 'rev-parse', 'HEAD' })
  git_repo.write(here.other, 'later.txt', { 'later' })
  git_repo.commit_all(here.other, 'Later')

  open_again(here, 'projects-session-resume-base-again')
  projects.enter_commits_window(child)
  child.type_keys('<Tab>')

  projects.wait_until('the project’s base is the one it had', function()
    return (projects.files_lines(child)[2] or ''):find(base:sub(1, 7), 1, true) ~= nil
  end)
end

T['a session']['that goes on with /clear begins with the session’s repository alone'] = function()
  open('projects-session-clear', true)

  clear_the_session()

  expect_tab_line('')
end

T['a session']['that goes on with /clear keeps the projects of the session it left'] = function()
  local here = open('projects-session-clear-kept', true)
  local state = vim.fs.joinpath(here.state_home, 'nvim')

  clear_the_session()

  eq(
    child.lua_get(
      [[(function(state, session)
        return #require('aineo.projects').read_kept(state, session)
      end)(...)]],
      { state, here.session }
    ),
    2
  )
end

T['a session']['that begins again shows the session’s project, not the one that was chosen'] = function()
  open('projects-session-reset-chosen', true)
  projects.enter_commits_window(child)
  child.type_keys('<Tab>')

  clear_the_session()

  expect_tab_line('')
  eq(vim.tbl_contains(projects.shown_buffer_names(child), 'aineo://changes-commits'), true)
end

T['a session']['that begins with the pane hidden leaves no line of tabs when the pane is shown'] = function()
  open('projects-session-clear-hidden', true)
  child.lua([[require('aineo.entry.registry').tab_list[1].show_pane('agent')]])

  clear_the_session()
  projects.show_changes_pane(child)

  expect_tab_line('')
end

T['a session']['that begins again lets a project of the session before join again'] = function()
  local here = open('projects-session-clear-rejoin', true)
  clear_the_session()
  expect_tab_line('')

  projects.edit(
    projects.name_transcript(child, followed_session()),
    vim.fs.joinpath(here.other, 'src/code.lua')
  )

  expect_tab_line(TWO_TABS)
end

T['a tab'] = MiniTest.new_set()

T['a tab']['closed leaves no project home, no file watch of the transcript and no timer of a count'] = function()
  local here = open('projects-session-closed-tab', true)
  projects.edit(here.transcript, vim.fs.joinpath(here.other, 'src/code.lua'))
  eq(buffers_named('aineo://copy'), 2)
  local watches_before = office_cells.open_handles(child, 'fs_event')
  local timers_before = office_cells.open_handles(child, 'timer')

  child.lua([[require('aineo.entry.projects').let_go(require('aineo.entry.registry').tab_list[1])]])

  projects.wait_until('the project’s buffers are gone', function()
    return buffers_named('aineo://copy') == 0
  end)
  eq(office_cells.open_handles(child, 'fs_event') < watches_before, true)
  eq(office_cells.open_handles(child, 'timer') <= timers_before, true)
end

T['the transcript'] = MiniTest.new_set()

T['the transcript']['followed to the session it says Claude Code went on in joins a project for an edit made there'] = function()
  local here = open('projects-session-continued', false)
  local continued_in = '22222222-2222-4222-8222-222222222222'
  local continuation = vim.fs.joinpath(vim.fs.dirname(here.transcript), continued_in .. '.jsonl')
  fake_transcript.append_text(continuation, '')

  fake_transcript.append(here.transcript, {
    vim.json.encode({
      type = 'continued-in',
      timestamp = os.date('!%Y-%m-%dT%H:%M:%S.000Z', os.time() + 5),
      sessionId = here.session,
      continuedInSessionId = continued_in,
    }),
  })
  vim.wait(1500)
  projects.edit(continuation, vim.fs.joinpath(here.other, 'src/code.lua'))

  expect_tab_line(TWO_TABS)
end

T['the transcript']['of a tab not yet written looks for its file and its subagents folder with one timer every 2 seconds'] = function()
  open('projects-session-polling', false)

  eq({
    office_cells.open_handles(child, 'timer') >= 1,
    child.lua_get([[(function()
        local count = 0
        vim.uv.walk(function(handle)
          if handle:get_type() == 'timer' and not handle:is_closing() and handle:get_repeat() == 500 then
            count = count + 1
          end
        end)
        return count
      end)()]]),
  }, { true, 0 })
end

T['a handed-over session'] = MiniTest.new_set()

T['a handed-over session']['takes the kept projects and each project’s kept base with it, though the tab does not follow it'] = function()
  local here = open('projects-session-hand-over', true)
  local from, to = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  local state = vim.fs.joinpath(here.state_home, 'nvim')
  local ready = child.lua_get(
    [[(function(state, from, other, to)
      local projects = require('aineo.projects')
      local project = { key = other .. '/.git', top = other, joined = 5 }
      projects.keep(state, from, { project })
      require('aineo.changes.kept').keep_base(
        state,
        projects.followed_id(from, project),
        { top = other, base = 'abc', saved = {} }
      )
      require('aineo.entry.projects').hand_over(
        require('aineo.entry.registry').tab_list[1],
        from,
        to
      )
      return projects.followed_id(from, project)
    end)(...)]],
    { state, from, here.other, to }
  )

  eq(ready ~= nil, true)
  eq(
    child.lua_get(
      [[(function(state, from, to, other)
        local projects = require('aineo.projects')
        local kept = require('aineo.changes.kept')
        local project = { key = other .. '/.git', top = other, joined = 5 }
        return {
          projects.read_kept(state, from) == nil,
          projects.read_kept(state, to) ~= nil,
          kept.read_kept_base(state, projects.followed_id(from, project)) == nil,
          kept.read_kept_base(state, projects.followed_id(to, project)) ~= nil,
        }
      end)(...)]],
      { state, from, to, here.other }
    ),
    { true, true, true, true }
  )
end

T['a forked session'] = MiniTest.new_set()

T['a forked session']['carries the projects of the session it forks and their bases, as a resume does'] = function()
  local here = open('projects-session-fork', true)
  local fork = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  local base = git_repo.git(here.other, { 'rev-parse', 'HEAD' })
  git_repo.write(here.other, 'later.txt', { 'later' })
  git_repo.commit_all(here.other, 'Later')

  fork_the_session(here.fake, here.session, fork)

  expect_tab_line(CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-api 1 %*')
  projects.enter_commits_window(child)
  child.type_keys('<Tab>')
  projects.wait_until('the project’s base is the one it had before the fork', function()
    return (projects.files_lines(child)[2] or ''):find(base:sub(1, 7), 1, true) ~= nil
  end)
end

T['a forked session']['carries no replayed edit: a project closed before the fork stays closed'] = function()
  local here = open('projects-session-fork-closed', true)
  local fork = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  projects.enter_commits_window(child)
  child.type_keys('<Tab>X')
  expect_tab_line('')

  fork_the_session(here.fake, here.session, fork)

  vim.wait(projects.QUIET_MS)
  eq(projects.tab_line(child), '')
end

T['a forked session']['is no clear: a cleared session carries nothing'] = function()
  open('projects-session-clear-nothing', true)

  clear_the_session()

  expect_tab_line('')
end

T['a forked session']['named for another session carries nothing into a session that is not that one (N1)'] = function()
  local here = open('projects-session-fork-stale', true)
  local other_session = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'

  child.lua(
    [[
      local projects = require('aineo.entry.projects')
      local tab = require('aineo.entry.registry').tab_list[1]
      projects.fork_of(tab, ..., 'cccccccc-cccc-4ccc-8ccc-cccccccccccc')
      projects.follow_session(tab, select(2, ...))
    ]],
    { here.session, other_session }
  )

  expect_tab_line('')
end

T['a forked session']['named while another session was followed still carries when it is followed'] = function()
  local here = open('projects-session-fork-late', true)
  local fork = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  child.lua(
    [[
      local projects = require('aineo.entry.projects')
      local tab = require('aineo.entry.registry').tab_list[1]
      projects.fork_of(tab, ..., select(2, ...))
      projects.follow_session(tab, 'dddddddd-dddd-4ddd-8ddd-dddddddddddd')
      projects.follow_session(tab, select(2, ...))
    ]],
    { here.session, fork }
  )

  expect_tab_line(TWO_TABS)
end

T['a session']['that a continued-in line of the session before names carries its projects and their bases'] = function()
  local here = open('projects-session-continued-carry', true)
  local next_session = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
  fake_transcript.append(here.transcript, {
    vim.json.encode({
      type = 'continued-in',
      timestamp = os.date('!%Y-%m-%dT%H:%M:%S.000Z', os.time() + 5),
      sessionId = here.session,
      continuedInSessionId = next_session,
    }),
  })
  vim.wait(1500)

  child.lua(
    [[require('aineo.entry.projects').follow_session(require('aineo.entry.registry').tab_list[1], ...)]],
    { next_session }
  )

  expect_tab_line(TWO_TABS)
end

T['a session']['no fork or continued-in line names carries nothing, as a resume elsewhere does'] = function()
  open('projects-session-plain-elsewhere', true)

  child.lua(
    [[require('aineo.entry.projects').follow_session(require('aineo.entry.registry').tab_list[1], ...)]],
    { 'ffffffff-ffff-4fff-8fff-ffffffffffff' }
  )

  expect_tab_line('')
end

return T
