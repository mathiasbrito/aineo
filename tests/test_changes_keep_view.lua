local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- What `s` asks the picker for.
local PROMPT = 'Show alone in the changes pane'

--- Two Claude Code session ids.
local SESSION_A = '11111111-1111-4111-8111-111111111111'
local SESSION_B = '22222222-2222-4222-8222-222222222222'

--- The Lua that defines, in the child, `_G.start_copy(key, directory)`: it
--- makes the changes home `key` names — the module's own for `'module'`, a
--- copy of its own (`new()`) for any other — in `_G.homes[key]`, begins its
--- session for `directory` with a stand-in timer, and shows its two buffers
--- in a tab page of its own: the files buffer in the tab's window, the
--- commits buffer in a window below it. `_G.report(key, work)` hands the home
--- a report. `vim.ui.select` is replaced by a picker that keeps every request
--- in `_G.pickers`, answered by `_G.choose()`, and `vim.notify` by one that
--- keeps every message in `_G.messages`.
local COPIES = [[
  _G.homes, _G.panes, _G.pickers, _G.messages, _G.timers = {}, {}, {}, {}, {}
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
  _G.report = function(key, work)
    return _G.homes[key].add_reported_work(work, function() end)
  end
  _G.start_copy = function(key, directory)
    local changes = require('aineo.changes')
    local home = key == 'module' and changes or changes.new()
    _G.homes[key] = home
    home.begin_session({
      directory = directory,
      show_diff = function(diff)
        return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
      end,
      start_timer = function(milliseconds, act)
        local timer = { milliseconds = milliseconds, act = act, stopped = false }
        table.insert(_G.timers, timer)
        return function()
          timer.stopped = true
        end
      end,
    })
    vim.cmd('tabnew')
    _G.panes[key] = home.pane_buffers()
    vim.api.nvim_win_set_buf(0, _G.panes[key].files)
    vim.api.nvim_open_win(_G.panes[key].commits, false, { split = 'below' })
  end
]]

--- The Lua that counts, in `_G.branch_listings`, the git home's listings of
--- the local branches asked for, and in `_G.branch_listings_answered` those
--- answered once what asked has run: the view kept is read back after one,
--- and a record that is ignored never asks for it.
local COUNT_BRANCH_LISTINGS = [=[
  local git = require('aineo.git')
  local list_branches = git.list_branches
  _G.branch_listings, _G.branch_listings_answered = 0, 0
  git.list_branches = function(found, done, options)
    _G.branch_listings = _G.branch_listings + 1
    return list_branches(found, function(...)
      done(...)
      _G.branch_listings_answered = _G.branch_listings_answered + 1
    end, options)
  end
]=]

--- Starts the editor the cases drive anew, as a quit and a restart of
--- aineo does: nothing of the editor before it is left but the files it
--- wrote.
local function restart_editor()
  git_repo.start_editor(child)
  child.lua(COPIES)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = restart_editor,
    post_once = child.stop,
  },
})

--- Makes the changes home `key` names (`COPIES`) in the child for
--- `directory`, its pane shown.
---
---@param key string
---@param directory string
local function start_copy(key, directory)
  child.lua('_G.start_copy(...)', { key, directory })
end

--- Makes the changes home `key` names follow the Claude Code session `id`,
--- its base, saves and view kept under `state`.
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

--- Hands the changes home `key` names the report `work`.
---
---@param key string
---@param work table
local function report(key, work)
  child.lua('_G.report(...)', { key, work })
end

--- The messages the child told through `vim.notify`.
---
---@return string[]
local function messages()
  return child.lua_get([[vim.tbl_map(function(told)
    return told.message
  end, _G.messages)]])
end

--- The lines of the buffer `which` of the pane of the changes home `key`
--- names.
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
--- names holds `expected`, at most `git_repo.PATIENCE_MS`, and asserts it.
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

--- Waits until the first line of the files window of the pane of the changes
--- home `key` names is `expected`, at most `git_repo.PATIENCE_MS`, and
--- asserts it.
---
---@param key string
---@param expected string
local function expect_files_heading(key, expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return pane_lines(key, 'files')[1] == expected
  end, 10)
  eq(pane_lines(key, 'files')[1], expected)
end

--- Waits until `condition()` holds, at most `git_repo.PATIENCE_MS`.
---
---@param description string
---@param condition fun(): boolean
local function wait_until(description, condition)
  git_repo.wait_until(description, condition)
end

--- Makes the directory `name` beside the repository at `top` a worktree of
--- it on the new branch `branch`, and returns its top level.
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

--- Writes `text` as the only line of `path` under `top` and commits that file
--- alone as `subject`; returns the commit's full id.
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

--- Makes the local branch `name` in the repository at `top`, holding one
--- commit `subject` past `main`, checked out in no worktree; returns that
--- commit's full id.
---
---@param top string
---@param name string
---@param subject string
---@return string
local function add_branch(top, name, subject)
  local worktree = add_worktree(top, 'making-' .. name:gsub('/', '-'), name)
  local commit = commit_only(worktree, 'branch.txt', name, subject)
  git_repo.git(top, { 'worktree', 'remove', '--force', worktree })
  return commit
