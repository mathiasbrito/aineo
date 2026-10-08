local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

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

--- Stops the child, once the fake Claude Code it runs, if any, has ended by
--- a hangup (`END_TERMINALS`): Neovim quitting then has no Claude Code for
--- aineo to stop by its keys, a stop that waits some 4.4 s for the fake to
--- exit once it reads its keys.
local function stop_the_child()
  if child.is_running() then
    child.lua(END_TERMINALS)
  end
  child.stop()
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      entry.restart(child)
    end,
    post_once = stop_the_child,
  },
})

--- How long a case waits for a file to hold what it waits for: longer than
--- the second after which Input's draft is saved, and than a start's
--- confirmation after a resume with no conversation, about 3 s.
local FILE_PATIENCE_MS = 8000

--- The lines of the layout's Input, read in the child.
local INPUT_LINES =
  "vim.api.nvim_buf_get_lines(require('aineo.layout').input_buffer(), 0, -1, true)"

--- The expression, run in the child, that gives the Report's lines, each
--- time of day, which starts a header, written `HH:MM`.
local REPORT_LINES = [[vim.tbl_map(function(line)
  return (line:gsub('^%d%d:%d%d ', 'HH:MM '))
end, vim.api.nvim_buf_get_lines(vim.fn.bufnr('aineo://report'), 0, -1, true))]]

--- Gives the child the git isolation of the git home's suites
--- (`git_repo.ENVIRONMENT`) and `state_home` as `XDG_STATE_HOME`, and moves
--- its working directory into `top`, where Claude Code starts.
---
---@param top string
---@param state_home string
local function enter(top, state_home)
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', {
    vim.tbl_extend('force', git_repo.ENVIRONMENT, { XDG_STATE_HOME = state_home }),
  })
  child.cmd('cd ' .. vim.fn.fnameescape(top))
end

--- Makes the repository `.tests/fixtures/git-<name>/repo` holding one file
--- in one commit and the state directory `.tests/fixtures/<name>-state`,
--- and has the child enter them (`enter()`); returns the repository's top
--- level, its commit, the child's state directory, `stdpath('state')`, and
--- the `XDG_STATE_HOME` it is under.
---
---@param name string the case's own name, starting `session-switch-`
---@return string top
---@return string base
---@return string state
---@return string state_home
local function in_repository(name)
  local top, base = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  local state_home = fixture.directory(name .. '-state')
  enter(top, state_home)
  return top, base, vim.fs.joinpath(state_home, 'nvim'), state_home
end

--- The files aineo keeps for the child's working directory under `state`,
--- until a session takes them: Input's draft and the Report's records.
---
---@param state string
---@return { draft: string, records: string }
local function directory_files(state)
  local name = vim.fn.sha256(child.fn.getcwd())
  return {
    draft = vim.fs.joinpath(state, 'aineo', 'drafts', name .. '.txt'),
    records = vim.fs.joinpath(state, 'aineo', 'reports', name .. '.jsonl'),
  }
end

--- The files aineo keeps for the Claude session `id` under `state`:
--- Input's draft, the Report's records and the changes pane's base.
---
---@param state string
---@param id string
---@return { draft: string, records: string, base: string }
local function session_files(state, id)
  local name = vim.fn.sha256(id)
  return {
    draft = vim.fs.joinpath(state, 'aineo', 'drafts', 'session-' .. name .. '.txt'),
    records = vim.fs.joinpath(state, 'aineo', 'reports', 'session-' .. name .. '.jsonl'),
    base = vim.fs.joinpath(state, 'aineo', 'changes-sessions', name .. '.json'),
  }
end

--- The whole text of the file at `path`, or nil when it cannot be read.
---
---@param path string
---@return string|nil
local function read_file(path)
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  return text
end

--- The text of the file at `path` once it holds `text`, waiting for that at
--- most `FILE_PATIENCE_MS`; else what it holds when the wait runs out.
---
---@param path string
---@param text string
---@return string|nil
local function text_once_written(path, text)
  vim.wait(FILE_PATIENCE_MS, function()
    return read_file(path) == text
  end, 20)
  return read_file(path)
