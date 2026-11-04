local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local explained = dofile('tests/helpers/explain_child.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

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
--- the editor answers.
---
---@param token string
---@param call table
---@return { text: string, is_error: boolean }|false
local function walk(token, call)
  return child.lua_get(
    [[require('aineo.mcp').receive_walkthrough_step(..., select(2, ...))]],
    { call, token }
  )
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
  vim.fn.writefile({ ('x'):rep(1024 * 1024 + 1) }, large)

  local answer = walk(
    token,
    step_for('src/large.txt', { ranges = { { start = 1, ['end'] = 1, text = 'Big.' } } })
  )

  vim.uv.fs_unlink(large)
  eq(answer, { text = ('refused: file: %s is larger than 1 MiB'):format(large), is_error = true })
  eq(bands_by_file(), {})
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

T['a second step']['is shown when the agent is not seen working, which tells no turn from the next'] = function()
  local token = open_layout('walkthrough-no-turn')
  walk(token, step_for('src/code.lua'))

  local answer = walk(token, step_for('src/other.lua', { step = 2 }))

  eq(answer.is_error, false)
  eq(bands_by_file(), { ['src/other.lua'] = { 2, 5 } })
end

return T