end

--- The commits window's line for `commit`, a full id, with `subject`.
---
---@param commit string
---@param subject string
---@return string
local function commit_line(commit, subject)
  return git_repo.commit_line(commit, subject)
end

--- The commits window's line for the commit the branch `name` of the
--- repository at `top` names, with `subject`.
---
---@param top string
---@param name string
---@param subject string
---@return string
local function last_commit_line(top, name, subject)
  return commit_line(git_repo.git(top, { 'rev-parse', 'refs/heads/' .. name }), subject)
end

--- The default view of a repository with no commit of the session's own and
--- no other worktree listed.
local DEFAULT_VIEW = { 'Uncommitted', 'Session work', 'No commits on this session' }

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

--- Switches the view of the pane of the home `key` names as `\g` does with
--- the cursor in its commits window (`toggle_focused_view()`).
---
---@param key string
local function toggle_in_pane(key)
  enter_window_of(key, 'commits')
  child.lua('_G.homes[...].toggle_focused_view()', { key })
end

--- Presses `s` in the commits window of the pane of the home `key` names
--- and waits until its picker opens, at most `git_repo.PATIENCE_MS`.
---
---@param key string
local function press_s(key)
  local before = child.lua_get('#_G.pickers')
  enter_window_of(key, 'commits')
  child.lua("pcall(vim.api.nvim_feedkeys, 's', 'mx', false)")
  wait_until('the picker opened', function()
    return child.lua_get('#_G.pickers') > before
  end)
end

