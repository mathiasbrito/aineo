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
--- directory `...`, with the git options and the working branch that
--- follow, and shows the pane's two buffers there: the files buffer in the
--- current window, the commits buffer in a window below it. Every buffer
--- the home asks to show as a diff is kept in `_G.shown_diffs` and shown in
--- a window of its own at the bottom, the cursor left where it is.
local BEGIN_AND_SHOW = [[
  local directory, git_options, working_branch = ...
  local changes = require('aineo.changes')
  _G.shown_diffs = {}
  changes.begin_session({
    directory = directory,
    git = git_options,
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

--- Begins the session in the child for `directory` with the setting
--- `changes.working_branch` set to `working_branch`, and shows the pane
--- (`BEGIN_AND_SHOW`).
---
---@param directory string
---@param working_branch string
---@param git_options? table
local function begin_and_show_working_on(directory, working_branch, git_options)
  child.lua(BEGIN_AND_SHOW, { directory, git_options or {}, working_branch })
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

--- Waits until the child has listed the worktrees `lists` times, once when
--- not given, which the commits window does at each of its reads, and every
--- read it asked of the git home has answered (`COUNT_GIT_READS`), so that
--- what the pane shows is what those reads gave.
---
---@param lists? integer
local function wait_for_the_reads(lists)
  git_repo.wait_until('every read answered', function()
    return child.lua_get(READS_ANSWERED, { lists or 1 })
  end)
end

--- Makes the window showing the child's buffer named `name` the current one.
---
---@param name string
local function enter_window_of(name)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { name })
end

--- Makes the commits window the current one and puts its cursor on line
--- `line`, as the user's keys do.
---
---@param line integer
local function go_to_commits_line(line)
  git_repo.wait_until('the commits window lists line ' .. line, function()
    return child.lua_get('vim.api.nvim_buf_line_count(vim.fn.bufnr(...))', { COMMITS }) >= line
  end)
  enter_window_of(COMMITS)
  child.type_keys(line .. 'G')
end

--- Puts the cursor of the files window, entered, on line `line`.
---
---@param line integer
local function go_to_files_line(line)
  enter_window_of(FILES)
  child.lua('vim.api.nvim_win_set_cursor(0, { ..., 0 })', { line })
end

--- The commits window's lines for an editor with no commit of its own, then
--- the lines `listed` for its worktrees.
---
---@param listed string[]
---@return string[]
local function commits_then(listed)
  return vim.list_extend({ 'Uncommitted', 'Session work', 'No commits on this session' }, listed)
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
  eq(lines_of(FILES), { 'Files in: Session work', '  M notes.txt' })
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
  eq(lines_of(FILES), { 'Files in: Session work', '  M notes.txt' })
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
  eq(lines_of(FILES), { 'Files in: Session work', '  M notes.txt' })
  eq(lines_of(COMMITS), commits_then({ 'Worktree repo (main)', 'No commits in this worktree' }))
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
  eq(lines_of(COMMITS), commits_then({}))
end

T['the editor’s own worktree']['in a submodule’s linked worktree lists the submodule’s checkout as another'] = function()
  local checkout, fixture = create_submodule('changesworktrees-submodule-linked')
  git_repo.write(checkout, 'notes.txt', { 'two' })
  local linked = vim.fs.joinpath(fixture, 'linked')
  git_repo.git(checkout, { 'worktree', 'add', '--quiet', '-b', 'linked', linked })
  child.lua(COUNT_GIT_READS)

  begin_and_show(linked)

  wait_for_the_reads()
  expect_lines(
    COMMITS,
    commits_then({
      'Landed in origin/main',
      'Nothing landed in origin/main on this session',
      'Worktree lib (main)',
      'No commits in this worktree',
    })
  )
  go_to_commits_line(6)
  expect_lines(FILES, { 'Files in: Worktree lib (main)', '  M notes.txt' })
end

T['the files window'] = MiniTest.new_set()

T['the files window']['heads a detached worktree’s whole change so'] = function()
  local top = git_repo.create('changesworktrees-detached', { ['notes.txt'] = { 'one' } })
  local agent = vim.fs.joinpath(vim.fs.dirname(top), 'agent')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '--detach', agent })
  git_repo.write(agent, 'agent.txt', { 'new' })
  begin_and_show(top)
  expect_lines(
    COMMITS,
    commits_then({ 'Worktree agent (detached)', 'No commits in this worktree' })
  )

  go_to_commits_line(4)

  expect_lines(FILES, { 'Files in: Worktree agent (detached)', '  ? agent.txt' })
end

T['the files window']['lists another worktree with no shared history, every file new'] = function()
  local top = git_repo.create('changesworktrees-unrelated-files', { ['notes.txt'] = { 'one' } })
  local unrelated = vim.fs.joinpath(vim.fs.dirname(top), 'unrelated')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '--orphan', '-b', 'unrelated', unrelated })
  git_repo.write(unrelated, 'b.txt', { 'b' })
  git_repo.commit_all(unrelated, 'Its own')
  begin_and_show(top)
  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })

  go_to_commits_line(4)

  expect_lines(FILES, { 'Files in: Worktree unrelated (unrelated)', '  A b.txt' })
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

