local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = child.stop,
  },
})

--- The name of the changes pane's files buffer.
local FILES = 'aineo://changes-files'

--- The name of the changes pane's commits buffer.
local COMMITS = 'aineo://changes-commits'

--- The Lua that begins the changes home's session in the child for the
--- directory `...`, with the git options that follow, and shows the pane's
--- two buffers there: the files buffer in the current window, the commits
--- buffer in a window below it. Every buffer the home asks to show as a diff
--- is kept in `_G.shown_diffs` and shown in a window of its own at the
--- bottom, the cursor left where it is.
local BEGIN_AND_SHOW = [[
  local directory, git_options = ...
  local changes = require('aineo.changes')
  _G.shown_diffs = {}
  changes.begin_session({
    directory = directory,
    git = git_options,
    show_diff = function(diff)
      table.insert(_G.shown_diffs, diff)
      local showing = vim.fn.bufwinid(diff)
      if showing ~= -1 then
        return showing
      end
      return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
    end,
  })
  local pane = changes.pane_buffers()
  vim.api.nvim_win_set_buf(0, pane.files)
  vim.api.nvim_open_win(pane.commits, false, { split = 'below' })
]]

--- Begins the session in the child for `directory` and shows the pane
--- (`BEGIN_AND_SHOW`).
---
---@param directory string
---@param git_options? table
local function begin_and_show(directory, git_options)
  child.lua(BEGIN_AND_SHOW, { directory, git_options })
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

--- Makes the directory `name` beside the repository at `top` a worktree of
--- it on the new branch `branch`, from `start_point` when given, and
--- returns the worktree's top level.
---
---@param top string
---@param name string
---@param branch string
---@param start_point? string
---@return string worktree
local function add_worktree(top, name, branch, start_point)
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), name)
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', branch, worktree, start_point })
  return worktree
end

--- The Lua that counts, in the child, every call made to a function of the
--- git home but its watch, in `_G.git_asked`, and each answer once its
--- caller's `done` has run, in `_G.git_answered`, both by the function's
--- name.
local COUNT_GIT_READS = [[
  local git = require('aineo.git')
  _G.git_asked, _G.git_answered = {}, {}
  for name, operation in pairs(git) do
    if type(operation) == 'function' and name ~= 'watch_repository' then
      _G.git_asked[name], _G.git_answered[name] = 0, 0
      git[name] = function(...)
        _G.git_asked[name] = _G.git_asked[name] + 1
        local arguments = { ... }
        for index = 1, select('#', ...) do
          if type(arguments[index]) == 'function' then
            local done = arguments[index]
            arguments[index] = function(...)
              done(...)
              _G.git_answered[name] = _G.git_answered[name] + 1
            end
            break
          end
        end
        return operation(unpack(arguments, 1, select('#', ...)))
      end
    end
  end
]]

--- The Lua expression saying whether the child has asked the git home for
--- the worktrees `...` times at least, and every call it made to the home
--- has answered (`COUNT_GIT_READS`).
local READS_ANSWERED = [[(function(lists)
  for name, asked in pairs(_G.git_asked) do
    if _G.git_answered[name] ~= asked then
      return false
    end
  end
  return _G.git_answered.list_worktrees >= lists
end)(...)]]

--- Waits until the child has listed the worktrees `lists` times, once per
--- window when not given, and every read it asked of the git home has
--- answered (`COUNT_GIT_READS`), so that what the pane shows is what those
--- reads gave.
---
---@param lists? integer
local function wait_for_the_reads(lists)
  git_repo.wait_until('every read answered', function()
    return child.lua_get(READS_ANSWERED, { lists or 2 })
  end)
end

T['the editor’s own worktree'] = MiniTest.new_set()

T['the editor’s own worktree']['is shown alone, as ever, in a repository whose git directory is separate'] = function()
  local fixture = git_repo.directory('changesworktrees-separate')
  local top = vim.fs.joinpath(fixture, 'work')
  vim.fn.mkdir(top, 'p')
  local separate = vim.fs.joinpath(fixture, 'store.git')
  git_repo.git(top, { 'init', '--quiet', '--initial-branch=main', '--separate-git-dir', separate })
  git_repo.write(top, 'notes.txt', { 'one' })
  git_repo.commit_all(top, 'First')
  git_repo.write(top, 'notes.txt', { 'two' })
  child.lua(COUNT_GIT_READS)

  begin_and_show(top)

  wait_for_the_reads()
  eq(lines_of(FILES), { '  M notes.txt' })
end

--- Makes the repository `lib`, with one commit, a submodule of the
--- repository `super`, with one commit, both under the fixture
--- `git-<name>`; returns the submodule's checkout in `super` and the
--- fixture's directory.
---
---@param name string
---@return string checkout
---@return string fixture
local function create_submodule(name)
  local fixture = git_repo.directory(name)
  local lib, super = vim.fs.joinpath(fixture, 'lib'), vim.fs.joinpath(fixture, 'super')
  for _, top in ipairs({ lib, super }) do
    vim.fn.mkdir(top, 'p')
    git_repo.git(top, { 'init', '--quiet', '--initial-branch=main' })
    git_repo.write(top, 'notes.txt', { 'one' })
    git_repo.commit_all(top, 'First')
  end
  git_repo.git(
    super,
    { '-c', 'protocol.file.allow=always', 'submodule', 'add', '--quiet', lib, 'lib' }
  )
  git_repo.commit_all(super, 'The submodule')
  return vim.fs.joinpath(super, 'lib'), fixture