--- The texts the last picker the child was asked for offers, and its prompt.
---
---@return { prompt: string, texts: string[] }
local function last_offered()
  return child.lua_get([[(function(request)
    return { prompt = request.options.prompt, texts = vim.tbl_map(request.options.format_item, request.items) }
  end)(_G.pickers[#_G.pickers])]])
end

--- Picks, with `s` in the pane of the home `key` names, the item at
--- `position` of what it offers.
---
---@param key string
---@param position integer
local function pick(key, position)
  press_s(key)
  child.lua('_G.choose(...)', { position })
end

--- Makes the repository `name` with one commit, starts the module's home on
--- it, follows the session `SESSION_A` with its record under the state
--- directory `state`, and waits for its default view.
---
---@param name string
---@param state string
---@return string top
local function start_on_repository(name, state)
  local top = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  start_copy('module', top)
  follow('module', SESSION_A, state)
  expect_pane_lines('module', 'commits', DEFAULT_VIEW)
  return top
end

--- Quits the editor and starts it again on the repository `top`, the module's
--- home following the session `id` with its record under `state`.
---
---@param top string
---@param id string
---@param state string
local function restart_on(top, id, state)
  restart_editor()
  child.lua(COUNT_BRANCH_LISTINGS)
  start_copy('module', top)
  follow('module', id, state)
end

--- Waits until the view kept has been read back and shown, at most
--- `git_repo.PATIENCE_MS`: the listing of the branches it waits for is
--- answered (`COUNT_BRANCH_LISTINGS`).
local function wait_for_restore()
  wait_until('the view kept read back', function()
    return child.lua_get('_G.branch_listings_answered') > 0
  end)
end

T['a restart'] = MiniTest.new_set()

T['a restart']['shows the worktree picked with s alone again'] = function()
  local state = fixture.directory('keep-view-worktree-state')
  local top = start_on_repository('keep-view-worktree', state)
  add_worktree(top, 'agent-1', 'feature/a')
  add_worktree(top, 'agent-2', 'feature/b')
  child.lua('_G.homes.module.refresh_shown_pane()')
  wait_until('both worktrees listed', function()
    return #pane_lines('module', 'commits') == 7
  end)
  pick('module', 2)
  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-2 (feature/b)', 'No commits in this worktree' }
  )

  restart_on(top, SESSION_A, state)

  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-2 (feature/b)', 'No commits in this worktree' }
  )
  expect_files_heading('module', 'Files in: Worktree agent-2 (feature/b)')
  eq(messages(), {})
end

--- The lines of the commits window for the worktree `folder` on `branch`
--- with no commit.
---
---@param folder string
---@param branch string
---@return string[]
local function bare_worktree(folder, branch)
  return { ('Worktree %s (%s)'):format(folder, branch), 'No commits in this worktree' }
end

--- The default view of a repository whose other worktrees, each of no
--- commit, are `others` (`bare_worktree()`).
---
---@param ... string[]
---@return string[]
local function default_view_with(...)
  local view = vim.list_slice(DEFAULT_VIEW)
  for _, other in ipairs({ ... }) do
    vim.list_extend(view, other)
  end
  return view
end

--- The default view of the repository the cases make with two worktrees:
--- `agent-1` on `feature/a` and `agent-2` on `feature/b`.
local DEFAULT_VIEW_WITH_BOTH =
  default_view_with(bare_worktree('agent-1', 'feature/a'), bare_worktree('agent-2', 'feature/b'))

--- The default view of the repository with a third worktree, `agent-3` on
--- `feature/c`.
local DEFAULT_VIEW_WITH_THREE = default_view_with(
  bare_worktree('agent-1', 'feature/a'),
  bare_worktree('agent-2', 'feature/b'),
  bare_worktree('agent-3', 'feature/c')
)

--- Waits until the commits window of the module's home lists `count` lines.
---
---@param count integer
local function wait_for_lines(count)
  wait_until('the commits window lists ' .. count .. ' lines', function()
    return #pane_lines('module', 'commits') == count
  end)
end

--- The path of the file that keeps the view of the session `id` under the
--- state directory `state`.
---
---@param state string
---@param id string
---@return string
local function view_file(state, id)
  return vim.fs.joinpath(state, 'aineo', 'changes-sessions', vim.fn.sha256(id) .. '.view.json')
end

--- Writes `text` as the whole of the file that keeps the view of the session
--- `id` under `state`.
---
---@param state string
---@param id string
---@param text string
local function write_view_file(state, id, text)
  local file = view_file(state, id)
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  assert(vim.fn.writefile({ text }, file) == 0, 'cannot write ' .. file)
end

--- Waits until the record of `SESSION_A` under `state` no longer holds `text`,
--- at most `git_repo.PATIENCE_MS`, and asserts it.
---
---@param state string
---@param text string
local function expect_record_without(state, text)
  local function holds()
    return table.concat(vim.fn.readfile(view_file(state, SESSION_A))):find(text, 1, true) ~= nil
  end
  vim.wait(git_repo.PATIENCE_MS, function()
    return not holds()
  end, 10)
  eq(holds(), false)
end

--- Makes the repository `name` with the worktrees `agent-1` on `feature/a`
--- and `agent-2` on `feature/b`, starts the module's home on it following
--- `SESSION_A`, and waits until the commits window lists them.
---
---@param name string
---@param state string
---@return string top
local function start_with_two_worktrees(name, state)
  local top = start_on_repository(name, state)
  add_worktree(top, 'agent-1', 'feature/a')
  add_worktree(top, 'agent-2', 'feature/b')
  child.lua('_G.homes.module.refresh_shown_pane()')
  wait_for_lines(7)
  return top
end

--- The top level of the worktree `folder` beside the repository at `top`.
---
---@param top string
---@param folder string
---@return string
local function worktree_at(top, folder)
  return vim.fs.joinpath(vim.fs.dirname(top), folder)
end

T['a restart']['shows the branch picked with s alone again'] = function()
  local state = fixture.directory('keep-view-branch-state')
  local top = start_on_repository('keep-view-branch', state)
  add_worktree(top, 'agent-1', 'feature/a')
  add_branch(top, 'feature/p', 'Work p')
  child.lua('_G.homes.module.refresh_shown_pane()')
  wait_for_lines(5)
  pick('module', 2)
  eq(last_offered().prompt, PROMPT)
  local alone = { 'Branch feature/p', last_commit_line(top, 'feature/p', 'Work p') }
  expect_pane_lines('module', 'commits', alone)

  restart_on(top, SESSION_A, state)

  expect_pane_lines('module', 'commits', alone)
  expect_files_heading('module', 'Files in: Branch feature/p')
  eq(messages(), {})
end

T['a restart']['shows the reported set again, each member under its heading, and tells nothing'] = function()
  local state = fixture.directory('keep-view-reported-state')
  local top = start_on_repository('keep-view-reported', state)
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  add_branch(top, 'feature/p', 'Work p')
  report('module', { kind = 'worktree', path = agent })
  report('module', { kind = 'branch', branch = 'feature/p' })
  local reported = vim.list_extend(
    bare_worktree('agent-1', 'feature/a'),
    { 'Branch feature/p', last_commit_line(top, 'feature/p', 'Work p') }
  )
  expect_pane_lines('module', 'commits', reported)

  restart_on(top, SESSION_A, state)

  expect_pane_lines('module', 'commits', reported)
  eq(messages(), {})
  eq(child.lua_get('#_G.timers'), 0)
end

T['a restart']['shows each report again with its base, label and age, its work read from that base'] = function()
  local state = fixture.directory('keep-view-report-base-state')
  local top = start_on_repository('keep-view-report-base', state)
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local one = commit_only(agent, 'one.txt', 'one', 'One')
  local two = commit_only(agent, 'two.txt', 'two', 'Two')
  report('module', { kind = 'worktree', path = agent, base = one, label = 'task' })
  local from_one = { 'Worktree agent-1 (feature/a)', commit_line(two, 'Two') }
  expect_pane_lines('module', 'commits', from_one)

  restart_on(top, SESSION_A, state)
  expect_pane_lines('module', 'commits', from_one)
  toggle_in_pane('module')

  expect_pane_lines('module', 'commits', {
    'Reported',
    ('worktree feature/a from %s task now'):format(one:sub(1, 7)),
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent-1 (feature/a)',
    commit_line(two, 'Two'),
  })
end

--- How long a case watches a pane that should not change, in
--- milliseconds: far longer than a read of the other worktrees takes.
local KEPT_STILL_MS = 3000

T['a restart']['keeps the branch each report was on, so a hook’s report on it changes nothing'] = function()
  local state = fixture.directory('keep-view-report-branch-state')
  local top = start_on_repository('keep-view-report-branch', state)
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local one = commit_only(agent, 'one.txt', 'one', 'One')
  report('module', { kind = 'worktree', path = agent, base = one, label = 'task' })
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  restart_on(top, SESSION_A, state)
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))

  report('module', { kind = 'worktree', path = agent, base = base, by_hook = true })
  wait_until('the hook’s report matched', function()
    return child.lua_get('#_G.timers == 1 and _G.timers[1].stopped')
  end)

  local still_from_one = bare_worktree('agent-1', 'feature/a')
  vim.wait(KEPT_STILL_MS, function()
    return not vim.deep_equal(pane_lines('module', 'commits'), still_from_one)
  end, 20)
  eq(pane_lines('module', 'commits'), still_from_one)
end

T['a restart']['keeps the worktree picked behind the reported set, shown alone once the set is gone'] = function()
  local state = fixture.directory('keep-view-behind-state')
  local top = start_with_two_worktrees('keep-view-behind', state)
  pick('module', 2)
  report('module', { kind = 'worktree', path = worktree_at(top, 'agent-1') })
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))

  restart_on(top, SESSION_A, state)
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  git_repo.git(top, { 'worktree', 'remove', worktree_at(top, 'agent-1') })
  expect_pane_lines('module', 'commits', default_view_with(bare_worktree('agent-2', 'feature/b')))
  toggle_in_pane('module')

  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
