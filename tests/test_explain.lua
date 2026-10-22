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

--- The schema every request hands Claude Code: an object holding the list of
--- explanations, each a line and its text, nothing else.
local SCHEMA = {
  type = 'object',
  properties = {
    explanations = {
      type = 'array',
      items = {
        type = 'object',
        properties = { line = { type = 'integer' }, text = { type = 'string' } },
        required = { 'line', 'text' },
        additionalProperties = false,
      },
    },
  },
  required = { 'explanations' },
  additionalProperties = false,
}

--- The lines of the file every case explains, in a project's `src/` folder.
local CODE = {
  'local function add(a, b)',
  '  return a + b',
  'end',
  '',
  'return add',
}

--- Starts the child afresh, its screen 60 columns wide, with the file
--- `<folder>/src/add.lua` (`CODE`) open, and the fake `claude`'s record and
--- the notifications the child shows kept (`recorded()`, `told()`).
---
---@param folder string
local function start_with_file(folder)
  children.restart(child)
  child.o.columns = 60
  vim.fn.mkdir(folder .. '/src', 'p')
  vim.fn.writefile(CODE, folder .. '/src/add.lua')
  local record = fixture.directory('explain/record') .. '/fake.jsonl'
  child.lua(
    [[
    vim.env.AINEO_FAKE_CLAUDE_RECORD = ...
    _G.told = {}
    vim.notify = function(message, level)
      table.insert(_G.told, { message = message, level = level })
    end
  ]],
    { record }
  )
  child.cmd('edit ' .. folder .. '/src/add.lua')
end

--- Starts the child as `start_with_file()` does, the file in a project that
--- is a git repository of its own, made with the git home's suites'
--- isolation (`git_repo.create_unborn()`). Returns the project's folder.
---
---@return string folder
local function start_with_project()
  local folder = git_repo.create_unborn('explain')
  start_with_file(folder)
  return folder
end

--- Starts the child as `start_with_file()` does, the file in a folder outside
--- any git repository. Returns that folder.
---
---@return string folder
local function start_outside_git()
  local folder = vim.fn.tempname()
  start_with_file(folder)
  return folder
end

--- Asks the explain home to explain the current buffer, in the current
--- window, with the request's other fields from `fields`: the code alone,
--- with the fake `claude`, `sonnet` and a long timeout unless they say
--- otherwise.
---
---@param fields? table
local function explain(fields)
  child.lua(
    [[
    local fields = ...
    require('aineo.explain').ask(vim.tbl_extend('force', {
      buffer = vim.api.nvim_get_current_buf(),
      window = vim.api.nvim_get_current_win(),
      tools = false,
      command = fields.command,
      model = 'sonnet',
      timeout_ms = 180000,
    }, fields))
  ]],
    { vim.tbl_extend('keep', fields or {}, { command = FAKE_CLAUDE }) }
  )
end

--- The lines the fake `claude` recorded, decoded, once it has recorded at
--- least `count` of them.
---
---@param count integer
---@return table[]
local function recorded(count)
  local record = vim.fs.joinpath(CHECKOUT, '.tests', 'fixtures', 'explain', 'record', 'fake.jsonl')
  local lines = {}
  vim.wait(PATIENCE_MS, function()
    lines = vim.uv.fs_stat(record) and vim.fn.readfile(record) or {}
    return #lines >= count
  end, 20)
  return vim.tbl_map(vim.json.decode, lines)
end

--- Has the fake `claude` print `text` as its answer.
---
---@param text string
local function answer_text(text)
  local answer = fixture.write('explain/answer.json', { text })
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT = ...', { answer })
end

--- Has the fake `claude` answer a successful result whose structured output
--- holds `explanations`, as Claude Code documents `--output-format json`
--- with `--json-schema`.
---
---@param explanations { line: any, text: any }[]
local function answer_explanations(explanations)
  answer_text(vim.json.encode({
    type = 'result',
    subtype = 'success',
    is_error = false,
    result = '',
    structured_output = { explanations = explanations },
  }))
