local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- The explain home's request file, which builds what a fix is asked with.
---
---@return table
local function request()
  return require('aineo.explain.request')
end

T['the fix schema'] = MiniTest.new_set()

T['the fix schema']['requires a summary and edits, each its lines, old and new lines and why, and nothing else'] = function()
  local schema = vim.json.decode(request().FIX_SCHEMA)

  eq(schema, {
    type = 'object',
    properties = {
      summary = { type = 'string' },
      edits = {
        type = 'array',
        items = {
          type = 'object',
          properties = {
            line = { type = 'integer' },
            last = { type = 'integer' },
            old = { type = 'array', items = { type = 'string' } },
            new = { type = 'array', items = { type = 'string' } },
            why = { type = 'string' },
          },
          required = { 'line', 'last', 'old', 'new', 'why' },
          additionalProperties = false,
        },
      },
    },
    required = { 'summary', 'edits' },
    additionalProperties = false,
  })
end

T['the arguments of a fix'] = MiniTest.new_set()

T['the arguments of a fix']['answer the fix schema with the read-only tools alone, the model and the effort'] = function()
  local argv = request().arguments({ 'claude', '--verbose' }, {
    model = 'opus',
    tools = true,
    effort = 'xhigh',
    schema = request().FIX_SCHEMA,
  })

  eq(argv, {
    'claude',
    '-p',
    '--output-format',
    'json',
    '--json-schema',
    request().FIX_SCHEMA,
    '--no-session-persistence',
    '--strict-mcp-config',
    '--model',
    'opus',
    '--setting-sources',
    'user',
    '--tools',
    'Read,Grep,Glob',
    '--allowedTools',
    'Read,Grep,Glob',
    '--effort',
    'xhigh',
  })
end

--- The code a fix is asked for: an issue on line 2 of a file of three lines.
local FIX = {
  path = 'src/code.lua',
  language = 'lua',
  issue_line = 2,
  issue = 'Adds where it should subtract.',
  lines = { 'local function sub(a, b)', '  return a + b', 'end' },
}

--- What the prompt of every fix says after the text the user may edit.
local FIXED_PART = 'The issue to fix is at line 2 of the file src/code.lua: Adds where it should subtract.'
  .. '\n\n'
  .. 'Answer in summary the whole fix in one sentence, and the edits that make it.'
  .. ' Fix only this file.'
  .. ' Each edit gives in line and last the first and last line it replaces, and repeats in old'
  .. ' exactly those lines of the numbered text below, verbatim with their indentation and'
  .. ' without their numbers; new holds the lines that replace them, and why says what the'
  .. ' change does and why it fixes the issue.'
  .. ' Each edit has at least one old line: to insert lines, replace an anchor line with itself'
  .. ' and the new lines.'
  .. ' Edits do not overlap.'
  .. ' Make the smallest change that fixes the issue.'
  .. ' When no fix is needed or possible, answer no edits and say why in the summary.'

T['the prompt of a fix'] = MiniTest.new_set()

T['the prompt of a fix']['is the default text, the fixed rules with the issue, then every line numbered'] = function()
  local prompt = request().fix_prompt(FIX)

  eq(
    prompt,
    table.concat({
      'Propose a fix for the issue at line 2 of the file src/code.lua (language: lua),'
        .. ' as numbered below.',
      'Make the smallest change that fixes it, reading the project with the tools where it helps.',
      '',
      FIXED_PART,
      '',
      '1 | local function sub(a, b)',
      '2 |   return a + b',
      '3 | end',
    }, '\n')
  )
end

T['the prompt of a fix']['starts with the text the user steered it with, the fixed rules kept'] = function()
  local prompt = request().fix_prompt(vim.tbl_extend('force', FIX, { steer = 'Fix it my way.' }))

  eq(
    prompt,
    table.concat({
      'Fix it my way.',
      '',
      FIXED_PART,
      '',
      '1 | local function sub(a, b)',
      '2 |   return a + b',
      '3 | end',
    }, '\n')
  )
end

T['the prompt of a fix']['names the language unknown for a buffer with no filetype'] = function()
  local text = request().default_fix_steer(vim.tbl_extend('force', FIX, { language = '' }))

  eq(
    vim.split(text, '\n')[1],
    'Propose a fix for the issue at line 2 of the file src/code.lua (language: unknown),'
      .. ' as numbered below.'
  )
end

--- What `claude -p --output-format json` prints for a result whose
--- structured output is `object`.
---
---@param object any
---@return string
local function result_holding(object)
  return vim.json.encode({
    type = 'result',
    subtype = 'success',
    is_error = false,
    result = '',
    structured_output = object,
  })
end

--- Reads the fix `output` holds (`aineo.explain.answer`'s `fix_in()`).
---
---@param output string
---@return table|nil fix
---@return string? problem
local function fix_in(output)
  return require('aineo.explain.answer').fix_in(output)
end

T['the answer of a fix'] = MiniTest.new_set()

T['the answer of a fix']['is its summary and its edits as answered'] = function()
  local edits = {
    {
      line = 2,
      last = 2,
      old = { '  return a + b' },
      new = { '  return a - b' },
      why = 'Subtracts.',
    },
  }

  local fix = fix_in(result_holding({ summary = 'Subtract.', edits = edits }))

  eq(fix, { summary = 'Subtract.', edits = edits })
end

T['the answer of a fix']['is the error an error result says'] = function()
  local output = vim.json.encode({
    type = 'result',
    subtype = 'error_during_execution',
    is_error = true,
    result = 'Overloaded.',
  })

  eq({ fix_in(output) }, { nil, 'Claude Code answered an error: Overloaded.' })
end

T['the answer of a fix']['is a problem when it holds no summary and no list of edits'] = MiniTest.new_set(
  {
    parametrize = {
      { result_holding({ summary = 'S.' }) },
      { result_holding({ edits = {} }) },
      { result_holding({ summary = 5, edits = {} }) },
      { result_holding({ summary = 'S.', edits = { a = 1 } }) },
      { result_holding('text') },
      { 'not json' },
    },
  },
  {
    test = function(output)
      eq({ fix_in(output) }, { nil, 'its answer holds no fix' })
    end,
  }
)

return T
