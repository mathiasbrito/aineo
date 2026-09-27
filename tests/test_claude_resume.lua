local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude = dofile('tests/helpers/claude_session.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- Expects `text` to be a string holding `part`, character for character.
local contains = MiniTest.new_expectation('a string containing a part', function(text, part)
  return type(text) == 'string' and text:find(part, 1, true) ~= nil
end, function(text, part)
  return string.format('Text: %s\nPart: %s', vim.inspect(text), vim.inspect(part))
end)

--- The form of a session id aineo makes: a version-4 UUID (RFC 9562 §5.4),
--- its variant `10xx`, in lower-case hexadecimal, `8-4-4-4-12`.
local SESSION_ID_PATTERN =
  '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$'

--- Expects `words` to be one word, a session id of `SESSION_ID_PATTERN`'s
--- form with no upper-case letter.
local is_one_session_id = MiniTest.new_expectation('one new session id', function(words)
  return #words == 1 and words[1]:find(SESSION_ID_PATTERN) ~= nil and words[1] == words[1]:lower()
end, function(words)
  return 'Words: ' .. vim.inspect(words)
end)

--- The words that follow `flag` in the arguments of `fake`'s `count`th
--- start, once it has started that many times; none when it has not.
---
---@param fake { record: string }
---@param count integer
---@param flag string
---@return string[]
local function words_of_start(fake, count, flag)
  return claude.words_after(claude.start_arguments(fake, count), flag)
end

--- The settings overrides that make a session keep its id under the state
--- directory `.tests/fixtures/<name>`, emptied, with `extra` on top.
---
---@param name string
---@param extra? table
---@return table
local function kept_in(name, extra)
  return vim.tbl_extend('force', { state_directory = fixture.directory(name) }, extra or {})
end

--- Writes `text`, byte for byte, as the file under `state_directory` that
--- keeps the session id of `working_directory`, as the help names it:
--- `aineo/claude-sessions/<the directory's SHA-256>.txt`.
---
---@param state_directory string
---@param working_directory string
---@param text string
local function write_kept_file(state_directory, working_directory, text)
  local directory = vim.fs.joinpath(state_directory, 'aineo', 'claude-sessions')
  vim.fn.mkdir(directory, 'p')
  local file =
    assert(io.open(vim.fs.joinpath(directory, vim.fn.sha256(working_directory) .. '.txt'), 'wb'))
  file:write(text)
  file:close()
end

--- A fake `claude` for one test, in `mode`, that keeps conversations as
--- Claude Code does (`AINEO_FAKE_CLAUDE_CONVERSATIONS`), in a directory of
--- its own under `.tests/fixtures/`, emptied.
---
---@param name string the test's own name for its files
---@param mode string one of the fake's modes
---@return { record: string, environment: table<string, string> }
local function fake_keeping_conversations(name, mode)
  return claude.fake(name, mode, {
    AINEO_FAKE_CLAUDE_CONVERSATIONS = fixture.directory(name .. '-conversations'),
  })
end

--- Stops the Claude Code of the terminal `buffer` in `child` as a hangup
--- does, and waits until the session has exited.
---
---@param child table
---@param buffer integer
local function stop_claude_code(child, buffer)
  child.lua('vim.fn.jobstop(vim.bo[...].channel)', { buffer })
  claude.wait_for_status(child, 'exited')
end

--- Starts, in `child`, a session on a new id with `fake` and `settings`,
--- stops it before anything was sent, so that Claude Code has no
--- conversation for that id, and starts again, which resumes that id; returns
--- the terminal of that resume.
---
---@param child table
---@param fake { record: string, environment: table<string, string> }
---@param settings table
---@return integer
local function resume_with_no_conversation(child, fake, settings)
  local first = claude.start(child, fake, settings)
  claude.wait_for_start(fake)
  stop_claude_code(child, first)
  return claude.start_again(child, settings)
end

--- Waits, at most `claude.PATIENCE_MS`, until the buffer `buffer` of
--- `child` is wiped, and says whether it was.
---
---@param child table
---@param buffer integer
---@return boolean
local function wait_until_wiped(child, buffer)
  return vim.wait(claude.PATIENCE_MS, function()
    return not child.api.nvim_buf_is_valid(buffer)
  end, 20)
end

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

T['start_session()'] = MiniTest.new_set()

T['start_session()']['starts Claude Code on a new session id where none is kept'] = function()
  local fake = claude.fake('resume-new-id', 'exit')

  claude.start(child, fake, kept_in('resume-new-id-state'))

  is_one_session_id(claude.words_after(claude.arguments(fake), '--session-id'))
end

T['start_session()']['resumes the kept session once Claude Code has exited'] = function()
  local fake = claude.fake('resume-again', 'exit')
  local settings = kept_in('resume-again-state')
  claude.start(child, fake, settings)
  claude.wait_for_status(child, 'exited')

  claude.start_again(child, settings)

  eq(words_of_start(fake, 2, '--resume'), words_of_start(fake, 1, '--session-id'))
  eq(words_of_start(fake, 2, '--session-id'), {})
end

T['start_session()']['resumes the session an earlier editor kept in the directory'] = function()
  local fake = claude.fake('resume-other-editor', 'exit')
  local settings = kept_in('resume-other-editor-state')
  claude.start(child, fake, settings)
  claude.wait_for_status(child, 'exited')
  children.restart(child)

  claude.start(child, fake, settings)

  eq(words_of_start(fake, 2, '--resume'), words_of_start(fake, 1, '--session-id'))
end

T['start_session()']['gives two editors started afresh in two directories two ids'] = function()
  local fake = claude.fake('resume-two-editors', 'exit')
  local state = kept_in('resume-two-editors-state')
  claude.start(
    child,
    fake,
    vim.tbl_extend('force', state, { cwd = fixture.directory('resume-two-editors-a') })
  )
  claude.wait_for_status(child, 'exited')
  children.restart(child)

  claude.start(
    child,
    fake,
    vim.tbl_extend('force', state, { cwd = fixture.directory('resume-two-editors-b') })
  )

  MiniTest.expect.no_equality(
    words_of_start(fake, 2, '--session-id'),
    words_of_start(fake, 1, '--session-id')
  )
end

T['start_session()']['keeps the session id it resumes'] = function()
  local fake = claude.fake('resume-keeps', 'exit')
  local settings = kept_in('resume-keeps-state')
  claude.start(child, fake, settings)
  claude.wait_for_status(child, 'exited')
  claude.start_again(child, settings)
  claude.wait_for_starts(fake, 2)
  claude.wait_for_status(child, 'exited')

  claude.start_again(child, settings)

  eq(words_of_start(fake, 3, '--resume'), words_of_start(fake, 1, '--session-id'))
end

T['start_session()']['counts a kept file that holds no session id as none, and replaces it'] =
  MiniTest.new_set({
    parametrize = {
      { '' },
      { '0f9e7c2a-1b3d-4e5f-8a9b' },
      { 'not a session id' },
      { '0F9E7C2A-1B3D-4E5F-8A9B-0C1D2E3F4A5B' },
    },
  })

T['start_session()']['counts a kept file that holds no session id as none, and replaces it']['holding'] = function(
  kept
)
  local fake = claude.fake('resume-malformed', 'exit')
  local settings = kept_in('resume-malformed-state')
  write_kept_file(settings.state_directory, vim.fn.getcwd(), kept)
  claude.start(child, fake, settings)
  claude.wait_for_status(child, 'exited')

  claude.start_again(child, settings)

  is_one_session_id(words_of_start(fake, 1, '--session-id'))
  eq(words_of_start(fake, 2, '--resume'), words_of_start(fake, 1, '--session-id'))
end

T['start_session()']['keeps a session for each directory, and resumes each in its own'] = function()
  local fake = claude.fake('resume-per-directory', 'exit')
  local state = kept_in('resume-per-directory-state')
  local in_a = vim.tbl_extend('force', state, { cwd = fixture.directory('resume-per-directory-a') })
  local in_b = vim.tbl_extend('force', state, { cwd = fixture.directory('resume-per-directory-b') })
  claude.start(child, fake, in_a)
  claude.wait_for_status(child, 'exited')
  claude.start_again(child, in_b)
  claude.wait_for_starts(fake, 2)
  claude.wait_for_status(child, 'exited')

  claude.start_again(child, in_a)

  is_one_session_id(words_of_start(fake, 2, '--session-id'))
  eq(words_of_start(fake, 3, '--resume'), words_of_start(fake, 1, '--session-id'))
end

T['start_session()']['starts Claude Code on a new session id it cannot keep, and says so'] = function()
  local fake = claude.fake('resume-unkeepable', 'exit')
  local state_file = fixture.write('resume-unkeepable-state', { 'a file, not a directory' })
  child.lua([[
    _G.notified = {}
    vim.notify = function(message, level)
      table.insert(_G.notified, { message = message, level = level })
    end
  ]])

  claude.start(child, fake, { state_directory = state_file })

  is_one_session_id(claude.words_after(claude.arguments(fake), '--session-id'))
  local notified = child.lua_get('_G.notified')
  eq(#notified, 1)
  eq(notified[1].level, vim.log.levels.WARN)
  contains(notified[1].message, "aineo: cannot keep Claude Code's session id in " .. state_file)
end

T['start_session()']['keeps the session id in a file only the user can read and write'] = function()
  local fake = claude.fake('resume-file-mode', 'exit')
  local settings = kept_in('resume-file-mode-state')

  claude.start(child, fake, settings)

  claude.wait_for_start(fake)
  local kept = vim.fs.joinpath(
    settings.state_directory,
    'aineo',
    'claude-sessions',
    vim.fn.sha256(vim.fn.getcwd()) .. '.txt'
  )
  eq(vim.fn.getfperm(kept), 'rw-------')
end

T['start_session()']['puts the session first and keeps --allowedTools last'] = function()
  local fake = claude.fake('resume-tools-last', 'exit')

  claude.start(child, fake, kept_in('resume-tools-last-state'))

  local arguments = claude.arguments(fake)
  eq(arguments[1], '--session-id')
  eq(
    vim.list_slice(arguments, #arguments - 2),
    { '--allowedTools', 'mcp__aineo__report', 'mcp__aineo__stand_in' }
  )
end

T['start_session()']['starts Claude Code on a new session id where a directory stands for the kept file'] = function()
  local fake = claude.fake('resume-kept-directory', 'exit')
  local settings = kept_in('resume-kept-directory-state')
  vim.fn.mkdir(
    vim.fs.joinpath(
      settings.state_directory,
      'aineo',
      'claude-sessions',
      vim.fn.sha256(vim.fn.getcwd()) .. '.txt'
    ),
    'p'
  )

  claude.start(child, fake, settings)

  is_one_session_id(words_of_start(fake, 1, '--session-id'))
end

T['a resume with no conversation'] = MiniTest.new_set()

T['a resume with no conversation']['starts a new session on a new id in its place'] = function()
  local fake = fake_keeping_conversations('resume-refused', 'ready')

  resume_with_no_conversation(child, fake, kept_in('resume-refused-state'))

  eq(words_of_start(fake, 2, '--resume'), words_of_start(fake, 1, '--session-id'))
  is_one_session_id(words_of_start(fake, 3, '--session-id'))
  MiniTest.expect.no_equality(
    words_of_start(fake, 3, '--session-id'),
    words_of_start(fake, 1, '--session-id')
  )
end

T['a resume with no conversation']['keeps the new session’s id in place of the one it could not resume'] = function()
  local fake = fake_keeping_conversations('resume-refused-kept', 'ready')
  local settings = kept_in('resume-refused-kept-state')
  resume_with_no_conversation(child, fake, settings)
  claude.wait_for_starts(fake, 3)
  eq(claude.wait_for_status(child, 'ready'), { 'ready' })
  stop_claude_code(child, child.lua_get("vim.fn.bufnr('%')"))

  claude.start_again(child, settings)

  eq(words_of_start(fake, 4, '--resume'), words_of_start(fake, 3, '--session-id'))
end

T['a resume with no conversation']['shows the new session’s terminal in every window that showed it'] = function()
  local fake = fake_keeping_conversations('resume-refused-windows', 'ready')
  local resumed = resume_with_no_conversation(child, fake, kept_in('resume-refused-windows-state'))
  child.cmd('vsplit')
  local windows = child.fn.win_findbuf(resumed)

  eq(wait_until_wiped(child, resumed), true)

  local replacement = child.api.nvim_win_get_buf(windows[1])
  eq(child.fn.win_findbuf(replacement), windows)
  eq(claude.buftype(child, replacement), 'terminal')
end

T['a resume with no conversation']['hands the new session’s terminal to on_terminal_replaced'] = function()
  local fake = fake_keeping_conversations('resume-refused-handed', 'ready')
  local settings = kept_in('resume-refused-handed-state')
  local first = claude.start(child, fake, settings)
  claude.wait_for_start(fake)
  stop_claude_code(child, first)
  local resumed = claude.start_again_noting_replacements(child, settings)

  eq(wait_until_wiped(child, resumed), true)

  eq(child.lua_get('_G.replaced_terminals'), { child.api.nvim_win_get_buf(0) })
end

T['a resume with no conversation']['is told by a message its terminal wraps'] = MiniTest.new_set({
  parametrize = { { 39 }, { 60 } },
})

T['a resume with no conversation']['is told by a message its terminal wraps']['at a width of'] = function(
  columns
)
  local fake = fake_keeping_conversations('resume-refused-wrapped', 'ready')
  child.cmd('vsplit')
  child.cmd('vertical resize ' .. columns)

  resume_with_no_conversation(child, fake, kept_in('resume-refused-wrapped-state'))

  is_one_session_id(words_of_start(fake, 3, '--session-id'))
end

T['a resume with no conversation']['is not taken for a resume that exits 1 another way, whose id stays kept'] = function()
  local fake = claude.fake('resume-other-exit', 'exit', { AINEO_FAKE_CLAUDE_EXIT_CODE = '1' })
  local settings = kept_in('resume-other-exit-state')
  claude.start(child, fake, settings)
  claude.wait_for_status(child, 'exited')
  claude.start_again(child, settings)
  claude.wait_for_starts(fake, 2)
  eq(claude.wait_for_status(child, 'exited'), { 'exited', 1 })

  claude.start_again(child, settings)

  eq(words_of_start(fake, 3, '--resume'), words_of_start(fake, 1, '--session-id'))
end

T['a resume with no conversation']['starts no new session as Neovim quits'] = function()
  local fake = fake_keeping_conversations('resume-refused-quit', 'ready')
  local settings = kept_in('resume-refused-quit-state')
  local resumed = resume_with_no_conversation(child, fake, settings)
  claude.wait_for_screen(child, resumed, 'No conversation found with session ID')
  child.lua([[
    vim.api.nvim_create_autocmd('VimLeavePre', {
      desc = 'Wait as Neovim quits, as another plugin might',
      callback = function()
        vim.wait(1000)
      end,
    })
  ]])
  claude.quit(child)
  eq(vim.fn.jobwait({ child.job.id }, claude.STOP_PATIENCE_MS), { 0 })
  children.restart(child)

  claude.start(child, fake, settings)

  eq(words_of_start(fake, 3, '--resume'), words_of_start(fake, 1, '--session-id'))
end

T['a resume with no conversation']['raises no error and starts nothing when a TermClose autocommand wipes its terminal'] = function()
  local fake = fake_keeping_conversations('resume-refused-wiped', 'ready')
  local settings = kept_in('resume-refused-wiped-state')
  local first = claude.start(child, fake, settings)
  claude.wait_for_start(fake)
  stop_claude_code(child, first)
  child.lua([[
    vim.api.nvim_create_autocmd('TermClose', {
      once = true,
      callback = function(event)
        vim.api.nvim_buf_delete(event.buf, { force = true })
      end,
    })
  ]])
  child.v.errmsg = ''

  local resumed = claude.start_again(child, settings)

  eq(wait_until_wiped(child, resumed), true)
  eq(claude.wait_for_status(child, 'exited'), { 'exited', 1 })
  eq(child.v.errmsg, '')
  eq(#claude.wait_for_starts(fake, 3), 2)
end

return T
