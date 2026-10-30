--- The test layout tool's side of the report server: what `tools/list`
--- says of `test_layout`, which of its arguments are a call the editor can
--- be offered, and the offer of that call to the editor that started
--- Claude Code. The rules themselves are the editor's to check: the relay
--- checks the shape of the call alone.

local editor = require('aineo.mcp.editor')
local names = require('aineo.mcp.names')

local M = {}

--- What the tool says of itself.
local DESCRIPTION = 'Tells aineo how this project lays out its tests, so that it finds the test'
  .. ' file of a source and the source of a test file, and knows where to create a new test file.'
  .. ' Call it once per project, when you first learn how the project lays out its tests.'
  .. ' Each rule is a preset, `{ "preset": "<id>" }`, with `kind` or `create` overridden when needed,'
  .. ' or a rule of its own: `source`, a template, with `test`, a template or a list of them'
  .. ' (the first is used to create), or `inline: true` (the test is in the source file),'
  .. ' or `folder: "<dir>/"` (tests tied to no one source).'
  .. ' Templates are paths from the unit root, with `/` separators: the folder of the nearest'
  .. ' manifest (pyproject.toml, package.json, go.mod, pom.xml, build.gradle…), or of the outermost'
  .. ' C or C++ build file (CMakeLists.txt, meson.build, Makefile) when that is nearer:'
  .. ' `{name}` the file name without its extension, `{path}` the folders between, `{ext}` the'
  .. ' extension, `{unit}` that folder itself, any other `{word}` one folder;'
  .. ' `{path|_}` joins the folders with `_`, `{word|-_}` turns `-` into `_`.'
  .. ' `discover` lists the globs of the framework that name test files.'
  .. ' It only informs aineo: if it refuses, correct the call as the refusal says and call again.'

--- The longest worktree path a call may give, in bytes.
local LONGEST_WORKTREE_BYTES = 4096

--- The test layout tool, as `tools/list` describes it: an object of
--- `worktree` and `rules`, required, `framework` and `replace`; no other
--- property.
---
---@return table
function M.tool()
  local template_list = { type = 'array', items = { type = 'string' } }
  return {
    name = names.TEST_LAYOUT_TOOL,
    description = DESCRIPTION,
    inputSchema = {
      type = 'object',
      properties = {
        worktree = {
          type = 'string',
          description = 'The absolute path of the folder of the git worktree the rules are for.',
        },
        rules = {
          type = 'array',
          description = 'The rules, in the order aineo tries them.',
          items = {
            type = 'object',
            properties = {
              preset = { type = 'string' },
              source = { type = 'string' },
              test = { anyOf = { { type = 'string' }, template_list } },
              inline = { type = 'boolean' },
              folder = { type = 'string' },
              kind = { type = 'string' },
              create = { type = 'boolean' },
              discover = template_list,
              framework = { type = 'string' },
              companions = template_list,
            },
            additionalProperties = false,
          },
        },
        framework = { type = 'string', description = 'The test framework of the rules.' },
        replace = {
          type = 'boolean',
          description = 'Whether the rules replace those aineo keeps (the default) or follow them.',
        },
      },
      required = { 'worktree', 'rules' },
      additionalProperties = false,
    },
  }
end

--- A call of the test layout tool: what an agent states of the layout of
--- its worktree's tests (`aineo.test_layout`'s declaration).
---@class aineo.mcp.TestLayoutCall
---@field worktree string
---@field rules table[]
---@field framework? string
---@field replace? boolean

--- The fields a call may give.
local FIELDS = { worktree = true, rules = true, framework = true, replace = true }

--- Whether `value` is a JSON object: a table that is no non-empty list.
---
---@param value any
---@return boolean
local function is_object(value)
  return type(value) == 'table' and not (vim.islist(value) and next(value) ~= nil)
end

