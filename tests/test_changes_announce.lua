local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- What `s` asks the picker for.
local PROMPT = 'Show alone in the changes pane'

--- The Lua that defines, in the child, `_G.start_copy(key, directory,
--- working_branch)`: it makes the changes home `key` names — the module's
--- own for `'module'`, a copy of its own (`new()`) for any other — in
--- `_G.homes[key]`, begins its session for `directory`, with the working
--- branch `working_branch` when given and a stand-in timer that keeps each timer it is
--- asked for in `_G.timers` (`{ milliseconds, act, stopped }`), to be run by
--- `_G.fire(index)`, and shows its two buffers in a tab page of its own: the
--- files buffer in the tab's window, the commits buffer in a window below it.
--- `_G.report(key, work)` hands the home a report, with a teller that keeps
--- each message in `_G.told`, by the home's key. `vim.ui.select` is replaced
--- by a picker that keeps every request in `_G.pickers`, answered by
--- `_G.choose()`, and `vim.notify` by one that keeps every message in
--- `_G.messages`.
local COPIES = [[
  _G.homes, _G.panes, _G.pickers, _G.messages, _G.timers, _G.told = {}, {}, {}, {}, {}, {}
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
  _G.fire = function(index)
    _G.timers[index].act()
  end
  _G.report = function(key, work)
    _G.told[key] = _G.told[key] or {}
    return _G.homes[key].add_reported_work(work, function(message)
      table.insert(_G.told[key], message)
    end)
  end
  _G.start_copy = function(key, directory, working_branch)
    local changes = require('aineo.changes')
    local home = key == 'module' and changes or changes.new()
    _G.homes[key] = home
    home.begin_session({
      directory = directory,
      working_branch = working_branch,
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
--- `directory`, its pane shown, with the working branch `working_branch`
--- when given.
---
---@param key string
---@param directory string
---@param working_branch? string
local function start_copy(key, directory, working_branch)
  child.lua('_G.start_copy(...)', { key, directory, working_branch })
end

--- Hands the changes home `key` names the report `work`.
---
---@param key string
---@param work table
local function report(key, work)
  child.lua('_G.report(...)', { key, work })
end

--- What the changes home `key` names told through the teller its reports
--- were given.
---
---@param key string
---@return string[]
local function told(key)
  return child.lua_get('_G.told[...] or {}', { key })
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

--- The default view of a repository with no commit of the session's own and
--- the worktree `agent-1` on `feature/a`, of no commit, listed.
local DEFAULT_VIEW_WITH_AGENT = vim.list_extend(
  vim.list_slice(DEFAULT_VIEW),
  { 'Worktree agent-1 (feature/a)', 'No commits in this worktree' }
)

--- The view of the reported worktree `agent-1` on `feature/a`, of no commit.
local AGENT_VIEW = { 'Worktree agent-1 (feature/a)', 'No commits in this worktree' }

--- The Reported section atop the default view once the worktree `agent-1`
--- on `feature/a` was reported, with no base, a moment ago.
local REPORTED_AGENT = { 'Reported', 'worktree feature/a from ? now' }

--- `rows`, the default view's rows below the Reported section, under
--- `REPORTED_AGENT`.
---
---@param rows string[]
---@return string[]
local function under_reported_agent(rows)
  return vim.list_extend(vim.list_slice(REPORTED_AGENT), rows)
end

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

--- Makes the repository `name` with one commit, starts the module's home on
--- it, waits for its default view, and returns its top level.
---
---@param name string
---@return string top
local function start_on_repository(name)
  local top = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  start_copy('module', top)
  expect_pane_lines('module', 'commits', DEFAULT_VIEW)
  return top
end

--- The words that tell the user Claude Code started work in `heading`.
---
---@param heading string
---@return string
local function started_in(heading)
  return ('aineo: Claude Code started work in %s; the changes pane shows the reported work'):format(
    heading
  )
end

T['a reported worktree'] = MiniTest.new_set()

T['a reported worktree']['shows under its heading with its commits, nothing else, and is told once'] = function()
  local top = start_on_repository('announce-worktree')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local work_a = commit_only(agent, 'a.txt', 'a', 'Work a')

  report('module', { kind = 'worktree', path = agent })

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    commit_line(work_a, 'Work a'),
  })
  eq(told('module'), { started_in('Worktree agent-1 (feature/a)') })
end

T['a reported worktree']['is matched by its real path when reported through a symbolic link'] = function()
  local top = start_on_repository('announce-link')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local link = vim.fs.joinpath(fixture.directory('announce-link-links'), 'to-agent')
  assert(vim.uv.fs_symlink(agent, link))

  report('module', { kind = 'worktree', path = link })

  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-1 (feature/a)', 'No commits in this worktree' }
  )
end

T['a reported worktree']['has its path resolved off the main loop, the reports kept in their order'] = function()
  local top = start_on_repository('announce-async-realpath')
  local links = fixture.directory('announce-async-realpath-links')
  local slow = vim.fs.joinpath(links, 'slow')
  local fast = vim.fs.joinpath(links, 'fast')
  assert(vim.uv.fs_symlink(add_worktree(top, 'agent-1', 'feature/a'), slow))
  assert(vim.uv.fs_symlink(add_worktree(top, 'agent-2', 'feature/b'), fast))
  child.lua(
    [[
      local slow, fast = ...
      local realpath = vim.uv.fs_realpath
      vim.uv.fs_realpath = function(path, callback)
        local reported = path == slow or path == fast
        if not callback then
          if reported then
            return nil, 'resolved on the main loop'
          end
          return realpath(path)
        end
        vim.defer_fn(function()
          local real_path, failure = realpath(path)
          callback(failure, real_path)
        end, path == slow and 300 or 0)
      end
    ]],
    { slow, fast }
  )

  report('module', { kind = 'worktree', path = slow })
  report('module', { kind = 'worktree', path = fast })

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
    'Worktree agent-2 (feature/b)',
    'No commits in this worktree',
  })
  eq(told('module'), {
    started_in('Worktree agent-1 (feature/a)'),
    started_in('Worktree agent-2 (feature/b)'),
  })
