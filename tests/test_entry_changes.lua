local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      entry.restart(child)
    end,
    post_once = child.stop,
  },
})

--- The name of the changes pane's files buffer.
local FILES = 'aineo://changes-files'

--- The name of the changes pane's commits buffer.
local COMMITS = 'aineo://changes-commits'

--- The Lua that counts, in the child, the looks for a repository the git
--- home was asked for, in `_G.finds_asked`, and the repositories it has
--- found or failed to find, in `_G.finds_answered`, and the reads of the
--- files it was asked for and answered, in `_G.file_reads`, and the lists
--- of worktrees each window reads last, in `_G.worktree_lists`, each answer
--- once its caller's `done` has run.
local COUNT_FINDS = [[
  local git = require('aineo.git')
  local find_repository = git.find_repository
  _G.finds_asked, _G.finds_answered = 0, 0
  git.find_repository = function(directory, done, options)
    _G.finds_asked = _G.finds_asked + 1
    return find_repository(directory, function(...)
      done(...)
      _G.finds_answered = _G.finds_answered + 1
    end, options)
  end
  local changed_files = git.changed_files
  _G.file_reads = { asked = 0, answered = 0 }
  git.changed_files = function(found, base, done, options)
    _G.file_reads.asked = _G.file_reads.asked + 1
    return changed_files(found, base, function(...)
      done(...)
      _G.file_reads.answered = _G.file_reads.answered + 1
    end, options)
  end
  local list_worktrees = git.list_worktrees
  _G.worktree_lists = { asked = 0, answered = 0 }
  git.list_worktrees = function(found, done, options)
    _G.worktree_lists.asked = _G.worktree_lists.asked + 1
    return list_worktrees(found, function(...)
      done(...)
      _G.worktree_lists.answered = _G.worktree_lists.answered + 1
    end, options)
  end
]]

--- Makes the repository `.tests/fixtures/git-<name>/repo` holding `files` in
--- one commit, gives the child the git isolation of the git home's suites
--- (`git_repo.ENVIRONMENT`), moves its working directory there, where
--- Claude Code starts, makes aineo run the fake `claude` in `mode`, and
--- counts the git home's looks for a repository (`COUNT_FINDS`); returns the
--- repository's top level and its one commit.
---
---@param name string the case's own name, starting `changespane-`
---@param files table<string, string[]>
---@param mode? string the fake's mode, `ready` when not given
---@param settings? table more of `vim.g.aineo` (`entry.use_fake()`)
---@return string top
---@return string base
local function in_repository(name, files, mode, settings)
  local top, base = git_repo.create(name, files)
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { git_repo.ENVIRONMENT })
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake(name, mode or 'ready'), settings)
  child.lua(COUNT_FINDS)
  return top, base
end

--- Opens the layout in the child (`:Aineo open`), and waits until the
--- session's repository was looked for, and so its base taken.
local function open_and_wait_for_the_base()
  child.cmd('Aineo open')
  git_repo.wait_until('the repository looked for', function()
    return child.lua_get('_G.finds_answered') >= 1
  end)
end

--- The lines of the child's buffer named `name`.
---
---@param name string
---@return string[]
local function lines_of(name)
  return git_repo.without_against_line(
    child.lua_get('vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, true)', { name })
  )
end

--- Waits until the child's buffer named `name` holds `expected`, at most
--- `git_repo.PATIENCE_MS`, and asserts that it does.
---
---@param name string
---@param expected string[]
local function expect_lines(name, expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(lines_of(name), expected)
  end, 10)
  eq(lines_of(name), expected)
end

T['the session'] = MiniTest.new_set()

T['the session']['begins at the first start of Claude Code: a commit made since is the session’s'] = function()
  local top = in_repository('changespane-entry-base', { ['notes.txt'] = { 'one' } })
  open_and_wait_for_the_base()
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')

  entry.press(child, '\\g')

  expect_lines(
    COMMITS,
    { 'Uncommitted', 'Session work', git_repo.commit_line(commit, 'Write two') }
  )
  expect_lines(FILES, { 'Files in: Session work', '  M notes.txt' })
end

T['the session']['outlives a restart of Claude Code: its commits stay the session’s'] = function()
  local top = in_repository('changespane-entry-restart', { ['notes.txt'] = { 'one' } }, 'exit')
  open_and_wait_for_the_base()
  eq(claude_session.wait_for_status(child, 'exited')[1], 'exited')
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')

  child.cmd('Aineo open')
  entry.press(child, '\\g')

  expect_lines(
    COMMITS,
    { 'Uncommitted', 'Session work', git_repo.commit_line(commit, 'Write two') }
  )
