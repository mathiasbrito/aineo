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

--- Has the fake `claude` print `text` as its answer, from the file `name`:
--- a request that runs reads its answer from the file it was started with,
--- so that a later answer in another file leaves it be.
---
---@param text string
---@param name? string a file name; `answer.json` when absent
local function answer_text(text, name)
  local answer = fixture.write('explain/' .. (name or 'answer.json'), { text })
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT = ...', { answer })
end

--- Has the fake `claude` answer a successful result whose structured output
--- holds `explanations`, as Claude Code documents `--output-format json`
--- with `--json-schema`.
---
---@param explanations { line: any, text: any }[]
---@param name? string the file the answer is read from (`answer_text()`)
local function answer_explanations(explanations, name)
  answer_text(
    vim.json.encode({
      type = 'result',
      subtype = 'success',
      is_error = false,
      result = '',
      structured_output = { explanations = explanations },
    }),
    name
  )
end

--- What the child shows of the explanations in the namespace `namespace`,
--- line by line: for each line with an extmark of it, from the top, the
--- line's number from 1, whether the virtual lines are above it, whether
--- they start at the window's left column, the highlight group of its
--- number, and the virtual lines as their chunks, as they are. `%s` is the
--- namespace's name.
local SHOWN_CHUNKS_OF = [[(function()
  local namespace = vim.api.nvim_get_namespaces().%s
  if not namespace then
    return {}
  end
  local shown = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })) do
    table.insert(shown, {
      line = mark[2] + 1,
      above = mark[4].virt_lines_above,
      leftcol = mark[4].virt_lines_leftcol,
      number_hl_group = mark[4].number_hl_group,
      virt_lines = mark[4].virt_lines,
    })
  end
  return shown
end)()]]

--- What the child shows of the explanations (`SHOWN_CHUNKS_OF`) with each
--- row reduced to what it says: its text, the chunks of the gutter left out,
--- the padding to the window's width cut and the frame of the spinner of a
--- row that says a request is working left out, in the group of the text.
local SHOWN = [[(function()
  local namespace = vim.api.nvim_get_namespaces().aineo_explain
  if not namespace then
    return {}
  end
  local shown = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })) do
    local rows = {}
    for _, row in ipairs(mark[4].virt_lines) do
      local text = ''
      for _, chunk in ipairs(row) do
        if chunk[2] == nil or chunk[2] == 'AineoExplain' then
          text = text .. chunk[1]
        end
      end
      text = text:gsub('\226[\160-\163][\128-\191] ', '')
      table.insert(rows, { { (text:gsub(' +$', '')), 'AineoExplain' } })
    end
    table.insert(shown, { line = mark[2] + 1, above = mark[4].virt_lines_above, virt_lines = rows })
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

--- What the child shows in the namespace `namespace` (`SHOWN_CHUNKS_OF`),
--- as it is, once it shows a virtual line holding `text`, or after
--- `PATIENCE_MS`.
---
---@param namespace string
---@param text string
---@return table[]
local function chunks_once_it_holds(namespace, text)
  local shown = {}
  vim.wait(PATIENCE_MS, function()
    shown = child.lua_get(SHOWN_CHUNKS_OF:format(namespace))
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

T['a request']['for issues asks for the potential issues of those lines instead, with the same answer schema and flags'] = function()
  start_with_project()

  explain({ kind = 'issues', range = { 2, 3 } })

  local call = recorded(2)
  eq(
    call[2].stdin,
    table.concat({
      'Review the code of the file src/add.lua (language: lua), lines 2 to 3 as numbered below, for potential issues.',
      '',
      'List the potential issues in those lines: bugs, unhandled cases, error handling gaps,'
        .. ' and security or performance risks. Tie each issue to the first line it concerns:'
        .. ' its line is that line’s number, from 2 to 3. Be brief, make no style remarks,'
        .. ' and answer an empty list when you find none.'
        .. ' Give each issue as an item of the answer’s list.',
      '',
      '1 | local function add(a, b)',
      '2 |   return a + b',
      '3 | end',
      '4 | ',
      '5 | return add',
    }, '\n')
  )
  eq(vim.json.decode(call[1].argv[5]), SCHEMA)
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

T['the look'] = MiniTest.new_set()

T['the look']['shows a row as the indent unhighlighted, then the mark and the text padded to the window’s width in AineoExplain, from the left column'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'Adds the two numbers.' } })

  explain()

  eq(chunks_once_it_holds('aineo_explain', 'Adds'), {
    {
      line = 2,
      above = true,
      leftcol = true,
      number_hl_group = 'AineoExplainNr',
      virt_lines = {
        { { '  ' }, { '┊ Adds the two numbers.' .. (' '):rep(35), 'AineoExplain' } },
      },
    },
  })
