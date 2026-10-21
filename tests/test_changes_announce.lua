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
  return git_repo.without_against_line(
    child.lua_get(
      'vim.api.nvim_buf_get_lines(_G.panes[...][select(2, ...)], 0, -1, true)',
      { key, which }
    )
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

--- The branch `name`, reported made from `base`, none when not given.
---
---@param name string
---@param base? string
---@return table
local function on(name, base)
  return { name = name, base = base }
end

--- An agent's call for the worktree at `path`, labelled `label`, listing
--- `branches`.
---
---@param path string
---@param label string
---@param branches table[]
---@return table
local function call_for(path, label, branches)
  return { worktree = path, label = label, branches = branches }
end

--- A report of aineo's hook for the worktree at `path`, of `branches`.
---
---@param path string
---@param branches table[]
---@return table
local function hook_for(path, branches)
  return { worktree = path, branches = branches, by_hook = true }
end

--- The agent's call `T` for the worktree at `path`, listing `feature/a`
--- with no base.
---
---@param path string
---@return table
local function agent_call(path)
  return call_for(path, 'T', { on('feature/a') })
end

--- The Reported section atop the default view once the worktree `agent-1`
--- on `feature/a` was reported by `agent_call()` a moment ago.
local REPORTED_AGENT = { 'Reported', 'T now', '  agent-1', '    feature/a * from ?' }

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

--- The words that tell the user git did not list the worktree `path` an
--- agent reported.
---
---@param path string
---@return string
local function unlisted(path)
  return ('aineo: Claude Code announced worktree %s, which git does not list; the changes pane is unchanged'):format(
    path
  )
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

--- The abbreviated id of `commit`, a full id, as a branch's line shows it.
---
---@param commit string
---@return string
local function short(commit)
  return commit:sub(1, 7)
end

--- Switches the view of the pane of the module's home as `\g` does with the
--- cursor in its commits window (`toggle_focused_view()`).
local function toggle_in_pane()
  enter_window_of('module', 'commits')
  child.lua('_G.homes.module.toggle_focused_view()')
end

--- Presses Enter on the line `line` of the commits window of the module's
--- home's pane.
---
---@param line integer
local function enter_on_line(line)
  enter_window_of('module', 'commits')
  child.lua('vim.api.nvim_win_set_cursor(0, { ..., 0 })', { line })
  child.lua([[pcall(vim.api.nvim_feedkeys, vim.keycode('<CR>'), 'mx', false)]])
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

--- The first lines of the default view of the module's home's pane, once
--- `\g` switched to it and it lists `expected` there.
---
---@param expected string[]
local function expect_reported_lines(expected)
  toggle_in_pane()
  wait_until('the Reported section lists ' .. vim.inspect(expected), function()
    return vim.deep_equal(vim.list_slice(pane_lines('module', 'commits'), 1, #expected), expected)
  end)
  eq(vim.list_slice(pane_lines('module', 'commits'), 1, #expected), expected)
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

--- The timers the child's home was asked for: how long each was, and
--- whether it was stopped.
---
---@return { milliseconds: integer, stopped: boolean }[]
local function timers()
  return child.lua_get([[vim.tbl_map(function(timer)
    return { milliseconds = timer.milliseconds, stopped = timer.stopped }
  end, _G.timers)]])
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
    { key, id, state }
  )
end

T['a reported worktree'] = MiniTest.new_set()

T['a reported worktree']['shows under its heading with its commits, nothing else, and is told once'] = function()
  local top = start_on_repository('announce-worktree')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local work_a = commit_only(agent, 'a.txt', 'a', 'Work a')

  report('module', agent_call(agent))

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

  report('module', agent_call(link))

  expect_pane_lines('module', 'commits', AGENT_VIEW)
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

  report('module', call_for(slow, 'T', { on('feature/a') }))
  report('module', call_for(fast, 'T', { on('feature/b') }))

  expect_pane_lines('module', 'commits', {
    'Worktree agent-2 (feature/b)',
    'No commits in this worktree',
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
  })
  eq(told('module'), {
    started_in('Worktree agent-1 (feature/a)'),
    started_in('Worktree agent-2 (feature/b)'),
  })
end

T['a report git does not list yet'] = MiniTest.new_set()

T['a report git does not list yet']['is added once a read lists it, a worktree added just after the call'] = function()
  local top = start_on_repository('announce-late')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local late = vim.fs.joinpath(vim.fs.dirname(top), 'agent-late')
  report('module', agent_call(agent))
  expect_pane_lines('module', 'commits', AGENT_VIEW)
  report('module', call_for(late, 'late', { on('feature/late') }))

  add_worktree(top, 'agent-late', 'feature/late')

  expect_pane_lines('module', 'commits', {
    'Worktree agent-late (feature/late)',
    'No commits in this worktree',
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
  })
  eq(told('module'), {
    started_in('Worktree agent-1 (feature/a)'),
    started_in('Worktree agent-late (feature/late)'),
  })
end

T['a report git does not list yet']['waits 60 s from the call, then is let go and told once, several at once'] = function()
  local top = start_on_repository('announce-unlisted')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local missing = vim.fs.joinpath(vim.fs.dirname(top), 'never-made')
  local other = vim.fs.joinpath(vim.fs.dirname(top), 'never-made-either')
  report('module', agent_call(missing))
  report('module', agent_call(other))
  report('module', agent_call(agent))
  expect_pane_lines('module', 'commits', AGENT_VIEW)

  child.lua('_G.fire(1); _G.fire(2); _G.fire(1)')

  eq(timers(), {
    { milliseconds = 60000, stopped = false },
    { milliseconds = 60000, stopped = false },
    { milliseconds = 60000, stopped = true },
  })
  eq(told('module'), {
    started_in('Worktree agent-1 (feature/a)'),
    unlisted(missing),
    unlisted(other),
  })
end

T['a report git does not list yet']['made again while it waits is taken and changes nothing: one timer, told once'] = function()
  local top = start_on_repository('announce-again-waiting')
  local missing = vim.fs.joinpath(vim.fs.dirname(top), 'never-made')

  local taken = child.lua_get(
    [[{
    _G.report('module', { worktree = ..., label = 'T', branches = { { name = 'a' } } }),
    _G.report('module', { worktree = ..., branches = { { name = 'b' } }, by_hook = true }),
  }]],
    { missing }
  )
  child.lua('_G.fire(1)')

  eq(taken, { true, true })
  eq(timers(), { { milliseconds = 60000, stopped = false } })
  eq(told('module'), { unlisted(missing) })
end

T['a report git does not list yet']['waits, at most 32 at once; a 33rd is not taken, and nothing is told of it'] = function()
  local top = start_on_repository('announce-at-most-32')
  local directory = vim.fs.dirname(top)

  local taken = child.lua_get(
    [[(function(directory)
      local taken = {}
      for index = 1, 33 do
        taken[index] = _G.report('module', {
          worktree = directory .. '/never-made-' .. index,
          label = 'T',
          branches = { { name = 'a' } },
        })
      end
      return taken
    end)(...)]],
    { directory }
  )

  eq(vim.list_slice(taken, 32), { true, false })
  eq(#timers(), 32)
  eq(told('module'), {})
end

T['a report git does not list yet']['listing no branch, of a worktree already removed, is let go untold'] = function()
  local top = start_on_repository('announce-empty-removed')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', agent_call(agent))
  expect_pane_lines('module', 'commits', AGENT_VIEW)
  git_repo.git(top, { 'worktree', 'remove', '--force', agent })

  report('module', call_for(agent, 'T', {}))
  expect_pane_lines('module', 'commits', DEFAULT_VIEW)
  child.lua('_G.fire(2)')

  eq(told('module'), { started_in('Worktree agent-1 (feature/a)') })
end

T['a report git does not list yet']['holding words git or a shell would read is compared, never run'] = function()
  local top = start_on_repository('announce-hostile')
  local witness = vim.fs.joinpath(fixture.directory('announce-hostile-witness'), 'made')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local directory = vim.fs.dirname(top)
  local hostile = vim.fs.joinpath(directory, ('$(touch %s)'):format(witness))
  report('module', call_for(vim.fs.joinpath(directory, '--help'), 'T', { on('--help') }))
  report('module', call_for(hostile, 'T', { on(('$(touch %s)'):format(witness)) }))
  report('module', agent_call(agent))
  expect_pane_lines('module', 'commits', AGENT_VIEW)

  child.lua('_G.fire(1); _G.fire(2)')

  eq(told('module'), {
    started_in('Worktree agent-1 (feature/a)'),
    unlisted(vim.fs.joinpath(directory, '--help')),
    unlisted(hostile),
  })
  eq(vim.uv.fs_stat(witness), nil)
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
      _G.report('module', { worktree = agent, label = 'T', branches = { { name = 'feature/a' } } })
    ]],
    { top, agent }
  )

  wait_until('the report told', function()
    return #told('module') > 0
  end)
  eq(told('module'), { started_in('Worktree agent-1 (feature/a)') })
end

T['the reported work'] = MiniTest.new_set()

T['the reported work']['adds up newest first, a worktree reported again moving first, told once'] = function()
  local top = start_on_repository('announce-add-up')
  local first = add_worktree(top, 'agent-1', 'feature/a')
  local second = add_worktree(top, 'agent-2', 'feature/b')
  report('module', agent_call(first))
  expect_pane_lines('module', 'commits', AGENT_VIEW)

  report('module', call_for(second, 'T', { on('feature/b') }))
  report('module', agent_call(first))
  local third = add_worktree(top, 'agent-3', 'feature/c')
  report('module', call_for(third, 'T', { on('feature/c') }))

  expect_pane_lines('module', 'commits', {
    'Worktree agent-3 (feature/c)',
    'No commits in this worktree',
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
    'Worktree agent-2 (feature/b)',
    'No commits in this worktree',
  })
  eq(told('module'), {
    started_in('Worktree agent-1 (feature/a)'),
    started_in('Worktree agent-2 (feature/b)'),
    started_in('Worktree agent-3 (feature/c)'),
  })
  eq(child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.bufwinid(_G.panes.module.commits))')[1], 1)
end

T['the reported work']['shows each worktree under its heading, then each branch it has not checked out, commits only'] = function()
  local top = start_on_repository('announce-page')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.write(top, 'notes.txt', { 'uncommitted' })
  commit_only(top, 'own.txt', 'own', 'Own')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local work_a = commit_only(agent, 'a.txt', 'a', 'Work a')
  local work_b = add_branch(top, 'feature/b', 'Work b')
  add_worktree(top, 'unreported', 'feature/u')

  report('module', call_for(agent, 'T', { on('feature/a', base), on('feature/b', base) }))

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    commit_line(work_a, 'Work a'),
    'Branch feature/b (not checked out: commits only)',
    commit_line(work_b, 'Work b'),
  })
