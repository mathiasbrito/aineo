local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local send = dofile('tests/helpers/send.lua')

local eq = MiniTest.expect.equality

--- The Neovims a case runs, each an aineo editor with its own Claude Code.
local child = MiniTest.new_child_neovim()
local other = MiniTest.new_child_neovim()

--- The Lua that ends, in a Neovim, the process of every terminal by a
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

--- Stops `editor`, once the fake Claude Code it runs, if any, has ended by a
--- hangup (`END_TERMINALS`); an editor that has quit by itself is stopped
--- as it is.
---
---@param editor table
local function stop(editor)
  if editor.is_running() then
    pcall(editor.lua, END_TERMINALS)
  end
  editor.stop()
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop(other)
      stop(child)
      entry.restart(child)
    end,
    post_once = function()
      stop(other)
      stop(child)
    end,
  },
})

--- How long a case waits for a file or an editor to hold what it waits for.
local PATIENCE_MS = 8000

--- Session ids of the form Claude Code gives.
local OTHER_SESSION_ID = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'

--- Gives `editor` the `XDG_STATE_HOME` `home`, under which aineo keeps
--- what it keeps; returns the state directory under it.
---
---@param editor table
---@param home string
---@return string
local function share_state(editor, home)
  editor.lua('vim.env.XDG_STATE_HOME = ...', { home })
  return vim.fs.joinpath(home, 'nvim')
end

--- The entry the list of running editors under `state` keeps for the
--- editor at `address`, decoded; nil when there is none.
---
---@param state string
---@param address string
---@return table?
local function entry_at(state, address)
  local path = vim.fs.joinpath(state, 'aineo', 'editors', vim.fn.sha256(address) .. '.json')
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  return vim.json.decode(text)
end

--- The entry the list under `state` keeps for `editor` (`entry_at()`) once
--- `is_wanted` accepts it, waiting at most `PATIENCE_MS`; else what it is
--- when the wait runs out.
---
---@param state string
---@param editor table
---@param is_wanted fun(listed: table?): boolean
---@return table?
local function entry_once(state, editor, is_wanted)
  local address = editor.v.servername
  vim.wait(PATIENCE_MS, function()
    return is_wanted(entry_at(state, address))
  end, 20)
  return entry_at(state, address)
end

--- The expression, run in an editor, that gives the terminal of its Claude
--- Code, shown in the layout's first window.
local CLAUDE_TERMINAL = 'vim.api.nvim_win_get_buf(vim.fn.win_getid(1))'

--- Types `keys` in `editor`'s Claude Code, as a user typing in Claude's
--- window would — a command such as `/clear\r`.
---
---@param editor table
---@param keys string
local function type_to_claude(editor, keys)
  claude_session.press_keys(editor, editor.lua_get(CLAUDE_TERMINAL), keys)
end

--- A fake `claude` for one case that runs the session hooks aineo gives it.
---
---@param name string
---@param extra_environment? table<string, string>
---@return { record: string, environment: table<string, string> }
local function fake_running_hooks(name, extra_environment)
  return claude_session.fake(
    name,
    'ready',
    vim.tbl_extend('force', { AINEO_FAKE_CLAUDE_HOOKS = '1' }, extra_environment or {})
  )
end

--- Opens the layout in `editor` with aineo running `fake`, and waits until
--- Claude Code is ready; returns the session it started on.
---
---@param editor table
---@param fake { environment: table<string, string> }
---@return string
local function open_until_ready(editor, fake)
  entry.use_fake(editor, fake)
  editor.cmd('Aineo open')
  claude_session.wait_for_status(editor, 'ready')
  return claude_session.followed_session_id(editor)
end

T['an editor’s entry'] = MiniTest.new_set()

