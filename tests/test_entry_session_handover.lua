local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- A second aineo editor, beside the child, with a Claude Code of its own.
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

--- Stops `editor`, once the fake Claude Code it runs, if any, has ended by
--- a hangup (`END_TERMINALS`): Neovim quitting then has no Claude Code for
--- aineo to stop by its keys, a stop that waits some 4.4 s for the fake to
--- exit once it reads its keys.
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

--- How long a case waits for a file to hold what it waits for: longer than
--- the second after which Input's draft is saved, and than a start's
--- confirmation after a resume with no conversation, about 3 s.
local FILE_PATIENCE_MS = 8000

--- The lines of the layout's Input, read in an editor.
local INPUT_LINES =
  "vim.api.nvim_buf_get_lines(require('aineo.layout').input_buffer(), 0, -1, true)"

--- The expression, run in an editor, that gives the Report's lines, each
--- time of day, which starts a header, written `HH:MM`.
local REPORT_LINES = [[vim.tbl_map(function(line)
  return (line:gsub('^%d%d:%d%d ', 'HH:MM '))
end, vim.api.nvim_buf_get_lines(vim.fn.bufnr('aineo://report'), 0, -1, true))]]

--- Gives `editor` the git isolation of the git home's suites
--- (`git_repo.ENVIRONMENT`) and `state_home` as `XDG_STATE_HOME`, and moves
--- its working directory into `directory`, where Claude Code starts.
---
---@param editor table
---@param directory string
---@param state_home string
local function enter(editor, directory, state_home)
  editor.lua('for name, value in pairs(...) do vim.env[name] = value end', {
    vim.tbl_extend('force', git_repo.ENVIRONMENT, { XDG_STATE_HOME = state_home }),
  })
  editor.cmd('cd ' .. vim.fn.fnameescape(directory))
end

--- Makes the repository `.tests/fixtures/git-<name>/repo` holding one file
--- in one commit and the state directory `.tests/fixtures/<name>-state`,
--- and has the child enter them (`enter()`); returns the repository's top
--- level, its commit, the child's state directory, `stdpath('state')`, and
--- the `XDG_STATE_HOME` it is under.
---
---@param name string the case's own name, starting `session-handover-`
---@return string top
---@return string base
---@return string state
---@return string state_home
local function in_repository(name)
  local top, base = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  local state_home = fixture.directory(name .. '-state')
  enter(child, top, state_home)
  return top, base, vim.fs.joinpath(state_home, 'nvim'), state_home
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

--- The kinds of the files aineo keeps for the Claude session `id` under
--- `state` that are there (`session_files()`), by kind.
---
---@param state string
---@param id string
---@return table<string, true>
local function files_left(state, id)
  local left = {}
  for kind, path in pairs(session_files(state, id)) do
    if vim.uv.fs_stat(path) then
      left[kind] = true
    end
  end
  return left
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

