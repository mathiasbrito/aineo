local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
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

--- The Lua that makes, in the child, a changes home of its own in
--- `_G.home`, begins its session with the settings `...` gives, and shows
--- its pane's two buffers in the current tab page: the files buffer in the
--- current window, the commits buffer in a window below it. The git home's
--- watches started and stopped are counted in `_G.watches`.
local BEGIN_AND_SHOW = [[
  local settings = ...
  local git = require('aineo.git')
  local watch_repository = git.watch_repository
  _G.watches = { started = 0, stopped = 0 }
  git.watch_repository = function(...)
    local watch, failure = watch_repository(...)
    _G.watches.started = _G.watches.started + 1
    if watch then
      local stop = watch.stop
      watch.stop = function()
        _G.watches.stopped = _G.watches.stopped + 1
        return stop()
      end
    end
    return watch, failure
  end
  _G.home = require('aineo.changes').new()
  _G.heard = 0
  _G.home.on_repository_change(function()
    _G.heard = _G.heard + 1
  end)
  settings.show_diff = function(diff)
    local showing = vim.fn.bufwinid(diff)
    if showing ~= -1 then
      return showing
    end
    return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
  end
  _G.home.begin_session(settings)
  _G.pane = _G.home.pane_buffers()
  vim.api.nvim_win_set_buf(0, _G.pane.files)
  vim.api.nvim_open_win(_G.pane.commits, false, { split = 'below' })
]]

--- Begins a home's session in the child for `directory`, with `settings`
--- besides it, and shows its pane (`BEGIN_AND_SHOW`).
---
---@param directory string
---@param settings? table
local function begin_and_show(directory, settings)
  child.lua(BEGIN_AND_SHOW, { vim.tbl_extend('force', { directory = directory }, settings or {}) })
end

--- The lines of the buffer `which` (`'files'` or `'commits'`) of the home's
--- pane in the child.
---
---@param which 'files'|'commits'
---@return string[]
local function lines_of(which)
  return child.lua_get('vim.api.nvim_buf_get_lines(_G.pane[...], 0, -1, true)', { which })
end

--- Waits until line `index` of the files buffer is `expected`, at most
--- `git_repo.PATIENCE_MS`, and asserts that it is.
---
---@param index integer
---@param expected string
local function expect_files_line(index, expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return lines_of('files')[index] == expected
  end, 10)
  eq(lines_of('files')[index], expected)
end

--- Asks the home in the child for the count of the files of *Session work*,
--- and waits for the answer.
---
---@return integer|nil
local function session_work_count()
  child.lua([[
    _G.counted, _G.count = false, nil
    _G.home.count_session_work(function(count)
      _G.counted, _G.count = true, count
    end)
  ]])
  git_repo.wait_until('the count is told', function()
    return child.lua_get('_G.counted')
  end)
  return child.lua_get('_G.count')
end

--- The abbreviated id of `commit`, a full id, as the pane shows it.
---
---@param commit string
---@return string
local function short(commit)
  return commit:sub(1, 7)
end

--- Shows another buffer in the files window and then the pane's again, as
--- hiding the pane and showing it afterwards does.
local function hide_and_show_the_pane()
  child.lua([[
    local window = vim.fn.bufwinid(_G.pane.files)
    vim.api.nvim_win_set_buf(window, vim.api.nvim_create_buf(false, true))
    vim.api.nvim_win_set_buf(window, _G.pane.files)
  ]])
end

T['the base words'] = MiniTest.new_set()

T['the base words']['are what the Against line says of the base of Session work when the session gives them'] = function()
  local top, base = git_repo.create('project-home-words', { ['a.txt'] = { 'one' } })

  begin_and_show(top, { base_words = 'first touched' })

  expect_files_line(2, ('Against: %s (main) first touched → working tree'):format(short(base)))
end

T['the base words']['are the session start when the session gives none'] = function()
  local top, base = git_repo.create('project-home-no-words', { ['a.txt'] = { 'one' } })

  begin_and_show(top)

  expect_files_line(2, ('Against: %s (main) session start → working tree'):format(short(base)))
end