end

T['the reported work']['drops a worktree git no longer lists, telling nothing, and once empty shows the default view, told once'] = function()
  local top = start_on_repository('announce-drop')
  local first = add_worktree(top, 'agent-1', 'feature/a')
  local second = add_worktree(top, 'agent-2', 'feature/b')
  report('module', agent_call(first))
  report('module', call_for(second, 'T', { on('feature/b') }))
  expect_pane_lines('module', 'commits', {
    'Worktree agent-2 (feature/b)',
    'No commits in this worktree',
    'Worktree agent-1 (feature/a)',
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

T['the reported work']['drops a branch git no longer lists from its worktree, the others staying'] = function()
  local top = start_on_repository('announce-drop-branch')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.git(top, { 'branch', 'feature/b' })
  report('module', call_for(agent, 'T', { on('feature/a', base), on('feature/b', base) }))
  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
    'Branch feature/b (not checked out: commits only)',
    'No commits on this branch',
  })

  git_repo.git(top, { 'branch', '-D', 'feature/b' })
  child.lua('_G.homes.module.refresh_shown_pane()')

  expect_pane_lines('module', 'commits', AGENT_VIEW)
  expect_reported_lines({
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    'Uncommitted',
  })
  eq(messages(), {})
end

T['the reported work']['loses a worktree an agent’s call lists no branch of'] = function()
  local top = start_on_repository('announce-empty')
  local first = add_worktree(top, 'agent-1', 'feature/a')
  local second = add_worktree(top, 'agent-2', 'feature/b')
  report('module', agent_call(first))
  report('module', call_for(second, 'T', { on('feature/b') }))
  expect_pane_lines('module', 'commits', {
    'Worktree agent-2 (feature/b)',
    'No commits in this worktree',
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
  })

  report('module', call_for(first, 'T', {}))

  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-2 (feature/b)', 'No commits in this worktree' }
  )
