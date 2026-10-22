local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local explained = dofile('tests/helpers/explain_child.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local send = dofile('tests/helpers/send.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The lines of the file every case explains.
local CODE = {
  'local a = 1',
  'local b = 2',
  'local c = 3',
  'local d = 4',
  'local e = 5',
  'return a',
}

--- The words that open the prompt of marked issues unless a case sets its own.
local DEFAULT_PROMPT =
  'Some issues were found in this code, can you check and propose a fix if the issue holds:'

--- The project every case's child works in, made once for the file.
local project

--- Takes on the git isolation of the git home's suites in this file's own
--- Neovim, which every child it starts inherits, and makes `project`.
local function make_the_project()
  for name, value in pairs(git_repo.ENVIRONMENT) do
    vim.env[name] = value
  end
  project = git_repo.create('explain-send', { ['src/code.lua'] = CODE })
end

--- The Lua that ends, in the child, the process of every terminal by a
--- hangup, and waits for each to end, at most 5 s each.
local END_TERMINALS = [[
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      local job = vim.b[buffer].terminal_job_id
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 5000)
    end
  end
]]

--- Stops the child, once the fake Claude Code it runs, if any, has ended.
local function stop_the_child()
  if child.is_running() then
    child.lua(END_TERMINALS)
  end
  child.stop()
end

--- Starts the child afresh in `project`, where Claude Code starts.
local function restart_in_the_project()
  stop_the_child()
  entry.restart(child)
  child.cmd('cd ' .. vim.fn.fnameescape(project))
end

local T = MiniTest.new_set({
  hooks = {
    pre_once = make_the_project,
    pre_case = restart_in_the_project,
    post_once = stop_the_child,
  },
})

--- Shows the file `src/code.lua` in a floating window of its own over the
--- layout, which it leaves as it is, and keeps every write to Claude's
--- terminal from then on (`send.watch_writes()`).
local function show_the_file()
  child.lua(
    [[
    local buffer = vim.fn.bufadd(...)
    vim.fn.bufload(buffer)
    vim.api.nvim_open_win(buffer, true, {
      relative = 'editor', row = 1, col = 1, width = 60, height = 12,
    })
  ]],
    { project .. '/src/code.lua' }
  )
  send.watch_writes(child)
end

--- Opens aineo's layout in the child with the fake `claude` in `mode` under
--- `name`. Returns the fake.
---
---@param name string
---@param mode string
---@param settings? table more of `vim.g.aineo`
---@return table fake
local function open_layout(name, mode, settings)
  local fake = claude_session.fake(name, mode)
  entry.use_fake(child, fake, settings)
  child.cmd('Aineo open')
  return fake
end

--- Opens the layout as `open_layout()` does, waits for the fake to be ready
--- for input, then shows the file (`show_the_file()`).
---
---@param name string
---@param settings? table more of `vim.g.aineo`
local function open_ready_layout(name, settings)
  open_layout(name, 'ready', settings)
  claude_session.wait_for_status(child, 'ready')
  show_the_file()
end

--- Types `keys` in the child's Normal mode as a user would, and waits until
--- they have run.
---
---@param keys string
local function press(keys)
  child.type_keys(keys)
  vim.wait(explained.PATIENCE_MS, function()
    return not child.is_blocked()
  end, 20)
end

--- Places issues on the lines of the child's file, each a line and a text.
---
---@param found { line: integer, text: string }[]
local function find_issues(found)
  explained.place(child, 'issues', found)
end

--- Marks the issue above `line`, as \vm does there.
---
---@param line integer
local function mark_issue_on(line)
  child.api.nvim_win_set_cursor(0, { line, 0 })
  press('\\vm')
end

--- The bytes Send writes for `message`: one bracketed paste and its Enter.
---
---@param message string
---@return string
local function paste(message)
  return '\27[200~' .. message .. '\27[201~\r'
end

--- How many issues the child's badge says are marked: the number in its
--- text, 0 when it shows none.
---
---@return integer
local function marked_in_badge()
  local floats = explained.floats(child)
  return floats[1] and tonumber(floats[1].text:match('(%d+) issue')) or 0
end

--- The number of Claude's terminal buffer in the child, once it exists, or
--- after the time a case waits.
---
---@return integer
local function terminal_buffer()
  local buffer
  vim.wait(explained.PATIENCE_MS, function()
    buffer = child.lua_get([[vim.iter(vim.api.nvim_list_bufs()):find(function(number)
      return vim.bo[number].buftype == 'terminal'
    end)]])
    return buffer ~= vim.NIL
  end, 20)
  return buffer
end

T['\\s'] = MiniTest.new_set()

T['\\s']['in a window whose buffer has marked issues sends them at once, in buffer order, behind the default prompt'] = function()
  open_ready_layout('explain-send-order')
  find_issues({ { line = 4, text = 'Shadows d.' }, { line = 2, text = 'Never used.' } })
  mark_issue_on(4)
  mark_issue_on(2)

  press('\\s')

  eq(send.writes(child), {
    paste(DEFAULT_PROMPT .. '\n- src/code.lua:2: Never used.' .. '\n- src/code.lua:4: Shadows d.'),
  })
end

T['\\s']['sends only the issues marked'] = function()
  open_ready_layout('explain-send-marked')
  find_issues({ { line = 2, text = 'First.' }, { line = 4, text = 'Second.' } })
  mark_issue_on(4)

  press('\\s')

  eq(send.writes(child), { paste(DEFAULT_PROMPT .. '\n- src/code.lua:4: Second.') })
end