end

T['a restart']['shows the default view when it was shown, the focused view back at \\g'] = function()
  local state = fixture.directory('keep-view-toggled-state')
  local top = start_with_two_worktrees('keep-view-toggled', state)
  pick('module', 2)
  toggle_in_pane('module')
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)

  restart_on(top, SESSION_A, state)

  wait_for_restore()
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)
  eq(messages(), {})
  toggle_in_pane('module')
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
end

T['a restart']['keeps what changes after the view was restored'] = function()
  local state = fixture.directory('keep-view-again-state')
  local top = start_with_two_worktrees('keep-view-again', state)
  pick('module', 2)
  restart_on(top, SESSION_A, state)
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
  toggle_in_pane('module')
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)

  restart_on(top, SESSION_A, state)

  wait_for_restore()
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)
end

T['the record'] = MiniTest.new_set()

T['the record']['is written when the view changes, whole, before the editor quits'] = function()
  local state = fixture.directory('keep-view-written-state')
  start_with_two_worktrees('keep-view-written', state)
  eq(vim.uv.fs_stat(view_file(state, SESSION_A)), nil)

  pick('module', 1)

  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  eq(vim.uv.fs_stat(view_file(state, SESSION_A)) ~= nil, true)
  eq(vim.fn.glob(vim.fs.joinpath(state, 'aineo', 'changes-sessions', '*.cut')), '')
end

T['the record']['is not written while the view never changes'] = function()
  local state = fixture.directory('keep-view-idle-state')
  start_with_two_worktrees('keep-view-idle', state)
  child.lua('_G.homes.module.refresh_shown_pane()')
  wait_for_lines(7)

  eq(vim.uv.fs_stat(view_file(state, SESSION_A)), nil)
end

T['the record']['of another repository is ignored, and written over once the view changes'] = function()
  local state = fixture.directory('keep-view-elsewhere-state')
  local top = start_with_two_worktrees('keep-view-elsewhere', state)
  write_view_file(
    state,
    SESSION_A,
    vim.json.encode({
      repository = top .. '-elsewhere',
      focused = true,
      shows_reported = false,
      reported = {},
      scope = { top = worktree_at(top, 'agent-1') },
    })
  )

  restart_editor()
  child.lua(COUNT_BRANCH_LISTINGS)
  start_copy('module', top)
  follow('module', SESSION_A, state)
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)
  eq(child.lua_get('_G.branch_listings'), 0)
  pick('module', 2)
  restart_on(top, SESSION_A, state)

  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
end