end

T['a reported branch'] = MiniTest.new_set()

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

T['a reported branch']['shows under its heading with its commits, and is told once'] = function()
  local top = start_on_repository('announce-branch')
  local work_b = add_branch(top, 'feature/b', 'Work b')

  report('module', { kind = 'branch', branch = 'feature/b' })

  expect_pane_lines('module', 'commits', { 'Branch feature/b', commit_line(work_b, 'Work b') })
  eq(told('module'), { started_in('Branch feature/b') })
end

T['a reported branch']['chooses its whole change, which the files window lists from its base to its tip'] = function()
  local top = start_on_repository('announce-branch-files')
  add_branch(top, 'feature/b', 'Work b')

  report('module', { kind = 'branch', branch = 'feature/b' })

  expect_pane_lines('module', 'files', { 'Files in: Branch feature/b', '  A branch.txt' })
end

T['a reported branch']['shows a file’s diff from its base by Enter under its whole change'] = function()
  local top = start_on_repository('announce-branch-diff')
  add_branch(top, 'feature/b', 'Work b')
  report('module', { kind = 'branch', branch = 'feature/b' })
  expect_pane_lines('module', 'files', { 'Files in: Branch feature/b', '  A branch.txt' })

  enter_window_of('module', 'files')
  child.lua('vim.api.nvim_win_set_cursor(0, { 2, 0 })')
  child.lua([[pcall(vim.api.nvim_feedkeys, vim.keycode('<CR>'), 'mx', false)]])

  wait_until('the diff shown', function()
    return child.lua_get([[vim.fn.bufexists('aineo://branch/feature/b//diff/branch.txt') == 1]])
  end)
end

T['a reported branch']['checked out in another worktree is added as that worktree'] = function()
  local top = start_on_repository('announce-branch-checked-out')
  add_worktree(top, 'agent-2', 'feature/c')

  report('module', { kind = 'branch', branch = 'feature/c' })

  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-2 (feature/c)', 'No commits in this worktree' }
  )
  eq(told('module'), { started_in('Worktree agent-2 (feature/c)') })
end

T['a report git does not list yet'] = MiniTest.new_set()

T['a report git does not list yet']['is added once a read lists it, a worktree added just after the call'] = function()
  local top = start_on_repository('announce-late')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local late = vim.fs.joinpath(vim.fs.dirname(top), 'agent-late')
  report('module', { kind = 'worktree', path = late })
  report('module', { kind = 'worktree', path = agent })
  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-1 (feature/a)', 'No commits in this worktree' }
  )

  add_worktree(top, 'agent-late', 'feature/late')

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
    'Worktree agent-late (feature/late)',
    'No commits in this worktree',
  })
  eq(told('module'), {
    started_in('Worktree agent-1 (feature/a)'),
    started_in('Worktree agent-late (feature/late)'),
  })
end

--- The timers the child's home was asked for: how long each was, and
--- whether it was stopped.
---
---@return { milliseconds: integer, stopped: boolean }[]
local function timers()
  return child.lua_get([[vim.tbl_map(function(timer)
    return { milliseconds = timer.milliseconds, stopped = timer.stopped }
  end, _G.timers)]])
end