end

--- What the child shows of the explanations, line by line: for each line
--- with an extmark of the namespace `aineo_explain`, from the top, the line's
--- number from 1 and the virtual lines above it, each as its chunks.
local SHOWN = [[(function()
  local namespace = vim.api.nvim_get_namespaces().aineo_explain
  if not namespace then
    return {}
  end
  local shown = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })) do
    table.insert(shown, {
      line = mark[2] + 1,
      above = mark[4].virt_lines_above,
      virt_lines = mark[4].virt_lines,
    })
  end
  return shown
end)()]]

--- What the child shows of the explanations (`SHOWN`), once it shows a
--- virtual line holding `text`, or after `PATIENCE_MS`.
---
---@param text string
---@return table[]
local function shown_once_it_holds(text)
  local shown = {}
  vim.wait(PATIENCE_MS, function()
    shown = child.lua_get(SHOWN)
    return vim.inspect(shown):find(text, 1, true) ~= nil
  end, 20)
  return shown
end

T['an answer'] = MiniTest.new_set()

T['an answer']['shows each explanation as a virtual line above its line, indented as it, after the mark ┊'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'Adds the two numbers.' } })

  explain()

  eq(shown_once_it_holds('Adds'), {
    {
      line = 2,
      above = true,
      virt_lines = { { { '  ┊ Adds the two numbers.', 'AineoExplain' } } },
    },
  })
end

T['an answer']['shows explanations in AineoExplain, which links to Comment unless set'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'Adds the two numbers.' } })

  explain()
  shown_once_it_holds('Adds')

  eq(child.api.nvim_get_hl(0, { name = 'AineoExplain' }), { link = 'Comment', default = true })
end

T['an answer']['wraps an explanation at the window’s text width, less the line’s indent, by display width'] = function()
  start_with_project()
  child.wo.number = true
  answer_explanations({ { line = 2, text = vim.trim(('wörd '):rep(20)) } })

  explain()

  eq(shown_once_it_holds('wörd')[1].virt_lines, {
    { { '  ┊ ' .. vim.trim(('wörd '):rep(10)), 'AineoExplain' } },
    { { '  ┊ ' .. vim.trim(('wörd '):rep(10)), 'AineoExplain' } },
  })
end

T['an answer']['cuts a word wider than the room into rows of its own'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'See ' .. ('x'):rep(120) .. ' here.' } })

  explain()

  eq(shown_once_it_holds('See')[1].virt_lines, {
    { { '  ┊ See', 'AineoExplain' } },
    { { '  ┊ ' .. ('x'):rep(56), 'AineoExplain' } },
    { { '  ┊ ' .. ('x'):rep(56), 'AineoExplain' } },
    { { '  ┊ ' .. ('x'):rep(8) .. ' here.', 'AineoExplain' } },
  })
end

T['an answer']['cuts a very long word in time proportional to its length'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = ('x'):rep(60000) } })
  local started = vim.uv.hrtime()

  explain()

  local shown = shown_once_it_holds('xxxx')
  eq(#shown[1].virt_lines, math.ceil(60000 / 56))
  eq((vim.uv.hrtime() - started) / 1e6 < 2500, true)
end

T['an answer']['drops the NUL characters of an explanation, and tells nothing'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'Ad\0ds.' } })

  explain()

  eq(shown_once_it_holds('Adds.')[1].virt_lines, { { { '  ┊ Adds.', 'AineoExplain' } } })
  eq(child.lua_get('_G.told'), {})
end

T['an answer']['indents a line indented past half the room by half the room'] = function()
  start_with_project()
  child.o.columns = 30
  child.api.nvim_buf_set_lines(0, 1, 2, false, { (' '):rep(40) .. 'return a + b' })
  answer_explanations({ { line = 2, text = 'Adds the two numbers.' } })

  explain()

  eq(shown_once_it_holds('Adds')[1].virt_lines, {
    { { (' '):rep(15) .. '┊ Adds the two', 'AineoExplain' } },
    { { (' '):rep(15) .. '┊ numbers.', 'AineoExplain' } },
  })