end

T['the look']['starts a row with ▎ in the gutter, the label expl right-aligned on the first row alone, and the rest of the gutter filled'] = function()
  start_with_project()
  child.wo.number = true
  child.wo.numberwidth = 8
  answer_explanations({ { line = 2, text = 'First.\nSecond.' } })

  explain()

  eq(chunks_once_it_holds('aineo_explain', 'First')[1].virt_lines, {
    {
      { '▎', 'AineoExplainGutter' },
      { '  ', 'AineoExplainGutterFill' },
      { 'expl', 'AineoExplainGutter' },
      { ' ', 'AineoExplainGutterFill' },
      { '  ' },
      { '┊ First.' .. (' '):rep(50 - 8), 'AineoExplain' },
    },
    {
      { '▎', 'AineoExplainGutter' },
      { (' '):rep(7), 'AineoExplainGutterFill' },
      { '  ' },
      { '┊ Second.' .. (' '):rep(50 - 9), 'AineoExplain' },
    },
  })
end

T['the look']['leaves the label out of a gutter too narrow for it and ▎, and keeps it in one that just fits'] =
  MiniTest.new_set({
    parametrize = {
      {
        5,
        {
          { '▎', 'AineoExplainGutter' },
          { '    ', 'AineoExplainGutterFill' },
        },
      },
      {
        6,
        {
          { '▎', 'AineoExplainGutter' },
          { 'expl', 'AineoExplainGutter' },
          { ' ', 'AineoExplainGutterFill' },
        },
      },
    },
  })