end

T['the reported work']['is emptied, and the reports still waiting dropped, when another session is followed'] = function()
  local top = start_on_repository('announce-other-session')
  local state = fixture.directory('announce-other-session-state')
  follow('module', '11111111-1111-4111-8111-111111111111', state)
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', agent_call(vim.fs.joinpath(vim.fs.dirname(top), 'never-made')))
  report('module', agent_call(agent))
  expect_pane_lines('module', 'commits', AGENT_VIEW)

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

T['the reported work']['is each changes home’s own'] = function()
  local top = start_on_repository('announce-two-homes')
  start_copy('other', top)
  expect_pane_lines('other', 'commits', DEFAULT_VIEW)
  local agent = add_worktree(top, 'agent-1', 'feature/a')

  report('module', agent_call(agent))
  expect_pane_lines('module', 'commits', AGENT_VIEW)
  child.lua('_G.homes.other.refresh_shown_pane()')

  expect_pane_lines('other', 'commits', DEFAULT_VIEW_WITH_AGENT)
end

T['the reported work']['lets the reports still waiting go untold when its home is let go'] = function()
  local top = start_on_repository('announce-let-go')
  start_copy('other', top)
  expect_pane_lines('other', 'commits', DEFAULT_VIEW)
  report('other', agent_call(vim.fs.joinpath(vim.fs.dirname(top), 'never-made')))

  child.lua('_G.homes.other.let_go()')

  eq(timers(), { { milliseconds = 60000, stopped = true } })