T['the files window']['colours the first line of another worktree’s whole change as a filter, and its files as the editor’s'] = function()
  local top = git_repo.create('changesworktrees-colours', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  begin_and_show(top)
  expect_lines(COMMITS, commits_then({ 'Worktree agent (agent)', 'No commits in this worktree' }))
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })

  local colours = child.lua_get(COLOURS_OF, { FILES })

  eq(colours, {
    { 0, 0, #'Files in: Worktree agent (agent)', 'AineoChangesFilter' },
    { 1, 2, 13, 'AineoChangesModified' },
  })
end

T['a worktree’s heading'] = MiniTest.new_set()

T['a worktree’s heading']['is coloured as a note in the commits window'] = function()
  local top = git_repo.create('changesworktrees-heading-colours', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent', 'agent')
  begin_and_show(top)
  expect_lines(COMMITS, commits_then({ 'Worktree agent (agent)', 'No commits in this worktree' }))

  local colours = child.lua_get(COLOURS_OF, { COMMITS })

  eq(colours, {
    { 0, 0, #'Uncommitted', 'AineoChangesFilter' },
    { 1, 0, #'Session work', 'AineoChangesFilter' },
    { 2, 0, #'No commits on this session', 'AineoChangesNote' },
    { 3, 0, #'Worktree agent (agent)', 'AineoChangesNote' },
    { 4, 0, #'No commits in this worktree', 'AineoChangesNote' },
  })
end

T['the files window']['keeps the cursor on its entry when the same filter is read again'] = function()
  local top = git_repo.create('changesworktrees-cursor', {
    ['a.txt'] = { 'one' },
    ['b.txt'] = { 'one' },
    ['c.txt'] = { 'one' },
  })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'b.txt', { 'agent' })
  git_repo.write(agent, 'c.txt', { 'agent' })
  begin_and_show(top)
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M b.txt', '  M c.txt' })
  go_to_files_line(3)
  git_repo.write(agent, 'a.txt', { 'agent' })

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M a.txt', '  M b.txt', '  M c.txt' })
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)[1]'), 4)
end

T['a worktree with nothing changed'] = MiniTest.new_set()

T['a worktree with nothing changed']['says so under its heading in the commits window'] = function()
  local top = git_repo.create('changesworktrees-nothing', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent', 'agent')

  begin_and_show(top)

  expect_lines(COMMITS, commits_then({ 'Worktree agent (agent)', 'No commits in this worktree' }))
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
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })
  go_to_files_line(2)

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
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })
  go_to_files_line(2)

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

T['Enter']['on another worktree’s file moves the cursor to its diff'] = function()
  local top = git_repo.create('changesworktrees-enter-cursor', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  begin_and_show(top)
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })
  go_to_files_line(2)

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(
    child.lua_get('vim.api.nvim_buf_get_name(0)'),
    ('aineo://worktree%s//diff/notes.txt'):format(agent)
  )
end

T['Enter']['on another worktree’s commit shows that commit’s diff, named for the worktree'] = function()
  local top = git_repo.create('changesworktrees-enter-commit', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  begin_and_show(top)
  expect_lines(
    COMMITS,
    commits_then({ 'Worktree agent (agent)', commit:sub(1, 7) .. ' The agent’s' })
  )
  enter_window_of(COMMITS)
  child.lua('vim.api.nvim_win_set_cursor(0, { 5, 0 })')

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

T['Enter']['on another worktree’s heading shows its whole change from its base, new files included, named for the worktree'] = function()
  local top = git_repo.create('changesworktrees-enter-heading', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  git_repo.write(agent, 'new.txt', { 'new' })
  begin_and_show(top)
  expect_lines(COMMITS, commits_then({ 'Worktree agent (agent)', 'No commits in this worktree' }))
  go_to_commits_line(4)

  child.type_keys('<CR>')

  wait_for_diffs(1)
  local shown = child.lua_get(SHOWN_DIFF, { 1 })
  eq({
    name = shown.name,
    headers = vim.tbl_filter(function(line)
      return vim.startswith(line, 'diff --git')
    end, shown.text),
  }, {
    name = ('aineo://worktree%s//since-base'):format(agent),
    headers = { 'diff --git a/new.txt b/new.txt', 'diff --git a/notes.txt b/notes.txt' },
  })
end

T['Enter']['on a file under another worktree’s commit shows the commit’s header and that file’s change, named for the worktree and the commit'] = function()
  local top = git_repo.create('changesworktrees-enter-commit-file', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  git_repo.write(agent, 'notes.txt', { 'later' })
  begin_and_show(top)
  expect_lines(
    COMMITS,
    commits_then({ 'Worktree agent (agent)', commit:sub(1, 7) .. ' The agent’s' })
  )
  go_to_commits_line(5)
  expect_lines(FILES, {
    'Files in: ' .. commit:sub(1, 7) .. ' The agent’s (worktree agent)',
    '  M notes.txt',
  })
  go_to_files_line(2)

  child.type_keys('<CR>')

  wait_for_diffs(1)
  local shown = child.lua_get(SHOWN_DIFF, { 1 })
  eq({
    name = shown.name,
    first = shown.text[1],
    last = { shown.text[#shown.text - 1], shown.text[#shown.text] },
  }, {
    name = ('aineo://worktree%s//commit/%s/notes.txt'):format(agent, commit),
    first = 'commit ' .. commit,
    last = { '-one', '+agent' },
  })
end

T['Enter']['on one path in two worktrees shows two diff buffers, each its worktree’s'] = function()
  local top = git_repo.create('changesworktrees-enter-two', { ['notes.txt'] = { 'one' } })
  local first = add_worktree(top, 'first', 'first')
  git_repo.write(first, 'notes.txt', { 'first' })
  local second = add_worktree(top, 'second', 'second')
  git_repo.write(second, 'notes.txt', { 'second' })
  begin_and_show(top)
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree first (first)', '  M notes.txt' })
  go_to_files_line(2)
  child.type_keys('<CR>')
  wait_for_diffs(1)

  go_to_commits_line(6)
  expect_lines(FILES, { 'Files in: Worktree second (second)', '  M notes.txt' })
  go_to_files_line(2)
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
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree repo (main)', '  M sub/diff/x.txt' })
  go_to_files_line(2)
  child.type_keys('<CR>')
  wait_for_diffs(1)

  go_to_commits_line(6)
  expect_lines(FILES, { 'Files in: Worktree sub (nested)', '  ? x.txt' })
  go_to_files_line(2)
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
  local expected = vim.list_extend({ 'Files in: Session work', '  ? ' .. LIVE_MARKER }, after or {})
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

  expect_lines(COMMITS, commits_then({ 'Worktree agent (agent)', 'No commits in this worktree' }))
end

T['the worktrees followed']['show a commit made in another worktree, once the watch calls back'] = function()
  local top = git_repo.create('changesworktrees-commit-followed', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  begin_and_show(top)
  watch_live(top)

  local commit = git_repo.commit_all(agent, 'The agent’s')

  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
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
  expect_lines(COMMITS, commits_then({ 'Worktree agent (agent)', 'No commits in this worktree' }))
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })
  go_to_files_line(2)
  child.type_keys('<CR>')
  wait_for_diffs(1)
  local diff = child.lua_get(SHOWN_DIFF, { 1 })

  git_repo.git(top, { 'worktree', 'remove', '--force', agent })

  expect_lines(COMMITS, commits_then({}))
  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
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
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })
  go_to_files_line(2)
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
    { 'its commits listed', 'log' },
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
  local commit = git_repo.commit_all(second, 'The second’s')
  local stand_in, switch = breakable_git_in('changesworktrees-failed', first, subcommand)
  turn_on(switch)

  begin_and_show(top, { executable = stand_in })

  expect_lines(
    COMMITS,
    commits_then({
      'Worktree first (first)',
      'The last refresh failed: fatal: broken',
      'Worktree second (second)',
      commit:sub(1, 7) .. ' The second’s',
    })
  )
end

T['a worktree whose later read fails'] = MiniTest.new_set()

T['a worktree whose later read fails']['keeps the list it showed, under git’s words'] = function()
  local top = git_repo.create('changesworktrees-failed-later', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  local stand_in, switch = breakable_git_in('changesworktrees-failed-later', agent, 'log')
  begin_and_show(top, { executable = stand_in })
  expect_lines(
    COMMITS,
    commits_then({ 'Worktree agent (agent)', commit:sub(1, 7) .. ' The agent’s' })
  )
  turn_on(switch)

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(
    COMMITS,
    commits_then({
      'Worktree agent (agent)',
      'The last refresh failed: fatal: broken',
      commit:sub(1, 7) .. ' The agent’s',
    })
  )
end

T['a worktree whose later read fails']['keeps the list it showed, under git’s words, when the remote’s default branch cannot be read'] = function()
  local top = git_repo.create('changesworktrees-comparison-failed', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  local stand_in, switch =
    breakable_git_in('changesworktrees-comparison-failed', top, 'symbolic-ref')
  begin_and_show(top, { executable = stand_in })
  expect_lines(
    COMMITS,
    commits_then({ 'Worktree agent (agent)', commit:sub(1, 7) .. ' The agent’s' })
  )
  turn_on(switch)

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Landed in origin/HEAD',
    'The last refresh failed: fatal: broken',
    'Worktree agent (agent)',
    'The last refresh failed: fatal: broken',
    commit:sub(1, 7) .. ' The agent’s',
  })
end

T['a list of worktrees that fails'] = MiniTest.new_set()

T['a list of worktrees that fails']['leaves the editor’s lines as ever, then says so in git’s words, in the commits window'] = function()
  local top = git_repo.create('changesworktrees-list-failed', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local stand_in, switch = breakable_git_in('changesworktrees-list-failed', top, 'worktree')
  turn_on(switch)

  begin_and_show(top, { executable = stand_in })

  expect_lines(COMMITS, commits_then({ 'The other worktrees could not be listed: fatal: broken' }))
  eq(lines_of(FILES), { 'Files in: Session work', '  M notes.txt' })
end

T['a later list of worktrees that fails'] = MiniTest.new_set()

T['a later list of worktrees that fails']['keeps the worktrees it showed, under the line saying so'] = function()
  local top = git_repo.create('changesworktrees-list-failed-later', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  local stand_in, switch = breakable_git_in('changesworktrees-list-failed-later', top, 'worktree')
  begin_and_show(top, { executable = stand_in })
  expect_lines(
    COMMITS,
    commits_then({ 'Worktree agent (agent)', commit:sub(1, 7) .. ' The agent’s' })
  )
  turn_on(switch)

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(
    COMMITS,
    commits_then({
      'The other worktrees could not be listed: fatal: broken',
      'Worktree agent (agent)',
      commit:sub(1, 7) .. ' The agent’s',
    })
  )
end
--- Writes a stand-in for git under the fixture `git-<name>` that, asked
--- for a `log` in the directory `held`, writes the file
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
    ('case " $* " in *" -C %s "*" log "*) : > "$0.waiting"; while [ ! -f "$0.gate" ]; do sleep 0.05; done ;; esac'):format(
      held
    ),
    ('exec %s "$@"'):format(REAL_GIT),
  })
  return stand_in, stand_in .. '.waiting', stand_in .. '.gate'
end

T['a worktree removed while it is read'] = MiniTest.new_set()

--- The Lua that counts, in the child, the reads of commits the git home
--- has answered, in `_G.commit_reads_answered`, each once its caller's
--- `done` has run.
local COUNT_COMMIT_READS = [[
  local git = require('aineo.git')
  local commits_since = git.commits_since
  _G.commit_reads_answered = 0
  git.commits_since = function(found, base, done, options)
    return commits_since(found, base, function(...)
      done(...)
      _G.commit_reads_answered = _G.commit_reads_answered + 1
    end, options)
  end
]]

T['a worktree removed while it is read']['is dropped, not told as a failure'] = function()
  local top = git_repo.create('changesworktrees-removed-meanwhile', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  local stand_in, waiting, gate = git_held_in('changesworktrees-removed-meanwhile', agent)
  child.lua(COUNT_COMMIT_READS)
  begin_and_show(top, { executable = stand_in })
  git_repo.wait_until('the worktree’s commits asked for', function()
    return vim.uv.fs_stat(waiting) ~= nil
  end)
  vim.fn.delete(agent, 'rf')

  assert(vim.fn.writefile({}, gate) == 0, 'cannot write ' .. gate)

  git_repo.wait_until('the editor’s and the worktree’s commits read', function()
    return child.lua_get('_G.commit_reads_answered') == 2
  end)
  eq(lines_of(COMMITS), commits_then({}))
end

T['the reads'] = MiniTest.new_set()

--- Writes a stand-in for git under the fixture `git-<name>` that runs
--- every `log` — the last git of each worktree's read of the commits
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
    ('  *" log "*) echo start >> "$0.log"; sleep 0.5; %s "$@"; code=$?; echo end >> "$0.log"; exit $code ;;'):format(
      REAL_GIT
    ),
    'esac',
    ('exec %s "$@"'):format(REAL_GIT),
  })
  return stand_in, stand_in .. '.log'
end

T['the reads']['of the commits window stay one at a time with several worktrees, one asked meanwhile once more after'] = function()
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

  wait_for_the_reads(2)
  eq({ vim.fn.readfile(log), child.lua_get('_G.git_asked.commits_since') }, {
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

T['the reads']['of the editor’s own commits, asked during the other worktrees’, show them before the next worktree is read'] = function()
  local top = git_repo.create('changesworktrees-own-between', { ['notes.txt'] = { 'one' } })
  local first = add_worktree(top, 'first', 'first')
  local second = add_worktree(top, 'second', 'second')
  local stand_in = git_holding('changesworktrees-own-between', 'log', { first, second })
  child.lua(COUNT_GIT_READS)
  begin_and_show(top, { executable = stand_in })
  wait_for_the_reads()
  touch(stand_in .. '.first.hold')
  touch(stand_in .. '.second.hold')
  child.lua("require('aineo.changes').refresh_shown_pane()")
  git_repo.wait_until('the first worktree’s commits asked for', function()
    return vim.uv.fs_stat(stand_in .. '.first.waiting') ~= nil
  end)
  git_repo.write(top, 'saved.txt', { 'saved' })
  local commit = git_repo.commit_all(top, 'Mine')
  child.lua("require('aineo.changes').refresh_shown_pane()")

  touch(stand_in .. '.first.gate')

  git_repo.wait_until('the second worktree’s commits asked for', function()
    return vim.uv.fs_stat(stand_in .. '.second.waiting') ~= nil
  end)
  local shown = lines_of(COMMITS)[3]
  touch(stand_in .. '.second.gate')
  eq(shown, commit:sub(1, 7) .. ' Mine')
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
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })
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
    'Uncommitted',
    'Session work',
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

T['the reads']['of the commits window read the editor’s branch once, however many worktrees'] = function()
  local top = git_repo.create('changesworktrees-comparison-once', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'first', 'first')
  add_worktree(top, 'second', 'second')
  add_worktree(top, 'third', 'third')
  local stand_in, log = git_logging_every_run('changesworktrees-comparison-once')
  child.lua(WATCH_IN_HAND)
  child.lua(COUNT_GIT_READS)

  begin_and_show(top, { executable = stand_in })

  wait_for_the_reads()
  eq(lines_holding(log, '@{upstream}'), 1)
end

T['the reads']['of the commits window read nothing of the editor’s branch with no other worktree'] = function()
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
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    commit:sub(1, 7) .. ' The agent’s',
  })
  git_repo.git(top, { 'merge', '--quiet', '--ff-only', 'agent' })

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
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
    'Uncommitted',
    'Session work',
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
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    commit:sub(1, 7) .. ' The agent’s',
  })