T['the look']['leaves the label out of a gutter too narrow for it and ▎, and keeps it in one that just fits']['of'] = function(
  numberwidth,
  gutter
)
  start_with_project()
  child.wo.number = true
  child.wo.numberwidth = numberwidth
  answer_explanations({ { line = 1, text = 'Starts.' } })

  explain()

  local row = chunks_once_it_holds('aineo_explain', 'Starts')[1].virt_lines[1]
  eq(vim.list_slice(row, 1, #gutter), gutter)
  eq(#row, #gutter + 1)
end

--- Defines in the child the highlight groups `colours` names, each as its
--- definition says.
---
---@param colours table<string, table>
local function use_theme(colours)
  child.lua(
    [[for name, definition in pairs(...) do
      vim.api.nvim_set_hl(0, name, definition)
    end]],
    { colours }
  )
end

--- The definition the child holds of the group `name`, a link not followed.
---
---@param name string
---@return table
local function group(name)
  return child.api.nvim_get_hl(0, { name = name })
end

T['the look']['computes its groups from the theme: the accent from DiagnosticInfo, the band from Normal blended 12% toward it, the gutter from LineNr'] = function()
  start_with_project()
  use_theme({
    Normal = { bg = 0x101010, fg = 0xeeeeee },
    DiagnosticInfo = { fg = 0x6090c0 },
    LineNr = { bg = 0x202020 },
  })
  answer_explanations({ { line = 2, text = 'Adds.' } })

  explain()
  shown_once_it_holds('Adds')

  eq(
    group('AineoExplain'),
    { fg = 0x6090c0, bg = 0x1a1f25, italic = true, cterm = { italic = true }, default = true }
  )
  eq(group('AineoExplainGutter'), { fg = 0x6090c0, bg = 0x202020, default = true })
  eq(group('AineoExplainGutterFill'), { bg = 0x202020, default = true })
  eq(
    group('AineoExplainNr'),
    { fg = 0x6090c0, bold = true, cterm = { bold = true }, default = true }
  )
end

T['the look']['falls back for the colours the theme lacks: Normal’s background by the background option, the accent, no LineNr background'] =
  MiniTest.new_set({
    parametrize = { { 'dark', 0x262f45 }, { 'light', 0xecf5fd } },
  })

T['the look']['falls back for the colours the theme lacks: Normal’s background by the background option, the accent, no LineNr background']['for'] = function(
  background,
  band
)
  start_with_project()
  child.o.background = background
  use_theme({ Normal = {}, DiagnosticInfo = {}, LineNr = {} })
  answer_explanations({ { line = 2, text = 'Adds.' } })

  explain()
  shown_once_it_holds('Adds')

  eq(
    group('AineoExplain'),
    { fg = 0x61afef, bg = band, italic = true, cterm = { italic = true }, default = true }
  )
  eq(group('AineoExplainGutter'), { fg = 0x61afef, default = true })
  eq(group('AineoExplainGutterFill'), { default = true })
end

T['the look']['computes its groups again when the colour scheme changes'] = function()
  start_with_project()
  use_theme({ Normal = { bg = 0x101010 }, DiagnosticInfo = { fg = 0x6090c0 } })
  answer_explanations({ { line = 2, text = 'Adds.' } })
  explain()
  shown_once_it_holds('Adds')

  use_theme({ Normal = { bg = 0x000000 }, DiagnosticInfo = { fg = 0xffffff } })
  child.cmd('doautocmd ColorScheme')

  eq(
    group('AineoExplain'),
    { fg = 0xffffff, bg = 0x1f1f1f, italic = true, cterm = { italic = true } }
  )
end

T['the look']['keeps a group the user defined, before it loads and after the colour scheme changes'] = function()
  start_with_project()
  use_theme({ AineoExplain = { fg = 0x123456, underline = true } })
  answer_explanations({ { line = 2, text = 'Adds.' } })

  explain()
  shown_once_it_holds('Adds')
  child.cmd('doautocmd ColorScheme')

  eq({ group('AineoExplain').fg, group('AineoExplain').underline }, { 0x123456, true })
  eq(group('AineoExplainNr').bold, true)
end

T['the look']['computes its groups again when the background option changes, with no colour scheme loaded'] = function()
  start_with_project()
  child.lua([[
    vim.api.nvim_create_autocmd('OptionSet', {
      pattern = 'background',
      callback = function()
        vim.api.nvim_set_hl(0, 'Normal', { bg = 0x000000 })
        vim.api.nvim_set_hl(0, 'DiagnosticInfo', { fg = 0xffffff })
      end,
    })
    vim.o.background = 'dark'
  ]])
  use_theme({ Normal = { bg = 0x101010 }, DiagnosticInfo = { fg = 0x6090c0 } })
  answer_explanations({ { line = 2, text = 'Adds.' } })
  explain()
  shown_once_it_holds('Adds')

  child.o.background = 'light'

  eq(group('AineoExplain').bg, 0x1f1f1f)
  eq(group('AineoExplain').fg, 0xffffff)
end

T['the look']['keeps a group the user defined as a default, before it loads and after the colour scheme changes'] = function()
  start_with_project()
  use_theme({ AineoExplain = { link = 'Comment', default = true } })
  answer_explanations({ { line = 2, text = 'Adds.' } })

  explain()
  shown_once_it_holds('Adds')
  child.cmd('doautocmd ColorScheme')

  eq(group('AineoExplain'), { link = 'Comment', default = true })
end

T['the look']['carries the cterm colours: the accent’s foreground, LineNr’s background in the gutter, CursorLine’s behind the band'] = function()
  start_with_project()
  use_theme({
    Normal = { bg = 0x101010 },
    DiagnosticInfo = { fg = 0x6090c0, ctermfg = 14 },
    LineNr = { bg = 0x202020, ctermbg = 240 },
    CursorLine = { bg = 0x303030, ctermbg = 236 },
  })
  answer_explanations({ { line = 2, text = 'Adds.' } })

  explain()
  shown_once_it_holds('Adds')

  eq(group('AineoExplain').ctermfg, 14)
  eq(group('AineoExplain').ctermbg, 236)
  eq(group('AineoExplainGutter').ctermfg, 14)
  eq(group('AineoExplainGutter').ctermbg, 240)
  eq(group('AineoExplainGutterFill').ctermbg, 240)
  eq(group('AineoExplainNr').ctermfg, 14)
end

T['the look']['leaves the cterm colours out that the theme lacks'] = function()
  start_with_project()
  use_theme({ DiagnosticInfo = { fg = 0x6090c0 }, LineNr = {}, CursorLine = {} })
  answer_explanations({ { line = 2, text = 'Adds.' } })

  explain()
  shown_once_it_holds('Adds')

  eq({
    group('AineoExplain').ctermfg,
    group('AineoExplain').ctermbg,
    group('AineoExplainGutter').ctermbg,
  }, {})
end

T['the look']['shows no gutter where the window shows no number, sign or fold column'] = function()
  start_with_project()
  answer_explanations({ { line = 1, text = 'Starts.' } })

  explain()

  eq(chunks_once_it_holds('aineo_explain', 'Starts')[1].virt_lines, {
    { { '┊ Starts.' .. (' '):rep(60 - 9), 'AineoExplain' } },
  })
end

T['issues'] = MiniTest.new_set()

--- The numbers of the lines the child shows virtual lines above in the
--- namespace `namespace`, without the one that says a request is working.
---
---@param namespace string
---@return integer[]
local function lines_shown(namespace)
  local lines = {}
  for _, mark in ipairs(child.lua_get(SHOWN_CHUNKS_OF:format(namespace))) do
    local says = vim.inspect(mark.virt_lines)
    if not says:find('explaining', 1, true) and not says:find('looking for issues', 1, true) then
      table.insert(lines, mark.line)
    end
  end
  return lines
end

--- The numbers of the lines the child shows virtual lines above in the
--- namespace `namespace`, once there are `count` of them, or after
--- `PATIENCE_MS`.
---
---@param namespace string
---@param count integer
---@return integer[]
local function lines_shown_once(namespace, count)
  local lines = {}
  vim.wait(PATIENCE_MS, function()
    lines = lines_shown(namespace)
    return #lines == count
  end, 20)
  return lines
end

T['issues']['show in a namespace of their own, in the issue look: ▎ and the label issue, AineoExplainIssue, and the line’s number in AineoExplainIssueNr'] = function()
  start_with_project()
  child.wo.number = true
  child.wo.numberwidth = 8
  answer_explanations({ { line = 2, text = 'Overflows.' } })

  explain({ kind = 'issues' })

  eq(chunks_once_it_holds('aineo_explain_issues', 'Overflows'), {
    {
      line = 2,
      above = true,
      leftcol = true,
      number_hl_group = 'AineoExplainIssueNr',
      virt_lines = {
        {
          { '▎', 'AineoExplainIssueGutter' },
          { ' ', 'AineoExplainIssueGutterFill' },
          { 'issue', 'AineoExplainIssueGutter' },
          { ' ', 'AineoExplainIssueGutterFill' },
          { '  ' },
          { '┊ Overflows.' .. (' '):rep(50 - 12), 'AineoExplainIssue' },
        },
      },
    },
  })
  eq(child.lua_get(SHOWN), {})
end

T['issues']['draw their groups from DiagnosticWarn’s foreground, `#e5c07b` without one'] =
  MiniTest.new_set({
    parametrize = {
      { { DiagnosticWarn = { fg = 0x808040 } }, 0x808040 },
      { { DiagnosticWarn = {} }, 0xe5c07b },
    },
  })

T['issues']['draw their groups from DiagnosticWarn’s foreground, `#e5c07b` without one']['with'] = function(
  theme,
  accent
)
  start_with_project()
  use_theme(theme)
  answer_explanations({ { line = 2, text = 'Overflows.' } })

  explain({ kind = 'issues' })
  chunks_once_it_holds('aineo_explain_issues', 'Overflows')

  eq(group('AineoExplainIssue').fg, accent)
  eq(group('AineoExplainIssueGutter').fg, accent)
  eq(group('AineoExplainIssueNr').fg, accent)
end

T['issues']['coexist with explanations, and each key toggles its own kind'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'Adds.' } })
  explain()
  lines_shown_once('aineo_explain', 1)
  answer_explanations({ { line = 5, text = 'Returns nothing.' } })
  explain({ kind = 'issues' })
  eq(lines_shown_once('aineo_explain_issues', 1), { 5 })
  eq(lines_shown('aineo_explain'), { 2 })

  explain({ kind = 'issues' })

  eq(lines_shown_once('aineo_explain_issues', 0), {})
  eq(lines_shown('aineo_explain'), { 2 })

  explain({ kind = 'issues' })
  lines_shown_once('aineo_explain_issues', 1)
  explain()

  eq(lines_shown_once('aineo_explain', 0), {})
  eq(lines_shown('aineo_explain_issues'), { 5 })
end

T['issues']['asked for some lines replace the issues inside them alone, and leave the explanations'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'Adds.' } })
  explain({ range = { 1, 3 } })
  lines_shown_once('aineo_explain', 1)
  answer_explanations({ { line = 2, text = 'Old.' }, { line = 5, text = 'Kept.' } })
  explain({ kind = 'issues' })
  lines_shown_once('aineo_explain_issues', 2)
  answer_explanations({ { line = 3, text = 'New.' } })

  explain({ kind = 'issues', range = { 1, 3 } })

  chunks_once_it_holds('aineo_explain_issues', 'New.')
  eq(lines_shown('aineo_explain_issues'), { 3, 5 })
  eq(lines_shown('aineo_explain'), { 2 })