end

T['the session']['does not begin at a start that fails: the next start takes the base'] = function()
  local top = in_repository('changespane-entry-failed-start', { ['notes.txt'] = { 'one' } })
  local fake = claude_session.fake('changespane-entry-failed-start', 'ready')
  entry.use_fake(child, fake, { claude = { cmd = { vim.fs.joinpath(top, 'no-such-claude') } } })
  entry.command(child, 'Aineo open')
  eq(child.lua_get('_G.finds_asked'), 0)
  git_repo.write(top, 'notes.txt', { 'two' })
  git_repo.commit_all(top, 'Write two')
  entry.use_fake(child, fake)

  open_and_wait_for_the_base()
  entry.press(child, '\\g')

  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
end

T['the session']['takes its working branch from changes.working_branch of the settings'] = function()
  local top = in_repository('changespane-entry-working-branch', { ['notes.txt'] = { 'one' } })
  local remote = vim.fs.joinpath(vim.fs.dirname(top), 'remote.git')
  git_repo.git(
    vim.fs.dirname(top),
    { 'init', '--quiet', '--bare', '--initial-branch=main', remote }
  )
  git_repo.git(top, { 'remote', 'add', 'origin', remote })
  git_repo.git(top, { 'push', '--quiet', 'origin', 'main:dev' })
  child.lua(
    "local settings = vim.g.aineo settings.changes = { working_branch = 'origin/dev' } vim.g.aineo = settings"
  )
  open_and_wait_for_the_base()

  entry.press(child, '\\g')

  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Landed in origin/dev',
    'Nothing landed in origin/dev on this session',
  })
end

T['the session']['draws as many commits in the commit graph as changes.graph_limit of the settings'] = function()
  local top = in_repository('changespane-entry-graph-limit', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  git_repo.commit_all(top, 'Write two')
  child.lua(
    'local settings = vim.g.aineo settings.changes = { graph_limit = 1 } vim.g.aineo = settings'
  )
  open_and_wait_for_the_base()
  entry.press(child, '\\g')
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { COMMITS })

  child.type_keys('t')

  git_repo.wait_until('the graph drawn', function()
    return #lines_of(COMMITS) == 2
  end)
  eq(lines_of(COMMITS)[2], 'Older commits not shown')
end

T['the pane'] = MiniTest.new_set()

--- Waits until every read of the files the child's git home was asked for
--- has answered, and every list of worktrees the reads end with.
local function wait_for_the_reads()
  git_repo.wait_until('every read of the files answered', function()
    return child.lua_get(
      '_G.file_reads.answered == _G.file_reads.asked and _G.worktree_lists.answered == _G.worktree_lists.asked'
    )
  end)
end

T['the pane']['reads its lists again as \\o restores the layout it shows in'] = function()
  local top = in_repository('changespane-entry-restore', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'scratch.log', { 'scratch' })
  open_and_wait_for_the_base()
  entry.press(child, '\\g')
  expect_lines(FILES, { 'Files in: Session work', '  ? scratch.log' })
  git_repo.wait_until('every read of the files answered', function()
    return child.lua_get('_G.file_reads.answered == _G.file_reads.asked')
  end)
  git_repo.write(top, '.git/info/exclude', { 'scratch.log' })

  entry.press(child, '\\o')

  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
end

--- Each door to the changes pane, as a set's `parametrize`: its name, and
--- the function that opens it.
local DOORS = {
  {
    'pressing \\g',
    function()
      entry.press(child, '\\g')
    end,
  },
  {
    'pressing <Plug>(aineo-pane-changes)',
    function()
      entry.press(child, '<Plug>(aineo-pane-changes)')
    end,
  },
  {
    'running :Aineo pane changes',
    function()
      entry.command(child, 'Aineo pane changes')
    end,
  },
}

T['the pane']['reads its lists again while it shows, by'] = MiniTest.new_set({
  parametrize = DOORS,
})

T['the pane']['reads its lists again while it shows, by']['door'] = function(_, door)
  local top = in_repository('changespane-entry-shown-again', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'scratch.log', { 'scratch' })
  open_and_wait_for_the_base()
  entry.press(child, '\\g')
  expect_lines(FILES, { 'Files in: Session work', '  ? scratch.log' })
  wait_for_the_reads()
  git_repo.write(top, '.git/info/exclude', { 'scratch.log' })

  door()

  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
