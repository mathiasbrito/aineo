local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_signals = dofile('tests/helpers/office_signals.lua')

local T = MiniTest.new_set()

T['a tool call'] = MiniTest.new_set()

--- The tool calls that give a state by their tool alone, as {tool, state}.
local STATE_OF_TOOL = {
  { 'Read', 'reading' },
  { 'NotebookRead', 'reading' },
  { 'LSP', 'reading' },
  { 'Grep', 'searching' },
  { 'Glob', 'searching' },
  { 'ToolSearch', 'searching' },
  { 'Edit', 'writing_code' },
  { 'Write', 'writing_code' },
  { 'NotebookEdit', 'writing_code' },
  { 'TaskCreate', 'planning' },
  { 'TaskUpdate', 'planning' },
  { 'TodoWrite', 'planning' },
  { 'EnterPlanMode', 'planning' },
  { 'ExitPlanMode', 'planning' },
  { 'WebSearch', 'on_the_web' },
  { 'WebFetch', 'on_the_web' },
  { 'Agent', 'delegating' },
  { 'AskUserQuestion', 'asking_you' },
  { 'Monitor', 'background_job' },
  { 'Skill', 'working' },
}

T['a tool call']['puts the agent in the state its tool gives while it runs'] = MiniTest.new_set({
  parametrize = STATE_OF_TOOL,
})

T['a tool call']['puts the agent in the state its tool gives while it runs'][''] = function(
  tool,
  state
)
  local story = office_signals.tell()

  story.started('a', tool)

  eq(story.state(), state)
end

T['a tool call']["puts the agent at the printer while aineo's report tool runs"] = function()
  local story = office_signals.tell({ report_tool = 'mcp__aineo__report' })

  story.started('a', 'mcp__aineo__report', { status = 'done', summary = 'x' })

  eq(story.state(), 'reporting')
end

T['a tool call']['gives no report for a report tool nobody named'] = function()
  local story = office_signals.tell()

  story.started('a', 'mcp__aineo__report')

  eq(story.state(), 'working')
end

T['a tool call']['gives the state of the call started last while several run'] = function()
  local story = office_signals.tell()

  story.started('a', 'Read')
  story.started('b', 'Edit')

  eq(story.state(), 'writing_code')
end

T['a tool call']['gives the state of the call still running once the later one finished'] = function()
  local story = office_signals.tell()

  story.started('a', 'Read')
  story.started('b', 'Edit')
  story.finished('b')

  eq(story.state(), 'reading')
end

return T
