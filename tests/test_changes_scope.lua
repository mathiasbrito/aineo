local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- What `s` asks the picker for.
local PROMPT = 'Show alone in the changes pane'

--- The Lua that defines, in the child, `_G.start_copy(key, directory)`: it
--- makes the changes home `key` names — the module's own for `'module'`, a
--- copy of its own (`new()`) for any other — in `_G.homes[key]`, begins its
--- session for `directory`, and shows its two buffers in a tab page of its
--- own: the files buffer in the tab's window, the commits buffer in a window
--- below it. Its pane's buffers are in `_G.panes[key]`. `vim.ui.select` is
--- replaced by a picker that keeps every request it is given in
--- `_G.pickers`, to be answered by `_G.choose()`, and `vim.notify` by one
--- that keeps every message in `_G.messages`. Every buffer the home is asked
--- to show in the middle column is kept in `_G.shown_diffs`.
local COPIES = [[
  _G.homes, _G.panes, _G.pickers, _G.messages, _G.shown_diffs = {}, {}, {}, {}, {}
  vim.ui.select = function(items, options, on_choice)
    table.insert(_G.pickers, { items = items, options = options, on_choice = on_choice })
  end
  vim.notify = function(message, level)
    table.insert(_G.messages, { message = message, level = level })
  end
  _G.choose = function(position)
    local request = _G.pickers[#_G.pickers]
    request.on_choice(position and request.items[position] or nil)
  end
  _G.start_copy = function(key, directory, working_branch)
    local changes = require('aineo.changes')
    local home = key == 'module' and changes or changes.new()
    _G.homes[key] = home
    home.begin_session({
      directory = directory,
      working_branch = working_branch,
      show_diff = function(diff)
        table.insert(_G.shown_diffs, diff)
        local showing = vim.fn.bufwinid(diff)
        if showing ~= -1 then
          return showing
        end
        return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
      end,
    })
    vim.cmd('tabnew')
    _G.panes[key] = home.pane_buffers()
    vim.api.nvim_win_set_buf(0, _G.panes[key].files)
    vim.api.nvim_open_win(_G.panes[key].commits, false, { split = 'below' })
  end
]]

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
      child.lua(COPIES)
    end,
    post_once = child.stop,
  },
})

--- Makes the changes home `key` names (`COPIES`) in the child for
--- `directory`.
---
---@param key string
---@param directory string
---@param working_branch? string
local function start_copy(key, directory, working_branch)
  child.lua('_G.start_copy(...)', { key, directory, working_branch })
end

--- The lines of the buffer `which` (`files` or `commits`) of the pane of the
--- changes home `key` names, in the child.
---
---@param key string
---@param which 'files'|'commits'
---@return string[]
local function pane_lines(key, which)
  return child.lua_get(
    'vim.api.nvim_buf_get_lines(_G.panes[...][select(2, ...)], 0, -1, true)',
    { key, which }
  )
end

--- Waits until the buffer `which` of the pane of the changes home `key`
--- names holds `expected`, at most `git_repo.PATIENCE_MS`, and asserts that
--- it does.
---
---@param key string
---@param which 'files'|'commits'
---@param expected string[]
local function expect_pane_lines(key, which, expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(pane_lines(key, which), expected)
  end, 10)
  eq(pane_lines(key, which), expected)
end

--- Makes the window `which` (`files` or `commits`) of the pane of the
--- changes home `key` names the current window.
---
---@param key string
---@param which 'files'|'commits'
local function enter_window_of(key, which)
  child.lua(
    'vim.api.nvim_set_current_win(vim.fn.win_findbuf(_G.panes[...][select(2, ...)])[1])',
    { key, which }
  )
end

--- Makes the directory `name` beside the repository at `top` a worktree of
--- it on the new branch `branch`, and returns the worktree's top level.
---
---@param top string
---@param name string
---@param branch string
---@return string worktree
local function add_worktree(top, name, branch)
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), name)
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', branch, worktree })
  return worktree
end

--- Makes the directory `name` beside the repository at `top` a worktree of
--- it on a detached `HEAD`, and returns the worktree's top level.
---
---@param top string
---@param name string
---@return string worktree
local function add_detached_worktree(top, name)
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), name)
  git_repo.git(top, { 'worktree', 'add', '--quiet', '--detach', worktree })
  return worktree
end

--- Writes `text` as the only line of `path` under `top` and commits that
--- file alone as `subject`; returns the commit's full id.
---
---@param top string
---@param path string
---@param text string
---@param subject string
---@return string
local function commit_only(top, path, text, subject)
  git_repo.write(top, path, { text })
  git_repo.git(top, { 'add', '--', path })
  git_repo.git(top, { 'commit', '--quiet', '--message', subject })
  return git_repo.git(top, { 'rev-parse', 'HEAD' })
end

--- The commits window's line for `commit`, a full id, with `subject`.
---
---@param commit string
---@param subject string
---@return string
local function commit_line(commit, subject)
  return commit:sub(1, 7) .. ' ' .. subject
end

--- How many pickers the child was asked for and messages it was told.
---
---@return integer
local function answers_to_s()
  return child.lua_get('#_G.pickers + #_G.messages')
end

--- Waits until `s` was answered, as `answers_to_s()` counts more than
--- `before`: a picker opened or the user told why none is, at most
--- `git_repo.PATIENCE_MS`.
---
---@param before integer
local function wait_for_the_answer_to_s(before)
  vim.wait(git_repo.PATIENCE_MS, function()
    return answers_to_s() > before
  end, 10)
end

--- Presses `s` in the window `which` of the pane of the changes home `key`
--- names.
---
---@param key string
---@param which 'files'|'commits'
local function press_s_without_waiting(key, which)
  enter_window_of(key, which)
  child.lua("pcall(vim.api.nvim_feedkeys, 's', 'mx', false)")
end

--- Presses `s` in the window `which` of the pane of the changes home `key`
--- names, and waits until it was answered: the lists it offers are read off
--- the main loop.
---
---@param key string
---@param which 'files'|'commits'
local function press_s(key, which)
  local before = answers_to_s()
  press_s_without_waiting(key, which)
  wait_for_the_answer_to_s(before)
end

--- Answers the last picker the child was asked for with its item at
--- `position`, or with none when not given, and returns whether answering
--- raised no error.
---
---@param position? integer
---@return boolean answered
local function answer_picker(position)
  return child.lua_get('(pcall(_G.choose, ...))', { position })
end

--- What every picker the child was asked for offered: its prompt and the
--- text each item shows.
---
---@return { prompt: string, texts: string[] }[]
local function offered()
  return child.lua_get([[vim.tbl_map(function(request)
    return {
      prompt = request.options.prompt,
      texts = vim.tbl_map(request.options.format_item, request.items),
    }
  end, _G.pickers)]])
end

--- The colours the buffer `which` of the pane of the changes home `key`
--- names shows on its line `line`: each as its first column, its end column
--- and its group.
---
---@param key string
---@param which 'files'|'commits'
---@param line integer
---@return { [1]: integer, [2]: integer, [3]: string }[]
local function colours_on(key, which, line)
  return child.lua_get(
    [[(function(key, which, line)
      local buffer = _G.panes[key][which]
      local marks = vim.api.nvim_buf_get_extmarks(buffer, -1, { line - 1, 0 }, { line - 1, -1 }, { details = true })
      return vim.tbl_map(function(mark)
        return { mark[3], mark[4].end_col, mark[4].hl_group }
      end, marks)
    end)(...)]],
    { key, which, line }
  )
end

