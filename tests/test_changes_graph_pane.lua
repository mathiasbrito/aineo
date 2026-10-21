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

--- The time the child's clock tells: the graph's commits are written long
--- before it.
local NOW = 1800000000

--- The Lua that begins the changes home's session in the child for the
--- directory `...`, its clock set to `NOW`, with the settings of the third
--- value besides (`graph_limit`, `git`), and shows the pane's two buffers
--- there: the files buffer in the current window, the commits buffer in a
--- window below it. Every buffer the home asks to show is kept in
--- `_G.shown_diffs` and shown in a window of its own at the bottom, the
--- cursor left where it is.
local BEGIN_AND_SHOW = [[
  local directory, now, settings = ...
  local changes = require('aineo.changes')
  _G.shown_diffs = {}
  changes.begin_session(vim.tbl_extend('force', settings, {
    directory = directory,
    now = function()
      return now
    end,
    show_diff = function(diff)
      table.insert(_G.shown_diffs, diff)
      local showing = vim.fn.bufwinid(diff)
      if showing ~= -1 then
        return showing
      end
      return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
    end,
  }))
  local pane = changes.pane_buffers()
  vim.api.nvim_win_set_buf(0, pane.files)
  vim.api.nvim_open_win(pane.commits, false, { split = 'below' })
]]

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

--- Waits until the cursor of the child's current window is at `expected`,
--- at most `git_repo.PATIENCE_MS`, and asserts that it is.
---
---@param expected integer[] the line, 1-based, and the byte column, 0-based
local function expect_cursor(expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(child.lua_get('vim.api.nvim_win_get_cursor(0)'), expected)
  end, 10)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), expected)
end

--- Waits until the child's current window shows the buffer named `name`, at
--- most `git_repo.PATIENCE_MS`, and asserts that it does.
---
---@param name string
local function expect_in_window_of(name)
  local function current_name()
    return child.lua_get('vim.api.nvim_buf_get_name(0)')
  end
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.endswith(current_name(), name)
  end, 10)
  eq(vim.endswith(current_name(), name), true)
end

--- Waits until the line under the cursor of the child's current window
--- ends with `ending`, at most `git_repo.PATIENCE_MS`, and asserts that it
--- does.
---
---@param ending string
local function expect_cursor_line_ending(ending)
  local function cursor_line()
    return child.lua_get('vim.api.nvim_get_current_line()')
  end
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.endswith(cursor_line(), ending)
  end, 10)
  eq({ line = cursor_line(), ends = vim.endswith(cursor_line(), ending) }, {
    line = cursor_line(),
    ends = true,
  })
end

--- Begins the session in the child for `directory`, with the clock at
--- `NOW` and `settings` besides, none when not given, and shows the pane
--- (`BEGIN_AND_SHOW`).
---
---@param directory string
---@param settings? { graph_limit?: integer, git?: table }
local function begin_and_show(directory, settings)
  child.lua(BEGIN_AND_SHOW, { directory, NOW, settings or {} })
end

--- Makes the current window the one showing the child's buffer named
--- `name`.
---
---@param name string
local function enter_window_of(name)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { name })
end

--- What the commits window lists before the graph is shown, for a
--- repository from `git_repo.create_graph()` whose session began at its
--- head.
local SECTIONS = { 'Uncommitted', 'Session work', 'No commits on this session' }

--- The graph's line for the commit `id` of the repository `top`, after
--- `drawn`, the graph git drew before it: its abbreviated id, its age as
--- git tells it, then `rest`, its subject, author and names.
---
---@param top string
---@param drawn string
---@param id string
---@param rest string
---@return string
local function graph_line(top, drawn, id, rest)
  return ('%s%s - (%s) %s'):format(drawn, id:sub(1, 7), git_repo.relative_age(top, id), rest)
end

--- The whole graph of a repository from `git_repo.create_graph()`.
---
---@param top string
---@param commits aineo.tests.GraphCommits
---@return string[]
local function whole_graph(top, commits)
  return {
    graph_line(top, '* ', commits.other, 'Other work - Carol (tag: v1, other)'),
    graph_line(top, '| * ', commits.merge, 'Merge side - Ada (HEAD -> main)'),
    '|/| ',
    graph_line(top, '| * ', commits.side, 'Side work - Bartholomew (side)'),
    graph_line(top, '* | ', commits.main, 'Main work - Ada'),
    '|/  ',
    graph_line(top, '* ', commits.begin, 'Begin - Ada'),
  }
