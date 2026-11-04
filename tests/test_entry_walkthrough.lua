local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local explained = dofile('tests/helpers/explain_child.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local send = dofile('tests/helpers/send.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The lines of the files every case walks through.
local CODE = {
  'local a = 1',
  'local b = 2',
  'local c = 3',
  'local d = 4',
  'local e = 5',
  'return a',
}

--- The project every case's child works in, made once for the file.
local project

--- Takes on the git isolation of the git home's suites in this file's own
--- Neovim, which every child it starts inherits, and makes `project`.
local function make_the_project()
  for name, value in pairs(git_repo.ENVIRONMENT) do
    vim.env[name] = value
  end
  project = git_repo.create('walkthrough', {
    ['src/code.lua'] = CODE,
    ['src/other.lua'] = CODE,
    ['src/long.lua'] = vim.fn.map(vim.fn.range(1, 100), 'printf("local v%d = %d", v:val, v:val)'),
  })
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
  child.o.columns = 200
  child.o.lines = 50
  child.cmd('cd ' .. vim.fn.fnameescape(project))
end

local T = MiniTest.new_set({
  hooks = {
    pre_once = make_the_project,
    pre_case = restart_in_the_project,
    post_once = stop_the_child,
  },
})

--- Opens aineo's layout in the child with the fake `claude` ready for input
--- under `name`, waits until the tab has written its entry in the list of
--- running editors, which makes the editor's handlers, and returns the
--- start token its hooks carry.
---
---@param name string the case's own name for its files, starting `walkthrough-`
---@return string token
local function open_layout(name)
  local fake = claude_session.fake(name, 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  claude_session.wait_for_status(child, 'ready')
  vim.wait(explained.PATIENCE_MS, function()
    return child.lua_get([[(pcall(vim.api.nvim_get_autocmds, { group = 'aineo.editors' }))]])
  end, 20)
  return claude_session.start_token(fake, 1)
end

--- A call of the walkthrough tool for `path`, a file of the project, that
--- is valid but for the fields `overrides` replaces.
---
---@param path string
---@param overrides? table
---@return table
local function step_for(path, overrides)
  return vim.tbl_extend('force', {
    file = project .. '/' .. path,
    title = 'The values',
    step = 1,
    total = 3,
    ranges = {
      { start = 2, ['end'] = 3, text = 'Two values.' },
      { start = 5, ['end'] = 5, text = 'The fifth.' },
    },
  }, overrides or {})
end

--- Offers the child's MCP home a call of the walkthrough tool, as the relay
--- of the Claude Code with the start token `token` does, and returns what
--- the editor answers, or, when the editor raises an error instead, a table
--- naming it, so that a case compares it with what it expects and fails by
--- its assertion.
---
---@param token string
---@param call table
---@return { text: string, is_error: boolean }|false|{ raised: string }
local function walk(token, call)
  local answered, answer = pcall(
    child.lua_get,
    [[require('aineo.mcp').receive_walkthrough_step(..., select(2, ...))]],
    { call, token }
  )
  return answered and answer or { raised = tostring(answer) }
end

--- The buffers of the child that show walkthrough bands, by the name of
--- each buffer's file from the project, with the line each band is above.
---
---@return table<string, integer[]>
local function bands_by_file()
  return child.lua_get(
    [[(function(project)
      local namespace = vim.api.nvim_get_namespaces()['aineo_explain_walk']
      local found = {}
      if not namespace then
        return found
      end
      for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        local lines = {}
        for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, {})) do
          table.insert(lines, mark[2] + 1)
        end
        if #lines > 0 then
          local name = vim.api.nvim_buf_get_name(buffer)
          found[vim.fs.relpath(project, name) or name] = lines
        end
      end
      return found
    end)(...)]],
    { project }
  )
end

T['a step'] = MiniTest.new_set()

T['a step']['opens the file in the middle window with a band above each range, the cursor staying where it was'] = function()
  local token = open_layout('walkthrough-opens')
  local was_in = child.lua_get('vim.api.nvim_get_current_win()')

  local answer = walk(token, step_for('src/code.lua'))

  eq(answer.is_error, false)
  eq(bands_by_file(), { ['src/code.lua'] = { 2, 5 } })
  eq(child.lua_get('vim.api.nvim_get_current_win()'), was_in)
  eq(
    child.lua_get([[vim.fn.bufwinid(vim.fn.bufnr(...)) > 0]], { project .. '/src/code.lua' }),
    true
  )