--- Makes the repository `name` a session's worth of work: a remote whose
--- `dev` holds a commit the repository has fetched and not merged (what
--- landed), the worktree `agent` of two commits (`Agent one`, then `Agent
--- two`), and the worktree `other` of one (`Other one`). Returns the top
--- level, the worktrees' and the commits' ids.
---
---@param name string
---@return { top: string, agent: string, other: string, landed: string, agent_one: string, agent_two: string, other_one: string }
local function create_work(name)
  local top, _, clone = git_repo.create_with_remote(name, { ['notes.txt'] = { 'one' } })
  local landed = git_repo.land_in_remote(clone, { ['landed.txt'] = { 'landed' } }, 'Landed')
  git_repo.fetch_remote(top)
  local agent = add_worktree(top, 'agent', 'agent')
  local agent_one = commit_only(agent, 'notes.txt', 'agent', 'Agent one')
  local agent_two = commit_only(agent, 'agent.txt', 'agent', 'Agent two')
  local other = add_worktree(top, 'other', 'other')
  local other_one = commit_only(other, 'other.txt', 'other', 'Other one')
  return {
    top = top,
    agent = agent,
    other = other,
    landed = landed,
    agent_one = agent_one,
    agent_two = agent_two,
    other_one = other_one,
  }
end

--- The commits window's lines for the work `create_work()` made and `own`,
--- a commit of the session's own, in the default view.
---
---@param work table
---@param own string
---@return string[]
local function default_view_of(work, own)
  return {
    'Uncommitted',
    'Session work',
    own and commit_line(own, 'Own') or 'No commits on this session',
    'Landed in origin/dev',
    commit_line(work.landed, 'Landed'),
    'Worktree agent (agent)',
    commit_line(work.agent_two, 'Agent two'),
    commit_line(work.agent_one, 'Agent one'),
    'Worktree other (other)',
    commit_line(work.other_one, 'Other one'),
  }
end

--- Starts the module's home on the work `create_work()` made, waits until
--- its commits window lists `default_view_of()` it, with a commit of the
--- session's own, and returns the work.
---
---@param name string
---@return table work
local function start_on_work(name)
  local work = create_work(name)
  start_copy('module', work.top, 'origin/dev')
  expect_pane_lines('module', 'commits', default_view_of(work))
  local own = commit_only(work.top, 'own.txt', 'own', 'Own')
  child.lua('_G.homes.module.refresh_shown_pane()')
  expect_pane_lines('module', 'commits', default_view_of(work, own))
  work.own = own
  return work
end

--- The Lua that counts, in the child, every call made to the git home but
--- its watch, and every answer once its caller's `done` has run, in
--- `_G.git_calls`.
local COUNT_GIT_CALLS = [[
  local git = require('aineo.git')
  _G.git_calls = { asked = 0, answered = 0 }
  for name, operation in pairs(git) do
    if type(operation) == 'function' and name ~= 'watch_repository' then
      git[name] = function(...)
        _G.git_calls.asked = _G.git_calls.asked + 1
        local arguments = { ... }
        for index = 1, select('#', ...) do
          if type(arguments[index]) == 'function' then
            local done = arguments[index]
            arguments[index] = function(...)
              done(...)
              _G.git_calls.answered = _G.git_calls.answered + 1
            end
            break
          end
        end
        return operation(unpack(arguments, 1, select('#', ...)))
      end
    end
  end
]]

--- Waits until the git home has answered every call it was given since
--- `COUNT_GIT_CALLS`, and at least one.
local function wait_for_the_reads()
  git_repo.wait_until('every read answered', function()
    return child.lua_get(
      '_G.git_calls.answered > 0 and _G.git_calls.asked == _G.git_calls.answered'
    )
  end)
end

T['s'] = MiniTest.new_set()

T['s']['offers the other worktrees, each marked and named by folder and branch, in the order they are listed'] = function()
  local top = git_repo.create('changesscope-offer', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent', 'feature/x')
  add_detached_worktree(top, 'loose')
  start_copy('module', top)
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (feature/x)',
    'No commits in this worktree',
    'Worktree loose (detached)',
    'No commits in this worktree',
  })

  press_s('module', 'commits')

  eq(offered(), {
    { prompt = PROMPT, texts = { '[worktree] agent (feature/x)', '[worktree] loose (detached)' } },
  })
end

T['s']['offers the same list from the files window'] = function()
  local top = git_repo.create('changesscope-offer-files', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent', 'agent')
  start_copy('module', top)
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })

  press_s('module', 'files')

  eq(offered(), { { prompt = PROMPT, texts = { '[worktree] agent (agent)' } } })
end

T['s']['stays Vim’s own in every other buffer'] = function()
  local top = git_repo.create('changesscope-vim-s', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent', 'agent')
  start_copy('module', top)
  child.cmd('tabnew')
  child.lua("vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'abc' })")

  child.type_keys('sX<Esc>')

  eq({ child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), offered() }, { { 'Xbc' }, {} })
end

T['s']['is mapped again in a pane buffer made anew'] = function()
  local top = git_repo.create('changesscope-made-anew', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent', 'agent')
  start_copy('module', top)
  child.lua('vim.api.nvim_buf_delete(_G.panes.module.commits, { force = true })')
  child.lua("_G.panes.module = require('aineo.changes').pane_buffers()")
  child.lua('vim.api.nvim_win_set_buf(0, _G.panes.module.commits)')
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })

  child.lua("pcall(vim.api.nvim_feedkeys, 's', 'mx', false)")

  wait_for_the_answer_to_s(0)
  eq(#offered(), 1)
end

T['picking'] = MiniTest.new_set()

T['picking']['a worktree shows it alone: its heading, in the colour of filters, then its commits, nothing else'] = function()
  local work = start_on_work('changesscope-pick')
  press_s('module', 'commits')

  child.lua('_G.choose(1)')

  expect_pane_lines('module', 'commits', {
    'Worktree agent (agent)',
    commit_line(work.agent_two, 'Agent two'),
    commit_line(work.agent_one, 'Agent one'),
  })
  eq(colours_on('module', 'commits', 1), { { 0, #'Worktree agent (agent)', 'AineoChangesFilter' } })
end

T['picking']['a worktree chooses its whole change, which the files window lists, the cursor on the first line'] = function()
  start_on_work('changesscope-pick-files')
  press_s('module', 'commits')

  child.lua('_G.choose(1)')

  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
  eq(
    child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.bufwinid(_G.panes.module.commits))'),
    { 1, 0 }
  )
end

T['picking']['nothing, by dismissing the picker, changes nothing'] = function()
  local work = start_on_work('changesscope-dismiss')
  press_s('module', 'commits')

  eq(answer_picker(nil), true)

  expect_pane_lines('module', 'commits', default_view_of(work, work.own))
  expect_pane_lines('module', 'files', { 'Files in: Session work', '  A own.txt' })
end

T['picking']['shows the cursor on a commit of the scope as the files of that commit, read in the worktree'] = function()
  local work = start_on_work('changesscope-commit')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })

  enter_window_of('module', 'commits')
  child.type_keys('2G')

  expect_pane_lines('module', 'files', {
    'Files in: ' .. commit_line(work.agent_two, 'Agent two') .. ' (worktree agent)',
    '  A agent.txt',
  })
end

T['picking']['under a scope offers the same list, and another worktree replaces the scope'] = function()
  local work = start_on_work('changesscope-replace')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })

  press_s('module', 'files')
  child.lua('_G.choose(2)')

  expect_pane_lines('module', 'commits', {
    'Worktree other (other)',
    commit_line(work.other_one, 'Other one'),
  })
  expect_pane_lines('module', 'files', { 'Files in: Worktree other (other)', '  A other.txt' })
  eq(offered()[2], offered()[1])
end

--- The notifications the child was given, each as its words and level.
---
---@return { message: string, level: integer }[]
local function messages_told()
  return child.lua_get('_G.messages')
end

T['s']['tells once that there is no other worktree to show alone, and opens no picker'] = function()
  local top = git_repo.create('changesscope-none', { ['notes.txt'] = { 'one' } })
  child.lua(COUNT_GIT_CALLS)
  start_copy('module', top)
  wait_for_the_reads()
  expect_pane_lines(
    'module',
    'commits',
    { 'Uncommitted', 'Session work', 'No commits on this session' }
  )

  press_s('module', 'commits')

  eq({ offered(), messages_told() }, {
    {},
    {
      { message = 'aineo: no other worktree or branch to show alone', level = vim.log.levels.INFO },
    },
  })
end