end

T['an answer']['starts a new row at each line break of an explanation'] = function()
  start_with_project()
  answer_explanations({ { line = 1, text = 'First.\nSecond.' } })

  explain()

  eq(shown_once_it_holds('First')[1].virt_lines, {
    { { '┊ First.', 'AineoExplain' } },
    { { '┊ Second.', 'AineoExplain' } },
  })
end

T['an answer']['drops lines outside the buffer, empty texts and repeats, and joins several on one line in order'] = function()
  start_with_project()
  answer_explanations({
    { line = 0, text = 'Before the file.' },
    { line = 6, text = 'After the file.' },
    { line = 2, text = '' },
    { line = 2, text = '   ' },
    { line = 3, text = 'Ends it.' },
    { line = 2, text = 'Adds.' },
    { line = 3, text = 'Closes it.' },
    { line = 3, text = 'Ends it.' },
  })

  explain()

  eq(shown_once_it_holds('Closes'), {
    { line = 2, above = true, virt_lines = { { { '  ┊ Adds.', 'AineoExplain' } } } },
    { line = 3, above = true, virt_lines = { { { '┊ Ends it. Closes it.', 'AineoExplain' } } } },
  })
end

T['an answer']['drops explanations whose line is not a whole number or whose text is not a string'] = function()
  start_with_project()
  answer_explanations({
    { line = 2.5, text = 'Half a line.' },
    { line = '2', text = 'A string for a line.' },
    { line = 2, text = 42 },
    { text = 'No line.' },
    { line = 5, text = 'Returns it.' },
  })

  explain()

  eq(shown_once_it_holds('Returns'), {
    { line = 5, above = true, virt_lines = { { { '┊ Returns it.', 'AineoExplain' } } } },
  })
end

T['an answer']['for some lines drops the explanations of the lines outside them'] = function()
  start_with_project()
  answer_explanations({
    { line = 1, text = 'Before.' },
    { line = 2, text = 'Inside.' },
    { line = 4, text = 'After.' },
  })

  explain({ range = { 2, 3 } })

  eq(shown_once_it_holds('Inside'), {
    { line = 2, above = true, virt_lines = { { { '  ┊ Inside.', 'AineoExplain' } } } },
  })
end

T['an answer']['with no structured output is read from its result, when that holds the object'] = function()
  start_with_project()
  answer_text(vim.json.encode({
    type = 'result',
    subtype = 'success',
    is_error = false,
    result = vim.json.encode({ explanations = { { line = 5, text = 'Returns it.' } } }),
  }))

  explain()

  eq(shown_once_it_holds('Returns'), {
    { line = 5, above = true, virt_lines = { { { '┊ Returns it.', 'AineoExplain' } } } },
  })
end

--- The notifications the child has shown, once it has shown at least one,
--- or after `PATIENCE_MS`.
---
---@return { message: string, level: integer }[]
local function told()
  local notifications = {}
  vim.wait(PATIENCE_MS, function()
    notifications = child.lua_get('_G.told')
    return #notifications > 0
  end, 20)
  return notifications
end

local ERROR = vim.log.levels.ERROR

T['an answer']['shown moves with the lines it explains, and vanishes with a line deleted'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'Adds.' }, { line = 5, text = 'Returns it.' } })
  explain()
  shown_once_it_holds('Returns')

  child.api.nvim_buf_set_lines(0, 0, 0, false, { '-- a new first line' })
  child.cmd('3delete')

  eq(child.lua_get(SHOWN), {
    { line = 5, above = true, virt_lines = { { { '┊ Returns it.', 'AineoExplain' } } } },
  })
end

T['a failure'] = MiniTest.new_set()

