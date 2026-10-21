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

--- The working branch the Landed cases name.
local WORKING_BRANCH = 'origin/dev'

--- The Lua that begins the changes home's session in the child with the
--- settings `...` gives besides the diff-showing function, and shows the
--- pane's two buffers there: the files buffer in the current window, the
--- commits buffer in a window below it. Every buffer the home asks to show
--- as a diff is kept in `_G.shown_diffs`, in the window already showing it
--- or in a window of its own at the bottom, the cursor left where it is.
local BEGIN_AND_SHOW = [[
  local settings = ...
  local changes = require('aineo.changes')
  _G.shown_diffs = {}
  settings.show_diff = function(diff)
    table.insert(_G.shown_diffs, diff)
    local showing = vim.fn.bufwinid(diff)
    if showing ~= -1 then
      return showing
    end
    return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
  end
  changes.begin_session(settings)
  local pane = changes.pane_buffers()
  vim.api.nvim_win_set_buf(0, pane.files)
  vim.api.nvim_open_win(pane.commits, false, { split = 'below' })
]]

--- Begins the session in the child for `directory`, with `settings` besides
--- it, and shows the pane (`BEGIN_AND_SHOW`).
---
---@param directory string
---@param settings? table
local function begin_and_show(directory, settings)
  child.lua(BEGIN_AND_SHOW, { vim.tbl_extend('force', { directory = directory }, settings or {}) })
end

--- The lines of the child's buffer named `name`.
---
---@param name string
---@return string[]
local function lines_of(name)
  return child.lua_get('vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, true)', { name })
end

--- Waits until line `index` of the child's buffer named `name` is
--- `expected`, at most `git_repo.PATIENCE_MS`, and asserts that it is.
---
---@param name string
---@param index integer
---@param expected string
local function expect_line(name, index, expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return lines_of(name)[index] == expected
  end, 10)
  eq(lines_of(name)[index], expected)
end

--- Makes the current window the one showing the child's buffer named
--- `name`.
---
---@param name string
local function enter_window_of(name)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { name })
end

--- Enters the commits window, once line `line` of it holds `listed`, and
--- puts its cursor there, as the user's keys do, the pane having shown
--- *Session work* first.
---
---@param line integer
---@param listed string
local function go_to_commits_line(line, listed)
  expect_line(FILES, 1, 'Files in: Session work')
  git_repo.wait_until(('line %d of the commits window holds %s'):format(line, listed), function()
    return (lines_of(COMMITS)[line] or ''):find(listed, 1, true) ~= nil
  end)
  enter_window_of(COMMITS)
  child.type_keys(line .. 'G')
end

--- The abbreviated id of `commit`, a full id, as the pane shows it.
---
---@param commit string
---@return string
local function short(commit)
  return commit:sub(1, 7)
end

--- Makes the repository `.tests/fixtures/git-<name>/repo` hold one commit,
--- `base`, on `main`, with a remote `origin` whose branch `dev` is `base`
--- too, and `.tests/fixtures/git-<name>/agent`, a clone of that remote on
--- `dev`, where the work that lands is made. Returns the repository's top
--- level, its `base` and the clone's top level.
---
---@param name string
---@return string top
---@return string base
---@return string agent
local function with_remote(name)
  return git_repo.create_with_remote(name, { ['a.txt'] = { 'one' } })
end

--- `text` as a 'winbar' shows it in the group the code `group` stands for.
---
---@param group string
---@param text string
---@return string
local function shown_in(group, text)
  return '%#' .. group .. '#' .. text .. '%*'
end

--- A commit's abbreviated id, as a bar shows it.
---
---@param commit string
---@return string
local function id_in_bar(commit)
  return shown_in('AineoChangesCommitId', short(commit))
end

--- Names, between parentheses, as a bar shows them.
---
---@param names string
---@return string
local function names_in_bar(names)
  return shown_in('AineoChangesReportedBranch', '(' .. names .. ')')
end

--- Words saying where a commit came from, as a bar shows them.
---
---@param words string
---@return string
local function words_in_bar(words)
  return shown_in('AineoChangesNote', words)
end