end

--- Shows the pane for a repository from `git_repo.create_graph()` named
--- after `case`, waits for its sections, then enters the commits window
--- and presses `t`; the session begun with `settings` (`begin_and_show()`).
---
---@param case string
---@param settings? { graph_limit?: integer, git?: table }
---@return string top
---@return aineo.tests.GraphCommits commits
local function pane_showing_the_graph(case, settings)
  local top, commits = git_repo.create_graph(case)
  begin_and_show(top, settings)
  expect_lines(COMMITS, SECTIONS)
  enter_window_of(COMMITS)
  child.type_keys('t')
  return top, commits
end

--- Waits until the first line of the commits window ends with `ending`, at
--- most `git_repo.PATIENCE_MS`, and asserts that it does.
---
---@param ending string
local function expect_first_commits_line_ending(ending)
  local function first_line()
    return lines_of(COMMITS)[1]
  end
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.endswith(first_line(), ending)
  end, 10)
  eq({ line = first_line(), ends = vim.endswith(first_line(), ending) }, {
    line = first_line(),
    ends = true,
  })
end

T['t'] = MiniTest.new_set()

T['t']['in the commits window shows the commit graph of every branch in place of the sections'] = function()
  local top, commits = pane_showing_the_graph('graphpane-shows')

  expect_lines(COMMITS, whole_graph(top, commits))
end

--- The author and age column of the graph's commits by Carol and Ada, as
--- the files window names a commit, told at `NOW`.
local CAROL = 'Carol 9y' .. (' '):rep(12)
local ADA = 'Ada 9y' .. (' '):rep(14)

T['the files window'] = MiniTest.new_set()

T['the files window']['lists the files of the first commit once t shows the graph, the cursor on it'] = function()
  local top, commits = pane_showing_the_graph('graphpane-first')

  expect_lines(COMMITS, whole_graph(top, commits))
  expect_cursor({ 1, 0 })
  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line_of(commits.other, CAROL, 'Other work'),
    '  A more.txt',
    '  A other.txt',
  })
end

T['t']['again shows the sections as they were, the choice made before the graph chosen again'] = function()
  local top, commits = pane_showing_the_graph('graphpane-back')
  expect_lines(COMMITS, whole_graph(top, commits))
  child.type_keys('jj')
  expect_lines(FILES, {
    'Files in: '
      .. git_repo.commit_line_of(commits.side, 'Bartholomew 9y' .. (' '):rep(6), 'Side work'),
    '  A side.txt',
  })

  child.type_keys('t')

  expect_lines(COMMITS, SECTIONS)
  expect_cursor({ 2, 0 })
  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
  child.type_keys('j')
  expect_cursor({ 3, 0 })
end

T['t']['again chooses the session’s commit chosen before the graph'] = function()
  local top = git_repo.create_graph('graphpane-back-commit')
  begin_and_show(top)
  expect_lines(COMMITS, SECTIONS)
  git_repo.write(top, 'later.txt', { 'later' })
  local later = git_repo.commit_all_dated(top, 'Later work', 'Ada', git_repo.GRAPH_STARTS_AT + 200)
  child.lua("require('aineo.changes').refresh_shown_pane()")
  local chosen = {
    'Files in: ' .. git_repo.commit_line_of(later, ADA, 'Later work'),
    '  A later.txt',
  }
  enter_window_of(COMMITS)
  child.type_keys('3G')
  expect_lines(FILES, chosen)
  child.type_keys('t')
  expect_cursor_line_ending('Later work - Ada (HEAD -> main)')
  child.type_keys('j')
  git_repo.wait_until('another commit chosen', function()
    return lines_of(FILES)[1] ~= chosen[1]
  end)

  child.type_keys('t')

  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    git_repo.commit_line_of(later, ADA, 'Later work'),
  })
  expect_cursor({ 3, 0 })
  expect_lines(FILES, chosen)
end

T['t']['shows the graph again after the sections, read anew'] = function()
  local top, commits =
    pane_showing_the_graph('graphpane-again', { git = { system_name = 'Linux' } })
  expect_lines(COMMITS, whole_graph(top, commits))
  child.type_keys('t')
  expect_lines(COMMITS, SECTIONS)
  git_repo.git(top, { 'tag', 'v2', commits.begin })

  child.type_keys('t')

  local again = whole_graph(top, commits)
  again[7] = graph_line(top, '* ', commits.begin, 'Begin - Ada (tag: v2)')
  expect_lines(COMMITS, again)
  expect_cursor({ 1, 0 })