T['a report git does not list yet']['waits 60 s from the call, then is let go and told once, several at once'] = function()
  local top = start_on_repository('announce-unlisted')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local missing = vim.fs.joinpath(vim.fs.dirname(top), 'never-made')
  report('module', { kind = 'worktree', path = missing })
  report('module', { kind = 'branch', branch = 'feature/never' })
  report('module', { kind = 'worktree', path = agent })
  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-1 (feature/a)', 'No commits in this worktree' }
  )

  child.lua('_G.fire(1); _G.fire(2); _G.fire(1)')

  eq(timers(), {
    { milliseconds = 60000, stopped = false },
    { milliseconds = 60000, stopped = false },
    { milliseconds = 60000, stopped = true },
  })
  eq(told('module'), {
    started_in('Worktree agent-1 (feature/a)'),
    ('aineo: Claude Code announced worktree %s, which git does not list; the changes pane is unchanged'):format(
      missing
    ),
    'aineo: Claude Code announced branch feature/never, which git does not list; the changes pane is unchanged',
  })
end

T['a report git does not list yet']['made again while it waits is taken and changes nothing: one timer, told once'] = function()
  local top = start_on_repository('announce-again-waiting')
  local missing = vim.fs.joinpath(vim.fs.dirname(top), 'never-made')

  local taken = child.lua_get(
    [[{
    _G.report('module', { kind = 'worktree', path = ... }),
    _G.report('module', { kind = 'worktree', path = ... }),
  }]],
    { missing }
  )
  child.lua('_G.fire(1)')

  eq(taken, { true, true })
  eq(timers(), { { milliseconds = 60000, stopped = false } })
  eq(told('module'), {
    ('aineo: Claude Code announced worktree %s, which git does not list; the changes pane is unchanged'):format(
      missing
    ),
  })
end

T['a report git does not list yet']['waits, at most 32 at once; a 33rd is not taken, and nothing is told of it'] = function()
  local top = start_on_repository('announce-at-most-32')
  local directory = vim.fs.dirname(top)

  local taken = child.lua_get(
    [[(function(directory)
      local taken = {}
      for index = 1, 33 do
        taken[index] = _G.report('module', { kind = 'worktree', path = directory .. '/never-made-' .. index })
      end
      return taken
    end)(...)]],
    { directory }
  )

  eq(vim.list_slice(taken, 32), { true, false })
  eq(#timers(), 32)
  eq(told('module'), {})
end

T['a report git does not list yet']['holding words git or a shell would read is compared, never run'] = function()
  local top = start_on_repository('announce-hostile')
  local witness = vim.fs.joinpath(fixture.directory('announce-hostile-witness'), 'made')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', { kind = 'branch', branch = '--help' })
  report('module', { kind = 'branch', branch = ('$(touch %s)'):format(witness) })
  report('module', { kind = 'worktree', path = agent })
  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-1 (feature/a)', 'No commits in this worktree' }
  )

  child.lua('_G.fire(1); _G.fire(2)')

  eq(told('module'), {
    started_in('Worktree agent-1 (feature/a)'),
    'aineo: Claude Code announced branch --help, which git does not list; the changes pane is unchanged',
    ('aineo: Claude Code announced branch $(touch %s), which git does not list; the changes pane is unchanged'):format(
      witness
    ),
  })
  eq(vim.uv.fs_stat(witness), nil)
end

T['the reported set'] = MiniTest.new_set()

T['the reported set']['adds up in the order first reported, and one reported again changes nothing and tells nothing'] = function()
  local top = start_on_repository('announce-add-up')
  local first = add_worktree(top, 'agent-1', 'feature/a')
  local second = add_worktree(top, 'agent-2', 'feature/b')
  report('module', { kind = 'worktree', path = first })
  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-1 (feature/a)', 'No commits in this worktree' }
  )

  report('module', { kind = 'worktree', path = second })
  report('module', { kind = 'branch', branch = 'feature/a' })
  report('module', { kind = 'worktree', path = first })
  local third = add_worktree(top, 'agent-3', 'feature/c')
  report('module', { kind = 'worktree', path = third })

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
    'Worktree agent-2 (feature/b)',
    'No commits in this worktree',
    'Worktree agent-3 (feature/c)',
    'No commits in this worktree',
  })
  eq(told('module'), {
    started_in('Worktree agent-1 (feature/a)'),
    started_in('Worktree agent-2 (feature/b)'),
    started_in('Worktree agent-3 (feature/c)'),
  })
  eq(child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.bufwinid(_G.panes.module.commits))')[1], 5)
end

