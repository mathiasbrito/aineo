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

--- The expression, run in a Neovim, that lists what the session reports.
local STATUS = "{ require('aineo.claude').session_status() }"

--- The expression, run in a Neovim, that counts its jobs.
local JOB_COUNT = [[#vim.tbl_filter(function(channel)
  return channel.stream == 'job'
end, vim.api.nvim_list_chans())]]

--- The expression, run in a Neovim, that counts its buffers.
local BUFFER_COUNT = '#vim.api.nvim_list_bufs()'

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

T['start_session()']['runs the command in a new terminal buffer'] = function()
  local fake = claude.fake('terminal', 'exit')

  local buffer = claude.start(child, fake)

  eq(claude.buftype(child, buffer), 'terminal')
  eq(vim.tbl_isempty(claude.wait_for_start(fake)), false)
end

T['start_session()']['keeps its terminal off the buffer list'] = function()
  local fake = claude.fake('unlisted', 'exit')

  local buffer = claude.start(child, fake)

  eq(child.api.nvim_get_option_value('buflisted', { buf = buffer }), false)
end

T['start_session()']['passes each word of the command to the process unchanged'] = function()
  local fake = claude.fake('words', 'exit')
  local word = [[an "argument" with 'quotes' and spaces]]

  claude.start(child, fake, { cmd = claude.fake_command({ word }) })

  eq(claude.arguments(fake)[1], word)
end

T['start_session()']['runs the command in the directory it is given'] = function()
  local fake = claude.fake('cwd', 'exit')
  local directory = fixture.directory('claude-cwd-directory')

  claude.start(child, fake, { cwd = directory })

  eq(claude.wait_for_start(fake).cwd, directory)
end

T['start_session()']['gives Claude the MCP servers as one --mcp-config'] = function()
  local fake = claude.fake('mcp-config', 'exit')

  claude.start(child, fake)

  eq(
    claude.decoded_words_after(claude.arguments(fake), '--mcp-config'),
    { { mcpServers = claude.stand_in_settings().mcp_servers } }
  )
end

T['start_session()']['writes the env of a server without variables as a JSON object'] = function()
  local fake = claude.fake('empty-env', 'exit')

  claude.start(child, fake)

  contains(claude.words_after(claude.arguments(fake), '--mcp-config')[1], '"env":{}')
end

T['start_session()']['writes an empty env for a server that names no env'] = function()
  local fake = claude.fake('server-without-env', 'exit')

  MiniTest.expect.no_error(function()
    claude.start(child, fake, {
      mcp_servers = { quiet = { type = 'stdio', command = 'true', args = { 'x' } } },
    })
  end)

  contains(claude.words_after(claude.arguments(fake), '--mcp-config')[1], '"env":{}')
end

T['start_session()']['writes an empty map of servers as a JSON object'] = function()
  local fake = claude.fake('no-servers', 'exit')

  claude.start(child, fake, { mcp_servers = vim.empty_dict() })

  eq(claude.words_after(claude.arguments(fake), '--mcp-config'), { '{"mcpServers":{}}' })
end

T['start_session()']['pre-allows each tool it is given with --allowedTools'] = function()
  local fake = claude.fake('allowed-tools', 'exit')

  claude.start(child, fake)

  eq(
    claude.words_after(claude.arguments(fake), '--allowedTools'),
    claude.stand_in_settings().allowed_tools
  )
end

T['start_session()']['appends the instructions to the system prompt byte for byte'] = function()
  local fake = claude.fake('instructions', 'exit')

  claude.start(child, fake)

  eq(
    claude.words_after(claude.arguments(fake), '--append-system-prompt'),
    { claude.stand_in_settings().instructions }
  )
end

