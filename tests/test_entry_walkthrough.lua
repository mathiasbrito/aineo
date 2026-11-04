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

--- The spellings of the path of `src/code.lua` that name the same file, by
--- a name for the case, each made from the project's folder.
local SPELLINGS = {
  dot = function()
    return project .. '/src/./code.lua'
  end,
  up = function()
    return project .. '/src/../src/code.lua'
  end,
  double_slash = function()
    return '/' .. project .. '/src/code.lua'
  end,
  through_a_link = function()
    local link = project .. '-link'
    vim.uv.fs_unlink(link)
    assert(vim.uv.fs_symlink(project, link))
    return link .. '/src/code.lua'
  end,
}

T['a step']['checks the ranges against the buffer the user edits, whatever the spelling of the path'] =
  MiniTest.new_set({
    parametrize = { { 'dot' }, { 'up' }, { 'double_slash' }, { 'through_a_link' } },
  })

T['a step']['checks the ranges against the buffer the user edits, whatever the spelling of the path']['given'] = function(
  spelling
)
  local token = open_layout('walkthrough-spelling-' .. spelling)
  walk(token, step_for('src/code.lua'))
  child.lua(
    [[
    local buffer = vim.fn.bufnr(...)
    vim.api.nvim_buf_set_lines(buffer, 2, 6, false, {})
  ]],
    { project .. '/src/code.lua' }
  )
  local file = SPELLINGS[spelling]()

  local answer = walk(
    token,
    step_for('src/code.lua', {
      file = file,
      step = 2,
      ranges = { { start = 5, ['end'] = 5, text = 'Gone.', first_line = 'local e = 5' } },
    })
  )

  eq(answer, {
    text = 'refused: ranges[1]: lines 5-5 are outside the file, which has 2 lines',
    is_error = true,
  })
  eq(bands_by_file(), { ['src/code.lua'] = { 2 } })
end

T['a step']['that is refused leaves the bands of the step before as they were'] = MiniTest.new_set({
  parametrize = {
    { { file = 'PROJECT/src/missing.lua' } },
    { { ranges = { { start = 2, ['end'] = 70, text = 'Too far.' } } } },
  },
})

T['a step']['that is refused leaves the bands of the step before as they were']['given'] = function(
  overrides
)
  local token = open_layout('walkthrough-refused-keeps')
  walk(token, step_for('src/code.lua'))
  local call = step_for('src/other.lua', vim.tbl_extend('force', { step = 2 }, overrides))
  call.file = call.file:gsub('PROJECT', project)

  local answer = walk(token, call)

  eq(answer.is_error, true)
  eq(bands_by_file(), { ['src/code.lua'] = { 2, 5 } })
end

T['a step']['checks first_line against the buffer the user edits, whatever the spelling of the path'] = function()
  local token = open_layout('walkthrough-spelling-first-line')
  walk(token, step_for('src/code.lua'))
  child.lua(
    [[
    local buffer = vim.fn.bufnr(...)
    vim.api.nvim_buf_set_lines(buffer, 0, 0, false, { 'new one', 'new two' })
  ]],
    { project .. '/src/code.lua' }
  )

  local answer = walk(
    token,
    step_for('src/code.lua', {
      file = SPELLINGS.dot(),
      step = 2,
      ranges = { { start = 5, ['end'] = 5, text = 'Moved.', first_line = 'local e = 5' } },
    })
  )

  eq(answer, {
    text = 'refused: ranges[1].first_line: line 5 reads "local c = 3", not "local e = 5"',
    is_error = true,
  })
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

T['a step']['is refused for a link that resolves under .git'] = function()
  local token = open_layout('walkthrough-link-dot-git')
  local link = project .. '/src/head.lua'
  vim.uv.fs_unlink(link)
  assert(vim.uv.fs_symlink(project .. '/.git/HEAD', link))

  local answer = walk(token, step_for('src/head.lua'))

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