end

T['t']['leaves the graph shown in a commits buffer made anew, on the commit chosen, k going from commit to commit'] = function()
  local top, commits = pane_showing_the_graph('graphpane-anew')
  expect_lines(COMMITS, whole_graph(top, commits))
  child.type_keys('jj')
  local side = {
    'Files in: '
      .. git_repo.commit_line_of(commits.side, 'Bartholomew 9y' .. (' '):rep(6), 'Side work'),
    '  A side.txt',
  }
  expect_lines(FILES, side)
  child.lua('vim.cmd.bwipeout(vim.fn.bufnr(...))', { COMMITS })

  child.lua([[
    local pane = require('aineo.changes').pane_buffers()
    vim.api.nvim_open_win(pane.commits, true, { split = 'below' })
  ]])

  expect_lines(COMMITS, whole_graph(top, commits))
  expect_cursor({ 4, 0 })
  expect_lines(FILES, side)
  child.type_keys('2k')
  expect_cursor({ 1, 0 })
end

T['t']['leaves a commits buffer made anew in another window choosing the commit its cursor is put on'] = function()
  local top, commits = pane_showing_the_graph('graphpane-anew-elsewhere')
  expect_lines(COMMITS, whole_graph(top, commits))
  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line_of(commits.other, CAROL, 'Other work'),
    '  A more.txt',
    '  A other.txt',
  })
  enter_window_of(FILES)
  child.lua('vim.cmd.bwipeout(vim.fn.bufnr(...))', { COMMITS })
  git_repo.git(top, { 'tag', '--delete', 'v1' })
  git_repo.git(top, { 'branch', '--delete', '--force', 'other' })

  child.lua([[
    local pane = require('aineo.changes').pane_buffers()
    vim.api.nvim_open_win(pane.commits, false, { split = 'below' })
  ]])

  expect_first_commits_line_ending('Merge side - Ada (HEAD -> main)')
  expect_in_window_of(FILES)
  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line_of(commits.merge, ADA, 'Merge side'),
    '  A side.txt',
  })
end

T['j and k'] = MiniTest.new_set()

T['j and k']['in the graph go from commit line to commit line, past a line of the graph alone'] = function()
  local top, commits = pane_showing_the_graph('graphpane-j')
  expect_lines(COMMITS, whole_graph(top, commits))
  expect_cursor({ 1, 0 })

  child.type_keys('j', 'j')

  expect_cursor({ 4, 0 })
  child.type_keys('k')
  expect_cursor({ 2, 0 })
end

T['j and k']['in the graph take a count of commit lines'] = function()
  local top, commits = pane_showing_the_graph('graphpane-count')
  expect_lines(COMMITS, whole_graph(top, commits))
  expect_cursor({ 1, 0 })

  child.type_keys('3j')

  expect_cursor({ 5, 0 })
  child.type_keys('2k')
  expect_cursor({ 2, 0 })
end

T['j and k']['in the graph choose the commit they land on for the files window'] = function()
  local top, commits = pane_showing_the_graph('graphpane-j-files')
  expect_lines(COMMITS, whole_graph(top, commits))

  child.type_keys('jj')

  expect_lines(FILES, {
    'Files in: '
      .. git_repo.commit_line_of(commits.side, 'Bartholomew 9y' .. (' '):rep(6), 'Side work'),
    '  A side.txt',
  })
end

--- The Lua that clicks, in the child, with the left button on line `...`
--- of the commits window, counted from 1 at its top, at its first column.
local CLICK_COMMITS_LINE = [[
  local line = ...
  local window = vim.fn.bufwinid('aineo://changes-commits')
  local position = vim.fn.win_screenpos(window)
  local row, column = position[1] - 1 + line - 1, position[2] - 1
  vim.api.nvim_input_mouse('left', 'press', '', 0, row, column)
  vim.api.nvim_input_mouse('left', 'release', '', 0, row, column)
]]

