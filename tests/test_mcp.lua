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
  eq(vim.list_slice(entry.args, 1, #entry.args - 1), { '--headless', '--clean', '-l' })
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

T['allowed_mcp_tools()']['pre-allows the report tool and nothing else'] = function()
  local tools = mcp.allowed_mcp_tools()

  eq(tools, { 'mcp__aineo__report' })
end

return T