end

T['the focused view'] = MiniTest.new_set()

T['the focused view']['of the reported work is switched with the default view by \\g in the pane'] = function()
  local top = start_on_repository('announce-toggle')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', agent_call(agent))
  expect_pane_lines('module', 'commits', AGENT_VIEW)

  toggle_in_pane()
  expect_pane_lines('module', 'commits', under_reported_agent(DEFAULT_VIEW_WITH_AGENT))
  toggle_in_pane()

  expect_pane_lines('module', 'commits', AGENT_VIEW)
end

T['the focused view']['becomes the reported work at a new report, from a worktree picked with s, its worktree chosen'] = function()
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

  report('module', agent_call(agent))

  expect_pane_lines('module', 'commits', AGENT_VIEW)
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Worktree agent-1 (feature/a)', 'No files changed in this worktree' }
  )
  eq(child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.bufwinid(_G.panes.module.commits))')[1], 1)
end

T['the focused view']['of the reported work stays, untold, when the worktree picked behind it is removed'] = function()
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
  report('module', agent_call(agent))
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

T['the focused view']['of the reported work stays, untold, when the branch picked behind it is deleted'] = function()
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
  report('module', agent_call(agent))
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

T['the focused view']['is offered by s after the tree, as all reported work, and kept behind a worktree picked'] = function()
  local top = start_on_repository('announce-s-item')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  add_worktree(top, 'agent-2', 'feature/b')
  report('module', agent_call(agent))
  expect_pane_lines('module', 'commits', AGENT_VIEW)

  press_s()
  eq(last_offered(), {
    prompt = PROMPT,
    texts = {
      '[reported] T now',
      '[reported]   agent-1',
      '[reported]     feature/a * from ?',
      '[reported] All reported work (1)',
      '[worktree] agent-1 (feature/a)',
      '[worktree] agent-2 (feature/b)',
    },
  })
  child.lua('_G.choose(6)')
  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-2 (feature/b)', 'No commits in this worktree' }
  )
  press_s()
  child.lua('_G.choose(4)')

  expect_pane_lines('module', 'commits', AGENT_VIEW)
end

T['the focused view']['is not brought into view by a report while the pane is not shown, and shows the work once shown'] = function()
  local top = start_on_repository('announce-hidden')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  child.cmd('tabnew')
  local windows_before = child.lua_get('#vim.api.nvim_tabpage_list_wins(0)')
  child.cmd('tabprevious | only | enew | tabnext')

  report('module', agent_call(agent))
  wait_until('the report told', function()
    return #told('module') == 1
  end)

  eq(child.lua_get('#vim.api.nvim_tabpage_list_wins(0)'), windows_before)
  eq(child.lua_get('#vim.fn.win_findbuf(_G.panes.module.commits)'), 0)
  child.lua('vim.api.nvim_win_set_buf(0, _G.panes.module.commits)')
  expect_pane_lines('module', 'commits', AGENT_VIEW)
end

