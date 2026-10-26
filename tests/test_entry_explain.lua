local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- How long a case waits for the child to reach a state, in milliseconds.
local PATIENCE_MS = 10000

local CHECKOUT = vim.fn.fnamemodify('.', ':p'):gsub('/$', '')

--- The fake `claude`, run in the real one's place (`tests/helpers/fake_claude.lua`,
--- through `tests/helpers/fake_claude_print.sh`, whose words hold no flag).
local FAKE_CLAUDE = { 'sh', CHECKOUT .. '/tests/helpers/fake_claude_print.sh' }

--- The record the fake `claude` writes.
local RECORD = vim.fs.joinpath(CHECKOUT, '.tests', 'fixtures', 'entry-explain', 'fake.jsonl')

--- The lines of the file every case explains.
local CODE = {
  'local function add(a, b)',
  '  return a + b',
  'end',
  '',
  'return add',
}

--- Starts the child afresh, aineo's prefix mapped, with `src/add.lua`
--- (`CODE`) open in a git repository, aineo configured to run the fake
--- `claude` with the settings `explain` (`vim.g.aineo`'s `explain`), and the
--- notifications it shows kept (`told()`).
---
---@param explain? table
local function start(explain)
  children.restart(child)
  local folder = git_repo.create_unborn('entry-explain')
  git_repo.write(folder, 'src/add.lua', CODE)
  fixture.directory('entry-explain')
  child.lua(
    [[
    local record, command, explain = ...
    vim.env.AINEO_FAKE_CLAUDE_RECORD = record
    vim.g.aineo = { autostart = false, claude = { cmd = command }, explain = explain }
    vim.o.timeoutlen = 100
    _G.told = {}
    vim.notify = function(message, level)
      table.insert(_G.told, { message = message, level = level })
    end
  ]],
    { RECORD, FAKE_CLAUDE, explain or vim.empty_dict() }
  )
  child.cmd('edit ' .. folder .. '/src/add.lua')
end

--- Types `keys` in the child and waits until it has settled: `\v` and `\V`
--- are the start of `\vi` and `\VI` too, so that the child waits for the
--- next key until 'timeoutlen' (`start()` shortens it) before it runs them.
---
---@param ... string
local function press(...)
  child.type_keys(...)
  vim.wait(PATIENCE_MS, function()
    return not child.is_blocked()
  end, 20)
end

--- The lines the fake `claude` recorded, decoded, once it has recorded at
--- least `count` of them, or after `PATIENCE_MS`.
---
---@param count integer
---@return table[]
local function recorded(count)
  local lines = {}
  vim.wait(PATIENCE_MS, function()
    lines = vim.uv.fs_stat(RECORD) and vim.fn.readfile(RECORD) or {}
    return #lines >= count
  end, 20)
  return vim.tbl_map(vim.json.decode, lines)
end

--- The words the fake `claude` was started with from the model on: the
--- model, `--setting-sources` and its value, `--tools` and the words that
--- name the tools; none when it did not
--- start within `PATIENCE_MS`.
---
---@return string[]
local function model_and_tools()
  return vim.list_slice((recorded(1)[1] or { argv = {} }).argv, 9)
end

--- The first line of the prompt the fake `claude` read; none when it read
--- none within `PATIENCE_MS`.
---
---@return string?
local function prompt_head()
  return vim.split((recorded(2)[2] or { stdin = '' }).stdin, '\n')[1]
end

T['\\v'] = MiniTest.new_set()

T['\\v']['in Normal mode explains the whole buffer with the code alone, with the model configured'] = function()
  start({ model = 'opus' })

  press('\\v')

  eq(model_and_tools(), { 'opus', '--setting-sources', 'user', '--tools', '' })
  eq(
    prompt_head(),
    'Explain the code of the file src/add.lua (language: lua), lines 1 to 5 as numbered below.'
  )
end

T['\\V'] = MiniTest.new_set()

T['\\V']['in Normal mode explains the whole buffer with read-only tools, with Sonnet by default'] = function()
  start()

  press('\\V')

  eq(model_and_tools(), {
    'sonnet',
    '--setting-sources',
    'user',
    '--tools',
    'Read,Grep,Glob',
    '--allowedTools',
    'Read,Grep,Glob',
  })
  eq(
    prompt_head(),
    'Explain the code of the file src/add.lua (language: lua), lines 1 to 5 as numbered below.'
  )
end

T['\\v']['in Visual mode explains the lines selected alone, and leaves Visual mode'] = function()
  start()

  press('2G', 'Vj', '\\v')

  eq(model_and_tools(), { 'sonnet', '--setting-sources', 'user', '--tools', '' })
  eq(
    prompt_head(),
    'Explain the code of the file src/add.lua (language: lua), lines 2 to 3 as numbered below.'
  )
  eq(child.fn.mode(), 'n')
end

T['\\V']['in Visual mode explains the lines selected alone, with read-only tools'] = function()
  start()

  press('2G', 'Vj', '\\V')

  eq(model_and_tools(), {
    'sonnet',
    '--setting-sources',
    'user',
    '--tools',
    'Read,Grep,Glob',
    '--allowedTools',
    'Read,Grep,Glob',
  })
  eq(
    prompt_head(),
    'Explain the code of the file src/add.lua (language: lua), lines 2 to 3 as numbered below.'
  )
  eq(child.fn.mode(), 'n')
end

T['\\v']['in Visual mode takes a selection made upwards as the same lines'] = function()
  start()

  press('3G', 'Vk', '\\v')

  eq(
    prompt_head(),
    'Explain the code of the file src/add.lua (language: lua), lines 2 to 3 as numbered below.'
  )
end

T[':Aineo explain'] = MiniTest.new_set()

T[':Aineo explain']['with a range and tools explains those lines with read-only tools'] = function()
  start()

  child.cmd('2,3Aineo explain tools')

  eq(model_and_tools(), {
    'sonnet',
    '--setting-sources',
    'user',
    '--tools',
    'Read,Grep,Glob',
    '--allowedTools',
    'Read,Grep,Glob',
  })
  eq(
    prompt_head(),
    'Explain the code of the file src/add.lua (language: lua), lines 2 to 3 as numbered below.'
  )
end

--- The number of lines of the current buffer that show explanations, once
--- it is `count`, or after `PATIENCE_MS`.
---
---@param count integer
---@return integer
local function explained_lines_once(count)
  local marks = 0
  vim.wait(PATIENCE_MS, function()
    marks = child.lua_get(
      [[#vim.tbl_filter(function(mark)
      return not vim.inspect(mark[4].virt_lines):find('explaining', 1, true)
    end, vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace('aineo_explain'), 0, -1, { details = true }))]]
    )
    return marks == count
  end, 20)
  return marks
