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

T['tools/list']['lists walkthrough_plan before walkthrough_step, with its title, summary, covers and steps required'] = function()
  local relay = mcp_relay.start_relay()

  relay:send(mcp_messages.recorded('tools/list'))

  local tools = get(decoded(relay:next_line()), 'result', 'tools')
  local listed = tools[#tools - 1]
  eq(
    { listed.name, listed.inputSchema.required, listed.inputSchema.additionalProperties },
    { 'walkthrough_plan', { 'title', 'summary', 'covers', 'steps' }, false }
  )
  eq(tools[#tools].name, 'walkthrough_step')
end

--- The `tools/call` line of the plan tool with `arguments`, its id 7.
---
---@param arguments any
---@return string
local function call(arguments)
  return mcp_messages.tools_call('walkthrough_plan', arguments, 7)
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
local function plan_with(overrides)
  return vim.tbl_extend('force', {
    title = 'The queue',
    summary = 'How jobs reach the queue and leave it.',
    covers = { 'The queue type', 'Taking a job' },
    steps = {
      { title = 'The queue type', file = '/repo/lib/queue.lua', introduces = { 'job', 'queue' } },
      { title = 'Taking a job', file = '/repo/lib/take.lua' },
    },
  }, overrides)
end

--- A step that is valid but for the fields `overrides` replaces.
---
---@param overrides table
---@return table
local function step_with(overrides)
  return vim.tbl_extend(
    'force',
    { title = 'The queue type', file = '/repo/lib/queue.lua', introduces = { 'job' } },
    overrides
  )
end

--- `count` strings `text`.
---
---@param count integer
---@param text string
---@return string[]
local function repeated(count, text)
  local items = {}
  for _ = 1, count do
    table.insert(items, text)
  end
  return items
end

T['tools/list']['states each limit in the description and in the input schema'] = function()
  local relay = mcp_relay.start_relay()

  relay:send(mcp_messages.recorded('tools/list'))

  local tools = get(decoded(relay:next_line()), 'result', 'tools')
  local listed = tools[#tools - 1]
  local properties = listed.inputSchema.properties
  local step = properties.steps.items.properties
  eq({
    properties.title.maxLength,
    properties.summary.maxLength,
    properties.covers.minItems,
    properties.covers.maxItems,
    properties.covers.items.maxLength,
    properties.steps.minItems,
    properties.steps.maxItems,
    step.title.maxLength,
    step.introduces.maxItems,
    step.introduces.items.maxLength,
  }, { 200, 4096, 1, 16, 200, 1, 64, 200, 8, 80 })
  eq(
    listed.description:find(
      '`title`, the title of a step and each item of `covers` are at most 200 characters',
      1,
      true
    ) ~= nil,
    true
  )
  eq(
    listed.description:find(
      '`summary` at most 4096 characters, `covers` 1 to 16 items, `steps` 1 to 64, a step introduces at most 8 concepts of at most 80 characters',
      1,
      true
    ) ~= nil,
    true
  )
end

T['a call'] = MiniTest.new_set()

T['a call']['whose arguments are refused is a tool error naming the field'] = MiniTest.new_set({
  parametrize = {
    { 42, 'arguments: expected an object' },
    { plan_with({ title = vim.NIL }), 'title: expected a non-empty string' },
    { plan_with({ title = '' }), 'title: expected a non-empty string' },
    { plan_with({ title = 'one\ntwo' }), 'title: holds a NUL or a line break' },
    { plan_with({ title = 'one\0two' }), 'title: holds a NUL or a line break' },
    { plan_with({ title = ('t'):rep(201) }), 'title: longer than 200 characters' },
    { plan_with({ title = ('日'):rep(201) }), 'title: longer than 200 characters' },
    { plan_with({ title = '   ' }), 'title: expected a non-empty string' },
    { plan_with({ summary = ' \t ' }), 'summary: expected a non-empty string' },
    { plan_with({ covers = { 'fine', ' ' } }), 'covers[2]: expected a non-empty string' },
    { plan_with({ summary = vim.NIL }), 'summary: expected a non-empty string' },
    { plan_with({ summary = '' }), 'summary: expected a non-empty string' },
    { plan_with({ summary = 'one\0two' }), 'summary: holds a NUL' },
    { plan_with({ summary = ('s'):rep(4097) }), 'summary: longer than 4096 characters' },
    { plan_with({ covers = 'all' }), 'covers: expected an array of 1 to 16 items' },
    { plan_with({ covers = {} }), 'covers: expected an array of 1 to 16 items' },
    { plan_with({ covers = repeated(17, 'a feature') }), 'covers: more than 16' },
    { plan_with({ covers = { 'fine', 7 } }), 'covers[2]: expected a non-empty string' },
    { plan_with({ covers = { '' } }), 'covers[1]: expected a non-empty string' },
    { plan_with({ covers = { 'one\ntwo' } }), 'covers[1]: holds a NUL or a line break' },
    { plan_with({ covers = { ('c'):rep(201) } }), 'covers[1]: longer than 200 characters' },
    { plan_with({ steps = 'all' }), 'steps: expected an array of 1 to 64 items' },
    { plan_with({ steps = {} }), 'steps: expected an array of 1 to 64 items' },
    { plan_with({ steps = vim.fn.range(65) }), 'steps: more than 64' },
    { plan_with({ steps = { 'all' } }), 'steps[1]: expected an object' },
    {
      plan_with({ steps = { step_with({ title = '' }) } }),
      'steps[1].title: expected a non-empty string',
    },
    {
      plan_with({ steps = { step_with({}), step_with({ title = 'one\ntwo' }) } }),
      'steps[2].title: holds a NUL or a line break',
    },
    {
      plan_with({ steps = { step_with({ title = '   ' }) } }),
      'steps[1].title: expected a non-empty string',
    },
    {
      plan_with({ steps = { step_with({ introduces = { ' ' } }) } }),
      'steps[1].introduces[1]: expected a non-empty string',
    },
    {
      plan_with({ steps = { step_with({ title = ('t'):rep(201) }) } }),
      'steps[1].title: longer than 200 characters',
    },
    {
      plan_with({ steps = { step_with({ file = vim.NIL }) } }),
      'steps[1].file: expected a non-empty string',
    },
    {
      plan_with({ steps = { step_with({ file = 'lib/queue.lua' }) } }),
      'steps[1].file: expected an absolute path',
    },
    {
      plan_with({ steps = { step_with({ file = '/repo/a\nb.lua' }) } }),
      'steps[1].file: holds a NUL or a line break',
    },
    {
      plan_with({ steps = { step_with({ file = '/' .. ('a'):rep(4096) }) } }),
      'steps[1].file: longer than 4096 bytes',
    },
    {
      plan_with({ steps = { step_with({ introduces = 'job' }) } }),
      'steps[1].introduces: expected an array of at most 8 names',
    },
    {
      plan_with({ steps = { step_with({ introduces = repeated(9, 'a name') }) } }),
      'steps[1].introduces: more than 8',
    },
    {
      plan_with({ steps = { step_with({ introduces = { 'job', '' } }) } }),
      'steps[1].introduces[2]: expected a non-empty string',
    },
    {
      plan_with({ steps = { step_with({ introduces = { 'one\ntwo' } }) } }),
      'steps[1].introduces[1]: holds a NUL or a line break',
    },
    {
      plan_with({ steps = { step_with({ introduces = { ('n'):rep(81) } }) } }),
      'steps[1].introduces[1]: longer than 80 characters',
    },
    {
      plan_with({ steps = { step_with({ colour = 'red' }) } }),
      'steps[1].colour: not a field of a step',
    },
    { plan_with({ run = 'now' }), 'run: not a field of walkthrough_plan' },
  },
})

T['a call']['whose arguments are refused is a tool error naming the field']['given'] = function(
  arguments,
  refusal
)
  local relay = mcp_relay.start_relay({
    AINEO_EDITOR_ADDRESS = '/nonexistent/editor.sock',
    AINEO_START_TOKEN = TOKEN,
  })

  relay:send(call(arguments))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('aineo refused the walkthrough plan: ' .. refusal, true)
  )
end

T['in the editor'] = MiniTest.new_set()

T['in the editor']['a valid call is offered to the handler, with the start token, and answered with its words'] = function()
  children.restart(editor)
  editor.lua([[
    require('aineo.mcp').on_walkthrough_planned(function(call, start_token)
      _G.offered = { call = call, token = start_token }
      return { text = 'Showing the plan', is_error = false }
    end)
  ]])
  local relay = mcp_relay.start_relay({
    AINEO_EDITOR_ADDRESS = editor.job.address,
    AINEO_START_TOKEN = TOKEN,
  })

  relay:send(call(plan_with({})))

  eq(get(decoded(relay:next_line()), 'result'), result_of('Showing the plan', false))
  eq(editor.lua_get('_G.offered'), {
    call = {
      title = 'The queue',
      summary = 'How jobs reach the queue and leave it.',
      covers = { 'The queue type', 'Taking a job' },
      steps = {
        { title = 'The queue type', file = '/repo/lib/queue.lua', introduces = { 'job', 'queue' } },
        { title = 'Taking a job', file = '/repo/lib/take.lua', introduces = {} },
      },
    },
    token = TOKEN,
  })
end

T['in the editor']['a call with no handler registered is not taken'] = function()
  children.restart(editor)
  local relay = mcp_relay.start_relay({
    AINEO_EDITOR_ADDRESS = editor.job.address,
    AINEO_START_TOKEN = TOKEN,
  })

  relay:send(call(plan_with({})))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('not taken: the editor that started Claude Code shows no walkthrough plan', true)
  )
end

T['in the editor']['a call without an editor address is not taken, and offers nothing'] = function()
  local relay = mcp_relay.start_relay({ AINEO_START_TOKEN = TOKEN })

  relay:send(call(plan_with({})))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('not taken: the editor that started Claude Code shows no walkthrough plan', true)
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
    require('aineo.mcp').on_walkthrough_planned(function()
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

T['in the editor']['takes 16 covers, 64 steps and 8 names a step introduces, the most a plan has'] = function()
  local steps = {}
  for _ = 1, 64 do
    table.insert(steps, step_with({ introduces = repeated(8, 'a name') }))
  end

  eq(
    answer_of_a_taking_editor(plan_with({ covers = repeated(16, 'a feature'), steps = steps })),
    result_of('shown', false)
  )
end

T['in the editor']['counts characters, not bytes: 200 characters of three bytes each are taken'] = function()
  local plan = plan_with({
    title = ('日'):rep(200),
    summary = ('日'):rep(4096),
    covers = { ('日'):rep(200) },
    steps = { step_with({ title = ('日'):rep(200), introduces = { ('日'):rep(80) } }) },
  })

  eq(answer_of_a_taking_editor(plan), result_of('shown', false))
end

T['in the editor']['takes a summary of 4 KiB, and titles, covers and names at their longest'] = function()
  local plan = plan_with({
    title = ('t'):rep(200),
    summary = ('s'):rep(4096),
    covers = { ('c'):rep(200) },
    steps = { step_with({ title = ('t'):rep(200), introduces = { ('n'):rep(80) } }) },
  })

  eq(answer_of_a_taking_editor(plan), result_of('shown', false))
end

return T
