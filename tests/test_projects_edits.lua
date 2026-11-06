local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local projects = require('aineo.projects')
local signals = require('aineo.transcript.signals')

local T = MiniTest.new_set()

--- The signal of a tool call `tool` made with `input`, by `agent`, as the
--- transcript's codec gives it for an assistant line.
---
---@param tool string
---@param input table
---@param agent? string 'main' when not given
---@return aineo.transcript.Signal
local function tool_call(tool, input, agent)
  local line = vim.json.encode({
    type = 'assistant',
    message = { content = { { type = 'tool_use', id = 'toolu_1', name = tool, input = input } } },
  })
  return assert(signals.signals_of_line(line, agent or 'main')[1], 'the line gives no signal')
end

T['edited_path()'] = MiniTest.new_set()

T['edited_path()']['is the absolute file_path of an Edit call'] = function()
  local signal =
    tool_call('Edit', { file_path = '/work/api/src/app.py', old_string = 'a', new_string = 'b' })

  eq(projects.edited_path(signal), '/work/api/src/app.py')
end

T['edited_path()']['is the absolute file_path of a Write call'] = function()
  local signal = tool_call('Write', { file_path = '/work/docs/index.md', content = 'x' })

  eq(projects.edited_path(signal), '/work/docs/index.md')
end

T['edited_path()']['is the notebook_path of a NotebookEdit call'] = function()
  local signal =
    tool_call('NotebookEdit', { notebook_path = '/work/lab/run.ipynb', new_source = 'x' })

  eq(projects.edited_path(signal), '/work/lab/run.ipynb')
end

T['edited_path()']['is the file_path of a NotebookEdit call that gives it'] = function()
  local signal = tool_call('NotebookEdit', { file_path = '/work/lab/run.ipynb' })

  eq(projects.edited_path(signal), '/work/lab/run.ipynb')
end

T['edited_path()']['is nil for a call that only reads a file'] = function()
  local signal = tool_call('Read', { file_path = '/work/api/src/app.py' })

  eq(projects.edited_path(signal), nil)
end

T['edited_path()']['is nil for a Bash call'] = function()
  local signal = tool_call('Bash', { command = 'echo hi > /work/api/x' })

  eq(projects.edited_path(signal), nil)
end

T['edited_path()']['is nil for a path that is not absolute'] = function()
  local signal = tool_call('Edit', { file_path = 'src/app.py' })

  eq(projects.edited_path(signal), nil)
end

T['edited_path()']['is nil for a file_path that is not a string'] = function()
  local signal = tool_call('Edit', { file_path = 7 })

  eq(projects.edited_path(signal), nil)
end

T['edited_path()']['is nil for a call that gives no path'] = function()
  local signal = tool_call('Write', {})

  eq(projects.edited_path(signal), nil)
end

T['edited_path()']['is nil for a signal that is no tool call'] = function()
  eq(projects.edited_path({ agent = 'main', kind = 'thinking' }), nil)
end

T['edited_path()']['reads a subagent’s call as the main agent’s'] = function()
  local signal = tool_call('Edit', { file_path = '/w/a.lua' }, 'a0000000000000001')

  eq(projects.edited_path(signal), '/w/a.lua')
end

return T