T['the record']['that cannot be written is told once, and the pane goes on'] = function()
  local state = fixture.directory('keep-view-blocked-state')
  start_with_two_worktrees('keep-view-blocked', state)
  vim.fn.mkdir(view_file(state, SESSION_A), 'p')

  pick('module', 1)
  toggle_in_pane('module')
  toggle_in_pane('module')

  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  local told = messages()
  eq(#told, 1)
  eq(told[1]:find("aineo: the changes pane cannot keep this session's view", 1, true), 1)
end

--- Records that are no view, each otherwise the view of the worktree
--- `agent-2` shown alone: `{ what is wrong with it, its text }`, where
--- `<repository>` stands for the top level of the repository and
--- `<worktree>` for the top level of `agent-2`.
local MALFORMED_RECORDS = {
  { 'not JSON', 'this is not json' },
  { 'empty', '' },
  { 'a list', '[]' },
  { 'JSON null', 'null' },
  {
    'no repository',
    '{"focused":true,"shows_reported":false,"reported":[],"scope":{"top":"<worktree>"}}',
  },
  {
    'no reported set',
    '{"repository":"<repository>","focused":true,"shows_reported":false,"scope":{"top":"<worktree>"}}',
  },
  {
    'a focused flag that is no boolean',
    '{"repository":"<repository>","focused":"yes","shows_reported":false,"reported":[],"scope":{"top":"<worktree>"}}',
  },
  {
    'a reported flag that is no boolean',
    '{"repository":"<repository>","focused":true,"shows_reported":"no","reported":[{"top":"<worktree>"}]}',
  },
  {
    'a reported set that is no list',
    '{"repository":"<repository>","focused":true,"shows_reported":false,"reported":{"top":"<worktree>"},"scope":{"top":"<worktree>"}}',
  },
  {
    'a pick of both a worktree and a branch',
    '{"repository":"<repository>","focused":true,"shows_reported":false,"reported":[],"scope":{"top":"<worktree>","branch":"feature/b"}}',
  },
  {
    'a member that is no table',
    '{"repository":"<repository>","focused":true,"shows_reported":false,"reported":[7],"scope":{"top":"<worktree>"}}',
  },
  {
    'a pick of a worktree with an empty name',
    '{"repository":"<repository>","focused":true,"shows_reported":false,"reported":[],"scope":{"top":""}}',
  },
  {
    'a member of a branch with an empty name',
    '{"repository":"<repository>","focused":true,"shows_reported":true,"reported":[{"branch":""}],"scope":{"top":"<worktree>"}}',
  },
  {
    'a member of a kind no report names',
    '{"repository":"<repository>","focused":true,"shows_reported":true,"reported":[{"top":"<worktree>","kind":"tree"}]}',
  },
  {
    'a member whose base is no commit id',
    '{"repository":"<repository>","focused":true,"shows_reported":true,"reported":[{"top":"<worktree>","base":"HEAD"}]}',
  },
  {
    'a member with an empty label',
    '{"repository":"<repository>","focused":true,"shows_reported":true,"reported":[{"top":"<worktree>","label":""}]}',
  },
  {
    'a member whose time is no whole number',
    '{"repository":"<repository>","focused":true,"shows_reported":true,"reported":[{"top":"<worktree>","at":1.5}]}',
  },
  {
    'a member on a branch with an empty name',
    '{"repository":"<repository>","focused":true,"shows_reported":true,"reported":[{"top":"<worktree>","on_branch":""}]}',
  },
  {
    'a member whose hook flag is no boolean',
    '{"repository":"<repository>","focused":true,"shows_reported":true,"reported":[{"top":"<worktree>","by_hook":"yes"}]}',
  },
}

T['a malformed record'] = MiniTest.new_set({ parametrize = MALFORMED_RECORDS })

T['a malformed record']['is ignored, and the pane starts as without one'] = function(_, text)
  local state = fixture.directory('keep-view-malformed-state')
  local top = git_repo.create('keep-view-malformed', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent-1', 'feature/a')
  local agent_2 = add_worktree(top, 'agent-2', 'feature/b')
  write_view_file(state, SESSION_A, (text:gsub('<repository>', top):gsub('<worktree>', agent_2)))

  child.lua(COUNT_BRANCH_LISTINGS)
  start_copy('module', top)
  follow('module', SESSION_A, state)

  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)
  eq(messages(), {})
  eq(child.lua_get('_G.branch_listings'), 0)
  eq(child.cmd_capture('messages'):find('Error', 1, true), nil)
end

T['a malformed record']['of the same shape with a valid pick restores it'] = function()
  local state = fixture.directory('keep-view-wellformed-state')
  local top = git_repo.create('keep-view-wellformed', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent-1', 'feature/a')
  local agent_2 = add_worktree(top, 'agent-2', 'feature/b')
  write_view_file(
    state,
    SESSION_A,
    vim.json.encode({
      repository = top,
      focused = true,
      shows_reported = false,
      reported = {},
      scope = { top = agent_2 },
    })
  )

  start_copy('module', top)
  follow('module', SESSION_A, state)

  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
end

T['a view that is gone'] = MiniTest.new_set()

T['a view that is gone']['drops a worktree removed since, untold, and shows the default view'] = function()
  local state = fixture.directory('keep-view-gone-worktree-state')
  local top = start_with_two_worktrees('keep-view-gone-worktree', state)
  pick('module', 2)
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
  child.stop()
  git_repo.git(top, { 'worktree', 'remove', worktree_at(top, 'agent-2') })

  restart_on(top, SESSION_A, state)

  expect_pane_lines('module', 'commits', default_view_with(bare_worktree('agent-1', 'feature/a')))
  expect_record_without(state, 'agent-2')
  eq(messages(), {})
end

T['a view that is gone']['drops a branch deleted since, untold, and shows the default view'] = function()
  local state = fixture.directory('keep-view-gone-branch-state')
  local top = start_on_repository('keep-view-gone-branch', state)
  add_worktree(top, 'agent-1', 'feature/a')
  add_branch(top, 'feature/p', 'Work p')
  child.lua('_G.homes.module.refresh_shown_pane()')
  wait_for_lines(5)
  pick('module', 2)
  expect_pane_lines(
    'module',
    'commits',
    { 'Branch feature/p', last_commit_line(top, 'feature/p', 'Work p') }
  )
  child.stop()
  git_repo.git(top, { 'branch', '-D', 'feature/p' })

  restart_on(top, SESSION_A, state)

  expect_pane_lines('module', 'commits', default_view_with(bare_worktree('agent-1', 'feature/a')))
  expect_record_without(state, 'feature/p')
  eq(messages(), {})
end

T['a view that is gone']['drops the members of the reported set that are gone, untold, and keeps the others'] = function()
  local state = fixture.directory('keep-view-gone-member-state')
  local top = start_on_repository('keep-view-gone-member', state)
  local first = add_worktree(top, 'agent-1', 'feature/a')
  add_branch(top, 'feature/p', 'Work p')
  report('module', { kind = 'worktree', path = first })
  report('module', { kind = 'branch', branch = 'feature/p' })
  wait_for_lines(4)
  child.stop()
  git_repo.git(top, { 'worktree', 'remove', first })

  restart_on(top, SESSION_A, state)

  expect_pane_lines(
    'module',
    'commits',
    { 'Branch feature/p', last_commit_line(top, 'feature/p', 'Work p') }
  )
  expect_record_without(state, 'agent-1')
  eq(messages(), {})
end

T['a view that is gone']['shows the default view, untold, when the whole reported set is gone'] = function()
  local state = fixture.directory('keep-view-gone-set-state')
  local top = start_on_repository('keep-view-gone-set', state)
  local first = add_worktree(top, 'agent-1', 'feature/a')
  report('module', { kind = 'worktree', path = first })
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  child.stop()
  git_repo.git(top, { 'worktree', 'remove', first })

  restart_on(top, SESSION_A, state)

  expect_pane_lines('module', 'commits', DEFAULT_VIEW)
  expect_record_without(state, 'agent-1')
  eq(messages(), {})
end

T['a view that is gone']['keeps the reported set when the worktree picked behind it is gone'] = function()
  local state = fixture.directory('keep-view-gone-behind-state')
  local top = start_with_two_worktrees('keep-view-gone-behind', state)
  pick('module', 2)
  report('module', { kind = 'worktree', path = worktree_at(top, 'agent-1') })
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  child.stop()
  git_repo.git(top, { 'worktree', 'remove', worktree_at(top, 'agent-2') })

  restart_on(top, SESSION_A, state)

  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  expect_record_without(state, 'agent-2')
  eq(messages(), {})
end

T['two sessions'] = MiniTest.new_set()

T['two sessions']['in two tabs keep two views, each shown again by its own tab'] = function()
  local state = fixture.directory('keep-view-two-tabs-state')
  local top = start_with_two_worktrees('keep-view-two-tabs', state)
  start_copy('other', top)
  follow('other', SESSION_B, state)
  expect_pane_lines('other', 'commits', DEFAULT_VIEW_WITH_BOTH)
  pick('module', 1)
  pick('other', 2)
  expect_pane_lines('other', 'commits', bare_worktree('agent-2', 'feature/b'))
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))

  restart_editor()
  start_copy('module', top)
  start_copy('other', top)
  follow('module', SESSION_A, state)
  follow('other', SESSION_B, state)

  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  expect_pane_lines('other', 'commits', bare_worktree('agent-2', 'feature/b'))
