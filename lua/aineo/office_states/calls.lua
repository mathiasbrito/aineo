--- What a tool call makes an agent do, as a state of the vocabulary: the tool
--- gives it, and for a command, the class of the command. Pure.

local commands = require('aineo.office_states.commands')

local M = {}

--- The state a tool gives by its name alone.
---@type table<string, string>
local STATE_OF_TOOL = {
  Read = 'reading',
  NotebookRead = 'reading',
  LSP = 'reading',
  Grep = 'searching',
  Glob = 'searching',
  ToolSearch = 'searching',
  Edit = 'writing_code',
  Write = 'writing_code',
  NotebookEdit = 'writing_code',
  TaskCreate = 'planning',
  TaskUpdate = 'planning',
  TodoWrite = 'planning',
  EnterPlanMode = 'planning',
  ExitPlanMode = 'planning',
  WebSearch = 'on_the_web',
  WebFetch = 'on_the_web',
  Agent = 'delegating',
  AskUserQuestion = 'asking_you',
  Monitor = 'background_job',
}

--- The tools that run a shell command.
local SHELL_TOOLS = { Bash = true, PowerShell = true }

--- The state of an agent whose call is of a tool the office does not class.
local STATE_OF_UNCLASSED_TOOL = 'working'

--- What the office is told about the calls it sees.
---@class aineo.office_states.CallSettings
---@field report_tool? string the name of aineo's report tool, as Claude Code calls it; none when the office is told of none
---@field commands? aineo.office_states.CommandClasses the classes of shell commands; none when the office is told of none

--- The state of an agent running the shell command a call carries: a
--- background job when the call asks to run in the background, else the state
--- of the command's class.
---
---@param input table the call's input
---@param settings aineo.office_states.CallSettings
---@return string state
local function state_of_shell_call(input, settings)
  if input.run_in_background == true then
    return 'background_job'
  end
  return commands.state_of_command(input.command, settings.commands or {})
end

--- The state of an agent while the tool call `signal` starts runs.
---
---@param signal aineo.transcript.Signal a `tool_started` signal
---@param settings aineo.office_states.CallSettings
---@return string state
function M.state_of_call(signal, settings)
  if signal.tool and signal.tool == settings.report_tool then
    return 'reporting'
  end
  if SHELL_TOOLS[signal.tool] then
    return state_of_shell_call(signal.input or {}, settings)
  end
  return STATE_OF_TOOL[signal.tool] or STATE_OF_UNCLASSED_TOOL
end

return M