end

T['the pane']['shown once reads its files once'] = function()
  in_repository('changespane-entry-read-once', { ['notes.txt'] = { 'one' } })
  open_and_wait_for_the_base()
  entry.press(child, '\\g')
  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
  wait_for_the_reads()
  entry.press(child, '\\pa')
  local asked = child.lua_get('_G.file_reads.asked')

  entry.press(child, '\\g')

  wait_for_the_reads()
  eq(child.lua_get('_G.file_reads.asked'), asked + 1)
end

--- The Lua expression that tells, in the child, how many autocommands,
--- buffers and running file system watches it holds.
local HELD = [[(function()
  local watches = 0
  vim.uv.walk(function(handle)
    if handle:get_type() == 'fs_event' and handle:is_active() and not handle:is_closing() then
      watches = watches + 1
    end
  end)
  return {
    autocommands = #vim.api.nvim_get_autocmds({}),
    buffers = #vim.api.nvim_list_bufs(),
    watches = watches,
  }
end)()]]

T['the pane']['shown ten times holds no more autocommands, buffers or watches than shown once'] = function()
  in_repository('changespane-entry-ten', { ['notes.txt'] = { 'one' } })
  open_and_wait_for_the_base()
  entry.press(child, '\\g')
  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
  wait_for_the_reads()
  local held = child.lua_get(HELD)

  entry.press(child, '\\pa\\g\\pa\\g\\pa\\g\\pa\\g\\pa\\g\\pa\\g\\pa\\g\\pa\\g\\pa\\g')

  wait_for_the_reads()
  eq(child.lua_get(HELD), held)
end

T['Enter'] = MiniTest.new_set()

--- Opens the layout around a repository whose `notes.txt` changed since the
--- base, shows the changes pane and waits for it to list the file, then
--- moves the cursor to the files window, onto the file's line. The pane is
--- shown by typing `pane_keys`, `\g` when not given; a configuration with
--- no prefix gives `:Aineo pane changes` instead (`pane_keys` = `false`).
--- `settings` are more of `vim.g.aineo` (`in_repository()`).
---
---@param name string
---@param pane_keys? string|false
---@param settings? table
---@return string top the repository's top level
local function changes_pane_listing_a_file(name, pane_keys, settings)
  local top = in_repository(name, { ['notes.txt'] = { 'one' } }, nil, settings)
  git_repo.write(top, 'notes.txt', { 'two' })
  open_and_wait_for_the_base()
  if pane_keys == false then
    child.cmd('Aineo pane changes')
  else
    entry.press(child, pane_keys or '\\g')
  end
  expect_lines(FILES, { 'Files in: Session work', '  M notes.txt' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')
  return top
end

--- Waits until a window of the child shows the buffer named `name`.
---
---@param name string
local function wait_for_window_showing(name)
  git_repo.wait_until(name .. ' shown', function()
    return child.lua_get('vim.fn.bufwinid(...)', { name }) ~= -1
  end)
end

T['Enter']['shows a file’s diff in the middle column and moves the cursor there, in Normal mode'] = function()
  changes_pane_listing_a_file('changespane-entry-enter')

  entry.press(child, '<CR>')

  wait_for_window_showing('aineo://diff/notes.txt')
  eq({ entry.windows(child), entry.current_window(child), child.api.nvim_get_mode().mode }, {
    { 'terminal', 'aineo://diff/notes.txt', FILES, COMMITS },
    'aineo://diff/notes.txt',
    'n',
  })
end

T['Enter']['then <BS> in the diff, with the agent pane on screen, shows the changes pane and moves to the file’s line'] = function()
  changes_pane_listing_a_file('changespane-entry-back-other-pane')
  entry.press(child, '<CR>')
  wait_for_window_showing('aineo://diff/notes.txt')
  entry.press(child, '\\pa')
  git_repo.wait_until('the changes pane left the screen', function()
    return child.lua_get('vim.fn.bufwinid(...)', { FILES }) == -1
  end)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { 'aineo://diff/notes.txt' })

  entry.press(child, '<BS>')

  git_repo.wait_until('the files window entered', function()
    return entry.current_window(child) == FILES
  end)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), { 3, 0 })
end