end

--- Has the fake `claude` answer `explanations`.
---
---@param explanations { line: integer, text: string }[]
local function answer_explanations(explanations)
  local answer = fixture.write('entry-explain/answer.json', {
    vim.json.encode({
      type = 'result',
      subtype = 'success',
      is_error = false,
      result = '',
      structured_output = { explanations = explanations },
    }),
  })
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT = ...', { answer })
end

T[':Aineo explain']['clear removes every explanation the buffer shows, and says so once'] = function()
  start()
  answer_explanations({ { line = 2, text = 'Adds.' }, { line = 5, text = 'Returns it.' } })
  child.cmd('Aineo explain')
  explained_lines_once(2)

  child.cmd('Aineo explain clear')

  eq(explained_lines_once(0), 0)
  eq(child.lua_get('_G.told'), {
    { message = 'aineo: explanations cleaned from this buffer', level = vim.log.levels.INFO },
  })
end

T[':Aineo explain']['with another word says which it takes, and asks nothing'] = function()
  start()

  child.cmd('Aineo explain all')

  eq(child.lua_get('_G.told'), {
    {
      message = 'aineo: :Aineo explain takes one of tools, issues, new, clear',
      level = vim.log.levels.ERROR,
    },
  })
  eq(vim.uv.fs_stat(RECORD), nil)
end

local RANGE_REFUSAL = {
  message = 'aineo: only :Aineo explain takes a range',
  level = vim.log.levels.ERROR,
}

T[':Aineo explain']['is the only subcommand that takes a range'] = MiniTest.new_set({
  parametrize = { { 'diff close' }, { 'zoom full' }, { 'tab 1' }, { 'claim' }, { 'bogus' } },
})

T[':Aineo explain']['is the only subcommand that takes a range']['given'] = function(arguments)
  start()

  child.cmd('2,3Aineo ' .. arguments)

  eq(child.lua_get('_G.told'), { RANGE_REFUSAL })
  eq(vim.uv.fs_stat(RECORD), nil)
end