end

T['the editor’s own worktree']['is shown alone, as ever, in a submodule'] = function()
  local checkout = create_submodule('changesworktrees-submodule')
  git_repo.write(checkout, 'notes.txt', { 'two' })
  child.lua(COUNT_GIT_READS)

  begin_and_show(checkout)

  wait_for_the_reads()
  eq(lines_of(FILES), { '  M notes.txt' })
end

T['the editor’s own worktree']['is shown once, a linked one whose folder moved and left a link behind'] = function()
  local fixture = git_repo.directory('changesworktrees-moved')
  local before = vim.fs.joinpath(fixture, 'before')
  local top = vim.fs.joinpath(before, 'repo')
  vim.fn.mkdir(top, 'p')
  git_repo.git(top, { 'init', '--quiet', '--initial-branch=main' })
  git_repo.write(top, 'notes.txt', { 'one' })
  git_repo.commit_all(top, 'First')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'mine', vim.fs.joinpath(before, 'mine') })
  local after = vim.fs.joinpath(fixture, 'after')
  assert(vim.uv.fs_rename(before, after))
  assert(vim.uv.fs_symlink(after, before))
  local mine = vim.fs.joinpath(after, 'mine')
  git_repo.write(mine, 'notes.txt', { 'two' })
  child.lua(COUNT_GIT_READS)

  begin_and_show(mine)

  wait_for_the_reads()
  eq(
    lines_of(FILES),
    { '  M notes.txt', 'Worktree repo (main)', 'No files changed in this worktree' }
  )
end

T['the editor’s own worktree']['is not listed as a locked one whose .git is gone, its folder inside the top level'] = function()
  local top = git_repo.create('changesworktrees-locked-unlinked', {
    ['notes.txt'] = { 'one' },
    ['.gitignore'] = { '/worktrees/' },
  })
  git_repo.write(top, 'notes.txt', { 'two' })
  local agent = vim.fs.joinpath(top, 'worktrees', 'agent')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '--lock', '-b', 'agent', agent })
  assert(os.remove(vim.fs.joinpath(agent, '.git')))
  child.lua(COUNT_GIT_READS)

  begin_and_show(top)

  wait_for_the_reads()
  eq(lines_of(FILES), { '  M notes.txt' })
end

T['the editor’s own worktree']['in a submodule’s linked worktree lists the submodule’s checkout as another'] = function()
  local checkout, fixture = create_submodule('changesworktrees-submodule-linked')
  git_repo.write(checkout, 'notes.txt', { 'two' })
  local linked = vim.fs.joinpath(fixture, 'linked')
  git_repo.git(checkout, { 'worktree', 'add', '--quiet', '-b', 'linked', linked })
  child.lua(COUNT_GIT_READS)

  begin_and_show(linked)

  wait_for_the_reads()
  eq(
    lines_of(FILES),
    { 'No files changed on this session', 'Worktree lib (main)', '  M notes.txt' }
  )
end

T['the files window'] = MiniTest.new_set()

T['the files window']['lists the editor’s files first, as ever, then each other worktree’s under its heading'] = function()
  local top = git_repo.create('changesworktrees-files', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'agent.txt', { 'new' })

  begin_and_show(top)

  expect_lines(FILES, { '  M notes.txt', 'Worktree agent (agent)', '  ? agent.txt' })
end

T['the files window']['heads a detached worktree’s section so'] = function()
  local top = git_repo.create('changesworktrees-detached', { ['notes.txt'] = { 'one' } })
  local agent = vim.fs.joinpath(vim.fs.dirname(top), 'agent')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '--detach', agent })
  git_repo.write(agent, 'agent.txt', { 'new' })

  begin_and_show(top)

  expect_lines(
    FILES,
    { 'No files changed on this session', 'Worktree agent (detached)', '  ? agent.txt' }
  )
end

T['the files window']['lists another worktree with no shared history, every file new'] = function()
  local top = git_repo.create('changesworktrees-unrelated-files', { ['notes.txt'] = { 'one' } })
  local unrelated = vim.fs.joinpath(vim.fs.dirname(top), 'unrelated')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '--orphan', '-b', 'unrelated', unrelated })
  git_repo.write(unrelated, 'b.txt', { 'b' })
  git_repo.commit_all(unrelated, 'Its own')

  begin_and_show(top)

  expect_lines(
    FILES,
    { 'No files changed on this session', 'Worktree unrelated (unrelated)', '  A b.txt' }
  )
end