T['the editor’s own worktree'] = MiniTest.new_set()

T['the editor’s own worktree']['is listed in the tree, the default view kept, and nothing is told'] = function()
  local top = start_on_repository('announce-own')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local own_folder = vim.fs.basename(top)

  report('module', call_for(top, 'main work', { on('main', base) }))

  expect_pane_lines('module', 'commits', {
    'Reported',
    'main work now',
    '  ' .. own_folder,
    ('    main * from %s'):format(short(base)),
    'Uncommitted',
    'Session work',
    'No commits on this session',
  })
  eq(told('module'), {})
end

T['the editor’s own worktree']['picked by Enter on its line, from a worktree picked, shows the default view'] = function()
  local top = start_on_repository('announce-own-back')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', call_for(agent, 'agent', { on('feature/a', base) }))
  expect_pane_lines('module', 'commits', AGENT_VIEW)
  report('module', call_for(top, 'main work', { on('main', base) }))
  expect_reported_lines({
    'Reported',
    'main work now',
    '  ' .. vim.fs.basename(top),
    ('    main * from %s'):format(short(base)),
    'agent now',
    '  agent-1',
  })
  enter_on_line(6)
  expect_pane_lines('module', 'commits', AGENT_VIEW)
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Worktree agent-1 (feature/a)', 'No files changed in this worktree' }
  )
  expect_reported_lines({ 'Reported', 'main work now', '  ' .. vim.fs.basename(top) })
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Worktree agent-1 (feature/a)', 'No files changed in this worktree' }
  )

  enter_on_line(3)

  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Session work', 'No files changed on this session' }
  )
end

T['the editor’s own worktree']['shows on its checked-out branch’s line the base the default view reads'] = function()
  local top = git_repo.create('announce-own-base', { ['notes.txt'] = { 'one' } })
  local older = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local newer = commit_only(top, 'next.txt', 'next', 'Newer')
  start_copy('module', top)
  expect_pane_lines('module', 'commits', DEFAULT_VIEW)

  report('module', call_for(top, 'own', { on('main', older) }))

  expect_pane_lines('module', 'commits', {
    'Reported',
    'own now',
    '  ' .. vim.fs.basename(top),
    ('    main * from %s'):format(short(newer)),
    'Uncommitted',
    'Session work',
    'No commits on this session',
  })
end

T['the Reported section'] = MiniTest.new_set()

T['the Reported section']['lists the tree atop the default view: labels newest first, worktrees, branches, the checked-out one marked'] = function()
  local top = start_on_repository('announce-section')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local first = add_worktree(top, 'agent-1', 'feature/a')
  local second = add_worktree(top, 'agent-2', 'feature/b')
  git_repo.git(top, { 'branch', 'feature/c' })
  report('module', call_for(first, 'first task', { on('feature/c', base), on('feature/a', base) }))
  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
    'Branch feature/c (not checked out: commits only)',
    'No commits on this branch',
  })
  report('module', call_for(second, 'second task', { on('feature/b', base) }))
  wait_until('both reports told', function()
    return #told('module') == 2
  end)

  toggle_in_pane()

  expect_pane_lines('module', 'commits', {
    'Reported',
    'second task now',
    '  agent-2',
    ('    feature/b * from %s'):format(short(base)),
    'first task now',
    '  agent-1',
    ('    feature/c from %s'):format(short(base)),
    ('    feature/a * from %s'):format(short(base)),
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
    'Worktree agent-2 (feature/b)',
    'No commits in this worktree',
  })
end

T['the Reported section']['takes an agent’s call made again in place of the first: its set replaced, a branch left out gone'] = function()
  local top = start_on_repository('announce-again')
  local agent, one, two = agent_with_two_commits(top)
  git_repo.git(top, { 'branch', 'feature/b' })
  report('module', call_for(agent, 'first', { on('feature/a', one), on('feature/b', one) }))
  wait_until('the report told', function()
    return #told('module') == 1
  end)

  report('module', call_for(agent, 'second', { on('feature/a', two) }))

  expect_reported_lines({
    'Reported',
    'second now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(two)),
    'Uncommitted',
  })
  eq(#told('module'), 1)
end

T['the Reported section']['picks by Enter on a worktree’s line that worktree alone'] = function()
  local top = start_on_repository('announce-enter')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local first = add_worktree(top, 'agent-1', 'feature/a')
  local second = add_worktree(top, 'agent-2', 'feature/b')
  report('module', call_for(first, 'T', { on('feature/a', base) }))
  report('module', call_for(second, 'T', { on('feature/b', base) }))
  wait_until('both reports told', function()
    return #told('module') == 2
  end)
  expect_reported_lines({
    'Reported',
    'T now',
    '  agent-2',
    ('    feature/b * from %s'):format(short(base)),
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    'Uncommitted',
  })

  enter_on_line(5)

  expect_pane_lines('module', 'commits', AGENT_VIEW)
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Worktree agent-1 (feature/a)', 'No files changed in this worktree' }
  )