T[':Aineo explain']['is offered after :Aineo, and tools, issues, new and clear after it, after a range too'] =
  MiniTest.new_set({
    parametrize = {
      { 'Aineo e', { 'explain' } },
      { 'Aineo explain ', { 'tools', 'issues', 'new', 'clear' } },
      { 'Aineo explain t', { 'tools' } },
      { '2,3Aineo explain ', { 'tools', 'issues', 'new', 'clear' } },
      { "'<,'>Aineo explain c", { 'clear' } },
      { 'Aineo explain tools ', { 'new' } },
      { 'Aineo explain issues ', { 'tools', 'new' } },
      { 'Aineo explain issues t', { 'tools' } },
      { 'Aineo explain issues tools ', { 'new' } },
      { 'Aineo explain issues tools new ', {} },
      { 'Aineo explain new ', {} },
      { 'Aineo explain clear ', {} },
      { 'Aineo explain n', { 'new' } },
      { 'Aineo explain i', { 'issues' } },
    },
  })

T[':Aineo explain']['is offered after :Aineo, and tools, issues, new and clear after it, after a range too']['typed'] = function(
  typed,
  completed
)
  start()

  eq(child.fn.getcompletion(typed, 'cmdline'), completed)
end

T['\\v']['pressed again in Normal mode clears the explanations'] = function()
  start()
  answer_explanations({ { line = 2, text = 'Adds.' }, { line = 5, text = 'Returns it.' } })
  press('\\v')
  explained_lines_once(2)

  press('\\v')

  eq(explained_lines_once(0), 0)
end

T['\\v']['in a buffer that holds no file says so, and asks nothing'] = function()
  start()
  child.cmd('enew')
  child.bo.buftype = 'nofile'

  press('\\v')

  eq(child.lua_get('_G.told'), {
    { message = 'aineo: explaining works in the buffer of a file', level = vim.log.levels.ERROR },
  })
  eq(vim.uv.fs_stat(RECORD), nil)
end

T['\\v']['stops Claude Code at the timeout configured, and says so'] = function()
  start({ timeout_ms = 3000 })
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "20000"')

  press('\\v')

  eq(
    vim.wait(PATIENCE_MS, function()
      return #child.lua_get('_G.told') > 0
    end, 20),
    true
  )
  eq(child.lua_get('_G.told'), {
    {
      message = 'aineo: explaining failed: Claude Code did not answer within 3 s',
      level = vim.log.levels.ERROR,
    },
  })
end

local ISSUES_HEAD =
  'Review the code of the file src/add.lua (language: lua), lines %d to %d as numbered below, for potential issues.'

local READ_ONLY = {
  '--tools',
  'Read,Grep,Glob',
  '--allowedTools',
  'Read,Grep,Glob',
}

--- The number of lines of the current buffer that show issues, once it is
--- `count`, or after `PATIENCE_MS`.
---
---@param count integer
---@return integer
local function issue_lines_once(count)
  local marks = 0
  vim.wait(PATIENCE_MS, function()
    marks = child.lua_get(
      [[#vim.tbl_filter(function(mark)
      return not vim.inspect(mark[4].virt_lines):find('looking for issues', 1, true)
    end, vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace('aineo_explain_issues'), 0, -1, { details = true }))]]
    )
    return marks == count
  end, 20)
  return marks
end

T['\\vi'] = MiniTest.new_set()

T['\\vi']['in Normal mode asks for the potential issues of the whole buffer, with the code alone'] = function()
  start()

  press('\\vi')

  eq(model_and_tools(), { 'sonnet', '--setting-sources', 'user', '--tools', '' })
  eq(prompt_head(), ISSUES_HEAD:format(1, 5))
end

T['\\vi']['in Visual mode asks for the issues of the lines selected alone, and leaves Visual mode'] = function()
  start()

  press('2G', 'Vj', '\\vi')

  eq(prompt_head(), ISSUES_HEAD:format(2, 3))
  eq(child.fn.mode(), 'n')
end

T['\\vi']['shows the issues, and pressed again in Normal mode clears them alone, the explanations staying'] = function()
  start()
  answer_explanations({ { line = 2, text = 'Adds.' } })
  press('\\v')
  explained_lines_once(1)
  answer_explanations({ { line = 5, text = 'Returns nothing.' } })
  press('\\vi')
  issue_lines_once(1)

  press('\\vi')

  eq(issue_lines_once(0), 0)
  eq(explained_lines_once(1), 1)
end