end

T['a step']['puts the first range in view, with a few lines above it, and the cursor on its first line'] = function()
  local token = open_layout('walkthrough-in-view')
  local was_in = child.lua_get('vim.api.nvim_get_current_win()')

  walk(
    token,
    step_for('src/long.lua', {
      ranges = {
        { start = 80, ['end'] = 82, text = 'Far down.' },
        { start = 10, ['end'] = 10, text = 'Not first.' },
      },
    })
  )

  eq(
    child.lua_get(
      [[(function(file)
        local window = vim.fn.bufwinid(vim.fn.bufnr(file))
        local view = vim.api.nvim_win_call(window, vim.fn.winsaveview)
        return { view.topline, view.lnum, vim.api.nvim_get_current_win() }
      end)(...)]],
      { project .. '/src/long.lua' }
    ),
    { 77, 80, was_in }
  )
end

T['a step']['answers what it shows and that the next step waits for the user'] = function()
  local token = open_layout('walkthrough-answer')

  local answer = walk(token, step_for('src/code.lua'))

  eq(answer, {
    text = ('Showing step 1/3, "The values", 2 explanations in %s/src/code.lua.'):format(project)
      .. ' Show the next step only when the user asks to move on.',
    is_error = false,
  })
end

T['a step']['takes the place of the previous step, in whichever file that was'] = function()
  local token = open_layout('walkthrough-replaces')
  walk(token, step_for('src/code.lua'))

  walk(token, step_for('src/other.lua', { step = 2 }))

  eq(bands_by_file(), { ['src/other.lua'] = { 2, 5 } })
end

--- The refusal `text` for a call, with the project's folder where it says
--- `PROJECT`.
---
---@param text string
---@return string
local function refusal(text)
  return 'refused: ' .. text:gsub('PROJECT', project)
end

T['a step']['is refused, and shows nothing, when the file or a range is not what the agent says'] =
  MiniTest.new_set({
    parametrize = {
      { { file = 'PROJECT/src/missing.lua' }, 'file: PROJECT/src/missing.lua is not on disk' },
      { { file = 'PROJECT/src' }, 'file: PROJECT/src is not a regular file' },
      {
        { file = 'PROJECT/.git/HEAD' },
        'file: PROJECT/.git/HEAD is under .git, outside the repository or a link leading out of it',
      },
      {
        { ranges = { { start = 2, ['end'] = 7, text = 'Too far.' } } },
        'ranges[1]: lines 2-7 are outside the file, which has 6 lines',
      },
      {
        {
          ranges = {
            { start = 2, ['end'] = 2, text = 'Fine.' },
            { start = 7, ['end'] = 7, text = 'Past it.' },
          },
        },
        'ranges[2]: lines 7-7 are outside the file, which has 6 lines',
      },
      {
        { ranges = { { start = 2, ['end'] = 2, text = 'Fine.', first_line = 'local x = 9' } } },
        'ranges[1].first_line: line 2 reads "local b = 2", not "local x = 9"',
      },
    },
  })

T['a step']['is refused, and shows nothing, when the file or a range is not what the agent says']['given'] = function(
  overrides,
  text
)
  local token = open_layout('walkthrough-refused')
  local call = step_for('src/code.lua', overrides)
  call.file = call.file:gsub('PROJECT', project)

  local answer = walk(token, call)

  eq(answer, { text = refusal(text), is_error = true })
  eq(bands_by_file(), {})
end

T['a step']['shows a range whose first line reads as the agent expects, whatever the spaces around it'] = function()
  local token = open_layout('walkthrough-first-line')

  local answer = walk(
    token,
    step_for('src/code.lua', {
      ranges = { { start = 2, ['end'] = 2, text = 'Fine.', first_line = '  local b = 2 ' } },
    })
  )

  eq(answer.is_error, false)
  eq(bands_by_file(), { ['src/code.lua'] = { 2 } })
end

--- Makes a second repository, which the editor does not have open, holding
--- the file `a.lua`; returns its folder.
---
---@param name string
---@return string folder
local function other_repository(name)
  return git_repo.create(name, { ['a.lua'] = CODE })
end