T['a failure']['an error result is told once, and nothing is shown'] = function()
  start_with_project()
  answer_text(vim.json.encode({
    type = 'result',
    subtype = 'success',
    is_error = true,
    result = 'Not logged in',
    structured_output = { explanations = { { line = 2, text = 'Adds.' } } },
  }))

  explain()

  eq(told(), {
    {
      message = 'aineo: explaining failed: Claude Code answered an error: Not logged in',
      level = ERROR,
    },
  })
  eq(child.lua_get(SHOWN), {})
end

T['a failure']['an exit with a code other than 0 is told once, with the first line of its errors, and nothing is shown'] = function()
  start_with_project()
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_EXIT = "2"')

  explain()

  eq(told(), {
    {
      message = 'aineo: explaining failed: Claude Code exited with code 2: Error: fake failure',
      level = ERROR,
    },
  })
  eq(child.lua_get(SHOWN), {})
end

T['a failure']['an error result on a non-zero exit is told with its text rather than the exit code'] = function()
  start_with_project()
  answer_text(vim.json.encode({
    type = 'result',
    subtype = 'success',
    is_error = true,
    result = 'Not logged in',
  }))
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_EXIT = "1"')

  explain()

  eq(told(), {
    {
      message = 'aineo: explaining failed: Claude Code answered an error: Not logged in',
      level = ERROR,
    },
  })
  eq(child.lua_get(SHOWN), {})
end

T['a failure']['an answer that holds no explanations is told once, and nothing is shown'] =
  MiniTest.new_set({
    parametrize = {
      { 'not JSON at all' },
      { '[1, 2]' },
      { '{"type":"result","is_error":false,"result":"Here are the explanations."}' },
      {
        '{"type":"result","is_error":false,"result":"","structured_output":{"explanations":"none"}}',
      },
      { '{"type":"result","is_error":false,"result":"","structured_output":null}' },
    },
  })

T['a failure']['an answer that holds no explanations is told once, and nothing is shown']['as'] = function(
  output
)
  start_with_project()
  answer_text(output)

  explain()

  eq(told(), {
    { message = 'aineo: explaining failed: its answer holds no explanations', level = ERROR },
  })
  eq(child.lua_get(SHOWN), {})
end

--- Has the fake `claude` wait `delay_ms` before it answers.
---
---@param delay_ms integer
local function answer_after(delay_ms)
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = ...', { tostring(delay_ms) })
end

--- The virtual line shown above the first line asked for while a request
--- runs, indented as that line.
local function explaining_above(line, indent)
  return {
    line = line,
    above = true,
    virt_lines = { { { (' '):rep(indent) .. '┊ explaining…', 'AineoExplain' } } },
  }
end

T['while it runs'] = MiniTest.new_set()

T['while it runs']['a virtual line above the first line asked for says it is explaining, until the answer'] = function()
  start_with_project()
  answer_after(1500)
  answer_explanations({ { line = 3, text = 'Ends it.' } })

  explain({ range = { 2, 3 } })
  local while_running = shown_once_it_holds('explaining')
  local answered = shown_once_it_holds('Ends')

  eq(while_running, { explaining_above(2, 2) })
  eq(
    answered,
    { { line = 3, above = true, virt_lines = { { { '┊ Ends it.', 'AineoExplain' } } } } }
  )
end

T['while it runs']['a change to the buffer has the answer dropped, and the user told to ask again'] = function()
  start_with_project()
  answer_after(1000)
  answer_explanations({ { line = 2, text = 'Adds.' } })

  explain()
  shown_once_it_holds('explaining')
  child.api.nvim_buf_set_lines(0, 0, 0, false, { '-- a new first line' })

  eq(told(), {
    {
      message = 'aineo: src/add.lua changed while it was explained: nothing is shown; ask again',
      level = vim.log.levels.WARN,
    },
  })
  eq(child.lua_get(SHOWN), {})
end