--- The 'winbar' of the window showing the diff the home was last asked to
--- show, in the child.
---
---@return string
local function bar_of_last_diff()
  return child.lua_get([[(function()
    local window = vim.fn.bufwinid(_G.shown_diffs[#_G.shown_diffs])
    return vim.api.nvim_get_option_value('winbar', { win = window })
  end)()]])
end

--- Waits until the bar of the last diff shown is `expected`, at most
--- `git_repo.PATIENCE_MS`, and asserts that it is.
---
---@param expected string
local function expect_bar(expected)
  git_repo.wait_until('a diff is shown', function()
    return child.lua_get('#_G.shown_diffs') > 0
  end)
  vim.wait(git_repo.PATIENCE_MS, function()
    return bar_of_last_diff() == expected
  end, 10)
  eq(bar_of_last_diff(), expected)
end

--- Puts the cursor of the files window on line `line` and presses `keys`
--- there.
---
---@param line integer
---@param keys string
local function press_in_files_window(line, keys)
  enter_window_of(FILES)
  child.lua('vim.api.nvim_win_set_cursor(0, { ..., 0 })', { line })
  child.type_keys(keys)
end

T['the second heading line'] = MiniTest.new_set()

T['the second heading line']['under Session work says the session start and the working tree, with the names of the base'] = function()
  local top, base = git_repo.create('against-session', { ['a.txt'] = { 'one' } })

  begin_and_show(top)

  expect_line(FILES, 1, 'Files in: Session work')
  expect_line(FILES, 2, ('Against: %s (main) session start → working tree'):format(short(base)))
end

T['the second heading line']['shows the label, an id, names and words in their groups, each linked to the group of its kind'] = function()
  local top, base = git_repo.create('against-colours', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  expect_line(FILES, 2, ('Against: %s (main) session start → working tree'):format(short(base)))

  local marks = child.lua_get([[vim.tbl_map(function(mark)
    return { mark[3], mark[4].end_col, mark[4].hl_group }
  end, vim.api.nvim_buf_get_extmarks(
    require('aineo.changes').pane_buffers().files, -1, { 1, 0 }, { 1, -1 }, { details = true }
  ))]])
  local links = child.lua_get(
    [[vim.tbl_map(function(group)
    return vim.api.nvim_get_hl(0, { name = group, link = true }).link
  end, { 'AineoChangesFilter', 'AineoChangesCommitId', 'AineoChangesReportedBranch', 'AineoChangesNote' })]]
  )

  eq(marks, {
    { 0, 8, 'AineoChangesFilter' },
    { 9, 16, 'AineoChangesCommitId' },
    { 17, 23, 'AineoChangesReportedBranch' },
    { 24, 37, 'AineoChangesNote' },
  })
  eq(links, { 'Title', 'Identifier', 'Label', 'Comment' })
end

T['the second heading line']['shows the id alone until the names are read, and does not wait for them'] = function()
  local top, base = git_repo.create('against-unread', { ['a.txt'] = { 'one' } })
  child.lua([[
    require('aineo.git').names_at = function(_, _, done)
      _G.release_names = done
    end
  ]])

  begin_and_show(top)

  expect_line(FILES, 2, ('Against: %s session start → working tree'):format(short(base)))
  git_repo.wait_until('the names are asked for', function()
    return child.lua_get('_G.release_names ~= nil')
  end)
  eq(child.lua_get('vim.fn.mode()'), 'n')
  expect_line(FILES, 2, ('Against: %s session start → working tree'):format(short(base)))
  child.lua('local id = ...; _G.release_names(nil, { [id] = { "main" } })', { base })
  expect_line(FILES, 2, ('Against: %s (main) session start → working tree'):format(short(base)))
end

T['the second heading line']['takes the names of the last read, not those of an earlier read that answers late'] = function()
  local top, base = git_repo.create('against-late', { ['a.txt'] = { 'one' } })
  child.lua([[
    _G.held = {}
    require('aineo.git').names_at = function(_, _, done)
      table.insert(_G.held, done)
    end
  ]])
  begin_and_show(top)
  git_repo.wait_until('the first read asks for names', function()
    return child.lua_get('#_G.held') == 1
  end)
  child.lua("require('aineo.changes').refresh_shown_pane()")
  git_repo.wait_until('the second read asks for names', function()
    return child.lua_get('#_G.held') == 2
  end)

  child.lua('local id = ...; _G.held[2](nil, { [id] = { "main" } })', { base })
  expect_line(FILES, 2, ('Against: %s (main) session start → working tree'):format(short(base)))
  child.lua('local id = ...; _G.held[1](nil, { [id] = { "stale" } })', { base })

  vim.wait(200)
  expect_line(FILES, 2, ('Against: %s (main) session start → working tree'):format(short(base)))
end

T['the second heading line']['under Uncommitted says HEAD and the working tree'] = function()
  local top, base = git_repo.create('against-uncommitted', { ['a.txt'] = { 'one' } })
  git_repo.git(top, { 'branch', 'dev' })
  begin_and_show(top)

  go_to_commits_line(1, 'Uncommitted')

  expect_line(FILES, 1, 'Files in: Uncommitted')
  expect_line(FILES, 2, ('Against: %s (dev, main) HEAD → working tree'):format(short(base)))
end

T['the second heading line']['under a commit says its parent and the commit, with their names'] = function()
  local top, base = git_repo.create('against-commit', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  git_repo.write(top, 'b.txt', { 'bee' })
  local commit = git_repo.commit_all(top, 'Add b')
  git_repo.git(top, { 'tag', 'v1' })

  go_to_commits_line(3, 'Add b')

  expect_line(FILES, 2, ('Against: %s parent → %s (main, v1)'):format(short(base), short(commit)))
end

T['the second heading line']['under a root commit says the empty tree and the commit'] = function()
  local top = git_repo.create_unborn('against-root')
  begin_and_show(top)
  git_repo.write(top, 'a.txt', { 'one' })
  local commit = git_repo.commit_all(top, 'First')

  go_to_commits_line(3, 'First')

  expect_line(FILES, 2, ('Against: empty tree → %s (main)'):format(short(commit)))
end

T['the second heading line']['under Landed says the merge base with the working branch and its commit'] = function()
  local top, base, agent = with_remote('against-landed')
  git_repo.git(top, { 'remote', 'set-head', 'origin', 'dev' })
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  local landed = git_repo.land_in_remote(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  git_repo.fetch_remote(top)

  go_to_commits_line(4, 'Landed in origin/dev')

  expect_line(
    FILES,
    2,
    ('Against: %s (main) merge base with origin/dev → %s (origin/dev)'):format(
      short(base),
      short(landed)
    )
  )
end

--- Makes the directory `agent` beside the repository at `top` a worktree of
--- it on the new branch `feature/a`, with one commit, `Agent work`, that
--- adds `agent.txt`; returns the worktree's top level and the commit's full
--- id.
---
---@param top string
---@return string worktree
---@return string commit
local function with_agent_worktree(top)
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), 'agent')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'feature/a', worktree })
  git_repo.write(worktree, 'agent.txt', { 'agent' })
  return worktree, git_repo.commit_all(worktree, 'Agent work')
end

T['the second heading line']['under another worktree’s whole change says its merge base with the working branch and the working tree'] = function()
  local top, base = git_repo.create('against-worktree', { ['a.txt'] = { 'one' } })
  with_agent_worktree(top)
  begin_and_show(top, { working_branch = 'main' })

  go_to_commits_line(6, 'Worktree agent')

  expect_line(FILES, 1, 'Files in: Worktree agent (feature/a)')
  expect_line(
    FILES,
    2,
    ('Against: %s (main) merge base with main → working tree'):format(short(base))
  )
end

T['the second heading line']['under another worktree’s whole change names the editor’s commit when there is no working branch'] = function()
  local top, base = git_repo.create('against-worktree-comparison', { ['a.txt'] = { 'one' } })
  with_agent_worktree(top)
  begin_and_show(top)

  go_to_commits_line(4, 'Worktree agent')

  expect_line(FILES, 1, 'Files in: Worktree agent (feature/a)')
  expect_line(
    FILES,
    2,
    ('Against: %s (main) merge base with %s → working tree'):format(short(base), short(base))
  )
end

T['the second heading line']['under a commit of another worktree says its parent and the commit'] = function()
  local top, base = git_repo.create('against-worktree-commit', { ['a.txt'] = { 'one' } })
  local _, commit = with_agent_worktree(top)
  begin_and_show(top)

  go_to_commits_line(5, 'Agent work')

  git_repo.wait_until('the files window lists the commit', function()
    return vim.startswith(lines_of(FILES)[1] or '', 'Files in: ' .. short(commit))
  end)
  expect_line(
    FILES,
    2,
    ('Against: %s (main) parent → %s (feature/a)'):format(short(base), short(commit))
  )
end

T['the second heading line']['under a commit that landed says its parent and the commit'] = function()
  local top, base, agent = with_remote('against-landed-commit')
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  local landed = git_repo.land_in_remote(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  git_repo.fetch_remote(top)

  go_to_commits_line(5, 'Add b')

  expect_line(
    FILES,
    2,
    ('Against: %s (main) parent → %s (origin/dev)'):format(short(base), short(landed))
  )
end

T['the bar of a diff window'] = MiniTest.new_set()

T['the bar of a diff window']['under Session work says both sides of the file’s diff, then its path'] = function()
  local top, base = git_repo.create('against-bar-session', { ['a.txt'] = { 'one' } })
  git_repo.write(top, 'a.txt', { 'two' })
  begin_and_show(top)
  expect_line(FILES, 3, '  M a.txt')

  press_in_files_window(3, '<CR>')

  expect_bar(
    id_in_bar(base)
      .. ' '
      .. names_in_bar('main')
      .. ' '
      .. words_in_bar('session start')
      .. ' ↔ working tree  a.txt'
  )
end

T['the bar of a diff window']['under a commit says the parent and the commit, then the path'] = function()
  local top, base = git_repo.create('against-bar-commit', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  git_repo.write(top, 'b.txt', { 'bee' })
  local commit = git_repo.commit_all(top, 'Add b')
  go_to_commits_line(3, 'Add b')
  git_repo.wait_until('the files window lists the commit', function()
    return vim.startswith(lines_of(FILES)[1], 'Files in: ' .. short(commit))
  end)
  expect_line(FILES, 3, '  A b.txt')

  press_in_files_window(3, '<CR>')

  expect_bar(
    id_in_bar(base)
      .. ' '
      .. words_in_bar('parent')
      .. ' ↔ '
      .. id_in_bar(commit)
      .. ' '
      .. names_in_bar('main')
      .. '  b.txt'
  )
end

T['the bar of a diff window']['of a whole diff has no path'] = function()
  local top, base = git_repo.create('against-bar-whole', { ['a.txt'] = { 'one' } })
  git_repo.write(top, 'a.txt', { 'two' })
  begin_and_show(top)
  go_to_commits_line(2, 'Session work')
  expect_line(FILES, 3, '  M a.txt')

  child.type_keys('<CR>')

  expect_bar(
    id_in_bar(base)
      .. ' '
      .. names_in_bar('main')
      .. ' '
      .. words_in_bar('session start')
      .. ' ↔ working tree'
  )
end

T['the bar of a diff window']['against HEAD says HEAD and the working tree'] = function()
  local top, base = git_repo.create('against-bar-head', { ['a.txt'] = { 'one' } })
  git_repo.write(top, 'a.txt', { 'two' })
  begin_and_show(top)
  expect_line(FILES, 3, '  M a.txt')

  press_in_files_window(3, 'h')

  expect_bar(
    id_in_bar(base)
      .. ' '
      .. names_in_bar('main')
      .. ' '
      .. words_in_bar('HEAD')
      .. ' ↔ working tree  a.txt'
  )
end

T['the bar of a diff window']['follows the cursor to the next file’s diff, path included'] = function()
  local top, base = git_repo.create('against-bar-follow', {
    ['a.txt'] = { 'one' },
    ['b.txt'] = { 'one' },
  })
  git_repo.write(top, 'a.txt', { 'two' })
  git_repo.write(top, 'b.txt', { 'two' })
  begin_and_show(top)
  expect_line(FILES, 4, '  M b.txt')
  press_in_files_window(3, '<CR>')
  expect_bar(
    id_in_bar(base)
      .. ' '
      .. names_in_bar('main')
      .. ' '
      .. words_in_bar('session start')
      .. ' ↔ working tree  a.txt'
  )

  enter_window_of(FILES)
  child.lua('vim.api.nvim_win_set_cursor(0, { 4, 0 })')

  expect_bar(
    id_in_bar(base)
      .. ' '
      .. names_in_bar('main')
      .. ' '
      .. words_in_bar('session start')
      .. ' ↔ working tree  b.txt'
  )
end

T['the bar of a diff window']['is read again with the diff when F toggles the context: HEAD that moved is told'] = function()
  local top, base = git_repo.create('against-bar-context', {
    ['a.txt'] = { 'one' },
    ['b.txt'] = { 'one' },
  })
  git_repo.write(top, 'a.txt', { 'two' })
  git_repo.write(top, 'b.txt', { 'two' })
  begin_and_show(top)
  go_to_commits_line(1, 'Uncommitted')
  expect_line(FILES, 1, 'Files in: Uncommitted')
  expect_line(FILES, 4, '  M b.txt')
  press_in_files_window(3, '<CR>')
  expect_bar(
    id_in_bar(base)
      .. ' '
      .. names_in_bar('main')
      .. ' '
      .. words_in_bar('HEAD')
      .. ' ↔ working tree  a.txt'
  )
  git_repo.git(top, { 'add', 'b.txt' })
  git_repo.git(top, { 'commit', '--quiet', '--message', 'Change b' })
  local moved = git_repo.git(top, { 'rev-parse', 'HEAD' })

  child.type_keys('F')

  expect_bar(
    id_in_bar(moved)
      .. ' '
      .. names_in_bar('main')
      .. ' '
      .. words_in_bar('HEAD')
      .. ' ↔ working tree  a.txt'
  )
end

return T