T['the base words']['are what the bar of a diff of Session work says too'] = function()
  local top = git_repo.create('project-home-bar', { ['a.txt'] = { 'one' } })
  git_repo.write(top, 'a.txt', { 'two' })
  begin_and_show(top, { base_words = 'first touched' })
  expect_files_line(1, 'Files in: Session work')
  git_repo.wait_until('the file is listed', function()
    return lines_of('files')[3] ~= nil and lines_of('files')[3]:find('a.txt', 1, true) ~= nil
  end)

  child.lua([[
    vim.api.nvim_set_current_win(vim.fn.bufwinid(_G.pane.files))
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.api.nvim_input('<CR>')
  ]])
  git_repo.wait_until('the diff has a bar', function()
    return child.lua_get([[(function()
      for _, window in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_get_option_value('winbar', { win = window }):find('first touched', 1, true) then
          return true
        end
      end
      return false
    end)()]])
  end)
end

T['the count of Session work'] = MiniTest.new_set()

T['the count of Session work']['is 0 while nothing changed since the base'] = function()
  local top = git_repo.create('project-home-count-none', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  expect_files_line(1, 'Files in: Session work')

  eq(session_work_count(), 0)
end

T['the count of Session work']['counts the files that differ from the base, untracked ones too'] = function()
  local top = git_repo.create('project-home-count', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  expect_files_line(1, 'Files in: Session work')
  git_repo.write(top, 'a.txt', { 'two' })
  git_repo.write(top, 'b.txt', { 'new' })

  eq(session_work_count(), 2)
end

T['the count of Session work']['counts the files of a commit made since the base'] = function()
  local top = git_repo.create('project-home-count-commit', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  expect_files_line(1, 'Files in: Session work')
  git_repo.write(top, 'c.txt', { 'three' })
  git_repo.commit_all(top, 'Add c')

  eq(session_work_count(), 1)
end

T['the count of Session work']['is nil in a folder that is in no repository'] = function()
  local folder = fixture.directory('project-home-count-no-repository')
  begin_and_show(folder)
  git_repo.wait_until('the pane says there is no repository', function()
    return (lines_of('commits')[1] or ''):find('repository', 1, true) ~= nil
  end)

  eq(session_work_count(), vim.NIL)
end

T['the watch'] = MiniTest.new_set()

T['the watch']['stops when the home is told to stop watching'] = function()
  local top = git_repo.create('project-home-stop', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  git_repo.wait_until('the watch started', function()
    return child.lua_get('_G.watches.started') == 1
  end)

  child.lua('_G.home.stop_watching()')

  eq(child.lua_get('_G.watches'), { started = 1, stopped = 1 })
end

T['the watch']['starts again once the pane is shown again'] = function()
  local top = git_repo.create('project-home-restart', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  git_repo.wait_until('the watch started', function()
    return child.lua_get('_G.watches.started') == 1
  end)
  child.lua('_G.home.stop_watching()')

  hide_and_show_the_pane()

  git_repo.wait_until('the watch started again', function()
    return child.lua_get('_G.watches.started') == 2
  end)
end

T['the watch']['is not stopped twice by a stop after the home let it go'] = function()
  local top = git_repo.create('project-home-stop-none', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  git_repo.wait_until('the watch started', function()
    return child.lua_get('_G.watches.started') == 1
  end)
  child.lua('_G.home.let_go()')

  child.lua('_G.home.stop_watching()')

  eq(child.lua_get('_G.watches'), { started = 1, stopped = 1 })
end

T['a change heard'] = MiniTest.new_set()

T['a change heard']['is told to the listener when the home finds its repository'] = function()
  local top = git_repo.create('project-home-found', { ['a.txt'] = { 'one' } })

  begin_and_show(top)

  git_repo.wait_until('the listener heard of it', function()
    return child.lua_get('_G.heard') >= 1
  end)
end

T['a change heard']['is told to the listener when a file of the working tree changes'] = function()
  local top = git_repo.create('project-home-heard', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  git_repo.wait_until('the watch started', function()
    return child.lua_get('_G.watches.started') == 1
  end)
  local heard_before = child.lua_get('_G.heard')

  git_repo.write(top, 'a.txt', { 'two' })

  git_repo.wait_until('the listener heard of the change', function()
    return child.lua_get('_G.heard') > heard_before
  end)
end

T['a change heard']['is told to the listener when the home takes the base of a session'] = function()
  local top = git_repo.create('project-home-session', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  git_repo.wait_until('the watch started', function()
    return child.lua_get('_G.watches.started') == 1
  end)
  local heard_before = child.lua_get('_G.heard')

  child.lua([[_G.home.follow_changes_session({
    id = '11111111-1111-4111-8111-111111111111',
    state_directory = vim.fn.stdpath('state'),
  })]])

  git_repo.wait_until('the listener heard of the base', function()
    return child.lua_get('_G.heard') > heard_before
  end)
end

return T