T['start_session()']['passes no flag beyond the servers, the instructions and the tools'] = function()
  local fake = claude.fake('no-other-flag', 'exit')

  claude.start(child, fake)

  eq(
    claude.flags(claude.arguments(fake)),
    { '--allowedTools', '--append-system-prompt', '--mcp-config' }
  )
  eq(#claude.arguments(fake), 7)
end

T['start_session()']['marks the process as aineo’s child with AINEO_CHILD=1'] = function()
  local fake = claude.fake('aineo-child', 'exit', { AINEO_FAKE_CLAUDE_ENV = 'AINEO_CHILD' })
  child.lua('vim.env.AINEO_CHILD = nil')

  claude.start(child, fake)

  eq(claude.wait_for_start(fake).env, { AINEO_CHILD = '1' })
end

T['start_session()']['gives the process the editor’s server address as NVIM'] = function()
  local fake = claude.fake('servername', 'exit', { AINEO_FAKE_CLAUDE_ENV = 'NVIM' })

  claude.start(child, fake)

  eq(claude.wait_for_start(fake).env, { NVIM = child.v.servername })
end

T['start_session()']['passes every other variable of the editor on unchanged'] = function()
  local fake = claude.fake('inherited', 'exit', {
    AINEO_FAKE_CLAUDE_ENV = 'AINEO_TEST_INHERITED,CLAUDE_CONFIG_DIR',
    AINEO_TEST_INHERITED = [[kept "as it is" — with spaces]],
  })

  claude.start(child, fake)

  eq(claude.wait_for_start(fake).env, {
    AINEO_TEST_INHERITED = [[kept "as it is" — with spaces]],
    CLAUDE_CONFIG_DIR = child.lua_get('vim.env.CLAUDE_CONFIG_DIR'),
  })
end

T['start_session()']['returns the running session instead of starting another'] = function()
  local fake = claude.fake('running', 'ready')
  local first = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, first)
  end)
  claude.wait_for_start(fake)

  local second = claude.start(child, fake)

  eq(second, first)
  eq(child.lua_get(JOB_COUNT), 1)
end

T['start_session()']['leaves nothing behind but the error when the command cannot run'] = function()
  local fake = claude.fake('not-executable', 'ready')
  local buffers = child.lua_get(BUFFER_COUNT)

  MiniTest.expect.error(function()
    claude.start(child, fake, { cmd = { 'aineo-no-such-claude' } })
  end, 'aineo%-no%-such%-claude')

  eq(child.lua_get(BUFFER_COUNT), buffers)
  eq(child.lua_get(STATUS), {})
end

T['start_session()']['returns a live terminal when the running one was just wiped'] = function()
  local fake = claude.fake('wiped-running', 'ready')
  local first = claude.start(child, fake)
  claude.wait_for_start(fake)

  local second = claude.start_again_after_wiping(child, first)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, second)
  end)

  eq(child.api.nvim_buf_is_valid(second), true)
end

T['start_session()']['starts Claude after a start that failed under :silent!'] = function()
  local fake = claude.fake('after-silent-failure', 'exit')
  claude.start_silently(child, fake, { cmd = { 'aineo-no-such-claude' } })

  claude.start(child, fake)

  eq(vim.tbl_isempty(claude.wait_for_start(fake)), false)
end

T['start_session()']['names the setting that is malformed'] = MiniTest.new_set({
  parametrize = {
    { 'cmd', 'claude' },
    { 'cmd', {} },
    { 'cmd', { 'claude', 1 } },
    { 'cwd', 1 },
    { 'cwd', '/nonexistent/aineo/directory' },
    { 'cwd', '/bin/sh' },
    { 'mcp_servers', 'aineo' },
    { 'allowed_tools', 'mcp__aineo__report' },
    { 'allowed_tools', { 1 } },
    { 'instructions', false },
  },
})

T['start_session()']['names the setting that is malformed']['and starts nothing'] = function(
  name,
  value
)
  local fake = claude.fake('malformed', 'ready')

  MiniTest.expect.error(function()
    claude.start(child, fake, { [name] = value })
  end, 'settings%.' .. name)

  eq(child.lua_get(STATUS), {})
end

T['start_session()']['refuses a directory it cannot enter, naming cwd, and starts nothing'] = function()
  local fake = claude.fake('cwd-unenterable', 'ready')
  local directory = fixture.directory('claude-cwd-unenterable')
  vim.uv.fs_chmod(directory, tonumber('000', 8))
  MiniTest.finally(function()
    vim.uv.fs_chmod(directory, tonumber('755', 8))
  end)
  local buffers = child.lua_get(BUFFER_COUNT)

  MiniTest.expect.error(function()
    claude.start(child, fake, { cwd = directory })
  end, 'settings%.cwd')

  eq(child.lua_get(BUFFER_COUNT), buffers)
  eq(child.lua_get(STATUS), {})
end