end

T['the Reported section']['picks by Enter on a label’s line every worktree and branch of that label together'] = function()
  local top = start_on_repository('announce-enter-label')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local first = add_worktree(top, 'agent-1', 'feature/a')
  local second = add_worktree(top, 'agent-2', 'feature/b')
  local third = add_worktree(top, 'agent-3', 'feature/c')
  git_repo.git(top, { 'branch', 'feature/d' })
  report('module', call_for(first, 'T', { on('feature/a', base), on('feature/d', base) }))
  report('module', call_for(second, 'other', { on('feature/b', base) }))
  report('module', call_for(third, 'T', { on('feature/c', base) }))
  wait_until('the reports told', function()
    return #told('module') == 3
  end)
  expect_reported_lines({
    'Reported',
    'T now',
    '  agent-3',
    ('    feature/c * from %s'):format(short(base)),
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    ('    feature/d from %s'):format(short(base)),
    'other now',
  })

  enter_on_line(2)

  expect_pane_lines('module', 'commits', {
    'Worktree agent-3 (feature/c)',
    'No commits in this worktree',
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
    'Branch feature/d (not checked out: commits only)',
    'No commits on this branch',
  })
end

T['the Reported section']['picks by Enter on a branch’s line its commits alone, or its worktree’s change while checked out there'] = function()
  local top = start_on_repository('announce-enter-branch')
  local agent, one, two = agent_with_two_commits(top)
  git_repo.write(agent, 'u.txt', { 'uncommitted' })
  git_repo.git(top, { 'branch', 'feature/b', two })
  report('module', call_for(agent, 'T', { on('feature/a', one), on('feature/b', one) }))
  wait_until('the report told', function()
    return #told('module') == 1
  end)
  expect_reported_lines({
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(one)),
    ('    feature/b from %s'):format(short(one)),
    'Uncommitted',
  })

  enter_on_line(5)
  expect_pane_lines('module', 'commits', {
    'Branch feature/b (not checked out: commits only)',
    commit_line(two, 'Two'),
  })
  expect_pane_lines('module', 'files', { 'Files in: Branch feature/b', '  A two.txt' })
  toggle_in_pane()
  enter_on_line(4)

  expect_pane_lines(
    'module',
    'commits',
    { 'Worktree agent-1 (feature/a)', commit_line(two, 'Two') }
  )
  expect_pane_lines(
    'module',
    'files',
    { 'Files in: Worktree agent-1 (feature/a)', '  A two.txt', '  ? u.txt' }
  )
end

T['the Reported section']['shows a file’s diff from a branch’s base by Enter under its whole change'] = function()
  local top = start_on_repository('announce-branch-diff')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  add_branch(top, 'feature/b', 'Work b')
  report('module', call_for(agent, 'T', { on('feature/a', base), on('feature/b', base) }))
  wait_until('the report told', function()
    return #told('module') == 1
  end)
  expect_reported_lines({
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    ('    feature/b from %s'):format(short(base)),
  })
  enter_on_line(5)
  expect_pane_lines('module', 'files', { 'Files in: Branch feature/b', '  A branch.txt' })

  enter_window_of('module', 'files')
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')
  child.lua([[pcall(vim.api.nvim_feedkeys, vim.keycode('<CR>'), 'mx', false)]])

  wait_until('the diff shown', function()
    return child.lua_get([[vim.fn.bufexists('aineo://branch/feature/b//diff/branch.txt') == 1]])
  end)
end

--- The second line of the files window of the module's home's pane, which
--- says what its diffs compare against, as the buffer holds it.
---
---@return string
local function against_line()
  return child.lua_get('vim.api.nvim_buf_get_lines(_G.panes.module.files, 1, 2, true)[1]')