T['the reported set']['shows each member under its own heading, its commits below, and nothing else'] = function()
  local top = start_on_repository('announce-page')
  git_repo.write(top, 'notes.txt', { 'uncommitted' })
  commit_only(top, 'own.txt', 'own', 'Own')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local work_a = commit_only(agent, 'a.txt', 'a', 'Work a')
  local work_b = add_branch(top, 'feature/b', 'Work b')
  add_worktree(top, 'unreported', 'feature/u')
  report('module', { kind = 'worktree', path = agent })
  report('module', { kind = 'branch', branch = 'feature/b' })

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    commit_line(work_a, 'Work a'),
    'Branch feature/b',
    commit_line(work_b, 'Work b'),
  })
end

T['the reported set']['drops a member git no longer lists, telling nothing, and once empty shows the default view, told once'] = function()
  local top = start_on_repository('announce-drop')
  local first = add_worktree(top, 'agent-1', 'feature/a')
  local second = add_worktree(top, 'agent-2', 'feature/b')
  report('module', { kind = 'worktree', path = first })
  report('module', { kind = 'worktree', path = second })
  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
    'Worktree agent-2 (feature/b)',
    'No commits in this worktree',
  })

  git_repo.git(top, { 'worktree', 'remove', first })
  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-2 (feature/b)', 'No commits in this worktree' }
  )
  eq(messages(), {})

  git_repo.git(top, { 'worktree', 'remove', second })
  expect_pane_lines('module', 'commits', DEFAULT_VIEW)
  eq(messages(), { 'aineo: the reported work is gone; the changes pane shows the default view' })
  eq(#told('module'), 2)
end

--- Makes the changes home `key` names follow the Claude Code session `id`,
--- its base and saves kept under `state`.
---
---@param key string
---@param id string
---@param state string
local function follow(key, id, state)
  child.lua(
    '_G.homes[...].follow_changes_session({ id = select(2, ...), state_directory = select(3, ...) })',
    {
      key,
      id,
      state,
    }
  )
end

T['the reported set']['is emptied, and the reports still waiting dropped, when another session is followed'] = function()
  local top = start_on_repository('announce-other-session')
  local state = fixture.directory('announce-other-session-state')
  follow('module', '11111111-1111-4111-8111-111111111111', state)
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', { kind = 'worktree', path = vim.fs.joinpath(vim.fs.dirname(top), 'never-made') })
  report('module', { kind = 'worktree', path = agent })
  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-1 (feature/a)', 'No commits in this worktree' }
  )

  follow('module', '22222222-2222-4222-8222-222222222222', state)

  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_AGENT)
  enter_window_of('module', 'commits')
  child.lua('_G.homes.module.toggle_focused_view()')
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_AGENT)
  eq(
    vim.tbl_map(function(timer)
      return timer.stopped
    end, timers()),
    { true, true }
  )
  eq(messages(), {})
end

T['the reported set']['is each changes home’s own'] = function()
  local top = start_on_repository('announce-two-homes')
  start_copy('other', top)
  expect_pane_lines('other', 'commits', DEFAULT_VIEW)
  local agent = add_worktree(top, 'agent-1', 'feature/a')

  report('module', { kind = 'worktree', path = agent })
  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-1 (feature/a)', 'No commits in this worktree' }
  )
  child.lua('_G.homes.other.refresh_shown_pane()')

  expect_pane_lines('other', 'commits', DEFAULT_VIEW_WITH_AGENT)
end

T['the reported set']['lets the reports still waiting go untold when its home is let go'] = function()
  local top = start_on_repository('announce-let-go')
  start_copy('other', top)
  expect_pane_lines('other', 'commits', DEFAULT_VIEW)
  report('other', { kind = 'worktree', path = vim.fs.joinpath(vim.fs.dirname(top), 'never-made') })

  child.lua('_G.homes.other.let_go()')

  eq(timers(), { { milliseconds = 60000, stopped = true } })
end

T['the focused view'] = MiniTest.new_set()

--- Switches the view of the pane of the module's home as `\g` does with the
--- cursor in its commits window (`toggle_focused_view()`).
local function toggle_in_pane()
  enter_window_of('module', 'commits')
  child.lua('_G.homes.module.toggle_focused_view()')
end

T['the focused view']['of the reported set is switched with the default view by \\g in the pane'] = function()
  local top = start_on_repository('announce-toggle')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', { kind = 'worktree', path = agent })
  expect_pane_lines('module', 'commits', AGENT_VIEW)

  toggle_in_pane()
  expect_pane_lines('module', 'commits', under_reported_agent(DEFAULT_VIEW_WITH_AGENT))
  toggle_in_pane()

  expect_pane_lines('module', 'commits', AGENT_VIEW)
end

--- Presses `s` in the commits window of the module's home's pane and waits
--- until its picker opens, at most `git_repo.PATIENCE_MS`.
local function press_s()
  local before = child.lua_get('#_G.pickers')
  enter_window_of('module', 'commits')
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