end

T['the selection of another worktree'] = MiniTest.new_set()

T['the selection of another worktree']['goes back to Session work, the cursor with it, once its worktree is no longer listed'] = function()
  local top = git_repo.create('wtsel-removed', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  begin_and_show(top)
  expect_lines(
    COMMITS,
    commits_then({ 'Worktree agent (agent)', commit:sub(1, 7) .. ' The agent’s' })
  )
  go_to_commits_line(5)
  expect_lines(FILES, {
    'Files in: ' .. commit:sub(1, 7) .. ' The agent’s (worktree agent)',
    '  M notes.txt',
  })
  git_repo.git(top, { 'worktree', 'remove', '--force', agent })

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(COMMITS, commits_then({}))
  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
  eq(child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.bufwinid(...))', { COMMITS }), { 2, 0 })
end

T['the selection of another worktree']['stays its commit when the lists are read again'] = function()
  local top = git_repo.create('wtsel-stays', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  child.lua(COUNT_GIT_READS)
  begin_and_show(top)
  go_to_commits_line(5)
  expect_lines(FILES, {
    'Files in: ' .. commit:sub(1, 7) .. ' The agent’s (worktree agent)',
    '  M notes.txt',
  })
  wait_for_the_reads()

  child.lua("require('aineo.changes').refresh_shown_pane()")

  wait_for_the_reads(2)
  eq(lines_of(FILES), {
    'Files in: ' .. commit:sub(1, 7) .. ' The agent’s (worktree agent)',
    '  M notes.txt',
  })
end

T['the selection of another worktree']['becomes the worktree’s whole change, the cursor on its heading, once its commit is no longer listed'] = function()
  local top = git_repo.create('wtsel-amended', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  begin_and_show(top)
  expect_lines(
    COMMITS,
    commits_then({ 'Worktree agent (agent)', commit:sub(1, 7) .. ' The agent’s' })
  )
  go_to_commits_line(5)
  expect_lines(FILES, {
    'Files in: ' .. commit:sub(1, 7) .. ' The agent’s (worktree agent)',
    '  M notes.txt',
  })
  git_repo.git(agent, { 'commit', '--quiet', '--amend', '--message', 'Amended' })
  local amended = git_repo.git(agent, { 'rev-parse', 'HEAD' })

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(COMMITS, commits_then({ 'Worktree agent (agent)', amended:sub(1, 7) .. ' Amended' }))
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })
  eq(child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.bufwinid(...))', { COMMITS }), { 4, 0 })
end

T['the selection of another worktree']['names the worktree’s branch as the commits window last read it'] = function()
  local top = git_repo.create('wtsel-renamed', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  begin_and_show(top)
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })
  git_repo.git(agent, { 'branch', '--move', 'renamed' })

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(FILES, { 'Files in: Worktree agent (renamed)', '  M notes.txt' })
end