end

T['two sessions']['start with the default view when the session has no view kept'] = function()
  local state = fixture.directory('keep-view-new-session-state')
  local top = start_with_two_worktrees('keep-view-new-session', state)
  pick('module', 1)
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))

  restart_editor()
  child.lua(COUNT_BRANCH_LISTINGS)
  start_copy('module', top)
  follow('module', SESSION_B, state)

  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)
  eq(child.lua_get('_G.branch_listings'), 0)
  eq(vim.uv.fs_stat(view_file(state, SESSION_B)), nil)
end

T['two sessions']['are told apart by a pane that follows another session than before'] = function()
  local state = fixture.directory('keep-view-follow-state')
  start_with_two_worktrees('keep-view-follow', state)
  pick('module', 1)
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))

  follow('module', SESSION_B, state)
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)
  pick('module', 2)
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
  follow('module', SESSION_A, state)

  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  follow('module', SESSION_B, state)
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
  eq(messages(), {})
end

T['a view that is gone']['shows the default view, untold, when the reported set is gone, and the pick behind it at \\g'] = function()
  local state = fixture.directory('keep-view-gone-set-behind-state')
  local top = start_with_two_worktrees('keep-view-gone-set-behind', state)
  pick('module', 2)
  report('module', { kind = 'worktree', path = worktree_at(top, 'agent-1') })
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  child.stop()
  git_repo.git(top, { 'worktree', 'remove', worktree_at(top, 'agent-1') })

  restart_on(top, SESSION_A, state)

  expect_pane_lines('module', 'commits', default_view_with(bare_worktree('agent-2', 'feature/b')))
  expect_record_without(state, 'agent-1')
  eq(messages(), {})
  toggle_in_pane('module')
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
end