--- The Lua that makes `vim.ui.select` in the child pick, at once, the item
--- it offers whose text holds `...`, and count the picks in `_G.picks`.
local PICK_ITEM_HOLDING = [[
  local wanted = ...
  _G.picks = 0
  vim.ui.select = function(items, options, on_choice)
    for _, item in ipairs(items) do
      if options.format_item(item):find(wanted, 1, true) then
        _G.picks = _G.picks + 1
        on_choice(item)
        return
      end
    end
  end
]]

T['s'] = MiniTest.new_set()

T['s']['in the graph leaves the graph as it is, and the commit under the cursor choosing'] = function()
  local top, commits = pane_showing_the_graph('graphpane-s')
  expect_lines(COMMITS, whole_graph(top, commits))
  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line_of(commits.other, CAROL, 'Other work'),
    '  A more.txt',
    '  A other.txt',
  })
  child.lua(PICK_ITEM_HOLDING, { '[branch] side' })

  child.type_keys('s')

  git_repo.wait_until('the branch picked', function()
    return child.lua_get('_G.picks') == 1
  end)
  expect_lines(COMMITS, whole_graph(top, commits))
  child.type_keys('jj')
  expect_lines(FILES, {
    'Files in: '
      .. git_repo.commit_line_of(commits.side, 'Bartholomew 9y' .. (' '):rep(6), 'Side work'),
    '  A side.txt',
  })
end

T['l and <BS>'] = MiniTest.new_set()

T['l and <BS>']['on a commit of the graph go to its files and back to its line'] = function()
  local top, commits = pane_showing_the_graph('graphpane-l')
  expect_lines(COMMITS, whole_graph(top, commits))
  child.type_keys('jj')

  child.type_keys('l')

  expect_in_window_of(FILES)
  expect_cursor({ 2, 0 })
  expect_lines(FILES, {
    'Files in: '
      .. git_repo.commit_line_of(commits.side, 'Bartholomew 9y' .. (' '):rep(6), 'Side work'),
    '  A side.txt',
  })
  child.lua('vim.api.nvim_win_set_cursor(vim.fn.bufwinid(...), { 1, 0 })', { COMMITS })
  child.type_keys('<BS>')
  expect_in_window_of(COMMITS)
  expect_cursor({ 4, 0 })
end

--- Waits until the child has been asked to show `count` buffers.
---
---@param count integer
local function wait_for_shown(count)
  git_repo.wait_until(('%d buffers shown'):format(count), function()
    return child.lua_get('#_G.shown_diffs') >= count
  end)
end

--- The name of the buffer the child was asked to show last.
---
---@return string
local function last_shown_name()
  return child.lua_get('vim.api.nvim_buf_get_name(_G.shown_diffs[#_G.shown_diffs])')
end

T['l and <BS>']['the diff follows the cursor over a graph commit’s files once l opened one'] = function()
  local top, commits = pane_showing_the_graph('graphpane-follow')
  expect_lines(COMMITS, whole_graph(top, commits))
  child.type_keys('l')
  expect_in_window_of(FILES)
  expect_cursor({ 2, 0 })
  child.type_keys('l')
  wait_for_shown(1)
  eq(last_shown_name(), 'aineo://commit/' .. commits.other .. '/more.txt')

  child.type_keys('j')

  wait_for_shown(2)
  eq(last_shown_name(), 'aineo://commit/' .. commits.other .. '/other.txt')
end

T['the graph'] = MiniTest.new_set()

T['the graph']['is read again as the repository changes, the cursor kept on its commit'] = function()
  local top, commits = pane_showing_the_graph('graphpane-watch')
  expect_lines(COMMITS, whole_graph(top, commits))
  child.type_keys('3j')
  expect_cursor({ 5, 0 })

  git_repo.write(top, 'later.txt', { 'later' })
  git_repo.commit_all_dated(top, 'Later work', 'Ada', git_repo.GRAPH_STARTS_AT + 300)

  expect_first_commits_line_ending('Later work - Ada (HEAD -> main)')
  expect_cursor_line_ending('Main work - Ada')
  expect_cursor({ 8, 0 })
end

T['the graph']['says its read failed, in git’s words, when git cannot draw it'] = function()
  local stand_in = git_repo.script('graphpane-failed-stand-in', 'git', {
    'case " $* " in',
    "  *' --graph '*) echo 'fatal: the graph broke' >&2; exit 128 ;;",
    'esac',
    ('exec %s "$@"'):format(vim.fn.exepath('git')),
  })

  pane_showing_the_graph('graphpane-failed', { git = { executable = stand_in } })

  expect_lines(COMMITS, { 'The last refresh failed: fatal: the graph broke' })