T['s']['tells that the list is still being read before the other worktrees were read'] = function()
  local top = git_repo.create('changesscope-unread', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent', 'agent')
  child.lua("require('aineo.git').list_worktrees = function() end")
  start_copy('module', top)
  expect_pane_lines(
    'module',
    'commits',
    { 'Uncommitted', 'Session work', 'No commits on this session' }
  )

  press_s('module', 'commits')

  eq({ offered(), messages_told() }, {
    {},
    { { message = 'aineo is reading the repository', level = vim.log.levels.INFO } },
  })
end

T['s']['opens its picker at once while a global map starts with s'] = function()
  local top = git_repo.create('changesscope-nowait', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent', 'agent')
  start_copy('module', top)
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })
  child.lua("vim.o.timeoutlen = 20000; vim.keymap.set('n', 'sa', function() end)")
  enter_window_of('module', 'commits')

  child.api.nvim_input('s')

  vim.wait(3000, function()
    return not child.is_blocked()
  end, 20)
  eq(child.is_blocked(), false)
  wait_for_the_answer_to_s(0)
  eq(#offered(), 1)
end

T['s']['ignores an answer of the picker that is not an item it offered'] = MiniTest.new_set({
  parametrize = { { 1 }, { '[worktree] agent (agent)' }, { {} }, { { top = 42 } } },
})

T['s']['ignores an answer of the picker that is not an item it offered']['answer'] = function(
  answer
)
  local top = git_repo.create('changesscope-bad-answer', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent', 'agent')
  start_copy('module', top)
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })
  press_s('module', 'commits')

  local answered = child.lua_get('(pcall(_G.pickers[#_G.pickers].on_choice, ...))', { answer })

  eq({ answered, messages_told() }, { true, {} })
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })
end

T['s']['tells that the other worktrees could not be listed, in the words the commits window shows, and opens no picker'] = function()
  local top = git_repo.create('changesscope-unlisted', { ['notes.txt'] = { 'one' } })
  child.lua([[require('aineo.git').list_worktrees = function(_, done)
    done({ reason = 'failed', message = 'broken' }, nil)
  end]])
  start_copy('module', top)
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'The other worktrees could not be listed: broken',
  })

  press_s('module', 'commits')

  eq({ offered(), messages_told() }, {
    {},
    {
      {
        message = 'aineo: The other worktrees could not be listed: broken',
        level = vim.log.levels.INFO,
      },
    },
  })
end

T['s']['tells why, in the words the windows show, while the session has no repository'] = function()
  local directory = git_repo.directory('changesscope-no-repository')
  child.lua([[require('aineo.git').find_repository = function(_, done)
    done({ reason = 'failed', message = 'boom' }, nil)
  end]])
  start_copy('module', directory)
  expect_pane_lines('module', 'commits', { 'The last refresh failed: boom' })

  press_s('module', 'commits')

  eq({ offered(), messages_told() }, {
    {},
    { { message = 'aineo: The last refresh failed: boom', level = vim.log.levels.INFO } },
  })
end

T['s']['tells that the repository is being read, while it is looked for'] = function()
  local directory = git_repo.directory('changesscope-reading')
  child.lua("require('aineo.git').find_repository = function() end")
  start_copy('module', directory)
  expect_pane_lines('module', 'commits', { 'aineo is reading the repository' })

  press_s('module', 'commits')

  eq({ offered(), messages_told() }, {
    {},
    { { message = 'aineo is reading the repository', level = vim.log.levels.INFO } },
  })
end

T['s']['tells that the repository is being read, before the session has begun'] = function()
  child.lua([[
    _G.panes.module = require('aineo.changes').pane_buffers()
    vim.api.nvim_win_set_buf(0, _G.panes.module.commits)
  ]])

  press_s('module', 'commits')

  eq({ offered(), messages_told() }, {
    {},
    { { message = 'aineo is reading the repository', level = vim.log.levels.INFO } },
  })
end

T['s']['tells a picker that raises from a Lua file without the position, on its first line'] = function()
  local top = git_repo.create('changesscope-raises-position', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent', 'agent')
  start_copy('module', top)
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })
  child.lua(
    "vim.ui.select = function() error('picker/init.lua:12: the menu failed\\nstack', 0) end"
  )

  press_s('module', 'commits')

  eq(messages_told(), { { message = 'aineo: the menu failed', level = vim.log.levels.ERROR } })
end

T['s']['tells once, as an error, a picker that raises'] = function()
  local top = git_repo.create('changesscope-raises', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent', 'agent')
  start_copy('module', top)
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })
  child.lua("vim.ui.select = function() error('the menu failed', 0) end")

  press_s('module', 'commits')

  eq(messages_told(), { { message = 'aineo: the menu failed', level = vim.log.levels.ERROR } })
end

--- Switches the changes home `key` names between its default view and its
--- focused view, as `\g` does when the pane shows.
---
---@param key string
local function toggle(key)
  child.lua('_G.homes[...].toggle_focused_view()', { key })
end

--- The cursor of the window showing the commits buffer of the pane of the
--- changes home `key` names: its line, 1-based, and its byte column.
---
---@param key string
---@return integer[]
local function commits_cursor(key)
  return child.lua_get(
    'vim.api.nvim_win_get_cursor(vim.fn.win_findbuf(_G.panes[...].commits)[1])',
    { key }
  )
end

T['toggling'] = MiniTest.new_set()

T['toggling']['from the scope view shows the default view, the choice and the cursor kept on the worktree’s heading'] = function()
  local work = start_on_work('changesscope-toggle-default')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })

  toggle('module')

  expect_pane_lines('module', 'commits', default_view_of(work, work.own))
  eq(commits_cursor('module'), { 6, 0 })
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
end

T['toggling']['from the default view shows the scope view again, the scope kept'] = function()
  local work = start_on_work('changesscope-toggle-back')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  toggle('module')
  expect_pane_lines('module', 'commits', default_view_of(work, work.own))

  toggle('module')

  expect_pane_lines('module', 'commits', {
    'Worktree agent (agent)',
    commit_line(work.agent_two, 'Agent two'),
    commit_line(work.agent_one, 'Agent one'),
  })
  eq(commits_cursor('module'), { 1, 0 })
end

T['toggling']['keeps a commit of the scope chosen, the cursor on its line in the default view'] = function()
  local work = start_on_work('changesscope-toggle-commit')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  enter_window_of('module', 'commits')
  child.type_keys('3G')
  expect_pane_lines('module', 'files', {
    'Files in: ' .. commit_line(work.agent_one, 'Agent one') .. ' (worktree agent)',
    '  M notes.txt',
  })

  toggle('module')

  expect_pane_lines('module', 'commits', default_view_of(work, work.own))
  eq(commits_cursor('module'), { 8, 0 })
  expect_pane_lines('module', 'files', {
    'Files in: ' .. commit_line(work.agent_one, 'Agent one') .. ' (worktree agent)',
    '  M notes.txt',
  })
end

T['toggling']['puts the cursor on the choice, wherever it was, as the default view returns'] = function()
  local work = start_on_work('changesscope-toggle-cursor')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
  enter_window_of('module', 'commits')

  child.lua([[
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    _G.homes.module.toggle_focused_view()
  ]])

  eq(pane_lines('module', 'commits'), default_view_of(work, work.own))
  eq(commits_cursor('module'), { 6, 0 })
end

T['toggling']['with no scope reads both lists again, though nothing changed'] = function()
  local top = git_repo.create('changesscope-toggle-reads-none', { ['notes.txt'] = { 'one' } })
  start_copy('module', top)
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Session work', 'No files changed on this session' }
  )
  child.lua(COUNT_GIT_CALLS)

  toggle('module')

  wait_for_the_reads()
end

T['toggling']['with no scope reads the shown pane again, as it did'] = function()
  local top = git_repo.create('changesscope-toggle-none', { ['notes.txt'] = { 'one' } })
  start_copy('module', top)
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Session work', 'No files changed on this session' }
  )
  git_repo.write(top, 'notes.txt', { 'two' })

  toggle('module')

  expect_pane_lines('module', 'files', { 'Files in: Session work', '  M notes.txt' })