T['an editor’s entry']['is written at its start’s confirmation, follows a switch, and is gone once the editor quits'] = function()
  local state = share_state(child, fixture.directory('entry-claim-listed'))
  local address = child.v.servername
  local started = open_until_ready(child, fake_running_hooks('entry-claim-listed'))
  local at_start = entry_once(state, child, function(listed)
    return listed ~= nil
  end)

  type_to_claude(child, '/clear\r')
  local after_switch = entry_once(state, child, function(listed)
    return listed ~= nil and listed.session ~= started
  end)
  stop(child)

  eq({
    at_start = at_start and { at_start.session, at_start.own, at_start.working_directory },
    switched = after_switch ~= nil and after_switch.session ~= started and after_switch.own,
    after_quit = entry_at(state, address),
  }, {
    at_start = { started, true, vim.fn.getcwd() },
    switched = true,
  })
end

--- The claim file of `session` under `state`, decoded; nil when there is
--- none.
---
---@param state string
---@param session string
---@return table?
local function claim_of(state, session)
  local path = vim.fs.joinpath(state, 'aineo', 'claims', vim.fn.sha256(session) .. '.json')
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  return vim.json.decode(text)
end

--- The pid of a process that has ended.
---
---@return integer
local function ended_pid()
  local process = vim.system({ 'true' })
  process:wait()
  return process.pid
end

--- More session ids of the form Claude Code gives.
local THIRD_SESSION_ID = '7d0e3a4f-8e1a-4d2f-b5c7-91d0e3a4f853'
local FOURTH_SESSION_ID = '91d0e3a4-f852-4d2f-b5c7-063cc43c8e1a'

T[':Aineo claim'] = MiniTest.new_set()

T[':Aineo claim']['completes to the sessions of Claude Codes running in the directory this Neovim started in, after a :cd too'] = function()
  local state = share_state(child, fixture.directory('entry-claim-complete'))
  local cwd = child.fn.getcwd()
  local mcp = require('aineo.mcp')
  local function record(pid, session, directory)
    mcp.record_server_start(state, {
      pid = pid,
      token = 'token-' .. session,
      session = session,
      working_directory = directory,
    })
  end
  record(vim.fn.getpid(), OTHER_SESSION_ID, cwd)
  record(ended_pid(), THIRD_SESSION_ID, cwd)
  record(vim.uv.os_getppid(), FOURTH_SESSION_ID, '/projects/beta')

  local before = child.fn.getcompletion('Aineo claim ', 'cmdline')
  child.cmd('cd /')
  local after_cd = child.fn.getcompletion('Aineo claim ', 'cmdline')

  eq({ before, after_cd }, { { OTHER_SESSION_ID }, { OTHER_SESSION_ID } })
end

--- The files aineo keeps for the working directory of `editor` under
--- `state`, until a session of its own takes them: Input's draft and the
--- Report's records.
---
---@param editor table
---@param state string
---@return { draft: string, records: string }
local function directory_files(editor, state)
  local name = vim.fn.sha256(editor.fn.getcwd())
  return {
    draft = vim.fs.joinpath(state, 'aineo', 'drafts', name .. '.txt'),
    records = vim.fs.joinpath(state, 'aineo', 'reports', name .. '.jsonl'),
  }
end

--- The files aineo keeps for the Claude session `id` under `state`.
---
---@param state string
---@param id string
---@return { draft: string, records: string }
local function session_files(state, id)
  local name = vim.fn.sha256(id)
  return {
    draft = vim.fs.joinpath(state, 'aineo', 'drafts', 'session-' .. name .. '.txt'),
    records = vim.fs.joinpath(state, 'aineo', 'reports', 'session-' .. name .. '.jsonl'),
  }
end