T['a step']['shows a file of a worktree the tab’s agents reported with announce_work'] = function()
  local token = open_layout('walkthrough-reported')
  local worktree = project .. '-reported'
  git_repo.git(project, { 'worktree', 'add', '--quiet', '-b', 'reported-work', worktree })
  vim.fn.writefile(CODE, worktree .. '/src/extra.lua')
  local taken = child.lua_get(
    [[require('aineo.mcp').receive_work_announcement({
      worktree = ..., label = 'reported', branches = { { name = 'reported-work', base = 'HEAD' } },
    }, select(2, ...))]],
    { worktree, token }
  )
  vim.wait(explained.PATIENCE_MS, function()
    return #child.lua_get(
      'require("aineo.entry.registry").tab_list[1].homes.changes.reported_worktree_tops()'
    ) > 0
  end, 20)

  local answer = walk(token, step_for('src/code.lua', { file = worktree .. '/src/extra.lua' }))

  eq(taken, true)
  eq(
    child.lua_get(
      'require("aineo.entry.registry").tab_list[1].homes.changes.reported_worktree_tops()'
    ),
    { vim.uv.fs_realpath(worktree) }
  )
  eq(answer.is_error, false)
  eq(bands_by_file(), { [worktree .. '/src/extra.lua'] = { 2, 5 } })
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

T['a step while the user types in the middle window'] = MiniTest.new_set()

--- Moves the cursor of the child to the window that shows `file`, a file of
--- the project, and types `keys` there (`i` or `R`).
---
---@param file string
---@param keys string
local function type_in_the_window_of(file, keys)
  child.lua(
    [[vim.api.nvim_set_current_win(vim.fn.bufwinid(vim.fn.bufnr(...)))]],
    { project .. '/' .. file }
  )
  child.type_keys(keys)
end

--- Waits until the child shows bands in the buffer of `file`, a file of the
--- project, or the time a case waits is over.
---
---@param file string
local function wait_for_bands_in(file)
  vim.wait(explained.PATIENCE_MS, function()
    return bands_by_file()[file] ~= nil
  end, 20)
end

