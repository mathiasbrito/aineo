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
--- files it was asked for and answered, in `_G.file_reads`, each answer once
--- its caller's `done` has run.
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
---@return string top
---@return string base
local function in_repository(name, files, mode)
  local top, base = git_repo.create(name, files)
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { git_repo.ENVIRONMENT })
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake(name, mode or 'ready'))
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
  return child.lua_get('vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, true)', { name })
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

  entry.press(child, '\\pc')

  expect_lines(COMMITS, { commit:sub(1, 7) .. ' Write two' })
  expect_lines(FILES, { '  M notes.txt' })
end

T['the session']['outlives a restart of Claude Code: its commits stay the session’s'] = function()
  local top = in_repository('changespane-entry-restart', { ['notes.txt'] = { 'one' } }, 'exit')
  open_and_wait_for_the_base()
  eq(claude_session.wait_for_status(child, 'exited')[1], 'exited')
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')

  child.cmd('Aineo open')
  entry.press(child, '\\pc')

  expect_lines(COMMITS, { commit:sub(1, 7) .. ' Write two' })
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
  entry.press(child, '\\pc')

  expect_lines(COMMITS, { 'No commits on this session' })
end

T['the pane'] = MiniTest.new_set()

--- Waits until every read of the files the child's git home was asked for
--- has answered.
local function wait_for_the_reads()
  git_repo.wait_until('every read of the files answered', function()
    return child.lua_get('_G.file_reads.answered == _G.file_reads.asked')
  end)
end

T['the pane']['reads its lists again as \\o restores the layout it shows in'] = function()
  local top = in_repository('changespane-entry-restore', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'scratch.log', { 'scratch' })
  open_and_wait_for_the_base()
  entry.press(child, '\\pc')
  expect_lines(FILES, { '  ? scratch.log' })
  git_repo.wait_until('every read of the files answered', function()
    return child.lua_get('_G.file_reads.answered == _G.file_reads.asked')
  end)
  git_repo.write(top, '.git/info/exclude', { 'scratch.log' })

  entry.press(child, '\\o')

  expect_lines(FILES, { 'No files changed on this session' })
end

--- Each door to the changes pane, as a set's `parametrize`: its name, and
--- the function that opens it.
local DOORS = {
  {
    'pressing \\pc',
    function()
      entry.press(child, '\\pc')
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
  entry.press(child, '\\pc')
  expect_lines(FILES, { '  ? scratch.log' })
  wait_for_the_reads()
  git_repo.write(top, '.git/info/exclude', { 'scratch.log' })

  door()

  expect_lines(FILES, { 'No files changed on this session' })
end

T['the pane']['shown once reads its files once'] = function()
  in_repository('changespane-entry-read-once', { ['notes.txt'] = { 'one' } })
  open_and_wait_for_the_base()
  entry.press(child, '\\pc')
  expect_lines(FILES, { 'No files changed on this session' })
  wait_for_the_reads()
  entry.press(child, '\\pa')
  local asked = child.lua_get('_G.file_reads.asked')

  entry.press(child, '\\pc')

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
  entry.press(child, '\\pc')
  expect_lines(FILES, { 'No files changed on this session' })
  wait_for_the_reads()
  local held = child.lua_get(HELD)

  entry.press(child, '\\pa\\pc\\pa\\pc\\pa\\pc\\pa\\pc\\pa\\pc\\pa\\pc\\pa\\pc\\pa\\pc\\pa\\pc')

  wait_for_the_reads()
  eq(child.lua_get(HELD), held)
end

T['Enter'] = MiniTest.new_set()

--- Opens the layout around a repository whose `notes.txt` changed since the
--- base, shows the changes pane and waits for it to list the file, then
--- moves the cursor to the files window.
---
---@param name string
local function changes_pane_listing_a_file(name)
  local top = in_repository(name, { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  open_and_wait_for_the_base()
  entry.press(child, '\\pc')
  expect_lines(FILES, { '  M notes.txt' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })
end

--- Waits until a window of the child shows the buffer named `name`.
---
---@param name string
local function wait_for_window_showing(name)
  git_repo.wait_until(name .. ' shown', function()
    return child.lua_get('vim.fn.bufwinid(...)', { name }) ~= -1
  end)
end

T['Enter']['shows a file’s diff in the middle column, the cursor staying in the pane'] = function()
  changes_pane_listing_a_file('changespane-entry-enter')

  entry.press(child, '<CR>')

  wait_for_window_showing('aineo://diff/notes.txt')
  eq(
    { entry.windows(child), entry.current_window(child) },
    { { 'terminal', 'aineo://diff/notes.txt', FILES, COMMITS }, FILES }
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

return T