T['Enter']['with none of the layout’s windows open moves the cursor to the diff above the pane'] = function()
  changes_pane_listing_a_file('changespane-entry-enter-alone')
  child.cmd('new')
  child.cmd('only')
  child.lua('vim.api.nvim_win_set_buf(0, vim.fn.bufnr(...))', { FILES })
  expect_lines(FILES, { 'Files in: Session work', '  M notes.txt' })
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')

  entry.press(child, '<CR>')

  wait_for_window_showing('aineo://diff/notes.txt')
  eq(
    { entry.windows(child), entry.current_window(child) },
    { { 'aineo://diff/notes.txt', FILES }, 'aineo://diff/notes.txt' }
  )
end

T['Enter']['again on the file the middle column shows keeps the diff’s window'] = function()
  changes_pane_listing_a_file('changespane-entry-enter-again')
  entry.press(child, '<CR>')
  wait_for_window_showing('aineo://diff/notes.txt')
  local window = child.lua_get('vim.fn.bufwinid(...)', { 'aineo://diff/notes.txt' })
  child.lua([[
    local git = require('aineo.git')
    local file_diff = git.file_diff
    _G.diffs_answered = 0
    git.file_diff = function(found, base, change, done, options)
      return file_diff(found, base, change, function(...)
        done(...)
        _G.diffs_answered = _G.diffs_answered + 1
      end, options)
    end
  ]])
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })

  entry.press(child, '<CR>')

  git_repo.wait_until('the diff shown again', function()
    return child.lua_get('_G.diffs_answered') >= 1
  end)
  eq(
    { child.lua_get('vim.fn.bufwinid(...)', { 'aineo://diff/notes.txt' }), entry.windows(child) },
    { window, { 'terminal', 'aineo://diff/notes.txt', FILES, COMMITS } }
  )
end

--- The Lua that holds, in the child, each answer the git home gives to a
--- read of a file's diff until `_G.answer_diff()` is called, which then
--- hands it to its caller at the main loop's next turn, and counts in
--- `_G.diffs_handed` the answers handed over, each as its caller's `done`
--- begins.
local HOLD_DIFF_ANSWERS = [[
  local git = require('aineo.git')
  local file_diff = git.file_diff
  _G.diffs_handed = 0
  git.file_diff = function(found, base, change, done, options)
    return file_diff(found, base, change, function(...)
      local answer = { n = select('#', ...), ... }
      _G.answer_diff = function()
        vim.schedule(function()
          _G.diffs_handed = _G.diffs_handed + 1
          done(unpack(answer, 1, answer.n))
        end)
      end
    end, options)
  end
]]

--- The Lua expression giving everything the child's messages hold.
local TOLD = "vim.api.nvim_exec2('messages', { output = true }).output"

T['Enter']['while the command-line window is open shows the diff once it closes, telling nothing'] = function()
  changes_pane_listing_a_file('changespane-entry-cmdwin')
  child.lua(HOLD_DIFF_ANSWERS)
  entry.press(child, '<CR>')
  git_repo.wait_until('the diff read', function()
    return child.lua_get('_G.answer_diff ~= nil')
  end)
  child.api.nvim_input('q:')
  git_repo.wait_until('the command-line window open', function()
    return child.fn.getcmdwintype() == ':'
  end)
  child.lua('_G.answer_diff()')
  git_repo.wait_until('the diff handed over', function()
    return child.lua_get('_G.diffs_handed') == 1
  end)
  local told_meanwhile = child.lua_get(TOLD)

  child.api.nvim_input(':quit<CR>')

  vim.wait(git_repo.PATIENCE_MS, function()
    return child.lua_get('vim.fn.bufwinid(...)', { 'aineo://diff/notes.txt' }) ~= -1
  end, 10)
  eq(
    { told_meanwhile = told_meanwhile, windows = entry.windows(child), told = child.lua_get(TOLD) },
    {
      told_meanwhile = '',
      windows = { 'terminal', 'aineo://diff/notes.txt', FILES, COMMITS },
      told = '',
    }
  )
end

T['the prefix and Enter'] = MiniTest.new_set()

T['the prefix and Enter']['opens the file for edition in the file column, as <S-CR> does'] = function()
  local top = changes_pane_listing_a_file('changespane-entry-prefix-enter')
  local path = vim.fs.joinpath(top, 'notes.txt')

  entry.press(child, '\\<CR>')

  wait_for_window_showing(path)
  eq({ entry.windows(child), entry.current_window(child) }, {
    { 'terminal', path, FILES, COMMITS },
    path,
  })
  eq(child.lua_get('vim.bo.modifiable'), true)