--- The name, from the project, of the file the child's current window shows.
---
---@return string
local function current_file()
  return child.lua_get([[vim.api.nvim_buf_get_name(0)]]):sub(#project + 2)
end

local HELD_WORDS = 'The user is typing in the middle window: step 2/3, "The values" shows once they'
  .. ' leave Insert mode. Show the next step only when the user asks to move on.'

T['a step while the user types in the middle window']['is held in Insert mode, and shown once they leave it'] = function()
  local token = open_layout('walkthrough-held')
  walk(token, step_for('src/code.lua'))
  type_in_the_window_of('src/code.lua', 'i')

  local answer = walk(token, step_for('src/other.lua', { step = 2 }))
  local while_typing = { bands_by_file(), current_file(), child.fn.mode() }
  child.type_keys('<Esc>')
  wait_for_bands_in('src/other.lua')

  eq(answer, { text = HELD_WORDS, is_error = false })
  eq(while_typing, { { ['src/code.lua'] = { 2, 5 } }, 'src/code.lua', 'i' })
  eq(bands_by_file(), { ['src/other.lua'] = { 2, 5 } })
end

T['a step while the user types in the middle window']['is shown when they leave Insert mode with CTRL-C, which fires no InsertLeave'] = function()
  local token = open_layout('walkthrough-held-ctrl-c')
  walk(token, step_for('src/code.lua'))
  type_in_the_window_of('src/code.lua', 'i')
  walk(token, step_for('src/other.lua', { step = 2 }))

  child.type_keys('<C-c>')
  wait_for_bands_in('src/other.lua')

  eq(bands_by_file(), { ['src/other.lua'] = { 2, 5 } })
end

T['a step while the user types in the middle window']['is held while a command of Insert mode runs from Normal mode'] = function()
  local token = open_layout('walkthrough-held-ctrl-o')
  walk(token, step_for('src/code.lua'))
  type_in_the_window_of('src/code.lua', 'i<C-o>')

  walk(token, step_for('src/other.lua', { step = 2 }))
  local while_pending = { bands_by_file(), current_file() }
  child.type_keys('l<Esc>')
  wait_for_bands_in('src/other.lua')

  eq(while_pending, { { ['src/code.lua'] = { 2, 5 } }, 'src/code.lua' })
  eq(bands_by_file(), { ['src/other.lua'] = { 2, 5 } })
end

T['a step while the user types in the middle window']['one held is dropped by a step shown, which it must not replace later'] = function()
  local token = open_layout('walkthrough-held-left-over')
  walk(token, step_for('src/code.lua'))
  type_in_the_window_of('src/code.lua', 'i')
  walk(token, step_for('src/other.lua', { step = 2 }))
  child.cmd('Aineo input')
  child.api.nvim_input('i')
  walk(
    token,
    step_for('src/long.lua', { step = 3, ranges = { { start = 10, ['end'] = 10, text = 'Ten.' } } })
  )

  child.type_keys('<Esc>')
  vim.wait(500)

  eq(bands_by_file(), { ['src/long.lua'] = { 10 } })
end

T['a step while the user types in the middle window']['is held in Replace mode too'] = function()
  local token = open_layout('walkthrough-held-replace')
  walk(token, step_for('src/code.lua'))
  type_in_the_window_of('src/code.lua', 'R')

  walk(token, step_for('src/other.lua', { step = 2 }))
  local while_typing = bands_by_file()
  child.type_keys('<Esc>')
  wait_for_bands_in('src/other.lua')

  eq(while_typing, { ['src/code.lua'] = { 2, 5 } })
  eq(bands_by_file(), { ['src/other.lua'] = { 2, 5 } })
end

T['a step while the user types in the middle window']['a newer step replaces the one held'] = function()
  local token = open_layout('walkthrough-held-newer')
  walk(token, step_for('src/code.lua'))
  type_in_the_window_of('src/code.lua', 'i')
  walk(token, step_for('src/other.lua', { step = 2 }))
  child.type_keys('<Esc>')
  wait_for_bands_in('src/other.lua')
  type_in_the_window_of('src/other.lua', 'i')
  walk(
    token,
    step_for('src/other.lua', { step = 3, ranges = { { start = 4, ['end'] = 4, text = 'Four.' } } })
  )
  walk(
    token,
    step_for('src/long.lua', { step = 4, ranges = { { start = 9, ['end'] = 9, text = 'Nine.' } } })
  )
  child.type_keys('<Esc>')
  wait_for_bands_in('src/long.lua')

  eq(bands_by_file(), { ['src/long.lua'] = { 9 } })
end

T['a step while the user types in the middle window']['is shown at once when they type in another window'] = function()
  local token = open_layout('walkthrough-not-held')
  walk(token, step_for('src/code.lua'))
  child.cmd('Aineo input')
  child.type_keys('i')

  local answer = walk(token, step_for('src/other.lua', { step = 2 }))

  eq(child.fn.mode(), 'i')
  eq(answer.text:sub(1, 12), 'Showing step')
  eq(bands_by_file(), { ['src/other.lua'] = { 2, 5 } })
end

T['a step while the user types in the middle window']['ending the walkthrough drops the one held'] = function()
  local token = open_layout('walkthrough-held-ended')
  walk(token, step_for('src/code.lua'))
  type_in_the_window_of('src/code.lua', 'i')
  walk(token, step_for('src/other.lua', { step = 2 }))

  walk(token, step_for('src/other.lua', { step = 3, ranges = {} }))
  child.type_keys('<Esc>')
  vim.wait(300)

  eq(bands_by_file(), {})
end

T['a step while the user types in the middle window']['that no longer fits is told and not shown'] = function()
  local token = open_layout('walkthrough-held-unfit')
  walk(token, step_for('src/code.lua'))
  type_in_the_window_of('src/code.lua', 'i')
  walk(token, step_for('src/other.lua', { step = 2 }))
  vim.fn.writefile({ 'a', 'b' }, project .. '/src/other.lua')
  child.lua('_G.entry_test_messages = {}')

  child.type_keys('<Esc>')
  vim.wait(explained.PATIENCE_MS, function()
    return #entry.messages(child) > 0
  end, 20)
  vim.fn.writefile(CODE, project .. '/src/other.lua')

  eq(entry.messages(child), {
    {
      message = 'aineo: the walkthrough step held while you typed is not shown: ranges[1]: lines 2-3 are outside the file, which has 2 lines',
      level = vim.log.levels.INFO,
    },
  })
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

T['a step refused for lack of room leaves the turn open for a corrected call in it'] = function()
  local token = open_layout('walkthrough-no-room-turn')
  be_busy(true)
  child.lua([[
    local layout = require('aineo.entry.registry').tab_list[1].homes.layout
    _G.show_file_before = layout.show_file
    layout.show_file = function() return nil end
  ]])
  local refused = walk(token, step_for('src/code.lua'))
  child.lua(
    [[require('aineo.entry.registry').tab_list[1].homes.layout.show_file = _G.show_file_before]]
  )

  local corrected = walk(token, step_for('src/code.lua'))

  eq(refused.text, 'refused: the middle column has no room for the file')
  eq(corrected.is_error, false)
  eq(bands_by_file(), { ['src/code.lua'] = { 2, 5 } })
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

T['a key while the agent works']['\\vc clears the bands and drops the message waiting, which would bring the walkthrough back'] = function()
  local token = open_layout('walkthrough-wait-clean')
  show_a_step(token)
  be_busy(true)
  entry.press(child, '\\vn')

  entry.press(child, '\\vc')
  be_busy(false)
  vim.wait(300)

  eq(bands_by_file(), {})
  eq(send.writes(child), {})
end

T['a key while the agent works']['an end call of the agent drops the message waiting too'] = function()
  local token = open_layout('walkthrough-wait-agent-end')
  show_a_step(token)
  be_busy(true)
  entry.press(child, '\\vn')

  walk(token, step_for('src/code.lua', { step = 2, ranges = {} }))
  be_busy(false)
  vim.wait(300)

  eq(send.writes(child), {})
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

T['a key after a message was sent'] = MiniTest.new_set()

T['a key after a message was sent']['waits until the agent has answered, though it is not seen working yet'] = function()
  local token = open_layout('walkthrough-key-twice')
  show_a_step(token)
  entry.press(child, '\\vn')
  child.lua('_G.entry_test_messages = {}')

  entry.press(child, '\\vp')
  local before_the_answer = send.writes(child)
  be_busy(true)
  be_busy(false)

  eq(before_the_answer, { paste('Next walkthrough step') })
  eq(writes_after_waiting_for(2), {
    paste('Next walkthrough step'),
    paste('Previous walkthrough step'),
  })
  eq(entry.messages(child), {
    {
      message = 'aineo: the agent has not answered yet: "Previous walkthrough step" goes when its turn ends',
      level = vim.log.levels.INFO,
    },
  })
end

T['a key after a message was sent']['goes after 10 s when the agent is never seen working, as with the busy title off'] = function()
  local token = open_layout('walkthrough-key-ten-seconds')
  show_a_step(token)
  entry.press(child, '\\vn')
  entry.press(child, '\\vp')
  local before_the_bound = send.writes(child)

  vim.wait(15000, function()
    return #send.writes(child) >= 2
  end, 50)

  eq(before_the_bound, { paste('Next walkthrough step') })
  eq(send.writes(child), {
    paste('Next walkthrough step'),
    paste('Previous walkthrough step'),
  })
end

T['a key after a message was sent']['stays held after 10 s while the agent works, and goes when its turn ends'] = function()
  local token = open_layout('walkthrough-key-ten-seconds-busy')
  show_a_step(token)
  entry.press(child, '\\vn')
  entry.press(child, '\\vp')
  be_busy(true)

  vim.wait(11500)
  local while_working = send.writes(child)
  be_busy(false)

  eq(while_working, { paste('Next walkthrough step') })
  eq(writes_after_waiting_for(2), {
    paste('Next walkthrough step'),
    paste('Previous walkthrough step'),
  })
end

T['a key after a message was sent']['is replaced by the key pressed after it, so that one message waits'] = function()
  local token = open_layout('walkthrough-key-thrice')
  show_a_step(token)
  entry.press(child, '\\vn')
  entry.press(child, '\\vp')
  entry.press(child, '\\vq')

  be_busy(true)
  be_busy(false)

  eq(writes_after_waiting_for(2), {
    paste('Next walkthrough step'),
    paste('End the walkthrough'),
  })
  vim.wait(300)
  eq(#send.writes(child), 2)
end

T['a key after a message was sent']['goes when a step is shown, the agent not being seen working'] = function()
  local token = open_layout('walkthrough-key-step-shown')
  show_a_step(token)
  entry.press(child, '\\vn')
  entry.press(child, '\\vp')

  walk(token, step_for('src/other.lua', { step = 2 }))

  eq(writes_after_waiting_for(2), {
    paste('Next walkthrough step'),
    paste('Previous walkthrough step'),
  })
end

T['a key after a message was sent']['stays held when a step is shown while the agent works, until its turn ends'] = function()
  local token = open_layout('walkthrough-key-step-while-busy')
  show_a_step(token)
  be_busy(true)
  entry.press(child, '\\vn')

  walk(token, step_for('src/other.lua', { step = 2 }))
  local while_busy = send.writes(child)
  be_busy(false)

  eq(while_busy, {})
  eq(writes_after_waiting_for(1), { paste('Next walkthrough step') })
end

T['a key after a message was sent']['is sent at once once a step was shown and no key waits'] = function()
  local token = open_layout('walkthrough-key-after-step')
  show_a_step(token)
  entry.press(child, '\\vn')
  walk(token, step_for('src/other.lua', { step = 2 }))

  entry.press(child, '\\vp')

  eq(writes_after_waiting_for(2), {
    paste('Next walkthrough step'),
    paste('Previous walkthrough step'),
  })
end

T['a key after a message was sent']['is sent at once once the turn has ended and no key waits'] = function()
  local token = open_layout('walkthrough-key-after-turn')
  show_a_step(token)
  entry.press(child, '\\vn')
  be_busy(true)
  be_busy(false)

  entry.press(child, '\\vp')

  eq(writes_after_waiting_for(2), {
    paste('Next walkthrough step'),
    paste('Previous walkthrough step'),
  })
end

T['a walkthrough and a session switch'] = MiniTest.new_set()

T['a walkthrough and a session switch']['ends with the switch: its bands are cleared and no message waits'] = function()
  child.lua('vim.env.XDG_STATE_HOME = ...', { fixture.directory('walkthrough-switch') })
  local fake = claude_session.fake('walkthrough-switch', 'ready', { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  claude_session.wait_for_status(child, 'ready')
  vim.wait(explained.PATIENCE_MS, function()
    return child.lua_get([[(pcall(vim.api.nvim_get_autocmds, { group = 'aineo.editors' }))]])
  end, 20)
  local token = claude_session.start_token(fake, 1)
  show_a_step(token)
  be_busy(true)
  entry.press(child, '\\vn')

  claude_session.press_keys(child, terminal_buffer(), '/clear\r')
  vim.wait(explained.PATIENCE_MS, function()
    return next(bands_by_file()) == nil
  end, 20)
  be_busy(false)
  vim.wait(300)

  eq(bands_by_file(), {})
  eq(
    vim.tbl_filter(function(bytes)
      return bytes:find('Next walkthrough step', 1, true) ~= nil
    end, send.writes(child)),
    {}
  )
end

T['a message waiting when its session ends'] = MiniTest.new_set()

T['a message waiting when its session ends']['is dropped with one notice, and raises no error'] = function()
  local token = open_layout('walkthrough-terminal-gone')
  show_a_step(token)
  be_busy(true)
  entry.press(child, '\\vn')
  child.lua('_G.entry_test_messages = {}')

  child.lua('vim.api.nvim_buf_delete(..., { force = true })', { terminal_buffer() })
  vim.wait(explained.PATIENCE_MS, function()
    return #entry.messages(child) > 0
  end, 20)

  eq(entry.messages(child), {
    {
      message = 'aineo: "Next walkthrough step" was not sent: the session of this tab has ended',
      level = vim.log.levels.INFO,
    },
  })
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
