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
--- buffer in a window below it. Every buffer the home asks to show as a
--- diff is kept in `_G.shown_diffs` and shown in a window of its own at the
--- bottom, the cursor left where it is; every message told is kept in
--- `_G.messages`.
local BEGIN_AND_SHOW = [[
  local directory, git_options = ...
  local changes = require('aineo.changes')
  _G.shown_diffs, _G.messages = {}, {}
  vim.notify = function(message, level)
    table.insert(_G.messages, { message = message, level = level })
  end
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

--- Begins the session in the child for `directory`, with the git options
--- `git_options` when given, and shows the pane (`BEGIN_AND_SHOW`).
---
---@param directory string
---@param git_options? table
local function begin_and_show(directory, git_options)
  child.lua(BEGIN_AND_SHOW, { directory, git_options })
end

--- The lines of the child's buffer named `name`, less the files window's
--- `Against:` line.
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

--- The messages the child told through `vim.notify`.
---
---@return string[]
local function messages()
  return child.lua_get([[vim.tbl_map(function(told)
    return told.message
  end, _G.messages)]])
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

--- The Lua expression saying whether the child has listed the worktrees
--- `...` times at least, and every call it made to the git home has
--- answered (`COUNT_GIT_READS`).
local READS_ANSWERED = [[(function(lists)
  for name, asked in pairs(_G.git_asked) do
    if _G.git_answered[name] ~= asked then
      return false
    end
  end
  return _G.git_answered.list_worktrees >= lists
end)(...)]]

--- Waits until the child has listed the worktrees `lists` times, and every
--- read it asked of the git home has answered (`COUNT_GIT_READS`), so that
--- what the pane shows is what those reads gave.
---
---@param lists integer
local function wait_for_the_reads(lists)
  git_repo.wait_until('every read answered', function()
    return child.lua_get(READS_ANSWERED, { lists })
  end)
end

--- The lines of the child's buffer named `name`, the files window's
--- `Against:` line kept.
---
---@param name string
---@return string[]
local function raw_lines_of(name)
  return child.lua_get('vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, true)', { name })
end

--- The line the cursor of the child's commits window is on.
---
---@return integer
local function commits_cursor_line()
  return child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.bufwinid(...))[1]', { COMMITS })
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

--- The commits window's lines for an editor with no commit of its own, then
--- the lines `listed` for its worktrees.
---
---@param listed string[]
---@return string[]
local function commits_then(listed)
  return vim.list_extend({ 'Uncommitted', 'Session work', 'No commits on this session' }, listed)
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

--- Makes, in the repository at `top`, the worktree `agent` on the branch
--- `agent`, with one commit of its own, `committed.txt` added as `The
--- agent’s`, and three changes not committed: `notes.txt` changed and
--- staged, `other.txt` changed and not staged, `new.txt` new and untracked;
--- the editor's own worktree gets an untracked `editor.txt`. Returns the
--- worktree's top level and the commit's full id.
---
---@param top string the top level of a repository holding `notes.txt` and `other.txt`
---@return string worktree
---@return string commit
local function agent_with_three_changes(top)
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'committed.txt', { 'committed' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  git_repo.write(agent, 'notes.txt', { 'staged' })
  git_repo.git(agent, { 'add', 'notes.txt' })
  git_repo.write(agent, 'other.txt', { 'unstaged' })
  git_repo.write(agent, 'new.txt', { 'untracked' })
  git_repo.write(top, 'editor.txt', { 'the editor’s' })
  return agent, commit
end

T['another worktree’s Uncommitted line'] = MiniTest.new_set()

T['another worktree’s Uncommitted line']['sits first under its heading, before its commits'] = function()
  local top = git_repo.create('wtuncommitted-line', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'agent.txt', { 'new' })
  local commit = git_repo.commit_all(agent, 'The agent’s')

  begin_and_show(top)

  expect_lines(
    COMMITS,
    commits_then({
      'Worktree agent (agent)',
      'Uncommitted — agent (agent)',
      git_repo.commit_line(commit, 'The agent’s'),
    })
  )
end

T['another worktree’s Uncommitted line']['lists the worktree’s staged, unstaged and untracked files once selected'] = function()
  local top =
    git_repo.create('wtuncommitted-files', { ['notes.txt'] = { 'one' }, ['other.txt'] = { 'one' } })
  agent_with_three_changes(top)
  begin_and_show(top)

  go_to_commits_line(5)

  expect_lines(FILES, {
    'Files in: Uncommitted — agent (agent)',
    '  M notes.txt',
    '  M other.txt',
    '  ? new.txt',
  })
end

T['another worktree’s Uncommitted line']['says there is nothing uncommitted in a clean worktree with commits'] = function()
  local top = git_repo.create('wtuncommitted-clean', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'committed.txt', { 'committed' })
  git_repo.commit_all(agent, 'The agent’s')
  begin_and_show(top)

  go_to_commits_line(5)

  expect_lines(FILES, { 'Files in: Uncommitted — agent (agent)', 'No uncommitted changes' })
end

T['another worktree’s Uncommitted line']['marks none of its files as saved by the user, whose saves are the editor’s worktree’s'] = function()
  local top = git_repo.create('wtuncommitted-saved', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'the agent’s' })
  begin_and_show(top)
  child.lua(
    [[
      local path = ...
      local files = vim.api.nvim_get_current_win()
      vim.cmd('aboveleft split ' .. vim.fn.fnameescape(path))
      vim.cmd("call setline(1, 'the user’s') | write")
      vim.api.nvim_set_current_win(files)
    ]],
    { vim.fs.joinpath(top, 'notes.txt') }
  )
  expect_lines(FILES, { 'Files in: Session work', '* M notes.txt' })

  go_to_commits_line(5)

  expect_lines(FILES, { 'Files in: Uncommitted — agent (agent)', '  M notes.txt' })
end

T['another worktree’s Uncommitted line']['sits first under the heading of a worktree an agent reported, shown alone'] = function()
  local top = git_repo.create('wtuncommitted-reported', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(COMMITS, commits_then({}))
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  git_repo.write(agent, 'a.txt', { 'a' })
  local commit = git_repo.commit_all(agent, 'Work a')
  git_repo.write(agent, 'b.txt', { 'b' })

  child.lua(
    "require('aineo.changes').add_reported_work(..., function() end)",
    { { worktree = agent, label = 'T', branches = { { name = 'feature/a' } } } }
  )

  expect_lines(COMMITS, {
    'Worktree agent-1 (feature/a)',
    'Uncommitted — agent-1 (feature/a)',
    git_repo.commit_line(commit, 'Work a'),
  })
  go_to_commits_line(2)
  expect_lines(FILES, { 'Files in: Uncommitted — agent-1 (feature/a)', '  ? b.txt' })
end

T['Enter'] = MiniTest.new_set()

--- Puts the cursor of the files window, entered, on line `line`, counted
--- without its `Against:` line (`git_repo.files_window_line()`).
---
---@param line integer
local function go_to_files_line(line)
  enter_window_of(FILES)
  child.lua('vim.api.nvim_win_set_cursor(0, { ..., 0 })', { git_repo.files_window_line(line) })
end

--- Waits until the home has asked the child to show `count` diffs.
---
---@param count integer
local function wait_for_diffs(count)
  git_repo.wait_until(('%d diffs shown'):format(count), function()
    return child.lua_get('#_G.shown_diffs') >= count
  end)
end

--- The Lua expression giving the name and the last two lines of the diff
--- buffer the home asked the child to show `...`-th.
local SHOWN_DIFF = [[(function(index)
  local diff = _G.shown_diffs[index]
  return { name = vim.api.nvim_buf_get_name(diff), last = vim.api.nvim_buf_get_lines(diff, -3, -1, true) }
end)(...)]]

--- Makes, in the repository at `top`, the worktree `name` on the branch
--- `name`, whose one commit changed `notes.txt` to `committed` and whose
--- working tree has it as `text`; returns the worktree's top level.
---
---@param top string
---@param name string
---@param text string
---@return string worktree
local function agent_changing_notes(top, name, text)
  local agent = add_worktree(top, name, name)
  git_repo.write(agent, 'notes.txt', { 'committed' })
  git_repo.commit_all(agent, 'The agent’s')
  git_repo.write(agent, 'notes.txt', { text })
  return agent
end

T['Enter']['on a file under another worktree’s Uncommitted shows its diff from that worktree’s HEAD, named for the worktree'] = function()
  local top = git_repo.create('wtuncommitted-enter', { ['notes.txt'] = { 'one' } })
  local agent = agent_changing_notes(top, 'agent', 'uncommitted')
  git_repo.write(top, 'notes.txt', { 'the editor’s' })
  begin_and_show(top)
  go_to_commits_line(5)
  expect_lines(FILES, { 'Files in: Uncommitted — agent (agent)', '  M notes.txt' })
  go_to_files_line(2)

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(child.lua_get(SHOWN_DIFF, { 1 }), {
    name = ('aineo://worktree%s//uncommitted/notes.txt'):format(agent),
    last = { '-committed', '+uncommitted' },
  })
end

T['Enter']['on one path uncommitted in two worktrees shows two diff buffers, each its worktree’s'] = function()
  local top = git_repo.create('wtuncommitted-enter-two', { ['notes.txt'] = { 'one' } })
  local first = agent_changing_notes(top, 'first', 'first')
  local second = agent_changing_notes(top, 'second', 'second')
  begin_and_show(top)
  go_to_commits_line(5)
  expect_lines(FILES, { 'Files in: Uncommitted — first (first)', '  M notes.txt' })
  go_to_files_line(2)
  child.type_keys('<CR>')
  wait_for_diffs(1)
  go_to_commits_line(8)
  expect_lines(FILES, { 'Files in: Uncommitted — second (second)', '  M notes.txt' })
  go_to_files_line(2)

  child.type_keys('<CR>')

  wait_for_diffs(2)
  eq({
    distinct = child.lua_get('_G.shown_diffs[1] ~= _G.shown_diffs[2]'),
    first = child.lua_get(SHOWN_DIFF, { 1 }),
    second = child.lua_get(SHOWN_DIFF, { 2 }),
  }, {
    distinct = true,
    first = {
      name = ('aineo://worktree%s//uncommitted/notes.txt'):format(first),
      last = { '-committed', '+first' },
    },
    second = {
      name = ('aineo://worktree%s//uncommitted/notes.txt'):format(second),
      last = { '-committed', '+second' },
    },
  })
end

T['Enter']['on another worktree’s Uncommitted line shows its whole diff from that worktree’s HEAD, named for the worktree'] = function()
  local top = git_repo.create('wtuncommitted-enter-whole', { ['notes.txt'] = { 'one' } })
  local agent = agent_changing_notes(top, 'agent', 'uncommitted')
  git_repo.write(top, 'notes.txt', { 'the editor’s' })
  begin_and_show(top)
  go_to_commits_line(5)

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(child.lua_get(SHOWN_DIFF, { 1 }), {
    name = ('aineo://worktree%s//uncommitted'):format(agent),
    last = { '-committed', '+uncommitted' },
  })
end

T['the worktree shown alone'] = MiniTest.new_set()

--- Shows the worktree first in the list `s` offers alone: presses `s` in
--- the commits window with a picker that chooses the list's first item.
local function show_first_worktree_alone()
  child.lua([[
    vim.ui.select = function(items, _, on_choice)
      on_choice(items[1])
    end
  ]])
  enter_window_of(COMMITS)
  child.type_keys('s')
end

--- Switches the pane between the default view and the worktree shown alone,
--- as `\g` does inside the pane.
local function toggle_view()
  child.lua("require('aineo.changes').toggle_focused_view()")
end

--- The lines of the commits window while the worktree `agent` on `agent`,
--- with the one commit `commit` of subject `The agent’s`, is shown alone.
---
---@param commit string
---@return string[]
local function agent_alone(commit)
  return {
    'Worktree agent (agent)',
    'Uncommitted — agent (agent)',
    git_repo.commit_line(commit, 'The agent’s'),
  }
end

T['the worktree shown alone']['lists its Uncommitted line under its heading, before its commits'] = function()
  local top =
    git_repo.create('wtuncommitted-alone', { ['notes.txt'] = { 'one' }, ['other.txt'] = { 'one' } })
  local _, commit = agent_with_three_changes(top)
  begin_and_show(top)
  expect_lines(COMMITS, commits_then(agent_alone(commit)))

  show_first_worktree_alone()

  expect_lines(COMMITS, agent_alone(commit))
  go_to_commits_line(2)
  expect_lines(FILES, {
    'Files in: Uncommitted — agent (agent)',
    '  M notes.txt',
    '  M other.txt',
    '  ? new.txt',
  })
end

T['the worktree shown alone']['keeps its Uncommitted chosen as the view switches back and forth'] = function()
  local top = git_repo.create(
    'wtuncommitted-alone-toggle',
    { ['notes.txt'] = { 'one' }, ['other.txt'] = { 'one' } }
  )
  local _, commit = agent_with_three_changes(top)
  begin_and_show(top)
  expect_lines(COMMITS, commits_then(agent_alone(commit)))
  show_first_worktree_alone()
  expect_lines(COMMITS, agent_alone(commit))
  go_to_commits_line(2)
  local listed = {
    'Files in: Uncommitted — agent (agent)',
    '  M notes.txt',
    '  M other.txt',
    '  ? new.txt',
  }
  expect_lines(FILES, listed)

  toggle_view()

  expect_lines(COMMITS, commits_then(agent_alone(commit)))
  expect_lines(FILES, listed)
  eq(commits_cursor_line(), 5)

  toggle_view()

  expect_lines(COMMITS, agent_alone(commit))
  expect_lines(FILES, listed)
  eq(commits_cursor_line(), 2)
end

T['the Reported tree'] = MiniTest.new_set()

--- Hands the child's home an agent's report of the worktree at `path`,
--- labelled `T`, listing `branches`, and waits until the commits window lists
--- the heading `heading` it shows; then switches to the default view, which
--- lists the Reported section, from the commits window.
---
---@param path string
---@param branches { name: string, base?: string }[]
---@param heading string
local function report_then_default_view(path, branches, heading)
  child.lua(
    "require('aineo.changes').add_reported_work(..., function() end)",
    { { worktree = path, label = 'T', branches = branches } }
  )
  git_repo.wait_until('the report shown', function()
    return vim.tbl_contains(lines_of(COMMITS), heading)
  end)
  enter_window_of(COMMITS)
  toggle_view()
end

--- The abbreviated id of `commit`, as a branch's line shows its base.
---
---@param commit string
---@return string
local function short(commit)
  return commit:sub(1, 7)
end

--- Waits until the child's commits window starts with the lines `expected`,
--- at most `git_repo.PATIENCE_MS`, and asserts that it does.
---
---@param expected string[]
local function expect_commits_start(expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(vim.list_slice(lines_of(COMMITS), 1, #expected), expected)
  end, 10)
  eq(vim.list_slice(lines_of(COMMITS), 1, #expected), expected)
end

T['the Reported tree']['lists Uncommitted first under the branch another worktree has checked out'] = function()
  local top, base = git_repo.create('wtuncommitted-tree', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  git_repo.write(agent, 'a.txt', { 'a' })
  local commit = git_repo.commit_all(agent, 'Work a')

  report_then_default_view(
    agent,
    { { name = 'feature/a', base = base } },
    'Worktree agent-1 (feature/a)'
  )

  expect_commits_start({
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    '      Uncommitted',
    '      ' .. git_repo.commit_line(commit, 'Work a'),
    'Uncommitted',
  })
end

T['the Reported tree']['lists no Uncommitted under a branch no worktree has checked out'] = function()
  local top, base = git_repo.create('wtuncommitted-tree-not-out', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  git_repo.git(top, { 'branch', 'feature/p' })

  report_then_default_view(
    agent,
    { { name = 'feature/a', base = base }, { name = 'feature/p', base = base } },
    'Worktree agent-1 (feature/a)'
  )

  expect_commits_start({
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    '      Uncommitted',
    ('    feature/p from %s'):format(short(base)),
    'Uncommitted',
  })
end

--- Makes, in the repository at `top`, the worktree `agent-1` on
--- `feature/a`, with an untracked `b.txt`, and an untracked `editor.txt` in
--- the editor's own worktree; reports it with the base `base` and shows the
--- default view, whose Reported section lists the branch's Uncommitted on
--- line 5. Returns the worktree's top level.
---
---@param top string
---@param base string
---@return string agent
local function reported_agent_with_untracked(top, base)
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  git_repo.write(agent, 'b.txt', { 'b' })
  git_repo.write(top, 'editor.txt', { 'the editor’s' })
  report_then_default_view(
    agent,
    { { name = 'feature/a', base = base } },
    'Worktree agent-1 (feature/a)'
  )
  expect_commits_start({
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    '      Uncommitted',
  })
  return agent
end

T['the Reported tree']['lists, on another worktree’s Uncommitted, that worktree’s files'] = function()
  local top, base = git_repo.create('wtuncommitted-tree-files', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  reported_agent_with_untracked(top, base)

  go_to_commits_line(5)

  expect_lines(FILES, { 'Files in: Uncommitted — agent-1 (feature/a)', '  ? b.txt' })
end

--- Makes the repository `name`, with an untracked `editor.txt`, shows its
--- pane in the child and reports its own worktree on `main`, its base the
--- repository's first commit: the default view's Reported section then
--- lists `main`'s Uncommitted on line 5. Returns the top level.
---
---@param name string
---@return string top
local function own_worktree_reported(name)
  local top, base = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'editor.txt', { 'the editor’s' })
  begin_and_show(top)
  child.lua(
    "require('aineo.changes').add_reported_work(..., function() end)",
    { { worktree = top, label = 'T', branches = { { name = 'main', base = base } } } }
  )
  expect_commits_start({
    'Reported',
    'T now',
    '  ' .. vim.fs.basename(top),
    ('    main * from %s'):format(short(base)),
    '      Uncommitted',
    'Uncommitted',
  })
  return top
end

T['the Reported tree']['lists, on the editor’s own branch’s Uncommitted, the editor’s own Uncommitted'] = function()
  own_worktree_reported('wtuncommitted-tree-own')

  go_to_commits_line(5)

  expect_lines(FILES, { 'Files in: Uncommitted', '  ? editor.txt' })
end

T['the Reported tree']['shows, at Enter on another worktree’s Uncommitted, that worktree alone, its Uncommitted chosen'] = function()
  local top, base = git_repo.create('wtuncommitted-tree-enter', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  reported_agent_with_untracked(top, base)
  go_to_commits_line(5)

  child.type_keys('<CR>')

  expect_lines(COMMITS, {
    'Worktree agent-1 (feature/a)',
    'Uncommitted — agent-1 (feature/a)',
    'No commits in this worktree',
  })
  expect_lines(FILES, { 'Files in: Uncommitted — agent-1 (feature/a)', '  ? b.txt' })
  eq(commits_cursor_line(), 2)
end

T['the Reported tree']['keeps, at Enter on the editor’s own branch’s Uncommitted, the default view with its Uncommitted chosen'] = function()
  own_worktree_reported('wtuncommitted-tree-own-enter')
  go_to_commits_line(5)
  expect_lines(FILES, { 'Files in: Uncommitted', '  ? editor.txt' })

  child.type_keys('<CR>')

  eq(commits_cursor_line(), 5)
  expect_lines(FILES, { 'Files in: Uncommitted', '  ? editor.txt' })
end

T['the Reported tree']['offers another worktree’s Uncommitted to s, whose pick does what Enter does'] = function()
  local top, base = git_repo.create('wtuncommitted-tree-s', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  reported_agent_with_untracked(top, base)
  child.lua([[
    _G.offered = nil
    vim.ui.select = function(items, options, on_choice)
      _G.offered = vim.tbl_map(options.format_item, items)
      on_choice(vim.iter(items):find(function(item)
        return options.format_item(item) == '[reported]       Uncommitted'
      end))
    end
  ]])
  enter_window_of(COMMITS)

  child.type_keys('s')

  git_repo.wait_until('s offered its list', function()
    return child.lua_get('_G.offered ~= nil')
  end)
  eq(vim.list_slice(child.lua_get('_G.offered'), 1, 6), {
    '[reported] T now',
    '[reported]   agent-1',
    '[reported]     feature/a * from ' .. short(base),
    '[reported]       Uncommitted',
    '[reported] All reported work (1)',
    '[worktree] agent-1 (feature/a)',
  })
  expect_lines(COMMITS, {
    'Worktree agent-1 (feature/a)',
    'Uncommitted — agent-1 (feature/a)',
    'No commits in this worktree',
  })
  expect_lines(FILES, { 'Files in: Uncommitted — agent-1 (feature/a)', '  ? b.txt' })
  eq(commits_cursor_line(), 2)
end

T['the Reported tree']['moves the Uncommitted to the branch the worktree checks out between two reads'] = function()
  local top, base = git_repo.create('wtuncommitted-tree-switch', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  git_repo.git(top, { 'branch', 'feature/p' })
  report_then_default_view(
    agent,
    { { name = 'feature/a', base = base }, { name = 'feature/p', base = base } },
    'Worktree agent-1 (feature/a)'
  )
  expect_commits_start({
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    '      Uncommitted',
    ('    feature/p from %s'):format(short(base)),
    'Uncommitted',
  })
  git_repo.git(agent, { 'switch', '--quiet', 'feature/p' })

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_commits_start({
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a from %s'):format(short(base)),
    ('    feature/p * from %s'):format(short(base)),
    '      Uncommitted',
    'Uncommitted',
  })
end

T['h'] = MiniTest.new_set()

T['h']['on a file under another worktree’s Uncommitted shows Enter’s diff, from that worktree’s HEAD'] = function()
  local top = git_repo.create('wtuncommitted-h', { ['notes.txt'] = { 'one' } })
  local agent = agent_changing_notes(top, 'agent', 'uncommitted')
  git_repo.write(top, 'notes.txt', { 'the editor’s' })
  begin_and_show(top)
  go_to_commits_line(5)
  expect_lines(FILES, { 'Files in: Uncommitted — agent (agent)', '  M notes.txt' })
  go_to_files_line(2)

  child.type_keys('h')

  wait_for_diffs(1)
  eq(child.lua_get(SHOWN_DIFF, { 1 }), {
    name = ('aineo://worktree%s//uncommitted/notes.txt'):format(agent),
    last = { '-committed', '+uncommitted' },
  })
end

T['the refresh'] = MiniTest.new_set()

--- The Lua that replaces, in the child, the git home's watch with one that
--- calls back only when a case calls `_G.on_change(failure, change)`, so
--- that only what a case asks for reads the pane: `_G.on_change` is the
--- first watch's, the session's own repository's; a later one, of a
--- worktree whose Uncommitted is chosen, never calls back.
local WATCH_IN_HAND = [[
  require('aineo.git').watch_repository = function(_, on_change)
    _G.on_change = _G.on_change or on_change
    return { stop = function() end, watches_subdirectories = true }
  end
]]

T['the refresh']['of the watch reads another worktree’s Uncommitted again, the editor’s own files unchanged, and keeps it selected'] = function()
  local top = git_repo.create('wtuncommitted-watch', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  child.lua(WATCH_IN_HAND)
  child.lua(COUNT_GIT_READS)
  begin_and_show(top)
  go_to_commits_line(5)
  expect_lines(FILES, { 'Files in: Uncommitted — agent (agent)', '  M notes.txt' })
  git_repo.write(agent, 'new.txt', { 'new' })
  wait_for_the_reads(1)
  local lists_before = child.lua_get('_G.git_answered.list_worktrees')

  child.lua('_G.on_change(nil, { files_changed = false, branch_moved = false })')

  wait_for_the_reads(lists_before + 1)
  eq(lines_of(FILES), { 'Files in: Uncommitted — agent (agent)', '  M notes.txt', '  ? new.txt' })
  eq(commits_cursor_line(), 5)
end

T['the refresh']['of the pane keeps another worktree’s Uncommitted selected once the agent commits what it listed'] = function()
  local top = git_repo.create('wtuncommitted-refresh', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  begin_and_show(top)
  go_to_commits_line(5)
  expect_lines(FILES, { 'Files in: Uncommitted — agent (agent)', '  M notes.txt' })
  local commit = git_repo.commit_all(agent, 'The agent’s')

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(
    COMMITS,
    commits_then({
      'Worktree agent (agent)',
      'Uncommitted — agent (agent)',
      git_repo.commit_line(commit, 'The agent’s'),
    })
  )
  expect_lines(FILES, { 'Files in: Uncommitted — agent (agent)', 'No uncommitted changes' })
  eq(commits_cursor_line(), 5)
end

T['the refresh']['goes back to Session work, with no error, once the worktree of the Uncommitted selected is removed'] = function()
  local top = git_repo.create('wtuncommitted-removed', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  begin_and_show(top)
  go_to_commits_line(5)
  expect_lines(FILES, { 'Files in: Uncommitted — agent (agent)', '  M notes.txt' })
  git_repo.git(top, { 'worktree', 'remove', '--force', agent })

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(COMMITS, commits_then({}))
  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
  eq({ cursor = commits_cursor_line(), messages = messages() }, { cursor = 2, messages = {} })
end

T['a worktree whose read fails'] = MiniTest.new_set()

--- The git the suites run, by its absolute path, for the stand-in that runs
--- it in its turn.
local REAL_GIT = vim.fn.exepath('git')

--- Writes a stand-in for git under the fixture `git-<name>` that fails
--- with `fatal: broken`, as git words a failure, every `rev-parse` it is
--- asked to run in the directory `broken`, and runs git for any other; returns
--- its path.
---
---@param name string
---@param broken string
---@return string stand_in
local function git_broken_in(name, broken)
  return git_repo.script(name, 'git', {
    ('case " $* " in *" -C %s "*" rev-parse "*) echo "fatal: broken" >&2; exit 128 ;; esac'):format(
      broken
    ),
    ('exec %s "$@"'):format(REAL_GIT),
  })
end

T['a worktree whose read fails']['shows its Uncommitted line, which lists git’s words and no file, never an error'] = function()
  local top = git_repo.create('wtuncommitted-failed', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  begin_and_show(top, { executable = git_broken_in('wtuncommitted-failed', agent) })
  expect_lines(
    COMMITS,
    commits_then({
      'Worktree agent (agent)',
      'Uncommitted — agent (agent)',
      'The last refresh failed: fatal: broken',
    })
  )

  go_to_commits_line(5)

  expect_lines(
    FILES,
    { 'Files in: Uncommitted — agent (agent)', 'The last refresh failed: fatal: broken' }
  )
  eq(messages(), {})
end

T['a worktree whose read fails']['tells the diff of its Uncommitted unreadable, naming it and its worktree'] = function()
  local top = git_repo.create('wtuncommitted-failed-diff', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  begin_and_show(top, { executable = git_broken_in('wtuncommitted-failed-diff', agent) })
  go_to_commits_line(5)
  expect_lines(
    FILES,
    { 'Files in: Uncommitted — agent (agent)', 'The last refresh failed: fatal: broken' }
  )

  child.type_keys('<CR>')

  git_repo.wait_until('a message told', function()
    return #messages() > 0
  end)
  eq(messages(), {
    'aineo: the diff of Uncommitted in the worktree agent could not be read: fatal: broken',
  })
end

T['a worktree whose read fails']['says what its Uncommitted compares in words alone, reading nothing of the editor’s'] = function()
  local top = git_repo.create('wtuncommitted-failed-against', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  child.lua(COUNT_GIT_READS)
  begin_and_show(top, { executable = git_broken_in('wtuncommitted-failed-against', agent) })
  go_to_commits_line(5)
  expect_lines(
    FILES,
    { 'Files in: Uncommitted — agent (agent)', 'The last refresh failed: fatal: broken' }
  )

  wait_for_the_reads(1)

  eq(raw_lines_of(FILES)[2], 'Against: HEAD → working tree')
end

T['a reported worktree not listed yet'] = MiniTest.new_set()

--- Writes a stand-in for git under the fixture `git-<name>` that holds
--- every `log` it is asked to run in the directory `held` while the file
--- `hold` exists, and runs git; returns its path.
---
---@param name string
---@param held string
---@param hold string
---@return string stand_in
local function git_holding_log_in(name, held, hold)
  return git_repo.script(name, 'git', {
    ('case " $* " in *" -C %s "*" log "*) while [ -e "%s" ]; do sleep 0.05; done ;; esac'):format(
      held,
      hold
    ),
    ('exec %s "$@"'):format(REAL_GIT),
  })
end

T['a reported worktree not listed yet']['says its Uncommitted is being read, then lists it once the worktree is listed'] = function()
  local top = git_repo.create('wtuncommitted-not-listed', { ['notes.txt'] = { 'one' } })
  local agent = vim.fs.joinpath(vim.fs.dirname(top), 'agent-1')
  local hold = vim.fs.joinpath(git_repo.directory('wtuncommitted-not-listed-hold'), 'hold')
  child.lua(WATCH_IN_HAND)
  begin_and_show(top, { executable = git_holding_log_in('wtuncommitted-not-listed', agent, hold) })
  expect_lines(COMMITS, commits_then({}))
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'feature/a', agent })
  git_repo.write(agent, 'b.txt', { 'b' })
  assert(vim.fn.writefile({}, hold) == 0, 'cannot write ' .. hold)
  child.lua(
    "require('aineo.changes').add_reported_work(..., function() end)",
    { { worktree = agent, label = 'T', branches = { { name = 'feature/a' } } } }
  )
  git_repo.wait_until('the reported view shows', function()
    return lines_of(COMMITS)[2] == 'Uncommitted — agent-1 (feature/a)'
  end)

  go_to_commits_line(2)

  expect_lines(
    FILES,
    { 'Files in: Uncommitted — agent-1 (feature/a)', 'aineo is reading the repository' }
  )
  assert(os.remove(hold))
  expect_lines(FILES, { 'Files in: Uncommitted — agent-1 (feature/a)', '  ? b.txt' })
end

--- Writes a stand-in for git under the fixture `git-<name>` that holds
--- every run in the directory `held` while the file `hold` exists, then
--- fails every `rev-parse` there with `fatal: broken`, and runs git for any
--- other; returns its path.
---
---@param name string
---@param held string
---@param hold string
---@return string stand_in
local function git_holding_then_broken_in(name, held, hold)
  return git_repo.script(name, 'git', {
    ('case " $* " in *" -C %s "*) while [ -e "%s" ]; do sleep 0.05; done ;; esac'):format(
      held,
      hold
    ),
    ('case " $* " in *" -C %s "*" rev-parse "*) echo "fatal: broken" >&2; exit 128 ;; esac'):format(
      held
    ),
    ('exec %s "$@"'):format(REAL_GIT),
  })
end

T['a reported worktree not listed yet']['says its Uncommitted is being read, then the failure the worktree is listed with'] = function()
  local top = git_repo.create('wtuncommitted-not-listed-failed', { ['notes.txt'] = { 'one' } })
  local agent = vim.fs.joinpath(vim.fs.dirname(top), 'agent-1')
  local hold = vim.fs.joinpath(git_repo.directory('wtuncommitted-not-listed-failed-hold'), 'hold')
  child.lua(WATCH_IN_HAND)
  begin_and_show(
    top,
    { executable = git_holding_then_broken_in('wtuncommitted-not-listed-failed', agent, hold) }
  )
  expect_lines(COMMITS, commits_then({}))
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'feature/a', agent })
  assert(vim.fn.writefile({}, hold) == 0, 'cannot write ' .. hold)
  child.lua(
    "require('aineo.changes').add_reported_work(..., function() end)",
    { { worktree = agent, label = 'T', branches = { { name = 'feature/a' } } } }
  )
  git_repo.wait_until('the reported view shows', function()
    return lines_of(COMMITS)[2] == 'Uncommitted — agent-1 (feature/a)'
  end)
  go_to_commits_line(2)
  expect_lines(
    FILES,
    { 'Files in: Uncommitted — agent-1 (feature/a)', 'aineo is reading the repository' }
  )

  assert(os.remove(hold))

  git_repo.wait_until('the worktree listed with a failure', function()
    return vim.startswith(lines_of(COMMITS)[3] or '', 'The last refresh failed: ')
  end)
  expect_lines(FILES, { 'Files in: Uncommitted — agent-1 (feature/a)', lines_of(COMMITS)[3] })
end

T['the refresh']['of a second report of the worktree reads its chosen Uncommitted again'] = function()
  local top = git_repo.create('wtuncommitted-report-again', { ['notes.txt'] = { 'one' } })
  child.lua(WATCH_IN_HAND)
  begin_and_show(top)
  expect_lines(COMMITS, commits_then({}))
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  git_repo.write(agent, 'a.txt', { 'a' })
  local report = { { worktree = agent, label = 'T', branches = { { name = 'feature/a' } } } }
  child.lua("require('aineo.changes').add_reported_work(..., function() end)", report)
  expect_lines(COMMITS, {
    'Worktree agent-1 (feature/a)',
    'Uncommitted — agent-1 (feature/a)',
    'No commits in this worktree',
  })
  go_to_commits_line(2)
  expect_lines(FILES, { 'Files in: Uncommitted — agent-1 (feature/a)', '  ? a.txt' })
  git_repo.write(agent, 'b.txt', { 'b' })

  child.lua("require('aineo.changes').add_reported_work(..., function() end)", report)

  expect_lines(FILES, { 'Files in: Uncommitted — agent-1 (feature/a)', '  ? a.txt', '  ? b.txt' })
  eq(commits_cursor_line(), 2)
end

T['the watch of the worktree chosen'] = MiniTest.new_set()

T['the watch of the worktree chosen']['lists a file the agent writes in its folder, outside the editor’s'] = function()
  local top = git_repo.create('wtuncommitted-watched', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  begin_and_show(top)
  go_to_commits_line(5)
  expect_lines(FILES, { 'Files in: Uncommitted — agent (agent)', '  M notes.txt' })

  git_repo.write(agent, 'new.txt', { 'new' })

  expect_lines(FILES, { 'Files in: Uncommitted — agent (agent)', '  M notes.txt', '  ? new.txt' })
end

--- The Lua that keeps, in the child, the top level of every repository the
--- git home is asked to watch in `_G.watched`, `true` while that watch runs
--- and `false` once it is stopped, how many times each was started in
--- `_G.starts` and its callback in `_G.callbacks`, the watch itself left to
--- run; and defines `_G.fs_events()`, the folders the event loop's file
--- system watches watch, sorted.
local RECORD_WATCHES = [[
  local git = require('aineo.git')
  local watch_repository = git.watch_repository
  _G.watched, _G.starts, _G.callbacks = {}, {}, {}
  git.watch_repository = function(found, on_change, ...)
    local started, failure = watch_repository(found, on_change, ...)
    if started then
      _G.watched[found.top] = true
      _G.starts[found.top] = (_G.starts[found.top] or 0) + 1
      _G.callbacks[found.top] = on_change
      local stop = started.stop
      started.stop = function()
        _G.watched[found.top] = false
        stop()
      end
    end
    return started, failure
  end
  _G.fs_events = function()
    local paths = {}
    vim.uv.walk(function(handle)
      if handle:get_type() == 'fs_event' and handle:is_active() and not handle:is_closing() then
        table.insert(paths, handle:getpath())
      end
    end)
    table.sort(paths)
    return paths
  end
]]

--- Waits until the child's watch of the folder `top` runs, when `running`,
--- or is stopped, and asserts it (`RECORD_WATCHES`).
---
---@param top string
---@param running boolean
local function expect_watched(top, running)
  vim.wait(git_repo.PATIENCE_MS, function()
    return child.lua_get('_G.watched[...]', { top }) == running
  end, 10)
  eq(child.lua_get('_G.watched[...]', { top }), running)
end

T['the watch of the worktree chosen']['stops when another line is chosen, starts again on the line, and stops when the pane hides'] = function()
  local top = git_repo.create('wtuncommitted-watch-stops', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  child.lua(RECORD_WATCHES)
  begin_and_show(top)
  go_to_commits_line(5)
  expect_watched(agent, true)

  go_to_commits_line(2)
  expect_watched(agent, false)
  go_to_commits_line(5)
  expect_watched(agent, true)
  child.lua([[
    for _, window in ipairs(vim.fn.win_findbuf(vim.fn.bufnr('aineo://changes-files'))) do
      vim.api.nvim_win_set_buf(window, vim.api.nvim_create_buf(true, false))
    end
    for _, window in ipairs(vim.fn.win_findbuf(vim.fn.bufnr('aineo://changes-commits'))) do
      vim.api.nvim_win_set_buf(window, vim.api.nvim_create_buf(true, false))
    end
  ]])

  expect_watched(agent, false)
end

--- The folders the child's file system watches watch (`RECORD_WATCHES`).
---
---@return string[]
local function fs_events()
  return child.lua_get('_G.fs_events()')
end

T['the watch of the worktree chosen']['adds one folder to what is watched, the worktree’s, not the git directory the session watches'] = function()
  local top = git_repo.create('wtuncommitted-watch-one-more', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  child.lua(RECORD_WATCHES)
  begin_and_show(top)
  expect_watched(top, true)
  local before = fs_events()

  go_to_commits_line(5)

  expect_watched(agent, true)
  eq(#fs_events(), #before + 1)
end

T['the watch of the worktree chosen']['starts none for a worktree inside the editor’s, which the session’s watch sees with its subfolders'] = function()
  local top = git_repo.create(
    'wtuncommitted-watch-inside',
    { ['notes.txt'] = { 'one' }, ['.gitignore'] = { 'inside/' } }
  )
  local agent = vim.fs.joinpath(top, 'inside')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'inside', agent })
  child.lua(RECORD_WATCHES)
  begin_and_show(top, { system_name = 'Darwin' })
  expect_watched(top, true)
  go_to_commits_line(5)
  expect_lines(FILES, { 'Files in: Uncommitted — inside (inside)', 'No uncommitted changes' })

  git_repo.write(agent, 'new.txt', { 'new' })

  expect_lines(FILES, { 'Files in: Uncommitted — inside (inside)', '  ? new.txt' })
  eq(child.lua_get('_G.starts[...] or 0', { agent }), 0)
end

return T