end

--- The base kept for the changes pane in the file at `path` once one is
--- kept there, waiting for that at most `FILE_PATIENCE_MS`; nil when none
--- is.
---
---@param path string
---@return string|nil
local function kept_base_once_written(path)
  vim.wait(FILE_PATIENCE_MS, function()
    return read_file(path) ~= nil
  end, 20)
  local text = read_file(path)
  return text and vim.json.decode(text).base
end

--- The task of each report the records file at `path` keeps, in order, or
--- nil when there is no such file.
---
---@param path string
---@return string[]|nil
local function kept_tasks(path)
  local text = read_file(path)
  return text
    and vim.tbl_map(function(line)
      return vim.json.decode(line).report.task
    end, vim.split(text, '\n', { trimempty = true }))
end

--- Writes `lines` as the file at `path`, as an earlier editor left it.
---
---@param path string
---@param lines string[]
local function leave_file(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  assert(vim.fn.writefile(lines, path) == 0, 'cannot write ' .. path)
end

--- Makes the child's report home receive a report of `task`, done, as
--- Claude Code's report tool hands it over (`aineo.mcp`'s relay).
---
---@param task string
local function receive_report(task)
  child.lua(
    "require('aineo.report').receive_report(...)",
    { { task = task, status = 'done', summary = 'All tests pass' } }
  )
end

--- The id of the session the child's Claude home follows.
---
---@return string
local function followed_session()
  return claude_session.followed_session_id(child)
end

--- How long after its start a case waits for a start that is never ready
--- to be followed all the same: longer than the 2 s after which a follow on
--- a timer would come, and than a resume with no conversation takes to be
--- replaced by a new session that is ready, about 3 s.
local UNCONFIRMED_PATIENCE_MS = 4000

--- The files aineo keeps for any Claude session under `state`: drafts,
--- records and the changes pane's bases, by path.
---
---@param state string
---@return string[]
local function any_session_files(state)
  local kept = vim.fs.joinpath(state, 'aineo')
  return vim.list_extend(
    vim.fn.glob(vim.fs.joinpath(kept, '*', 'session-*'), true, true),
    vim.fn.glob(vim.fs.joinpath(kept, 'changes-sessions', '*'), true, true)
  )
end

--- What aineo keeps for any Claude session under `state`
--- (`any_session_files()`), once a file of it is there, or
--- `UNCONFIRMED_PATIENCE_MS` after `started_at` (`vim.uv.now()`), when none
--- has come by then.
---
---@param state string
---@param started_at integer
---@return string[]
local function session_files_after_unconfirmed_wait(state, started_at)
  vim.wait(UNCONFIRMED_PATIENCE_MS - (vim.uv.now() - started_at), function()
    return #any_session_files(state) > 0
  end, 20)
  return any_session_files(state)
end

--- A fake `claude` for one case, in its `ready` mode, that runs the session
--- hooks aineo gives it (`AINEO_FAKE_CLAUDE_HOOKS`), as Claude Code does in
--- a folder the user trusted, with `extra_environment` on top.
---
---@param name string the case's own name for its files
---@param extra_environment? table<string, string>
---@return { record: string, environment: table<string, string> }
local function fake_running_hooks(name, extra_environment)
  return claude_session.fake(
    name,
    'ready',
    vim.tbl_extend('force', { AINEO_FAKE_CLAUDE_HOOKS = '1' }, extra_environment or {})
  )
end

--- The expression, run in the child, that gives the terminal whose Claude
--- Code still runs.
local RUNNING_CLAUDE_TERMINAL = [[vim.iter(vim.api.nvim_list_bufs()):find(function(buffer)
  return vim.bo[buffer].buftype == 'terminal'
    and vim.fn.jobwait({ vim.b[buffer].terminal_job_id }, 0)[1] == -1
end)]]

