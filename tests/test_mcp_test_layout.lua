local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local mcp_messages = dofile('tests/helpers/mcp_messages.lua')
local mcp_relay = dofile('tests/helpers/mcp_relay.lua')

local eq = MiniTest.expect.equality
local get = vim.tbl_get
local decoded = mcp_relay.decoded

--- The child Neovim a relay offers calls to: the user's editor.
local editor = MiniTest.new_child_neovim()

--- The start token the relay is told in each case.
local TOKEN = 'start-token-1'

--- The fixture tree of Python layouts.
local PYTHON_TREE = vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'fixtures', 'test_layout', 'python')

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      for name, value in pairs(git_repo.ENVIRONMENT) do
        vim.env[name] = value
      end
    end,
    post_case = mcp_relay.stop_all,
    post_once = editor.stop,
  },
})

--- A relay told the editor `address` and the start token `TOKEN`.
---
---@param address string
---@return aineo.test.Relay
local function relay_for(address)
  return mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = address, AINEO_START_TOKEN = TOKEN })
end

--- The `tools/call` line of the test layout tool with `arguments`, its id 7.
---
---@param arguments any
---@return string
local function call(arguments)
  return mcp_messages.tools_call('test_layout', arguments, 7)
end

--- The `tools/call` result of one text item, a tool error when `is_error`.
---
---@param text string
---@param is_error boolean
---@return table
local function result_of(text, is_error)
  return { isError = is_error, content = { { type = 'text', text = text } } }
end

--- A fresh git repository holding a copy of the Python fixture tree, its
--- files untracked; its folder as the file system resolves it.
---
---@return string top
local function python_repository()
  local top = git_repo.create_unborn('mcp-test-layout')
  for name, kind in vim.fs.dir(PYTHON_TREE, { depth = math.huge }) do
    if kind == 'file' then
      local copy = vim.fs.joinpath(top, name)
      vim.fn.mkdir(vim.fs.dirname(copy), 'p')
      assert(vim.uv.fs_copyfile(vim.fs.joinpath(PYTHON_TREE, name), copy))
    end
  end
  return assert(vim.uv.fs_realpath(top))
end

--- Restarts the editor, its working folder `folder`, with the handlers
--- aineo's composition root makes for a tab's Claude Code.
---
---@param folder string
local function restart_editor_with_handlers(folder)
  children.restart(editor)
  editor.cmd('cd ' .. vim.fn.fnameescape(folder))
  editor.lua([[require('aineo.entry.editors').make_editor_handlers()]])
end

T['tools/list'] = MiniTest.new_set()

T['tools/list']['lists test_layout last, with its worktree and rules required'] = function()
  local relay = mcp_relay.start_relay()

  relay:send(mcp_messages.recorded('tools/list'))

  local tools = get(decoded(relay:next_line()), 'result', 'tools')
  local listed = tools[#tools]
  eq(
    { listed.name, listed.inputSchema.required, listed.inputSchema.additionalProperties },
    { 'test_layout', { 'worktree', 'rules' }, false }
  )
end

T['a call'] = MiniTest.new_set()

T['a call']['whose arguments are refused is a tool error naming the field'] = MiniTest.new_set({
  parametrize = {
    { 42, 'arguments: expected an object' },
    { { rules = {} }, 'worktree: expected a non-empty string' },
    { { worktree = 'repo', rules = {} }, 'worktree: expected an absolute path' },
    { { worktree = '/repo', rules = 'pytest' }, 'rules: expected an array' },
    { { worktree = '/repo', rules = { 'python.pytest.flat' } }, 'rules[1]: expected an object' },
    { { worktree = '/repo', rules = {}, framework = 3 }, 'framework: expected a string' },
    { { worktree = '/repo', rules = {}, replace = 'no' }, 'replace: expected true or false' },
    { { worktree = '/repo', rules = {}, run = 'pytest' }, 'run: not a field of test_layout' },
  },
})

T['a call']['whose arguments are refused is a tool error naming the field']['given'] = function(
  arguments,
  refusal
)
  local relay = relay_for('/nonexistent/editor.sock')

  relay:send(call(arguments))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('aineo refused the test layout: ' .. refusal, true)
  )
end

T['in the editor'] = MiniTest.new_set()

T['in the editor']['a valid call keeps the rules and answers what each pairs'] = function()
  local top = python_repository()
  restart_editor_with_handlers(top)
  local relay = relay_for(editor.job.address)

  relay:send(call({ worktree = top, rules = { { preset = 'python.pytest.suffix' } } }))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of(
      'aineo keeps 1 rule for this repository:\n'
        .. '1. agent rule 1 (python.pytest.suffix): pairs 1 source with a test, 0 contradictions',
      false
    )
  )
  eq(
    editor.lua_get(
      ('require("aineo.test_layout").test_for(%q).origin'):format(top .. '/lib/extra.py')
    ),
    'agent'
  )
end

T['in the editor']['rules the editor refuses are a tool error saying why'] = function()
  local top = python_repository()
  restart_editor_with_handlers(top)
  local relay = relay_for(editor.job.address)

  relay:send(call({ worktree = top, rules = { { preset = 'python.nose' } } }))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('aineo refused the test layout: rules[1].preset: no preset python.nose', true)
  )
end

T['in the editor']['a call for a repository the editor has not open is refused'] = function()
  local top = python_repository()
  restart_editor_with_handlers(vim.fn.getcwd())
  local relay = relay_for(editor.job.address)

  relay:send(call({ worktree = top, rules = { { preset = 'python.pytest.suffix' } } }))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of(
      'aineo refused the test layout: worktree: '
        .. top
        .. ' is no checkout of a repository the editor has open',
      true
    )
  )
end

T['in the editor']['a call with no handler registered is not taken'] = function()
  children.restart(editor)
  local relay = relay_for(editor.job.address)

  relay:send(call({ worktree = '/repo', rules = {} }))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('not taken: the editor that started Claude Code keeps no test layout', true)
  )
end

return T