end

T['toggling']['while the pane is not shown changes nothing: the view it was left in stays'] = function()
  local work = start_on_work('changesscope-toggle-hidden')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('module', 'commits', {
    'Worktree agent (agent)',
    commit_line(work.agent_two, 'Agent two'),
    commit_line(work.agent_one, 'Agent one'),
  })
  child.lua([[for _, buffer in pairs(_G.panes.module) do
    vim.api.nvim_win_close(vim.fn.win_findbuf(buffer)[1], true)
  end]])

  toggle('module')

  eq(pane_lines('module', 'commits')[1], 'Worktree agent (agent)')
end

T['toggling']['to the scope view chooses the scope’s whole change when the default view’s choice is not listed there'] = function()
  local work = start_on_work('changesscope-toggle-unlisted')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  toggle('module')
  expect_pane_lines('module', 'commits', default_view_of(work, work.own))
  enter_window_of('module', 'commits')
  child.type_keys('1G')
  expect_pane_lines('module', 'files', { 'Files in: Uncommitted', 'No uncommitted changes' })

  toggle('module')

  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
  eq(commits_cursor('module'), { 1, 0 })
end

--- Reads the shown pane of the changes home `key` names again.
---
---@param key string
local function refresh(key)
  child.lua('_G.homes[...].refresh_shown_pane()', { key })
end

--- Removes the worktree at `worktree` from the repository at `top`, as
--- `git worktree remove` does.
---
---@param top string
---@param worktree string
local function remove_worktree(top, worktree)
  git_repo.git(top, { 'worktree', 'remove', '--force', worktree })
end

--- What the user is told when the worktree `agent` is no longer listed.
local AGENT_GONE = 'aineo: Worktree agent (agent) is gone; the changes pane shows the default view'

T['a scope gone'] = MiniTest.new_set()

T['a scope gone']['is cleared at the read that no longer lists its worktree: the default view, Session work chosen, the user told once'] = function()
  local work = start_on_work('changesscope-gone')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
  remove_worktree(work.top, work.agent)

  refresh('module')

  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    commit_line(work.own, 'Own'),
    'Landed in origin/dev',
    commit_line(work.landed, 'Landed'),
    'Worktree other (other)',
    commit_line(work.other_one, 'Other one'),
  })
  expect_pane_lines('module', 'files', { 'Files in: Session work', '  A own.txt' })
  eq(commits_cursor('module'), { 2, 0 })
  refresh('module')
  expect_pane_lines('module', 'files', { 'Files in: Session work', '  A own.txt' })
  eq(messages_told(), { { message = AGENT_GONE, level = vim.log.levels.INFO } })
end

T['a scope gone']['is cleared while hidden too, and a worktree listed again does not bring it back'] = function()
  local work = start_on_work('changesscope-gone-hidden')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  toggle('module')
  expect_pane_lines('module', 'commits', default_view_of(work, work.own))
  remove_worktree(work.top, work.agent)
  refresh('module')
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    commit_line(work.own, 'Own'),
    'Landed in origin/dev',
    commit_line(work.landed, 'Landed'),
    'Worktree other (other)',
    commit_line(work.other_one, 'Other one'),
  })
  git_repo.git(work.top, { 'worktree', 'add', '--quiet', work.agent, 'agent' })
  refresh('module')
  expect_pane_lines('module', 'commits', default_view_of(work, work.own))

  toggle('module')

  expect_pane_lines('module', 'commits', default_view_of(work, work.own))
  eq(messages_told(), { { message = AGENT_GONE, level = vim.log.levels.INFO } })
end

T['a scope gone']['between the picker and the pick tells that the worktree is gone and changes nothing'] = function()
  local work = start_on_work('changesscope-gone-picked')
  press_s('module', 'commits')
  remove_worktree(work.top, work.agent)
  refresh('module')
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    commit_line(work.own, 'Own'),
    'Landed in origin/dev',
    commit_line(work.landed, 'Landed'),
    'Worktree other (other)',
    commit_line(work.other_one, 'Other one'),
  })

  eq(answer_picker(1), true)

  eq(messages_told(), {
    { message = 'aineo: [worktree] agent (agent) is gone', level = vim.log.levels.INFO },
  })
  expect_pane_lines('module', 'files', { 'Files in: Session work', '  A own.txt' })
end

T['a scope’s commit'] = MiniTest.new_set()

T['a scope’s commit']['no longer listed after an amend becomes the scope’s whole change, the cursor on its first line'] = function()
  local work = start_on_work('changesscope-amended')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  enter_window_of('module', 'commits')
  child.type_keys('2G')
  expect_pane_lines('module', 'files', {
    'Files in: ' .. commit_line(work.agent_two, 'Agent two') .. ' (worktree agent)',
    '  A agent.txt',
  })
  git_repo.git(work.agent, { 'commit', '--quiet', '--amend', '--message', 'Amended' })
  local amended = git_repo.git(work.agent, { 'rev-parse', 'HEAD' })

  refresh('module')

  expect_pane_lines('module', 'commits', {
    'Worktree agent (agent)',
    commit_line(amended, 'Amended'),
    commit_line(work.agent_one, 'Agent one'),
  })
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
  eq(commits_cursor('module'), { 1, 0 })
end

--- Tells the changes home `key` names to follow the Claude Code session
--- `id`, kept under the state directory `state`.
---
---@param key string
---@param id string
---@param state string
local function follow(key, id, state)
  child.lua(
    '_G.homes[...].follow_changes_session({ id = select(2, ...), state_directory = select(3, ...) })',
    { key, id, state }
  )
end

--- Two Claude Code session ids.
local SESSION_A = '11111111-1111-4111-8111-111111111111'
local SESSION_B = '22222222-2222-4222-8222-222222222222'

T['following another session'] = MiniTest.new_set()

T['following another session']['keeps a scope picked before the first session was followed'] = function()
  local work = start_on_work('changesscope-first-follow')
  local state = git_repo.directory('changesscope-first-follow-state')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
  child.lua(COUNT_GIT_CALLS)

  follow('module', SESSION_A, state)

  wait_for_the_reads()
  expect_pane_lines('module', 'commits', {
    'Worktree agent (agent)',
    commit_line(work.agent_two, 'Agent two'),
    commit_line(work.agent_one, 'Agent one'),
  })
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
end

T['following another session']['clears the scope, Session work chosen, and tells nothing'] = function()
  local work = start_on_work('changesscope-follow')
  local state = git_repo.directory('changesscope-follow-state')
  follow('module', SESSION_A, state)
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })

  follow('module', SESSION_B, state)

  expect_pane_lines('module', 'commits', default_view_of(work))
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Session work', 'No files changed on this session' }
  )
  eq(commits_cursor('module'), { 2, 0 })
  eq(messages_told(), {})
end

T['a scope'] = MiniTest.new_set()

T['a scope']['shown alone chooses its whole change again when the commits buffer is made anew'] = function()
  local work = start_on_work('changesscope-made-anew-scope')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
  child.lua(COUNT_GIT_CALLS)
  child.lua([[
    vim.api.nvim_buf_delete(_G.panes.module.commits, { force = true })
    _G.panes.module = require('aineo.changes').pane_buffers()
    vim.cmd('botright split')
    vim.api.nvim_win_set_buf(0, _G.panes.module.commits)
  ]])
  wait_for_the_reads()

  expect_pane_lines('module', 'commits', {
    'Worktree agent (agent)',
    commit_line(work.agent_two, 'Agent two'),
    commit_line(work.agent_one, 'Agent one'),
  })
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
  eq(commits_cursor('module'), { 1, 0 })
end