end

T['the graph']['draws as many commits as the session’s limit, then says older ones are not shown'] = function()
  local top, commits = pane_showing_the_graph('graphpane-limit', { graph_limit = 2 })

  expect_lines(COMMITS, {
    graph_line(top, '* ', commits.other, 'Other work - Carol (tag: v1, other)'),
    graph_line(top, '| * ', commits.merge, 'Merge side - Ada (HEAD -> main)'),
    'Older commits not shown',
  })
  child.type_keys('G')
  expect_cursor({ 2, 0 })
end

T['the graph']['chooses the commit the cursor is left on once the one chosen is no longer listed'] = function()
  local top, commits = pane_showing_the_graph('graphpane-gone')
  expect_lines(COMMITS, whole_graph(top, commits))
  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line_of(commits.other, CAROL, 'Other work'),
    '  A more.txt',
    '  A other.txt',
  })

  git_repo.git(top, { 'tag', '--delete', 'v1' })
  git_repo.git(top, { 'branch', '--delete', '--force', 'other' })

  expect_first_commits_line_ending('Merge side - Ada (HEAD -> main)')
  expect_cursor({ 1, 0 })
  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line_of(commits.merge, ADA, 'Merge side'),
    '  A side.txt',
  })
end

--- Waits until the cursor of the child's window showing the commits buffer,
--- current or not, is at `expected`, at most `git_repo.PATIENCE_MS`, and
--- asserts that it is.
---
---@param expected integer[] the line, 1-based, and the byte column, 0-based
local function expect_commits_cursor(expected)
  local function cursor()
    return child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.bufwinid(...))', { COMMITS })
  end
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(cursor(), expected)
  end, 10)
  eq(cursor(), expected)
end

T['the graph']['keeps a commits window that is not current on a commit line, chosen, once its commit is gone'] = function()
  local top, commits = pane_showing_the_graph('graphpane-gone-elsewhere')
  expect_lines(COMMITS, whole_graph(top, commits))
  child.type_keys('j')
  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line_of(commits.merge, ADA, 'Merge side'),
    '  A side.txt',
  })
  enter_window_of(FILES)
  local tree = git_repo.git(top, { 'rev-parse', commits.merge .. '^{tree}' })
  local again = git_repo.git(
    top,
    { 'commit-tree', tree, '-p', commits.main, '-p', commits.side, '-m', 'Merge again' }
  )

  git_repo.git(top, { 'update-ref', 'refs/heads/main', again })

  expect_first_commits_line_ending('Merge again - aineo tests (HEAD -> main)')
  expect_commits_cursor({ 3, 0 })
  expect_lines(FILES, {
    'Files in: '
      .. git_repo.commit_line_of(commits.side, 'Bartholomew 9y' .. (' '):rep(6), 'Side work'),
    '  A side.txt',
  })
end

T['the graph']['is read again when the pane is shown again, where the watch sees no reference written'] = function()
  local top, commits =
    pane_showing_the_graph('graphpane-shown', { git = { system_name = 'Linux' } })
  expect_lines(COMMITS, whole_graph(top, commits))
  git_repo.git(top, { 'tag', 'v2', commits.begin })

  child.lua("require('aineo.changes').refresh_shown_pane()")

  local again = whole_graph(top, commits)
  again[7] = graph_line(top, '* ', commits.begin, 'Begin - Ada (tag: v2)')
  expect_lines(COMMITS, again)
end

T['Enter'] = MiniTest.new_set()

T['Enter']['on a graph commit shows that commit’s whole diff'] = function()
  local top, commits = pane_showing_the_graph('graphpane-enter')
  expect_lines(COMMITS, whole_graph(top, commits))
  child.type_keys('jj')
  expect_cursor({ 4, 0 })

  child.type_keys('<CR>')

  wait_for_shown(1)
  eq(last_shown_name(), 'aineo://commit/' .. commits.side)
end

T['the cursor'] = MiniTest.new_set()

T['the cursor']['jumped down onto a line of the graph alone goes on to the commit line below'] = function()
  local top, commits = pane_showing_the_graph('graphpane-jump')
  expect_lines(COMMITS, whole_graph(top, commits))
  expect_cursor({ 1, 0 })

  child.type_keys('6G')

  expect_cursor({ 7, 0 })