T['a view that is gone']['stays kept, the pane starting as without it, when git cannot list the branches'] = function()
  local state = fixture.directory('keep-view-unlisted-state')
  local top = start_with_two_worktrees('keep-view-unlisted', state)
  pick('module', 2)
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
  local kept = vim.fn.readfile(view_file(state, SESSION_A))
  restart_editor()
  child.lua([[
    require('aineo.git').list_branches = function(_, done)
      done({ reason = 'failed', message = 'no branches' })
      _G.listing_answered = true
    end
  ]])

  start_copy('module', top)
  follow('module', SESSION_A, state)

  wait_until('the listing answered', function()
    return child.lua_get('_G.listing_answered') == true
  end)
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)
  eq(messages(), {})
  eq(vim.fn.readfile(view_file(state, SESSION_A)), kept)
end

--- The Lua that makes the git home's first listing of the local branches
--- wait until `_G.release_listing()`, then answer as it would; later ones
--- answer at once.
local HOLD_BRANCH_LISTING = [[
  local git = require('aineo.git')
  local list_branches = git.list_branches
  local held = false
  git.list_branches = function(found, done, options)
    if held then
      return list_branches(found, done, options)
    end
    held = true
    _G.release_listing = function()
      list_branches(found, done, options)
    end
  end
]]

T['a restart']['leaves the view kept untouched while the worktrees and branches are read'] = function()
  local state = fixture.directory('keep-view-held-state')
  local top = start_with_two_worktrees('keep-view-held', state)
  pick('module', 2)
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
  local kept = vim.fn.readfile(view_file(state, SESSION_A))
  restart_editor()
  child.lua(HOLD_BRANCH_LISTING)

  start_copy('module', top)
  follow('module', SESSION_A, state)
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)
  child.lua('_G.homes.module.refresh_shown_pane()')
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)

  eq(vim.fn.readfile(view_file(state, SESSION_A)), kept)
  child.lua('_G.release_listing()')
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
end

T['a restart']['reads the branch of the reported set it shows after the pane read its own lists'] = function()
  local state = fixture.directory('keep-view-late-state')
  local top = start_on_repository('keep-view-late', state)
  add_branch(top, 'feature/p', 'Work p')
  report('module', { kind = 'branch', branch = 'feature/p' })
  local reported = { 'Branch feature/p', last_commit_line(top, 'feature/p', 'Work p') }
  expect_pane_lines('module', 'commits', reported)
  restart_editor()
  child.lua(HOLD_BRANCH_LISTING)

  start_copy('module', top)
  follow('module', SESSION_A, state)
  expect_pane_lines('module', 'commits', DEFAULT_VIEW)
  child.lua('_G.release_listing()')

  expect_pane_lines('module', 'commits', reported)
end

T['a restart']['gives way to a pick made while the view kept is read back'] = function()
  local state = fixture.directory('keep-view-racing-state')
  local top = start_with_two_worktrees('keep-view-racing', state)
  pick('module', 2)
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
  restart_editor()
  child.lua(HOLD_BRANCH_LISTING)
  start_copy('module', top)
  follow('module', SESSION_A, state)
  expect_pane_lines('module', 'commits', DEFAULT_VIEW)
  child.lua('_G.homes.module.refresh_shown_pane()')
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)
  pick('module', 1)
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))

  child.lua('_G.release_listing()')
  wait_until('the pick kept', function()
    return table.concat(vim.fn.readfile(view_file(state, SESSION_A))):find('agent-1', 1, true)
      ~= nil
  end)
  restart_on(top, SESSION_A, state)

  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
end