T['while it runs']['a write of the buffer, which moves its change count, leaves the answer shown, as the lines are those sent'] = function()
  start_with_project()
  child.api.nvim_buf_set_lines(0, 1, 2, false, { '  return a + b -- not saved' })
  answer_after(1000)
  answer_explanations({ { line = 2, text = 'Adds.' } })

  explain()
  shown_once_it_holds('explaining')
  child.cmd('silent write')

  eq(told(), {})
  eq(shown_once_it_holds('Adds.')[1].virt_lines[1][1][1], '  ┊ Adds.')
end

T['asked again'] = MiniTest.new_set()

T['asked again']['for the whole buffer while it shows explanations clears them, and asks nothing'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'Adds.' }, { line = 5, text = 'Returns it.' } })
  explain()
  shown_once_it_holds('Returns')

  explain()

  eq(child.lua_get(SHOWN), {})
  eq(#recorded(2), 2)
end

T['asked again']['for some lines replaces the explanations inside them alone'] = function()
  start_with_project()
  answer_explanations({
    { line = 2, text = 'Adds.' },
    { line = 3, text = 'Ends it.' },
    { line = 5, text = 'Returns it.' },
  })
  explain()
  shown_once_it_holds('Returns')
  answer_explanations({ { line = 2, text = 'Adds them.' } })

  explain({ range = { 1, 3 } })

  eq(shown_once_it_holds('them'), {
    { line = 2, above = true, virt_lines = { { { '  ┊ Adds them.', 'AineoExplain' } } } },
    { line = 5, above = true, virt_lines = { { { '┊ Returns it.', 'AineoExplain' } } } },
  })
end

--- Whether the process `pid` has ended, once it has, or after `PATIENCE_MS`.
---
---@param pid integer
---@return boolean
local function has_ended(pid)
  return vim.wait(PATIENCE_MS, function()
    return vim.uv.kill(pid, 0) ~= 0
  end, 20)
end

--- The notifications the child shows within half a second, beyond those it
--- has shown already: a bounded wait for one that must not come.
---
---@return { message: string, level: integer }[]
local function told_later()
  local before = #child.lua_get('_G.told')
  vim.wait(500, function()
    return #child.lua_get('_G.told') > before
  end, 20)
  return vim.list_slice(child.lua_get('_G.told'), before + 1)
end

T['asked again']['while it runs stops Claude Code, says so, and shows nothing of it'] = function()
  start_with_project()
  answer_after(5000)
  answer_explanations({ { line = 2, text = 'Adds.' } })
  explain()
  shown_once_it_holds('explaining')
  local pid = recorded(1)[1].pid

  explain({ range = { 1, 3 } })

  eq(child.lua_get(SHOWN), {})
  eq(told(), { { message = 'aineo: explaining stopped', level = vim.log.levels.INFO } })
  eq(has_ended(pid), true)
  eq(told_later(), {})
  eq(#recorded(2), 2)
end

T['a failure']['a request that outlasts its timeout has Claude Code stopped, and the user told once'] = function()
  start_with_project()
  answer_after(5000)
  answer_explanations({ { line = 2, text = 'Adds.' } })

  explain({ timeout_ms = 3000 })
  local pid = recorded(1)[1].pid

  eq(told(), {
    {
      message = 'aineo: explaining failed: Claude Code did not answer within 3 s',
      level = ERROR,
    },
  })
  eq(has_ended(pid), true)
  eq(child.lua_get(SHOWN), {})
  eq(told_later(), {})
end

T['a failure']['a command that cannot run raises its error, shows nothing, and leaves no request running'] = function()
  start_with_project()

  local raised = child.lua([[
    local ran, failure = pcall(require('aineo.explain').ask, {
      buffer = 0 + vim.api.nvim_get_current_buf(),
      window = vim.api.nvim_get_current_win(),
      tools = false,
      command = { '/nonexistent/claude' },
      model = 'sonnet',
      timeout_ms = 180000,
    })
    return { ran = ran, failure = tostring(failure) }
  ]])

  eq(raised.ran, false)
  eq(raised.failure:find('claude.cmd cannot be run: ', 1, true) ~= nil, true)
  eq(child.lua_get(SHOWN), {})
  explain()
  eq(shown_once_it_holds('explaining'), { explaining_above(1, 0) })
end

T['while it runs']['a window closed has the answer wrapped at another window showing the buffer'] = function()
  start_with_project()
  child.cmd('vsplit')
  answer_after(1000)
  answer_explanations({ { line = 1, text = vim.trim(('word '):rep(20)) } })

  explain()
  shown_once_it_holds('explaining')
  child.cmd('close')

  eq(shown_once_it_holds('word'), {
    {
      line = 1,
      above = true,
      virt_lines = {
        { { '┊ ' .. vim.trim(('word '):rep(11)), 'AineoExplain' } },
        { { '┊ ' .. vim.trim(('word '):rep(9)), 'AineoExplain' } },
      },
    },
  })
end

T['while it runs']['a buffer no window shows has the answer wrapped at the screen’s width'] = function()
  start_with_project()
  child.wo.number = true
  answer_after(1000)
  answer_explanations({ { line = 1, text = vim.trim(('word '):rep(20)) } })

  explain()
  shown_once_it_holds('explaining')
  child.cmd('enew')
  vim.wait(PATIENCE_MS, function()
    local marks = child.lua_get('vim.api.nvim_buf_get_extmarks(1, -1, 0, -1, { details = true })')
    return vim.inspect(marks):find('word', 1, true) ~= nil
  end, 20)
  child.cmd('buffer 1')

  eq(child.lua_get(SHOWN), {
    {
      line = 1,
      above = true,
      virt_lines = {
        { { '┊ ' .. vim.trim(('word '):rep(11)), 'AineoExplain' } },
        { { '┊ ' .. vim.trim(('word '):rep(9)), 'AineoExplain' } },
      },
    },
  })
end

T['while it runs']['a buffer wiped out has the answer dropped without an error'] = function()
  start_with_project()
  answer_after(1000)
  answer_explanations({ { line = 2, text = 'Adds.' } })
  explain()
  shown_once_it_holds('explaining')
  local pid = recorded(1)[1].pid

  child.cmd('bwipeout!')

  eq(has_ended(pid), true)
  eq(told_later(), {})
  eq(child.v.errmsg, '')
end

T['clear()'] = MiniTest.new_set()

T['clear()']['removes every explanation and stops the request that runs, silently'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'Adds.' }, { line = 5, text = 'Returns it.' } })
  explain()
  shown_once_it_holds('Returns')
  answer_after(20000)
  explain({ range = { 2, 3 } })
  shown_once_it_holds('explaining')
  local pid = recorded(3)[3].pid

  child.lua("require('aineo.explain').clear(vim.api.nvim_get_current_buf())")

  eq(child.lua_get(SHOWN), {})
  eq(
    vim.wait(3000, function()
      return vim.uv.kill(pid, 0) ~= 0
    end, 20),
    true
  )
  eq(told_later(), {})
