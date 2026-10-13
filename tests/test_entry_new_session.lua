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
--- a hangup (`END_TERMINALS`).
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

--- How long a case waits for a switch, a message or a mode.
local PATIENCE_MS = 8000

--- A session id of the form Claude Code gives, for the claimed session.
local OTHER_ID = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'

--- The expression, run in the child, that gives the mode it is in.
local MODE = 'vim.api.nvim_get_mode().mode'

--- The expression, run in the child, that gives the terminal shown in the
--- child's first window, which is Claude's in the layout.
local CLAUDE_WINDOW_BUFFER = 'vim.api.nvim_win_get_buf(vim.fn.win_getid(1))'

--- What the layout's windows show under the agent pane.
local AGENT_PANE = { 'terminal', 'aineo://report', 'aineo://input' }

--- What `\N` and `<Plug>(aineo-new)` tell the user, as a warning, when they
--- do nothing: the words every refusal begins with.
local NO_NEW_SESSION = 'aineo: no new session — '

--- The bracketed paste, then Enter, in which `\N` writes `/clear` to a
--- running Claude Code.
local CLEAR_WRITE = '\27[200~/clear\27[201~\r'

--- The lines of the Report (`aineo://report`) in the child, each time of
--- day, which starts a header, written `HH:MM`.
local REPORT_LINES = [[vim.tbl_map(function(line)
  return (line:gsub('^%d%d:%d%d ', 'HH:MM '))
end, vim.api.nvim_buf_get_lines(vim.fn.bufnr('aineo://report'), 0, -1, true))]]

--- The lines of the layout's Input, read in the child.
local INPUT_LINES =
  "vim.api.nvim_buf_get_lines(require('aineo.layout').input_buffer(), 0, -1, true)"

--- A fake `claude` for one case, in `mode`, that runs the session hooks
--- aineo gives it (`AINEO_FAKE_CLAUDE_HOOKS`), so that `/clear` moves it to a
--- new session as Claude Code does.
---
---@param name string the case's own name for its files
---@param mode string one of the fake's modes
---@return { record: string, environment: table<string, string> }
local function fake_running_hooks(name, mode)
  return claude_session.fake(name, mode, { AINEO_FAKE_CLAUDE_HOOKS = '1' })
end

--- Gives the child a state directory of the case's own — aineo keeps the
--- session Claude Code last switched to there, which the next case's start
--- would resume — and makes aineo run `fake` there.
---
---@param fake { record: string, environment: table<string, string> }
---@param settings? table more of `vim.g.aineo`
local function use_fake_in_own_state(fake, settings)
  child.lua(
    'vim.env.XDG_STATE_HOME = ...',
    { fixture.directory(vim.fs.basename(vim.fs.dirname(fake.record)) .. '-state') }
  )
  entry.use_fake(child, fake, settings)
end