T['a scope']['lists the failure line of its worktree’s read under its heading, with its commits'] = function()
  local work = start_on_work('changesscope-section-failed')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
  child.lua([[local git = require('aineo.git')
    local commits_since = git.commits_since
    git.commits_since = function(repository, base, done, options)
      if vim.endswith(repository.top, '/agent') then
        done({ reason = 'failed', message = 'broken' }, nil)
        return
      end
      return commits_since(repository, base, done, options)
    end]])

  refresh('module')

  expect_pane_lines('module', 'commits', {
    'Worktree agent (agent)',
    'The last refresh failed: broken',
    commit_line(work.agent_two, 'Agent two'),
    commit_line(work.agent_one, 'Agent one'),
  })
end

T['a scope']['leaves out the line saying the session’s own read failed, which the default view shows'] = function()
  local work = start_on_work('changesscope-own-failed')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
  child.lua([[local git = require('aineo.git')
    local commits_since = git.commits_since
    git.commits_since = function(repository, base, done, options)
      if vim.endswith(repository.top, '/agent') or vim.endswith(repository.top, '/other') then
        return commits_since(repository, base, done, options)
      end
      done({ reason = 'failed', message = 'broken' }, nil)
    end]])
  child.lua(COUNT_GIT_CALLS)

  refresh('module')
  wait_for_the_reads()

  expect_pane_lines('module', 'commits', {
    'Worktree agent (agent)',
    commit_line(work.agent_two, 'Agent two'),
    commit_line(work.agent_one, 'Agent one'),
  })
  toggle('module')
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    'The last refresh failed: broken',
    commit_line(work.own, 'Own'),
    'Landed in origin/dev',
    commit_line(work.landed, 'Landed'),
    'Worktree agent (agent)',
    commit_line(work.agent_two, 'Agent two'),
    commit_line(work.agent_one, 'Agent one'),
    'Worktree other (other)',
    commit_line(work.other_one, 'Other one'),
  })
end

T['a scope']['leaves out the line saying the other worktrees could not be listed, which the default view shows'] = function()
  local work = start_on_work('changesscope-list-failed')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
  child.lua([[local git = require('aineo.git')
    git.list_worktrees = function(_, done)
      done({ reason = 'failed', message = 'broken' }, nil)
    end]])

  refresh('module')
  toggle('module')
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    commit_line(work.own, 'Own'),
    'Landed in origin/dev',
    commit_line(work.landed, 'Landed'),
    'The other worktrees could not be listed: broken',
    'Worktree agent (agent)',
    commit_line(work.agent_two, 'Agent two'),
    commit_line(work.agent_one, 'Agent one'),
    'Worktree other (other)',
    commit_line(work.other_one, 'Other one'),
  })

  toggle('module')

  expect_pane_lines('module', 'commits', {
    'Worktree agent (agent)',
    commit_line(work.agent_two, 'Agent two'),
    commit_line(work.agent_one, 'Agent one'),
  })
end

T['a scope']['is a changes home’s own: another tab’s home still shows the default view'] = function()
  local top = git_repo.create('changesscope-homes', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent', 'agent')
  local default = {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'No commits in this worktree',
  }
  start_copy('first', top)
  start_copy('second', top)
  expect_pane_lines('first', 'commits', default)
  expect_pane_lines('second', 'commits', default)

  press_s('first', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('first', 'commits', { 'Worktree agent (agent)', 'No commits in this worktree' })
  child.lua(COUNT_GIT_CALLS)

  refresh('second')
  wait_for_the_reads()

  expect_pane_lines('second', 'commits', default)
  expect_pane_lines(
    'second',
    'files',
    { 'Files in: Session work', 'No files changed on this session' }
  )
end

T['a scope']['leaves the reads as they are: a commit of the editor’s own is listed at once when the default view returns'] = function()
  local work = start_on_work('changesscope-reads')
  press_s('module', 'commits')
  child.lua('_G.choose(1)')
  expect_pane_lines('module', 'files', {
    'Files in: Worktree agent (agent)',
    '  A agent.txt',
    '  M notes.txt',
  })
  child.lua(COUNT_GIT_CALLS)
  local second = commit_only(work.top, 'second.txt', 'second', 'Own two')
  refresh('module')
  wait_for_the_reads()

  toggle('module')

  eq(pane_lines('module', 'commits'), {
    'Uncommitted',
    'Session work',
    commit_line(second, 'Own two'),
    commit_line(work.own, 'Own'),
    'Landed in origin/dev',
    commit_line(work.landed, 'Landed'),
    'Worktree agent (agent)',
    commit_line(work.agent_two, 'Agent two'),
    commit_line(work.agent_one, 'Agent one'),
    'Worktree other (other)',
    commit_line(work.other_one, 'Other one'),
  })
end

--- Commits the files staged in `top` as `subject`, as made at `epoch`
--- seconds after 1970, and returns the commit's full id.
---
---@param top string
---@param subject string
---@param epoch integer
---@return string commit
local function commit_dated(top, subject, epoch)
  local committed = vim
    .system({ 'git', 'commit', '--quiet', '--message', subject }, {
      cwd = top,
      env = vim.tbl_extend('force', git_repo.ENVIRONMENT, {
        GIT_COMMITTER_DATE = ('%d +0000'):format(epoch),
      }),
      text = true,
    })
    :wait()
  assert(committed.code == 0, committed.stderr)
  return git_repo.git(top, { 'rev-parse', 'HEAD' })
end

--- What a commit of `make_branch()` is: a file written and committed, or a
--- file renamed.
---@class ScopeBranchCommit
---@field subject string
---@field path? string the file written with `text`
---@field text? string
---@field rename? string[] the file renamed: from its path, to its path

--- Epoch seconds after every commit the fixtures make as they run, from
--- which the commits of `make_branch()` are dated, so that the order of the
--- branches by their newest commit is the one the case says.
local AFTER_THE_FIXTURES = os.time() + 3600

--- Puts `commits` on the branch `name` in the repository at `top`, dated one
--- second apart from `epoch` on, making the branch from `start`, a commit or
--- a branch, when `start` is given, and taking it as it is when it is not;
--- no worktree has it checked out afterwards. Returns the commits' ids, the
--- first made first.
---
---@param top string
---@param name string
---@param start string|nil
---@param commits ScopeBranchCommit[]
---@param epoch? integer
---@return string[] ids
local function make_branch(top, name, start, commits, epoch)
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), 'making-' .. (name:gsub('%W', '-')))
  if start then
    git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', name, worktree, start })
  else
    git_repo.git(top, { 'worktree', 'add', '--quiet', worktree, name })
  end
  local ids = {}
  for index, commit in ipairs(commits) do
    if commit.rename then
      git_repo.git(worktree, { 'mv', commit.rename[1], commit.rename[2] })
    else
      git_repo.write(worktree, commit.path, { commit.text })
      git_repo.git(worktree, { 'add', '--', commit.path })
    end
    ids[index] = commit_dated(worktree, commit.subject, (epoch or AFTER_THE_FIXTURES) + index)
  end
  git_repo.git(top, { 'worktree', 'remove', '--force', worktree })
  return ids
end

T['branches in s'] = MiniTest.new_set()

T['branches in s']['are offered after the worktrees, each marked, the one with the newest commit first'] = function()
  local work = create_work('changesscope-branches')
  make_branch(
    work.top,
    'feature/x',
    'origin/dev',
    { { path = 'x.txt', text = 'x', subject = 'X' } }
  )
  git_repo.git(work.top, { 'branch', 'idle', 'main' })
  start_copy('module', work.top, 'origin/dev')
  expect_pane_lines('module', 'commits', default_view_of(work))

  press_s('module', 'commits')

  eq(offered(), {
    {
      prompt = PROMPT,
      texts = {
        '[worktree] agent (agent)',
        '[worktree] other (other)',
        '[branch] feature/x',
        '[branch] idle',
      },
    },
  })
end

T['branches in s']['leave out each branch a worktree has checked out as it is now, the editor’s own included'] = function()
  local work = create_work('changesscope-branches-checked-out')
  start_copy('module', work.top, 'origin/dev')
  expect_pane_lines('module', 'commits', default_view_of(work))
  git_repo.git(work.top, { 'checkout', '--quiet', '-b', 'late' })

  press_s('module', 'commits')

  eq(offered()[1].texts, {
    '[worktree] agent (agent)',
    '[worktree] other (other)',
    '[branch] main',
  })