T['\\v']['pressed in Normal mode with issues shown clears the explanations alone, the issues staying'] = function()
  start()
  answer_explanations({ { line = 2, text = 'Adds.' } })
  press('\\v')
  explained_lines_once(1)
  answer_explanations({ { line = 5, text = 'Returns nothing.' } })
  press('\\vi')
  issue_lines_once(1)

  press('\\v')

  eq(explained_lines_once(0), 0)
  eq(issue_lines_once(1), 1)
end

T['\\VI'] = MiniTest.new_set()

T['\\VI']['in Normal mode asks for the issues of the whole buffer, with read-only tools'] = function()
  start()

  press('\\VI')

  eq(vim.list_slice(model_and_tools(), 4), READ_ONLY)
  eq(prompt_head(), ISSUES_HEAD:format(1, 5))
end

T['\\VI']['in Visual mode asks for the issues of the lines selected alone, with read-only tools'] = function()
  start()

  press('2G', 'Vj', '\\VI')

  eq(vim.list_slice(model_and_tools(), 4), READ_ONLY)
  eq(prompt_head(), ISSUES_HEAD:format(2, 3))
  eq(child.fn.mode(), 'n')
end

T[':Aineo explain']['issues asks for the issues of the lines given, and issues tools reads the project too'] =
  MiniTest.new_set({
    parametrize = {
      { '2,3Aineo explain issues', { '--tools', '' } },
      { '2,3Aineo explain issues tools', READ_ONLY },
    },
  })

T[':Aineo explain']['issues asks for the issues of the lines given, and issues tools reads the project too']['typed'] = function(
  typed,
  tools
)
  start()

  child.cmd(typed)

  eq(vim.list_slice(model_and_tools(), 4), tools)
  eq(prompt_head(), ISSUES_HEAD:format(2, 3))
end

T[':Aineo explain']['clear removes the issues too'] = function()
  start()
  answer_explanations({ { line = 2, text = 'Adds.' } })
  child.cmd('Aineo explain')
  explained_lines_once(1)
  child.cmd('Aineo explain issues')
  issue_lines_once(1)

  child.cmd('Aineo explain clear')

  eq(explained_lines_once(0), 0)
  eq(issue_lines_once(0), 0)
end

T[':Aineo explain']['tools issues, and issues with a third word, say which words it takes, and ask nothing'] =
  MiniTest.new_set({
    parametrize = {
      { 'Aineo explain tools issues' },
      { 'Aineo explain issues tools all' },
      { 'Aineo explain new tools' },
      { 'Aineo explain clear new' },
    },
  })

T[':Aineo explain']['tools issues, and issues with a third word, say which words it takes, and ask nothing']['typed'] = function(
  typed
)
  start()

  child.cmd(typed)

  eq(child.lua_get('_G.told'), {
    {
      message = 'aineo: :Aineo explain takes one of tools, issues, new, clear',
      level = vim.log.levels.ERROR,
    },
  })
  eq(vim.uv.fs_stat(RECORD), nil)
end

--- The number of times the fake `claude` has started, once it has started
--- `count`, or after `PATIENCE_MS`.
---
---@param count integer
---@return integer
local function started_once(count)
  return #recorded(count * 2) / 2
end

T[':Aineo explain']['shows the kept answer when the code is unchanged, and new asks again'] = function()
  start()
  answer_explanations({ { line = 2, text = 'Adds.' } })
  child.cmd('Aineo explain')
  explained_lines_once(1)
  child.cmd('Aineo explain')
  eq(explained_lines_once(0), 0)

  child.cmd('Aineo explain')

  eq(explained_lines_once(1), 1)
  eq(child.lua_get('_G.told'), {
    {
      message = 'aineo: the earlier answer, the code unchanged (:Aineo explain new asks again)',
      level = vim.log.levels.INFO,
    },
  })
  eq(started_once(1), 1)

  child.cmd('Aineo explain new')

  eq(started_once(2), 2)
end

T[':Aineo explain']['clear drops the kept answer, so asking again asks anew'] = function()
  start()
  answer_explanations({ { line = 2, text = 'Adds.' } })
  child.cmd('Aineo explain')
  explained_lines_once(1)
  child.cmd('Aineo explain clear')

  child.cmd('Aineo explain')

  eq(started_once(2), 2)
end

T[':Aineo explain']['issues tools new asks the issues again with read-only tools'] = function()
  start()
  answer_explanations({ { line = 2, text = 'Adds.' } })
  child.cmd('Aineo explain issues tools')
  issue_lines_once(1)
  child.cmd('Aineo explain clear')

  child.cmd('Aineo explain issues tools new')

  eq(started_once(2), 2)
end

return T
