local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local mcp_messages = dofile('tests/helpers/mcp_messages.lua')
local mcp_relay = dofile('tests/helpers/mcp_relay.lua')

local eq = MiniTest.expect.equality
local get = vim.tbl_get
local decoded = mcp_relay.decoded

--- The child Neovim a relay offers calls to: the user's editor.
local editor = MiniTest.new_child_neovim()

--- The start token the relay is told in each case.
local TOKEN = 'start-token-1'

local T = MiniTest.new_set({
  hooks = {
    post_case = mcp_relay.stop_all,
    post_once = editor.stop,
  },
})

T['tools/list'] = MiniTest.new_set()

T['tools/list']['lists walkthrough_step last, with its file, title and step required'] = function()
  local relay = mcp_relay.start_relay()

  relay:send(mcp_messages.recorded('tools/list'))

  local tools = get(decoded(relay:next_line()), 'result', 'tools')
  local listed = tools[#tools]
  eq(
    { listed.name, listed.inputSchema.required, listed.inputSchema.additionalProperties },
    { 'walkthrough_step', { 'file', 'title', 'step' }, false }
  )
end

--- The `tools/call` line of the walkthrough tool with `arguments`, its id 7.
---
---@param arguments any
---@return string
local function call(arguments)
  return mcp_messages.tools_call('walkthrough_step', arguments, 7)
end

--- The `tools/call` result of one text item, a tool error when `is_error`.
---
---@param text string
---@param is_error boolean
---@return table
local function result_of(text, is_error)
  return { isError = is_error, content = { { type = 'text', text = text } } }
end

--- A call that is valid but for the fields `overrides` replaces.
---
---@param overrides table
---@return table
local function step_with(overrides)
  return vim.tbl_extend('force', {
    file = '/repo/lib/queue.lua',
    title = 'The queue',
    step = 1,
    total = 3,
    ranges = { { start = 3, ['end'] = 5, text = 'The queue holds the jobs.' } },
  }, overrides)
end

--- A range that is valid but for the fields `overrides` replaces.
---
---@param overrides table
---@return table
local function range_with(overrides)
  return vim.tbl_extend(
    'force',
    { start = 3, ['end'] = 5, text = 'The queue holds the jobs.' },
    overrides
  )
end

T['a call'] = MiniTest.new_set()

T['a call']['whose arguments are refused is a tool error naming the field'] = MiniTest.new_set({
  parametrize = {
    { 42, 'arguments: expected an object' },
    { step_with({ file = vim.NIL }), 'file: expected a non-empty string' },
    { step_with({ file = 'lib/queue.lua' }), 'file: expected an absolute path' },
    { step_with({ file = '/repo/a\nb.lua' }), 'file: holds a NUL or a line break' },
    { step_with({ file = '/' .. ('a'):rep(4096) }), 'file: longer than 4096 bytes' },
    { step_with({ title = '' }), 'title: expected a non-empty string' },
    { step_with({ title = 'one\ntwo' }), 'title: holds a NUL or a line break' },
    { step_with({ title = 'one\0two' }), 'title: holds a NUL or a line break' },
    { step_with({ title = ('t'):rep(201) }), 'title: longer than 200 bytes' },
    { step_with({ step = 'one' }), 'step: expected a whole number from 1' },
    { step_with({ step = 0 }), 'step: expected a whole number from 1' },
    { step_with({ step = 1.5 }), 'step: expected a whole number from 1' },
    { step_with({ total = 'three' }), 'total: expected a whole number not below step' },
    { step_with({ step = 4, total = 3 }), 'total: expected a whole number not below step' },
    { step_with({ ranges = 'all' }), 'ranges: expected an array' },
    { step_with({ ranges = vim.fn.range(17) }), 'ranges: more than 16' },
    { step_with({ ranges = { 'all' } }), 'ranges[1]: expected an object' },
    {
      step_with({ ranges = { range_with({ start = 0 }) } }),
      'ranges[1].start: expected a whole number from 1',
    },
    {
      step_with({ ranges = { range_with({ start = 'top' }) } }),
      'ranges[1].start: expected a whole number from 1',
    },
    {
      step_with({ ranges = { range_with({ ['end'] = 2 }) } }),
      'ranges[1].end: expected a whole number not below start',
    },
    {
      step_with({ ranges = { range_with({ ['end'] = vim.NIL }) } }),
      'ranges[1].end: expected a whole number not below start',
    },
    {
      step_with({ ranges = { range_with({ text = '' }) } }),
      'ranges[1].text: expected a non-empty string',
    },
    {
      step_with({ ranges = { range_with({ text = ('x'):rep(8193) }) } }),
      'ranges[1].text: longer than 8192 bytes',
    },
    {
      step_with({ ranges = { range_with({ text = 'one\0two' }) } }),
      'ranges[1].text: holds a NUL',
    },
    {
      step_with({
        ranges = {
          range_with({ text = ('x'):rep(8192) }),
          range_with({ text = ('x'):rep(8192) }),
          range_with({ text = ('x'):rep(8192) }),
          range_with({ text = ('x'):rep(8192) }),
          range_with({ text = 'x' }),
        },
      }),
      'ranges: the texts are longer than 32768 bytes in all',
    },
    {
      step_with({ ranges = { range_with({ first_line = 3 }) } }),
      'ranges[1].first_line: expected a string',
    },
    {
      step_with({ ranges = { range_with({ first_line = ('x'):rep(1025) }) } }),
      'ranges[1].first_line: longer than 1024 bytes',
    },
    {
      step_with({ ranges = { range_with({ colour = 'red' }) } }),
      'ranges[1].colour: not a field of a range',
    },
    { step_with({ run = 'now' }), 'run: not a field of walkthrough_step' },
  },
})

T['a call']['whose arguments are refused is a tool error naming the field']['given'] = function(
  arguments,
  refusal
)
  local relay = mcp_relay.start_relay({
    AINEO_EDITOR_ADDRESS = '/nonexistent/editor.sock',
    AINEO_START_TOKEN = 'start-token-1',
  })

  relay:send(call(arguments))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('aineo refused the walkthrough step: ' .. refusal, true)
  )