end

T['branches in s']['leave out the working branch, its short name compared with the remote left off'] = function()
  local work = create_work('changesscope-branches-working')
  git_repo.git(work.top, { 'branch', 'dev', 'origin/dev' })
  git_repo.git(work.top, { 'branch', 'feature/dev', 'origin/dev' })
  start_copy('module', work.top, 'origin/dev')
  expect_pane_lines('module', 'commits', default_view_of(work))

  press_s('module', 'commits')

  eq(offered()[1].texts, {
    '[worktree] agent (agent)',
    '[worktree] other (other)',
    '[branch] feature/dev',
  })
end

T['branches in s']['leave out a working branch that names a local branch alone, not the branch its last component names'] = function()
  local work = create_work('changesscope-branches-working-local')
  git_repo.git(work.top, { 'branch', 'dev', 'origin/dev' })
  git_repo.git(work.top, { 'branch', 'feature/dev', 'origin/dev' })
  start_copy('module', work.top, 'feature/dev')
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Landed in feature/dev',
    commit_line(work.landed, 'Landed'),
    'Worktree agent (agent)',
    commit_line(work.agent_two, 'Agent two'),
    commit_line(work.agent_one, 'Agent one'),
    'Worktree other (other)',
    commit_line(work.other_one, 'Other one'),
  })

  press_s('module', 'commits')

  eq(offered()[1].texts, {
    '[worktree] agent (agent)',
    '[worktree] other (other)',
    '[branch] dev',
  })
end

T['branches in s']['a second press while the branches are read opens no second picker'] = function()
  local work = create_work('changesscope-branches-twice')
  git_repo.git(work.top, { 'branch', 'feature/x' })
  start_copy('module', work.top, 'origin/dev')
  expect_pane_lines('module', 'commits', default_view_of(work))
  child.lua([=[
    local git = require('aineo.git')
    local list_branches = git.list_branches
    _G.branch_reads = {}
    git.list_branches = function(found, done, options)
      table.insert(_G.branch_reads, function()
        list_branches(found, done, options)
      end)
    end
  ]=])
  enter_window_of('module', 'commits')

  child.lua("pcall(vim.api.nvim_feedkeys, 'ss', 'mx', false)")
  local started = child.lua_get('#_G.branch_reads')
  child.lua('for _, answer in ipairs(_G.branch_reads) do answer() end')
  wait_for_the_answer_to_s(0)

  eq({ started, #offered() }, { 1, 1 })
end

T['branches in s']['are not offered once the home was let go while they were read'] = function()
  local work = create_work('changesscope-branches-let-go')
  git_repo.git(work.top, { 'branch', 'feature/x' })
  start_copy('second', work.top, 'origin/dev')
  expect_pane_lines('second', 'commits', default_view_of(work))
  child.lua([=[
    local git = require('aineo.git')
    local list_branches = git.list_branches
    git.list_branches = function(found, done, options)
      _G.answer_branches = function()
        list_branches(found, done, options)
      end
    end
  ]=])
  press_s_without_waiting('second', 'commits')

  child.lua('_G.homes.second.let_go()')
  child.lua('_G.answer_branches()')
  vim.wait(1000, function()
    return answers_to_s() > 0
  end, 10)

  eq({ offered(), messages_told() }, { {}, {} })
end

--- Starts the module's home on the repository at `top`, which has no other
--- worktree, and waits until the commits window has read it.
---
---@param top string
local function start_without_other_worktrees(top)
  child.lua(COUNT_GIT_CALLS)
  start_copy('module', top)
  wait_for_the_reads()
  expect_pane_lines(
    'module',
    'commits',
    { 'Uncommitted', 'Session work', 'No commits on this session' }
  )
end

T['branches in s']['are the only items where no other worktree is listed'] = function()
  local top = git_repo.create('changesscope-branches-alone', { ['notes.txt'] = { 'one' } })
  git_repo.git(top, { 'branch', 'feature/x' })
  start_without_other_worktrees(top)

  press_s('module', 'commits')

  eq(offered(), { { prompt = PROMPT, texts = { '[branch] feature/x' } } })
end

T['branches in s']['are quoted as a path is quoted'] = function()
  local top = git_repo.create('changesscope-branches-quoted', { ['notes.txt'] = { 'one' } })
  git_repo.git(top, { 'branch', 'say"hi"' })
  start_without_other_worktrees(top)

  press_s('module', 'commits')

  eq(offered()[1].texts, { '[branch] "say\\"hi\\""' })
end

--- The commits window's lines when the branch `feature/x` of `work_with_branch()`
--- is shown alone.
---
---@param work table
---@return string[]
local function branch_view_of(work)
  return {
    'Branch feature/x',
    commit_line(work.x_two, 'X two'),
    commit_line(work.x_one, 'X one'),
  }
end

--- Makes the repository `name` the work `create_work()` makes, with the
--- branch `feature/x` forked from the commit of the working branch,
--- `origin/dev`, that holds `landed.txt`, and two commits on it — `X one`
--- adds `x.txt`, `X two` changes `notes.txt` — and the branch `idle`, which
--- holds what `main` does; starts the module's home on it, with
--- `working_branch` as the working branch, and waits until its commits
--- window lists the default view. Returns the work, with the ids of the two
--- commits as `x_one` and `x_two`.
---
---@param name string
---@param working_branch? string `origin/dev` when not given, none when `false`
---@return table work
local function work_with_branch(name, working_branch)
  local work = create_work(name)
  local made = make_branch(work.top, 'feature/x', 'origin/dev', {
    { path = 'x.txt', text = 'x', subject = 'X one' },
    { path = 'notes.txt', text = 'x notes', subject = 'X two' },
  })
  work.x_one, work.x_two = made[1], made[2]
  git_repo.git(work.top, { 'branch', 'idle', 'main' })
  start_copy('module', work.top, working_branch == nil and 'origin/dev' or working_branch or nil)
  local default_view = default_view_of(work)
  if working_branch == false then
    default_view = vim.tbl_filter(function(line)
      return line ~= 'Landed in origin/dev' and line ~= commit_line(work.landed, 'Landed')
    end, default_view)
  end
  expect_pane_lines('module', 'commits', default_view)
  return work
end

--- Picks the item of the list `s` offers that reads `text`, in the module's
--- home.
---
---@param text string
local function pick(text)
  press_s('module', 'commits')
  local position = vim.fn.index(offered()[#offered()].texts, text) + 1
  assert(position > 0, text .. ' is not offered')
  child.lua('_G.choose(...)', { position })
end

T['a branch'] = MiniTest.new_set()

T['a branch']['shown alone lists its name, whole in the colour of filters, then its commits since its merge base with the working branch, newest first'] = function()
  local work = work_with_branch('changesscope-branch-pick')

  pick('[branch] feature/x')

  expect_pane_lines('module', 'commits', branch_view_of(work))
  eq(colours_on('module', 'commits', 1), { { 0, #'Branch feature/x', 'AineoChangesFilter' } })
end

--- The files window's lines when the whole change of the branch
--- `feature/x` of `work_with_branch()` is chosen.
local BRANCH_FILES = { 'Files in: Branch feature/x', '  M notes.txt', '  A x.txt' }

T['a branch']['shown alone chooses its whole change, which the files window lists, the cursor on the first line'] = function()
  work_with_branch('changesscope-branch-files')

  pick('[branch] feature/x')

  expect_pane_lines('module', 'files', BRANCH_FILES)
  eq(
    child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.bufwinid(_G.panes.module.commits))'),
    { 1, 0 }
  )
end

T['a branch']['lists committed files only, unmarked: what the editor’s worktree changed and what the user saved is not among them'] = function()
  local work = work_with_branch('changesscope-branch-committed')
  git_repo.write(work.top, 'scratch.txt', { 'untracked' })
  git_repo.write(work.top, 'notes.txt', { 'edited, not committed' })
  child.lua('vim.cmd.edit(...)', { vim.fs.joinpath(work.top, 'notes.txt') })
  child.lua("vim.cmd('write')")

  pick('[branch] feature/x')

  expect_pane_lines('module', 'files', BRANCH_FILES)
end

T['a branch']['says no file changed on a branch whose merge base is its tip'] = function()
  work_with_branch('changesscope-branch-no-files')

  pick('[branch] idle')

  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Branch idle', 'No files changed on this branch' }
  )
end

T['a branch']['shows the cursor on a commit of it as the files of that commit, naming the branch'] = function()
  local work = work_with_branch('changesscope-branch-commit')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)

  enter_window_of('module', 'commits')
  child.type_keys('3G')

  expect_pane_lines('module', 'files', {
    'Files in: ' .. commit_line(work.x_one, 'X one') .. ' (branch feature/x)',
    '  A x.txt',
  })
end

T['a branch']['keeps the commit selected when the lists are read again'] = function()
  local work = work_with_branch('changesscope-branch-commit-kept')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)
  enter_window_of('module', 'commits')
  child.type_keys('3G')
  expect_pane_lines('module', 'files', {
    'Files in: ' .. commit_line(work.x_one, 'X one') .. ' (branch feature/x)',
    '  A x.txt',
  })
  commit_only(work.top, 'own.txt', 'own', 'Own')
  child.lua(COUNT_GIT_CALLS)

  refresh('module')
  wait_for_the_reads()

  expect_pane_lines('module', 'files', {
    'Files in: ' .. commit_line(work.x_one, 'X one') .. ' (branch feature/x)',
    '  A x.txt',
  })
  eq(commits_cursor('module'), { 3, 0 })
end

T['a branch']['shown alone says it has no commits when its merge base is its tip'] = function()
  work_with_branch('changesscope-branch-none')

  pick('[branch] idle')

  expect_pane_lines('module', 'commits', { 'Branch idle', 'No commits on this branch' })
end

T['a branch']['lists every commit since its merge base with the comparison commit where the working branch gives none'] = function()
  local work = work_with_branch('changesscope-branch-comparison', false)

  pick('[branch] feature/x')

  expect_pane_lines('module', 'commits', {
    'Branch feature/x',
    commit_line(work.x_two, 'X two'),
    commit_line(work.x_one, 'X one'),
    commit_line(work.landed, 'Landed'),
  })
end

T['a branch']['is read again with its tip: a commit added to it shows at the next read, in both windows'] = function()
  local work = work_with_branch('changesscope-branch-tip')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)

  local added = make_branch(
    work.top,
    'feature/x',
    nil,
    { { path = 'y.txt', text = 'y', subject = 'X three' } },
    AFTER_THE_FIXTURES + 100
  )
  refresh('module')

  expect_pane_lines('module', 'commits', {
    'Branch feature/x',
    commit_line(added[1], 'X three'),
    commit_line(work.x_two, 'X two'),
    commit_line(work.x_one, 'X one'),
  })
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Branch feature/x', '  M notes.txt', '  A x.txt', '  A y.txt' }
  )
end

T['a branch']['reset below the commit selected has its whole change selected, the cursor on the first line'] = function()
  local work = work_with_branch('changesscope-branch-reset')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)
  enter_window_of('module', 'commits')
  child.type_keys('2G')
  expect_pane_lines('module', 'files', {
    'Files in: ' .. commit_line(work.x_two, 'X two') .. ' (branch feature/x)',
    '  M notes.txt',
  })

  git_repo.git(work.top, { 'branch', '--force', 'feature/x', work.x_one })
  refresh('module')

  expect_pane_lines('module', 'commits', { 'Branch feature/x', commit_line(work.x_one, 'X one') })
  expect_pane_lines('module', 'files', { 'Files in: Branch feature/x', '  A x.txt' })
  eq(commits_cursor('module'), { 1, 0 })