T['the files window under another worktree’s whole change'] = MiniTest.new_set()

T['the files window under another worktree’s whole change']['reads the worktree’s base again at every read'] = function()
  local top = git_repo.create('wtsel-base-again', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  git_repo.commit_all(agent, 'The agent’s')
  begin_and_show(top)
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })
  git_repo.git(top, { 'merge', '--quiet', '--ff-only', 'agent' })

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(FILES, { 'Files in: Worktree agent (agent)', 'No files changed in this worktree' })
end

T['the files window under another worktree’s whole change']['is read again at every call of the watch, the editor’s own files unchanged'] = function()
  local top = git_repo.create('wtsel-watch', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  child.lua(WATCH_IN_HAND)
  begin_and_show(top)
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })
  git_repo.write(agent, 'new.txt', { 'new' })

  child.lua('_G.on_change(nil, { files_changed = false, branch_moved = false })')

  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt', '  ? new.txt' })
end

T['the files window under another worktree’s whole change']['keeps its files under git’s words when a later read fails'] = function()
  local top = git_repo.create('wtsel-failed-later', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local stand_in, switch = breakable_git_in('wtsel-failed-later', agent, 'ls-files')
  begin_and_show(top, { executable = stand_in })
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })
  turn_on(switch)

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(FILES, {
    'Files in: Worktree agent (agent)',
    'The last refresh failed: fatal: broken',
    '  M notes.txt',
  })