end

T['the prefix and Enter']['leaves the file in the file column when the cursor then moves in the files window'] = function()
  local top = changes_pane_listing_a_file('changespane-entry-prefix-enter-follow')
  local path = vim.fs.joinpath(top, 'notes.txt')
  entry.press(child, 'l')
  wait_for_window_showing('aineo://diff/notes.txt')
  entry.press(child, '\\<CR>')
  wait_for_window_showing(path)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })

  entry.press(child, 'k')
  entry.press(child, 'j')

  vim.wait(500)
  eq(entry.windows(child), { 'terminal', path, FILES, COMMITS })
end

T['the prefix and Enter']['follows the prefix vim.g.aineo names'] = function()
  entry.restart(child, { '--cmd', "lua vim.g.aineo = { prefix = ',', autostart = false }" })
  local top = changes_pane_listing_a_file(
    'changespane-entry-prefix-enter-custom',
    ',g',
    { prefix = ',', autostart = false }
  )
  local path = vim.fs.joinpath(top, 'notes.txt')

  entry.press(child, ',<CR>')

  wait_for_window_showing(path)
  eq(entry.current_window(child), path)
end

T['the prefix and Enter']['maps nothing, <S-CR> staying, when the prefix is false'] = function()
  entry.restart(child, { '--cmd', 'lua vim.g.aineo = { prefix = false, autostart = false }' })
  changes_pane_listing_a_file(
    'changespane-entry-prefix-enter-off',
    false,
    { prefix = false, autostart = false }
  )

  eq(child.lua_get('vim.fn.maparg(..., "n")', { '\\<CR>' }), '')
  eq(child.lua_get('vim.fn.maparg(..., "n", false, true).buffer', { '<S-CR>' }), 1)
end

T['gf'] = MiniTest.new_set()

