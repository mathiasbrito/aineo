local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The name of the module's own changes pane's files buffer.
local FILES = 'aineo://changes-files'

--- The name of the module's own changes pane's commits buffer.
local COMMITS = 'aineo://changes-commits'

--- Two Claude Code session ids.
local SESSION_A = '11111111-1111-4111-8111-111111111111'
local SESSION_B = '22222222-2222-4222-8222-222222222222'

--- The hunk header a diff of a file of twenty lines has when it shows the
--- whole file.
local WHOLE_HUNK = '@@ -1,20 +1,20 @@'

--- The hunk header a diff of a file of twenty lines, its tenth changed, has
--- when it shows three lines of context.
local THREE_LINES_HUNK = '@@ -7,7 +7,7 @@'

--- What the commits window says when the session has no commit.
local NO_COMMITS = 'No commits on this session'

--- The Lua that defines, in the child, `_G.start_copy(key, directory)`: it
--- makes the changes home `key` names — the module's own for `'module'`, a
--- copy of its own (`new()`) for any other — in `_G.homes[key]`, begins its
--- session for `directory`, and shows its two buffers in a tab page of
--- its own: the files buffer in the tab's window, the commits buffer in a
--- window below it. Every buffer the home asks to show as a diff is kept in
--- `_G.diffs[key]` and shown in the window already showing it, or else in a
--- window of its own at the bottom of the tab, the cursor left where it is.
--- Its pane's buffers are in `_G.panes[key]`. The git home's looks for a
--- repository answered are counted in `_G.finds_answered`, each once its
--- caller's `done` has run, and the watches it started and stopped in
--- `_G.watches`.
local COPIES = [[
  _G.homes, _G.panes, _G.diffs = {}, {}, {}
  local git = require('aineo.git')
  local find_repository = git.find_repository
  _G.finds_answered = 0
  git.find_repository = function(directory, done, options)
    return find_repository(directory, function(...)
      done(...)
      _G.finds_answered = _G.finds_answered + 1
    end, options)
  end
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
  _G.start_copy = function(key, directory)
    local changes = require('aineo.changes')
    local home = key == 'module' and changes or changes.new()
    _G.homes[key], _G.diffs[key] = home, {}
    home.begin_session({
      directory = directory,
      show_diff = function(diff)
        table.insert(_G.diffs[key], diff)
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
local function start_copy(key, directory)
  child.lua('_G.start_copy(...)', { key, directory })
end

--- The lines of the buffer `which` (`files` or `commits`) of the pane of
--- the changes home `key` names, in the child; one line saying so when the
--- buffer is gone.
---
---@param key string
---@param which 'files'|'commits'
---@return string[]
local function pane_lines(key, which)
  return child.lua_get(
    [[(function(key, which)
      local buffer = _G.panes[key][which]
      if not vim.api.nvim_buf_is_valid(buffer) then
        return { 'the ' .. which .. ' buffer of ' .. key .. ' is gone' }
      end
      return vim.api.nvim_buf_get_lines(buffer, 0, -1, true)
    end)(...)]],
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
--- changes home `key` names the current window, in its tab page.
---
---@param key string
---@param which 'files'|'commits'
local function enter_window_of(key, which)
  child.lua(
    'vim.api.nvim_set_current_win(vim.fn.win_findbuf(_G.panes[...][select(2, ...)])[1])',
    { key, which }
  )
end

--- Waits until the git home has answered `count` looks for a repository
--- (`COPIES`).
---
---@param count integer
local function wait_for_finds(count)
  git_repo.wait_until(('%d looks for the repository answered'):format(count), function()
    return child.lua_get('_G.finds_answered') >= count
  end)
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

--- Opens `path` in a window above the current one, writes `text` as its
--- only line and saves it there, and goes back to the window it came from.
---
---@param path string
---@param text string
local function save_file(path, text)
  child.lua(
    [[
      local path, text = ...
      local back = vim.api.nvim_get_current_win()
      vim.cmd('aboveleft split ' .. vim.fn.fnameescape(path))
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { text })
      vim.cmd('write')
      vim.api.nvim_set_current_win(back)
    ]],
    { path, text }
  )
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

--- The lines `1…count` of a file, line `n` reading `line n`, the lines
--- named in `changed` reading `changed <n>`.
---
---@param count integer
---@param changed? integer[]
---@return string[]
local function numbered_lines(count, changed)
  local lines = {}
  for number = 1, count do
    lines[number] = 'line ' .. number
  end
  for _, number in ipairs(changed or {}) do
    lines[number] = 'changed ' .. number
  end
  return lines
end

--- Waits until the changes home `key` names has been asked to show `count`
--- diffs.
---
---@param key string
---@param count integer
local function wait_for_diffs(key, count)
  git_repo.wait_until(('%d diffs shown by %s'):format(count, key), function()
    return child.lua_get('#_G.diffs[...]', { key }) >= count
  end)
end

--- Presses Enter on line `line` of the files window of the changes home
--- `key` names and waits until that home has been asked to show `count`
--- diffs.
---
---@param key string
---@param line integer
---@param count integer
local function open_file_at(key, line, count)
  enter_window_of(key, 'files')
  child.type_keys(line .. 'G', '<CR>')
  wait_for_diffs(key, count)
end

--- The hunk headers of the diff buffer the changes home `key` names was
--- asked to show last.
---
---@param key string
---@return string[]
local function hunk_headers_shown(key)
  local headers = {}
  for _, line in
    ipairs(
      child.lua_get(
        'vim.api.nvim_buf_get_lines(_G.diffs[...][#_G.diffs[...]], 0, -1, true)',
        { key }
      )
    )
  do
    table.insert(headers, line:match('^(@@ [^@]+ @@)'))
  end
  return headers
end

--- Waits until the hunk headers of the diff buffer the changes home `key`
--- names was asked to show last are `expected`, and asserts that they are.
---
---@param key string
---@param expected string[]
local function expect_hunks_shown(key, expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(hunk_headers_shown(key), expected)
  end, 10)
  eq(hunk_headers_shown(key), expected)
end

--- The first buffer the changes home `key` names was asked to show: its
--- name, whether it exists, and in how many windows it is shown.
---
---@param key string
---@return { name: string, valid: boolean, windows: integer }
local function first_shown_of(key)
  return child.lua_get(
    [[(function(key)
      local buffer = _G.diffs[key][1]
      local valid = vim.api.nvim_buf_is_valid(buffer)
      return {
        name = valid and vim.api.nvim_buf_get_name(buffer) or 'wiped',
        valid = valid,
        windows = valid and #vim.fn.win_findbuf(buffer) or 0,
      }
    end)(...)]],
    { key }
  )
end

T['new()'] = MiniTest.new_set()

T['new()']['gives a home of its own on each call, with the functions the module has'] = function()
  local homes = child.lua_get([[(function()
    local changes = require('aineo.changes')
    local first, second = changes.new(), changes.new()
    local names = {
      'begin_session',
      'follow_changes_session',
      'hand_over_changes_session',
      'refresh_shown_pane',
      'pane_buffers',
    }
    local shape = { functions = {}, apart = {} }
    for _, name in ipairs(names) do
      shape.functions[name] = type(first[name]) == 'function' and type(second[name]) == 'function'
      shape.apart[name] = first[name] ~= second[name] and first[name] ~= changes[name]
    end
    shape.tables = { first ~= second, first ~= changes, second ~= changes }
    return shape
  end)()]])
  eq(homes, {
    functions = {
      begin_session = true,
      follow_changes_session = true,
      hand_over_changes_session = true,
      refresh_shown_pane = true,
      pane_buffers = true,
    },
    apart = {
      begin_session = true,
      follow_changes_session = true,
      hand_over_changes_session = true,
      refresh_shown_pane = true,
      pane_buffers = true,
    },
    tables = { true, true, true },
  })
end

T['new()']['after the module was loaded again does not take the label of a home that lives'] = function()
  local panes = child.lua_get([[(function()
    local old = require('aineo.changes').new().pane_buffers()
    package.loaded['aineo.changes'] = nil
    local new = require('aineo.changes').new().pane_buffers()
    local valid = vim.api.nvim_buf_is_valid(old.files)
    return {
      old_valid = valid,
      old_name = valid and vim.api.nvim_buf_get_name(old.files) or 'wiped',
      new_name = vim.api.nvim_buf_get_name(new.files),
    }
  end)()]])
  eq(panes, {
    old_valid = true,
    old_name = 'aineo://copy1/changes-files',
    new_name = 'aineo://copy2/changes-files',
  })
end

T['begin_session()'] = MiniTest.new_set()

T['begin_session()']['of a second copy leaves the first copy’s lists as they were'] = function()
  local first = git_repo.create('changescopies-begin-first', { ['a.txt'] = { 'one' } })
  local second = git_repo.create('changescopies-begin-second', { ['b.txt'] = { 'one' } })
  git_repo.write(first, 'a.txt', { 'changed' })
  git_repo.write(second, 'b.txt', { 'changed' })
  start_copy('first', first)
  expect_pane_lines('first', 'files', { 'Files in: Session work', '  M a.txt' })
  expect_pane_lines('first', 'commits', { 'Uncommitted', 'Session work', NO_COMMITS })

  start_copy('second', second)

  expect_pane_lines('second', 'files', { 'Files in: Session work', '  M b.txt' })
  eq(pane_lines('first', 'files'), { 'Files in: Session work', '  M a.txt' })
  eq(pane_lines('first', 'commits'), { 'Uncommitted', 'Session work', NO_COMMITS })
end

T['pane_buffers()'] = MiniTest.new_set()

T['pane_buffers()']['of a second copy wipes nothing of the first copy’s, and every buffer has a name of its own'] = function()
  local top = git_repo.create('changescopies-names', { ['a.txt'] = { 'one' } })
  start_copy('first', top)
  start_copy('second', top)

  eq(
    child.lua_get([[(function()
      local names, loaded = {}, true
      for _, key in ipairs({ 'first', 'second' }) do
        for _, buffer in pairs(_G.panes[key]) do
          local valid = vim.api.nvim_buf_is_valid(buffer)
          names[valid and vim.api.nvim_buf_get_name(buffer) or 'wiped'] = true
          loaded = loaded and valid and vim.api.nvim_buf_is_loaded(buffer)
        end
      end
      return { vim.tbl_count(names), loaded }
    end)()]]),
    { 4, true }
  )
end

T['pane_buffers()']['of the module keep the names the module has had'] = function()
  local top = git_repo.create('changescopies-module-names', { ['a.txt'] = { 'one' } })
  start_copy('module', top)
  start_copy('copy', top)

  eq(
    child.lua_get([[vim.tbl_map(function(buffer)
        return vim.api.nvim_buf_is_valid(buffer) and vim.api.nvim_buf_get_name(buffer) or 'wiped'
      end, { _G.panes.module.files, _G.panes.module.commits })]]),
    { FILES, COMMITS }
  )
end

T['following sessions'] = MiniTest.new_set()

T['following sessions']['keeps each copy’s own base'] = function()
  local top = git_repo.create('changescopies-bases', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changescopies-bases-state')
  start_copy('first', top)
  wait_for_finds(1)
  follow('first', SESSION_A, state)
  wait_for_finds(2)
  local commit = commit_only(top, 'other.txt', 'other', 'Made after the first')
  start_copy('second', top)
  wait_for_finds(3)
  follow('second', SESSION_B, state)
  wait_for_finds(4)

  expect_pane_lines(
    'first',
    'commits',
    { 'Uncommitted', 'Session work', commit_line(commit, 'Made after the first') }
  )
  expect_pane_lines('second', 'commits', { 'Uncommitted', 'Session work', NO_COMMITS })
end

T['a save'] = MiniTest.new_set()

T['a save']['marks the file in each copy whose repository holds it, and in no other'] = function()
  local top = git_repo.create('changescopies-saves', { ['notes.txt'] = { 'one' } })
  local other = git_repo.create('changescopies-saves-other', { ['notes.txt'] = { 'one' } })
  git_repo.write(other, 'notes.txt', { 'changed' })
  start_copy('first', top)
  start_copy('second', other)
  start_copy('third', top)
  wait_for_finds(3)
  expect_pane_lines('second', 'files', { 'Files in: Session work', '  M notes.txt' })

  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')

  expect_pane_lines('first', 'files', { 'Files in: Session work', '* M notes.txt' })
  expect_pane_lines('third', 'files', { 'Files in: Session work', '* M notes.txt' })
  eq(pane_lines('second', 'files'), { 'Files in: Session work', '  M notes.txt' })
end

T['the commits window'] = MiniTest.new_set()

T['the commits window']['of one copy selects the filter of its own files window alone'] = function()
  local top = git_repo.create('changescopies-filter', { ['a.txt'] = { 'one' } })
  start_copy('first', top)
  start_copy('second', top)
  wait_for_finds(2)
  local change_a = commit_only(top, 'a.txt', 'two', 'Change a')
  local add_b = commit_only(top, 'b.txt', 'one', 'Add b')
  expect_pane_lines('first', 'files', { 'Files in: Session work', '  M a.txt', '  A b.txt' })
  expect_pane_lines('second', 'files', { 'Files in: Session work', '  M a.txt', '  A b.txt' })

  enter_window_of('first', 'commits')
  child.type_keys('4G')
  enter_window_of('second', 'commits')
  child.type_keys('3G')

  expect_pane_lines(
    'first',
    'files',
    { 'Files in: ' .. change_a:sub(1, 7) .. ' Change a', '  M a.txt' }
  )
  expect_pane_lines('second', 'files', { 'Files in: ' .. add_b:sub(1, 7) .. ' Add b', '  A b.txt' })
  eq(
    pane_lines('first', 'files'),
    { 'Files in: ' .. change_a:sub(1, 7) .. ' Change a', '  M a.txt' }
  )
end

T['Enter'] = MiniTest.new_set()

T['Enter']['on the same file in two copies’ panes shows each its own diff, in a window of its own'] = function()
  local top = git_repo.create('changescopies-enter', { ['a.txt'] = numbered_lines(20) })
  git_repo.write(top, 'a.txt', numbered_lines(20, { 10 }))
  start_copy('first', top)
  start_copy('second', top)
  expect_pane_lines('first', 'files', { 'Files in: Session work', '  M a.txt' })
  expect_pane_lines('second', 'files', { 'Files in: Session work', '  M a.txt' })

  open_file_at('first', 2, 1)
  open_file_at('second', 2, 1)

  local first, second = first_shown_of('first'), first_shown_of('second')
  eq({ first.valid, first.windows, second.valid, second.windows }, { true, 1, true, 1 })
  eq(first.name ~= second.name, true)
  eq(child.lua_get('_G.diffs.first[1] ~= _G.diffs.second[1]'), true)
end

T['Enter']['in two copies’ panes before git answers shows both diffs'] = function()
  local top = git_repo.create('changescopies-enter-at-once', { ['a.txt'] = numbered_lines(20) })
  git_repo.write(top, 'a.txt', numbered_lines(20, { 10 }))
  start_copy('first', top)
  start_copy('second', top)
  expect_pane_lines('first', 'files', { 'Files in: Session work', '  M a.txt' })
  expect_pane_lines('second', 'files', { 'Files in: Session work', '  M a.txt' })

  child.lua([[
    for _, key in ipairs({ 'first', 'second' }) do
      vim.api.nvim_set_current_win(vim.fn.win_findbuf(_G.panes[key].files)[1])
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      vim.api.nvim_feedkeys(vim.keycode('<CR>'), 'x', false)
    end
  ]])

  wait_for_diffs('first', 1)
  wait_for_diffs('second', 1)
end

T['Enter']['in a copy, read while textlock holds, then on another file, keeps no buffer of the first diff'] = function()
  local top =
    git_repo.create('changescopies-enter-textlock', { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } })
  git_repo.write(top, 'a.txt', { 'a2' })
  git_repo.write(top, 'b.txt', { 'b2' })
  local stand_in = git_repo.script('changescopies-enter-textlock', 'git', {
    'case " $* " in *" diff "*a.txt*) while [ ! -f "$0.gate" ]; do sleep 0.05; done ;; esac',
    ('exec %s "$@"'):format(vim.fn.exepath('git')),
  })
  child.lua(
    [[
      _G.holding, _G.diffs_read = false, 0
      local git = require('aineo.git')
      local file_diff = git.file_diff
      git.file_diff = function(...)
        local arguments = { ... }
        for index = 1, select('#', ...) do
          if type(arguments[index]) == 'function' then
            local done = arguments[index]
            arguments[index] = function(...)
              _G.diffs_read = _G.diffs_read + 1
              done(...)
            end
          end
        end
        return file_diff(unpack(arguments, 1, select('#', ...)))
      end
      vim.keymap.set('n', 'X', function()
        _G.holding = true
        vim.fn.getcharstr()
        _G.holding = false
        return ''
      end, { expr = true })
      local home = require('aineo.changes').new()
      home.begin_session({
        directory = (...),
        git = { executable = (select(2, ...)) },
        show_diff = function(diff)
          table.insert(_G.shown, diff)
          return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
        end,
      })
      _G.shown = {}
      local panes = home.pane_buffers()
      vim.cmd('tabnew')
      vim.api.nvim_win_set_buf(0, panes.files)
      _G.files = panes.files
    ]],
    { top, stand_in }
  )
  git_repo.wait_until('the files listed', function()
    return vim.deep_equal(
      child.lua_get('vim.api.nvim_buf_get_lines(_G.files, 0, -1, true)'),
      { 'Files in: Session work', '  M a.txt', '  M b.txt' }
    )
  end)
  child.type_keys('j<CR>')
  child.api.nvim_input('X')
  git_repo.wait_until('the hold', function()
    return child.lua_get('_G.holding == true')
  end)
  vim.fn.writefile({}, stand_in .. '.gate')
  git_repo.wait_until('the diff of a.txt read', function()
    return child.lua_get('_G.diffs_read == 1')
  end)

  child.api.nvim_input('qj<CR>')

  git_repo.wait_until('the diff of b.txt read', function()
    return child.lua_get('_G.diffs_read == 2')
  end)
  vim.wait(git_repo.PATIENCE_MS, function()
    return child.fn.bufexists('aineo://copy1/diff/a.txt') == 0
  end, 10)
  eq({
    shown = child.lua_get('vim.tbl_map(vim.api.nvim_buf_get_name, _G.shown)'),
    kept = child.fn.bufexists('aineo://copy1/diff/a.txt'),
  }, { shown = { 'aineo://copy1/diff/b.txt' }, kept = 0 })
end

T['Enter']['in the module’s pane names its diff as it always has'] = function()
  local top = git_repo.create('changescopies-enter-module', { ['a.txt'] = numbered_lines(20) })
  git_repo.write(top, 'a.txt', numbered_lines(20, { 10 }))
  start_copy('module', top)
  expect_pane_lines('module', 'files', { 'Files in: Session work', '  M a.txt' })

  open_file_at('module', 2, 1)

  eq(first_shown_of('module').name, 'aineo://diff/a.txt')
end

T['gf'] = MiniTest.new_set()

T['gf']['on the same commit’s file in two copies’ panes shows each its own file'] = function()
  local top = git_repo.create('changescopies-gf', { ['a.txt'] = { 'one' } })
  start_copy('first', top)
  start_copy('second', top)
  wait_for_finds(2)
  local commit = commit_only(top, 'a.txt', 'two', 'Change a')
  local commit_files = { 'Files in: ' .. commit:sub(1, 7) .. ' Change a', '  M a.txt' }
  for _, key in ipairs({ 'first', 'second' }) do
    expect_pane_lines(
      key,
      'commits',
      { 'Uncommitted', 'Session work', commit_line(commit, 'Change a') }
    )
    enter_window_of(key, 'commits')
    child.type_keys('4G')
    expect_pane_lines(key, 'files', commit_files)
  end

  for _, key in ipairs({ 'first', 'second' }) do
    enter_window_of(key, 'files')
    child.type_keys('2G', 'gf')
    wait_for_diffs(key, 1)
  end

  local first, second = first_shown_of('first'), first_shown_of('second')
  eq({ first.valid, first.windows, second.valid, second.windows }, { true, 1, true, 1 })
  eq(first.name ~= second.name, true)
  eq(child.lua_get('_G.diffs.first[1] ~= _G.diffs.second[1]'), true)
end

T['F'] = MiniTest.new_set()

T['F']['in one copy’s diff opens the next diff of the other copy with the whole file as its context'] = function()
  local top = git_repo.create('changescopies-f', { ['a.txt'] = numbered_lines(20) })
  git_repo.write(top, 'a.txt', numbered_lines(20, { 10 }))
  start_copy('first', top)
  start_copy('second', top)
  expect_pane_lines('first', 'files', { 'Files in: Session work', '  M a.txt' })
  expect_pane_lines('second', 'files', { 'Files in: Session work', '  M a.txt' })
  open_file_at('first', 2, 1)
  expect_hunks_shown('first', { THREE_LINES_HUNK })

  child.type_keys('F')
  expect_hunks_shown('first', { WHOLE_HUNK })
  open_file_at('second', 2, 1)

  expect_hunks_shown('second', { WHOLE_HUNK })
end

T['F']['in two copies’ diffs before git answers shows each the whole file'] = function()
  local top = git_repo.create('changescopies-f-at-once', { ['a.txt'] = numbered_lines(20) })
  git_repo.write(top, 'a.txt', numbered_lines(20, { 10 }))
  start_copy('first', top)
  start_copy('second', top)
  expect_pane_lines('first', 'files', { 'Files in: Session work', '  M a.txt' })
  expect_pane_lines('second', 'files', { 'Files in: Session work', '  M a.txt' })
  open_file_at('first', 2, 1)
  open_file_at('second', 2, 1)
  expect_hunks_shown('first', { THREE_LINES_HUNK })
  expect_hunks_shown('second', { THREE_LINES_HUNK })

  child.lua([[
    for _, key in ipairs({ 'first', 'second' }) do
      vim.api.nvim_set_current_win(vim.fn.win_findbuf(_G.diffs[key][1])[1])
      vim.api.nvim_feedkeys('F', 'x', false)
    end
  ]])

  expect_hunks_shown('first', { WHOLE_HUNK })
  expect_hunks_shown('second', { WHOLE_HUNK })
end

T['the watch'] = MiniTest.new_set()

T['the watch']['of each copy runs once its pane is shown and stops at quit'] = function()
  local top = git_repo.create('changescopies-watch', { ['a.txt'] = { 'one' } })
  start_copy('first', top)
  start_copy('second', top)
  git_repo.wait_until('both copies’ watches started', function()
    return child.lua_get('_G.watches.started') == 2
  end)

  child.cmd('doautocmd VimLeavePre')

  eq(child.lua_get('_G.watches'), { started = 2, stopped = 2 })
end

T['let_go()'] = MiniTest.new_set()

--- Whether the autocommand group `name` exists in the child.
---
---@param name string
---@return boolean
local function group_exists(name)
  return child.lua_get('(pcall(vim.api.nvim_get_autocmds, { group = ... }))', { name })
end

T['let_go()']['is a field of a home new() made, and not of the module'] = function()
  eq(
    child.lua_get([[(function()
      local changes = require('aineo.changes')
      return { home = type(changes.new().let_go), module = type(changes.let_go) }
    end)()]]),
    { home = 'function', module = 'nil' }
  )
end

T['let_go()']['stops the watch, removes the handlers and wipes the two pane buffers of its copy, and leaves the other copy’s'] = function()
  local top = git_repo.create('changescopies-let-go', { ['a.txt'] = { 'one' } })
  start_copy('first', top)
  start_copy('second', top)
  git_repo.wait_until('both copies’ watches started', function()
    return child.lua_get('_G.watches.started') == 2
  end)

  child.lua('_G.homes.second.let_go()')

  eq(
    child.lua_get([[{
      watches = _G.watches,
      first_panes = vim.api.nvim_buf_is_valid(_G.panes.first.files)
        and vim.api.nvim_buf_is_valid(_G.panes.first.commits),
      second_files = vim.api.nvim_buf_is_valid(_G.panes.second.files),
      second_commits = vim.api.nvim_buf_is_valid(_G.panes.second.commits),
    }]]),
    {
      watches = { started = 2, stopped = 1 },
      first_panes = true,
      second_files = false,
      second_commits = false,
    }
  )
  eq({
    first_save = group_exists('aineo_changes_copy1'),
    first_scroll = group_exists('aineo_changes_commits_scroll_copy1'),
    second_save = group_exists('aineo_changes_copy2'),
    second_scroll = group_exists('aineo_changes_commits_scroll_copy2'),
  }, { first_save = true, first_scroll = true, second_save = false, second_scroll = false })
end

T['let_go()']['wipes the diffs of its copy, and leaves the other copy’s'] = function()
  local top = git_repo.create('changescopies-let-go-diffs', { ['a.txt'] = numbered_lines(20) })
  git_repo.write(top, 'a.txt', numbered_lines(20, { 10 }))
  start_copy('first', top)
  start_copy('second', top)
  expect_pane_lines('first', 'files', { 'Files in: Session work', '  M a.txt' })
  expect_pane_lines('second', 'files', { 'Files in: Session work', '  M a.txt' })
  open_file_at('first', 2, 1)
  open_file_at('second', 2, 1)

  child.lua('_G.homes.second.let_go()')

  eq(
    { first = first_shown_of('first').valid, second = first_shown_of('second').valid },
    { first = true, second = false }
  )
end

T['let_go()']['starts no watch when the repository is found after it'] = function()
  local top = git_repo.create('changescopies-let-go-late', { ['a.txt'] = { 'one' } })

  child.lua('_G.start_copy(...); _G.homes.first.let_go()', { 'first', top })
  wait_for_finds(1)

  eq(child.lua_get('_G.watches'), { started = 0, stopped = 0 })
end

T['the scroll handlers'] = MiniTest.new_set()

T['the scroll handlers']['of the commits windows are one for each copy'] = function()
  local top = git_repo.create('changescopies-scroll', { ['a.txt'] = { 'one' } })
  start_copy('first', top)
  start_copy('second', top)

  eq(
    child.lua_get([[#vim.tbl_filter(function(autocmd)
      return vim.startswith(autocmd.desc or '', 'aineo: select the filter of the files window after a pause, as a scroll')
    end, vim.api.nvim_get_autocmds({ event = 'WinScrolled' }))]]),
    2
  )
end

return T