T['the focused view']['becomes the reported set at a new report, from a worktree picked with s, its member chosen'] = function()
  local top = start_on_repository('announce-from-pick')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  add_worktree(top, 'agent-2', 'feature/b')
  child.lua('_G.homes.module.refresh_shown_pane()')
  expect_pane_lines(
    'module',
    'commits',
    vim.list_extend(vim.list_slice(DEFAULT_VIEW_WITH_AGENT), {
      'Worktree agent-2 (feature/b)',
      'No commits in this worktree',
    })
  )
  press_s()
  child.lua('_G.choose(2)')
  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-2 (feature/b)', 'No commits in this worktree' }
  )

  report('module', { kind = 'worktree', path = agent })

  expect_pane_lines('module', 'commits', AGENT_VIEW)
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Worktree agent-1 (feature/a)', 'No files changed in this worktree' }
  )
  eq(child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.bufwinid(_G.panes.module.commits))')[1], 1)
end

T['the focused view']['of the reported set stays, untold, when the worktree picked behind it is removed'] = function()
  local top = start_on_repository('announce-pick-gone')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local picked = add_worktree(top, 'agent-2', 'feature/b')
  child.lua('_G.homes.module.refresh_shown_pane()')
  expect_pane_lines(
    'module',
    'commits',
    vim.list_extend(vim.list_slice(DEFAULT_VIEW_WITH_AGENT), {
      'Worktree agent-2 (feature/b)',
      'No commits in this worktree',
    })
  )
  press_s()
  child.lua('_G.choose(2)')
  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-2 (feature/b)', 'No commits in this worktree' }
  )
  report('module', { kind = 'worktree', path = agent })
  expect_pane_lines('module', 'commits', AGENT_VIEW)

  git_repo.git(top, { 'worktree', 'remove', picked })
  local late = commit_only(agent, 'late.txt', 'late', 'Late a')
  local agent_view = { 'Worktree agent-1 (feature/a)', commit_line(late, 'Late a') }
  expect_pane_lines('module', 'commits', agent_view)
  eq(messages(), {})
  toggle_in_pane()
  expect_pane_lines(
    'module',
    'commits',
    under_reported_agent({
      'Uncommitted',
      'Session work',
      'No commits on this session',
      'Worktree agent-1 (feature/a)',
      commit_line(late, 'Late a'),
    })
  )
  toggle_in_pane()

  expect_pane_lines('module', 'commits', agent_view)
end

T['the focused view']['of the reported set stays, untold, when the branch picked behind it is deleted'] = function()
  local top = start_on_repository('announce-branch-pick-gone')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  add_branch(top, 'feature/p', 'Work p')
  child.lua('_G.homes.module.refresh_shown_pane()')
  expect_pane_lines('module', 'commits', DEFAULT_VIEW_WITH_AGENT)
  press_s()
  eq(last_offered().texts, { '[worktree] agent-1 (feature/a)', '[branch] feature/p' })
  child.lua('_G.choose(2)')
  expect_pane_lines(
    'module',
    'commits',
    { 'Branch feature/p', last_commit_line(top, 'feature/p', 'Work p') }
  )
  report('module', { kind = 'worktree', path = agent })
  expect_pane_lines('module', 'commits', AGENT_VIEW)

  git_repo.git(top, { 'branch', '-D', 'feature/p' })
  local late = commit_only(agent, 'late.txt', 'late', 'Late a')
  local agent_view = { 'Worktree agent-1 (feature/a)', commit_line(late, 'Late a') }
  expect_pane_lines('module', 'commits', agent_view)
  eq(messages(), {})
  toggle_in_pane()
  expect_pane_lines(
    'module',
    'commits',
    under_reported_agent({
      'Uncommitted',
      'Session work',
      'No commits on this session',
      'Worktree agent-1 (feature/a)',
      commit_line(late, 'Late a'),
    })
  )
  toggle_in_pane()

  expect_pane_lines('module', 'commits', agent_view)
end

T['the focused view']['offers the reported set first in s, after each report, and keeps it behind a worktree picked'] = function()
  local top = start_on_repository('announce-s-item')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  add_worktree(top, 'agent-2', 'feature/b')
  report('module', { kind = 'worktree', path = agent })
  expect_pane_lines('module', 'commits', AGENT_VIEW)

  press_s()
  eq(last_offered(), {
    prompt = PROMPT,
    texts = {
      '[reported] feature/a from ?',
      '[reported] All reported work (1)',
      '[worktree] agent-1 (feature/a)',
      '[worktree] agent-2 (feature/b)',
    },
  })
  child.lua('_G.choose(4)')
  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-2 (feature/b)', 'No commits in this worktree' }
  )
  press_s()
  child.lua('_G.choose(2)')

  expect_pane_lines('module', 'commits', AGENT_VIEW)