end

T['a branch']['checked out in a new worktree stays the scope'] = function()
  local work = work_with_branch('changesscope-branch-checked-out')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)

  local checked_out = vim.fs.joinpath(vim.fs.dirname(work.top), 'checked-out')
  git_repo.git(work.top, { 'worktree', 'add', '--quiet', checked_out, 'feature/x' })
  child.lua(COUNT_GIT_CALLS)
  refresh('module')
  wait_for_the_reads()

  expect_pane_lines('module', 'commits', branch_view_of(work))
  eq(messages_told(), {})
end

--- What the user is told when the branch `feature/x` is gone.
local FEATURE_X_GONE = 'aineo: Branch feature/x is gone; the changes pane shows the default view'

T['a branch']['that names no commit any more clears the scope: the default view, Session work chosen, the user told once'] = function()
  local work = work_with_branch('changesscope-branch-gone')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)

  git_repo.git(work.top, { 'branch', '-D', 'feature/x' })
  refresh('module')

  expect_pane_lines('module', 'commits', default_view_of(work))
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Session work', 'No files changed on this session' }
  )
  child.lua(COUNT_GIT_CALLS)
  refresh('module')
  wait_for_the_reads()
  eq(messages_told(), { { message = FEATURE_X_GONE, level = vim.log.levels.INFO } })
end

T['a branch']['renamed is gone as deleted is'] = function()
  local work = work_with_branch('changesscope-branch-renamed')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)

  git_repo.git(work.top, { 'branch', '--move', 'feature/x', 'feature/y' })
  refresh('module')

  expect_pane_lines('module', 'commits', default_view_of(work))
  eq(messages_told(), { { message = FEATURE_X_GONE, level = vim.log.levels.INFO } })
end

T['a branch']['that names no commit any more is gone while the default view hides it too'] = function()
  local work = work_with_branch('changesscope-branch-gone-hidden')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)
  toggle('module')
  expect_pane_lines('module', 'commits', default_view_of(work))

  git_repo.git(work.top, { 'branch', '-D', 'feature/x' })
  child.lua(COUNT_GIT_CALLS)
  refresh('module')
  wait_for_the_reads()

  eq(messages_told(), { { message = FEATURE_X_GONE, level = vim.log.levels.INFO } })
  toggle('module')
  expect_pane_lines('module', 'commits', default_view_of(work))
end

T['a branch']['is switched with \\g like a worktree: the default view chooses Session work, the scope view its whole change again'] = function()
  local work = work_with_branch('changesscope-branch-toggle')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)

  toggle('module')

  expect_pane_lines('module', 'commits', default_view_of(work))
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Session work', 'No files changed on this session' }
  )

  toggle('module')

  expect_pane_lines('module', 'commits', branch_view_of(work))
  expect_pane_lines('module', 'files', BRANCH_FILES)
end

--- Waits until the child was asked to show `count` buffers in the middle
--- column.
---
---@param count integer
local function wait_for_diffs(count)
  git_repo.wait_until(('%d buffers shown'):format(count), function()
    return child.lua_get('#_G.shown_diffs') >= count
  end)
end

--- The name of the buffer the child was asked to show last.
---
---@return string
local function last_diff_name()
  return child.lua_get('vim.api.nvim_buf_get_name(_G.shown_diffs[#_G.shown_diffs])')
end

--- The lines of the buffer the child was asked to show last.
---
---@return string[]
local function last_diff_lines()
  return child.lua_get('vim.api.nvim_buf_get_lines(_G.shown_diffs[#_G.shown_diffs], 0, -1, true)')
end

--- The lines of `lines` that begin with `prefix`.
---
---@param lines string[]
---@param prefix string
---@return string[]
local function lines_beginning(lines, prefix)
  return vim.tbl_filter(function(line)
    return vim.startswith(line, prefix)
  end, lines)
end

--- Types `keys` in the window `which` of the pane of the changes home
--- `module`, its cursor on line `line`.
---
---@param which 'files'|'commits'
---@param line integer
---@param keys string
local function type_on(which, line, keys)
  enter_window_of('module', which)
  child.lua('vim.api.nvim_win_set_cursor(0, { ..., 0 })', { line })
  child.type_keys(keys)
end

