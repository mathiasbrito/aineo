local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude = dofile('tests/helpers/claude_session.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

--- The session kept for the folder in these cases, and another session.
local KEPT_ID = '0f9e7c2a-1b3d-4e5f-8a9b-0c1d2e3f4a5b'
local OTHER_ID = '7c1d9e3a-5b2f-4a6c-9d8e-1f0a2b3c4d5e'

--- What aineo tells the user when the kept session is open in another
--- interactive Claude Code, with the level it tells it at (`WARN`).
local ALSO_OPEN_WARNING = 'aineo: this session is also open in another Claude Code'
local WARN = vim.log.levels.WARN

--- How long a case waits, after a list has answered, to be sure that no
--- Claude Code launched.
local NO_LAUNCH_WINDOW_MS = 800

--- An entry of `claude agents --json` as Claude Code 2.1.296 documents it,
--- for the kept session as an interactive session that runs, with
--- `overrides` on top.
---
---@param overrides? table
---@return table
local function interactive_entry(overrides)
  return vim.tbl_extend('force', {
    cwd = '/work/project',
    kind = 'interactive',
    startedAt = 1790000000000,
    sessionId = KEPT_ID,
    name = 'refactor',
    pid = 4242,
    status = 'idle',
  }, overrides or {})
end

--- An entry for the kept session as a background session that runs.
---
---@param overrides? table
---@return table
local function background_entry(overrides)
  return vim.tbl_extend('force', {
    id = 'a1b2c3d4',
    cwd = '/work/project',
    kind = 'background',
    startedAt = 1790000100000,
    sessionId = KEPT_ID,
    name = 'tests',
    state = 'working',
    pid = 4343,
    status = 'busy',
  }, overrides or {})
end

--- The settings overrides that make a session keep its ids under the state
--- directory `.tests/fixtures/<name>-state`, emptied, with the session
--- `KEPT_ID` kept for the editor's working directory.
---
---@param name string
---@return table
local function keeping_the_session(name)
  local state_directory = fixture.directory(name .. '-state')
  local directory = vim.fs.joinpath(state_directory, 'aineo', 'claude-sessions')
  vim.fn.mkdir(directory, 'p')
  local file =
    assert(io.open(vim.fs.joinpath(directory, vim.fn.sha256(vim.fn.getcwd()) .. '.txt'), 'wb'))
  file:write(KEPT_ID)
  file:close()
  return { state_directory = state_directory }
end

--- A fake `claude` for one case that answers `agents --json` with `entries`,
--- written as the JSON array the fake prints (or as the text it prints, when
--- `entries` is a string), and the extra environment `extra_environment`
--- names.
---
---@param name string the case's own name for its files
---@param entries table[]|string
---@param extra_environment? table<string, string>
---@return { record: string, environment: table<string, string> }
local function fake_listing(name, entries, extra_environment)
  local fake = claude.fake(name, 'ready', extra_environment)
  local listing = vim.fs.joinpath(vim.fs.dirname(fake.record), 'agents.json')
  assert(
    vim.fn.writefile({ type(entries) == 'string' and entries or vim.json.encode(entries) }, listing)
      == 0,
    'cannot write ' .. listing
  )
  fake.environment.AINEO_FAKE_CLAUDE_AGENTS = listing
  return fake
end

--- Waits, at most `claude.PATIENCE_MS`, until `gate` has seen `count` lists
--- start.
---
---@param gate { lists_started: fun(): integer }
---@param count integer
local function wait_for_lists(gate, count)
  vim.wait(claude.PATIENCE_MS, function()
    return gate.lists_started() >= count
  end, 20)
end

--- Replaces `vim.notify` in the child with a function that notes each
--- message and level it is given in the child's `_G.told`.
local function note_what_is_told()
  child.lua([[
    _G.told = {}
    vim.notify = function(message, level)
      table.insert(_G.told, { message, level })
    end
  ]])
end

--- What the child's `vim.notify` was given (`note_what_is_told()`), each as
--- `{ message, level }`.
---
---@return table[]
local function told()
  return child.lua_get('_G.told')
end

--- Where the session of the child stands, as `session_status()` reports it,
--- as a list.
---
---@return any[]
local function status()
  return child.lua_get("{ require('aineo.claude').session_status() }")
end

--- How long a case waits for a Claude Code that starts once a list has run
--- out its bound of 5 s: the bound, and time for the launch.
local LIST_BOUND_AND_LAUNCH_MS = 8000

--- Whether the fake has recorded a run as Claude Code, and not only the
--- `agents --json` of the list.
---
---@param fake { record: string }
---@return boolean
local function claude_code_has_started(fake)
  return vim.iter(claude.record(fake)):any(function(entry)
    return entry.argv ~= nil and entry.argv[1] ~= 'agents'
  end)
end

--- Waits `NO_LAUNCH_WINDOW_MS`, the time a Claude Code that launched would
--- need to show in the fake's record.
local function wait_for_a_launch_that_must_not_come()
  vim.wait(NO_LAUNCH_WINDOW_MS, function()
    return false
  end, 20)
end

T['a start that would resume'] = MiniTest.new_set()

T['a start that would resume']['lists the folder’s sessions before it launches Claude Code on the kept session'] = function()
  local fake = fake_listing('resume-elsewhere-lists-first', {})
  local settings = keeping_the_session('resume-elsewhere-lists-first')

  claude.start(child, fake, settings)
  claude.wait_for_start(fake)

  local ran = vim.tbl_map(
    function(entry)
      return entry.argv
    end,
    vim.tbl_filter(function(entry)
      return entry.argv ~= nil
    end, claude.record(fake))
  )
  eq(ran[1], { 'agents', '--json', '--cwd', vim.fn.getcwd(), '--all' })
  eq({ ran[2][1], ran[2][2] }, { '--resume', KEPT_ID })
end

T['a start that would resume']['lists nothing and launches at once where no session is kept'] = function()
  local fake = fake_listing('resume-elsewhere-new-id', {})
  local settings = { state_directory = fixture.directory('resume-elsewhere-new-id-state') }

  claude.start(child, fake, settings)

  eq(claude.start_arguments(fake, 1)[1], '--session-id')
  eq(claude.wait_for_listings(fake, 0), {})
end

T['a start that would resume']['lists nothing for the new session that takes the place of a resume with no conversation'] = function()
  local fake = fake_listing('resume-elsewhere-no-conversation', {}, {
    AINEO_FAKE_CLAUDE_CONVERSATIONS = fixture.directory('resume-elsewhere-no-conversation-chats'),
  })
  local settings = { state_directory = fixture.directory('resume-elsewhere-no-conversation-state') }
  local first = claude.start(child, fake, settings)
  claude.wait_for_start(fake)
  child.lua('vim.fn.jobstop(vim.bo[...].channel)', { first })
  claude.wait_for_status(child, 'exited')

  claude.start_again(child, settings)
  claude.wait_for_starts(fake, 3)

  eq(claude.start_arguments(fake, 3)[1], '--session-id')
  eq(#claude.wait_for_listings(fake, 0), 1)
end

T['a start that waits for the list'] = MiniTest.new_set()

T['a start that waits for the list']['returns its buffer at once, empty, starting on the kept session'] = function()
  local fake = fake_listing('resume-elsewhere-waits', {})
  local gate = claude.list_gate('resume-elsewhere-waits')
  local settings =
    vim.tbl_extend('force', keeping_the_session('resume-elsewhere-waits'), { cmd = gate.cmd })

  local buffer = claude.start(child, fake, settings)

  eq(claude.buftype(child, buffer), 'nofile')
  eq(status(), { 'starting' })
  eq(claude.followed_session_id(child), KEPT_ID)
  eq(child.api.nvim_win_get_buf(0), buffer)
end

T['a start that waits for the list']['starts nothing for a second start, which returns the same buffer'] = function()
  local fake = fake_listing('resume-elsewhere-twice', {})
  local gate = claude.list_gate('resume-elsewhere-twice')
  local settings =
    vim.tbl_extend('force', keeping_the_session('resume-elsewhere-twice'), { cmd = gate.cmd })
  local first = claude.start(child, fake, settings)
  wait_for_lists(gate, 1)

  local second = claude.start_again(child, settings)
  gate.open()
  claude.wait_for_start(fake)
  wait_for_a_launch_that_must_not_come()

  eq(second, first)
  eq(gate.lists_started(), 1)
  eq(#claude.wait_for_starts(fake, 0), 1)
end

T['a start that waits for the list']['raises on a write, as when no session runs'] = function()
  local fake = fake_listing('resume-elsewhere-write', {})
  local gate = claude.list_gate('resume-elsewhere-write')
  local settings =
    vim.tbl_extend('force', keeping_the_session('resume-elsewhere-write'), { cmd = gate.cmd })
  claude.start(child, fake, settings)

  local written = child.lua_get("{ pcall(require('aineo.claude').write_to_session, 'hello') }")

  eq(written, {
    false,
    'aineo.claude: no Claude Code session is running to write to',
  })
end

T['a start that waits for the list']['presses nothing when Neovim quits'] = function()
  local fake = fake_listing('resume-elsewhere-quit', {})
  local gate = claude.list_gate('resume-elsewhere-quit')
  local settings =
    vim.tbl_extend('force', keeping_the_session('resume-elsewhere-quit'), { cmd = gate.cmd })
  claude.start(child, fake, settings)
  local reported = vim.fs.joinpath(fixture.directory('resume-elsewhere-quit-report'), 'errors')
  child.lua(
    [[
      local reported = ...
      vim.api.nvim_create_autocmd('VimLeavePre', {
        callback = function()
          vim.fn.writefile({ vim.v.errmsg }, reported)
        end,
      })
    ]],
    { reported }
  )

  claude.quit(child)

  eq(claude.wait_for_file(reported), { '' })
end

T['a start that waits for the list']['launches in that same buffer once the list answers, resuming the kept session as a start does'] = function()
  local fake = fake_listing('resume-elsewhere-launch', {})
  local gate = claude.list_gate('resume-elsewhere-launch')
  local settings =
    vim.tbl_extend('force', keeping_the_session('resume-elsewhere-launch'), { cmd = gate.cmd })
  local buffer = claude.start(child, fake, settings)

  gate.open()
  local arguments = claude.start_arguments(fake, 1)

  eq(claude.words_after(arguments, '--resume'), { KEPT_ID })
  eq(claude.flags(arguments), {
    '--allowedTools',
    '--append-system-prompt',
    '--mcp-config',
    '--resume',
    '--settings',
  })
  eq(claude.buftype(child, buffer), 'terminal')
  eq(claude.wait_for_status(child, 'ready'), { 'ready' })
end

T['a start that waits for the list']['leaves the options of the window that shows it as they were when Claude Code launches in it'] = function()
  local fake = fake_listing('resume-elsewhere-window-options', {})
  local gate = claude.list_gate('resume-elsewhere-window-options')
  local settings = vim.tbl_extend(
    'force',
    keeping_the_session('resume-elsewhere-window-options'),
    { cmd = gate.cmd }
  )
  local buffer = claude.start(child, fake, settings)
  local options = [[{ vim.wo.number, vim.wo.relativenumber, vim.wo.wrap, vim.wo.list,
    vim.wo.signcolumn, vim.wo.foldcolumn, vim.wo.winhighlight }]]
  child.lua([[
    vim.wo.number = true
    vim.wo.relativenumber = true
    vim.wo.wrap = true
    vim.wo.list = true
    vim.wo.signcolumn = 'yes'
    vim.wo.foldcolumn = '1'
    vim.wo.winhighlight = 'Normal:Pmenu'
  ]])

  gate.open()
  claude.wait_for_launch(child, buffer)

  eq(child.lua_get(options), { true, true, true, true, 'yes', '1', 'Normal:Pmenu' })
end

T['a start that waits for the list']['tells the user once, as an error, when Claude Code cannot launch, and wipes the buffer'] = function()
  local fake = fake_listing('resume-elsewhere-unlaunchable', {})
  local gate = claude.list_gate('resume-elsewhere-unlaunchable')
  local settings = vim.tbl_extend(
    'force',
    keeping_the_session('resume-elsewhere-unlaunchable'),
    { cmd = gate.cmd }
  )
  note_what_is_told()
  local buffer = claude.start(child, fake, settings)
  child.lua('vim.fn.jobstart = function() return 0 end')

  gate.open()
  vim.wait(claude.PATIENCE_MS, function()
    return #told() > 0
  end, 20)

  local notified = told()
  eq(#notified, 1)
  eq(notified[1][2], vim.log.levels.ERROR)
  eq(notified[1][1]:sub(1, 29), 'aineo: jobstart() cannot run ')
  eq(child.api.nvim_buf_is_valid(buffer), false)
end

T['a start that waits for the list']['keeps the job it launched when the options of its window cannot be put back'] = function()
  local fake = fake_listing('resume-elsewhere-options-fail', {})
  local gate = claude.list_gate('resume-elsewhere-options-fail')
  local settings = vim.tbl_extend(
    'force',
    keeping_the_session('resume-elsewhere-options-fail'),
    { cmd = gate.cmd }
  )
  note_what_is_told()
  local buffer = claude.start(child, fake, settings)
  child.lua("vim.api.nvim_win_is_valid = function() error('Keyboard interrupt') end")

  gate.open()
  claude.wait_for_launch(child, buffer)

  eq(child.lua_get("{ pcall(require('aineo.claude').write_to_session, '') }"), { true })
  eq(told(), {})
end

T['a start that waits for the list']['launches Claude Code all the same when the options of its window cannot be read'] = function()
  local fake = fake_listing('resume-elsewhere-options-unread', {})
  local gate = claude.list_gate('resume-elsewhere-options-unread')
  local settings = vim.tbl_extend(
    'force',
    keeping_the_session('resume-elsewhere-options-unread'),
    { cmd = gate.cmd }
  )
  note_what_is_told()
  local buffer = claude.start(child, fake, settings)
  child.lua("vim.api.nvim_get_all_options_info = function() error('Keyboard interrupt') end")

  gate.open()
  claude.wait_for_launch(child, buffer)

  eq(child.lua_get("{ pcall(require('aineo.claude').write_to_session, '') }"), { true })
  eq(told(), {})
end

T['a start that waits for the list']['launches nothing, and tells nothing, when its buffer was wiped before the list answered'] = function()
  local fake = fake_listing('resume-elsewhere-wiped', {})
  local gate = claude.list_gate('resume-elsewhere-wiped')
  local settings =
    vim.tbl_extend('force', keeping_the_session('resume-elsewhere-wiped'), { cmd = gate.cmd })
  note_what_is_told()
  local buffer = claude.start(child, fake, settings)
  child.lua('vim.cmd.bwipeout({ tostring(...), bang = true })', { buffer })

  gate.open()
  claude.wait_for_listings(fake, 1)
  wait_for_a_launch_that_must_not_come()

  eq(claude.wait_for_starts(fake, 0), {})
  eq(told(), {})
end

T['a start that waits for the list']['launches nothing for a start that another has taken the place of, and the other launches'] = function()
  local fake = fake_listing('resume-elsewhere-replaced', {})
  local gate = claude.list_gate('resume-elsewhere-replaced')
  local settings =
    vim.tbl_extend('force', keeping_the_session('resume-elsewhere-replaced'), { cmd = gate.cmd })
  local buffer = claude.start(child, fake, settings)
  child.lua('vim.cmd.bwipeout({ tostring(...), bang = true })', { buffer })
  local other = claude.start_again(child, settings)

  gate.open()
  claude.wait_for_start(fake)
  wait_for_a_launch_that_must_not_come()

  eq(#claude.wait_for_starts(fake, 0), 1)
  eq(claude.buftype(child, other), 'terminal')
end

T['a start that waits for the list']['launches once the command-line window has closed, where terminals are refused'] = function()
  local fake = fake_listing('resume-elsewhere-cmdwin', {})
  local gate = claude.list_gate('resume-elsewhere-cmdwin')
  local settings =
    vim.tbl_extend('force', keeping_the_session('resume-elsewhere-cmdwin'), { cmd = gate.cmd })
  note_what_is_told()
  local buffer = claude.start(child, fake, settings)
  child.type_keys('q:')

  gate.open()
  claude.wait_for_listings(fake, 1)
  wait_for_a_launch_that_must_not_come()
  local waiting = { claude.buftype(child, buffer), child.fn.getcmdwintype() }
  child.api.nvim_input(':quit<CR>')

  eq(claude.wait_for_launch(child, buffer), true)
  eq(waiting, { 'nofile', ':' })
  eq(told(), {})
end

T['a start that waits for the list']['launches nothing once Neovim is quitting'] = function()
  local fake = fake_listing('resume-elsewhere-exiting', {})
  local gate = claude.list_gate('resume-elsewhere-exiting')
  local settings =
    vim.tbl_extend('force', keeping_the_session('resume-elsewhere-exiting'), { cmd = gate.cmd })
  claude.start(child, fake, settings)
  child.lua(
    [[
      local gate, wait_ms = ...
      vim.api.nvim_create_autocmd('VimLeavePre', {
        callback = function()
          vim.fn.writefile({}, gate)
          vim.wait(wait_ms, function()
            return false
          end, 20)
        end,
      })
    ]],
    { gate.cmd[4], NO_LAUNCH_WINDOW_MS }
  )

  claude.quit(child)
  vim.wait(claude.STOP_PATIENCE_MS, function()
    return vim.fn.jobwait({ child.job.id }, 0)[1] ~= -1
  end, 50)

  eq(claude.wait_for_starts(fake, 0), {})
end

T['a list that does not answer'] = MiniTest.new_set()

T['a list that does not answer']['fails, and the start resumes the kept session and tells nothing'] =
  MiniTest.new_set({
    parametrize = {
      { 'exits with a failure', '[]', { AINEO_FAKE_CLAUDE_AGENTS_EXIT = '3' } },
      { 'prints what is not JSON', 'No sessions yet.', {} },
    },
  })

T['a list that does not answer']['fails, and the start resumes the kept session and tells nothing']['by'] = function(
  how,
  printed,
  environment
)
  local name = 'resume-elsewhere-failed-' .. how:gsub('%W', '-')
  local fake = fake_listing(name, printed, environment)
  note_what_is_told()

  claude.start(child, fake, keeping_the_session(name))

  eq(claude.words_after(claude.start_arguments(fake, 1), '--resume'), { KEPT_ID })
  eq(told(), {})
end

T['a list that does not answer']['times out after 5 s, and the start resumes the kept session and tells nothing'] = function()
  local fake = fake_listing('resume-elsewhere-timeout', {})
  local silent_list = { 'sh', '-c', 'case "$5" in agents) sleep 30;; esac; exec "$@"', 'sh' }
  local settings = vim.tbl_extend('force', keeping_the_session('resume-elsewhere-timeout'), {
    cmd = vim.list_extend(silent_list, claude.fake_command()),
  })
  note_what_is_told()

  claude.start(child, fake, settings)
  vim.wait(LIST_BOUND_AND_LAUNCH_MS, function()
    return claude_code_has_started(fake)
  end, 50)

  eq(claude.words_after(claude.start_arguments(fake, 1), '--resume'), { KEPT_ID })
  eq(told(), {})
end

T['the kept session open in another interactive Claude Code'] = MiniTest.new_set()

T['the kept session open in another interactive Claude Code']['is warned of once, in one short line, and resumed'] = function()
  local fake = fake_listing('resume-elsewhere-warns', { interactive_entry() })
  note_what_is_told()

  claude.start(child, fake, keeping_the_session('resume-elsewhere-warns'))
  claude.wait_for_start(fake)

  eq(told(), { { ALSO_OPEN_WARNING, WARN } })
  eq(#ALSO_OPEN_WARNING <= 60, true)
  eq(claude.words_after(claude.start_arguments(fake, 1), '--resume'), { KEPT_ID })
end

T['the kept session open in another interactive Claude Code']['is told nothing of when what the list holds is no such session'] =
  MiniTest.new_set({
    parametrize = {
      { 'nothing', {} },
      { 'a background session of the kept id that runs', { background_entry() } },
      { 'an interactive session of another id', { interactive_entry({ sessionId = OTHER_ID }) } },
      {
        'an interactive session of the kept id with no pid',
        { interactive_entry({ pid = vim.NIL, status = vim.NIL }) },
      },
    },
  })

T['the kept session open in another interactive Claude Code']['is told nothing of when what the list holds is no such session']['holds'] = function(
  held,
  entries
)
  local name = 'resume-elsewhere-quiet-' .. held:gsub('%W', '-')
  local fake = fake_listing(name, entries)
  note_what_is_told()

  claude.start(child, fake, keeping_the_session(name))
  claude.wait_for_start(fake)

  eq(told(), {})
  eq(claude.words_after(claude.start_arguments(fake, 1), '--resume'), { KEPT_ID })
end

return T