end

T['the focused view']['is not brought into view by a report while the pane is not shown, and shows the set once shown'] = function()
  local top = start_on_repository('announce-hidden')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  child.cmd('tabnew')
  local windows_before = child.lua_get('#vim.api.nvim_tabpage_list_wins(0)')
  child.cmd('tabprevious | only | enew | tabnext')

  report('module', { kind = 'worktree', path = agent })
  wait_until('the report told', function()
    return #told('module') == 1
  end)

  eq(child.lua_get('#vim.api.nvim_tabpage_list_wins(0)'), windows_before)
  eq(child.lua_get('#vim.fn.win_findbuf(_G.panes.module.commits)'), 0)
  child.lua('vim.api.nvim_win_set_buf(0, _G.panes.module.commits)')
  expect_pane_lines('module', 'commits', AGENT_VIEW)
end

T['a report git does not list yet']['made before the session’s repository is found is matched once it is, the pane never shown'] = function()
  local top = git_repo.create('announce-before-found', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent-1', 'feature/a')

  child.lua(
    [[
      local top, agent = ...
      _G.homes.module = require('aineo.changes')
      _G.homes.module.begin_session({
        directory = top,
        show_diff = function() end,
        start_timer = function()
          return function() end
        end,
      })
      _G.report('module', { kind = 'worktree', path = agent })
    ]],
    { top, agent }
  )

  wait_until('the report told', function()
    return #told('module') > 0
  end)
  eq(told('module'), { started_in('Worktree agent-1 (feature/a)') })
end

T['the editor’s own work'] = MiniTest.new_set()

T['the editor’s own work']['reported as its worktree or as its branch is not added, and nothing is told'] = function()
  local top = start_on_repository('announce-own')
  local agent = add_worktree(top, 'agent-1', 'feature/a')

  report('module', { kind = 'worktree', path = top })
  report('module', { kind = 'branch', branch = 'main' })
  report('module', { kind = 'worktree', path = agent })

  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-1 (feature/a)', 'No commits in this worktree' }
  )
  eq(told('module'), { started_in('Worktree agent-1 (feature/a)') })
end

T['the editor’s own work']['includes the working branch, which s never offers, though no worktree has it checked out'] = function()
  local top = git_repo.create('announce-working-branch', { ['notes.txt'] = { 'one' } })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'other' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  start_copy('module', top, 'main')

  report('module', { kind = 'branch', branch = 'main' })
  report('module', { kind = 'worktree', path = agent })

  expect_pane_lines('module', 'commits', AGENT_VIEW)
  eq(told('module'), { started_in('Worktree agent-1 (feature/a)') })
end

T['the Reported section'] = MiniTest.new_set()

--- The abbreviated id of `commit`, a full id, as a report's line shows it.
---
---@param commit string
---@return string
local function short(commit)
  return commit:sub(1, 7)
end

T['the Reported section']['lists each report atop the default view, newest first, with its base, label and age'] = function()
  local top = start_on_repository('announce-section')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local first = add_worktree(top, 'agent-1', 'feature/a')
  add_worktree(top, 'agent-2', 'feature/b')
  report('module', { kind = 'worktree', path = first, base = base, label = 'first task' })
  expect_pane_lines('module', 'commits', AGENT_VIEW)
  report('module', { kind = 'branch', branch = 'feature/b', base = base })
  wait_until('both reports told', function()
    return #told('module') == 2
  end)

  toggle_in_pane()

  expect_pane_lines('module', 'commits', {
    'Reported',
    ('branch feature/b from %s now'):format(short(base)),
    ('worktree feature/a from %s first task now'):format(short(base)),
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
    'Worktree agent-2 (feature/b)',
    'No commits in this worktree',
  })
end

--- Makes the worktree `agent-1` on `feature/a` beside the repository at
--- `top`, with two commits, `One` and `Two`; returns the worktree's top
--- level and the two commits' full ids.
---
---@param top string
---@return string worktree
---@return string one
---@return string two
local function agent_with_two_commits(top)
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local one = commit_only(agent, 'one.txt', 'one', 'One')
  local two = commit_only(agent, 'two.txt', 'two', 'Two')
  return agent, one, two
end