T['a step']['is refused for a file of a repository the editor does not have open'] = function()
  local token = open_layout('walkthrough-not-open')
  local other = other_repository('walkthrough-not-open-other')

  local answer = walk(token, step_for('src/code.lua', { file = other .. '/a.lua' }))

  eq(answer, {
    text = ('refused: file: %s/a.lua is in no repository the editor has open'):format(other),
    is_error = true,
  })
  eq(bands_by_file(), {})
end

T['a step']['is refused for a link that leads out of the repository'] = function()
  local token = open_layout('walkthrough-link-out')
  local other = other_repository('walkthrough-link-out-other')
  local link = project .. '/src/leak.lua'
  vim.uv.fs_unlink(link)
  assert(vim.uv.fs_symlink(other .. '/a.lua', link))

  local answer = walk(token, step_for('src/leak.lua'))

  vim.uv.fs_unlink(link)
  eq(answer, {
    text = ('refused: file: %s is under .git, outside the repository or a link leading out of it'):format(
      link
    ),
    is_error = true,
  })
  eq(bands_by_file(), {})
end

T['a step']['is refused for a file larger than 1 MiB'] = function()
  local token = open_layout('walkthrough-large')
  local large = project .. '/src/large.txt'
  vim.fn.writefile({ ('x'):rep(1024 * 1024) }, large)

  local answer = walk(
    token,
    step_for('src/large.txt', { ranges = { { start = 1, ['end'] = 1, text = 'Big.' } } })
  )

  vim.uv.fs_unlink(large)
  eq(answer, { text = ('refused: file: %s is larger than 1 MiB'):format(large), is_error = true })
  eq(bands_by_file(), {})
end

T['a step']['shows a file of exactly 1 MiB'] = function()
  local token = open_layout('walkthrough-largest')
  local largest = project .. '/src/largest.txt'
  vim.fn.writefile({ ('x'):rep(1024 * 1024 - 1) }, largest)

  local answer = walk(
    token,
    step_for('src/largest.txt', { ranges = { { start = 1, ['end'] = 1, text = 'Big.' } } })
  )

  vim.uv.fs_unlink(largest)
  eq(answer.is_error, false)
end

T['a step']['shows a file of a worktree the tab’s agents reported, besides the repositories the editor has open'] = function()
  local token = open_layout('walkthrough-reported')
  local other = other_repository('walkthrough-reported-other')
  child.lua(
    [[
    local other = ...
    require('aineo.entry.registry').tab_list[1].homes.changes.reported_worktree_tops = function()
      return { other }
    end
  ]],
    { other }
  )

  local answer = walk(token, step_for('src/code.lua', { file = other .. '/a.lua' }))

  eq(answer.is_error, false)
  eq(bands_by_file(), { [other .. '/a.lua'] = { 2, 5 } })
end

T['a step']['is refused, and shows nothing, when the layout has no room for the file'] = function()
  local token = open_layout('walkthrough-no-room')
  child.lua(
    [[require('aineo.entry.registry').tab_list[1].homes.layout.show_file = function() return nil end]]
  )

  local answer = walk(token, step_for('src/code.lua'))

  eq(answer, { text = 'refused: the middle column has no room for the file', is_error = true })
  eq(bands_by_file(), {})
end

T['ending the walkthrough'] = MiniTest.new_set()

T['ending the walkthrough']['clears the bands, whichever file shows them, and says so'] = function()
  local token = open_layout('walkthrough-end')
  walk(token, step_for('src/code.lua'))

  local answer = walk(token, step_for('src/code.lua', { step = 3, ranges = {} }))

  eq(answer, { text = 'The walkthrough is ended and its bands are cleared.', is_error = false })
  eq(bands_by_file(), {})
end

T['ending the walkthrough']['needs no file that is there'] = function()
  local token = open_layout('walkthrough-end-nothing')

  local answer = walk(token, step_for('src/code.lua', { file = '/nowhere.lua', ranges = {} }))

  eq(answer, { text = 'The walkthrough is ended and its bands are cleared.', is_error = false })
end

--- The number of Claude's terminal buffer in the child.
---
---@return integer
local function terminal_buffer()
  return child.lua_get([[vim.iter(vim.api.nvim_list_bufs()):find(function(number)
    return vim.bo[number].buftype == 'terminal'
  end)]])
end