end

T['when Neovim quits'] = MiniTest.new_set()

T['when Neovim quits']['a request that runs has its Claude Code stopped'] = function()
  start_with_project()
  answer_after(20000)
  explain()
  local pid = recorded(1)[1].pid

  child.api.nvim_exec_autocmds('VimLeavePre', {})

  eq(
    vim.wait(3000, function()
      return vim.uv.kill(pid, 0) ~= 0
    end, 20),
    true
  )
end

T['a request'] = MiniTest.new_set()

T['a request']['runs claude.cmd in print mode, the code alone, with no tool, no MCP server, no settings and no session kept'] = function()
  start_with_project()

  explain()

  local argv = recorded(1)[1].argv
  eq(vim.json.decode(argv[5]), SCHEMA)
  argv[5] = 'the schema'
  eq(argv, {
    '-p',
    '--output-format',
    'json',
    '--json-schema',
    'the schema',
    '--no-session-persistence',
    '--strict-mcp-config',
    '--model',
    'sonnet',
    '--setting-sources',
    'user',
    '--tools',
    '',
  })
end

T['a request']['with tools lets Claude Code read the project with Read, Grep and Glob alone, without asking, and the model asked for'] = function()
  start_with_project()

  explain({ tools = true, model = 'opus' })

  local argv = recorded(1)[1].argv
  argv[5] = 'the schema'
  eq(argv, {
    '-p',
    '--output-format',
    'json',
    '--json-schema',
    'the schema',
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
  })