end

T['issues']['asked while explanations run start beside them, and both answers show'] = function()
  start_with_project()
  answer_after(1500)
  answer_explanations({ { line = 2, text = 'Adds.' } }, 'explanations.json')
  explain()
  recorded(2)
  answer_explanations({ { line = 5, text = 'Overflows.' } }, 'issues.json')

  explain({ kind = 'issues' })

  eq(#recorded(4), 4)
  eq(lines_shown_once('aineo_explain', 1), { 2 })
  eq(lines_shown_once('aineo_explain_issues', 1), { 5 })
  eq(told_later(), {})
end

T['issues']['a key of the kind that runs cancels that request alone, says so, and leaves the other running'] =
  MiniTest.new_set({
    parametrize = {
      { 'explanations', 'aineo_explain_issues', 'Overflows.' },
      { 'issues', 'aineo_explain', 'Adds.' },
    },
  })

T['issues']['a key of the kind that runs cancels that request alone, says so, and leaves the other running']['pressed for'] = function(
  cancelled,
  other_namespace,
  other_text
)
  start_with_project()
  answer_after(3000)
  local answers = {
    explanations = { { line = 2, text = 'Adds.' } },
    issues = { { line = 5, text = 'Overflows.' } },
  }
  answer_explanations(answers.explanations, 'explanations.json')
  explain({ kind = 'explanations' })
  local first_pid = recorded(1)[1].pid
  answer_explanations(answers.issues, 'issues.json')
  explain({ kind = 'issues' })
  local second_pid = recorded(3)[3].pid
  local cancelled_pid = cancelled == 'explanations' and first_pid or second_pid
  local other_pid = cancelled == 'explanations' and second_pid or first_pid

  explain({ kind = cancelled })

  eq(told(), { { message = 'aineo: explaining stopped', level = vim.log.levels.INFO } })
  eq(has_ended(cancelled_pid), true)
  eq(vim.uv.kill(other_pid, 0), 0)
  chunks_once_it_holds(other_namespace, other_text)
  eq(#lines_shown(other_namespace), 1)
  eq(told_later(), {})
end

T['issues']['on a line both kinds show, the explanation rows sit above the issue rows, whichever answer came first'] =
  MiniTest.new_set({
    parametrize = { { 'explanations' }, { 'issues' } },
  })

T['issues']['on a line both kinds show, the explanation rows sit above the issue rows, whichever answer came first']['first'] = function(
  first
)
  start_with_project()
  local texts = {
    explanations = { { line = 2, text = 'Explained.' } },
    issues = { { line = 2, text = 'Issued.' } },
  }
  local second = first == 'explanations' and 'issues' or 'explanations'
  answer_explanations(texts[first], first .. '.json')
  explain({ kind = first })
  lines_shown_once(first == 'explanations' and 'aineo_explain' or 'aineo_explain_issues', 1)
  answer_explanations(texts[second], second .. '.json')
  explain({ kind = second })
  lines_shown_once(second == 'explanations' and 'aineo_explain' or 'aineo_explain_issues', 1)
  child.cmd('redraw')

  local rows = child.get_screenshot().text
  local function row_of(text)
    for number, row in ipairs(rows) do
      if table.concat(row):find(text, 1, true) then
        return number
      end
    end
  end

  eq(row_of('Explained.') < row_of('Issued.'), true)
  eq(row_of('Issued.') < row_of('return a + b'), true)
end

T['clear()']['stops the requests of both kinds that run, silently'] = function()
  start_with_project()
  answer_after(20000)
  explain({ kind = 'explanations' })
  local first_pid = recorded(1)[1].pid
  explain({ kind = 'issues' })
  local second_pid = recorded(3)[3].pid

  child.lua("require('aineo.explain').clear(vim.api.nvim_get_current_buf())")

  eq(has_ended(first_pid), true)
  eq(has_ended(second_pid), true)
  eq(told_later(), {})
end

T['issues']['found in an empty answer are told once, and nothing is shown'] = function()
  start_with_project()
  answer_explanations({})

  explain({ kind = 'issues' })

  eq(told(), { { message = 'aineo: no potential issues found', level = vim.log.levels.INFO } })
  eq(lines_shown('aineo_explain_issues'), {})
end

T['an answer']['with no explanation tells nothing'] = function()
  start_with_project()
  answer_explanations({})

  explain()

  eq(#recorded(2), 2)
  eq(told_later(), {})
  eq(child.lua_get(SHOWN), {})
end

T['clear()']['removes the issues too'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'Overflows.' } })
  explain({ kind = 'issues' })
  lines_shown_once('aineo_explain_issues', 1)

  child.lua("require('aineo.explain').clear(vim.api.nvim_get_current_buf())")

  eq(lines_shown('aineo_explain_issues'), {})
end

T['a badge'] = MiniTest.new_set()

--- The ten frames of the spinner, in the order they show.
local FRAMES = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

--- The floating windows of the child, each as the part of its configuration
--- that matters, its text, and the 'winhighlight' it shows with.
local FLOATS = [[(function()
  local floats = {}
  for _, window in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(window)
    if config.relative ~= '' then
      table.insert(floats, {
        relative = config.relative,
        win = config.win,
        anchor = config.anchor,
        row = config.row,
        col = config.col,
        focusable = config.focusable,
        border = config.border,
        text = table.concat(
          vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(window), 0, -1, false),
          '\n'
        ),
        winhighlight = vim.wo[window].winhighlight,
      })
    end
  end
  return floats
end)()]]