--- Has the child's Claude Code count as busy, or not.
---
---@param busy boolean
local function be_busy(busy)
  child.lua('vim.b[...].aineo_session_busy = select(2, ...)', { terminal_buffer(), busy })
end

T['a second step'] = MiniTest.new_set()

T['a second step']['within one turn of the agent is refused, and the first step stays shown'] = function()
  local token = open_layout('walkthrough-one-turn')
  be_busy(true)
  walk(token, step_for('src/code.lua'))

  local answer = walk(token, step_for('src/other.lua', { step = 2 }))

  eq(answer, {
    text = 'refused: a step is shown in this turn already;'
      .. ' show the next one in a turn of its own, once the user asks to move on',
    is_error = true,
  })
  eq(bands_by_file(), { ['src/code.lua'] = { 2, 5 } })
end

T['a second step']['in the turn after is shown'] = function()
  local token = open_layout('walkthrough-next-turn')
  be_busy(true)
  walk(token, step_for('src/code.lua'))
  be_busy(false)
  be_busy(true)

  local answer = walk(token, step_for('src/other.lua', { step = 2 }))

  eq(answer.is_error, false)
  eq(bands_by_file(), { ['src/other.lua'] = { 2, 5 } })
end

T['a second step']['is shown once the turn that showed the first has ended'] = function()
  local token = open_layout('walkthrough-turn-ended')
  be_busy(true)
  walk(token, step_for('src/code.lua'))
  be_busy(false)

  local answer = walk(token, step_for('src/other.lua', { step = 2 }))

  eq(answer.is_error, false)
  eq(bands_by_file(), { ['src/other.lua'] = { 2, 5 } })
end

T['a second step']['is shown when the agent is not seen working, which tells no turn from the next'] = function()
  local token = open_layout('walkthrough-no-turn')
  walk(token, step_for('src/code.lua'))

  local answer = walk(token, step_for('src/other.lua', { step = 2 }))

  eq(answer.is_error, false)
  eq(bands_by_file(), { ['src/other.lua'] = { 2, 5 } })
end

T['the keys'] = MiniTest.new_set()

--- The bytes Send writes for `message`: one bracketed paste and its Enter.
---
---@param message string
---@return string
local function paste(message)
  return '\27[200~' .. message .. '\27[201~\r'
end

--- Shows a step in the child, as an agent does, and keeps every write to
--- Claude's terminal from then on.
---
---@param token string
local function show_a_step(token)
  walk(token, step_for('src/code.lua'))
  send.watch_writes(child)
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

T['the keys']['\\vn sends the next step to the session as a message of the user'] = function()
  local token = open_layout('walkthrough-key-next')
  show_a_step(token)

  entry.press(child, '\\vn')

  eq(writes_after_waiting_for(1), { paste('Next walkthrough step') })
end

T['the keys']['\\vp sends the previous step'] = function()
  local token = open_layout('walkthrough-key-previous')
  show_a_step(token)

  entry.press(child, '\\vp')

  eq(writes_after_waiting_for(1), { paste('Previous walkthrough step') })
end

T['the keys']['\\vq sends the end of the walkthrough and clears its bands at once'] = function()
  local token = open_layout('walkthrough-key-end')
  show_a_step(token)

  entry.press(child, '\\vq')

  eq(writes_after_waiting_for(1), { paste('End the walkthrough') })
  eq(bands_by_file(), {})
end

T['the keys']['say so, and send nothing, while no step is shown'] = MiniTest.new_set({
  parametrize = { { '\\vn' }, { '\\vp' }, { '\\vq' } },
})

T['the keys']['say so, and send nothing, while no step is shown']['given'] = function(keys)
  open_layout('walkthrough-key-none')
  send.watch_writes(child)

  entry.press(child, keys)

  eq(send.writes(child), {})
  eq(entry.messages(child), {
    { message = 'aineo: no walkthrough step is shown in this tab', level = vim.log.levels.INFO },
  })
end

T['the keys']['say so, and send nothing, in a tab page that holds no tab of aineo'] = function()
  local token = open_layout('walkthrough-key-other-page')
  show_a_step(token)
  child.cmd('tabnew')

  entry.press(child, '\\vn')

  eq(send.writes(child), {})
  eq(entry.messages(child), {
    { message = 'aineo: no walkthrough step is shown in this tab', level = vim.log.levels.INFO },
  })