--- The first two lines of the default view of the module's home's pane,
--- once `\g` switched to it and it lists `expected` there.
---
---@param expected string[]
local function expect_reported_lines(expected)
  toggle_in_pane()
  wait_until('the Reported section lists ' .. vim.inspect(expected), function()
    return vim.deep_equal(vim.list_slice(pane_lines('module', 'commits'), 1, #expected), expected)
  end)
  eq(vim.list_slice(pane_lines('module', 'commits'), 1, #expected), expected)
end

T['the Reported section']['takes a report made again of the same work in place of the first, on one line'] = function()
  local top = start_on_repository('announce-again')
  local agent, one, two = agent_with_two_commits(top)
  report('module', { kind = 'worktree', path = agent, base = one, label = 'first' })
  wait_until('the report told', function()
    return #told('module') == 1
  end)

  report('module', { kind = 'branch', branch = 'feature/a', base = two, label = 'second' })

  expect_reported_lines({
    'Reported',
    ('branch feature/a from %s second now'):format(short(two)),
    'Uncommitted',
  })
  eq(#told('module'), 1)
end

T['the Reported section']['picks a report by Enter on its line, which shows its work alone'] = function()
  local top = start_on_repository('announce-enter')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local first = add_worktree(top, 'agent-1', 'feature/a')
  local second = add_worktree(top, 'agent-2', 'feature/b')
  report('module', { kind = 'worktree', path = first, base = base })
  report('module', { kind = 'worktree', path = second, base = base })
  wait_until('both reports told', function()
    return #told('module') == 2
  end)
  toggle_in_pane()
  expect_pane_lines('module', 'commits', {
    'Reported',
    ('worktree feature/b from %s now'):format(short(base)),
    ('worktree feature/a from %s now'):format(short(base)),
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
    'Worktree agent-2 (feature/b)',
    'No commits in this worktree',
  })

  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')
  child.lua([[pcall(vim.api.nvim_feedkeys, vim.keycode('<CR>'), 'mx', false)]])

  expect_pane_lines('module', 'commits', AGENT_VIEW)
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Worktree agent-1 (feature/a)', 'No files changed in this worktree' }
  )
end

T['the Reported section']['is offered first by s, newest first, a report picked showing its work alone'] = function()
  local top = start_on_repository('announce-s-reports')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local first = add_worktree(top, 'agent-1', 'feature/a')
  add_worktree(top, 'agent-2', 'feature/b')
  report('module', { kind = 'worktree', path = first, base = base, label = 'first' })
  expect_pane_lines('module', 'commits', AGENT_VIEW)
  report('module', { kind = 'branch', branch = 'feature/b', base = base, label = 'second' })
  wait_until('both reports told', function()
    return #told('module') == 2
  end)

  press_s()
  eq(last_offered().texts, {
    ('[reported] feature/b from %s  second'):format(short(base)),
    ('[reported] feature/a from %s  first'):format(short(base)),
    '[reported] All reported work (2)',
    '[worktree] agent-1 (feature/a)',
    '[worktree] agent-2 (feature/b)',
  })
  child.lua('_G.choose(2)')

  expect_pane_lines('module', 'commits', AGENT_VIEW)
end

T['the Reported section']['picks a reported worktree by Enter before the commits window has listed it'] = function()
  local top = start_on_repository('announce-enter-early')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', { kind = 'worktree', path = agent, base = base })
  wait_until('the report told', function()
    return #told('module') == 1
  end)
  expect_reported_lines({ 'Reported', ('worktree feature/a from %s now'):format(short(base)) })

  child.lua('vim.api.nvim_win_set_cursor(0, { 2, 0 })')
  child.lua([[pcall(vim.api.nvim_feedkeys, vim.keycode('<CR>'), 'mx', false)]])

  expect_pane_lines('module', 'commits', AGENT_VIEW)
  eq(messages(), {})
end

T['a reported base'] = MiniTest.new_set()

T['a reported base']['shows a worktree’s commits since it, and its files since it, uncommitted ones included'] = function()
  local top = start_on_repository('announce-base-worktree')
  local agent, one, two = agent_with_two_commits(top)
  git_repo.write(agent, 'u.txt', { 'uncommitted' })

  report('module', { kind = 'worktree', path = agent, base = one })

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    commit_line(two, 'Two'),
  })
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Worktree agent-1 (feature/a)', '  A two.txt', '  ? u.txt' }
  )
end

T['a reported base']['shows a branch no worktree has checked out from it, commits only, its heading saying so'] = function()
  local top = start_on_repository('announce-base-branch')
  local agent, one, two = agent_with_two_commits(top)
  git_repo.git(top, { 'worktree', 'remove', '--force', agent })

  report('module', { kind = 'branch', branch = 'feature/a', base = one })

  expect_pane_lines('module', 'commits', {
    'Branch feature/a (no worktree: commits only)',
    commit_line(two, 'Two'),
  })
  expect_pane_lines('module', 'files', { 'Files in: Branch feature/a', '  A two.txt' })
end

T['a reported base']['gives way to the pane’s own after a rebase onto newer work, which lists none of that work'] = function()
  local top = start_on_repository('announce-base-rebase')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', { kind = 'worktree', path = agent, base = base })
  expect_pane_lines('module', 'commits', AGENT_VIEW)
  local moved_on = commit_only(top, 'dev.txt', 'dev', 'Dev moved on, not the agent')
  commit_only(agent, 'agent.txt', 'agent', 'Agent work')
  git_repo.git(agent, { 'rebase', '--quiet', 'main' })
  local rebased = git_repo.git(agent, { 'rev-parse', 'HEAD' })

  child.lua('_G.homes.module.refresh_shown_pane()')

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    commit_line(rebased, 'Agent work'),
  })
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Worktree agent-1 (feature/a)', '  A agent.txt' }
  )
  expect_reported_lines({ 'Reported', ('worktree feature/a from %s now'):format(short(moved_on)) })