--- The floating windows of the child (`FLOATS`), once there are `count` of
--- them, or after `PATIENCE_MS`.
---
---@param count integer
---@return table[]
local function floats_once(count)
  local floats = {}
  vim.wait(PATIENCE_MS, function()
    floats = child.lua_get(FLOATS)
    return #floats == count
  end, 20)
  return floats
end

--- The text of the only floating window of the child, once it holds
--- `fragment`, or after `PATIENCE_MS`.
---
---@param fragment string
---@return string
local function badge_text_once_it_holds(fragment)
  local text = ''
  vim.wait(PATIENCE_MS, function()
    local floats = child.lua_get(FLOATS)
    text = floats[1] and floats[1].text or ''
    return text:find(fragment, 1, true) ~= nil
  end, 20)
  return text
end

--- The spinner frame and the words of a badge's `text`: ` <frame> <words> `.
---
---@param text string
---@return string frame
---@return string words
local function badge_parts(text)
  return text:sub(2, 4), text:sub(6, -2)
end

--- The number of timers of the child that are active.
local ACTIVE_TIMERS = [[(function()
  local count = 0
  vim.uv.walk(function(handle)
    if handle:get_type() == 'timer' and handle:is_active() then
      count = count + 1
    end
  end)
  return count
end)()]]