--- Why `worktree` is refused: no non-empty string, longer than 4096
--- bytes, holding a NUL or a line break, or no absolute path.
---
---@param worktree any
---@return string?
local function worktree_problem(worktree)
  if type(worktree) ~= 'string' or worktree == '' then
    return 'worktree: expected a non-empty string'
  end
  if #worktree > LONGEST_WORKTREE_BYTES then
    return ('worktree: longer than %d bytes'):format(LONGEST_WORKTREE_BYTES)
  end
  if worktree:find('[%z\n\r]') then
    return 'worktree: holds a NUL or a line break'
  end
  if not vim.startswith(worktree, '/') then
    return 'worktree: expected an absolute path'
  end
  return nil
end

--- Why `rules` are refused: no list, or an item that is no object.
---
---@param rules any
---@return string?
local function rules_problem(rules)
  if type(rules) ~= 'table' or not vim.islist(rules) then
    return 'rules: expected an array'
  end
  for position, rule in ipairs(rules) do
    if not is_object(rule) then
      return ('rules[%d]: expected an object'):format(position)
    end
  end
  return nil
end

--- Why `arguments` are no call of the tool, naming the field at fault; nil
--- when they are one.
---
---@param arguments any
---@return string?
local function refusal_of(arguments)
  if not is_object(arguments) then
    return 'arguments: expected an object'
  end
  local problem = worktree_problem(arguments.worktree) or rules_problem(arguments.rules)
  if problem then
    return problem
  end
  if arguments.framework ~= nil and type(arguments.framework) ~= 'string' then
    return 'framework: expected a string'
  end
  if arguments.replace ~= nil and type(arguments.replace) ~= 'boolean' then
    return 'replace: expected true or false'
  end
  for key in pairs(arguments) do
    if not FIELDS[key] then
      return tostring(key) .. ': not a field of test_layout'
    end
  end
  return nil
end

--- The call `arguments` describe, or nil and why they are refused: an
--- object of `worktree`, an absolute path, `rules`, a list of objects,
--- and optionally `framework`, a string, and `replace`, true or false.
--- What each rule says is the editor's to check.
---
---@param arguments any
---@return aineo.mcp.TestLayoutCall? call
---@return string? refusal
function M.validate(arguments)
  local refusal = refusal_of(arguments)
  if refusal then
    return nil, refusal
  end
  return {
    worktree = arguments.worktree,
    rules = arguments.rules,
    framework = arguments.framework,
    replace = arguments.replace,
  }
end

--- The Lua the editor runs for a call, its arguments the call and the
--- start token: `aineo.mcp`'s `receive_test_layout()` answers the words
--- for Claude, or `false` when no handler took it. Both travel as data.
local RECEIVE_TEST_LAYOUT = [[
  local call, start_token = ...
  return require('aineo.mcp').receive_test_layout(call, start_token)
]]

--- What the relay tells Claude when the editor did not take a call.
M.NOT_TAKEN = 'not taken: the editor that started Claude Code keeps no test layout'

--- What the relay tells Claude when the editor answered a call with
--- something that is not words for it.
local UNREADABLE_ANSWER = 'the editor answered the call with something aineo cannot read'

--- Offers `call` to the editor that started Claude Code, and to no other,
--- with the token of that start (`editor.offer_report()`, bounded), and
--- answers with the words for Claude and whether they are an error: the
--- editor's; `NOT_TAKEN` when it did not take the call, and at once,
--- offering nothing, with no editor address or no token; why not, in
--- words, when the editor cannot be reached, closes the connection,
--- refuses the call or does not answer in time.
---
---@param context { editor_address?: string, token?: string }
---@param call aineo.mcp.TestLayoutCall
---@return string text
---@return boolean is_error
function M.offer(context, call)
  if not (context.editor_address and context.token) then
    return M.NOT_TAKEN, true
  end
  local kind, explanation, answer = editor.offer_report(context.editor_address, {
    lua = RECEIVE_TEST_LAYOUT,
    arguments = { call, context.token },
    subject = 'test layout',
  })
  if kind == 'declined' then
    return M.NOT_TAKEN, true
  end
  if kind ~= 'taken' then
    return explanation, true
  end
  if
    type(answer) ~= 'table'
    or type(answer.text) ~= 'string'
    or type(answer.is_error) ~= 'boolean'
  then
    return UNREADABLE_ANSWER, true
  end
  return answer.text, answer.is_error
end

return M