--- Writes `lines` as the file at `path`, as an earlier editor left it.
---
---@param path string
---@param lines string[]
local function leave_file(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  assert(vim.fn.writefile(lines, path) == 0, 'cannot write ' .. path)
end

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

--- One report, kept as an earlier editor kept it, and how the Report shows
--- it.
local EARLIER_RECORD =
  '{"time":"2026-10-08T09:05:00","report":{"task":"Earlier task","status":"done","summary":"Kept"}}'
local EARLIER_REPORT = 'HH:MM [done] Earlier task — Kept'

--- A session id of the form Claude Code gives, kept for a directory, that
--- Claude Code has no conversation for.
local DEAD_SESSION_ID = '7d0e3a4f-8e1a-4d2f-b5c7-91d0e3a4f853'

--- Leaves, under `state`, what an earlier editor kept for the session `id`
--- in the repository `top`: `draft` as Input's draft, one report
--- (`EARLIER_RECORD`), and `base` as the changes pane's base, with
--- `notes.txt` saved.
---
---@param state string
---@param id string
---@param top string
---@param base string
---@param draft string
local function leave_session(state, id, top, base, draft)
  local kept = session_files(state, id)
  leave_file(kept.draft, { draft })
  leave_file(kept.records, { EARLIER_RECORD })
  leave_file(kept.base, { vim.json.encode({ top = top, base = base, saved = { 'notes.txt' } }) })
end

--- A fake `claude` for one case, in its `ready` mode, that keeps
--- conversations as Claude Code does (`AINEO_FAKE_CLAUDE_CONVERSATIONS`), in
--- a directory of its own that holds none yet — a resume of any id kept
--- before finds no conversation — with `extra_environment` on top.
---
---@param name string the case's own name for its files
---@param extra_environment? table<string, string>
---@return { record: string, environment: table<string, string> }
local function fake_with_no_conversation(name, extra_environment)
  return claude_session.fake(
    name,
    'ready',
    vim.tbl_extend('force', {
      AINEO_FAKE_CLAUDE_CONVERSATIONS = fixture.directory(name .. '-conversations'),
    }, extra_environment or {})
  )
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
--- else whether it does when the wait runs out.
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

--- The names of the changes pane's buffers.
local FILES = 'aineo://changes-files'
local COMMITS = 'aineo://changes-commits'

--- How the commits window lists `commit`, made with the subject `subject`.
---
---@param commit string
---@param subject string
---@return string
local function commit_line(commit, subject)
  return commit:sub(1, 7) .. ' ' .. subject
end

T['a resume with no conversation'] = MiniTest.new_set()

T['a resume with no conversation']['in a new editor shows the dead session’s draft, Report and changes base under the session that took its place, leaving no file under the dead id'] = function()
  local top, base, state = in_repository('session-handover-new-editor')
  keep_session_id(state, top, DEAD_SESSION_ID)
  leave_session(state, DEAD_SESSION_ID, top, base, 'notes for the dead session')
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')
  local fake = fake_with_no_conversation('session-handover-new-editor')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')

  claude_session.wait_for_starts(fake, 2)
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\pc')

  eq({
    input = child.lua_get(INPUT_LINES),
    report = child.lua_get(REPORT_LINES),
    listed = lists_once(COMMITS, commit_line(commit, 'Write two'), true),
    marked = lists_once(FILES, '* M notes.txt', true),
    dead = files_left(state, DEAD_SESSION_ID),
  }, {
    input = { 'notes for the dead session' },
    report = { EARLIER_REPORT },
    listed = true,
    marked = true,
    dead = {},
  })
end

--- The id of the session `editor`'s Claude home follows.
---
---@param editor table
---@return string
local function followed_session(editor)
  return claude_session.followed_session_id(editor)
end

--- The expression, run in an editor, that gives the terminal whose Claude
--- Code still runs.
local RUNNING_CLAUDE_TERMINAL = [[vim.iter(vim.api.nvim_list_bufs()):find(function(buffer)
  return vim.bo[buffer].buftype == 'terminal'
    and vim.fn.jobwait({ vim.b[buffer].terminal_job_id }, 0)[1] == -1
end)]]

--- Types `keys` in `editor`'s running Claude Code, as a user typing in
--- Claude's window would.
---
---@param editor table
---@param keys string
local function type_to_claude(editor, keys)
  claude_session.press_keys(editor, editor.lua_get(RUNNING_CLAUDE_TERMINAL), keys)
end

--- Types `/clear` and Enter in `editor`'s running Claude Code and waits, at
--- most `FILE_PATIENCE_MS`, until its Claude home follows another session;
--- returns the session it follows then.
---
---@param editor table
---@return string
local function clear(editor)
  local before = followed_session(editor)
  type_to_claude(editor, '/clear\r')
  vim.wait(FILE_PATIENCE_MS, function()
    return followed_session(editor) ~= before
  end, 20)
  return followed_session(editor)
end

--- Writes `text` as the only line of the file `path` from a hidden buffer of
--- `editor`, as `:write` does, which the changes pane marks as a save.
---
---@param editor table
---@param path string
---@param text string
local function save_in(editor, path, text)
  editor.lua(
    [[
      local path, text = ...
      local buffer = vim.fn.bufadd(path)
      vim.fn.bufload(buffer)
      vim.api.nvim_buf_set_lines(buffer, 0, -1, true, { text })
      vim.api.nvim_buf_call(buffer, function()
        vim.cmd('silent write')
      end)
    ]],
    { path, text }
  )
end

--- Ends `editor`'s Claude Code by a hangup and waits until its Claude home
--- says it has exited.
---
---@param editor table
local function end_claude(editor)
  editor.lua(END_TERMINALS)
  claude_session.wait_for_status(editor, 'exited')
end

--- A fake `claude` that keeps conversations (`fake_with_no_conversation()`)
--- and runs the session hooks aineo gives it (`AINEO_FAKE_CLAUDE_HOOKS`).
---
---@param name string
---@return { record: string, environment: table<string, string> }
local function fake_running_hooks(name)
  return fake_with_no_conversation(name, { AINEO_FAKE_CLAUDE_HOOKS = '1' })
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
  return followed_session(editor)
end

--- Makes, in the child, the session of a `/clear` in which nothing was
--- sent, after a message sent in the first session, with `notes` typed in
--- Input and `notes.txt` of `top` saved; then ends Claude Code and presses
--- `\o`, whose resume of that session finds no conversation. Returns that
--- session's id once the start that took its place has launched (the
--- fake's third start), before it is ready.
---
---@param top string
---@param fake { record: string, environment: table<string, string> }
---@param notes string[]
---@return string dead
local function resume_a_cleared_session(top, fake, notes)
  open_until_ready(child, fake)
  type_to_claude(child, 'a message\r')
  local dead = clear(child)
  entry.set_input(child, notes)
  save_in(child, vim.fs.joinpath(top, 'notes.txt'), 'two')
  end_claude(child)
  entry.press(child, '\\o')
  claude_session.wait_for_starts(fake, 3)
  return dead
end

T['a resume with no conversation']['in the same editor keeps Input’s text and the changes pane’s marks under the session that took its place'] = function()
  local top, _, state = in_repository('session-handover-same-editor')
  local fake = fake_running_hooks('session-handover-same-editor')
  local dead = resume_a_cleared_session(top, fake, { 'notes after the clear' })
  local at_fallback = child.lua_get(INPUT_LINES)
  entry.set_input(child, { 'notes after the clear', 'typed while it starts' })

  claude_session.wait_for_status(child, 'ready')
  local fresh = followed_session(child)
  entry.press(child, '\\pc')

  eq({
    at_fallback = at_fallback,
    at_ready = child.lua_get(INPUT_LINES),
    draft = text_once_written(
      session_files(state, fresh).draft,
      'notes after the clear\ntyped while it starts\n'
    ),
    marked = lists_once(FILES, '* M notes.txt', true),
    dead = files_left(state, dead),
  }, {
    at_fallback = { 'notes after the clear' },
    at_ready = { 'notes after the clear', 'typed while it starts' },
    draft = 'notes after the clear\ntyped while it starts\n',
    marked = true,
    dead = {},
  })
end

T['a resume with no conversation']['whose new session is stopped before it is ready passes the dead session’s draft on to the next'] = function()
  local top, base, state = in_repository('session-handover-chain')
  keep_session_id(state, top, DEAD_SESSION_ID)
  leave_session(state, DEAD_SESSION_ID, top, base, 'notes for the dead session')
  local fake = fake_with_no_conversation('session-handover-chain')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_starts(fake, 2)
  end_claude(child)

  entry.press(child, '\\o')
  claude_session.wait_for_starts(fake, 4)
  claude_session.wait_for_status(child, 'ready')

  eq({
    input = child.lua_get(INPUT_LINES),
    draft = read_file(session_files(state, followed_session(child)).draft),
    dead = files_left(state, DEAD_SESSION_ID),
  }, {
    input = { 'notes for the dead session' },
    draft = 'notes for the dead session\n',
    dead = {},
  })
end

T['a resume with no conversation']['is not a start in another directory: the session left keeps its draft, records and base'] = function()
  local top, _, state = in_repository('session-handover-elsewhere')
  local first = open_until_ready(child, claude_session.fake('session-handover-elsewhere', 'ready'))
  entry.set_input(child, { 'notes for the first session' })
  local kept_draft =
    text_once_written(session_files(state, first).draft, 'notes for the first session\n')
  save_in(child, vim.fs.joinpath(top, 'notes.txt'), 'two')
  end_claude(child)
  child.cmd('cd ' .. vim.fn.fnameescape(fixture.directory('session-handover-elsewhere-cd')))

  entry.press(child, '\\o')
  claude_session.wait_for_status(child, 'ready')
  local second = followed_session(child)

  eq({
    kept_draft = kept_draft,
    second_is_new = second ~= first,
    input = child.lua_get(INPUT_LINES),
    first = files_left(state, first),
    second = files_left(state, second),
  }, {
    kept_draft = 'notes for the first session\n',
    second_is_new = true,
    input = { '' },
    first = { draft = true, base = true },
    second = {},
  })
end

T['a resume with no conversation']['is not a restart on a session with a conversation, which keeps its own'] = function()
  local _, _, state = in_repository('session-handover-conversation')
  local fake = fake_with_no_conversation('session-handover-conversation')
  local first = open_until_ready(child, fake)
  type_to_claude(child, 'a message\r')
  entry.set_input(child, { 'notes for the session' })
  text_once_written(session_files(state, first).draft, 'notes for the session\n')
  end_claude(child)

  entry.press(child, '\\o')
  claude_session.wait_for_starts(fake, 2)
  claude_session.wait_for_status(child, 'ready')

  eq({
    followed = followed_session(child),
    input = child.lua_get(INPUT_LINES),
    draft = read_file(session_files(state, first).draft),
  }, {
    followed = first,
    input = { 'notes for the session' },
    draft = 'notes for the session\n',
  })
end

--- The entry the list of running editors under `state` keeps for `editor`,
--- decoded, once `is_wanted` accepts it, waiting at most
--- `FILE_PATIENCE_MS`; else what it is when the wait runs out, nil when
--- there is none.
---
---@param state string
---@param editor table
---@param is_wanted fun(candidate: table?): boolean
---@return table?
local function entry_once(state, editor, is_wanted)
  local path =
    vim.fs.joinpath(state, 'aineo', 'editors', vim.fn.sha256(editor.v.servername) .. '.json')
  local function decoded()
    local text = read_file(path)
    return text and vim.json.decode(text)
  end
  vim.wait(FILE_PATIENCE_MS, function()
    return is_wanted(decoded())
  end, 20)
  return decoded()
end

--- A session id of the form Claude Code gives, for a session this Neovim
--- claims and its own Claude Code does not run.
local CLAIMED_SESSION_ID = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'

T['a resume with no conversation']['while a claim of another session holds moves the dead session’s files, the panes staying on the claimed session'] = function()
  local top, base, state = in_repository('session-handover-claimed-other')
  keep_session_id(state, top, DEAD_SESSION_ID)
  leave_session(state, DEAD_SESSION_ID, top, base, 'notes for the dead session')
  leave_file(session_files(state, CLAIMED_SESSION_ID).draft, { 'notes for the claimed session' })
  local fake = fake_with_no_conversation('session-handover-claimed-other')
  entry.use_fake(child, fake)
  child.cmd('Aineo claim ' .. CLAIMED_SESSION_ID)
  child.cmd('Aineo open')

  claude_session.wait_for_starts(fake, 2)
  claude_session.wait_for_status(child, 'ready')
  local fresh = followed_session(child)
  local editor_entry = entry_once(state, child, function(candidate)
    return candidate ~= nil
  end)

  eq({
    input = child.lua_get(INPUT_LINES),
    listed = editor_entry and { editor_entry.session, editor_entry.own },
    fresh = read_file(session_files(state, fresh).draft),
    dead = files_left(state, DEAD_SESSION_ID),
  }, {
    input = { 'notes for the claimed session' },
    listed = { CLAIMED_SESSION_ID, false },
    fresh = 'notes for the dead session\n',
    dead = {},
  })
end

T['a resume with no conversation']['of a session whose Claude Code still runs in another Neovim hands nothing over, after a :cd into that Neovim’s directory too'] = function()
  local name = 'session-handover-running'
  local parent = fixture.directory(name)
  local directory = vim.fs.joinpath(parent, 'sub')
  vim.fn.mkdir(directory, 'p')
  local state_home = fixture.directory(name .. '-state')
  local state = vim.fs.joinpath(state_home, 'nvim')
  entry.restart(other)
  enter(other, directory, state_home)
  local running = open_until_ready(other, fake_running_hooks(name .. '-other'))
  entry.set_input(other, { 'notes of the running session' })
  local kept_draft =
    text_once_written(session_files(state, running).draft, 'notes of the running session\n')
  enter(child, parent, state_home)
  open_until_ready(child, fake_with_no_conversation(name))
  end_claude(child)
  child.cmd('cd ' .. vim.fn.fnameescape(directory))

  local fake = fake_with_no_conversation(name .. '-resume')
  entry.use_fake(child, fake)
  entry.press(child, '\\o')
  claude_session.wait_for_starts(fake, 2)
  claude_session.wait_for_status(child, 'ready')

  eq({
    kept_draft = kept_draft,
    resumed = claude_session.words_after(claude_session.start_arguments(fake, 1), '--resume'),
    running = files_left(state, running),
    fresh = files_left(state, followed_session(child)),
  }, {
    kept_draft = 'notes of the running session\n',
    resumed = { running },
    running = { draft = true },
    fresh = {},
  })
end

--- Makes, in the child, the session of a `/clear` in which nothing was
--- sent, after a message sent in the first session; then ends Claude Code
--- and presses `\o` with the fake in its `trust` mode, so that the session
--- taking the place of the resume, which finds no conversation, is never
--- ready. Returns the cleared session's id once that start has launched.
---
---@param fake { record: string, environment: table<string, string> }
---@return string dead
local function resume_a_cleared_session_never_ready(fake)
  open_until_ready(child, fake)
  type_to_claude(child, 'a message\r')
  local dead = clear(child)
  end_claude(child)
  child.lua("vim.env.AINEO_FAKE_CLAUDE_MODE = 'trust'")
  entry.press(child, '\\o')
  claude_session.wait_for_starts(fake, 3)
  return dead
end

T['a resume with no conversation']['in the same editor lists this Neovim under the session that took its place before that session is ready'] = function()
  local _, _, state = in_repository('session-handover-entry')
  local fake = fake_running_hooks('session-handover-entry')
  local dead = resume_a_cleared_session_never_ready(fake)
  local fresh = followed_session(child)

  local editor_entry = entry_once(state, child, function(candidate)
    return candidate ~= nil and candidate.session == fresh
  end)

  eq({
    fresh_is_new = fresh ~= dead,
    session = editor_entry and editor_entry.session,
    own = editor_entry and editor_entry.own,
    status = child.lua_get("require('aineo.claude').session_status()"),
  }, { fresh_is_new = true, session = fresh, own = true, status = 'starting' })
end

--- The editor the claim file of `session` under `state` names, once it no
--- longer names `address`, waiting at most `FILE_PATIENCE_MS`; else the
--- one it names when the wait runs out; nil when there is no claim file.
---
---@param state string
---@param session string
---@param address string
---@return string?
local function claimant_once_not(state, session, address)
  local path = vim.fs.joinpath(state, 'aineo', 'claims', vim.fn.sha256(session) .. '.json')
  local function claimant()
    local text = read_file(path)
    return text and vim.json.decode(text).address
  end
  vim.wait(FILE_PATIENCE_MS, function()
    return claimant() ~= address
  end, 20)
  return claimant()
end

T['a resume with no conversation']['in the same editor lets go this Neovim’s claim of the dead session, made with no word'] = function()
  local _, _, state = in_repository('session-handover-claim-own')
  local fake = fake_running_hooks('session-handover-claim-own')
  open_until_ready(child, fake)
  type_to_claude(child, 'a message\r')
  local dead = clear(child)
  child.cmd('Aineo claim')
  local claimant_before = claimant_once_not(state, dead, nil)
  end_claude(child)
  child.lua("vim.env.AINEO_FAKE_CLAUDE_MODE = 'trust'")

  entry.press(child, '\\o')
  claude_session.wait_for_starts(fake, 3)

  eq({
    before = claimant_before,
    after = claimant_once_not(state, dead, child.v.servername),
    status = child.lua_get("require('aineo.claude').session_status()"),
  }, { before = child.v.servername, status = 'starting' })
end

T['a resume with no conversation']['of a session this Neovim claimed by its id lets the claim go, and the panes follow the session that took its place as this Neovim’s own'] = function()
  local top, base, state = in_repository('session-handover-claim-id')
  keep_session_id(state, top, DEAD_SESSION_ID)
  leave_session(state, DEAD_SESSION_ID, top, base, 'notes for the dead session')
  local fake = fake_with_no_conversation('session-handover-claim-id')
  entry.use_fake(child, fake)
  child.cmd('Aineo claim ' .. DEAD_SESSION_ID)
  local claimant_before = claimant_once_not(state, DEAD_SESSION_ID, nil)

  child.cmd('Aineo open')
  claude_session.wait_for_starts(fake, 2)
  claude_session.wait_for_status(child, 'ready')
  local fresh = followed_session(child)
  local editor_entry = entry_once(state, child, function(candidate)
    return candidate ~= nil and candidate.session == fresh and candidate.own
  end)

  eq({
    before = claimant_before,
    after = claimant_once_not(state, DEAD_SESSION_ID, child.v.servername),
    listed = editor_entry and { editor_entry.session, editor_entry.own },
    input = child.lua_get(INPUT_LINES),
  }, {
    before = child.v.servername,
    listed = { fresh, true },
    input = { 'notes for the dead session' },
  })
end

--- The expression, run in an editor, that gives the cursor of the window
--- showing the Report.
local REPORT_CURSOR = "vim.api.nvim_win_get_cursor(vim.fn.bufwinid('aineo://report'))"

T['a resume with no conversation']['of a session this Neovim claimed by its id leaves Input’s undo and the Report’s cursor as they were through the new session’s confirmation'] = function()
  local top, base, state = in_repository('session-handover-claim-id-undo')
  keep_session_id(state, top, DEAD_SESSION_ID)
  leave_session(state, DEAD_SESSION_ID, top, base, 'notes for the dead session')
  local fake = fake_with_no_conversation('session-handover-claim-id-undo')
  entry.use_fake(child, fake)
  child.cmd('Aineo claim ' .. DEAD_SESSION_ID)
  child.cmd('Aineo open')
  claude_session.wait_for_starts(fake, 2)
  child.lua("vim.api.nvim_win_set_cursor(vim.fn.bufwinid('aineo://report'), { 1, 4 })")
  child.cmd('Aineo input')
  child.type_keys('A', ' and more', '<Esc>')
  local before_ready = {
    status = child.lua_get("require('aineo.claude').session_status()"),
    input = child.lua_get(INPUT_LINES),
  }

  claude_session.wait_for_status(child, 'ready')
  local cursor = child.lua_get(REPORT_CURSOR)
  child.type_keys('u')

  eq({ before_ready = before_ready, cursor = cursor, undone = child.lua_get(INPUT_LINES) }, {
    before_ready = { status = 'starting', input = { 'notes for the dead session and more' } },
    cursor = { 1, 4 },
    undone = { 'notes for the dead session' },
  })
end

return T
