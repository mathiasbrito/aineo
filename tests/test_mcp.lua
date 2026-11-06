local MiniTest = require('mini.test')
local mcp = require('aineo.mcp')

local eq = MiniTest.expect.equality
local expect = MiniTest.expect

local T = MiniTest.new_set()

--- Expects `text` to hold `part` as it is written.
---
---@param text string
---@param part string
local function contains(text, part)
  eq({ part = part, found = text:find(part, 1, true) ~= nil }, { part = part, found = true })
end

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

T['allowed_mcp_tools()']['pre-allows the report tool, the announcement tool, the reading of output, the test layout and the walkthrough plan and step, and nothing else'] = function()
  local tools = mcp.allowed_mcp_tools()

  eq(tools, {
    'mcp__aineo__report',
    'mcp__aineo__announce_work',
    'mcp__aineo__run_output',
    'mcp__aineo__test_layout',
    'mcp__aineo__walkthrough_plan',
    'mcp__aineo__walkthrough_step',
  })
end

T['walkthrough_instructions()'] = MiniTest.new_set()

T['walkthrough_instructions()']['name the tool and tell the agent to show one step per call, only after the user asks to move'] = function()
  local paragraph = mcp.walkthrough_instructions()

  contains(paragraph, '`mcp__aineo__walkthrough_step`')
  contains(
    paragraph,
    'Show one step per call, only after the user asks to move; never two steps in one turn.'
  )
end

T['walkthrough_instructions()']['tell the agent to plan the walkthrough the way the solution is built'] = function()
  local paragraph = mcp.walkthrough_instructions()

  contains(
    paragraph,
    'introduce a concept (a type, a module, a data shape, a rule) in a step before any step whose code relies on it;'
      .. ' start from what the rest stands on, then follow the flow;'
      .. " when that order cannot hold (a cycle, a forward use), say so in that step's explanation"
      .. ' in a sentence and name the step that explains it.'
  )
end

T['walkthrough_instructions()']['tell the agent to ask the user whether to start once the plan is done'] = function()
  local paragraph = mcp.walkthrough_instructions()

  contains(paragraph, 'tell the user the plan is done and ask whether to start')
end

T['walkthrough_instructions()']['tell the agent to send the plan before step 1, with a summary of what the walkthrough is about and the features and changes it covers'] = function()
  local paragraph = mcp.walkthrough_instructions()

  contains(paragraph, 'Once the user says yes, send the plan with `mcp__aineo__walkthrough_plan`')
  contains(paragraph, 'before step 1')
  contains(paragraph, 'a `summary` saying what the walkthrough is about')
  contains(paragraph, '`covers` listing the features and changes it goes through')
end

T['walkthrough_instructions()']['tell the agent to call announce_work for the checkout of another repository first, also for code it only reads'] = function()
  local paragraph = mcp.walkthrough_instructions()

  contains(
    paragraph,
    "A file of a repository other than the session's is shown only once you have called `mcp__aineo__announce_work`"
      .. ' for its checkout with the branch checked out there, also for code you only read and want to explain.'
  )
end

T['the walkthrough plan tool'] = MiniTest.new_set()

T['the walkthrough plan tool']['is named as Claude Code names it'] = function()
  eq(mcp.walkthrough_plan_tool_name(), 'mcp__aineo__walkthrough_plan')
end

T['the walkthrough plan tool']['tells the agent when to send the plan, and the order to build it in, as the instructions do'] = function()
  local description = require('aineo.mcp.walkthrough_plan_tool').tool().description

  contains(
    description,
    'Once the user agrees to the plan, send it with this tool before showing step 1.'
  )
  contains(description, 'Sending a plan again replaces the one shown.')
  contains(
    description,
    'introduce a concept (a type, a module, a data shape, a rule) in a step before any step whose code relies on it;'
      .. ' start from what the rest stands on, then follow the flow;'
      .. " when that order cannot hold (a cycle, a forward use), say so in that step's explanation"
      .. ' in a sentence and name the step that explains it.'
  )
end

T['the walkthrough tool'] = MiniTest.new_set()

T['the walkthrough tool']['is named as Claude Code names it'] = function()
  eq(mcp.walkthrough_tool_name(), 'mcp__aineo__walkthrough_step')
end

T['the walkthrough tool']['tells the agent to walk through checked-out work only, in a repository the editor has open or a worktree reported'] = function()
  local description = require('aineo.mcp.walkthrough_tool').tool().description

  contains(
    description,
    'inside a repository the editor has open or a worktree an agent reported with announce_work'
  )
  contains(
    description,
    'Walk through checked-out work only: a branch no worktree has checked out has no file on disk.'
  )
end

T['the walkthrough tool']['tells the agent to call announce_work for the checkout of another repository first, also for code it only reads'] = function()
  local description = require('aineo.mcp.walkthrough_tool').tool().description

  contains(
    description,
    "A file of a repository other than the session's is shown only once you have called announce_work"
      .. ' for its checkout with the branch checked out there, also for code you only read and want to explain.'
  )
end

T['the walkthrough plan tool']['tells the agent to call announce_work for the checkout of another repository first, also for code it only reads'] = function()
  local description = require('aineo.mcp.walkthrough_plan_tool').tool().description

  contains(
    description,
    "A file of a repository other than the session's is listed only once you have called announce_work"
      .. ' for its checkout with the branch checked out there, also for code you only read and want to explain.'
  )
end

T['the walkthrough tool']['describes the pace and the order of the plan, as the instructions do'] = function()
  local description = require('aineo.mcp.walkthrough_tool').tool().description

  contains(
    description,
    'Show one step per call, only after the user asks to move; never two steps in one turn.'
  )
  contains(
    description,
    'introduce a concept (a type, a module, a data shape, a rule) in a step before any step whose code relies on it;'
      .. ' start from what the rest stands on, then follow the flow;'
      .. " when that order cannot hold (a cycle, a forward use), say so in that step's explanation"
      .. ' in a sentence and name the step that explains it.'
  )
end

T['test_layout_instructions()'] = MiniTest.new_set()

T['test_layout_instructions()']['tell the agent to state the layout once per project, naming the presets'] = function()
  local sentence = mcp.test_layout_instructions({ 'python.pytest.flat', 'go.testing.colocated' })

  eq(
    sentence,
    'Call `mcp__aineo__test_layout` once per project, when you first learn how the project'
      .. ' lays out its tests, with presets when one fits: python.pytest.flat, go.testing.colocated.'
  )
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