end

T['the files window under another worktree’s whole change']['keeps its files under a line saying the worktree is gone when it is removed meanwhile'] = function()
  local top = git_repo.create('wtsel-gone', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  child.lua(WATCH_IN_HAND)
  begin_and_show(top)
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })
  git_repo.git(top, { 'worktree', 'remove', '--force', agent })

  child.lua(
    [[
      local files = vim.api.nvim_get_current_win()
      vim.cmd('aboveleft split ' .. vim.fn.fnameescape(... .. '/notes.txt'))
      vim.cmd('write')
      vim.api.nvim_set_current_win(files)
    ]],
    { top }
  )

  expect_lines(FILES, {
    'Files in: Worktree agent (agent)',
    'The last refresh failed: the worktree is gone',
    '  M notes.txt',
  })
end

T['the files window under another worktree’s whole change']['lists the filter with no files, under git’s words, when its first read fails'] = function()
  local top = git_repo.create('wtsel-failed-first', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local stand_in, switch = breakable_git_in('wtsel-failed-first', agent, 'ls-files')
  turn_on(switch)
  begin_and_show(top, { executable = stand_in })
  expect_lines(COMMITS, commits_then({ 'Worktree agent (agent)', 'No commits in this worktree' }))

  go_to_commits_line(4)

  expect_lines(FILES, {
    'Files in: Worktree agent (agent)',
    'The last refresh failed: fatal: broken',
  })
end

T['the files window under another worktree’s whole change']['lists its commit with no files, under git’s words, when the read of the commit’s files fails'] = function()
  local top = git_repo.create('wtsel-commit-failed', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  local stand_in, switch = breakable_git_in('wtsel-commit-failed', agent, 'show')
  turn_on(switch)
  begin_and_show(top, { executable = stand_in })
  expect_lines(
    COMMITS,
    commits_then({ 'Worktree agent (agent)', commit:sub(1, 7) .. ' The agent’s' })
  )

  go_to_commits_line(5)

  expect_lines(FILES, {
    'Files in: ' .. commit:sub(1, 7) .. ' The agent’s (worktree agent)',
    'The last refresh failed: fatal: broken',
  })
end

T['the reads']['of the files window read the editor’s files alone, however many worktrees'] = function()
  local top = git_repo.create('wtsel-files-alone', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'first', 'first')
  add_worktree(top, 'second', 'second')
  child.lua(WATCH_IN_HAND)
  child.lua(COUNT_GIT_READS)

  begin_and_show(top)

  wait_for_the_reads()
  eq(child.lua_get('{ _G.git_asked.changed_files, _G.git_asked.commits_since }'), { 1, 3 })
end

T['a worktree’s base from the working branch'] = MiniTest.new_set()

--- The working branch the cases name.
local WORKING_BRANCH = 'origin/dev'

--- The commits window's lines for an editor with no commit of its own, then
--- the working branch's heading with the commits that landed in it, then
--- the lines `listed` for its worktrees.
---
---@param landed string[]
---@param listed string[]
---@return string[]
local function commits_landed_then(landed, listed)
  local lines = commits_then({ 'Landed in ' .. WORKING_BRANCH })
  vim.list_extend(lines, landed)
  return vim.list_extend(lines, listed)
end

--- Makes the editor's repository, on `main` at `base` with the remote
--- `origin`, whose branch `dev` then takes the commit `landed`, fetched
--- into the repository; and the worktree `agent` beside it, forked from
--- `origin/dev` after that, with the commit `mine` of its own. Returns the
--- repository's top level, the worktree's, and `landed` and `mine`.
---
---@param name string
---@return string top
---@return string agent
---@return string landed
---@return string mine
local function fork_after_landing(name)
  local top, _, clone = git_repo.create_with_remote(name)
  local landed = git_repo.land_in_remote(clone, { ['landed.txt'] = { 'landed' } }, 'Landed')
  git_repo.fetch_remote(top)
  local agent = add_worktree(top, 'agent', 'agent', WORKING_BRANCH)
  git_repo.write(agent, 'agent.txt', { 'agent' })
  local mine = git_repo.commit_all(agent, 'The agent’s')
  return top, agent, landed, mine
end

T['a worktree’s base from the working branch']['lists the commits since the working branch, not since the editor’s older commit'] = function()
  local top, _, landed, mine = fork_after_landing('wtbase-commits')

  begin_and_show_working_on(top, WORKING_BRANCH)

  expect_lines(
    COMMITS,
    commits_landed_then(
      { landed:sub(1, 7) .. ' Landed' },
      { 'Worktree agent (agent)', mine:sub(1, 7) .. ' The agent’s' }
    )
  )
end

T['a worktree’s base from the working branch']['lists the files of its whole change since the working branch'] = function()
  local top = fork_after_landing('wtbase-files')
  begin_and_show_working_on(top, WORKING_BRANCH)
  go_to_commits_line(6)

  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  A agent.txt' })
end

T['a worktree’s base from the working branch']['shows its whole change since the working branch on Enter on the heading'] = function()
  local top, agent = fork_after_landing('wtbase-heading')
  begin_and_show_working_on(top, WORKING_BRANCH)
  go_to_commits_line(6)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  A agent.txt' })

  child.type_keys('<CR>')

  wait_for_diffs(1)
  local shown = child.lua_get(SHOWN_DIFF, { 1 })
  eq({
    name = shown.name,
    headers = vim.tbl_filter(function(line)
      return vim.startswith(line, 'diff --git')
    end, shown.text),
  }, {
    name = ('aineo://worktree%s//since-base'):format(agent),
    headers = { 'diff --git a/agent.txt b/agent.txt' },
  })
end

T['a worktree’s base from the working branch']['is counted from the remote’s default branch when the setting names none'] = function()
  local top, _, landed, mine = fork_after_landing('wtbase-remote-head')
  git_repo.git(top, { 'remote', 'set-head', 'origin', 'dev' })

  begin_and_show(top)

  expect_lines(
    COMMITS,
    commits_landed_then(
      { landed:sub(1, 7) .. ' Landed' },
      { 'Worktree agent (agent)', mine:sub(1, 7) .. ' The agent’s' }
    )
  )
end

T['a worktree’s base from the working branch']['is counted from the branch the setting names, not from the remote’s default branch'] = function()
  local top, _, landed, mine = fork_after_landing('wtbase-setting-wins')
  git_repo.git(top, { 'push', '--quiet', 'origin', 'main' })
  git_repo.fetch_remote(top)
  git_repo.git(top, { 'remote', 'set-head', 'origin', 'main' })

  begin_and_show_working_on(top, WORKING_BRANCH)

  expect_lines(
    COMMITS,
    commits_landed_then(
      { landed:sub(1, 7) .. ' Landed' },
      { 'Worktree agent (agent)', mine:sub(1, 7) .. ' The agent’s' }
    )
  )
end

T['a worktree’s base from the working branch']['is the editor’s comparison commit where there is no working branch'] = function()
  local top = git_repo.create('wtbase-none', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'agent.txt', { 'agent' })
  local mine = git_repo.commit_all(agent, 'The agent’s')
  git_repo.write(top, 'editor.txt', { 'editor' })
  git_repo.commit_all(top, 'The editor’s')

  begin_and_show(top)

  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    mine:sub(1, 7) .. ' The agent’s',
  })
