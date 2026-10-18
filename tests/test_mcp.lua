local MiniTest = require('mini.test')
local mcp = require('aineo.mcp')

local eq = MiniTest.expect.equality
local expect = MiniTest.expect

local T = MiniTest.new_set()

T['mcp_servers()'] = MiniTest.new_set()

T['mcp_servers()']['describes the report server the way Claude Code starts a stdio server'] = function()
  local servers = mcp.mcp_servers('/tmp/nvim.editor.sock', '/opt/nvim/bin/nvim')

  local entry = servers.aineo
  local script = entry.args[#entry.args]
  eq(vim.tbl_keys(servers), { 'aineo' })
  eq(
    { entry.type, entry.command, entry.env },
    { 'stdio', '/opt/nvim/bin/nvim', { AINEO_EDITOR_ADDRESS = '/tmp/nvim.editor.sock' } }
  )
  eq(
    vim.list_slice(entry.args, 1, #entry.args - 1),
    { '--headless', '--clean', '--cmd', 'set noloadplugins', '-l' }
  )
  eq({ vim.fn.isabsolutepath(script), vim.fn.filereadable(script) }, { 1, 1 })
end

T['mcp_servers()']['refuses an address or a program that is not a string, naming it'] =
  MiniTest.new_set({
    parametrize = {
      { 42, '/opt/nvim/bin/nvim', 'editor_address: expected string, got number' },
      { '/tmp/nvim.editor.sock', false, 'editor_program: expected string, got boolean' },
    },
  })

T['mcp_servers()']['refuses an address or a program that is not a string, naming it']['given'] = function(
  editor_address,
  editor_program,
  refusal
)
  expect.error(function()
    mcp.mcp_servers(editor_address, editor_program)
  end, refusal)
end

T['report_tool_name()'] = MiniTest.new_set()

T['report_tool_name()']['is the name Claude Code gives the report tool of the aineo server'] = function()
  local name = mcp.report_tool_name()

  eq(name, 'mcp__aineo__report')
end

T['allowed_mcp_tools()'] = MiniTest.new_set()

T['allowed_mcp_tools()']['pre-allows the report tool, the announcement tool and the reading of output, and nothing else'] = function()
  local tools = mcp.allowed_mcp_tools()

  eq(tools, { 'mcp__aineo__report', 'mcp__aineo__announce_work', 'mcp__aineo__run_output' })
end

T['the names of the run tools'] = MiniTest.new_set()

T['the names of the run tools']['are those Claude Code gives them'] = function()
  eq(
    { mcp.run_tool_name(), mcp.run_output_tool_name(), mcp.run_stop_tool_name() },
    { 'mcp__aineo__run', 'mcp__aineo__run_output', 'mcp__aineo__run_stop' }
  )
end

T['run_instructions()'] = MiniTest.new_set()

T['run_instructions()']['tell the agent to run and stop only on the user’s explicit request, and how to read output sparingly'] = function()
  local paragraph = mcp.run_instructions()

  eq(
    paragraph,
    'aineo can run commands in its run pane in Neovim.'
      .. ' Call `mcp__aineo__run` only when the user explicitly asks you to run something,'
      .. ' for example "run the backend", and `mcp__aineo__run_stop` only when the user explicitly asks you to stop it;'
      .. ' never on your own initiative. Claude Code asks the user to approve every such call.'
      .. ' To see what a process printed, call `mcp__aineo__run_output`, which needs no approval:'
      .. ' filter first to keep your context small, with `pattern`, a Vim regex such as `error|warn|fail`'
      .. ' (very magic: escape `= @ % & ~ { < >` with a backslash to match them literally, as in `level\\=error`),'
      .. ' a small `last` (40 by default, with no maximum), and then `after_line`,'
      .. ' the `total` of the answer before, to read only what is new; `ignore_case` is true by default.'
      .. ' Each line is a terminal row, and a resize renumbers the rows:'
      .. ' if `total` is smaller than your last `after_line`, read again without it.'
      .. ' The interactive shell of the run pane is not read.'
  )
end

return T
