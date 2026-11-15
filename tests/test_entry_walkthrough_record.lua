local MiniTest = require('mini.test')
local entry = dofile('tests/helpers/entry.lua')
local explained = dofile('tests/helpers/explain_child.lua')
local send = dofile('tests/helpers/send.lua')
local walkthrough_session = dofile('tests/helpers/walkthrough_session.lua')

local eq = MiniTest.expect.equality

local instruction = require('aineo.entry.walkthrough_record_instruction')

local child = MiniTest.new_child_neovim()

--- The project every case's child works in, made once for the file.
local project

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      project = walkthrough_session.make_project('walkthrough-record')
    end,
    pre_case = function()
      for _, folder in ipairs({ 'walkthroughs', 'records', 'elsewhere' }) do
        vim.fn.delete(project .. '/' .. folder, 'rf')
      end
      walkthrough_session.restart(child, project)
    end,
    post_once = function()
      walkthrough_session.stop(child)
    end,
  },
})

--- The day the records of the cases are named for.
---
---@return string
local function today()
  return os.date('%Y-%m-%d')
end

--- Opens the layout in the child under `name` and returns the start token.
---
---@param name string
---@param settings? table more of `vim.g.aineo`
---@return string token
local function open_layout(name, settings)
  return walkthrough_session.open_layout(child, 'walkthrough-record-' .. name, settings)
end

--- Sends the plan `call`, or the default one, as the agent does.
---
---@param token string
---@param call? table
local function plan(token, call)
  walkthrough_session.offer(
    child,
    'receive_walkthrough_plan',
    token,
    call or walkthrough_session.plan_for(project)
  )
end

--- Shows the first step as the agent does, and keeps every write to Claude's
--- terminal from then on.
---
---@param token string
local function show_a_step(token)
  walkthrough_session.offer(
    child,
    'receive_walkthrough_step',
    token,
    walkthrough_session.step_for(project, 'src/code.lua', 1)
  )
  send.watch_writes(child)
end

--- Has the child's Claude Code count as busy, or not.
---
---@param busy boolean
local function be_busy(busy)
  walkthrough_session.be_busy(child, busy)
end

--- The bytes Send writes for `message`: one bracketed paste and its Enter.
---
---@param message string
---@return string
local function paste(message)
  return '\27[200~' .. message .. '\27[201~\r'
end

--- Waits until the child has written `count` times to a channel, or the
--- time a case waits is over, and returns what it wrote.
---
---@param count integer
---@return string[]
local function writes_after_waiting_for(count)
  vim.wait(explained.PATIENCE_MS, function()
    return #send.writes(child) >= count
  end, 20)
  return send.writes(child)
end

--- The path of the record of the plan the cases send, in `folder`.
---
---@param folder string
---@param name? string the end of the file's name, without its extension
---@return string
local function record_in(folder, name)
  return ('%s/%s-%s.pdf'):format(folder, today(), name or 'the-values')
end

--- Writes the file `path` in the child's folder, with its folder.
---
---@param path string
local function write_file(path)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile({ 'record' }, path)
end

--- The bands of the walkthrough the child shows, as a count.
---
---@return integer
local function band_count()
  return child.lua_get([[(function()
    local namespace = vim.api.nvim_get_namespaces()['aineo_explain_walk']
    local count = 0
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      count = count + #vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, {})
    end
    return count
  end)()]])
end

--- What the child told the user once the record was due: the messages after
--- the first `skipped` of them.
---
---@param skipped integer
---@return { message: string, level: integer }[]
local function messages_after(skipped)
  return vim.list_slice(entry.messages(child), skipped + 1)
end

T['\\Vq'] = MiniTest.new_set()

T['\\Vq']['asks the agent for the record at the path under the folder Claude works in'] = function()
  local token = open_layout('key')
  plan(token)
  show_a_step(token)

  entry.press(child, '\\Vq')

  eq(
    writes_after_waiting_for(1),
    { paste(instruction.text(record_in(project .. '/walkthroughs'))) }
  )
end

T['\\Vq']['ends the walkthrough as \\vq does: the bands are cleared at once'] = function()
  local token = open_layout('clears')
  plan(token)
  show_a_step(token)

  entry.press(child, '\\Vq')

  eq(band_count(), 0)
end