end

T['the cursor']['moved up onto a line of the graph alone goes on to the commit line above'] = function()
  local top, commits = pane_showing_the_graph('graphpane-up')
  expect_lines(COMMITS, whole_graph(top, commits))
  child.type_keys('jj')
  expect_cursor({ 4, 0 })

  child.type_keys('<Up>')

  expect_cursor({ 2, 0 })
end

T['the cursor']['moved up by - and <C-p> passes each line of the graph alone'] = function()
  local top, commits = pane_showing_the_graph('graphpane-minus')
  expect_lines(COMMITS, whole_graph(top, commits))
  child.type_keys('G')
  expect_cursor({ 7, 0 })

  child.type_keys('-')

  expect_cursor({ 5, 0 })
  child.type_keys('<C-p>')
  expect_cursor({ 4, 0 })
  child.type_keys('<C-p>')
  expect_cursor({ 2, 0 })
end

T['the cursor']['clicked on a line of the graph alone below it goes on to the commit line below'] = function()
  local top, commits = pane_showing_the_graph('graphpane-click')
  expect_lines(COMMITS, whole_graph(top, commits))
  expect_cursor({ 1, 0 })

  child.lua(CLICK_COMMITS_LINE, { 3 })

  expect_cursor({ 4, 0 })
end

--- The Lua that counts, in the child, the calls the git home is asked for
--- the session's commits, the files of a commit and the files changed since
--- the base, and the answers each was given (`_G.reads`); a read asked for
--- while one answers is counted before that answer is.
local COUNT_READS = [[
  local git = require('aineo.git')
  _G.reads = {}
  for _, name in ipairs({ 'commits_since', 'commit_files', 'changed_files' }) do
    local original = git[name]
    _G.reads[name] = { calls = 0, answers = 0 }
    git[name] = function(...)
      local counted = _G.reads[name]
      counted.calls = counted.calls + 1
      local arguments = { ... }
      local done = arguments[3]
      arguments[3] = function(...)
        done(...)
        counted.answers = counted.answers + 1
      end
      return original(unpack(arguments, 1, select('#', ...)))
    end
  end
]]

--- Waits until the child has read the session's commits again since
--- `COUNT_READS` began counting, and every read it counts was answered.
local function wait_for_the_reads()
  git_repo.wait_until('every read answered', function()
    return child.lua_get([[_G.reads.commits_since.answers > 0
      and _G.reads.commits_since.answers == _G.reads.commits_since.calls
      and _G.reads.commit_files.answers == _G.reads.commit_files.calls
      and _G.reads.changed_files.answers == _G.reads.changed_files.calls]])
  end)
end

T['the files window']['keeps listing the graph commit chosen when the session’s commits are read again'] = function()
  local _, commits = pane_showing_the_graph('graphpane-reread')
  local listed = {
    'Files in: ' .. git_repo.commit_line_of(commits.other, CAROL, 'Other work'),
    '  A more.txt',
    '  A other.txt',
  }
  expect_lines(FILES, listed)
  child.lua(COUNT_READS)

  child.lua("require('aineo.changes').refresh_shown_pane()")

  wait_for_the_reads()
  eq(lines_of(FILES), listed)
end

T['the files window']['keeps listing the session’s commit chosen when t shows the graph, the cursor on its line'] = function()
  local top = git_repo.create_graph('graphpane-chosen')
  begin_and_show(top)
  expect_lines(COMMITS, SECTIONS)
  git_repo.write(top, 'later.txt', { 'later' })
  local later = git_repo.commit_all_dated(top, 'Later work', 'Ada', git_repo.GRAPH_STARTS_AT + 200)
  child.lua("require('aineo.changes').refresh_shown_pane()")
  local chosen = {
    'Files in: ' .. git_repo.commit_line_of(later, ADA, 'Later work'),
    '  A later.txt',
  }
  enter_window_of(COMMITS)
  child.type_keys('3G')
  expect_lines(FILES, chosen)

  child.type_keys('t')

  expect_cursor_line_ending(
    later:sub(1, 7)
      .. ' - ('
      .. git_repo.relative_age(top, later)
      .. ') Later work - Ada (HEAD -> main)'
  )
  expect_lines(FILES, chosen)
end

return T