T['start_session()']['starts Claude again in a new terminal once it has exited'] = function()
  local fake = claude.fake('restart', 'exit')
  local first = claude.start(child, fake)
  claude.wait_for_status(child, 'exited')

  local second = claude.start_again(child)

  MiniTest.expect.no_equality(second, first)
  eq(claude.buftype(child, second), 'terminal')
  eq(#claude.wait_for_starts(fake, 2), 2)
end

T['start_session()']['shows the new terminal in every window that showed the old one'] = function()
  local fake = claude.fake('restart-windows', 'exit')
  local first = claude.start(child, fake)
  child.cmd('vsplit')
  local windows = child.fn.win_findbuf(first)
  child.cmd('new')
  claude.wait_for_status(child, 'exited')

  local second = claude.start_again(child)

  eq(child.fn.win_findbuf(second), windows)
end

T['start_session()']['wipes the terminal of the Claude that exited'] = function()
  local fake = claude.fake('restart-wipe', 'exit')
  local first = claude.start(child, fake)
  claude.wait_for_status(child, 'exited')

  claude.start_again(child)

  eq(child.api.nvim_buf_is_valid(first), false)
end

T['start_session()']['starts Claude again after the old terminal was wiped'] = function()
  local fake = claude.fake('restart-after-wipe', 'exit')
  local first = claude.start(child, fake)
  claude.wait_for_status(child, 'exited')
  eq(child.api.nvim_buf_is_valid(first), true)
  child.cmd('bwipeout! ' .. first)

  local second
  MiniTest.expect.no_error(function()
    second = claude.start_again(child)
  end)

  eq(claude.buftype(child, second), 'terminal')
end

T['session_status()'] = MiniTest.new_set()

T['session_status()']['reports nothing before a session starts'] = function()
  eq(child.lua_get(STATUS), {})
end

T['session_status()']['is starting as soon as the session starts'] = function()
  local fake = claude.fake('starting', 'ready')

  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  eq(child.lua_get(STATUS), { 'starting' })
end

T['session_status()']['is exited, with the exit code, once Claude exits'] = function()
  local fake = claude.fake('exit-code', 'exit', { AINEO_FAKE_CLAUDE_EXIT_CODE = '3' })

  claude.start(child, fake)

  eq(claude.wait_for_status(child, 'exited'), { 'exited', 3 })
end

T['session_status()']['is exited with 122 when the system cannot execute the command'] = function()
  local fake = claude.fake('exec-failure', 'ready')
  local command = fixture.write('claude-exec-failure/claude', { '#!/nonexistent/interpreter' })
  vim.uv.fs_chmod(command, tonumber('755', 8))

  claude.start(child, fake, { cmd = { command } })

  eq(claude.wait_for_status(child, 'exited'), { 'exited', 122 })
end

T['session_status()']['leaves the terminal showing Neovim’s exit line'] = function()
  local fake = claude.fake('exit-line', 'exit', { AINEO_FAKE_CLAUDE_EXIT_CODE = '3' })
  local buffer = claude.start(child, fake)

  claude.wait_for_status(child, 'exited')

  contains(claude.wait_for_screen(child, buffer, '[Process exited 3]'), '[Process exited 3]')
end

T['session_status()']['is ready once its input box shows'] = function()
  local fake = claude.fake('ready', 'ready')

  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  eq(claude.wait_for_status(child, 'ready'), { 'ready' })
end

T['session_status()']['is ready when the folder’s name holds the word trust'] = function()
  local fake =
    claude.fake('trust-folder', 'ready', { AINEO_FAKE_CLAUDE_FOLDER = '~/trusted/aineo' })

  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  eq(claude.wait_for_status(child, 'ready'), { 'ready' })
end

T['session_status()']['stays starting for 1.2 s after the prompt shows'] = function()
  local fake = claude.fake('settle', 'ready')
  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  claude.wait_for_screen(child, buffer, '❯')

  eq(claude.wait_for_status(child, 'ready', 1200), { 'starting' })
end

T['session_status()']['never becomes ready behind the workspace-trust dialog'] = function()
  local fake = claude.fake('trust', 'trust')
  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  claude.wait_for_screen(child, buffer, 'Yes, I trust this folder')

  eq(claude.wait_for_status(child, 'ready'), { 'starting' })
end

T['session_status()']['is ready soon after a long output before the prompt'] = function()
  local fake = claude.fake('verbose', 'verbose')

  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  eq(claude.wait_for_status(child, 'ready'), { 'ready' })
end

T['session_status()']['is ready with a draft of several lines in the prompt'] = function()
  local fake = claude.fake('draft', 'draft')

  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  eq(claude.wait_for_status(child, 'ready'), { 'ready' })
end

T['session_status()']['is not ready while a permission dialog asks the user'] = function()
  local fake = claude.fake('asks', 'asks')
  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)
  eq(claude.wait_for_status(child, 'ready'), { 'ready' })

  claude.press_keys(child, buffer, '\r')

  eq(claude.wait_for_status(child, 'starting'), { 'starting' })