end

--- Waits until the second line of the module's files window is `expected`,
--- at most `git_repo.PATIENCE_MS`, and asserts that it is.
---
---@param expected string
local function expect_against_line(expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return against_line() == expected
  end, 10)
  eq(against_line(), expected)
end

T['the Reported section']['says on the Against line that a branch’s base is the reported one, when it is read from it'] = function()
  local top = start_on_repository('announce-against-reported')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local tip = add_branch(top, 'feature/b', 'Work b')
  report('module', call_for(agent, 'T', { on('feature/a', base), on('feature/b', base) }))
  wait_until('the report told', function()
    return #told('module') == 1
  end)
  expect_reported_lines({
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    ('    feature/b from %s'):format(short(base)),
  })

  enter_on_line(5)

  expect_against_line(
    ('Against: %s (feature/a, main) reported base → %s (feature/b)'):format(
      short(base),
      short(tip)
    )
  )
end

T['the Reported section']['says on the Against line that a branch’s base is a merge base, when the reported one is not behind its tip'] = function()
  local top = start_on_repository('announce-against-merge-base')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local tip = add_branch(top, 'feature/b', 'Work b')
  git_repo.write(top, 'main.txt', { 'main moves' })
  local moved = git_repo.commit_all(top, 'Main moves')
  report('module', call_for(agent, 'T', { on('feature/a', base), on('feature/b', moved) }))
  wait_until('the report told', function()
    return #told('module') == 1
  end)
  expect_reported_lines({
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    ('    feature/b from %s'):format(short(moved)),
  })

  enter_on_line(5)

  expect_against_line(
    ('Against: %s (feature/a) merge base with %s → %s (feature/b)'):format(
      short(base),
      short(moved),
      short(tip)
    )
  )
end

T['the Reported section']['is offered first by s, as the tree, an item picked showing its work alone'] = function()
  local top = start_on_repository('announce-s-reports')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local first = add_worktree(top, 'agent-1', 'feature/a')
  local second = add_worktree(top, 'agent-2', 'feature/b')
  report('module', call_for(first, 'first', { on('feature/a', base) }))
  expect_pane_lines('module', 'commits', AGENT_VIEW)
  report('module', call_for(second, 'second', { on('feature/b', base) }))
  wait_until('both reports told', function()
    return #told('module') == 2
  end)

  press_s()
  eq(last_offered().texts, {
    '[reported] second now',
    '[reported]   agent-2',
    ('[reported]     feature/b * from %s'):format(short(base)),
    '[reported] first now',
    '[reported]   agent-1',
    ('[reported]     feature/a * from %s'):format(short(base)),
    '[reported] All reported work (2)',
    '[worktree] agent-1 (feature/a)',
    '[worktree] agent-2 (feature/b)',
  })
  child.lua('_G.choose(5)')

  expect_pane_lines('module', 'commits', AGENT_VIEW)
end

T['the Reported section']['offers all reported work in s counting the worktrees, not the labels or branches'] = function()
  local top = start_on_repository('announce-s-count')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local first = add_worktree(top, 'agent-1', 'feature/a')
  local second = add_worktree(top, 'agent-2', 'feature/b')
  git_repo.git(top, { 'branch', 'feature/c' })
  report('module', call_for(first, 'T', { on('feature/a', base), on('feature/c', base) }))
  report('module', call_for(second, 'T', { on('feature/b', base) }))
  wait_until('both reports told', function()
    return #told('module') == 2
  end)

  press_s()

  eq(last_offered().texts[7], '[reported] All reported work (2)')
end

T['the Reported section']['picks a reported worktree by Enter before the commits window has listed it'] = function()
  local top = start_on_repository('announce-enter-early')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', call_for(agent, 'T', { on('feature/a', base) }))
  wait_until('the report told', function()
    return #told('module') == 1
  end)
  expect_reported_lines({ 'Reported', 'T now', '  agent-1' })

  enter_on_line(3)

  expect_pane_lines('module', 'commits', AGENT_VIEW)
  eq(messages(), {})
end