T['a branch']['Enter on its heading shows its whole change from its base to its tip, the editor’s own changes left out, in aineo://branch/{name}//since-base'] = function()
  local work = work_with_branch('changesscope-branch-enter-heading')
  git_repo.write(work.top, 'scratch.txt', { 'untracked' })
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)

  type_on('commits', 1, '<CR>')

  wait_for_diffs(1)
  eq(last_diff_name(), 'aineo://branch/feature/x//since-base')
  eq(lines_beginning(last_diff_lines(), 'diff --git'), {
    'diff --git a/notes.txt b/notes.txt',
    'diff --git a/x.txt b/x.txt',
  })
  eq(child.lua_get('vim.api.nvim_get_current_buf() == _G.shown_diffs[1]'), true)
end

T['a branch']['Enter on a file under its whole change shows that file’s change, in aineo://branch/{name}//diff/{path}'] = function()
  work_with_branch('changesscope-branch-enter-file')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)

  type_on('files', 2, '<CR>')

  wait_for_diffs(1)
  eq(last_diff_name(), 'aineo://branch/feature/x//diff/notes.txt')
  eq(lines_beginning(last_diff_lines(), '+'), { '+++ b/notes.txt', '+x notes' })
end

T['a branch']['Enter on a renamed file shows the rename with both paths'] = function()
  local work = work_with_branch('changesscope-branch-enter-rename')
  make_branch(
    work.top,
    'mover',
    'origin/dev',
    { { rename = { 'notes.txt', 'moved.txt' }, subject = 'Move notes' } }
  )
  pick('[branch] mover')
  expect_pane_lines('module', 'files', { 'Files in: Branch mover', '  R notes.txt → moved.txt' })

  type_on('files', 2, '<CR>')

  wait_for_diffs(1)
  eq(last_diff_name(), 'aineo://branch/mover//diff/moved.txt')
  eq(
    lines_beginning(last_diff_lines(), 'rename'),
    { 'rename from notes.txt', 'rename to moved.txt' }
  )
end

T['a branch']['Enter on one of its commits, and on a file under it, shows them as your own commits are shown'] = function()
  local work = work_with_branch('changesscope-branch-enter-commit')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)

  type_on('commits', 3, '<CR>')
  wait_for_diffs(1)
  eq(last_diff_name(), 'aineo://commit/' .. work.x_one)
  expect_pane_lines('module', 'files', {
    'Files in: ' .. commit_line(work.x_one, 'X one') .. ' (branch feature/x)',
    '  A x.txt',
  })
  type_on('files', 2, '<CR>')
  wait_for_diffs(2)

  eq(last_diff_name(), 'aineo://commit/' .. work.x_one .. '/x.txt')
end

T['a branch']['l on a file shows what Enter shows, in Enter’s buffer'] = function()
  work_with_branch('changesscope-branch-l')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)

  type_on('files', 3, 'l')

  wait_for_diffs(1)
  eq(last_diff_name(), 'aineo://branch/feature/x//diff/x.txt')
end

T['a branch']['h on a file under its whole change shows it from HEAD straight to its tip, in aineo://branch/{name}//head/{path}'] = function()
  local work = work_with_branch('changesscope-branch-h')
  commit_only(work.top, 'x.txt', 'own x', 'Own x')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)

  type_on('files', 3, 'h')

  wait_for_diffs(1)
  eq(last_diff_name(), 'aineo://branch/feature/x//head/x.txt')
  eq(lines_beginning(last_diff_lines(), '+'), { '+++ b/x.txt', '+x' })
  eq(lines_beginning(last_diff_lines(), '-'), { '--- a/x.txt', '-own x' })
end

T['a branch']['h on a file under one of its commits shows it from that commit straight to HEAD, as for any commit'] = function()
  local work = work_with_branch('changesscope-branch-h-commit')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)
  enter_window_of('module', 'commits')
  child.type_keys('3G')
  expect_pane_lines('module', 'files', {
    'Files in: ' .. commit_line(work.x_one, 'X one') .. ' (branch feature/x)',
    '  A x.txt',
  })

  type_on('files', 2, 'h')

  wait_for_diffs(1)
  eq(last_diff_name(), 'aineo://head/commit/' .. work.x_one .. '/x.txt')
  eq(lines_beginning(last_diff_lines(), '-'), { '--- a/x.txt', '-x' })
end

T['a branch']['gf on a file under its whole change shows the file as its tip has it, in aineo://show/{tip}/{path}'] = function()
  local work = work_with_branch('changesscope-branch-gf')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)

  type_on('files', 3, 'gf')

  wait_for_diffs(1)
  eq(last_diff_name(), 'aineo://show/' .. work.x_two .. '/x.txt')
  eq(last_diff_lines(), { 'x' })
end

T['a branch']['gf on a file under one of its commits shows the file as that commit has it'] = function()
  local work = work_with_branch('changesscope-branch-gf-commit')
  pick('[branch] feature/x')
  expect_pane_lines('module', 'files', BRANCH_FILES)
  enter_window_of('module', 'commits')
  child.type_keys('3G')
  expect_pane_lines('module', 'files', {
    'Files in: ' .. commit_line(work.x_one, 'X one') .. ' (branch feature/x)',
    '  A x.txt',
  })

  type_on('files', 2, 'gf')

  wait_for_diffs(1)
  eq(last_diff_name(), 'aineo://show/' .. work.x_one .. '/x.txt')
end

T['a branch']['tells that the diff of its whole change cannot be read when its first read failed'] = function()
  work_with_branch('changesscope-branch-unread')
  child.lua([[
    local git = require('aineo.git')
    local resolve_commit = git.resolve_commit
    git.resolve_commit = function(found, name, done, options)
      if vim.startswith(name, 'refs/heads/') then
        done({ reason = 'failed', message = 'refs are broken' }, nil)
        return
      end
      resolve_commit(found, name, done, options)
    end
  ]])
  pick('[branch] feature/x')
  expect_pane_lines('module', 'commits', {
    'Branch feature/x',
    'The last refresh failed: refs are broken',
  })

  type_on('commits', 1, '<CR>')

  git_repo.wait_until('the failure told', function()
    return #messages_told() > 0
  end)
  eq(messages_told(), {
    {
      message = 'aineo: the diff of Branch feature/x could not be read: refs are broken',
      level = vim.log.levels.ERROR,
    },
  })
end

T['branches in s']['that cannot be listed leave the worktrees alone, the failure told once as a warning'] = function()
  local work = create_work('changesscope-branches-failed')
  git_repo.git(work.top, { 'branch', 'feature/x' })
  child.lua([[require('aineo.git').list_branches = function(_, done)
    done({ reason = 'failed', message = 'refs are broken' }, nil)
  end]])
  start_copy('module', work.top, 'origin/dev')
  expect_pane_lines('module', 'commits', default_view_of(work))

  press_s('module', 'commits')

  eq(offered()[1].texts, { '[worktree] agent (agent)', '[worktree] other (other)' })
  eq(messages_told(), {
    {
      message = 'aineo: the local branches could not be listed: refs are broken',
      level = vim.log.levels.WARN,
    },
  })
end

T['branches in s']['are not read once the worktrees could not be listed: nothing says which are checked out'] = function()
  local top = git_repo.create('changesscope-branches-unlisted', { ['notes.txt'] = { 'one' } })
  git_repo.git(top, { 'branch', 'feature/x' })
  child.lua([=[
    local git = require('aineo.git')
    _G.branch_reads = 0
    local list_branches = git.list_branches
    git.list_branches = function(...)
      _G.branch_reads = _G.branch_reads + 1
      return list_branches(...)
    end
    git.list_worktrees = function(_, done)
      done({ reason = 'failed', message = 'broken' }, nil)
    end
  ]=])
  start_copy('module', top)
  expect_pane_lines('module', 'commits', {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'The other worktrees could not be listed: broken',
  })

  press_s('module', 'commits')

  eq({ offered(), messages_told(), child.lua_get('_G.branch_reads') }, {
    {},
    {
      {
        message = 'aineo: The other worktrees could not be listed: broken',
        level = vim.log.levels.INFO,
      },
    },
    0,
  })
end

return T