end

T['session_status()']['is not ready while a permission dialog asks in a terminal tall enough for it'] = function()
  local fake = claude.fake('asks-tall', 'asks')
  child.o.lines = 42
  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)
  eq(claude.wait_for_status(child, 'ready'), { 'ready' })

  claude.press_keys(child, buffer, '\r')

  eq(claude.wait_for_status(child, 'starting'), { 'starting' })
end

T['session_status()']['is ready again once the prompt returns after a dialog'] = function()
  local fake = claude.fake('asks-then-prompt', 'asks')
  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)
  eq(claude.wait_for_status(child, 'ready'), { 'ready' })
  claude.press_keys(child, buffer, '\r')
  eq(claude.wait_for_status(child, 'starting'), { 'starting' })

  claude.press_keys(child, buffer, '\27')

  eq(claude.wait_for_status(child, 'ready'), { 'ready' })
end

T['session_status()']['never becomes ready behind the MCP-server approval dialog'] = function()
  local fake = claude.fake('mcp-server', 'mcp-server')
  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  claude.wait_for_screen(child, buffer, 'Continue without using this MCP server')

  eq(claude.wait_for_status(child, 'ready'), { 'starting' })
end

T['session_status()']['never becomes ready when a dialog replaces the prompt at once'] = function()
  local fake = claude.fake('asks-at-once', 'asks-at-once')
  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  claude.wait_for_screen(child, buffer, 'Do you want to proceed?')

  eq(claude.wait_for_status(child, 'ready'), { 'starting' })
end

T['session_status()']['reads only the terminal’s rows, not the input box in its scrollback'] = function()
  local fake = claude.fake('box-in-scrollback', 'box-in-scrollback')
  child.cmd('split')
  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  claude.wait_for_screen(child, buffer, 'Yes, I trust this folder')

  eq(claude.wait_for_status(child, 'ready'), { 'starting' })
end

T['session_status()']['never becomes ready on a choice with no rule above it'] = function()
  local fake = claude.fake('no-rule-above', 'no-rule-above')
  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  claude.wait_for_screen(child, buffer, 'Esc to cancel')

  eq(claude.wait_for_status(child, 'ready'), { 'starting' })
end

T['session_status()']['never becomes ready on a choice with no rule below it'] = function()
  local fake = claude.fake('no-rule-below', 'no-rule-below')
  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  claude.wait_for_screen(child, buffer, 'Esc to cancel')

  eq(claude.wait_for_status(child, 'ready'), { 'starting' })
end

T['session_status()']['is exited once Claude exits with its cursor below the input box'] = function()
  local fake = claude.fake('exit-below-box', 'exit-below-box')
  claude.start(child, fake)
  eq(claude.wait_for_status(child, 'ready'), { 'ready' })

  local status = claude.wait_for_status(child, 'exited')

  eq(status, { 'exited', 0 })
end

T['session_status()']['is ready when its input box fits a terminal no window has shown'] = function()
  local fake = claude.fake('hidden', 'input-box')

  local buffer = claude.start_hidden(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  eq(claude.wait_for_status(child, 'ready'), { 'ready' })
end

T['session_status()']['is ready again once the prompt returns while no window shows it'] = function()
  local fake = claude.fake('asks-hidden', 'asks')
  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)
  eq(claude.wait_for_status(child, 'ready'), { 'ready' })
  claude.press_keys(child, buffer, '\r')
  eq(claude.wait_for_status(child, 'starting'), { 'starting' })
  child.cmd('enew')

  claude.press_keys(child, buffer, '\27')

  eq(claude.wait_for_status(child, 'ready'), { 'ready' })
end