T['the Reported section']['adds a branch aineo’s hook saw made in a reported worktree beside the others, the label kept'] = function()
  local top = start_on_repository('announce-new-branch')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', call_for(agent, 'task', { on('feature/a', base) }))
  wait_until('the report told', function()
    return #told('module') == 1
  end)
  local one = commit_only(agent, 'one.txt', 'one', 'One')
  git_repo.git(agent, { 'checkout', '--quiet', '-b', 'feature/b' })

  report('module', hook_for(agent, { on('feature/b', one) }))
  child.lua('_G.homes.module.refresh_shown_pane()')

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/b)',
    'No commits in this worktree',
    'Branch feature/a (not checked out: commits only)',
    commit_line(one, 'One'),
  })
  expect_reported_lines({
    'Reported',
    'task now',
    '  agent-1',
    ('    feature/a from %s'):format(short(base)),
    ('    feature/b * from %s'):format(short(one)),
    'Uncommitted',
  })
  eq(#told('module'), 1)
end

T['the Reported section']['lists a worktree aineo’s hook saw added under no label, until an agent’s call gives one'] = function()
  local top = start_on_repository('announce-hook-worktree')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', hook_for(agent, { on('feature/a', base) }))
  wait_until('the report told', function()
    return #told('module') == 1
  end)
  expect_reported_lines({
    'Reported',
    '(no label) now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    'Uncommitted',
  })
  toggle_in_pane()

  report('module', call_for(agent, 'task', { on('feature/a', base) }))

  expect_reported_lines({
    'Reported',
    'task now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    'Uncommitted',
  })
end

T['the Reported section']['takes the agent’s base over the report of aineo’s hook, both ways'] = function()
  local top = start_on_repository('announce-hook-then-call')
  local agent, one, two = agent_with_two_commits(top)
  report('module', hook_for(agent, { on('feature/a', one) }))
  wait_until('the hook’s report told', function()
    return #told('module') == 1
  end)
  report('module', call_for(agent, 'task', { on('feature/a', two) }))
  report('module', hook_for(agent, { on('feature/a', one) }))

  expect_reported_lines({
    'Reported',
    'task now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(two)),
    'Uncommitted',
  })
end

T['a reported base'] = MiniTest.new_set()

T['a reported base']['shows a worktree’s commits since its checked-out branch’s, and its files since it, uncommitted ones included'] = function()
  local top = start_on_repository('announce-base-worktree')
  local agent, one, two = agent_with_two_commits(top)
  git_repo.write(agent, 'u.txt', { 'uncommitted' })

  report('module', call_for(agent, 'T', { on('feature/a', one) }))

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

T['a reported base']['gives way to the pane’s own after a rebase onto newer work, which lists none of that work'] = function()
  local top = start_on_repository('announce-base-rebase')
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  report('module', call_for(agent, 'T', { on('feature/a', base) }))
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
  expect_reported_lines({
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(moved_on)),
  })
end

T['a reported base']['that the repository does not have gives way to the pane’s own, with no failure shown'] = function()
  local top = start_on_repository('announce-base-unknown')
  local agent, one, two = agent_with_two_commits(top)

  report('module', call_for(agent, 'T', { on('feature/a', ('0'):rep(40)) }))

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    commit_line(two, 'Two'),
    commit_line(one, 'One'),
  })
end

T['a reported base']['of a branch not checked out, that the repository does not have, gives way to the pane’s own'] = function()
  local top = start_on_repository('announce-base-unknown-branch')
  local agent, one, two = agent_with_two_commits(top)
  git_repo.git(agent, { 'checkout', '--quiet', '--detach' })
  local other = add_worktree(top, 'agent-2', 'feature/o')

  report('module', call_for(other, 'T', { on('feature/o'), on('feature/a', ('0'):rep(40)) }))

  expect_pane_lines('module', 'commits', {
    'Worktree agent-2 (feature/o)',
    'No commits in this worktree',
    'Branch feature/a (not checked out: commits only)',
    commit_line(two, 'Two'),
    commit_line(one, 'One'),
  })
end

T['a reported base']['missing, as in a report kept before reports gave one, shows from ? and the base of today’s rule'] = function()
  local top = start_on_repository('announce-base-none')
  local agent, one, two = agent_with_two_commits(top)

  report('module', agent_call(agent))

  expect_pane_lines('module', 'commits', {
    'Worktree agent-1 (feature/a)',
    commit_line(two, 'Two'),
    commit_line(one, 'One'),
  })
  expect_reported_lines({ 'Reported', 'T now', '  agent-1', '    feature/a * from ?' })
end

return T