T['a badge']['shows in the top right corner of the window the request was made in, with a spinner, the words and the seconds'] = function()
  start_with_project()
  answer_after(4000)
  answer_explanations({ { line = 2, text = 'Adds.' } })
  local window = child.api.nvim_get_current_win()

  explain()

  local floats = floats_once(1)
  local frame, words = badge_parts(floats[1].text)
  eq(vim.tbl_contains(FRAMES, frame), true)
  eq(words:match('^explaining… %d+s$') ~= nil, true)
  floats[1].text = nil
  eq(floats[1], {
    relative = 'win',
    win = window,
    anchor = 'NE',
    row = 0,
    col = 60,
    focusable = false,
    border = 'none',
    winhighlight = 'NormalFloat:AineoExplain',
  })
end

T['a badge']['for issues says looking for issues, in the issue look'] = function()
  start_with_project()
  answer_after(4000)
  answer_explanations({ { line = 2, text = 'Adds.' } })

  explain({ kind = 'issues' })

  local floats = floats_once(1)
  local _, words = badge_parts(floats[1].text)
  eq(words:match('^looking for issues… %d+s$') ~= nil, true)
  eq(floats[1].winhighlight, 'NormalFloat:AineoExplainIssue')
end

T['a badge']['advances its spinner every 100 ms, and counts the seconds'] = function()
  start_with_project()
  answer_after(4000)
  answer_explanations({ { line = 2, text = 'Adds.' } })
  explain()
  floats_once(1)
  local seen = {}

  vim.wait(1000, function()
    local floats = child.lua_get(FLOATS)
    local frame = badge_parts(floats[1].text)
    seen[frame] = true
    return false
  end, 15)

  eq(vim.tbl_count(seen) >= 5, true)
  eq(badge_text_once_it_holds(' 1s'):find(' 1s', 1, true) ~= nil, true)
end