end

T['a worktree’s base from the working branch']['is the editor’s comparison commit, read once, where the working branch names no commit'] = function()
  local top = git_repo.create('wtbase-no-commit', { ['notes.txt'] = { 'one' } })
  local first = add_worktree(top, 'first', 'first')
  add_worktree(top, 'second', 'second')
  git_repo.write(first, 'first.txt', { 'first' })
  local mine = git_repo.commit_all(first, 'The first’s')
  local stand_in, log = git_logging_every_run('wtbase-no-commit')
  child.lua(WATCH_IN_HAND)
  child.lua(COUNT_GIT_READS)

  begin_and_show_working_on(top, 'origin/nothing', { executable = stand_in })

  wait_for_the_reads()
  eq(lines_of(COMMITS), {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Landed in origin/nothing',
    'origin/nothing names no commit',
    'Worktree first (first)',
    mine:sub(1, 7) .. ' The first’s',
    'Worktree second (second)',
    'No commits in this worktree',
  })
  eq(lines_holding(log, '@{upstream}'), 1)
end

--- Makes the branch `unrelated` in the repository `top`: one commit with no
--- parent and no file, which shares no history with any other branch.
---
---@param top string
local function make_unrelated_branch(top)
  local empty_tree = git_repo.git(top, { 'hash-object', '-t', 'tree', '-w', '/dev/null' })
  local commit = git_repo.git(top, { 'commit-tree', '-m', 'Unrelated', empty_tree })
  git_repo.git(top, { 'branch', 'unrelated', commit })