--- Types `keys` in the child's running Claude Code, as a user typing in
--- Claude's window would — a command such as `/clear\r` — and waits, at most
--- `FILE_PATIENCE_MS`, until the Claude home follows another session than
--- the one it followed before; returns the session it follows then.
---
---@param keys string
---@return string
local function switch_by_keys(keys)
  local before = followed_session()
  claude_session.press_keys(child, child.lua_get(RUNNING_CLAUDE_TERMINAL), keys)
  vim.wait(FILE_PATIENCE_MS, function()
    return followed_session() ~= before
  end, 20)
  return followed_session()
end

--- The lines of the child's buffer named `name`.
---
---@param name string
---@return string[]
local function lines_of(name)
  return child.lua_get('vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, true)', { name })
end

--- Whether the child's buffer named `name` lists `line`, once it does so
--- as `expected` says, waiting for that at most `git_repo.PATIENCE_MS`;
--- else whether it does when the wait runs out. Only the line is looked
--- for: the pane's other lines are not this file's to pin.
---
---@param name string
---@param line string
---@param expected boolean
---@return boolean
local function lists_once(name, line, expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.tbl_contains(lines_of(name), line) == expected
  end, 10)
  return vim.tbl_contains(lines_of(name), line)
end

--- The name of the changes pane's commits buffer.
local COMMITS = 'aineo://changes-commits'

--- How the commits window lists `commit`, made with the subject `subject`.
---
---@param commit string
---@param subject string
---@return string
local function listed(commit, subject)
  return commit:sub(1, 7) .. ' ' .. subject
end

--- A session id of the form Claude Code gives, for a session an earlier
--- editor kept a draft, records or a base for.
local OTHER_SESSION_ID = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'

--- One report, kept as an earlier editor kept it, and how the Report shows
--- it.
local EARLIER_RECORD =
  '{"time":"2026-10-08T09:05:00","report":{"task":"Earlier task","status":"done","summary":"Kept"}}'
local EARLIER_REPORT = 'HH:MM [done] Earlier task — Kept'

--- Leaves, under `state`, what an earlier editor kept for the session `id`
--- in the repository `top`: one report (`EARLIER_RECORD`), and `base` as
--- the changes pane's base, with no save.
---
---@param state string
---@param id string
---@param top string
---@param base string
local function leave_session(state, id, top, base)
  local kept = session_files(state, id)
  leave_file(kept.records, { EARLIER_RECORD })
  leave_file(kept.base, { vim.json.encode({ top = top, base = base, saved = {} }) })
end

--- How the Report shows a report of `task` that `receive_report()` gave.
---
---@param task string
---@return string
local function shown(task)
  return 'HH:MM [done] ' .. task .. ' — All tests pass'
end

--- Opens the layout in the child with aineo running `fake`, and waits until
--- Claude Code is ready; returns the session it started on.
---
---@param fake { environment: table<string, string> }
---@return string
local function open_until_ready(fake)
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  return followed_session()
end

T['a start'] = MiniTest.new_set()