--- Opens the layout around a repository with one new file, `has space.txt`,
--- shows the changes pane and waits for it to list the file, then moves the
--- cursor to the files window, onto the file's line. Returns the file's
--- absolute path.
---
---@param name string
---@return string path
local function changes_pane_listing_a_new_file(name)
  local top = in_repository(name, { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'has space.txt', { 'text' })
  open_and_wait_for_the_base()
  entry.press(child, '\\g')
  expect_lines(FILES, { 'Files in: Session work', '  ? has space.txt' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')
  return vim.fs.joinpath(top, 'has space.txt')
end

T['gf']['opens the file in the file column, the files window still showing the list'] = function()
  local path = changes_pane_listing_a_new_file('changespane-entry-gf')

  entry.press(child, 'gf')

  wait_for_window_showing(path)
  eq({ entry.windows(child), entry.current_window(child) }, {
    { 'terminal', path, FILES, COMMITS },
    path,
  })
end

T['gf']['with none of the layout’s windows open opens the file in the files window, as :edit does'] = function()
  local path = changes_pane_listing_a_new_file('changespane-entry-gf-alone')
  child.cmd('new')
  child.cmd('only')
  child.lua('vim.api.nvim_win_set_buf(0, vim.fn.bufnr(...))', { FILES })
  expect_lines(FILES, { 'Files in: Session work', '  ? has space.txt' })
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')

  entry.press(child, 'gf')

  wait_for_window_showing(path)
  eq({ entry.windows(child), entry.current_window(child) }, { { path }, path })
end

T['the focused view'] = MiniTest.new_set()

--- Makes `vim.ui.select` pick the first item it is offered, at once.
local PICK_THE_FIRST = [[
  vim.ui.select = function(items, _, on_choice)
    on_choice(items[1])
  end
]]

--- Opens the layout around a repository with one other worktree, `agent`,
--- of one commit, shows the changes pane, and shows that worktree alone
--- with `s`, once Claude Code is ready: its first readiness follows the
--- session, which takes its base then, so a pick made before it would
--- be read again against a base that is not yet the session's. Returns the
--- commits window's lines in the default view and in the scope view.
---
---@param name string
---@return string[] default_view
---@return string[] scope_view
local function scoped_to_the_agent_worktree(name)
  local top = in_repository(name, { ['notes.txt'] = { 'one' } })
  local agent = vim.fs.joinpath(vim.fs.dirname(top), 'agent')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'agent', agent })
  git_repo.write(agent, 'agent.txt', { 'agent' })
  local commit = git_repo.commit_all(agent, 'Agent one')
  child.lua(PICK_THE_FIRST)
  open_and_wait_for_the_base()
  eq(claude_session.wait_for_status(child, 'ready')[1], 'ready')
  local default_view = {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'Uncommitted — agent (agent)',
    git_repo.commit_line(commit, 'Agent one'),
  }
  local scope_view = {
    'Worktree agent (agent)',
    'Uncommitted — agent (agent)',
    git_repo.commit_line(commit, 'Agent one'),
  }
  entry.press(child, '\\g')
  expect_lines(COMMITS, default_view)
  entry.press(child, 's')
  expect_lines(COMMITS, scope_view)
  return default_view, scope_view
end

T['the focused view']['switches with the default view, by'] = MiniTest.new_set({
  parametrize = DOORS,
})

T['the focused view']['switches with the default view, by']['door'] = function(name, door)
  local default_view, scope_view =
    scoped_to_the_agent_worktree('changespane-entry-toggle-' .. name:gsub('%W', ''))

  door()
  expect_lines(COMMITS, default_view)
  door()

  expect_lines(COMMITS, scope_view)
end

T['the focused view']['is shown again by \\g from another pane, the scope kept'] = function()
  local _, scope_view = scoped_to_the_agent_worktree('changespane-entry-other-pane')
  entry.press(child, '\\pa')

  entry.press(child, '\\g')

  expect_lines(COMMITS, scope_view)
end

T['the focused view']['shows the default view from another pane once \\g switched to it'] = function()
  local default_view = scoped_to_the_agent_worktree('changespane-entry-left-default')
  entry.press(child, '\\g')
  expect_lines(COMMITS, default_view)
  entry.press(child, '\\pa')

  entry.press(child, '\\g')

  expect_lines(COMMITS, default_view)
end

--- Makes the window showing Claude's terminal the current one.
local function enter_claude_window()
  child.lua([[
    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local buffer = vim.api.nvim_win_get_buf(window)
      if vim.bo[buffer].buftype == 'terminal' then
        vim.api.nvim_set_current_win(window)
        return
      end
    end
    error('no terminal window')
  ]])
end

T['the focused view']['is kept by \\g from Claude’s window, with the pane on screen: the cursor moves into the pane'] = function()
  local _, scope_view = scoped_to_the_agent_worktree('changespane-entry-from-claude')
  enter_claude_window()
  eq(entry.current_window(child), 'terminal')

  entry.press(child, '\\g')

  eq({ entry.current_window(child), lines_of(COMMITS) }, { COMMITS, scope_view })
end

T['the focused view']['is kept by \\g from a diff Enter opened, with the pane on screen: the cursor moves into the pane'] = function()
  local _, scope_view = scoped_to_the_agent_worktree('changespane-entry-from-diff')
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  A agent.txt' })
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')
  entry.press(child, '<CR>')
  git_repo.wait_until('the diff shown and entered', function()
    return entry.current_window(child):find('//diff/', 1, true) ~= nil
  end)

  entry.press(child, '\\g')

  eq({ entry.current_window(child), lines_of(COMMITS) }, { COMMITS, scope_view })
end
T['Diff close'] = MiniTest.new_set()

--- Each door to the closing of the diff the pane shows, as a set's
--- `parametrize`: its name, and the function that goes through it.
local DIFF_CLOSE_DOORS = {
  {
    'pressing \\d',
    function()
      entry.press(child, '\\d')
    end,
  },
  {
    'pressing <Plug>(aineo-diff-close)',
    function()
      entry.press(child, '<Plug>(aineo-diff-close)')
    end,
  },
  {
    'running :Aineo diff close',
    function()
      entry.command(child, 'Aineo diff close')
    end,
  },
}

T['Diff close']['closes the diff the cursor is in and puts the cursor on the file’s line of the files window, by'] =
  MiniTest.new_set({ parametrize = DIFF_CLOSE_DOORS })

T['Diff close']['closes the diff the cursor is in and puts the cursor on the file’s line of the files window, by']['door'] = function(
  _,
  door
)
  changes_pane_listing_a_file('changespane-entry-diff-close')
  entry.press(child, '<CR>')
  wait_for_window_showing('aineo://diff/notes.txt')

  door()

  eq({
    entry.windows(child),
    entry.current_window(child),
    child.api.nvim_win_get_cursor(0),
    child.api.nvim_get_mode().mode,
  }, { { 'terminal', FILES, COMMITS }, FILES, { 3, 0 }, 'n' })
end

T['Diff close']['closes the diff from Claude’s window, the cursor staying there, by'] =
  MiniTest.new_set({
    parametrize = DIFF_CLOSE_DOORS,
  })

T['Diff close']['closes the diff from Claude’s window, the cursor staying there, by']['door'] = function(
  _,
  door
)
  changes_pane_listing_a_file('changespane-entry-diff-close-claude')
  entry.press(child, '<CR>')
  wait_for_window_showing('aineo://diff/notes.txt')
  child.lua('vim.api.nvim_set_current_win(vim.fn.win_getid(1))')
  child.cmd('stopinsert')

  door()

  eq(
    { entry.windows(child), entry.current_window(child) },
    { { 'terminal', FILES, COMMITS }, 'terminal' }
  )
end

T['Diff close']['with no aineo tab tells there is no diff and makes no tab, by'] =
  MiniTest.new_set({
    parametrize = { DIFF_CLOSE_DOORS[1], DIFF_CLOSE_DOORS[3] },
  })

T['Diff close']['with no aineo tab tells there is no diff and makes no tab, by']['door'] = function(
  _,
  door
)
  door()

  eq({
    entry.messages(child),
    child.lua_get("#require('aineo.entry.registry').tab_list"),
    entry.windows(child),
  }, {
    { { message = 'aineo: no diff to close', level = vim.log.levels.INFO } },
    0,
    { '' },
  })
end

T['Diff close']['from a tab page of no aineo tab closes the diff of the tab used last and moves there'] = function()
  changes_pane_listing_a_file('changespane-entry-diff-close-plain-tab')
  entry.press(child, '<CR>')
  wait_for_window_showing('aineo://diff/notes.txt')
  child.cmd('tabnew')

  entry.press(child, '\\d')

  eq({ child.fn.tabpagenr(), entry.windows(child) }, { 1, { 'terminal', FILES, COMMITS } })
end

T['Diff close']['gives the file column back: Claude’s column takes half of the screen again'] = function()
  changes_pane_listing_a_file('changespane-entry-diff-close-columns')
  entry.press(child, '<CR>')
  wait_for_window_showing('aineo://diff/notes.txt')
  local with_the_column = child.lua_get('vim.api.nvim_win_get_width(vim.fn.win_getid(1))')

  entry.press(child, '\\d')

  git_repo.wait_until('Claude’s column half of the screen', function()
    return child.lua_get('vim.api.nvim_win_get_width(vim.fn.win_getid(1))')
      == math.floor(entry.COLUMNS / 2)
  end)
  eq(with_the_column < math.floor(entry.COLUMNS / 2), true)
end

T['Diff close']['tells once that there is no diff to close when none is shown'] = function()
  changes_pane_listing_a_file('changespane-entry-diff-close-none')
  local windows = entry.windows(child)

  entry.press(child, '\\d')

  eq({ entry.messages(child), entry.windows(child) }, {
    { { message = 'aineo: no diff to close', level = vim.log.levels.INFO } },
    windows,
  })
end

--- What `:Aineo diff` tells the user when it is not given `close`.
local DIFF_USAGE = 'aineo: :Aineo diff takes one of close'

T[':Aineo diff'] = MiniTest.new_set()

T[':Aineo diff']['tells the user once which word it takes, and does nothing else, given'] =
  MiniTest.new_set({
    parametrize = {
      { 'no word', 'Aineo diff' },
      { 'another word', 'Aineo diff open' },
      { 'more words after close', 'Aineo diff close now' },
    },
  })

T[':Aineo diff']['tells the user once which word it takes, and does nothing else, given']['the command'] = function(
  _,
  command
)
  child.cmd(command)

  eq(
    { entry.messages(child), entry.windows(child) },
    { { { message = DIFF_USAGE, level = vim.log.levels.ERROR } }, { '' } }
  )
end

T[':Aineo diff']['completes close, filtered by what is typed, and nothing after it'] = function()
  eq({
    child.fn.getcompletion('Aineo diff ', 'cmdline'),
    child.fn.getcompletion('Aineo diff c', 'cmdline'),
    child.fn.getcompletion('Aineo diff x', 'cmdline'),
    child.fn.getcompletion('Aineo diff close ', 'cmdline'),
  }, { { 'close' }, { 'close' }, {}, {} })
end

return T