end

T['a worktree’s base from the working branch']['is the editor’s comparison commit for a worktree that shares no history with the working branch'] = function()
  local top = git_repo.create('wtbase-unrelated', { ['notes.txt'] = { 'one' } })
  make_unrelated_branch(top)
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'agent.txt', { 'agent' })
  local mine = git_repo.commit_all(agent, 'The agent’s')

  begin_and_show_working_on(top, 'unrelated')

  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Landed in unrelated',
    git_repo.git(top, { 'rev-parse', '--short=7', 'unrelated' }) .. ' Unrelated',
    'Worktree agent (agent)',
    mine:sub(1, 7) .. ' The agent’s',
  })
end

T['a worktree’s base from the working branch']['reads the working branch’s commit once for the worktrees, however many'] = function()
  local top = git_repo.create_with_remote('wtbase-once')
  add_worktree(top, 'first', 'first')
  add_worktree(top, 'second', 'second')
  add_worktree(top, 'third', 'third')
  local stand_in, log = git_logging_every_run('wtbase-once')
  child.lua(WATCH_IN_HAND)
  child.lua(COUNT_GIT_READS)

  begin_and_show_working_on(top, WORKING_BRANCH, { executable = stand_in })

  wait_for_the_reads()
  eq({
    lines_holding(log, WORKING_BRANCH .. '^{commit}'),
    lines_holding(log, '@{upstream}'),
  }, { 2, 0 })
end

T['a worktree’s base from the working branch']['says why under every worktree when the working branch’s commit cannot be read, and keeps their lists'] = function()
  local top, _, landed, mine = fork_after_landing('wtbase-failed')
  local stand_in, switch = breakable_git_in('wtbase-failed', top, '--verify')
  begin_and_show_working_on(top, WORKING_BRANCH, { executable = stand_in })
  expect_lines(
    COMMITS,
    commits_landed_then(
      { landed:sub(1, 7) .. ' Landed' },
      { 'Worktree agent (agent)', mine:sub(1, 7) .. ' The agent’s' }
    )
  )
  turn_on(switch)

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Landed in origin/dev',
    'The last refresh failed: fatal: broken',
    landed:sub(1, 7) .. ' Landed',
    'Worktree agent (agent)',
    'The last refresh failed: fatal: broken',
    mine:sub(1, 7) .. ' The agent’s',
  })
end

T['a worktree’s base from the working branch']['says why in the files window when the working branch’s commit cannot be read, and keeps its files'] = function()
  local top = fork_after_landing('wtbase-failed-files')
  local stand_in, switch = breakable_git_in('wtbase-failed-files', top, '--verify')
  begin_and_show_working_on(top, WORKING_BRANCH, { executable = stand_in })
  go_to_commits_line(6)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  A agent.txt' })
  turn_on(switch)

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(FILES, {
    'Files in: Worktree agent (agent)',
    'The last refresh failed: fatal: broken',
    '  A agent.txt',
  })
end

T['a worktree’s base from the working branch']['moves with the working branch once a fetch moves it'] = function()
  local top, agent, landed, mine = fork_after_landing('wtbase-moves')
  child.lua(WATCH_IN_HAND)
  begin_and_show_working_on(top, WORKING_BRANCH)
  go_to_commits_line(6)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  A agent.txt' })
  git_repo.git(agent, { 'push', '--quiet', 'origin', 'agent:dev' })
  git_repo.fetch_remote(top)

  child.lua(
    '_G.on_change(nil, { files_changed = false, branch_moved = false, references_changed = true })'
  )

  expect_lines(FILES, { 'Files in: Worktree agent (agent)', 'No files changed in this worktree' })
  expect_lines(
    COMMITS,
    commits_landed_then(
      { mine:sub(1, 7) .. ' The agent’s', landed:sub(1, 7) .. ' Landed' },
      { 'Worktree agent (agent)', 'No commits in this worktree' }
    )
  )
end

T['a worktree’s base from the working branch']['is not read at all for a worktree with no commit yet, the editor’s comparison commit neither'] = function()
  local top, _, landed, mine = fork_after_landing('wtbase-fresh')
  local fresh = vim.fs.joinpath(vim.fs.dirname(top), 'fresh')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '--orphan', '-b', 'fresh', fresh })
  local stand_in, log = git_logging_every_run('wtbase-fresh')
  child.lua(WATCH_IN_HAND)
  child.lua(COUNT_GIT_READS)

  begin_and_show_working_on(top, WORKING_BRANCH, { executable = stand_in })

  wait_for_the_reads()
  eq(lines_of(COMMITS), {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Landed in ' .. WORKING_BRANCH,
    landed:sub(1, 7) .. ' Landed',
    'Worktree agent (agent)',
    mine:sub(1, 7) .. ' The agent’s',
    'Worktree fresh (fresh)',
    'No commits in this worktree',
  })
  eq(lines_holding(log, '@{upstream}'), 0)
