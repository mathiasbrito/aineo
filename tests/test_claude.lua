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

return T