T['\\s']['writes the issues’ prompt from explain.issues_prompt'] = function()
  open_ready_layout('explain-send-prompt', { explain = { issues_prompt = 'Fix these:' } })
  find_issues({ { line = 2, text = 'Never used.' } })
  mark_issue_on(2)

  press('\\s')

  eq(send.writes(child), { paste('Fix these:\n- src/code.lua:2: Never used.') })
end

T['\\s']['puts an issue’s text on one line'] = function()
  open_ready_layout('explain-send-one-line')
  find_issues({ { line = 2, text = 'Never used.\n\n  Remove it.' } })
  mark_issue_on(2)

  press('\\s')

  eq(send.writes(child), { paste(DEFAULT_PROMPT .. '\n- src/code.lua:2: Never used. Remove it.') })
end

T['\\s']['gives the line an issue starts at as the lines move'] = function()
  open_ready_layout('explain-send-moved')
  find_issues({ { line = 2, text = 'Never used.' } })
  mark_issue_on(2)
  child.api.nvim_buf_set_lines(0, 0, 0, false, { '-- a new first line' })

  press('\\s')

  eq(send.writes(child), { paste(DEFAULT_PROMPT .. '\n- src/code.lua:3: Never used.') })
end

T['\\s']['leaves Input as it is'] = function()
  open_ready_layout('explain-send-input')
  entry.set_input(child, { 'a draft' })
  find_issues({ { line = 2, text = 'Never used.' } })
  mark_issue_on(2)

  press('\\s')

  eq(send.input(child).lines, { 'a draft' })
  eq(#send.writes(child), 1)
end

T['\\s']['clears the marks once sent, and the issues stay shown'] = function()
  open_ready_layout('explain-send-cleared')
  find_issues({ { line = 2, text = 'Never used.' } })
  mark_issue_on(2)

  press('\\s')

  eq(marked_in_badge(), 0)
  eq(
    child.lua_get(
      [[#vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces().aineo_explain_issues, 0, -1, {})]]
    ),
    1
  )
end

T['\\s']['pressed again, with no issue marked, sends Input as it always has'] = function()
  open_ready_layout('explain-send-again')
  find_issues({ { line = 2, text = 'Never used.' } })
  mark_issue_on(2)
  press('\\s')
  entry.set_input(child, { 'the draft' })

  press('\\s')

  eq(send.writes(child), {
    paste(DEFAULT_PROMPT .. '\n- src/code.lua:2: Never used.'),
    paste('the draft'),
  })
end

T['\\s']['with issues shown and none marked sends Input as it always has'] = function()
  open_ready_layout('explain-send-unmarked')
  entry.set_input(child, { 'the draft' })
  find_issues({ { line = 2, text = 'Never used.' } })

  press('\\s')

  eq(send.writes(child), { paste('the draft') })
end

T['\\s']['with the marked issue’s line deleted sends Input as it always has'] = function()
  open_ready_layout('explain-send-deleted')
  entry.set_input(child, { 'the draft' })
  find_issues({ { line = 2, text = 'Never used.' } })
  mark_issue_on(2)
  child.api.nvim_buf_set_lines(0, 1, 2, false, {})
  vim.wait(explained.PATIENCE_MS, function()
    return marked_in_badge() == 0
  end, 20)

  press('\\s')

  eq(send.writes(child), { paste('the draft') })
end

T['\\s']['from another tab page sends the issues through the tab that Send acts on'] = function()
  open_ready_layout('explain-send-tab')
  find_issues({ { line = 2, text = 'Never used.' } })
  mark_issue_on(2)
  child.cmd('tab split')

  press('\\s')

  eq(send.writes(child), { paste(DEFAULT_PROMPT .. '\n- src/code.lua:2: Never used.') })
end

T['\\s']['from a tab page of its own, whose aineo tab shows another file, sends the issues and leaves Input'] = function()
  open_layout('explain-send-own-tab', 'ready')
  claude_session.wait_for_status(child, 'ready')
  entry.set_input(child, { 'a draft' })
  send.watch_writes(child)
  child.cmd('tabedit ' .. vim.fn.fnameescape(project .. '/src/code.lua'))
  find_issues({ { line = 2, text = 'Never used.' } })
  mark_issue_on(2)

  press('\\s')

  eq(send.writes(child), { paste(DEFAULT_PROMPT .. '\n- src/code.lua:2: Never used.') })
  eq(send.input(child).lines, { 'a draft' })
end

T['\\s']['keeps the marks, and tells the user as Send does, when Claude is not ready'] = function()
  local fake = open_layout('explain-send-trust', 'trust')
  claude_session.wait_for_screen(child, terminal_buffer(), 'Yes, I trust this folder')
  show_the_file()
  find_issues({ { line = 2, text = 'Never used.' } })
  mark_issue_on(2)
  local before = #claude_session.received(fake)

  press('\\s')

  eq(marked_in_badge(), 1)
  eq(send.writes(child), {})
  eq(#claude_session.received(fake), before)
  eq(entry.messages(child), {
    {
      message = 'aineo: nothing sent — Claude is not ready: it is starting, or a dialog in its window awaits your answer',
      level = vim.log.levels.WARN,
    },
  })
end

T['\\s']['in Visual mode does what it does without marked issues: sends nothing from a window that is not Input'] = function()
  open_ready_layout('explain-send-visual')
  find_issues({ { line = 2, text = 'Never used.' } })
  mark_issue_on(2)

  press('Vj\\s')

  eq(send.writes(child), {})
  eq(marked_in_badge(), 1)
  eq(entry.messages(child), {
    {
      message = 'aineo: nothing sent — Visual Send works in Input only',
      level = vim.log.levels.WARN,
    },
  })
end

return T