end

T['a worktree’s base from the working branch']['says why under the worktree whose base needs the editor’s comparison commit when that cannot be read, the others as ever'] = function()
  local top, _, landed, mine = fork_after_landing('wtbase-comparison-failed')
  make_unrelated_branch(top)
  local other = vim.fs.joinpath(vim.fs.dirname(top), 'other')
  git_repo.git(top, { 'worktree', 'add', '--quiet', other, 'unrelated' })
  git_repo.write(other, 'other.txt', { 'other' })
  local theirs = git_repo.commit_all(other, 'The other’s')
  local unrelated = git_repo.git(top, { 'rev-parse', '--short=7', 'unrelated~1' })
  local stand_in, switch = breakable_git_in('wtbase-comparison-failed', top, 'symbolic-ref')
  begin_and_show_working_on(top, WORKING_BRANCH, { executable = stand_in })
  local other_listed = {
    'Worktree other (unrelated)',
    theirs:sub(1, 7) .. ' The other’s',
    unrelated .. ' Unrelated',
  }
  expect_lines(
    COMMITS,
    commits_landed_then(
      { landed:sub(1, 7) .. ' Landed' },
      vim.list_extend(
        { 'Worktree agent (agent)', mine:sub(1, 7) .. ' The agent’s' },
        other_listed
      )
    )
  )
  turn_on(switch)

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(
    COMMITS,
    commits_landed_then({ landed:sub(1, 7) .. ' Landed' }, {
      'Worktree agent (agent)',
      mine:sub(1, 7) .. ' The agent’s',
      'Worktree other (unrelated)',
      'The last refresh failed: fatal: broken',
      theirs:sub(1, 7) .. ' The other’s',
      unrelated .. ' Unrelated',
    })
  )
end

T['a worktree’s base from the working branch']['says why under a worktree whose base needs the editor’s comparison commit, the setting naming no commit'] = function()
  local top = git_repo.create('wtbase-comparison-failed-alone', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'agent.txt', { 'agent' })
  local mine = git_repo.commit_all(agent, 'The agent’s')
  local stand_in, switch = breakable_git_in('wtbase-comparison-failed-alone', top, 'symbolic-ref')
  begin_and_show_working_on(top, 'origin/nothing', { executable = stand_in })
  expect_lines(
    COMMITS,
    commits_then({
      'Landed in origin/nothing',
      'origin/nothing names no commit',
      'Worktree agent (agent)',
      mine:sub(1, 7) .. ' The agent’s',
    })
  )
  turn_on(switch)

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(
    COMMITS,
    commits_then({
      'Landed in origin/nothing',
      'origin/nothing names no commit',
      'Worktree agent (agent)',
      'The last refresh failed: fatal: broken',
      mine:sub(1, 7) .. ' The agent’s',
    })
  )
end

T['a worktree’s base from the working branch']['says why when the merge base with the working branch’s commit cannot be read, not counting from the editor’s comparison commit'] = function()
  local top, agent, landed, mine = fork_after_landing('wtbase-merge-base-failed')
  local stand_in = git_repo.script('wtbase-merge-base-failed', 'git', {
    ('case " $* " in *" -C %s "*" merge-base "*" %s "*) [ -f "$0.broken" ] && { echo "fatal: broken" >&2; exit 128; } ;; esac'):format(
      agent,
      landed
    ),
    ('exec %s "$@"'):format(REAL_GIT),
  })
  begin_and_show_working_on(top, WORKING_BRANCH, { executable = stand_in })
  expect_lines(
    COMMITS,
    commits_landed_then(
      { landed:sub(1, 7) .. ' Landed' },
      { 'Worktree agent (agent)', mine:sub(1, 7) .. ' The agent’s' }
    )
  )
  turn_on(stand_in .. '.broken')

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(
    COMMITS,
    commits_landed_then({ landed:sub(1, 7) .. ' Landed' }, {
      'Worktree agent (agent)',
      'The last refresh failed: fatal: broken',
      mine:sub(1, 7) .. ' The agent’s',
    })
  )
end

--- The added lines of the diff the home asked the child to show `index`-th.
---
---@param index integer
---@return string[]
local function added_lines_of_shown_diff(index)
  return vim.tbl_filter(function(line)
    return line:match('^%+[^+]') ~= nil
  end, child.lua_get(SHOWN_DIFF, { index }).text)
end

T['a worktree’s base from the working branch']['shows the diff of a file of its whole change from the working branch on Enter and on l'] = function()
  local top, _, clone = git_repo.create_with_remote('wtbase-file-diff')
  git_repo.land_in_remote(clone, { ['a.txt'] = { 'one', 'landed' } }, 'Landed')
  git_repo.fetch_remote(top)
  local agent = add_worktree(top, 'agent', 'agent', WORKING_BRANCH)
  git_repo.write(agent, 'a.txt', { 'one', 'landed', 'agent' })
  git_repo.commit_all(agent, 'The agent’s')
  begin_and_show_working_on(top, WORKING_BRANCH)
  go_to_commits_line(6)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M a.txt' })
  go_to_files_line(2)

  child.type_keys('<CR>')
  wait_for_diffs(1)
  local on_enter = added_lines_of_shown_diff(1)
  go_to_files_line(2)
  child.type_keys('l')
  wait_for_diffs(2)

  eq({ on_enter, added_lines_of_shown_diff(2) }, { { '+agent' }, { '+agent' } })
end

return T