end

T['a reported base']['that the repository does not have gives way to the pane’s own, with no failure shown'] = function()
  local top = start_on_repository('announce-base-unknown')
  local agent, one, two = agent_with_two_commits(top)

  report('module', { kind = 'worktree', path = agent, base = ('0'):rep(40) })

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    commit_line(two, 'Two'),
    commit_line(one, 'One'),
  })
end

T['a reported base']['of a branch, that the repository does not have, gives way to the pane’s own'] = function()
  local top = start_on_repository('announce-base-unknown-branch')
  local agent, one, two = agent_with_two_commits(top)
  git_repo.git(top, { 'worktree', 'remove', '--force', agent })

  report('module', { kind = 'branch', branch = 'feature/a', base = ('0'):rep(40) })

  expect_pane_lines('module', 'commits', {
    'Branch feature/a (no worktree: commits only)',
    commit_line(two, 'Two'),
    commit_line(one, 'One'),
  })
end

T['a reported base']['missing, as in a report made before reports gave one, shows from ? and the base of today’s rule'] = function()
  local top = start_on_repository('announce-base-none')
  local agent, one, two = agent_with_two_commits(top)

  report('module', { kind = 'worktree', path = agent })

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    commit_line(two, 'Two'),
    commit_line(one, 'One'),
  })
  expect_reported_lines({ 'Reported', 'worktree feature/a from ? now' })
end

T['the Reported section']['takes the branch and base of a branch made in a reported worktree, the label kept'] = function()
  local top = start_on_repository('announce-new-branch')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', { kind = 'worktree', path = agent, base = base, label = 'task' })
  wait_until('the report told', function()
    return #told('module') == 1
  end)
  local one = commit_only(agent, 'one.txt', 'one', 'One')
  git_repo.git(agent, { 'checkout', '--quiet', '-b', 'feature/b' })

  report('module', { kind = 'branch', branch = 'feature/b', base = one, by_hook = true })
  child.lua('_G.homes.module.refresh_shown_pane()')

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/b)',
    'No commits in this worktree',
  })
  expect_reported_lines({
    'Reported',
    ('worktree feature/b from %s task now'):format(short(one)),
    'Uncommitted',
  })
end

T['the Reported section']['takes a branch reported and then a worktree made of it as one line'] = function()
  local top = start_on_repository('announce-branch-then-worktree')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.git(top, { 'branch', 'feature/w' })
  report('module', { kind = 'branch', branch = 'feature/w', base = base, label = 'task' })
  wait_until('the branch told', function()
    return #told('module') == 1
  end)
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), 'agent-w')
  git_repo.git(top, { 'worktree', 'add', '--quiet', worktree, 'feature/w' })

  report('module', { kind = 'worktree', path = worktree, base = base, by_hook = true })
  wait_until('the worktree told', function()
    return #told('module') == 2
  end)

  press_s()
  eq(vim.list_slice(last_offered().texts, 1, 2), {
    ('[reported] feature/w from %s  task'):format(short(base)),
    '[reported] All reported work (1)',
  })
end

T['the Reported section']['takes the agent’s base and label over the report of aineo’s hook, both ways'] = function()
  local top = start_on_repository('announce-hook-then-call')
  local agent, one, two = agent_with_two_commits(top)
  report('module', { kind = 'worktree', path = agent, base = one, by_hook = true })
  report('module', { kind = 'worktree', path = agent, base = two, label = 'task' })
  report('module', { kind = 'worktree', path = agent, base = one, by_hook = true })
  wait_until('the report told', function()
    return #told('module') == 1
  end)

  expect_reported_lines({
    'Reported',
    ('worktree feature/a from %s task now'):format(short(two)),
    'Uncommitted',
  })
end

return T