T['\\Vq']['sends the instruction alone, not the message \\vq sends'] = function()
  local token = open_layout('alone')
  plan(token)
  show_a_step(token)

  entry.press(child, '\\Vq')
  vim.wait(300)

  eq(#send.writes(child), 1)
end

T['\\Vq']['names the record for the walkthrough, walkthrough when its plan was never sent'] = function()
  local token = open_layout('no-plan')
  show_a_step(token)

  entry.press(child, '\\Vq')

  eq(
    writes_after_waiting_for(1),
    { paste(instruction.text(record_in(project .. '/walkthroughs', 'walkthrough'))) }
  )
end

T['\\Vq']['names the record for the plan sent last'] = function()
  local token = open_layout('last-plan')
  plan(token)
  plan(token, walkthrough_session.plan_for(project, { title = 'The Second Take, Revised' }))
  show_a_step(token)

  entry.press(child, '\\Vq')

  eq(
    writes_after_waiting_for(1),
    { paste(instruction.text(record_in(project .. '/walkthroughs', 'the-second-take-revised'))) }
  )
end

T['\\Vq']['puts the record under a relative record_folder'] = function()
  local token = open_layout('relative', { walkthrough = { record_folder = 'records/walks' } })
  plan(token)
  show_a_step(token)

  entry.press(child, '\\Vq')

  eq(
    writes_after_waiting_for(1),
    { paste(instruction.text(record_in(project .. '/records/walks'))) }
  )
end

T['\\Vq']['puts the record in an absolute record_folder as it is'] = function()
  local token =
    open_layout('absolute', { walkthrough = { record_folder = project .. '/elsewhere' } })
  plan(token)
  show_a_step(token)

  entry.press(child, '\\Vq')

  eq(writes_after_waiting_for(1), { paste(instruction.text(record_in(project .. '/elsewhere'))) })
end

T['\\Vq']['counts up from -2 when a record of that name is written already'] = function()
  local token = open_layout('taken')
  plan(token)
  show_a_step(token)
  write_file(record_in(project .. '/walkthroughs'))

  entry.press(child, '\\Vq')

  eq(
    writes_after_waiting_for(1),
    { paste(instruction.text(record_in(project .. '/walkthroughs', 'the-values-2'))) }
  )
end

T['\\Vq']['sends nothing, and says so, while no step is shown'] = function()
  local token = open_layout('none')
  plan(token)
  send.watch_writes(child)

  entry.press(child, '\\Vq')

  eq(send.writes(child), {})
  eq(entry.messages(child), {
    { message = 'aineo: no walkthrough step is shown in this tab', level = vim.log.levels.INFO },
  })
end

T['\\Vq']['waits while the agent works, tells so without the instruction, and goes when the turn ends'] = function()
  local token = open_layout('wait')
  plan(token)
  show_a_step(token)
  be_busy(true)

  entry.press(child, '\\Vq')
  local before_the_end = send.writes(child)
  be_busy(false)

  eq(before_the_end, {})
  eq(
    writes_after_waiting_for(1),
    { paste(instruction.text(record_in(project .. '/walkthroughs'))) }
  )
  eq(entry.messages(child), {
    {
      message = 'aineo: the agent is working: "Write the walkthrough record" goes when its turn ends',
      level = vim.log.levels.INFO,
    },
  })
end

T['the record'] = MiniTest.new_set()

--- Sends `\Vq` in a tab that shows a step, the agent idle, and returns the
--- PDF the instruction asks for.
---
---@param name string
---@return string pdf
local function ask_for_the_record(name)
  local token = open_layout(name)
  plan(token)
  show_a_step(token)
  entry.press(child, '\\Vq')
  writes_after_waiting_for(1)
  return record_in(project .. '/walkthroughs')
end

--- Has the agent work for a turn: it is seen working, then idle.
local function work_for_a_turn()
  be_busy(true)
  be_busy(false)
end

T['the record']['is told as written, as information, when the turn ends with the PDF there'] = function()
  local pdf = ask_for_the_record('told-pdf')
  be_busy(true)
  write_file(pdf)
  write_file((pdf:gsub('%.pdf$', '.html')))
  be_busy(false)

  eq(entry.messages(child), {
    { message = 'aineo: the walkthrough record is written: ' .. pdf, level = vim.log.levels.INFO },
  })
end

T['the record']['is told as HTML only, as a warning, when the turn ends with no PDF tool found'] = function()
  local pdf = ask_for_the_record('told-html')
  local html = pdf:gsub('%.pdf$', '.html')
  be_busy(true)
  write_file(html)
  be_busy(false)

  eq(entry.messages(child), {
    {
      message = 'aineo: the walkthrough record has no PDF, no PDF tool was found: its HTML is at '
        .. html,
      level = vim.log.levels.WARN,
    },
  })
end

T['the record']['is told as not written, as a warning, when the turn ends with no file'] = function()
  local pdf = ask_for_the_record('told-none')

  work_for_a_turn()

  eq(entry.messages(child), {
    {
      message = 'aineo: the walkthrough record was not written: there is no file at ' .. pdf,
      level = vim.log.levels.WARN,
    },
  })
end

T['the record']['is not told before the turn ends'] = function()
  local pdf = ask_for_the_record('told-late')

  be_busy(true)
  write_file(pdf)

  eq(entry.messages(child), {})
end

T['the record']['is told once: a later turn says nothing'] = function()
  local pdf = ask_for_the_record('told-once')
  be_busy(true)
  write_file(pdf)
  be_busy(false)
  local told = #entry.messages(child)

  work_for_a_turn()

  eq(messages_after(told), {})
end

T['the record']['is not told for the turn that sent the instruction held back'] = function()
  local token = open_layout('told-held')
  plan(token)
  show_a_step(token)
  be_busy(true)
  entry.press(child, '\\Vq')
  be_busy(false)
  writes_after_waiting_for(1)
  local told = #entry.messages(child)

  eq(told, 1)
  be_busy(true)
  write_file(record_in(project .. '/walkthroughs'))
  be_busy(false)

  eq(messages_after(told), {
    {
      message = 'aineo: the walkthrough record is written: '
        .. record_in(project .. '/walkthroughs'),
      level = vim.log.levels.INFO,
    },
  })
end

T['the record']['is not told for the turn that sent the instruction when the moves follow the tab first'] = function()
  local token = open_layout('told-held-after-move')
  plan(token)
  show_a_step(token)
  be_busy(true)
  entry.press(child, '\\vn')
  entry.press(child, '\\Vq')
  be_busy(false)
  writes_after_waiting_for(1)
  local told = #entry.messages(child)

  eq(told, 2)
  be_busy(true)
  write_file(record_in(project .. '/walkthroughs'))
  be_busy(false)

  eq(messages_after(told), {
    {
      message = 'aineo: the walkthrough record is written: '
        .. record_in(project .. '/walkthroughs'),
      level = vim.log.levels.INFO,
    },
  })
end

return T