--- Opens the layout in the child on `fake` (`use_fake_in_own_state()`) and
--- waits until Claude Code is ready.
---
---@param fake { record: string, environment: table<string, string> }
local function open_layout_on(fake)
  use_fake_in_own_state(fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

--- Ends Claude Code in the child as a hangup does, by stopping the job of
--- the terminal Claude's window shows, and waits until the session has
--- exited.
local function end_claude_code()
  child.lua(('vim.fn.jobstop(vim.bo[%s].channel)'):format(CLAUDE_WINDOW_BUFFER))
  eq(claude_session.wait_for_status(child, 'exited')[1], 'exited')
end

--- The id of the session the child's Claude home follows now.
---
---@return string
local function followed_session_id()
  return claude_session.followed_session_id(child)
end

--- The session id the fake's `count`th start was given, on `--session-id`,
--- or none.
---
---@param fake { record: string }
---@param count integer
---@return string[]
local function new_id_of_start(fake, count)
  return claude_session.words_after(claude_session.start_arguments(fake, count), '--session-id')
end

--- The session id the fake's `count`th start resumed, on `--resume`, or none.
---
---@param fake { record: string }
---@param count integer
---@return string[]
local function resumed_id_of_start(fake, count)
  return claude_session.words_after(claude_session.start_arguments(fake, count), '--resume')
end

--- Waits until the child has told the user something, at most
--- `PATIENCE_MS`, and returns what it has told.
---
---@return { message: string?, level: integer? }[]
local function messages_once_told()
  vim.wait(PATIENCE_MS, function()
    return #entry.messages(child) > 0
  end, 20)
  return entry.messages(child)
end

--- Whether the fake has been written `/clear` as `\N` writes it.
---
---@param fake { record: string }
---@return boolean
local function was_written_clear(fake)
  return claude_session.received(fake):find(CLEAR_WRITE, 1, true) ~= nil
end

--- Waits, at most `PATIENCE_MS`, until the child's Claude home follows
--- another session than `before`, and returns the session it follows then.
---
---@param before string
---@return string
local function followed_session_once_changed(before)
  vim.wait(PATIENCE_MS, function()
    return followed_session_id() ~= before
  end, 20)
  return followed_session_id()
end

--- Waits, at most `PATIENCE_MS`, until the child's Report and Input are
--- empty, and returns their lines.
---
---@return { report: string[], input: string[] }
local function panes_once_empty()
  vim.wait(PATIENCE_MS, function()
    return vim.deep_equal(child.lua_get(REPORT_LINES), { '' })
      and vim.deep_equal(child.lua_get(INPUT_LINES), { '' })
  end, 20)
  return { report = child.lua_get(REPORT_LINES), input = child.lua_get(INPUT_LINES) }
end

--- Gives the child's report home a report of `task`, done, as Claude Code's
--- report tool hands it over.
---
---@param task string
local function receive_report(task)
  child.lua(
    "require('aineo.report').receive_report(...)",
    { { task = task, status = 'done', summary = 'All tests pass' } }
  )
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

--- Whether the child's commits window lists `line`, once it does so as
--- `expected` says, waiting for that at most `git_repo.PATIENCE_MS`; else
--- whether it does when the wait runs out.
---
---@param line string
---@param expected boolean
---@return boolean
local function commits_list_once(line, expected)
  local function lists()
    return vim.tbl_contains(
      child.lua_get('vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, true)', { COMMITS }),
      line
    )
  end
  vim.wait(git_repo.PATIENCE_MS, function()
    return lists() == expected
  end, 10)
  return lists()
end

--- Makes the repository `.tests/fixtures/git-<name>/repo` holding one file
--- in one commit, gives the child the repository isolation of the commits
--- suites (`git_repo.ENVIRONMENT`) and moves its working directory into it,
--- where Claude Code starts; returns the repository's top level.
---
---@param name string the case's own name for its files
---@return string top
local function enter_repository(name)
  local top = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', {
    git_repo.ENVIRONMENT,
  })
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  return top
end

T['the entry points'] = MiniTest.new_set({
  parametrize = {
    {
      function()
        entry.command(child, 'Aineo new')
      end,
    },
    {
      function()
        entry.press(child, '<Plug>(aineo-new)')
      end,
    },
    {
      function()
        entry.press(child, '\\N')
      end,
    },
  },
})