T['a badge']['animates the progress line above the first line asked for with the same spinner'] = function()
  start_with_project()
  answer_after(4000)
  answer_explanations({ { line = 2, text = 'Adds.' } })
  explain({ range = { 1, 3 } })
  local lines = {}

  vim.wait(1000, function()
    local row = child.lua_get(SHOWN_CHUNKS_OF:format('aineo_explain'))[1].virt_lines[1]
    local text = row[#row][1]:gsub(' +$', '')
    lines[text] = true
    return false
  end, 15)

  eq(vim.tbl_count(lines) >= 5, true)
  for line in pairs(lines) do
    eq(vim.tbl_contains(FRAMES, line:sub(5, 7)), true)
    eq(line:sub(1, 4) .. line:sub(8), '┊  explaining…')
  end
end

T['a badge']['lists the requests that run in the order they started, joined by a dot, in one float'] =
  MiniTest.new_set({
    parametrize = {
      { 'explanations', 'issues', '^explaining… %d+s · looking for issues… %d+s$' },
      { 'issues', 'explanations', '^looking for issues… %d+s · explaining… %d+s$' },
    },
  })

T['a badge']['lists the requests that run in the order they started, joined by a dot, in one float']['first'] = function(
  first,
  second,
  pattern
)
  start_with_project()
  answer_after(4000)
  answer_explanations({ { line = 2, text = 'Adds.' } })
  explain({ kind = first })
  floats_once(1)
  explain({ kind = second })

  local floats = floats_once(1)
  local text = badge_text_once_it_holds('·')

  eq(#floats, 1)
  eq(select(2, badge_parts(text)):match(pattern) ~= nil, true)
end

T['a badge']['loses the part of a request that ends, and closes with the last'] = function()
  start_with_project()
  answer_after(4000)
  answer_explanations({ { line = 2, text = 'Adds.' } })
  explain({ kind = 'explanations' })
  explain({ kind = 'issues' })
  badge_text_once_it_holds('·')

  explain({ kind = 'explanations' })

  local text = badge_text_once_it_holds('looking')
  eq(select(2, badge_parts(text)):match('^looking for issues… %d+s$') ~= nil, true)
  explain({ kind = 'issues' })
  eq(floats_once(0), {})
end

T['a badge']['and its timer end with the request on every path'] = MiniTest.new_set({
  parametrize = {
    { 'an answer' },
    { 'a cancel' },
    { 'the timeout' },
    { 'a failure' },
    { 'a buffer wiped' },
    { 'clear()' },
    { 'quitting' },
  },
})

T['a badge']['and its timer end with the request on every path']['by'] = function(path)
  start_with_project()
  local baseline = child.lua_get(ACTIVE_TIMERS)
  local delay = (path == 'an answer' or path == 'a failure') and 300 or 20000
  answer_after(delay)
  answer_explanations({ { line = 2, text = 'Adds.' } })
  local timeout_ms = path == 'the timeout' and 600 or 180000
  if path == 'a failure' then
    child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_EXIT = "2"')
  end
  explain({ timeout_ms = timeout_ms })
  floats_once(1)

  if path == 'a cancel' then
    explain({ timeout_ms = timeout_ms })
  elseif path == 'a buffer wiped' then
    child.cmd('enew')
    child.cmd('bwipeout! #')
  elseif path == 'clear()' then
    child.lua("require('aineo.explain').clear(vim.api.nvim_get_current_buf())")
  elseif path == 'quitting' then
    child.api.nvim_exec_autocmds('VimLeavePre', {})
  end

  eq(floats_once(0), {})
  eq(
    vim.wait(PATIENCE_MS, function()
      return child.lua_get(ACTIVE_TIMERS) == baseline
    end, 20),
    true
  )
end

T['a badge']['is gone with the window the request was made in, while the request goes on and shows its answer'] = function()
  start_with_project()
  answer_after(1500)
  answer_explanations({ { line = 2, text = 'Adds.' } })
  child.cmd('vsplit')
  explain()
  floats_once(1)

  child.cmd('close')

  eq(floats_once(0), {})
  eq(shown_once_it_holds('Adds')[1].line, 2)
end

T['a kept answer'] = MiniTest.new_set()

--- What the user is told when an answer is placed again instead of asked for.
---
---@param words string the words that ask again, after `:Aineo explain`
---@return { message: string, level: integer }
local function told_kept(words)
  return {
    message = ('aineo: the earlier answer, the code unchanged (:Aineo explain %sasks again)'):format(
      words
    ),
    level = vim.log.levels.INFO,
  }
end

--- Asks for explanations of the whole buffer, waits for them, and hides them
--- by asking again. Returns what was shown.
---
---@param fields? table the request's fields beyond the defaults
---@return table[] shown
local function explained_then_hidden(fields)
  answer_explanations({ { line = 2, text = 'Adds.' }, { line = 5, text = 'Returns it.' } })
  explain(fields)
  local shown = shown_once_it_holds('Returns')
  explain(fields)
  eq(child.lua_get(SHOWN), {})
  return shown
end

--- How many times the fake `claude` has started, after the child had time
--- to start another.
---
---@return integer
local function processes_started()
  told_later()
  return #recorded(0) / 2
end

T['a kept answer']['asked again after it was hidden shows the same texts at once, starts no process, and says so'] = function()
  start_with_project()
  local first = explained_then_hidden()

  explain()

  eq(told(), { told_kept('new ') })
  eq(child.lua_get(SHOWN), first)
  eq(processes_started(), 1)
end

T['a kept answer']['for issues says so with the words that ask again'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'Overflows.' } })
  explain({ kind = 'issues', tools = true })
  lines_shown_once('aineo_explain_issues', 1)
  explain({ kind = 'issues', tools = true })

  explain({ kind = 'issues', tools = true })

  eq(told(), { told_kept('issues tools new ') })
  eq(lines_shown('aineo_explain_issues'), { 2 })
  eq(processes_started(), 1)