--- Writes `lines` as the file at `path`, as an earlier editor left it.
---
---@param path string
---@param lines string[]
local function leave_file(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  assert(vim.fn.writefile(lines, path) == 0, 'cannot write ' .. path)
end

--- A records line holding a report of `task`, as an earlier editor kept it.
---
---@param task string
---@return string
local function record_of(task)
  return vim.json.encode({
    time = '2026-10-10T09:05:00',
    report = { task = task, status = 'done', summary = 'Kept' },
  })
end

--- The expression, run in an editor, that gives the Report's lines, each time
--- of day, which starts a header, written `HH:MM`; none while there is no
--- Report.
local REPORT_LINES = [[(function()
  local report = vim.fn.bufnr('aineo://report')
  local lines = report == -1 and {} or vim.api.nvim_buf_get_lines(report, 0, -1, true)
  return vim.tbl_map(function(line)
    return (line:gsub('^%d%d:%d%d ', 'HH:MM '))
  end, lines)
end)()]]

--- The lines of the layout's Input, read in an editor.
local INPUT_LINES =
  "vim.api.nvim_buf_get_lines(require('aineo.layout').input_buffer(), 0, -1, true)"

--- How the Report shows a kept report of `task`.
---
---@param task string
---@return string
local function shown(task)
  return 'HH:MM [done] ' .. task .. ' — Kept'
end

--- `expression`'s value in `editor` once it equals `expected`, waiting for
--- that at most `PATIENCE_MS`; else its value when the wait runs out.
---
---@param editor table
---@param expression string
---@param expected any
---@return any
local function once_equal(editor, expression, expected)
  vim.wait(PATIENCE_MS, function()
    return vim.deep_equal(editor.lua_get(expression), expected)
  end, 20)
  return editor.lua_get(expression)
end

T[':Aineo claim']['with an id, before the first start, leaves the directory’s records and draft, and the start keeps the panes on the claimed session'] = function()
  local state = share_state(child, fixture.directory('entry-claim-before-start'))
  local folder = directory_files(child, state)
  leave_file(folder.records, { record_of('Directory task') })
  leave_file(folder.draft, { 'Directory notes' })
  local claimed = session_files(state, OTHER_SESSION_ID)
  leave_file(claimed.records, { record_of('Claimed task') })
  leave_file(claimed.draft, { 'Claimed notes' })

  child.cmd('Aineo claim ' .. OTHER_SESSION_ID)
  open_until_ready(child, fake_running_hooks('entry-claim-before-start'))

  eq({
    report = once_equal(child, REPORT_LINES, { shown('Claimed task') }),
    input = once_equal(child, INPUT_LINES, { 'Claimed notes' }),
    directory_records = vim.fn.filereadable(folder.records),
    directory_draft = vim.fn.filereadable(folder.draft),
  }, {
    report = { shown('Claimed task') },
    input = { 'Claimed notes' },
    directory_records = 1,
    directory_draft = 1,
  })
end

T[':Aineo claim']['with no word, while a claim of another session holds, returns the panes to this Neovim’s own session, which takes the directory’s records and draft'] = function()
  local state = share_state(child, fixture.directory('entry-claim-return'))
  local folder = directory_files(child, state)
  leave_file(folder.records, { record_of('Directory task') })
  leave_file(folder.draft, { 'Directory notes' })
  local claimed = session_files(state, OTHER_SESSION_ID)
  leave_file(claimed.draft, { 'Claimed notes' })
  child.cmd('Aineo claim ' .. OTHER_SESSION_ID)
  local own = open_until_ready(child, fake_running_hooks('entry-claim-return'))
  once_equal(child, INPUT_LINES, { 'Claimed notes' })
  entry.set_input(child, { 'Claimed notes, edited' })

  child.cmd('Aineo claim')

  eq({
    report = once_equal(child, REPORT_LINES, { shown('Directory task') }),
    input = once_equal(child, INPUT_LINES, { 'Directory notes' }),
    directory_records = vim.fn.filereadable(folder.records),
    claimed_draft = vim.fn.readfile(claimed.draft),
    claim = claim_of(state, own) and claim_of(state, own).address,
    entry = entry_once(state, child, function(listed)
      return listed ~= nil and listed.session == own
    end).own,
  }, {
    report = { shown('Directory task') },
    input = { 'Directory notes' },
    directory_records = 0,
    claimed_draft = { 'Claimed notes, edited' },
    claim = child.v.servername,
    entry = true,
  })
end

T[':Aineo claim']['with no word, while a claim of another session holds, in a Neovim whose Claude Code never started, warns once and changes nothing'] = function()
  local state = share_state(child, fixture.directory('entry-claim-return-none'))
  child.cmd('Aineo claim ' .. OTHER_SESSION_ID)

  child.cmd('Aineo claim')

  eq({
    messages = entry.messages(child),
    claim = claim_of(state, OTHER_SESSION_ID) and claim_of(state, OTHER_SESSION_ID).address,
    following = entry_at(state, child.v.servername).session,
  }, {
    messages = {
      {
        message = 'aineo: Claude Code has not started in this Neovim;'
          .. ' :Aineo claim {id} follows a session, :Aineo open starts Claude Code here',
        level = vim.log.levels.WARN,
      },
    },
    claim = child.v.servername,
    following = OTHER_SESSION_ID,
  })
end

--- Starts, in `host`, a Claude Code whose editor is gone: the fake, running
--- the hooks aineo gives it and keeping its report server for its life,
--- told an address no editor listens on, with `state` as its state
--- directory; returns the fake and the session it started on.
---
---@param host table
---@param state string
---@param name string
---@return { record: string, environment: table<string, string> } fake
---@return string session
local function start_orphaned_claude(host, state, name)
  local gone = vim.fs.joinpath(vim.fs.dirname(state), 'gone.sock')
  local fake = fake_running_hooks(name, { AINEO_FAKE_CLAUDE_MCP = 'kept' })
  local buffer = claude_session.start(host, fake, {
    state_directory = state,
    editor_address = gone,
    mcp_servers = require('aineo.mcp').mcp_servers(gone, vim.v.progpath),
  })
  host.lua('_G.orphaned_terminal = ...', { buffer })
  return fake, claude_session.words_after(claude_session.arguments(fake), '--session-id')[1]
end

--- Types `keys` in the Claude Code `start_orphaned_claude()` started in
--- `host`.
---
---@param host table
---@param keys string
local function type_to_orphan(host, keys)
  claude_session.press_keys(host, host.lua_get('_G.orphaned_terminal'), keys)
end

--- The text of the report tool's answer the fake recorded `count`th, once
--- it has recorded that many past its handshake, waiting at most
--- `PATIENCE_MS`.
---
---@param fake { record: string }
---@param count integer
---@return string?
local function report_answer(fake, count)
  local answers = {}
  vim.wait(PATIENCE_MS, function()
    answers = vim.tbl_filter(function(recorded)
      return type(recorded.mcp) == 'table' and vim.tbl_get(recorded.mcp, 'result', 'content') ~= nil
    end, claude_session.record(fake))
    return #answers >= count
  end, 20)
  return answers[count] and answers[count].mcp.result.content[1].text
end

--- What the report tool answers when the claimant took the report.
local CLAIMANT_TOOK = 'Delivered to the Agent Report of another Neovim that claimed this session.'

--- How the Report shows a report the fake's `/report` key made of `task`.
---
---@param task string
---@return string
local function reported(task)
  return 'HH:MM [done] ' .. task .. ' — All tests pass'
end

T['a claim of a session whose editor is gone'] = MiniTest.new_set()

T['a claim of a session whose editor is gone']['shows its kept reports and gets its next, and follows it, still claimed, across a /clear'] = function()
  local home = fixture.directory('entry-claim-orphan')
  local state = share_state(child, home)
  children.restart(other)
  share_state(other, home)
  local fake, session = start_orphaned_claude(other, state, 'entry-claim-orphan')
  report_answer(fake, 0)
  type_to_orphan(other, '/report Kept before the claim\r')
  report_answer(fake, 1)
  open_until_ready(child, fake_running_hooks('entry-claim-orphan-own'))

  child.cmd('Aineo claim ' .. session)
  local kept = once_equal(child, REPORT_LINES, { reported('Kept before the claim') })
  type_to_orphan(other, '/report Sent to the claimant\r')
  local answer = report_answer(fake, 2)
  type_to_orphan(other, '/clear\r')
  local moved = entry_once(state, child, function(listed)
    return listed ~= nil and listed.session ~= session
  end)
  type_to_orphan(other, '/report After the clear\r')

  eq({
    kept = kept,
    answer = answer,
    moved = moved and { moved.own, claim_of(state, moved.session).address },
    after_clear = report_answer(fake, 3),
    report = once_equal(child, REPORT_LINES, { reported('After the clear') }),
  }, {
    kept = { reported('Kept before the claim') },
    answer = CLAIMANT_TOOK,
    moved = { false, child.v.servername },
    after_clear = CLAIMANT_TOOK,
    report = { reported('After the clear') },
  })
end

T['a claim of a session whose editor is gone']['wins over a Neovim used later that shows the session as its own, until that one claims it; then, once it quits, the reports come back'] = function()
  local home = fixture.directory('entry-claim-precedence')
  local state = share_state(child, home)
  children.restart(other)
  share_state(other, home)
  local host = MiniTest.new_child_neovim()
  MiniTest.finally(function()
    stop(host)
  end)
  children.restart(host)
  share_state(host, home)
  local fake, session = start_orphaned_claude(host, state, 'entry-claim-precedence')
  report_answer(fake, 0)
  entry.restart(other)
  share_state(other, home)
  local own = open_until_ready(other, fake_running_hooks('entry-claim-precedence-own'))
  child.cmd('Aineo claim ' .. session)
  other.api.nvim_exec_autocmds('FocusGained', {})

  type_to_orphan(host, '/report While claimed\r')
  local while_claimed = report_answer(fake, 1)
  local claimant_lines = once_equal(child, REPORT_LINES, { reported('While claimed') })
  other.cmd('Aineo claim')
  type_to_orphan(host, '/report Claimed by the other\r')
  local by_other = report_answer(fake, 2)
  stop(other)
  type_to_orphan(host, '/report After the other quit\r')

  eq({
    own = own,
    while_claimed = while_claimed,
    claimant_lines = claimant_lines,
    by_other = by_other,
    after_quit = report_answer(fake, 3),
    lines = once_equal(child, REPORT_LINES, {
      reported('While claimed'),
      reported('After the other quit'),
    }),
  }, {
    own = session,
    while_claimed = CLAIMANT_TOOK,
    claimant_lines = { reported('While claimed') },
    by_other = CLAIMANT_TOOK,
    after_quit = 'Delivered to the Agent Report of another Neovim that shows this session,'
      .. ' because the one Claude Code started in is gone or follows another session.',
    lines = { reported('While claimed'), reported('After the other quit') },
  })
end

T['a claim of a session whose editor answers'] = MiniTest.new_set()

T['a claim of a session whose editor answers']['follows its Claude Code to the session of a /clear and gets the next report, the starting editor following it as its own'] = function()
  local home = fixture.directory('entry-claim-answering')
  local state = share_state(child, home)
  entry.restart(other)
  share_state(other, home)
  local fake = fake_running_hooks('entry-claim-answering', { AINEO_FAKE_CLAUDE_MCP = 'kept' })
  local session = open_until_ready(other, fake)
  report_answer(fake, 0)
  child.cmd('Aineo claim ' .. session)

  type_to_claude(other, '/clear\r')
  local moved = entry_once(state, child, function(listed)
    return listed ~= nil and listed.session ~= session
  end)
  type_to_claude(other, '/report After the clear\r')

  eq({
    moved = moved and moved.session == claude_session.followed_session_id(other),
    claimant = moved and claim_of(state, moved.session).address,
    starting = entry_at(state, other.v.servername).own,
    answer = report_answer(fake, 1),
    lines = once_equal(child, REPORT_LINES, { reported('After the clear') }),
  }, {
    moved = true,
    claimant = child.v.servername,
    starting = true,
    answer = CLAIMANT_TOOK,
    lines = { reported('After the clear') },
  })
end

T[':Aineo claim']['completes to the session of a Claude Code started without aineo’s hooks, which its report server recorded'] = function()
  share_state(child, fixture.directory('entry-claim-no-hooks'))
  local fake =
    claude_session.fake('entry-claim-no-hooks', 'ready', { AINEO_FAKE_CLAUDE_MCP = 'kept' })
  local session = open_until_ready(child, fake)
  report_answer(fake, 0)

  eq(child.fn.getcompletion('Aineo claim ', 'cmdline'), { session })
end

T['a claim of another session'] = MiniTest.new_set()

T['a claim of another session']['keeps the panes where they are at a /clear of this Neovim’s own Claude Code, which is kept for the directory; :Aineo claim with its own id brings them back'] = function()
  local state = share_state(child, fixture.directory('entry-claim-own-switch'))
  local claimed = session_files(state, OTHER_SESSION_ID)
  leave_file(claimed.draft, { 'Claimed notes' })
  local started = open_until_ready(child, fake_running_hooks('entry-claim-own-switch'))
  child.cmd('Aineo claim ' .. OTHER_SESSION_ID)
  once_equal(child, INPUT_LINES, { 'Claimed notes' })

  type_to_claude(child, '/clear\r')
  vim.wait(PATIENCE_MS, function()
    return claude_session.followed_session_id(child) ~= started
  end, 20)
  local switched = claude_session.followed_session_id(child)
  local held = {
    input = child.lua_get(INPUT_LINES),
    following = entry_at(state, child.v.servername).session,
  }
  child.cmd('Aineo claim ' .. switched)

  eq({
    held = held,
    switched = switched ~= started,
    kept_for_directory = vim.fn.readfile(
      vim.fs.joinpath(state, 'aineo', 'claude-sessions', vim.fn.sha256(child.fn.getcwd()) .. '.txt')
    ),
    back = entry_once(state, child, function(listed)
      return listed ~= nil and listed.session == switched
    end).own,
  }, {
    held = { input = { 'Claimed notes' }, following = OTHER_SESSION_ID },
    switched = true,
    kept_for_directory = { switched },
    back = true,
  })
end

T['an editor’s entry']['is marked used again when the editor gains focus'] = function()
  local state = share_state(child, fixture.directory('entry-claim-focus'))
  child.cmd('Aineo claim ' .. OTHER_SESSION_ID)
  local before = entry_at(state, child.v.servername).used

  child.api.nvim_exec_autocmds('FocusGained', {})

  eq(entry_at(state, child.v.servername).used > before, true)
end

T['an editor’s entry']['is not written again once the editor quits, though a switch is told to it while aineo stops its Claude Code'] = function()
  local state = share_state(child, fixture.directory('entry-claim-exiting'))
  local address = child.v.servername
  child.cmd('Aineo claim ' .. OTHER_SESSION_ID)
  open_until_ready(child, fake_running_hooks('entry-claim-exiting'))

  child.lua_notify('vim.cmd("qall!")')
  local served = vim.wait(PATIENCE_MS, function()
    local connected, channel = pcall(vim.fn.sockconnect, 'pipe', address, { rpc = true })
    if not connected then
      return false
    end
    local told = pcall(
      vim.rpcrequest,
      channel,
      'nvim_exec_lua',
      [[
        if vim.v.exiting == vim.NIL then
          return false
        end
        require('aineo.mcp').receive_followed_switch(...)
        return true
      ]],
      { OTHER_SESSION_ID, THIRD_SESSION_ID }
    )
    pcall(vim.fn.chanclose, channel)
    return told
  end, 10)
  vim.wait(claude_session.STOP_PATIENCE_MS, function()
    return vim.uv.fs_stat(address) == nil
  end, 20)

  eq({
    served = served,
    entry = entry_at(state, address),
    claims = vim.fn.glob(vim.fs.joinpath(state, 'aineo', 'claims', '*'), true, true),
  }, { served = true, claims = {} })
end

T['\\s'] = MiniTest.new_set()

--- What Send tells the user while this Neovim, whose own Claude terminal runs
--- a session, follows `OTHER_SESSION_ID` by a claim.
local REFUSED_WHILE_CLAIMED = {
  message = 'aineo: nothing sent — Input holds the draft of the claimed session '
    .. OTHER_SESSION_ID
    .. '; :Aineo claim with no argument returns this Neovim to its own session',
  level = vim.log.levels.WARN,
}

T['\\s']['sends nothing while a claim of another session holds, in Normal and Visual mode and by :Aineo send, and says why'] = function()
  share_state(child, fixture.directory('entry-claim-send'))
  open_until_ready(child, fake_running_hooks('entry-claim-send'))
  child.cmd('Aineo claim ' .. OTHER_SESSION_ID)
  once_equal(child, INPUT_LINES, { '' })
  entry.set_input(child, { 'notes for the claimed session' })
  send.watch_writes(child)
  child.lua('_G.entry_test_messages = {}')
  send.enter_input(child)

  send.type_keys(child, '\\s')
  child.cmd('Aineo send')
  send.type_keys(child, 'ggV\\s')
  local mode = child.fn.mode()
  send.type_keys(child, 'gv')

  eq({
    writes = send.writes(child),
    input = child.lua_get(INPUT_LINES),
    messages = entry.messages(child),
    mode = mode,
    reselected = child.fn.mode(),
  }, {
    writes = {},
    input = { 'notes for the claimed session' },
    messages = { REFUSED_WHILE_CLAIMED, REFUSED_WHILE_CLAIMED, REFUSED_WHILE_CLAIMED },
    mode = 'n',
    reselected = 'V',
  })
end

T['\\s']['sends nothing in a Neovim whose Claude Code never started while it follows a claimed session, naming what works there'] = function()
  share_state(child, fixture.directory('entry-claim-send-none'))
  child.cmd('Aineo claim ' .. OTHER_SESSION_ID)

  child.cmd('Aineo send')

  eq(entry.messages(child), {
    {
      message = 'aineo: nothing sent — Input holds the draft of the claimed session '
        .. OTHER_SESSION_ID
        .. '; :Aineo claim {id} follows another session, :Aineo open starts Claude Code here',
      level = vim.log.levels.WARN,
    },
  })
end

T['\\s']['sends as before once :Aineo claim with no word has returned this Neovim to its own session'] = function()
  share_state(child, fixture.directory('entry-claim-send-returned'))
  open_until_ready(child, fake_running_hooks('entry-claim-send-returned'))
  child.cmd('Aineo claim ' .. OTHER_SESSION_ID)
  child.cmd('Aineo claim')
  entry.set_input(child, { 'hello' })
  send.watch_writes(child)

  child.cmd('Aineo send')

  eq(send.writes(child), { '\27[200~hello\27[201~\r' })
end

T['\\s']['sends as before after :Aineo claim with no word in a Neovim that follows its own session'] = function()
  share_state(child, fixture.directory('entry-claim-send-own'))
  open_until_ready(child, fake_running_hooks('entry-claim-send-own'))
  child.cmd('Aineo claim')
  entry.set_input(child, { 'hello' })
  send.watch_writes(child)

  child.cmd('Aineo send')

  eq(send.writes(child), { '\27[200~hello\27[201~\r' })
end

T[':Aineo claim']['with more than one word tells the user it takes at most one'] = function()
  child.cmd('Aineo claim ' .. OTHER_SESSION_ID .. ' extra')

  eq(entry.messages(child), {
    {
      message = 'aineo: :Aineo claim takes at most one Claude session id',
      level = vim.log.levels.ERROR,
    },
  })
end

T[':Aineo claim']['with what is no session id errs once, naming it, and changes nothing'] = function()
  local state = share_state(child, fixture.directory('entry-claim-malformed'))

  entry.command(child, 'Aineo claim not-a-session')

  eq({
    messages = entry.messages(child),
    claims = vim.fn.glob(vim.fs.joinpath(state, 'aineo', 'claims', '*'), true, true),
    entry = entry_at(state, child.v.servername),
  }, {
    messages = {
      {
        message = 'aineo: :Aineo claim takes a Claude session id, not not-a-session',
        level = vim.log.levels.ERROR,
      },
    },
    claims = {},
  })
end

T[':Aineo claim']['with no word in a Neovim whose Claude Code never started warns once and records nothing'] = function()
  local state = share_state(child, fixture.directory('entry-claim-no-session'))

  child.cmd('Aineo claim')

  eq({
    messages = entry.messages(child),
    claims = vim.fn.glob(vim.fs.joinpath(state, 'aineo', 'claims', '*'), true, true),
    entry = entry_at(state, child.v.servername),
  }, {
    messages = {
      {
        message = 'aineo: Claude Code has not started in this Neovim;'
          .. ' :Aineo claim {id} follows a session, :Aineo open starts Claude Code here',
        level = vim.log.levels.WARN,
      },
    },
    claims = {},
  })
end

return T