--- The Lua expression giving the colours of the child's buffer named
--- `...`: each as its line, first and last column, and group, all
--- 0-based, the last column end-exclusive.
local COLOURS_OF = [[(function(name)
  local marks = vim.api.nvim_buf_get_extmarks(vim.fn.bufnr(name), -1, 0, -1, { details = true })
  return vim.tbl_map(function(mark)
    return { mark[2], mark[3], mark[4].end_col, mark[4].hl_group }
  end, marks)
end)(...)]]

T['the files window']['colours another worktree’s heading as a note, and its files as the editor’s'] = function()
  local top = git_repo.create('changesworktrees-colours', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt', 'Worktree agent (agent)', '  M notes.txt' })

  local colours = child.lua_get(COLOURS_OF, { FILES })

  eq(colours, {
    { 0, 2, 13, 'AineoChangesModified' },
    { 1, 0, #'Worktree agent (agent)', 'AineoChangesNote' },
    { 2, 2, 13, 'AineoChangesModified' },
  })
end

T['the files window']['keeps the cursor on another worktree’s entry while one of the same path is listed above it'] = function()
  local top = git_repo.create('changesworktrees-cursor', { ['notes.txt'] = { 'one' } })
  local first = add_worktree(top, 'first', 'first')
  git_repo.write(first, 'notes.txt', { 'first' })
  local second = add_worktree(top, 'second', 'second')
  git_repo.write(second, 'notes.txt', { 'second' })
  begin_and_show(top)
  expect_lines(FILES, {
    'No files changed on this session',
    'Worktree first (first)',
    '  M notes.txt',
    'Worktree second (second)',
    '  M notes.txt',
  })
  child.lua('vim.api.nvim_win_set_cursor(0, { 5, 0 })')
  git_repo.write(top, 'a.txt', { 'a' })
  git_repo.write(top, 'b.txt', { 'b' })

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(FILES, {
    '  ? a.txt',
    '  ? b.txt',
    'Worktree first (first)',
    '  M notes.txt',
    'Worktree second (second)',
    '  M notes.txt',
  })
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)[1]'), 6)
end

T['a worktree with nothing changed'] = MiniTest.new_set({
  parametrize = {
    {
      FILES,
      {
        'No files changed on this session',
        'Worktree agent (agent)',
        'No files changed in this worktree',
      },
    },
    {
      COMMITS,
      { 'No commits on this session', 'Worktree agent (agent)', 'No commits in this worktree' },
    },
  },
})

T['a worktree with nothing changed']['says so under its heading in'] = function(name, expected)
  local top = git_repo.create('changesworktrees-nothing', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent', 'agent')

  begin_and_show(top)

  expect_lines(name, expected)
end

T['Enter'] = MiniTest.new_set()

--- Waits until the home has asked the child to show `count` diffs.
---
---@param count integer
local function wait_for_diffs(count)
  git_repo.wait_until(('%d diffs shown'):format(count), function()
    return child.lua_get('#_G.shown_diffs') >= count
  end)
end

--- The Lua expression giving the name and the lines of the diff buffer the
--- home asked the child to show `...`-th.
local SHOWN_DIFF = [[(function(index)
  local diff = _G.shown_diffs[index]
  return { name = vim.api.nvim_buf_get_name(diff), text = vim.api.nvim_buf_get_lines(diff, 0, -1, true) }
end)(...)]]

T['Enter']['on another worktree’s file shows its diff from that worktree’s base, neither the session’s nor a HEAD'] = function()
  local top = git_repo.create('changesworktrees-enter-base', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'two' })
  git_repo.commit_all(agent, 'The agent’s')
  git_repo.write(agent, 'notes.txt', { 'three' })
  git_repo.write(top, 'notes.txt', { 'main' })
  git_repo.write(top, 'main.txt', { 'main' })
  git_repo.commit_all(top, 'The editor’s')
  begin_and_show(top)
  expect_lines(
    FILES,
    { 'No files changed on this session', 'Worktree agent (agent)', '  M notes.txt' }
  )
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')

  child.type_keys('<CR>')

  wait_for_diffs(1)
  local shown = child.lua_get(SHOWN_DIFF, { 1 })
  eq({ shown.text[#shown.text - 1], shown.text[#shown.text] }, { '-one', '+three' })
end

T['Enter']['on another worktree’s file shows its diff, named for the worktree'] = function()
  local top, base = git_repo.create('changesworktrees-enter-file', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local before = git_repo.git(top, { 'rev-parse', base .. ':notes.txt' })
  local after = git_repo.git(agent, { 'hash-object', 'notes.txt' })
  begin_and_show(top)
  expect_lines(
    FILES,
    { 'No files changed on this session', 'Worktree agent (agent)', '  M notes.txt' }
  )
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(child.lua_get(SHOWN_DIFF, { 1 }), {
    name = ('aineo://worktree%s//diff/notes.txt'):format(agent),
    text = {
      'diff --git a/notes.txt b/notes.txt',
      ('index %s..%s 100644'):format(before, after),
      '--- a/notes.txt',
      '+++ b/notes.txt',
      '@@ -1 +1 @@',
      '-one',
      '+agent',
    },
  })
end

T['Enter']['on another worktree’s commit shows that commit’s diff, named for the worktree'] = function()
  local top = git_repo.create('changesworktrees-enter-commit', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  begin_and_show(top)
  expect_lines(COMMITS, {
    'No commits on this session',
    'Worktree agent (agent)',
    commit:sub(1, 7) .. ' The agent’s',
  })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { COMMITS })
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')

  child.type_keys('<CR>')

  wait_for_diffs(1)
  local shown = child.lua_get(SHOWN_DIFF, { 1 })
  eq({
    name = shown.name,
    first = shown.text[1],
    last = { shown.text[#shown.text - 1], shown.text[#shown.text] },
  }, {
    name = ('aineo://worktree%s//commit/%s'):format(agent, commit),
    first = 'commit ' .. commit,
    last = { '-one', '+agent' },
  })
end

--- The Lua that counts, in the child, the diffs the git home is asked for,
--- in `_G.diffs_asked`, and keeps every notification from then on in
--- `_G.messages` rather than showing it.
local COUNT_DIFFS_AND_MESSAGES = [[
  local git = require('aineo.git')
  _G.diffs_asked = 0
  for _, name in ipairs({ 'file_diff', 'commit_diff' }) do
    local read = git[name]
    git[name] = function(...)
      _G.diffs_asked = _G.diffs_asked + 1
      return read(...)
    end
  end
  _G.messages = {}
  vim.notify = function(message)
    table.insert(_G.messages, message)
  end
]]

T['Enter']['on another worktree’s heading does nothing and says nothing'] = function()
  local top = git_repo.create('changesworktrees-enter-heading', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  child.lua(COUNT_DIFFS_AND_MESSAGES)
  begin_and_show(top)
  expect_lines(
    FILES,
    { 'No files changed on this session', 'Worktree agent (agent)', '  M notes.txt' }
  )
  child.lua('vim.api.nvim_win_set_cursor(0, { 2, 0 })')
  child.type_keys('<CR>')

  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')
  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(child.lua_get('{ _G.diffs_asked, _G.messages }'), { 1, {} })
end

T['Enter']['on one path in two worktrees shows two diff buffers, each its worktree’s'] = function()
  local top = git_repo.create('changesworktrees-enter-two', { ['notes.txt'] = { 'one' } })
  local first = add_worktree(top, 'first', 'first')
  git_repo.write(first, 'notes.txt', { 'first' })
  local second = add_worktree(top, 'second', 'second')
  git_repo.write(second, 'notes.txt', { 'second' })
  begin_and_show(top)
  expect_lines(FILES, {
    'No files changed on this session',
    'Worktree first (first)',
    '  M notes.txt',
    'Worktree second (second)',
    '  M notes.txt',
  })
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')
  child.type_keys('<CR>')
  wait_for_diffs(1)

  child.lua('vim.api.nvim_win_set_cursor(0, { 5, 0 })')
  child.type_keys('<CR>')

  wait_for_diffs(2)
  local last_line = 'vim.api.nvim_buf_get_lines(_G.shown_diffs[...], -2, -1, true)[1]'
  eq({
    distinct = child.lua_get('_G.shown_diffs[1] ~= _G.shown_diffs[2]'),
    first = child.lua_get(last_line, { 1 }),
    second = child.lua_get(last_line, { 2 }),
  }, { distinct = true, first = '+first', second = '+second' })
end

T['Enter']['on two worktrees’ files whose top level and path join alike shows two diff buffers'] = function()
  local fixture = git_repo.directory('changesworktrees-enter-joined')
  local top = vim.fs.joinpath(fixture, 'repo')
  vim.fn.mkdir(top, 'p')
  git_repo.git(top, { 'init', '--quiet', '--initial-branch=main' })
  git_repo.write(top, '.gitignore', { '/diff/' })
  git_repo.write(top, 'sub/diff/x.txt', { 'one' })
  git_repo.commit_all(top, 'First')
  git_repo.write(top, 'sub/diff/x.txt', { 'main' })
  local nested = vim.fs.joinpath(top, 'diff', 'sub')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'nested', nested })
  git_repo.write(nested, 'x.txt', { 'nested' })
  local editor = vim.fs.joinpath(fixture, 'editor')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'editor', editor })
  begin_and_show(editor)
  expect_lines(FILES, {
    'No files changed on this session',
    'Worktree repo (main)',
    '  M sub/diff/x.txt',
    'Worktree sub (nested)',
    '  ? x.txt',
  })
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')
  child.type_keys('<CR>')
  wait_for_diffs(1)

  child.lua('vim.api.nvim_win_set_cursor(0, { 5, 0 })')
  child.type_keys('<CR>')

  wait_for_diffs(2)
  eq(child.lua_get('_G.shown_diffs[1] ~= _G.shown_diffs[2]'), true)
end

--- How long a case waits for the watch to call back for one change before it
--- makes the change again: far longer than a call takes.
local RETRY_MS = 3000

--- The file `watch_live()` writes at the top level of a repository.
local LIVE_MARKER = 'live.txt'

--- Returns once the watch the pane started on the repository at `top` is
--- seen to be live: `LIVE_MARKER`, written there again every `RETRY_MS`, is
--- listed in the files window, the editor's only file, above the lines
--- `after`, none when not given. On macOS, libuv starts a watch's event
--- stream after the watch has started, and a change made before the stream
--- runs is never seen.
---
---@param top string
---@param after? string[]
local function watch_live(top, after)
  local expected = vim.list_extend({ '  ? ' .. LIVE_MARKER }, after or {})
  for _ = 1, git_repo.PATIENCE_MS / RETRY_MS do
    git_repo.write(top, LIVE_MARKER, { 'live' })
    if
      vim.wait(RETRY_MS, function()
        return vim.deep_equal(lines_of(FILES), expected)
      end, 10)
    then
      return
    end
  end
  eq(lines_of(FILES), expected)
end

T['the worktrees followed'] = MiniTest.new_set()

T['the worktrees followed']['show one added after the pane first showed, once the watch calls back'] = function()
  local top = git_repo.create('changesworktrees-added', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  watch_live(top)

  add_worktree(top, 'agent', 'agent')

  expect_lines(
    FILES,
    { '  ? ' .. LIVE_MARKER, 'Worktree agent (agent)', 'No files changed in this worktree' }
  )
end

T['the worktrees followed']['show a commit made in another worktree, once the watch calls back'] = function()
  local top = git_repo.create('changesworktrees-commit-followed', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  begin_and_show(top)
  watch_live(top, { 'Worktree agent (agent)', 'No files changed in this worktree' })

  local commit = git_repo.commit_all(agent, 'The agent’s')

  expect_lines(COMMITS, {
    'No commits on this session',
    'Worktree agent (agent)',
    commit:sub(1, 7) .. ' The agent’s',
  })
end

T['the worktrees followed']['drop one removed, once the watch calls back, its diff left as it was'] = function()
  local top = git_repo.create('changesworktrees-removed', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  begin_and_show(top)
  watch_live(top, { 'Worktree agent (agent)', '  M notes.txt' })
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')
  child.type_keys('<CR>')
  wait_for_diffs(1)
  local diff = child.lua_get(SHOWN_DIFF, { 1 })

  git_repo.git(top, { 'worktree', 'remove', '--force', agent })

  expect_lines(FILES, { '  ? ' .. LIVE_MARKER })
  eq(child.lua_get(SHOWN_DIFF, { 1 }), diff)
end

--- The git the suites run, by its absolute path, for the stand-ins that
--- run it in their turn.
local REAL_GIT = vim.fn.exepath('git')

--- Writes a stand-in for git under the fixture `git-<name>` that fails
--- with `fatal: broken`, as git words a failure, every `subcommand` it is
--- asked to run in the directory `broken` while the file `<stand-in>.broken`
--- exists, and runs git otherwise; returns its path and the switch file's.
---
---@param name string
---@param broken string
---@param subcommand string
---@return string stand_in
---@return string switch
local function breakable_git_in(name, broken, subcommand)
  local stand_in = git_repo.script(name, 'git', {
    ('case " $* " in *" -C %s "*" %s "*) [ -f "$0.broken" ] && { echo "fatal: broken" >&2; exit 128; } ;; esac'):format(
      broken,
      subcommand
    ),
    ('exec %s "$@"'):format(REAL_GIT),
  })
  return stand_in, stand_in .. '.broken'
end

--- Makes the stand-in whose switch file is `switch` fail from now on
--- (`breakable_git_in()`).
---
---@param switch string
local function turn_on(switch)
  assert(vim.fn.writefile({}, switch) == 0, 'cannot write ' .. switch)
end

T['a diff of another worktree that fails'] = MiniTest.new_set()

T['a diff of another worktree that fails']['is told naming its worktree'] = function()
  local top = git_repo.create('changesworktrees-diff-failed', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local stand_in, switch = breakable_git_in('changesworktrees-diff-failed', agent, 'diff')
  child.lua(COUNT_DIFFS_AND_MESSAGES)
  begin_and_show(top, { executable = stand_in })
  expect_lines(FILES, { '  M notes.txt', 'Worktree agent (agent)', '  M notes.txt' })
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')
  turn_on(switch)

  child.type_keys('<CR>')

  git_repo.wait_until('a message told', function()
    return child.lua_get('#_G.messages') > 0
  end)
  eq(child.lua_get('_G.messages'), {
    'aineo: the diff of notes.txt in the worktree agent could not be read: fatal: broken',
  })
end

T['a worktree whose read fails'] = MiniTest.new_set({
  parametrize = {
    { 'its repository found', 'rev-parse' },
    { 'its base read', 'merge-base' },
    { 'its files listed', 'ls-files' },
  },
})

T['a worktree whose read fails']['shows git’s words under its heading, the other worktrees as ever, failing'] = function(
  _,
  subcommand
)
  local top = git_repo.create('changesworktrees-failed', { ['notes.txt'] = { 'one' } })
  local first = add_worktree(top, 'first', 'first')
  local second = add_worktree(top, 'second', 'second')
  git_repo.write(second, 'notes.txt', { 'second' })
  local stand_in, switch = breakable_git_in('changesworktrees-failed', first, subcommand)
  turn_on(switch)

  begin_and_show(top, { executable = stand_in })

  expect_lines(FILES, {
    'No files changed on this session',
    'Worktree first (first)',
    'The last refresh failed: fatal: broken',
    'Worktree second (second)',
    '  M notes.txt',
  })
end

T['a worktree whose later read fails'] = MiniTest.new_set()

T['a worktree whose later read fails']['keeps the list it showed, under git’s words'] = function()
  local top = git_repo.create('changesworktrees-failed-later', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local stand_in, switch = breakable_git_in('changesworktrees-failed-later', agent, 'ls-files')
  begin_and_show(top, { executable = stand_in })
  expect_lines(
    FILES,
    { 'No files changed on this session', 'Worktree agent (agent)', '  M notes.txt' }
  )
  turn_on(switch)

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(FILES, {
    'No files changed on this session',
    'Worktree agent (agent)',
    'The last refresh failed: fatal: broken',
    '  M notes.txt',
  })
end

T['a worktree whose later read fails']['keeps the list it showed, under git’s words, when the editor’s branch cannot be read'] = function()
  local top = git_repo.create('changesworktrees-comparison-failed', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local stand_in, switch =
    breakable_git_in('changesworktrees-comparison-failed', top, 'symbolic-ref')
  begin_and_show(top, { executable = stand_in })
  expect_lines(
    FILES,
    { 'No files changed on this session', 'Worktree agent (agent)', '  M notes.txt' }
  )
  turn_on(switch)

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(FILES, {
    'No files changed on this session',
    'Worktree agent (agent)',
    'The last refresh failed: fatal: broken',
    '  M notes.txt',
  })
end

T['a list of worktrees that fails'] = MiniTest.new_set({
  parametrize = {
    { FILES, '  M notes.txt' },
    { COMMITS, 'No commits on this session' },
  },
})

T['a list of worktrees that fails']['leaves the editor’s lines as ever, then says so in git’s words, in'] = function(
  name,
  own_line
)
  local top = git_repo.create('changesworktrees-list-failed', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local stand_in, switch = breakable_git_in('changesworktrees-list-failed', top, 'worktree')
  turn_on(switch)

  begin_and_show(top, { executable = stand_in })

  expect_lines(name, { own_line, 'The other worktrees could not be listed: fatal: broken' })
end

T['a later list of worktrees that fails'] = MiniTest.new_set()

T['a later list of worktrees that fails']['keeps the worktrees it showed, under the line saying so'] = function()
  local top = git_repo.create('changesworktrees-list-failed-later', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local stand_in, switch = breakable_git_in('changesworktrees-list-failed-later', top, 'worktree')
  begin_and_show(top, { executable = stand_in })
  expect_lines(
    FILES,
    { 'No files changed on this session', 'Worktree agent (agent)', '  M notes.txt' }
  )
  turn_on(switch)

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(FILES, {
    'No files changed on this session',
    'The other worktrees could not be listed: fatal: broken',
    'Worktree agent (agent)',
    '  M notes.txt',
  })
end

--- Writes a stand-in for git under the fixture `git-<name>` that, asked
--- for an `ls-files` in the directory `held`, writes the file
--- `<stand-in>.waiting` and waits for the file `<stand-in>.gate` before it
--- runs git, as it runs git at once for anything else; returns its path,
--- the waiting file's and the gate's.
---
---@param name string
---@param held string
---@return string stand_in
---@return string waiting
---@return string gate
local function git_held_in(name, held)
  local stand_in = git_repo.script(name, 'git', {
    ('case " $* " in *" -C %s "*" ls-files "*) : > "$0.waiting"; while [ ! -f "$0.gate" ]; do sleep 0.05; done ;; esac'):format(
      held
    ),
    ('exec %s "$@"'):format(REAL_GIT),
  })
  return stand_in, stand_in .. '.waiting', stand_in .. '.gate'
end

T['a worktree removed while it is read'] = MiniTest.new_set()

--- The Lua that counts, in the child, the reads of changed files the git
--- home has answered, in `_G.file_reads_answered`, each once its caller's
--- `done` has run.
local COUNT_FILE_READS = [[
  local git = require('aineo.git')
  local changed_files = git.changed_files
  _G.file_reads_answered = 0
  git.changed_files = function(found, base, done, options)
    return changed_files(found, base, function(...)
      done(...)
      _G.file_reads_answered = _G.file_reads_answered + 1
    end, options)
  end
]]

T['a worktree removed while it is read']['is dropped, not told as a failure'] = function()
  local top = git_repo.create('changesworktrees-removed-meanwhile', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  local stand_in, waiting, gate = git_held_in('changesworktrees-removed-meanwhile', agent)
  child.lua(COUNT_FILE_READS)
  begin_and_show(top, { executable = stand_in })
  git_repo.wait_until('the worktree’s files asked for', function()
    return vim.uv.fs_stat(waiting) ~= nil
  end)
  vim.fn.delete(agent, 'rf')

  assert(vim.fn.writefile({}, gate) == 0, 'cannot write ' .. gate)

  git_repo.wait_until('the editor’s and the worktree’s files read', function()
    return child.lua_get('_G.file_reads_answered') == 2
  end)
  eq(lines_of(FILES), { 'No files changed on this session' })
end

T['the reads'] = MiniTest.new_set()

--- Writes a stand-in for git under the fixture `git-<name>` that runs
--- every `ls-files` — the last git of each worktree's read of the files
--- window — between a line `start` and a line `end` it appends to the file
--- `<stand-in>.log`, after a pause of half a second; returns its path and
--- the log's.
---
---@param name string
---@return string stand_in
---@return string log
local function logging_git(name)
  local stand_in = git_repo.script(name, 'git', {
    'case " $* " in',
    ('  *" ls-files "*) echo start >> "$0.log"; sleep 0.5; %s "$@"; code=$?; echo end >> "$0.log"; exit $code ;;'):format(
      REAL_GIT
    ),
    'esac',
    ('exec %s "$@"'):format(REAL_GIT),
  })
  return stand_in, stand_in .. '.log'
end

T['the reads']['of a window stay one at a time with several worktrees, one asked meanwhile once more after'] = function()
  local top = git_repo.create('changesworktrees-one-at-a-time', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'first', 'first')
  add_worktree(top, 'second', 'second')
  local stand_in, log = logging_git('changesworktrees-one-at-a-time')
  child.lua(COUNT_GIT_READS)
  begin_and_show(top, { executable = stand_in, system_name = 'Linux' })
  git_repo.wait_until('the first read started', function()
    return vim.uv.fs_stat(log) ~= nil
  end)

  child.lua("require('aineo.changes').refresh_shown_pane()")
  child.lua("require('aineo.changes').refresh_shown_pane()")

  wait_for_the_reads(4)
  eq({ vim.fn.readfile(log), child.lua_get('_G.git_asked.changed_files') }, {
    {
      'start',
      'end',
      'start',
      'end',
      'start',
      'end',
      'start',
      'end',
      'start',
      'end',
      'start',
      'end',
    },
    6,
  })
end

--- Writes a stand-in for git under the fixture `git-<name>` that, while the
--- file `<stand-in>.<folder>.hold` exists, holds every `subcommand` in
--- each worktree of `held`, by its top level, `<folder>` the top level's
--- last part: it writes `<stand-in>.<folder>.waiting` and waits for
--- `<stand-in>.<folder>.gate` before it runs git, as it runs git at once
--- for anything else; returns its path.
---
---@param name string
---@param subcommand string
---@param held string[]
---@return string stand_in
local function git_holding(name, subcommand, held)
  local lines = {}
  for _, top in ipairs(held) do
    local files = '"$0.' .. vim.fs.basename(top)
    table.insert(
      lines,
      ('case " $* " in *" -C %s "*" %s "*) if [ -f %s.hold" ]; then : > %s.waiting"; while [ ! -f %s.gate" ]; do sleep 0.05; done; fi ;; esac'):format(
        top,
        subcommand,
        files,
        files,
        files
      )
    )
  end
  table.insert(lines, ('exec %s "$@"'):format(REAL_GIT))
  return git_repo.script(name, 'git', lines)
end

--- Writes the empty file `path`.
---
---@param path string
local function touch(path)
  assert(vim.fn.writefile({}, path) == 0, 'cannot write ' .. path)
end

T['the reads']['of the editor’s own list, asked during the other worktrees’, show it before the next worktree is read'] = function()
  local top = git_repo.create('changesworktrees-own-between', { ['notes.txt'] = { 'one' } })
  local first = add_worktree(top, 'first', 'first')
  local second = add_worktree(top, 'second', 'second')
  local stand_in = git_holding('changesworktrees-own-between', 'ls-files', { first, second })
  child.lua(COUNT_GIT_READS)
  begin_and_show(top, { executable = stand_in })
  wait_for_the_reads()
  touch(stand_in .. '.first.hold')
  touch(stand_in .. '.second.hold')
  child.lua("require('aineo.changes').refresh_shown_pane()")
  git_repo.wait_until('the first worktree’s files asked for', function()
    return vim.uv.fs_stat(stand_in .. '.first.waiting') ~= nil
  end)
  git_repo.write(top, 'saved.txt', { 'saved' })
  child.lua("require('aineo.changes').refresh_shown_pane()")

  touch(stand_in .. '.first.gate')

  git_repo.wait_until('the second worktree’s files asked for', function()
    return vim.uv.fs_stat(stand_in .. '.second.waiting') ~= nil
  end)
  local shown = lines_of(FILES)[1]
  touch(stand_in .. '.second.gate')
  eq(shown, '  ? saved.txt')
end

--- The Lua that replaces, in the child, the git home's watch with one that
--- calls back only when a case calls `_G.on_change(failure, change)`, so
--- that only what a case asks for reads the pane.
local WATCH_IN_HAND = [[
  require('aineo.git').watch_repository = function(_, on_change)
    _G.on_change = on_change
    return { stop = function() end, watches_subdirectories = true }
  end
]]

T['the reads']['of the editor’s commits, asked during a read, stay asked when a later call asks without them'] = function()
  local top = git_repo.create('changesworktrees-own-asked', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  local stand_in = git_holding('changesworktrees-own-asked', 'merge-base', { agent })
  child.lua(WATCH_IN_HAND)
  begin_and_show(top, { executable = stand_in })
  expect_lines(
    COMMITS,
    { 'No commits on this session', 'Worktree agent (agent)', 'No commits in this worktree' }
  )
  touch(stand_in .. '.agent.hold')
  child.lua('_G.on_change(nil, { files_changed = false, branch_moved = false })')
  git_repo.wait_until('the other worktree’s base asked for', function()
    return vim.uv.fs_stat(stand_in .. '.agent.waiting') ~= nil
  end)
  local commit = git_repo.commit_all(top, 'Mine')
  child.lua('_G.on_change(nil, { files_changed = true, branch_moved = true })')
  child.lua('_G.on_change(nil, { files_changed = true, branch_moved = false })')
  vim.fn.delete(stand_in .. '.agent.hold')

  touch(stand_in .. '.agent.gate')

  expect_lines(COMMITS, {
    commit:sub(1, 7) .. ' Mine',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })
end

--- Writes a stand-in for git under the fixture `git-<name>` that appends
--- the arguments of every git it runs, one line each, to the file
--- `<stand-in>.log`; returns its path and the log's.
---
---@param name string
---@return string stand_in
---@return string log
local function git_logging_every_run(name)
  local stand_in = git_repo.script(name, 'git', {
    'printf "%s\\n" "$*" >> "$0.log"',
    ('exec %s "$@"'):format(REAL_GIT),
  })
  return stand_in, stand_in .. '.log'
end

--- How many lines of the file `log` hold `text`.
---
---@param log string
---@param text string
---@return integer
local function lines_holding(log, text)
  return #vim.tbl_filter(function(line)
    return line:find(text, 1, true) ~= nil
  end, vim.fn.readfile(log))
end

T['the reads']['of a window read the editor’s branch once, however many worktrees'] = function()
  local top = git_repo.create('changesworktrees-comparison-once', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'first', 'first')
  add_worktree(top, 'second', 'second')
  add_worktree(top, 'third', 'third')
  local stand_in, log = git_logging_every_run('changesworktrees-comparison-once')
  child.lua(WATCH_IN_HAND)
  child.lua(COUNT_GIT_READS)

  begin_and_show(top, { executable = stand_in })

  wait_for_the_reads()
  eq(lines_holding(log, '@{upstream}'), 2)
end

T['the reads']['of a window read nothing of the editor’s branch with no other worktree'] = function()
  local top = git_repo.create('changesworktrees-comparison-none', { ['notes.txt'] = { 'one' } })
  local stand_in, log = git_logging_every_run('changesworktrees-comparison-none')
  child.lua(WATCH_IN_HAND)
  child.lua(COUNT_GIT_READS)

  begin_and_show(top, { executable = stand_in })

  wait_for_the_reads()
  eq(lines_holding(log, '@{upstream}'), 0)
end

T['the commits window'] = MiniTest.new_set()

T['the commits window']['no longer lists another worktree’s commit once the editor’s branch holds it, its base read again'] = function()
  local top = git_repo.create('changesworktrees-base-again', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  begin_and_show(top)
  expect_lines(
    COMMITS,
    { 'No commits on this session', 'Worktree agent (agent)', commit:sub(1, 7) .. ' The agent’s' }
  )
  git_repo.git(top, { 'merge', '--quiet', '--ff-only', 'agent' })

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(COMMITS, {
    commit:sub(1, 7) .. ' The agent’s',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })
end

T['the commits window']['lists another worktree with no shared history, every commit its own'] = function()
  local top = git_repo.create('changesworktrees-unrelated-commits', { ['notes.txt'] = { 'one' } })
  local unrelated = vim.fs.joinpath(vim.fs.dirname(top), 'unrelated')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '--orphan', '-b', 'unrelated', unrelated })
  git_repo.write(unrelated, 'b.txt', { 'b' })
  local commit = git_repo.commit_all(unrelated, 'Its own')

  begin_and_show(top)

  expect_lines(COMMITS, {
    'No commits on this session',
    'Worktree unrelated (unrelated)',
    commit:sub(1, 7) .. ' Its own',
  })
end

T['the commits window']['lists the editor’s commits first, as ever, then each other worktree’s under its heading'] = function()
  local top = git_repo.create('changesworktrees-commits', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'agent.txt', { 'new' })
  local commit = git_repo.commit_all(agent, 'The agent’s')

  begin_and_show(top)

  expect_lines(COMMITS, {
    'No commits on this session',
    'Worktree agent (agent)',
    commit:sub(1, 7) .. ' The agent’s',
  })
end

return T