end

T['in the editor'] = MiniTest.new_set()

T['in the editor']['a valid call is offered to the handler, with the start token, and answered with its words'] = function()
  children.restart(editor)
  editor.lua([[
    require('aineo.mcp').on_walkthrough_stepped(function(call, start_token)
      _G.offered = { call = call, token = start_token }
      return { text = 'Showing step 1/3', is_error = false }
    end)
  ]])
  local relay = mcp_relay.start_relay({
    AINEO_EDITOR_ADDRESS = editor.job.address,
    AINEO_START_TOKEN = TOKEN,
  })

  relay:send(call(step_with({})))

  eq(get(decoded(relay:next_line()), 'result'), result_of('Showing step 1/3', false))
  eq(editor.lua_get('_G.offered'), {
    call = step_with({}),
    token = TOKEN,
  })
end

T['in the editor']['a call with no handler registered is not taken'] = function()
  children.restart(editor)
  local relay = mcp_relay.start_relay({
    AINEO_EDITOR_ADDRESS = editor.job.address,
    AINEO_START_TOKEN = TOKEN,
  })

  relay:send(call(step_with({})))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('not taken: the editor that started Claude Code shows no walkthrough', true)
  )
end

T['in the editor']['a call without an editor address is not taken, and offers nothing'] = function()
  local relay = mcp_relay.start_relay({ AINEO_START_TOKEN = TOKEN })

  relay:send(call(step_with({})))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('not taken: the editor that started Claude Code shows no walkthrough', true)
  )
end

--- Offers `arguments` as a call of the tool to an editor whose handler takes
--- every call and says `shown`, and returns the result the relay answers.
---
---@param arguments table
---@return table
local function answer_of_a_taking_editor(arguments)
  children.restart(editor)
  editor.lua([[
    require('aineo.mcp').on_walkthrough_stepped(function()
      return { text = 'shown', is_error = false }
    end)
  ]])
  local relay = mcp_relay.start_relay({
    AINEO_EDITOR_ADDRESS = editor.job.address,
    AINEO_START_TOKEN = TOKEN,
  })
  relay:send(call(arguments))
  return get(decoded(relay:next_line()), 'result')
end

T['in the editor']['takes 16 ranges, the most a step has'] = function()
  local ranges = {}
  for _ = 1, 16 do
    table.insert(ranges, range_with({}))
  end

  eq(answer_of_a_taking_editor(step_with({ ranges = ranges })), result_of('shown', false))
end

T['in the editor']['takes texts of 32 KiB in all, and no more'] = function()
  local ranges = {}
  for _ = 1, 4 do
    table.insert(ranges, range_with({ text = ('x'):rep(8192) }))
  end

  eq(answer_of_a_taking_editor(step_with({ ranges = ranges })), result_of('shown', false))
end

T['in the editor']['takes a text of 8 KiB, the most one range has'] = function()
  local ranges = { range_with({ text = ('x'):rep(8192) }) }

  eq(answer_of_a_taking_editor(step_with({ ranges = ranges })), result_of('shown', false))
end

return T