end

T['a request']['takes from claude.cmd the words before its first flag alone: the program and its wrapper words'] = function()
  start_with_project()

  explain({
    command = vim.list_extend(vim.list_slice(FAKE_CLAUDE), {
      '--mcp-config',
      '{"mcpServers":{}}',
      '--settings',
      '{"hooks":{}}',
      '--verbose',
      '--tools',
      'X',
    }),
  })

  local argv = recorded(1)[1].argv
  eq(argv[1], '-p')
  eq(vim.tbl_contains(argv, '--mcp-config'), false)
  eq(vim.tbl_contains(argv, '--settings'), false)
  eq(vim.tbl_contains(argv, '--verbose'), false)
  eq(argv[#argv - 1], '--tools')
  eq(argv[#argv], '')
end

T['a request']['runs Claude Code in the git top level of the file'] = function()
  local folder = start_with_project()

  explain()

  eq(recorded(1)[1].cwd, vim.uv.fs_realpath(folder))
end

T['a request']['runs Claude Code in the folder of a file outside any git repository'] = function()
  local folder = start_outside_git()

  explain()

  eq(recorded(1)[1].cwd, vim.uv.fs_realpath(folder .. '/src'))
end

T['a request']['runs Claude Code in the nearest folder that exists for a new file outside any repository'] = function()
  local folder = start_outside_git()
  child.cmd('edit ' .. folder .. '/src/not-made/yet/new.lua')

  explain()

  eq(recorded(1)[1].cwd, vim.uv.fs_realpath(folder .. '/src'))
  eq(
    vim.startswith(recorded(2)[2].stdin, 'Explain the code of the file not-made/yet/new.lua '),
    true
  )
end

T['a request']['hands Claude Code the path from the project, the language, the range and the text with unsaved changes, each line numbered'] = function()
  start_with_project()
  child.api.nvim_buf_set_lines(0, 1, 2, false, { '  return a + b -- not saved' })

  explain()

  eq(
    recorded(2)[2].stdin,
    table.concat({
      'Explain the code of the file src/add.lua (language: lua), lines 1 to 5 as numbered below.',
      '',
      'Write brief explanations of the parts of those lines worth explaining, not one for every line.'
        .. ' Tie each explanation to the first line it explains: its line is that line’s number,'
        .. ' from 1 to 5.',
      '',
      '1 | local function add(a, b)',
      '2 |   return a + b -- not saved',
      '3 | end',
      '4 | ',
      '5 | return add',
    }, '\n')
  )
end

T['a request']['for some lines names them alone as the range, and still hands every line'] = function()
  start_with_project()

  explain({ range = { 2, 3 } })

  local prompt = vim.split(recorded(2)[2].stdin, '\n')
  eq(
    prompt[1],
    'Explain the code of the file src/add.lua (language: lua), lines 2 to 3 as numbered below.'
  )
  eq(vim.endswith(prompt[3], ' from 2 to 3.'), true)
  eq(#prompt, 9)
end

T['a request']['names the language unknown for a buffer with no filetype'] = function()
  start_with_project()
  child.bo.filetype = ''

  explain()

  eq(
    vim.split(recorded(2)[2].stdin, '\n')[1],
    'Explain the code of the file src/add.lua (language: unknown), lines 1 to 5 as numbered below.'
  )
end

T['a request']['aligns the numbers of the lines to the right'] = function()
  start_with_project()
  child.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(('x\n'):rep(9) .. 'y', '\n'))

  explain()

  eq(vim.list_slice(vim.split(recorded(2)[2].stdin, '\n'), 13, 14), { ' 9 | x', '10 | y' })
end

return T