T['a restart']['gives way to a reported set made before the session was followed, though nothing shows it'] = function()
  local state = fixture.directory('keep-view-early-set-state')
  local top = start_on_repository('keep-view-early-set', state)
  add_worktree(top, 'agent-1', 'feature/a')
  add_worktree(top, 'agent-2', 'feature/b')
  add_worktree(top, 'agent-3', 'feature/c')
  child.lua('_G.homes.module.refresh_shown_pane()')
  wait_for_lines(9)
  pick('module', 3)
  expect_pane_lines('module', 'commits', bare_worktree('agent-3', 'feature/c'))
  restart_editor()
  child.lua(COUNT_BRANCH_LISTINGS)
  start_copy('module', top)
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_THREE)
  report('module', { kind = 'worktree', path = worktree_at(top, 'agent-1') })
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  pick('module', 4)
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
  git_repo.git(top, { 'worktree', 'remove', worktree_at(top, 'agent-2') })
  local reported_default_view = vim.list_extend(
    { 'Reported', 'worktree feature/a from ? now' },
    default_view_with(bare_worktree('agent-1', 'feature/a'), bare_worktree('agent-3', 'feature/c'))
  )
  expect_pane_lines('module', 'commits', reported_default_view)

  local listings_before = child.lua_get('_G.branch_listings')
  follow('module', SESSION_A, state)

  eq(child.lua_get('_G.branch_listings'), listings_before)
  expect_pane_lines('module', 'commits', reported_default_view)
end

T['a restart']['drops, untold, a pick of the editor’s own worktree a record holds'] = function()
  local state = fixture.directory('keep-view-own-pick-state')
  local top = git_repo.create('keep-view-own-pick', { ['notes.txt'] = { 'one' } })
  add_worktree(top, 'agent-1', 'feature/a')
  add_worktree(top, 'agent-2', 'feature/b')
  write_view_file(
    state,
    SESSION_A,
    vim.json.encode({
      repository = top,
      focused = true,
      shows_reported = false,
      reported = {},
      scope = { top = top },
    })
  )
  child.lua(COUNT_BRANCH_LISTINGS)
  start_copy('module', top)

  follow('module', SESSION_A, state)
  wait_for_restore()

  expect_record_without(state, '"scope"')
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)
  eq(messages(), {})
end

T['a restart']['gives way to a pick made before the session was followed'] = function()
  local state = fixture.directory('keep-view-early-state')
  local top = start_with_two_worktrees('keep-view-early', state)
  pick('module', 2)
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
  restart_editor()
  start_copy('module', top)
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)
  pick('module', 1)
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))

  follow('module', SESSION_A, state)
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  restart_on(top, SESSION_A, state)

  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
end

T['the record']['is replaced whole: a write that fails leaves the view as it was'] = function()
  local state = fixture.directory('keep-view-whole-state')
  local top = start_with_two_worktrees('keep-view-whole', state)
  pick('module', 1)
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  local editor_pid = child.lua_get('vim.uv.os_getpid()')
  vim.fn.mkdir(('%s.%d.cut'):format(view_file(state, SESSION_A), editor_pid), 'p')

  pick('module', 2)

  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
  eq(#messages(), 1)
  restart_on(top, SESSION_A, state)
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
end

T['two sessions']['followed while the view of another is read back never shows it'] = function()
  local state = fixture.directory('keep-view-other-restore-state')
  local top = start_with_two_worktrees('keep-view-other-restore', state)
  pick('module', 2)
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
  restart_editor()
  child.lua(COUNT_BRANCH_LISTINGS)
  start_copy('module', top)
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)

  child.lua(
    [[
    local home = _G.homes.module
    home.follow_changes_session({ id = select(1, ...), state_directory = select(3, ...) })
    home.follow_changes_session({ id = select(2, ...), state_directory = select(3, ...) })
  ]],
    { SESSION_A, SESSION_B, state }
  )
  wait_for_restore()

  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)
  eq(vim.uv.fs_stat(view_file(state, SESSION_B)), nil)
end

T['two sessions']['followed while the view of another is read back keep their own'] = function()
  local state = fixture.directory('keep-view-quick-state')
  local top = start_with_two_worktrees('keep-view-quick', state)
  pick('module', 2)
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
  restart_editor()
  start_copy('module', top)
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_BOTH)

  child.lua(
    [[
    local home = _G.homes.module
    home.follow_changes_session({ id = select(1, ...), state_directory = select(3, ...) })
    home.follow_changes_session({ id = select(2, ...), state_directory = select(3, ...) })
  ]],
    { SESSION_A, SESSION_B, state }
  )
  pick('module', 1)
  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
  restart_on(top, SESSION_B, state)

  expect_pane_lines('module', 'commits', bare_worktree('agent-1', 'feature/a'))
end

T['a hand-over'] = MiniTest.new_set()

T['a hand-over']['moves the view to the session that takes over'] = function()
  local state = fixture.directory('keep-view-hand-over-state')
  local top = start_with_two_worktrees('keep-view-hand-over', state)
  pick('module', 2)
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))

  child.lua(
    '_G.homes.module.hand_over_changes_session({ from = select(1, ...), to = select(2, ...), state_directory = select(3, ...) })',
    { SESSION_A, SESSION_B, state }
  )

  eq(vim.uv.fs_stat(view_file(state, SESSION_A)), nil)
  eq(vim.uv.fs_stat(view_file(state, SESSION_B)) ~= nil, true)
  restart_on(top, SESSION_B, state)
  expect_pane_lines('module', 'commits', bare_worktree('agent-2', 'feature/b'))
end

return T