T['a start']['once ready, keeps the reports, the draft and the changes pane’s base under the session it started on, with no hook run'] = function()
  local _, base, state = in_repository('session-switch-started')
  leave_file(directory_files(state).draft, { 'Refactor the parser' })
  entry.use_fake(child, claude_session.fake('session-switch-started', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  local kept = session_files(state, followed_session())

  receive_report('Rename the lexer')

  eq({
    input = child.lua_get(INPUT_LINES),
    draft = text_once_written(kept.draft, 'Refactor the parser\n'),
    directory_draft = read_file(directory_files(state).draft),
    tasks = kept_tasks(kept.records),
    base = kept_base_once_written(kept.base),
  }, {
    input = { 'Refactor the parser' },
    draft = 'Refactor the parser\n',
    tasks = { 'Rename the lexer' },
    base = base,
  })
end

T['a start']['that is never ready leaves the folder’s draft and records where they are, and saves what is typed there'] = function()
  local _, _, state = in_repository('session-switch-unconfirmed')
  local folder = directory_files(state)
  leave_file(folder.draft, { 'Refactor the parser' })
  leave_file(folder.records, {
    '{"time":"2026-10-08T09:05:00","report":{"task":"Earlier task","status":"done","summary":"Kept"}}',
  })
  entry.use_fake(child, claude_session.fake('session-switch-unconfirmed', 'trust'))
  local started_at = vim.uv.now()
  child.cmd('Aineo open')

  entry.set_input(child, { 'then run the tests' })

  eq({
    draft = text_once_written(folder.draft, 'then run the tests\n'),
    tasks = kept_tasks(folder.records),
    session_files = session_files_after_unconfirmed_wait(state, started_at),
    status = child.lua_get("require('aineo.claude').session_status()"),
  }, {
    draft = 'then run the tests\n',
    tasks = { 'Earlier task' },
    session_files = {},
    status = 'starting',
  })
end

T['a switch'] = MiniTest.new_set()

T['a switch']['by /clear, once ready, shows an empty Report and an empty Input, and takes HEAD as the changes pane’s base'] = function()
  local top = in_repository('session-switch-clear')
  entry.use_fake(child, fake_running_hooks('session-switch-clear'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  receive_report('Rename the lexer')
  entry.set_input(child, { 'notes for the first session' })
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')
  entry.press(child, '\\pc')
  local listed_before = lists_once(COMMITS, listed(commit, 'Write two'), true)
  entry.press(child, '\\pa')

  switch_by_keys('/clear\r')

  local report, input = child.lua_get(REPORT_LINES), child.lua_get(INPUT_LINES)
  entry.press(child, '\\pc')
  eq({
    listed_before = listed_before,
    report = report,
    input = input,
    listed = lists_once(COMMITS, listed(commit, 'Write two'), false),
  }, { listed_before = true, report = { '' }, input = { '' }, listed = false })
end

T['a switch']['by /resume, with the agent pane shown, shows the session’s reports in the Report at once, and its base at \\pc'] = function()
  local top, base, state = in_repository('session-switch-resume-agent')
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')
  leave_session(state, OTHER_SESSION_ID, top, base)
  open_until_ready(fake_running_hooks('session-switch-resume-agent'))

  switch_by_keys('/resume ' .. OTHER_SESSION_ID .. '\r')

  local report = child.lua_get(REPORT_LINES)
  entry.press(child, '\\pc')
  eq(
    { report = report, listed = lists_once(COMMITS, listed(commit, 'Write two'), true) },
    { report = { EARLIER_REPORT }, listed = true }
  )
end

T['a switch']['by /resume, with the changes pane shown, shows the session’s base there at once, and its reports at \\pa'] = function()
  local top, base, state = in_repository('session-switch-resume-changes')
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')
  leave_session(state, OTHER_SESSION_ID, top, base)
  open_until_ready(fake_running_hooks('session-switch-resume-changes'))
  entry.press(child, '\\pc')
  local listed_before = lists_once(COMMITS, listed(commit, 'Write two'), false)

  switch_by_keys('/resume ' .. OTHER_SESSION_ID .. '\r')

  local listed_after = lists_once(COMMITS, listed(commit, 'Write two'), true)
  entry.press(child, '\\pa')
  eq({
    listed_before = listed_before,
    listed_after = listed_after,
    report = child.lua_get(REPORT_LINES),
  }, { listed_before = false, listed_after = true, report = { EARLIER_REPORT } })
end

T['a switch']['by /resume back to the first session brings its Report, its base and its draft back'] = function()
  local top = in_repository('session-switch-resume-back')
  local first = open_until_ready(fake_running_hooks('session-switch-resume-back'))
  receive_report('Rename the lexer')
  entry.set_input(child, { 'notes for the first session' })
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')
  switch_by_keys('/clear\r')

  switch_by_keys('/resume ' .. first .. '\r')

  local report, input = child.lua_get(REPORT_LINES), child.lua_get(INPUT_LINES)
  entry.press(child, '\\pc')
  eq({
    report = report,
    input = input,
    listed = lists_once(COMMITS, listed(commit, 'Write two'), true),
  }, {
    report = { shown('Rename the lexer') },
    input = { 'notes for the first session' },
    listed = true,
  })
end

T['a switch']['keeps Input’s text as the draft of the session left, and puts the draft of the session switched to in Input'] = function()
  local _, _, state = in_repository('session-switch-drafts')
  leave_file(session_files(state, OTHER_SESSION_ID).draft, { 'notes for the other session' })
  local first = open_until_ready(fake_running_hooks('session-switch-drafts'))
  entry.set_input(child, { 'notes for the first session' })

  switch_by_keys('/resume ' .. OTHER_SESSION_ID .. '\r')

  eq({
    input = child.lua_get(INPUT_LINES),
    left = text_once_written(session_files(state, first).draft, 'notes for the first session\n'),
  }, {
    input = { 'notes for the other session' },
    left = 'notes for the first session\n',
  })
end

T['a switch']['by /branch shows the new session’s Report and Input, both empty'] = function()
  in_repository('session-switch-branch')
  local first = open_until_ready(fake_running_hooks('session-switch-branch'))
  receive_report('Rename the lexer')
  entry.set_input(child, { 'notes for the first session' })

  local branched = switch_by_keys('/branch\r')

  MiniTest.expect.no_equality(branched, first)
  eq(
    { report = child.lua_get(REPORT_LINES), input = child.lua_get(INPUT_LINES) },
    { report = { '' }, input = { '' } }
  )
end

--- The source or reason of each `event` hook `fake` has run, in order,
--- once one of them is `cause`, waiting for that at most
--- `FILE_PATIENCE_MS`; else those it has run when the wait runs out.
---
---@param fake { record: string }
---@param event string
---@param cause string
---@return string[]
local function hook_causes_once(fake, event, cause)
  local causes
  vim.wait(FILE_PATIENCE_MS, function()
    causes = vim.tbl_map(
      function(run)
        return run.cause
      end,
      vim.tbl_filter(function(recorded)
        return recorded.hook == event
      end, claude_session.record(fake))
    )
    return vim.tbl_contains(causes, cause)
  end, 20)
  return causes
end

--- The expression, run in the child, that gives the cursor of the window
--- showing the Report.
local REPORT_CURSOR = "vim.api.nvim_win_get_cursor(vim.fn.bufwinid('aineo://report'))"

T['a SessionStart of the session followed'] = MiniTest.new_set()

T['a SessionStart of the session followed']['by /compact changes nothing: the Report’s lines and cursor, and Input’s text, stay'] = function()
  in_repository('session-switch-compact')
  local fake = fake_running_hooks('session-switch-compact')
  local first = open_until_ready(fake)
  receive_report('Rename the lexer')
  receive_report('Write the docs')
  child.lua("vim.api.nvim_win_set_cursor(vim.fn.bufwinid('aineo://report'), { 1, 0 })")
  entry.set_input(child, { 'notes for the first session' })

  claude_session.press_keys(child, child.lua_get(RUNNING_CLAUDE_TERMINAL), '/compact\r')

  local causes = hook_causes_once(fake, 'SessionStart', 'compact')
  claude_session.wait_for_deliveries(child)
  eq({
    causes = causes,
    followed = followed_session(),
    report = child.lua_get(REPORT_LINES),
    cursor = child.lua_get(REPORT_CURSOR),
    input = child.lua_get(INPUT_LINES),
  }, {
    causes = { 'startup', 'compact' },
    followed = first,
    report = { shown('Rename the lexer'), shown('Write the docs') },
    cursor = { 1, 0 },
    input = { 'notes for the first session' },
  })
end

T['a new editor'] = MiniTest.new_set()

T['a new editor']['in the directory resumes the session switched to, and shows its Report and its draft'] = function()
  local top, _, state, state_home = in_repository('session-switch-next-editor')
  open_until_ready(fake_running_hooks('session-switch-next-editor-first'))
  local cleared = switch_by_keys('/clear\r')
  receive_report('Write the docs')
  entry.set_input(child, { 'notes for the cleared session' })
  text_once_written(session_files(state, cleared).draft, 'notes for the cleared session\n')
  stop_the_child()
  entry.restart(child)
  enter(top, state_home)
  local fake = fake_running_hooks('session-switch-next-editor')

  open_until_ready(fake)

  eq({
    resumed = claude_session.words_after(claude_session.arguments(fake), '--resume'),
    report = child.lua_get(REPORT_LINES),
    input = child.lua_get(INPUT_LINES),
  }, {
    resumed = { cleared },
    report = { shown('Write the docs') },
    input = { 'notes for the cleared session' },
  })
end

--- A session id of the form Claude Code gives, kept for a directory, that
--- Claude Code has no conversation for.
local DEAD_SESSION_ID = '7d0e3a4f-8e1a-4d2f-b5c7-91d0e3a4f853'

--- Keeps `id` as the session id of `directory` under `state`, as the Claude
--- home names its file there: `aineo/claude-sessions/<the directory's
--- SHA-256>.txt`.
---
---@param state string
---@param directory string
---@param id string
local function keep_session_id(state, directory, id)
  local file =
    vim.fs.joinpath(state, 'aineo', 'claude-sessions', vim.fn.sha256(directory) .. '.txt')
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  assert(vim.fn.writefile({ id }, file, 'b') == 0, 'cannot write ' .. file)
end

--- A fake `claude` for one case, in its `ready` mode, that keeps
--- conversations as Claude Code does (`AINEO_FAKE_CLAUDE_CONVERSATIONS`), in
--- a directory of its own that holds none yet: a resume of any id kept
--- before finds no conversation.
---
---@param name string the case's own name for its files
---@return { record: string, environment: table<string, string> }
local function fake_with_no_conversation(name)
  return claude_session.fake(name, 'ready', {
    AINEO_FAKE_CLAUDE_CONVERSATIONS = fixture.directory(name .. '-conversations'),
  })
end

T['a resume with no conversation'] = MiniTest.new_set()

T['a resume with no conversation']['at the first start gives the folder’s draft and records, and what was typed meanwhile, to the session that takes its place'] = function()
  local top, _, state = in_repository('session-switch-dead-first')
  local folder = directory_files(state)
  leave_file(folder.draft, { 'Refactor the parser' })
  leave_file(folder.records, { EARLIER_RECORD })
  keep_session_id(state, top, DEAD_SESSION_ID)
  local fake = fake_with_no_conversation('session-switch-dead-first')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  entry.set_input(child, { 'Refactor the parser', 'then run the tests' })

  claude_session.wait_for_starts(fake, 2)
  claude_session.wait_for_status(child, 'ready')

  local replacement = session_files(state, followed_session())
  eq({
    input = child.lua_get(INPUT_LINES),
    report = child.lua_get(REPORT_LINES),
    draft = text_once_written(replacement.draft, 'Refactor the parser\nthen run the tests\n'),
    tasks = kept_tasks(replacement.records),
    dead = vim.tbl_map(vim.uv.fs_stat, session_files(state, DEAD_SESSION_ID)),
  }, {
    input = { 'Refactor the parser', 'then run the tests' },
    report = { EARLIER_REPORT },
    draft = 'Refactor the parser\nthen run the tests\n',
    tasks = { 'Earlier task' },
    dead = {},
  })
end

T['a resume with no conversation']['at a later start in another directory keeps what is typed before it is ready as the draft of the session followed until then'] = function()
  local _, _, state = in_repository('session-switch-dead-later')
  local fake = fake_with_no_conversation('session-switch-dead-later')
  local first = open_until_ready(fake)
  child.lua(END_TERMINALS)
  claude_session.wait_for_status(child, 'exited')
  local elsewhere = fixture.directory('session-switch-dead-later-elsewhere')
  keep_session_id(state, elsewhere, DEAD_SESSION_ID)
  child.cmd('cd ' .. vim.fn.fnameescape(elsewhere))
  entry.press(child, '\\o')

  entry.set_input(child, { 'notes typed while it starts' })

  local typed =
    text_once_written(session_files(state, first).draft, 'notes typed while it starts\n')
  claude_session.wait_for_starts(fake, 3)
  claude_session.wait_for_status(child, 'ready')
  eq({
    typed = typed,
    dead = vim.uv.fs_stat(session_files(state, DEAD_SESSION_ID).draft),
    input = child.lua_get(INPUT_LINES),
  }, {
    typed = 'notes typed while it starts\n',
    input = { '' },
  })
end

return T