T['session_status()']['is not ready once Claude has exited, even right after its prompt'] = function()
  local fake = claude.fake('exit-while-settling', 'exit')
  local buffer = claude.start(child, fake)
  claude.wait_for_screen(child, buffer, '❯')

  claude.wait_for_status(child, 'exited')

  eq(claude.wait_for_status(child, 'ready'), { 'exited', 0 })
end

T['session_status()']['is exited as soon as its running terminal is wiped'] = function()
  local fake = claude.fake('wiped-status', 'ready')
  local buffer = claude.start(child, fake)
  eq(claude.wait_for_status(child, 'ready'), { 'ready' })

  local status = claude.status_after_wiping(child, buffer)

  eq(status, { 'exited' })
end

T['quitting Neovim'] = MiniTest.new_set()

T['quitting Neovim']['stops an idle Claude by a double Ctrl-C'] = function()
  local fake = claude.fake('quit-idle', 'ready')
  claude.start(child, fake)
  claude.wait_for_start(fake)

  claude.quit(child)

  eq(claude.wait_for_end(fake), { { ended = 'keys', code = 0 } })
  eq(vim.fn.jobwait({ child.job.id }, 1000), { 0 })
end

T['quitting Neovim']['ends a turn with one Ctrl-C before the double Ctrl-C'] = function()
  local fake = claude.fake('quit-busy', 'busy')
  claude.start(child, fake)
  claude.wait_for_start(fake)

  claude.quit(child)

  eq(claude.wait_for_end(fake), { { turn = 'interrupted' }, { ended = 'keys', code = 0 } })
end

T['quitting Neovim']['lets later exit handlers run when Claude’s terminal has just closed'] = function()
  local fake = claude.fake('quit-closed', 'ready')
  local ran = vim.fs.joinpath(fixture.directory('claude-quit-closed-handler'), 'ran')
  claude.add_job_stopping_exit_handler(child)
  claude.start(child, fake)
  claude.wait_for_start(fake)
  claude.add_exit_handler(child, ran)

  claude.quit(child)

  eq(claude.wait_for_file(ran), { 'ran' })
end

T['quitting Neovim']['ends a turn by keys though Ctrl-C is pressed in the editor meanwhile'] = function()
  local fake = claude.fake('quit-busy-interrupted', 'busy')
  claude.start(child, fake)
  claude.wait_for_start(fake)

  claude.quit_pressing_ctrl_c(child)

  eq(claude.wait_for_end(fake), { { turn = 'interrupted' }, { ended = 'keys', code = 0 } })
end

T['quitting Neovim']['leaves no deaf Claude running though Ctrl-C is pressed in the editor'] = function()
  local fake = claude.fake('quit-deaf-interrupted', 'deaf')
  claude.start(child, fake, { cmd = claude.deaf_fake_command() })
  local pid = claude.wait_for_start(fake).pid

  claude.quit_pressing_ctrl_c(child)

  eq(claude.wait_for_process_end(pid), true)
end

T['quitting Neovim']['leaves no Claude that ignores its keys and the hangup running'] = function()
  local fake = claude.fake('quit-deaf', 'deaf')
  claude.start(child, fake, { cmd = claude.deaf_fake_command() })
  local pid = claude.wait_for_start(fake).pid

  claude.quit(child)

  eq(claude.wait_for_process_end(pid), true)
  eq(claude.ctrl_c_count(fake), 3)
end

T['quitting Neovim']['leaves no deaf Claude running when its terminal is wiped as Neovim quits'] = function()
  local fake = claude.fake('quit-deaf-wiped', 'deaf')
  local buffer = claude.start(child, fake, { cmd = claude.deaf_fake_command() })
  local pid = claude.wait_for_start(fake).pid

  claude.wipe_terminal_and_quit(child, buffer)

  eq(claude.wait_for_process_end(pid), true)
end

T['quitting Neovim']['leaves no deaf Claude running when an earlier exit handler wipes its terminal'] = function()
  local fake = claude.fake('quit-deaf-wiped-by-handler', 'deaf')
  claude.add_terminal_wiping_exit_handler(child)
  claude.start(child, fake, { cmd = claude.deaf_fake_command() })
  local pid = claude.wait_for_start(fake).pid

  claude.quit(child)

  eq(claude.wait_for_process_end(pid), true)
end

return T
