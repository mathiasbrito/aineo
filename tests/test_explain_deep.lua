local MiniTest = require('mini.test')
local explained = dofile('tests/helpers/explain_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The lines of the file every case explains.
local CODE = {
  'local function add(a, b)',
  '  return a + b',
  'end',
  '',
  'return add',
}

--- Starts the child with `CODE` open in a project of its own, aineo
--- configured to run the fake `claude`, and the fake answering one
--- explanation of line 1.
---
---@param config? table more of `vim.g.aineo`
---@return string folder the project's folder
local function start(config)
  local folder = explained.start(
    child,
    'explain-deep',
    CODE,
    vim.tbl_deep_extend('force', { claude = { cmd = explained.FAKE_CLAUDE } }, config or {})
  )
  explained.answer(child, { { line = 1, text = 'adds' } })
  return folder
end

--- Asks the explain home, in the child, for a deep request about the
--- current buffer with the fake `claude`, as the fields `fields` say over
--- these defaults: explanations, with tools, the model `sonnet`, a long
--- timeout, and a deep request of effort `high` whose steer is `Steer.`
---
---@param fields? table
local function ask_deep(fields)
  child.lua(
    [[
    local fields, command = ...
    local request = vim.tbl_deep_extend('force', {
      buffer = vim.api.nvim_get_current_buf(),
      window = vim.api.nvim_get_current_win(),
      tools = true,
      command = command,
      model = 'sonnet',
      timeout_ms = 180000,
      deep = { effort = 'high', steer = 'Steer.' },
    }, fields)
    if request.deep.steer == false then
      request.deep.steer = nil
    end
    require('aineo.explain').ask(request)
  ]],
    { fields or vim.empty_dict(), explained.FAKE_CLAUDE }
  )
end

--- Asks as `ask_deep()` does, but with no steer: the user is asked for it
--- in a float.
---
---@param fields? table
local function ask_steered(fields)
  ask_deep(vim.tbl_deep_extend('force', fields or {}, { deep = { steer = false } }))
end

--- The record the fake `claude` writes (`explained.start()` makes its folder).
local RECORD = vim.fs.joinpath(
  vim.fn.fnamemodify('.', ':p'):gsub('/$', ''),
  '.tests',
  'fixtures',
  'explain-deep-record',
  'fake.jsonl'
)

--- The lines the fake `claude` recorded, decoded, once it has recorded at
--- least `count` of them, or after `PATIENCE_MS`.
---
---@param count integer
---@return table[]
local function recorded(count)
  local lines = {}
  vim.wait(explained.PATIENCE_MS, function()
    lines = vim.uv.fs_stat(RECORD) and vim.fn.readfile(RECORD) or {}
    return #lines >= count
  end, 20)
  return vim.tbl_map(vim.json.decode, lines)
end

T['a deep request'] = MiniTest.new_set()

T['a deep request']['runs Claude Code with the read-only tools, the model asked for and the effort asked for'] = function()
  start()

  ask_deep({ model = 'opus', deep = { effort = 'xhigh' } })

  local argv = recorded(1)[1].argv
  eq(vim.list_slice(argv, 8), {
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

T['a deep request']['hands Claude Code the edited text, then the rule that ties each explanation to its first line, then every line numbered'] = function()
  start()

  ask_deep({ deep = { steer = 'Dig into add.\nMention the call paths.' } })

  eq(
    recorded(2)[2].stdin,
    table.concat({
      'Dig into add.',
      'Mention the call paths.',
      '',
      'The code asked about is the file src/code.lua, lines 1 to 5.'
        .. ' Tie each explanation to the first line it explains: its line is that line’s number,'
        .. ' from 1 to 5.',
      '',
      '1 | local function add(a, b)',
      '2 |   return a + b',
      '3 | end',
      '4 | ',
      '5 | return add',
    }, '\n')
  )
end

T['a deep request']['for issues ties each issue to its first line, from the first to the last line asked, and has each given as an item'] = function()
  start()

  ask_deep({ kind = 'issues', range = { 2, 3 }, deep = { steer = 'Look hard.' } })

  eq(vim.list_slice(vim.split(recorded(2)[2].stdin, '\n'), 1, 4), {
    'Look hard.',
    '',
    'The code asked about is the file src/code.lua, lines 2 to 3.'
      .. ' Tie each issue to the first line it concerns: its line is that line’s number,'
      .. ' from 2 to 3. Give each issue as an item of the answer’s list.',
    '',
  })
end

T['a kept deep answer'] = MiniTest.new_set()

--- Asks as `ask_deep()` does and waits until the answer is shown.
---
---@param fields? table
local function ask_deep_and_wait(fields)
  ask_deep(fields)
  explained.wait_for(child, (fields or {}).kind or 'explanations', 1)
end

T['a kept deep answer']['is placed again for the same prompt, model and effort on unchanged text, starting no request'] = function()
  start()
  ask_deep_and_wait()

  ask_deep()

  eq(#recorded(2), 2)
  eq(explained.told(child), {
    {
      message = 'aineo: the earlier answer, the code and the prompt unchanged (change the prompt to ask again)',
      level = vim.log.levels.INFO,
    },
  })
end

T['a kept deep answer']['is not reused for another steer: that is a new request'] = function()
  start()
  ask_deep_and_wait()

  ask_deep({ deep = { steer = 'Another steer.' } })

  eq(#recorded(4), 4)
end

T['a kept deep answer']['is not reused for another effort or model: that is a new request'] =
  MiniTest.new_set({
    parametrize = { { { deep = { effort = 'max' } } }, { { model = 'opus' } } },
  })

T['a kept deep answer']['is not reused for another effort or model: that is a new request']['for'] = function(
  fields
)
  start()
  ask_deep_and_wait()

  ask_deep(fields)

  eq(#recorded(4), 4)
end

T['a kept deep answer']['is not what a request with read-only tools alone reuses: that is a new request'] = function()
  start()
  child.lua(
    [[
    local command = ...
    local ask = {
      buffer = vim.api.nvim_get_current_buf(),
      window = vim.api.nvim_get_current_win(),
      tools = true,
      command = command,
      model = 'sonnet',
      timeout_ms = 180000,
    }
    require('aineo.explain').ask(ask)
  ]],
    { explained.FAKE_CLAUDE }
  )
  explained.wait_for(child, 'explanations', 1)
  child.lua("require('aineo.explain').clear(vim.api.nvim_get_current_buf())")

  ask_deep()

  eq(#recorded(4), 4)
end

T['the steering float'] = MiniTest.new_set()

--- The float the child is in, if any: its text, the 'filetype' and
--- 'buftype' of its buffer, its title, and whether it is centred.
local FLOAT_STATE = [[(function()
  local window = vim.api.nvim_get_current_win()
  local config = vim.api.nvim_win_get_config(window)
  if config.relative == '' then
    return vim.NIL
  end
  local buffer = vim.api.nvim_win_get_buf(window)
  local title = ''
  for _, chunk in ipairs(config.title or {}) do
    title = title .. chunk[1]
  end
  local outer_width = config.width + 2
  local outer_height = config.height + 2
  return {
    lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false),
    filetype = vim.bo[buffer].filetype,
    buftype = vim.bo[buffer].buftype,
    title = title,
    centred = math.abs(config.col + outer_width / 2 - vim.o.columns / 2) <= 1
      and math.abs(config.row + outer_height / 2 - (vim.o.lines - 1) / 2) <= 1,
  }
end)()]]

--- The float the child is in (`FLOAT_STATE`); a table with no field when it
--- is in none.
---
---@return table
local function float()
  local state = child.lua_get(FLOAT_STATE)
  return state ~= vim.NIL and state or {}
end

--- Types `keys` in the child and waits until it has settled.
---
---@param ... string
local function press(...)
  child.type_keys(...)
  vim.wait(explained.PATIENCE_MS, function()
    return not child.is_blocked()
  end, 20)
end

T['the steering float']['opens before any request, holding the default prompt for explanations with the file, language and lines filled in'] = function()
  start()

  ask_steered({ range = { 2, 3 } })

  eq(float().lines, {
    'Explain the code of the file src/code.lua (language: lua), lines 2 to 3 as numbered below, thoroughly.',
    'Explain what the code does and why, the call paths and data flow it takes part in,'
      .. ' found by reading the project with the tools, and what is non-obvious.',
  })
  eq(#recorded(0), 0)
end

T['the steering float']['holds the default prompt for issues, asking for the evidence and an empty list when there is none'] = function()
  start()

  ask_steered({ kind = 'issues' })

  eq(float().lines, {
    'Review the code of the file src/code.lua (language: lua), lines 1 to 5 as numbered below, for potential issues.',
    'For each potential issue, say why it holds, how it would show up, and the evidence in the project,'
      .. ' found by reading it with the tools. Make no style remarks, and answer an empty list when you find none.',
  })
end

T['the steering float']['is a markdown scratch buffer in a centred float titled with what it does and its keys'] = function()
  start()

  ask_steered()

  local state = float()
  eq({ state.filetype, state.buftype, state.centred }, { 'markdown', 'nofile', true })
  eq(state.title, ' Deep explanation: <CR> sends · q or <Esc> cancels · R restores the default ')
end

--- How many virtual lines of explanations the file's buffer in the child
--- holds, among them the one that says a request is working, which a request
--- shows the moment it starts.
---
---@return integer
local function explanation_lines_held()
  return child.lua_get([[(function()
    local namespace = vim.api.nvim_get_namespaces().aineo_explain
    local buffer = vim.fn.bufnr('src/code.lua')
    return namespace and #vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, {}) or 0
  end)()]])
end

--- Replaces the text of the float the child is in.
---
---@param lines string[]
local function set_float_text(lines)
  child.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

T['the steering float']['sends the text in Normal mode with <CR>, closes, and starts the request with the text as edited'] = function()
  start()
  ask_steered()
  set_float_text({ 'Dig deep.', 'Mention the callers.' })

  press('<CR>')

  eq(
    vim.startswith(
      recorded(2)[2].stdin,
      'Dig deep.\nMention the callers.\n\nThe code asked about is the file src/code.lua, lines 1 to 5. Tie each'
    ),
    true
  )
  eq(float(), {})
  eq(explanation_lines_held() > 0, true)
end

T['the steering float']['cancels with nothing sent on q and on <Esc> in Normal mode'] =
  MiniTest.new_set({
    parametrize = { { 'q' }, { '<Esc>' } },
  })

T['the steering float']['cancels with nothing sent on q and on <Esc> in Normal mode']['by'] = function(
  key
)
  start()
  ask_steered()

  press(key)

  eq({ float(), explanation_lines_held() }, { {}, 0 })
  eq(#recorded(0), 0)
end

T['the steering float']['puts the default text back on R in Normal mode, and keeps the float'] = function()
  start()
  ask_steered()
  set_float_text({ 'Something else.' })

  press('R')

  eq(
    float().lines[1],
    'Explain the code of the file src/code.lua (language: lua), lines 1 to 5 as numbered below, thoroughly.'
  )
  eq(explanation_lines_held(), 0)
end

T['the steering float']['refuses a text of white space alone with one message, sends nothing and stays open'] = function()
  start()
  ask_steered()
  set_float_text({ '  ', '', '	' })

  press('<CR>')

  eq(float().lines, { '  ', '', '	' })
  eq(explanation_lines_held(), 0)
  eq(explained.told(child), {
    { message = 'aineo: the prompt is empty: nothing is sent', level = vim.log.levels.WARN },
  })
end

T['the steering float']['is plain editing in Insert mode: <CR> breaks the line and sends nothing'] = function()
  start()
  ask_steered()

  press('A', '<CR>', 'More.')

  eq(#float().lines, 3)
  eq(float().lines[2], 'More.')
  eq(explanation_lines_held(), 0)
end

T['the steering float']['starts the next float of the kind with the text last sent, and R brings the default back'] = function()
  start()
  ask_steered()
  set_float_text({ 'My own steer.' })
  press('<CR>')
  explained.wait_for(child, 'explanations', 1)

  ask_steered()

  eq(float().lines, { 'My own steer.' })
  press('R')
  eq(vim.startswith(float().lines[1], 'Explain the code of the file src/code.lua'), true)
end

T['the steering float']['remembers the text sent for each kind apart'] = function()
  start()
  ask_steered()
  set_float_text({ 'My own steer.' })
  press('<CR>')
  explained.wait_for(child, 'explanations', 1)

  ask_steered({ kind = 'issues' })

  eq(vim.startswith(float().lines[1], 'Review the code of the file src/code.lua'), true)
end

--- Sends a steer of `head` and `steer` from the float of the current
--- explanations request and waits until its answer is shown.
---
---@param head string
---@param steer string
local function send_steer(head, steer)
  ask_steered()
  set_float_text({ head, steer })
  press('<CR>')
  explained.wait_for(child, 'explanations', 1)
end

T['the steering float']['keeps the steer sent but names the new file and language in the head when it opens for another file'] = function()
  local folder = start()
  send_steer(
    'Explain the code of the file src/code.lua (language: lua), lines 1 to 5 as numbered below, thoroughly.',
    'My steer.'
  )
  vim.fn.writefile({ 'x = 1', 'y = 2', 'print(x + y)' }, folder .. '/src/other.py')
  child.cmd('edit ' .. folder .. '/src/other.py')

  ask_steered()

  eq(float().lines, {
    'Explain the code of the file src/other.py (language: python), lines 1 to 3 as numbered below, thoroughly.',
    'My steer.',
  })
end

T['the steering float']['refuses lines the buffer no longer has when sent: one message, nothing sent, the float closed'] = function()
  start()
  ask_steered({ range = { 4, 5 } })
  child.lua([[vim.api.nvim_buf_set_lines(vim.fn.bufnr('src/code.lua'), 2, -1, false, {})]])

  press('<CR>')

  eq({ float(), explanation_lines_held() }, { {}, 0 })
  eq(explained.told(child), {
    {
      message = 'aineo: the selected lines are no longer in the buffer',
      level = vim.log.levels.WARN,
    },
  })
end

T['the steering float']['sends nothing and raises nothing when the buffer is gone by then'] = function()
  start()
  child.cmd('new')
  child.cmd('wincmd j')
  local source = child.api.nvim_get_current_buf()
  ask_steered()
  child.api.nvim_buf_delete(source, { force = true })

  local sent_without_error = child.lua_get([[(function()
    local send = vim.fn.maparg('<CR>', 'n', false, true).callback
    return (pcall(send))
  end)()]])

  eq(sent_without_error, true)
  eq({ float(), explained.told(child) }, { {}, {} })
  eq(#recorded(0), 0)
end

--- How many floating windows the child has open.
---
---@return integer
local function floats_open()
  return child.lua_get([[#vim.tbl_filter(function(window)
    return vim.api.nvim_win_get_config(window).relative ~= ''
  end, vim.api.nvim_list_wins())]])
end

--- Waits until the child has no floating window open, or `PATIENCE_MS`.
local function wait_until_no_float()
  vim.wait(explained.PATIENCE_MS, function()
    return floats_open() == 0
  end, 20)
end

T['the steering float']['closes when the user leaves it, sends nothing, and keeps its text as the draft of the next float of the kind'] = function()
  start()
  ask_steered()
  set_float_text({
    'Explain the code of the file src/code.lua (language: lua), lines 1 to 5 as numbered below, thoroughly.',
    'Draft steer.',
  })

  press('<C-w>p')
  wait_until_no_float()

  eq(explanation_lines_held(), 0)
  ask_steered({ range = { 2, 3 } })
  eq(float().lines, {
    'Explain the code of the file src/code.lua (language: lua), lines 2 to 3 as numbered below, thoroughly.',
    'Draft steer.',
  })
end

T['the steering float']['leaves no buffer behind when it closes, however it closes'] =
  MiniTest.new_set({
    parametrize = { { 'q' }, { '<Esc>' }, { '<CR>' }, { '<C-w>p' }, { ':q<CR>' } },
  })

T['the steering float']['leaves no buffer behind when it closes, however it closes']['by'] = function(
  key
)
  start()
  local buffers_before = #child.api.nvim_list_bufs()
  ask_steered()

  press(key)
  wait_until_no_float()

  eq(#child.api.nvim_list_bufs(), buffers_before)
end

T['the steering float']['does not keep what was typed when the user cancels it'] = function()
  start()
  ask_steered()
  set_float_text({ 'Typed and cancelled.' })

  press('q')
  ask_steered()

  eq(vim.startswith(float().lines[1], 'Explain the code of the file src/code.lua'), true)
end

T['the steering float']['is the only one: another deep key while it is open focuses it and opens no other'] = function()
  start()
  local source = child.api.nvim_get_current_buf()
  ask_steered()
  child.cmd('noautocmd wincmd p')

  ask_steered({ buffer = source, kind = 'issues' })

  eq(floats_open(), 1)
  eq(vim.startswith(float().lines[1], 'Explain the code of the file src/code.lua'), true)
end

T['the steering float']['sends, for another file, a prompt that names that file and its lines alone'] = function()
  local folder = start()
  send_steer(
    'Explain the code of the file src/code.lua (language: lua), lines 1 to 5 as numbered below, thoroughly.',
    'My steer.'
  )
  vim.fn.writefile({ 'x = 1', 'y = 2', 'print(x + y)' }, folder .. '/src/other.py')
  child.cmd('edit ' .. folder .. '/src/other.py')
  ask_steered()

  press('<CR>')

  eq(
    recorded(4)[4].stdin,
    table.concat({
      'Explain the code of the file src/other.py (language: python), lines 1 to 3 as numbered below, thoroughly.',
      'My steer.',
      '',
      'The code asked about is the file src/other.py, lines 1 to 3.'
        .. ' Tie each explanation to the first line it explains: its line is that line’s number,'
        .. ' from 1 to 3.',
      '',
      '1 | x = 1',
      '2 | y = 2',
      '3 | print(x + y)',
    }, '\n')
  )
end

T['the steering float']['keeps the steer sent but names the new lines in the head when it opens for another range of the same file'] = function()
  start()
  send_steer(
    'Explain the code of the file src/code.lua (language: lua), lines 1 to 5 as numbered below, thoroughly.',
    'My steer.'
  )

  ask_steered({ range = { 2, 3 } })

  eq(float().lines, {
    'Explain the code of the file src/code.lua (language: lua), lines 2 to 3 as numbered below, thoroughly.',
    'My steer.',
  })
end

T['the steering float']['leaves a head the user rewrote as it was written'] = function()
  start()
  send_steer('My own head.', 'My steer.')

  ask_steered({ range = { 2, 3 } })

  eq(float().lines, { 'My own head.', 'My steer.' })
end

T['the look'] = MiniTest.new_set()

--- The chunks of the first row of the first virtual line the child shows in
--- the namespace `namespace`.
---
---@param namespace string
---@return table[]
local function first_row_in(namespace)
  return child.lua_get(
    [[(function(namespace)
      local marks = vim.api.nvim_buf_get_extmarks(
        0, vim.api.nvim_get_namespaces()[namespace], 0, -1, { details = true })
      return marks[1][4].virt_lines[1]
    end)(...)]],
    { namespace }
  )
end

T['the look']['labels a deep explanation expl+ in the gutter'] = function()
  start()
  child.wo.number = true
  child.wo.numberwidth = 10

  ask_deep_and_wait()

  eq(first_row_in('aineo_explain')[3], { 'expl+', 'AineoExplainGutter' })
end

T['the look']['labels a deep explanation placed again from the answer kept expl+ too, after \\V cleared it'] = function()
  start()
  child.wo.number = true
  child.wo.numberwidth = 10
  ask_deep_and_wait()
  child.lua(
    [[require('aineo.explain').ask({
      buffer = vim.api.nvim_get_current_buf(),
      window = vim.api.nvim_get_current_win(),
      tools = true,
      command = ...,
      model = 'sonnet',
      timeout_ms = 180000,
    })]],
    { explained.FAKE_CLAUDE }
  )

  ask_deep()

  eq(first_row_in('aineo_explain')[3], { 'expl+', 'AineoExplainGutter' })
  eq(#recorded(2), 2)
end

T['the look']['labels a deep issue issue+ in the gutter'] = function()
  start()
  child.wo.number = true
  child.wo.numberwidth = 10
  explained.answer(child, { { line = 2, text = 'overflows' } })

  ask_deep_and_wait({ kind = 'issues' })

  eq(first_row_in('aineo_explain_issues')[3], { 'issue+', 'AineoExplainIssueGutter' })
end

T['the look']['says in its working line and its badge that a deep request is working'] =
  MiniTest.new_set({
    parametrize = {
      { 'explanations', 'explaining in depth…' },
      { 'issues', 'looking for issues in depth…' },
    },
  })

T['the look']['says in its working line and its badge that a deep request is working']['for'] = function(
  kind,
  working
)
  start()
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "3000"')

  ask_deep({ kind = kind })

  local badge = explained.badge_text_once(child, function(text)
    return text:find(working, 1, true) ~= nil
  end)
  eq(badge:find(working, 1, true) ~= nil, true)
  local namespace = kind == 'issues' and 'aineo_explain_issues' or 'aineo_explain'
  eq(first_row_in(namespace)[#first_row_in(namespace)][1]:find(working, 1, true) ~= nil, true)
end

return T