end

T['the keys']['say so once the walkthrough is ended'] = function()
  local token = open_layout('walkthrough-key-after-end')
  show_a_step(token)
  entry.press(child, '\\vq')

  entry.press(child, '\\vn')

  eq(writes_after_waiting_for(1), { paste('End the walkthrough') })
  eq(entry.messages(child), {
    { message = 'aineo: no walkthrough step is shown in this tab', level = vim.log.levels.INFO },
  })
end

T['a key while the agent works'] = MiniTest.new_set()

T['a key while the agent works']['waits, and the message goes when the turn ends, the user told so'] = function()
  local token = open_layout('walkthrough-wait')
  show_a_step(token)
  be_busy(true)

  entry.press(child, '\\vn')
  local before_the_end = send.writes(child)
  be_busy(false)

  eq(before_the_end, {})
  eq(writes_after_waiting_for(1), { paste('Next walkthrough step') })
  eq(entry.messages(child), {
    {
      message = 'aineo: the agent is working: "Next walkthrough step" goes when its turn ends',
      level = vim.log.levels.INFO,
    },
  })
end

T['a key while the agent works']['is sent once, not again at the end of a later turn'] = function()
  local token = open_layout('walkthrough-wait-once')
  show_a_step(token)
  be_busy(true)
  entry.press(child, '\\vn')
  be_busy(false)
  writes_after_waiting_for(1)

  be_busy(true)
  be_busy(false)
  vim.wait(300)

  eq(send.writes(child), { paste('Next walkthrough step') })
end

T['a key while the agent works']['never leaves two messages waiting: the last key replaces the one before'] = function()
  local token = open_layout('walkthrough-wait-replace')
  show_a_step(token)
  be_busy(true)
  entry.press(child, '\\vn')
  entry.press(child, '\\vp')

  be_busy(false)

  eq(writes_after_waiting_for(1), { paste('Previous walkthrough step') })
  vim.wait(300)
  eq(send.writes(child), { paste('Previous walkthrough step') })
end

T['a key while the agent works']['\\vq clears the bands at once and its message replaces the one waiting'] = function()
  local token = open_layout('walkthrough-wait-end')
  show_a_step(token)
  be_busy(true)
  entry.press(child, '\\vn')

  entry.press(child, '\\vq')
  local bands = bands_by_file()
  be_busy(false)

  eq(bands, {})
  eq(writes_after_waiting_for(1), { paste('End the walkthrough') })
end

T['the keys']['send nothing while a claim of another session holds, and say why'] = function()
  local claimed = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'
  child.lua('vim.env.XDG_STATE_HOME = ...', { fixture.directory('walkthrough-claim') })
  local fake = claude_session.fake('walkthrough-claim', 'ready', { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  claude_session.wait_for_status(child, 'ready')
  vim.wait(explained.PATIENCE_MS, function()
    return child.lua_get([[(pcall(vim.api.nvim_get_autocmds, { group = 'aineo.editors' }))]])
  end, 20)
  local token = claude_session.start_token(fake, 1)
  show_a_step(token)
  child.cmd('Aineo claim ' .. claimed)
  child.lua('_G.entry_test_messages = {}')

  entry.press(child, '\\vn')

  eq(send.writes(child), {})
  eq(entry.messages(child), {
    {
      message = 'aineo: nothing sent — Input holds the draft of the claimed session '
        .. claimed
        .. '; :Aineo claim with no argument returns this Neovim to its own session',
      level = vim.log.levels.WARN,
    },
  })
end

T['the keys']['\\vc cleans the bands from the window of the file, and sends nothing'] = function()
  local token = open_layout('walkthrough-key-clean')
  show_a_step(token)
  child.lua(
    [[vim.api.nvim_set_current_win(vim.fn.bufwinid(vim.fn.bufnr(...)))]],
    { project .. '/src/code.lua' }
  )

  entry.press(child, '\\vc')

  eq(bands_by_file(), {})
  eq(send.writes(child), {})
end

T['the keys']['\\vc cleans the bands from another window of the tab too, and sends nothing'] = function()
  local token = open_layout('walkthrough-key-clean-elsewhere')
  show_a_step(token)

  entry.press(child, '\\vc')

  eq(bands_by_file(), {})
  eq(send.writes(child), {})
end

return T
