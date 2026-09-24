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

  eq(child.api.nvim_get_option_value('buftype', { buf = buffer }), 'terminal')
  eq(vim.tbl_isempty(claude.wait_for_start(fake)), false)
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

T['start_session()']['names the setting that is malformed'] = MiniTest.new_set({
  parametrize = {
    { 'cmd', 'claude' },
    { 'cmd', {} },
    { 'cwd', 1 },
    { 'mcp_servers', 'aineo' },
    { 'allowed_tools', 'mcp__aineo__report' },
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

T['start_session()']['starts Claude again in a new terminal once it has exited'] = function()
  local fake = claude.fake('restart', 'exit')
  local first = claude.start(child, fake)
  claude.wait_for_status(child, 'exited')

  local second = claude.start_again(child)

  MiniTest.expect.no_equality(second, first)
  eq(child.api.nvim_get_option_value('buftype', { buf = second }), 'terminal')
  eq(#claude.wait_for_starts(fake, 2), 2)
end

T['start_session()']['shows the new terminal in every window that showed the old one'] = function()
  local fake = claude.fake('restart-windows', 'exit')
  local first = claude.start(child, fake)
  child.cmd('vsplit')
  local windows = child.fn.win_findbuf(first)
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
  child.cmd('bwipeout! ' .. first)

  local second
  MiniTest.expect.no_error(function()
    second = claude.start_again(child)
  end)

  eq(child.api.nvim_get_option_value('buftype', { buf = second }), 'terminal')
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

T['session_status()']['leaves the terminal showing Neovim’s exit line'] = function()
  local fake = claude.fake('exit-line', 'exit', { AINEO_FAKE_CLAUDE_EXIT_CODE = '3' })
  local buffer = claude.start(child, fake)

  claude.wait_for_status(child, 'exited')

  contains(claude.wait_for_screen(child, buffer, '[Process exited 3]'), '[Process exited 3]')
end

T['session_status()']['is ready once the prompt shows with no trust dialog'] = function()
  local fake = claude.fake('ready', 'ready')

  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  eq(claude.wait_for_status(child, 'ready'), { 'ready' })
end

T['session_status()']['stays starting for a moment after the prompt shows'] = function()
  local fake = claude.fake('settle', 'ready')
  local buffer = claude.start(child, fake)
  MiniTest.finally(function()
    claude.end_by_keys(child, fake, buffer)
  end)

  claude.wait_for_screen(child, buffer, '❯')

  eq(child.lua_get(STATUS), { 'starting' })
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

T['session_status()']['is not ready once Claude has exited, even right after its prompt'] = function()
  local fake = claude.fake('exit-while-settling', 'exit')
  local buffer = claude.start(child, fake)
  claude.wait_for_screen(child, buffer, '❯')

  claude.wait_for_status(child, 'exited')

  eq(claude.wait_for_status(child, 'ready'), { 'exited', 0 })
end

T['quitting Neovim'] = MiniTest.new_set()

T['quitting Neovim']['stops an idle Claude by a double Ctrl-C'] = function()
  local fake = claude.fake('quit-idle', 'ready')
  claude.start(child, fake)
  claude.wait_for_start(fake)

  claude.quit(child)

  eq(claude.wait_for_end(fake), { { ended = 'keys', code = 0 } })
end

T['quitting Neovim']['ends a turn with one Ctrl-C before the double Ctrl-C'] = function()
  local fake = claude.fake('quit-busy', 'busy')
  claude.start(child, fake)
  claude.wait_for_start(fake)

  claude.quit(child)

  eq(claude.wait_for_end(fake), { { turn = 'interrupted' }, { ended = 'keys', code = 0 } })
end

T['quitting Neovim']['leaves no Claude that ignores its keys and the hangup running'] = function()
  local fake = claude.fake('quit-deaf', 'deaf')
  claude.start(child, fake, { cmd = claude.deaf_fake_command() })
  local pid = claude.wait_for_start(fake).pid

  claude.quit(child)

  eq(claude.wait_for_process_end(pid), true)
  eq(claude.ctrl_c_count(fake), 3)
end

return T
