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

--- The session kept for the folder in these cases, its short id as Claude
--- Code's `claude agents --json` gives it, and another session.
local KEPT_ID = '0f9e7c2a-1b3d-4e5f-8a9b-0c1d2e3f4a5b'
local SHORT_ID = 'a1b2c3d4'
local OTHER_ID = '7c1d9e3a-5b2f-4a6c-9d8e-1f0a2b3c4d5e'

--- An entry of `claude agents --json` as Claude Code 2.1.296 documents it,
--- for the kept session as a background session that runs, with `overrides`
--- on top.
---
---@param overrides? table
---@return table
local function background_entry(overrides)
  return vim.tbl_extend('force', {
    id = SHORT_ID,
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

--- The session id kept for the editor's working directory under the state
--- directory of `settings` (`keeping_the_session()`).
---
---@param settings { state_directory: string }
---@return string
local function kept_session_id(settings)
  local file = vim.fs.joinpath(
    settings.state_directory,
    'aineo',
    'claude-sessions',
    vim.fn.sha256(vim.fn.getcwd()) .. '.txt'
  )
  return table.concat(vim.fn.readfile(file), '\n')
end

--- An entry for the kept session as an interactive session that runs, open
--- in another Claude Code.
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
--- and the extra environment `extra_environment` names.
---
---@param name string the case's own name for its files
---@param entries table[]
---@param extra_environment? table<string, string>
---@param mode? string the fake's mode, `ready` by default
---@return { record: string, environment: table<string, string> }
local function fake_listing(name, entries, extra_environment, mode)
  local fake = claude.fake(name, mode or 'ready', extra_environment)
  local listing = vim.fs.joinpath(vim.fs.dirname(fake.record), 'agents.json')
  assert(vim.fn.writefile({ vim.json.encode(entries) }, listing) == 0, 'cannot write ' .. listing)
  fake.environment.AINEO_FAKE_CLAUDE_AGENTS = listing
  return fake
end

T['Claude’s status line'] = MiniTest.new_set()

--- How long a case waits, after an attach has exited, to be sure that no
--- new session took its place.
local NO_NEW_SESSION_WINDOW_MS = 1500

--- What aineo tells the user at an attach, with the level it tells it at.
local ATTACHED_NOTE = 'aineo: attached to a background session (no Report)'
local INFO = vim.log.levels.INFO

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

T['a start that resumes the session the list shows running in the background'] = MiniTest.new_set()

T['a start that resumes the session the list shows running in the background']['attaches to it with claude attach and none of aineo’s flags, in the buffer the start returned'] = function()
  local fake = fake_listing('attach-command', { background_entry() })

  local buffer = claude.start(child, fake, keeping_the_session('attach-command'))

  eq(claude.start_arguments(fake, 1), { 'attach', SHORT_ID })
  eq(claude.wait_for_launch(child, buffer), true)
end

T['a start that resumes the session the list shows running in the background']['tells the user once, in one short line, that it attached'] = function()
  local fake = fake_listing('attach-note', { background_entry() })
  note_what_is_told()

  claude.start(child, fake, keeping_the_session('attach-note'))
  claude.wait_for_start(fake)

  eq(told(), { { ATTACHED_NOTE, INFO } })
  eq(#ATTACHED_NOTE <= 60, true)
end

T['a start that resumes the session the list shows running in the background']['attaches and tells nothing of another Claude Code when the list shows both kinds'] = function()
  local fake = fake_listing('attach-both', { interactive_entry(), background_entry() })
  note_what_is_told()

  claude.start(child, fake, keeping_the_session('attach-both'))

  eq(claude.start_arguments(fake, 1), { 'attach', SHORT_ID })
  eq(told(), { { ATTACHED_NOTE, INFO } })
end

T['a start that resumes a session the list does not show attachable'] = MiniTest.new_set({
  parametrize = {
    { 'nothing', {} },
    { 'an interactive session of the kept id', { interactive_entry() } },
    { 'an interactive session with an id', { interactive_entry({ id = SHORT_ID }) } },
    { 'a background session without a short id', { background_entry({ id = vim.NIL }) } },
    {
      'a background session whose process has ended',
      { background_entry({ pid = vim.NIL, status = vim.NIL }) },
    },
    { 'a background session of another id', { background_entry({ sessionId = OTHER_ID }) } },
  },
})

T['a start that resumes a session the list does not show attachable']['resumes it, as a start does'] = function(
  held,
  entries
)
  local name = 'attach-not-' .. held:gsub('%W', '-')
  local fake = fake_listing(name, entries)

  claude.start(child, fake, keeping_the_session(name))

  eq(claude.words_after(claude.start_arguments(fake, 1), '--resume'), { KEPT_ID })
end

--- The expression, run in a Neovim, that shows the terminal buffer `...` in
--- the current window with `session_statusline()` as that window's status
--- line, and gives the text that status line draws.
local STATUSLINE_TEXT = [[(function(buffer)
  vim.api.nvim_win_set_buf(0, buffer)
  local statusline = require('aineo.claude').session_statusline()
  vim.wo[0][0].statusline = statusline
  return vim.api.nvim_eval_statusline(statusline, { winid = 0, maxwidth = 1000 }).str
end)(...)]]

--- What Claude's status line draws for the start of the case `name` on
--- `entries`, once Claude Code has launched and titled its session `tests`.
---
---@param name string
---@param entries table[]
---@return string
local function statusline_after_the_start(name, entries)
  local fake = fake_listing(name, entries)
  local buffer = claude.start(child, fake, keeping_the_session(name))
  claude.wait_for_launch(child, buffer)
  child.lua('vim.b[...].term_title = "✳ tests"', { buffer })
  return child.lua_get(STATUSLINE_TEXT, { buffer })
end

T['Claude’s status line']['reads (attached) after the name while Claude Code is attached'] = function()
  local shown = statusline_after_the_start('attach-statusline', { background_entry() })

  eq(shown, 'tests (attached) — ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':~'))
end

T['Claude’s status line']['drops (attached) once the attach has exited'] = function()
  local name = 'attach-statusline-exited'
  local fake = fake_listing(name, { background_entry() }, nil, 'exit')
  local buffer = claude.start(child, fake, keeping_the_session(name))
  claude.wait_for_status(child, 'exited')

  eq(
    child.lua_get(STATUSLINE_TEXT, { buffer }),
    'Claude Code — ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':~')
  )
end

T['Claude’s status line']['reads as at any start where Claude Code resumed the session'] = function()
  local shown = statusline_after_the_start('attach-statusline-resumed', {})

  eq(shown, 'tests — ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':~'))
end

T['a start that resumes the session the list shows running in the background']['follows the attached session, which stays the one kept for the folder'] = function()
  local fake = fake_listing('attach-kept', { background_entry() })
  local settings = keeping_the_session('attach-kept')

  claude.start(child, fake, settings)
  claude.wait_for_start(fake)

  eq(claude.followed_session_id(child), KEPT_ID)
  eq(kept_session_id(settings), KEPT_ID)
end

T['a start that attaches'] = MiniTest.new_set()

T['a start that attaches']['tells nothing of the --settings of claude.cmd that aineo cannot read'] = function()
  local fake = fake_listing('attach-unread-settings', { background_entry() })
  local settings = keeping_the_session('attach-unread-settings')
  settings.cmd = vim.list_extend(
    { 'sh', '-c', 'shift 2; exec "$@"', 'sh', '--settings', '/nonexistent/settings.json' },
    claude.fake_command()
  )
  note_what_is_told()

  claude.start(child, fake, settings)
  claude.wait_for_start(fake)

  eq(told(), { { ATTACHED_NOTE, INFO } })
end

T['quitting Neovim with Claude Code attached'] = MiniTest.new_set()

--- Whether the fake received the Ctrl+Z key, the byte 26.
---
---@param fake { record: string }
---@return boolean
local function pressed_ctrl_z(fake)
  return claude.received(fake):find('\26', 1, true) ~= nil
end

T['quitting Neovim with Claude Code attached']['presses Ctrl+Z and never Ctrl-C, which leaves the background session running'] = function()
  local fake = fake_listing('attach-quit', { background_entry() })
  claude.start(child, fake, keeping_the_session('attach-quit'))
  claude.wait_for_status(child, 'ready')

  claude.quit(child)
  local events = claude.wait_for_end(fake)

  eq(claude.ctrl_c_count(fake), 0)
  eq(pressed_ctrl_z(fake), true)
  eq(events[#events], { ended = 'detach', code = 0 })
end

T['quitting Neovim with Claude Code attached']['hangs the terminal up once Ctrl+Z has not detached it'] = function()
  local fake = fake_listing('attach-quit-stays', { background_entry() }, nil, 'ignores-detach')
  claude.start(child, fake, keeping_the_session('attach-quit-stays'))
  claude.wait_for_status(child, 'ready')

  local alive_when_the_quit_goes_on =
    vim.fs.joinpath(fixture.directory('attach-quit-stays-handler'), 'alive')
  child.lua(
    [[
      local path, pid = ...
      vim.api.nvim_create_autocmd('VimLeavePre', {
        callback = function()
          vim.fn.writefile({ vim.uv.kill(pid, 0) == 0 and 'alive' or 'dead' }, path)
        end,
      })
    ]],
    { alive_when_the_quit_goes_on, claude.wait_for_start(fake).pid }
  )

  claude.quit(child)
  local events = claude.wait_for_end(fake)

  eq(claude.ctrl_c_count(fake), 0)
  eq(pressed_ctrl_z(fake), true)
  eq(events[#events], { ended = 'hangup', code = 129 })
  eq(claude.wait_for_file(alive_when_the_quit_goes_on), { 'dead' })
end

T['an attach that exits with a failure at once'] = MiniTest.new_set()

--- What aineo tells the user when an attach did not take and it resumes the
--- session, with the level it tells it at.
local ATTACH_FAILED_NOTE = 'aineo: the attach failed; resuming the session'

--- The environment of a fake whose attach prints that it found no
--- conversation and exits 1, as a session that ended between the list and the
--- attach might make `claude attach` do.
local ATTACH_FAILS = {
  AINEO_FAKE_CLAUDE_ATTACH_SAYS = 'No conversation found with session ID: ' .. KEPT_ID,
}

T['an attach that exits with a failure at once']['is followed by a resume of the kept session, which starts no new session'] = function()
  local fake = fake_listing('attach-fails', { background_entry() }, ATTACH_FAILS)
  note_what_is_told()
  local settings = keeping_the_session('attach-fails')

  claude.start(child, fake, settings)
  local resumed = claude.start_arguments(fake, 2)

  eq(claude.words_after(resumed, '--resume'), { KEPT_ID })
  eq(claude.flags(resumed), {
    '--allowedTools',
    '--append-system-prompt',
    '--mcp-config',
    '--resume',
    '--settings',
  })
  eq(claude.wait_for_status(child, 'ready'), { 'ready' })
  eq(claude.followed_session_id(child), KEPT_ID)
  eq(kept_session_id(settings), KEPT_ID)
  eq(told(), { { ATTACHED_NOTE, INFO }, { ATTACH_FAILED_NOTE, INFO } })
end

T['an attach that exits with a failure at once']['is not followed by a resume when its terminal was wiped, which hangs it up'] = function()
  local fake = fake_listing('attach-wiped', { background_entry() })
  local buffer = claude.start(child, fake, keeping_the_session('attach-wiped'))
  claude.wait_for_status(child, 'ready')

  child.lua('vim.cmd.bwipeout({ tostring(...), bang = true })', { buffer })
  claude.wait_for_status(child, 'exited')
  vim.wait(NO_NEW_SESSION_WINDOW_MS, function()
    return false
  end, 20)

  eq(#claude.wait_for_starts(fake, 0), 1)
end

T['an attach to a claimed session'] = MiniTest.new_set()

--- The session another process runs that these cases attach to, as
--- `list_sessions()` delivers it: in Claude Code's background service, with
--- a short id, with `overrides` on top.
---
---@param overrides? table
---@return aineo.claude.ListedSession
local function claimed_listing(overrides)
  return vim.tbl_extend('force', {
    session_id = OTHER_ID,
    short_id = SHORT_ID,
    kind = 'background',
    status = 'idle',
    running = true,
  }, overrides or {})
end

--- Attaches the child's Claude home to `listed` (`attach_session()`), with
--- the stand-in settings overridden by `overrides`, and `return_to` the
--- session resumed when the attach ends; the new terminal is shown in the
--- current window, and each terminal `on_terminal_replaced` and each switch
--- `on_session_switched` is given is noted in the child's
--- `_G.replaced_terminals` and `_G.session_switches`. Returns the new
--- terminal.
---
---@param overrides table
---@param listed aineo.claude.ListedSession
---@param return_to string
---@return integer
local function attach_claimed(overrides, listed, return_to)
  return child.lua(
    [[
      local overrides, listed, return_to = ...
      local settings = dofile('tests/helpers/claude_session.lua').stand_in_settings(overrides)
      _G.replaced_terminals = {}
      _G.session_switches = {}
      settings.on_terminal_replaced = function(terminal)
        table.insert(_G.replaced_terminals, terminal)
      end
      settings.on_session_switched = function(id, source, left)
        table.insert(_G.session_switches, { id = id, source = source, left = left })
      end
      local buffer = require('aineo.claude').attach_session(settings, listed, return_to)
      vim.api.nvim_win_set_buf(0, buffer)
      return buffer
    ]],
    { overrides, listed, return_to }
  )
end

--- How each process of `fake` that has ended so far ended, in order, each
--- as the record's `{ ended, code }` line.
---
---@param fake { record: string }
---@return table[]
local function endings(fake)
  return vim.tbl_filter(function(entry)
    return entry.ended ~= nil
  end, claude.record(fake))
end

--- Waits until `count` processes of `fake` have ended (`endings()`), at
--- most `claude.STOP_PATIENCE_MS`.
---
---@param fake { record: string }
---@param count integer
local function wait_for_endings(fake, count)
  vim.wait(claude.STOP_PATIENCE_MS, function()
    return #endings(fake) >= count
  end, 20)
end

--- Starts the child's Claude home on `KEPT_ID`, kept for the folder of the
--- case `name`, with `fake`, and waits until it is ready; returns the
--- settings overrides it started with.
---
---@param name string
---@param fake { environment: table<string, string> }
---@return table
local function start_own_session(name, fake)
  local settings = keeping_the_session(name)
  claude.start(child, fake, settings)
  claude.wait_for_status(child, 'ready')
  return settings
end

T['an attach to a claimed session']['stops the running Claude Code by its keys and attaches to the session, keeping nothing for the folder'] = function()
  local fake = claude.fake('claim-attach', 'ready')
  local settings = start_own_session('claim-attach', fake)

  attach_claimed(settings, claimed_listing(), KEPT_ID)
  local attached = claude.start_arguments(fake, 2)

  eq(attached, { 'attach', SHORT_ID })
  eq(endings(fake), { { ended = 'keys', code = 0 } })
  eq(claude.followed_session_id(child), OTHER_ID)
  eq(kept_session_id(settings), KEPT_ID)
end

T['an attach to a claimed session']['that ends by itself resumes the session it returns to in its place, telling the replacement and the switch'] = function()
  local fake = claude.fake('claim-attach-ends', 'ready')
  local settings = start_own_session('claim-attach-ends', fake)
  local attach = attach_claimed(settings, claimed_listing(), KEPT_ID)
  claude.wait_for_status(child, 'ready')

  claude.press_keys(child, attach, '\26')
  local resumed = claude.start_arguments(fake, 3)
  claude.wait_for_session_switches(child, 2)

  eq(claude.words_after(resumed, '--resume'), { KEPT_ID })
  eq(claude.followed_session_id(child), KEPT_ID)
  eq(#child.lua_get('_G.replaced_terminals'), 1)
  eq(child.lua_get('_G.session_switches'), {
    { id = OTHER_ID, source = 'resume', left = KEPT_ID },
    { id = KEPT_ID, source = 'resume', left = OTHER_ID },
  })
end

--- Makes the fake `fake` answer `agents --json` with `entries` from now on,
--- as Claude Code would once its sessions changed.
---
---@param fake { record: string }
---@param entries table[]
local function list_from_now_on(fake, entries)
  local listing = vim.fs.joinpath(vim.fs.dirname(fake.record), 'agents.json')
  assert(vim.fn.writefile({ vim.json.encode(entries) }, listing) == 0, 'cannot write ' .. listing)
end

--- The short id the cases give the session they attach to when the session
--- returned to has `SHORT_ID`.
local CLAIMED_SHORT_ID = 'c1c2c3c4'

T['an attach to a claimed session']['that ends by itself attaches to the session it returns to when a background host runs that one by then'] = function()
  local fake = fake_listing('claim-attach-own-in-background', {})
  local settings = start_own_session('claim-attach-own-in-background', fake)
  local attach = attach_claimed(settings, claimed_listing({ short_id = CLAIMED_SHORT_ID }), KEPT_ID)
  claude.wait_for_status(child, 'ready')
  list_from_now_on(fake, { background_entry() })

  claude.press_keys(child, attach, '\26')
  local returned = claude.start_arguments(fake, 3)

  eq(returned, { 'attach', SHORT_ID })
end

T['an attach to a claimed session']['replaced by a start of aineo’s resumes nothing more once it has detached'] = function()
  local fake = claude.fake('claim-attach-replaced', 'ready')
  local settings = start_own_session('claim-attach-replaced', fake)
  attach_claimed(settings, claimed_listing(), KEPT_ID)
  claude.wait_for_status(child, 'ready')

  child.lua(
    [[
      local settings = dofile('tests/helpers/claude_session.lua').stand_in_settings(...)
      require('aineo.claude').replace_session(settings, { id = select(2, ...), resumed = true })
    ]],
    { settings, KEPT_ID }
  )
  claude.wait_for_status(child, 'ready')
  vim.wait(NO_NEW_SESSION_WINDOW_MS, function()
    return false
  end, 20)

  eq(#claude.wait_for_starts(fake, 0), 3)
  eq(endings(fake), { { ended = 'keys', code = 0 }, { ended = 'detach', code = 0 } })
end

T['an attach to a claimed session']['of a session that cannot be attached to raises, stopping nothing'] = function()
  local fake = claude.fake('claim-attach-refused', 'ready')
  local settings = start_own_session('claim-attach-refused', fake)

  local attached, failure =
    pcall(attach_claimed, settings, claimed_listing({ kind = 'interactive', pid = 4242 }), KEPT_ID)

  eq(attached, false)
  eq(
    tostring(failure):find('the session ' .. OTHER_ID .. ' cannot be attached to', 1, true) ~= nil,
    true
  )
  eq(child.lua_get("require('aineo.claude').session_status()"), 'ready')
  eq(#claude.wait_for_starts(fake, 0), 1)
end

T['an attach to a claimed session']['that fails at once resumes the session it returns to, never the session it attached to'] = function()
  local fake = claude.fake('claim-attach-fails', 'ready', ATTACH_FAILS)
  local settings = start_own_session('claim-attach-fails', fake)

  attach_claimed(settings, claimed_listing(), KEPT_ID)
  local resumed = claude.start_arguments(fake, 3)
  vim.wait(NO_NEW_SESSION_WINDOW_MS, function()
    return false
  end, 20)

  eq(claude.words_after(resumed, '--resume'), { KEPT_ID })
  eq(#claude.wait_for_starts(fake, 0), 3)
end

T['an attach to a claimed session']['stopped by its home’s stop resumes nothing, as a closing tab stops it'] = function()
  local fake = claude.fake('claim-attach-stopped', 'ready')
  local settings = start_own_session('claim-attach-stopped', fake)
  attach_claimed(settings, claimed_listing(), KEPT_ID)
  claude.wait_for_status(child, 'ready')

  child.lua("require('aineo.claude').stop_session()")
  vim.wait(NO_NEW_SESSION_WINDOW_MS, function()
    return false
  end, 20)

  eq(#claude.wait_for_starts(fake, 0), 2)
  eq(endings(fake), { { ended = 'keys', code = 0 }, { ended = 'detach', code = 0 } })
end

T['an attach to a claimed session']['ending once another start has taken its place resumes nothing more'] = function()
  local fake = claude.fake('claim-attach-overtaken', 'ready')
  local settings = start_own_session('claim-attach-overtaken', fake)
  local attach = attach_claimed(settings, claimed_listing(), KEPT_ID)
  claude.wait_for_status(child, 'ready')
  child.lua(
    [[
      local overrides = ...
      vim.api.nvim_create_autocmd('CmdwinLeave', {
        once = true,
        callback = function()
          vim.schedule(function()
            local helper = dofile('tests/helpers/claude_session.lua')
            require('aineo.claude').start_session(helper.stand_in_settings(overrides))
          end)
        end,
      })
    ]],
    { settings }
  )
  child.type_keys('q:')

  claude.press_keys(child, attach, '\26')
  wait_for_endings(fake, 2)
  child.api.nvim_input(':quit<CR>')
  claude.wait_for_starts(fake, 3)
  vim.wait(NO_NEW_SESSION_WINDOW_MS, function()
    return false
  end, 20)

  eq(#claude.wait_for_starts(fake, 0), 3)
end

T['an attach to a claimed session']['ending once another start has taken its place, whose swap an autocommand of the user’s broke, resumes nothing over that start'] = function()
  local fake = claude.fake('claim-attach-overtaken-broken', 'ready')
  local settings = start_own_session('claim-attach-overtaken-broken', fake)
  local attach = attach_claimed(settings, claimed_listing(), KEPT_ID)
  claude.wait_for_status(child, 'ready')
  child.lua(
    [[
      local overrides = ...
      vim.api.nvim_create_autocmd('CmdwinLeave', {
        once = true,
        callback = function()
          vim.schedule(function()
            local helper = dofile('tests/helpers/claude_session.lua')
            local settings = helper.stand_in_settings(overrides)
            settings.new_session = true
            vim.api.nvim_create_autocmd('BufWinEnter', {
              callback = function(event)
                if vim.b[event.buf].terminal_job_id and not _G.swap_broken then
                  _G.swap_broken = true
                  error('a user autocommand raising as the terminals are swapped')
                end
              end,
            })
            _G.overtaking = { pcall(require('aineo.claude').start_session, settings) }
            _G.overtaking_session = require('aineo.claude').session_id()
          end)
        end,
      })
    ]],
    { settings }
  )
  child.type_keys('q:')

  claude.press_keys(child, attach, '\26')
  wait_for_endings(fake, 2)
  vim.wait(claude.PATIENCE_MS, function()
    return child.lua_get("#vim.api.nvim_get_autocmds({ event = 'CmdwinLeave' })") >= 2
  end, 20)
  child.api.nvim_input(':quit<CR>')
  claude.wait_for_starts(fake, 3)
  vim.wait(NO_NEW_SESSION_WINDOW_MS, function()
    return false
  end, 20)

  eq(child.lua_get('_G.overtaking[1]'), false)
  eq(child.lua_get('vim.api.nvim_buf_is_valid(...)', { attach }), true)
  eq(claude.followed_session_id(child), child.lua_get('_G.overtaking_session'))
end

T['an attach to a claimed session']['resumes nothing once its terminal was wiped, which hangs it up'] = function()
  local fake = claude.fake('claim-attach-wiped', 'ready')
  local settings = start_own_session('claim-attach-wiped', fake)
  local attach = attach_claimed(settings, claimed_listing(), KEPT_ID)
  claude.wait_for_status(child, 'ready')

  child.lua('vim.cmd.bwipeout({ tostring(...), bang = true })', { attach })
  claude.wait_for_status(child, 'exited')
  vim.wait(NO_NEW_SESSION_WINDOW_MS, function()
    return false
  end, 20)

  eq(#claude.wait_for_starts(fake, 0), 2)
end

T['an attach to a claimed session']['resumes nothing as Neovim quits, which detaches it'] = function()
  local fake = claude.fake('claim-attach-quit', 'ready')
  local settings = start_own_session('claim-attach-quit', fake)
  attach_claimed(settings, claimed_listing(), KEPT_ID)
  claude.wait_for_status(child, 'ready')

  child.lua([[
    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        vim.wait(1000, function()
          return false
        end, 20)
      end,
    })
  ]])

  claude.quit(child)
  wait_for_endings(fake, 2)
  vim.wait(NO_NEW_SESSION_WINDOW_MS, function()
    return false
  end, 20)

  eq(#claude.wait_for_starts(fake, 0), 2)
end

return T