T['the entry points'][':Aineo new, <Plug>(aineo-new) and \\N start a new session on a new id once Claude Code has exited'] = function(
  trigger
)
  local fake = fake_running_hooks('new-session-entry-points', 'ready')
  open_layout_on(fake)
  end_claude_code()

  trigger()

  claude_session.wait_for_starts(fake, 2)
  eq(#new_id_of_start(fake, 2), 1)
  MiniTest.expect.no_equality(new_id_of_start(fake, 2), new_id_of_start(fake, 1))
  eq(resumed_id_of_start(fake, 2), {})
end

T['the entry points']['are refused with a word after new'] = function()
  entry.command(child, 'Aineo new all')

  eq(entry.messages(child), { { message = entry.USAGE, level = vim.log.levels.ERROR } })
end

T['with no Claude Code running'] = MiniTest.new_set()

T['with no Claude Code running']['lists no session and resumes nothing'] = function()
  local fake = fake_running_hooks('new-session-no-list', 'ready')
  open_layout_on(fake)
  end_claude_code()

  entry.press(child, '\\N')

  eq(#claude_session.wait_for_starts(fake, 2), 2)
  eq(#claude_session.wait_for_listings(fake, 0), 0)
  eq(resumed_id_of_start(fake, 2), {})
end

T['with no Claude Code running']['keeps the new id for the folder, so that \\o resumes it after /exit'] = function()
  local fake = fake_running_hooks('new-session-kept', 'ready')
  open_layout_on(fake)
  end_claude_code()
  entry.press(child, '\\N')
  claude_session.wait_for_status(child, 'ready')
  end_claude_code()

  entry.press(child, '\\o')

  eq(#claude_session.wait_for_starts(fake, 3), 3)
  eq(#new_id_of_start(fake, 2), 1)
  eq(resumed_id_of_start(fake, 3), new_id_of_start(fake, 2))
end

T['with no Claude Code running']['puts the new terminal in the exited one’s place and the cursor in Claude’s window in Terminal mode'] = function()
  local fake = fake_running_hooks('new-session-layout', 'ready')
  open_layout_on(fake)
  entry.press(child, '\\r')
  local exited = child.lua_get(CLAUDE_WINDOW_BUFFER)
  end_claude_code()

  entry.press(child, '\\N')

  vim.wait(PATIENCE_MS, function()
    return child.lua_get(MODE) == 't'
  end, 20)
  eq(entry.windows(child), AGENT_PANE)
  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 't')
  eq(child.lua_get(CLAUDE_WINDOW_BUFFER) ~= exited, true)
  eq(child.lua_get('vim.api.nvim_buf_is_valid(...)', { exited }), false)
end

T['with no Claude Code running']['opens the layout around a new session when Claude Code never started'] = function()
  local fake = fake_running_hooks('new-session-never-started', 'ready')
  use_fake_in_own_state(fake)

  entry.press(child, '\\N')

  claude_session.wait_for_status(child, 'ready')
  eq(entry.windows(child), AGENT_PANE)
  eq(#new_id_of_start(fake, 1), 1)
  eq(entry.messages(child), {})
end

T['with no Claude Code running']['opens the layout around a new session when Claude’s terminal was wiped'] = function()
  local fake = fake_running_hooks('new-session-wiped', 'ready')
  open_layout_on(fake)
  child.lua('vim.api.nvim_buf_delete(' .. CLAUDE_WINDOW_BUFFER .. ', { force = true })')
  eq(claude_session.wait_for_status(child, 'exited')[1], 'exited')

  entry.press(child, '\\N')

  eq(#claude_session.wait_for_starts(fake, 2), 2)
  eq(#new_id_of_start(fake, 2), 1)
  eq(entry.windows(child), AGENT_PANE)
end

T['with no Claude Code running']['takes HEAD as the changes pane’s base for the new session'] = function()
  local top = enter_repository('new-session-changes')
  local fake = fake_running_hooks('new-session-changes', 'ready')
  open_layout_on(fake)
  local first = followed_session_id()
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')
  entry.press(child, '\\g')
  local listed_before = commits_list_once(listed(commit, 'Write two'), true)
  entry.press(child, '\\pa')
  end_claude_code()

  entry.press(child, '\\N')

  claude_session.wait_for_status(child, 'ready')
  followed_session_once_changed(first)
  entry.press(child, '\\g')
  eq({
    listed_before = listed_before,
    listed = commits_list_once(listed(commit, 'Write two'), false),
  }, { listed_before = true, listed = false })
end

T['with no Claude Code running']['makes the Report and Input follow the new session'] = function()
  local fake = fake_running_hooks('new-session-follows', 'ready')
  open_layout_on(fake)
  local first = followed_session_id()
  receive_report('Rename the lexer')
  entry.set_input(child, { 'notes for the first session' })
  end_claude_code()

  entry.press(child, '\\N')

  claude_session.wait_for_status(child, 'ready')
  eq(followed_session_once_changed(first) ~= first, true)
  eq(panes_once_empty(), { report = { '' }, input = { '' } })
end

T['with Claude Code running and ready'] = MiniTest.new_set()

T['with Claude Code running and ready']['writes /clear and Enter as one paste, and follows the switch to a new session'] = function()
  local fake = fake_running_hooks('new-session-clear', 'ready')
  open_layout_on(fake)
  local first = followed_session_id()
  receive_report('Rename the lexer')

  entry.press(child, '\\N')

  local cleared = followed_session_once_changed(first)
  eq(was_written_clear(fake), true)
  eq(cleared ~= first, true)
  eq(panes_once_empty().report, { '' })
  eq(entry.messages(child), {})
  eq(#claude_session.wait_for_starts(fake, 0), 1)
end

T['with Claude Code running and ready']['leaves the cursor in Claude’s window in Terminal mode'] = function()
  local fake = fake_running_hooks('new-session-clear-cursor', 'ready')
  open_layout_on(fake)
  entry.press(child, '\\r')
  local first = followed_session_id()

  entry.press(child, '\\N')

  followed_session_once_changed(first)
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(MODE) == 't'
  end, 20)
  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 't')
end

T['a refusal'] = MiniTest.new_set()

T['a refusal']['while the prompt holds text writes nothing, says to clear it, and puts the window and the mode back'] = function()
  local fake = fake_running_hooks('new-session-refuse-text', 'draft')
  open_layout_on(fake)
  entry.press(child, '\\r')
  local first = followed_session_id()

  entry.press(child, '\\N')

  eq(messages_once_told(), {
    {
      message = NO_NEW_SESSION .. 'the prompt holds text; clear it, then press the key again',
      level = vim.log.levels.WARN,
    },
  })
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(MODE) == 'n'
  end, 20)
  vim.wait(300)
  eq(was_written_clear(fake), false)
  eq(claude_session.received(fake):find('/clear', 1, true), nil)
  eq(entry.current_window(child), 'aineo://report')
  eq(child.lua_get(MODE), 'n')
  eq(followed_session_id(), first)
end

T['a refusal']['while Claude Code is starting or a dialog awaits an answer writes nothing and starts nothing'] = function()
  local fake = fake_running_hooks('new-session-refuse-starting', 'trust')
  use_fake_in_own_state(fake)
  child.cmd('Aineo open')
  claude_session.wait_for_screen(child, child.lua_get(CLAUDE_WINDOW_BUFFER), 'trust')

  entry.press(child, '\\N')

  eq(messages_once_told(), {
    {
      message = NO_NEW_SESSION
        .. 'Claude is not ready: it is starting, or a dialog in its window awaits your answer',
      level = vim.log.levels.WARN,
    },
  })
  vim.wait(300)
  eq(claude_session.received(fake):find('/clear', 1, true), nil)
  eq(#claude_session.wait_for_starts(fake, 0), 1)
end

T['a refusal']['while a start waits for the session list writes nothing and starts nothing'] = function()
  local fake = fake_running_hooks('new-session-refuse-list', 'ready')
  local gate = claude_session.list_gate('new-session-refuse-list')
  use_fake_in_own_state(fake, { claude = { cmd = gate.cmd } })
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  end_claude_code()
  child.cmd('Aineo open')
  vim.wait(PATIENCE_MS, function()
    return gate.lists_started() > 0
  end, 20)

  entry.press(child, '\\N')

  eq(messages_once_told(), {
    {
      message = NO_NEW_SESSION
        .. 'Claude is not ready: it is starting, or a dialog in its window awaits your answer',
      level = vim.log.levels.WARN,
    },
  })
  gate.open()
  claude_session.wait_for_status(child, 'ready')
  eq(claude_session.received(fake):find('/clear', 1, true), nil)
  eq(#claude_session.wait_for_starts(fake, 0), 2)
end

--- The words `\N` tells the user, as a warning, when a claim of the session
--- `OTHER_ID` holds and Claude Code's own session runs.
local CLAIMED_WORDS = NO_NEW_SESSION
  .. 'the panes follow the claimed session '
  .. OTHER_ID
  .. ', which this Neovim’s Claude terminal does not run;'
  .. ' :Aineo claim with no argument returns this Neovim to its own session'

T['a refusal']['while a claim of another session holds writes nothing and says how to leave the claim'] = function()
  local fake = fake_running_hooks('new-session-refuse-claim', 'ready')
  open_layout_on(fake)
  child.cmd('Aineo claim ' .. OTHER_ID)

  entry.press(child, '\\N')

  eq(messages_once_told(), { { message = CLAIMED_WORDS, level = vim.log.levels.WARN } })
  vim.wait(300)
  eq(claude_session.received(fake):find('/clear', 1, true), nil)
end

T['a refusal']['while a claim of another session holds, with Claude Code starting, gives the claim’s words'] = function()
  local fake = fake_running_hooks('new-session-refuse-claim-starting', 'trust')
  use_fake_in_own_state(fake)
  child.cmd('Aineo open')
  claude_session.wait_for_screen(child, child.lua_get(CLAUDE_WINDOW_BUFFER), 'trust')
  child.cmd('Aineo claim ' .. OTHER_ID)

  entry.press(child, '\\N')

  eq(messages_once_told(), { { message = CLAIMED_WORDS, level = vim.log.levels.WARN } })
  vim.wait(300)
  eq(claude_session.received(fake):find('/clear', 1, true), nil)
end

T['a refusal']['while a claim of another session holds, after Claude Code has exited, starts nothing'] = function()
  local fake = fake_running_hooks('new-session-refuse-claim-exited', 'ready')
  open_layout_on(fake)
  end_claude_code()
  child.cmd('Aineo claim ' .. OTHER_ID)

  entry.press(child, '\\N')

  eq(messages_once_told(), { { message = CLAIMED_WORDS, level = vim.log.levels.WARN } })
  vim.wait(300)
  eq(#claude_session.wait_for_starts(fake, 0), 1)
end

T['a refusal']['when Claude’s window does not enter Terminal mode writes nothing and puts the cursor back'] = function()
  local fake = fake_running_hooks('new-session-refuse-no-terminal-mode', 'ready')
  open_layout_on(fake)
  entry.press(child, '\\r')
  child.lua('rawset(vim.cmd, "startinsert", function() end)')

  entry.press(child, '\\N')

  eq(messages_once_told(), {
    {
      message = NO_NEW_SESSION .. 'Claude’s window did not enter Terminal mode',
      level = vim.log.levels.WARN,
    },
  })
  eq(entry.current_window(child), 'aineo://report')
  child.lua('rawset(vim.cmd, "startinsert", nil)')
  child.lua('vim.api.nvim_set_current_win(vim.fn.win_getid(1))')
  child.cmd('startinsert')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(MODE) == 't'
  end, 20)
  vim.wait(300)
  eq(claude_session.received(fake):find('/clear', 1, true), nil)
end

--- Where a twin is pressed from, by the mode it is pressed in: `t`, Terminal
--- mode in a terminal of the user's own; `i`, Insert mode in a buffer of
--- the user's own.
local USER_BUFFER = { t = 'terminal cat', i = 'enew' }

--- Presses `<C-\>N` in the child in `mode`: `t`, Terminal mode in Claude's
--- prompt, entered by `\c`; `i`, Insert mode in a buffer of the user's own.
---
---@param mode 't'|'i'
local function press_twin_from_claude_or_other_buffer(mode)
  if mode == 't' then
    entry.press(child, '\\c')
  else
    child.cmd('enew')
    child.cmd('startinsert')
  end
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(MODE) == mode
  end, 20)
  eq(child.lua_get(MODE), mode)
  child.type_keys('<C-\\>N')
end

T['the twin <C-\\>N'] = MiniTest.new_set({ parametrize = { { 't' }, { 'i' } } })

T['the twin <C-\\>N']['starts a new session on a new id after Claude Code has exited, pressed in a buffer of the user’s own'] = function(
  mode
)
  local fake = fake_running_hooks('new-session-twin-start-' .. mode, 'ready')
  open_layout_on(fake)
  end_claude_code()
  child.cmd(USER_BUFFER[mode])
  child.cmd('startinsert')
  eq(child.lua_get(MODE), mode)

  child.type_keys('<C-\\>N')

  claude_session.wait_for_starts(fake, 2)
  eq(#new_id_of_start(fake, 2), 1)
  eq(resumed_id_of_start(fake, 2), {})
end

T['the twin <C-\\>N']['writes /clear and Enter, pressed in Claude’s prompt or in Insert mode in another buffer'] = function(
  mode
)
  local fake = fake_running_hooks('new-session-twin-clear-' .. mode, 'ready')
  open_layout_on(fake)
  local first = followed_session_id()
  press_twin_from_claude_or_other_buffer(mode)

  followed_session_once_changed(first)
  eq(was_written_clear(fake), true)
end

T['the twin <C-\\>N']['writes nothing while the prompt holds text, pressed in Claude’s prompt or in Insert mode in another buffer'] = function(
  mode
)
  local fake = fake_running_hooks('new-session-twin-refuse-' .. mode, 'draft')
  open_layout_on(fake)
  press_twin_from_claude_or_other_buffer(mode)

  eq(messages_once_told(), {
    {
      message = NO_NEW_SESSION .. 'the prompt holds text; clear it, then press the key again',
      level = vim.log.levels.WARN,
    },
  })
  vim.wait(300)
  eq(claude_session.received(fake):find('/clear', 1, true), nil)
end

return T