end

T['a kept answer']['is not used for another kind, tools or range, which start a request'] =
  MiniTest.new_set({
    parametrize = {
      { { tools = true } },
      { { kind = 'issues' } },
      { { range = { 1, 3 } } },
    },
  })

T['a kept answer']['is not used for another kind, tools or range, which start a request']['asked with'] = function(
  fields
)
  start_with_project()
  explained_then_hidden()

  explain(fields)

  eq(#recorded(4), 4)
  eq(processes_started(), 2)
end

T['a kept answer']['is dropped when the text of the lines changes, and a request starts'] = function()
  start_with_project()
  explained_then_hidden()
  child.api.nvim_buf_set_lines(0, 0, 1, false, { '-- changed' })

  explain()

  eq(#recorded(4), 4)
end

T['a kept answer']['is kept by a write of the buffer alone'] = function()
  start_with_project()
  explained_then_hidden()
  child.cmd('write')

  explain()

  eq(told(), { told_kept('new ') })
  eq(processes_started(), 1)
end

T['a kept answer']['is replaced by asking again with new, which starts a request and keeps its answer'] = function()
  start_with_project()
  explained_then_hidden()
  answer_explanations({ { line = 3, text = 'Ends it.' } }, 'second.json')

  explain({ fresh = true })

  eq(shown_once_it_holds('Ends')[1].line, 3)
  explain()
  eq(child.lua_get(SHOWN), {})
  explain()
  eq(shown_once_it_holds('Ends')[1].line, 3)
  eq(processes_started(), 2)
end

T['a kept answer']['is forgotten with the buffer'] = function()
  local folder = start_with_project()
  explained_then_hidden()
  child.cmd('bwipeout!')
  child.cmd('edit ' .. folder .. '/src/add.lua')

  explain()

  eq(#recorded(4), 4)
end

T['a kept answer']['is placed wrapped for the window it is placed in now'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = vim.trim(('wörd '):rep(20)) } })
  explain()
  shown_once_it_holds('wörd')
  explain()
  child.o.columns = 40

  explain()

  eq(#shown_once_it_holds('wörd')[1].virt_lines, 3)
end

T['a kept answer']['for some lines is kept for those lines, and placed after clear()'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'Adds.' } })
  explain({ range = { 1, 3 } })
  local shown = shown_once_it_holds('Adds')
  child.lua("require('aineo.explain').clear(vim.api.nvim_get_current_buf())")

  explain({ range = { 1, 3 } })

  eq(told(), { told_kept('new ') })
  eq(child.lua_get(SHOWN), shown)
  eq(processes_started(), 1)
end

T['a kept answer']['asked again with new while it is shown asks again instead of clearing it'] = function()
  start_with_project()
  answer_explanations({ { line = 2, text = 'Adds.' } })
  explain()
  shown_once_it_holds('Adds')
  answer_explanations({ { line = 3, text = 'Ends it.' } }, 'second.json')

  explain({ fresh = true })

  eq(shown_once_it_holds('Ends')[1].line, 3)
  eq(processes_started(), 2)
end

return T
