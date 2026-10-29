local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that defines, in the child, `_G.start_copy(directory)`: it begins
--- the session of the changes module's own home for `directory`, with a
--- stand-in timer that keeps each timer it is asked for in `_G.timers`, and
--- shows its two buffers in a tab page of its own: the files buffer in the
--- tab's window, the commits buffer in a window below it. `_G.report(work)`
--- hands the home a report. `vim.ui.select` is replaced by a picker that
--- keeps every request in `_G.pickers`, answered by `_G.choose()`, and
--- `vim.notify` by one that keeps every message in `_G.messages`.
local HOME = [[
  _G.pickers, _G.messages, _G.timers = {}, {}, {}
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
  _G.report = function(work)
    return require('aineo.changes').add_reported_work(work, function() end)
  end
  _G.start_copy = function(directory)
    local home = require('aineo.changes')
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
    _G.pane = home.pane_buffers()
    vim.api.nvim_win_set_buf(0, _G.pane.files)
    vim.api.nvim_open_win(_G.pane.commits, false, { split = 'below' })
  end
]]

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
      child.lua(HOME)
    end,
    post_once = child.stop,
  },
})

--- The default view of a repository with no commit of the session's own.
local DEFAULT_VIEW = { 'Uncommitted', 'Session work', 'No commits on this session' }

--- The lines of the pane's buffer `which`, less the files window's
--- `Against:` line.
---
---@param which 'files'|'commits'
---@return string[]
local function pane_lines(which)
  return git_repo.without_against_line(
    child.lua_get('vim.api.nvim_buf_get_lines(_G.pane[...], 0, -1, true)', { which })
  )
end

--- Waits until the pane's buffer `which` holds `expected`, at most
--- `git_repo.PATIENCE_MS`, and asserts it.
---
---@param which 'files'|'commits'
---@param expected string[]
local function expect_pane_lines(which, expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(pane_lines(which), expected)
  end, 10)
  eq(pane_lines(which), expected)
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

--- The first 7 characters of the commit id `commit`.
---
---@param commit string
---@return string
local function short(commit)
  return commit:sub(1, 7)
end

--- `line`, a commits window's line, indented as a commit under a branch of
--- the Reported section.
---
---@param line string
---@return string
local function under_branch(line)
  return '      ' .. line
end

--- Makes the pane's window `which` the current window.
---
---@param which 'files'|'commits'
local function enter_window_of(which)
  child.lua('vim.api.nvim_set_current_win(vim.fn.win_findbuf(_G.pane[...])[1])', { which })
end

--- Presses Enter on the line `line` of the commits window.
---
---@param line integer
local function enter_on_line(line)
  enter_window_of('commits')
  child.lua('vim.api.nvim_win_set_cursor(0, { ..., 0 })', { line })
  child.lua([[pcall(vim.api.nvim_feedkeys, vim.keycode('<CR>'), 'mx', false)]])
end

--- The editor's own worktree as the cases build it: its top level and
--- folder, the session's base, the commit made after it on `main` that the
--- branch `feature/own` was reported made from, and the branch's own commit.
---@class OwnWork
---@field top string
---@field folder string
---@field session_base string
---@field reported_base string
---@field on_branch string

--- A Claude Code session id.
local SESSION = '11111111-1111-4111-8111-111111111111'

--- Makes the home follow the Claude Code session `SESSION`, its base, saves
--- and view kept under `state`.
---
---@param state string
local function follow(state)
  child.lua(
    "require('aineo.changes').follow_changes_session({ id = ..., state_directory = select(2, ...) })",
    { SESSION, state }
  )
end

--- Makes the repository `name`, starts the home on it — following
--- `SESSION`, its view kept under `state`, when given — then, the session's
--- base taken, commits `Before the branch` on `main`, checks out the new
--- branch `feature/own` and commits `On the branch` on it, and reports that
--- branch in the editor's own worktree, made from `Before the branch` — or
--- from no base, `from ?`, with `without_base`. Waits for the default view
--- to list the Reported section, the branch's commits since the base its
--- view reads under it.
---
---@param name string
---@param without_base? boolean
---@param state? string
---@return OwnWork
local function start_on_own_branch(name, without_base, state)
  local top = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  local session_base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  child.lua('_G.start_copy(...)', { top })
  if state then
    follow(state)
  end
  expect_pane_lines('commits', DEFAULT_VIEW)
  local reported_base = commit_only(top, 'before.txt', 'before', 'Before the branch')
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'feature/own' })
  local on_branch = commit_only(top, 'branch.txt', 'branch', 'On the branch')
  child.lua('_G.report(...)', {
    {
      worktree = top,
      label = 'own',
      branches = { { name = 'feature/own', base = not without_base and reported_base or nil } },
    },
  })
  local folder = vim.fs.basename(top)
  local base_shown = without_base and '?' or short(reported_base)
  local commits = {
    git_repo.commit_line(on_branch, 'On the branch'),
    git_repo.commit_line(reported_base, 'Before the branch'),
  }
  local under = without_base and {} or { under_branch(commits[1]) }
  expect_pane_lines(
    'commits',
    vim.list_extend(
      vim.list_extend({
        'Reported',
        'own now',
        '  ' .. folder,
        ('    feature/own * from %s'):format(base_shown),
        '      Uncommitted',
      }, under),
      vim.list_extend({ 'Uncommitted', 'Session work' }, commits)
    )
  )
  return {
    top = top,
    folder = folder,
    session_base = session_base,
    reported_base = reported_base,
    on_branch = on_branch,
  }
end

--- The commits window's lines for the editor's own worktree `work` shown
--- alone, its commits from the reported base.
---
---@param work OwnWork
---@return string[]
local function own_view(work)
  return {
    ('Worktree %s (feature/own) · yours'):format(work.folder),
    'Uncommitted',
    git_repo.commit_line(work.on_branch, 'On the branch'),
  }
end

T['Enter'] = MiniTest.new_set()

T['Enter']['on the editor’s own worktree’s lines shows it alone, its commits from the reported base'] =
  MiniTest.new_set({
    parametrize = { { 'worktree', 3 }, { 'branch', 4 } },
  })

T['Enter']['on the editor’s own worktree’s lines shows it alone, its commits from the reported base']['line'] = function(
  _,
  line
)
  local work = start_on_own_branch('own-view-enter-' .. line)

  enter_on_line(line)

  expect_pane_lines('commits', own_view(work))
end

T['Enter']['on the editor’s own worktree’s line lists in the files window its whole change from the reported base, its uncommitted files included'] = function()
  local work = start_on_own_branch('own-view-files')
  git_repo.write(work.top, 'loose.txt', { 'loose' })

  enter_on_line(3)

  expect_pane_lines('files', {
    ('Files in: Worktree %s (feature/own) · yours'):format(work.folder),
    '  A branch.txt',
    '  ? loose.txt',
  })
end

T['Enter']['on a branch reported with no base shows the commits from the default view’s base'] = function()
  local work = start_on_own_branch('own-view-no-base', true)

  enter_on_line(4)

  expect_pane_lines('commits', {
    ('Worktree %s (feature/own) · yours'):format(work.folder),
    'Uncommitted',
    git_repo.commit_line(work.on_branch, 'On the branch'),
    git_repo.commit_line(work.reported_base, 'Before the branch'),
  })
end

T['Enter']['on a branch reported from a commit older than the session’s base shows its commits from that commit'] = function()
  local top = git_repo.create('own-view-older-base', { ['notes.txt'] = { 'one' } })
  local created_from = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'feature/own' })
  local before_session = commit_only(top, 'before.txt', 'before', 'Before the session')
  child.lua('_G.start_copy(...)', { top })
  expect_pane_lines('commits', DEFAULT_VIEW)
  local in_session = commit_only(top, 'in.txt', 'in', 'In the session')
  child.lua('_G.report(...)', {
    { worktree = top, label = 'own', branches = { { name = 'feature/own', base = created_from } } },
  })
  git_repo.wait_until('the Reported section listed', function()
    return pane_lines('commits')[1] == 'Reported'
  end)

  enter_on_line(3)

  expect_pane_lines('commits', {
    ('Worktree %s (feature/own) · yours'):format(vim.fs.basename(top)),
    'Uncommitted',
    git_repo.commit_line(in_session, 'In the session'),
    git_repo.commit_line(before_session, 'Before the session'),
  })
end

T['Enter']['on a branch reported from a commit not in its history shows the commits from the default view’s base'] = function()
  local top = git_repo.create('own-view-unrelated-base', { ['notes.txt'] = { 'one' } })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'side' })
  local elsewhere = commit_only(top, 'side.txt', 'side', 'Elsewhere')
  git_repo.git(top, { 'checkout', '--quiet', 'main' })
  commit_only(top, 'main.txt', 'main', 'On main')
  child.lua('_G.start_copy(...)', { top })
  expect_pane_lines('commits', DEFAULT_VIEW)
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'feature/own' })
  local on_branch = commit_only(top, 'branch.txt', 'branch', 'On the branch')
  child.lua('_G.report(...)', {
    { worktree = top, label = 'own', branches = { { name = 'feature/own', base = elsewhere } } },
  })
  git_repo.wait_until('the Reported section listed', function()
    return pane_lines('commits')[1] == 'Reported'
  end)

  enter_on_line(3)

  expect_pane_lines('commits', {
    ('Worktree %s (feature/own) · yours'):format(vim.fs.basename(top)),
    'Uncommitted',
    git_repo.commit_line(on_branch, 'On the branch'),
  })
end

T['Enter']['on a commit made before the session’s base keeps it chosen through a read'] = function()
  local top = git_repo.create('own-view-older-commit', { ['notes.txt'] = { 'one' } })
  local created_from = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'feature/own' })
  local before_session = commit_only(top, 'before.txt', 'before', 'Before the session')
  child.lua('_G.start_copy(...)', { top })
  expect_pane_lines('commits', DEFAULT_VIEW)
  child.lua('_G.report(...)', {
    { worktree = top, label = 'own', branches = { { name = 'feature/own', base = created_from } } },
  })
  git_repo.wait_until('the Reported section listed', function()
    return pane_lines('commits')[1] == 'Reported'
  end)
  enter_on_line(3)
  local heading = ('Worktree %s (feature/own) · yours'):format(vim.fs.basename(top))
  expect_pane_lines(
    'commits',
    { heading, 'Uncommitted', git_repo.commit_line(before_session, 'Before the session') }
  )
  enter_window_of('commits')
  child.type_keys('3G')
  local chosen = 'Files in: ' .. git_repo.commit_line(before_session, 'Before the session')
  git_repo.wait_until('the commit chosen', function()
    return pane_lines('files')[1] == chosen
  end)

  local later = commit_only(top, 'later.txt', 'later', 'Later')
  child.lua("require('aineo.changes').refresh_shown_pane()")
  expect_pane_lines('commits', {
    heading,
    'Uncommitted',
    git_repo.commit_line(later, 'Later'),
    git_repo.commit_line(before_session, 'Before the session'),
  })

  eq(pane_lines('files')[1], chosen)
end

T['the default view'] = MiniTest.new_set()

--- The Lua that holds back, in the child, every call of the repository's
--- watch while `_G.watch_on` is false, so that a case decides which reads
--- follow a change.
local WATCH_GATE = [[
  local git = require('aineo.git')
  local watch_repository = git.watch_repository
  _G.watch_on = true
  git.watch_repository = function(found, on_change, options)
    return watch_repository(found, function(...)
      if _G.watch_on then
        on_change(...)
      end
    end, options)
  end
]]

--- The line of the commits window below `Session work` that reads
--- `wanted`; nil when none does.
---
---@param wanted string
---@return integer|nil
local function line_below_session_work(wanted)
  local listed = pane_lines('commits')
  local session_work = vim.fn.index(listed, 'Session work') + 1
  local position = vim.fn.index(vim.list_slice(listed, session_work + 1), wanted) + 1
  return session_work > 0 and position > 0 and session_work + position or nil
end

--- How long a case lets the reads a change started end before it takes
--- the next step, where no line of the pane tells that they have.
local SETTLE_MS = 1000

T['the default view']['gives a commit a reset removed way to Session work, your branch reported'] = function()
  child.lua(WATCH_GATE)
  local top = git_repo.create('own-view-reset', { ['notes.txt'] = { 'one' } })
  child.lua('_G.start_copy(...)', { top })
  expect_pane_lines('commits', DEFAULT_VIEW)
  local reported_base = commit_only(top, 'before.txt', 'before', 'Before the branch')
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'feature/own' })
  local on_branch = commit_only(top, 'branch.txt', 'branch', 'On the branch')
  local third = commit_only(top, 'third.txt', 'third', 'Third')
  child.lua('_G.report(...)', {
    {
      worktree = top,
      label = 'own',
      branches = { { name = 'feature/own', base = reported_base } },
    },
  })
  child.lua("require('aineo.changes').refresh_shown_pane()")
  local third_line = git_repo.commit_line(third, 'Third')
  git_repo.wait_until('Third listed below Session work', function()
    return pane_lines('commits')[1] == 'Reported' and line_below_session_work(third_line) ~= nil
  end)
  vim.wait(SETTLE_MS)
  enter_window_of('commits')
  child.type_keys(line_below_session_work(third_line) .. 'G')
  git_repo.wait_until('Third chosen', function()
    return pane_lines('files')[1] == 'Files in: ' .. third_line
  end)
  vim.wait(SETTLE_MS)
  child.lua('_G.watch_on = false')

  git_repo.git(top, { 'reset', '--quiet', '--hard', 'HEAD~1' })
  child.lua("require('aineo.changes').refresh_shown_pane()")

  git_repo.wait_until('the reset read', function()
    return line_below_session_work(third_line) == nil
      and line_below_session_work(git_repo.commit_line(on_branch, 'On the branch')) ~= nil
  end)
  expect_pane_lines('files', { 'Files in: Session work', '  A before.txt', '  A branch.txt' })
end

T['the default view']['gives a commit chosen in your view from before the session’s base way to Session work'] = function()
  local top = git_repo.create('own-view-older-commit-back', { ['notes.txt'] = { 'one' } })
  local created_from = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'feature/own' })
  local before_session = commit_only(top, 'before.txt', 'before', 'Before the session')
  child.lua('_G.start_copy(...)', { top })
  expect_pane_lines('commits', DEFAULT_VIEW)
  child.lua('_G.report(...)', {
    { worktree = top, label = 'own', branches = { { name = 'feature/own', base = created_from } } },
  })
  git_repo.wait_until('the Reported section listed', function()
    return pane_lines('commits')[1] == 'Reported'
  end)
  enter_on_line(3)
  expect_pane_lines('commits', {
    ('Worktree %s (feature/own) · yours'):format(vim.fs.basename(top)),
    'Uncommitted',
    git_repo.commit_line(before_session, 'Before the session'),
  })
  enter_window_of('commits')
  child.type_keys('3G')
  git_repo.wait_until('the commit chosen', function()
    return pane_lines('files')[1]
      == 'Files in: ' .. git_repo.commit_line(before_session, 'Before the session')
  end)

  enter_window_of('commits')
  child.lua("require('aineo.changes').toggle_focused_view()")

  expect_pane_lines('files', { 'Files in: Session work', 'No files changed on this session' })
end

T['a read'] = MiniTest.new_set()

--- The Lua that keeps, in the child's `_G.git_runs`, every process the
--- home starts from then on.
local COUNT_GIT_RUNS = [[
  _G.git_runs = 0
  local system = vim.system
  vim.system = function(...)
    _G.git_runs = _G.git_runs + 1
    return system(...)
  end
]]

--- How many processes one read of the shown pane starts, its watch held
--- back (`WATCH_GATE`), counted once none has started for a while.
---
---@return integer
local function git_runs_of_one_read()
  vim.wait(SETTLE_MS)
  child.lua('_G.watch_on = false')
  child.lua(COUNT_GIT_RUNS)
  child.lua("require('aineo.changes').refresh_shown_pane()")
  local counted, still_since = -1, vim.uv.now()
  vim.wait(git_repo.PATIENCE_MS, function()
    local runs = child.lua_get('_G.git_runs')
    if runs ~= counted then
      counted, still_since = runs, vim.uv.now()
    end
    return runs > 0 and vim.uv.now() - still_since > SETTLE_MS
  end, 50)
  return counted
end

T['a read']['of the default view, your branch reported, runs git once for each list'] = function()
  child.lua(WATCH_GATE)
  start_on_own_branch('own-view-git-runs')

  eq(git_runs_of_one_read(), 13)
end

T['a read']['runs no git for your view while no branch you have checked out is reported'] = function()
  child.lua(WATCH_GATE)
  local top = git_repo.create('own-view-git-runs-lonely', { ['notes.txt'] = { 'one' } })
  child.lua('_G.start_copy(...)', { top })
  expect_pane_lines('commits', DEFAULT_VIEW)
  git_repo.git(top, { 'branch', 'lonely' })
  child.lua('_G.report(...)', {
    { worktree = top, label = 'own', branches = { { name = 'lonely' } } },
  })
  git_repo.wait_until('the Reported section listed', function()
    return pane_lines('commits')[1] == 'Reported'
  end)

  eq(git_runs_of_one_read(), 17)
end

T['the tree line'] = MiniTest.new_set()

--- The Lua that keeps, in the child's `_G.branch_lines`, every text the
--- commits window has written on the line of the branch `feature/own`,
--- each once, in the order first written.
local RECORD_BRANCH_LINES = [[
  _G.branch_lines = {}
  local seen = {}
  vim.api.nvim_buf_attach(_G.pane.commits, false, {
    on_lines = function(_, buffer)
      vim.schedule(function()
        for _, text in ipairs(vim.api.nvim_buf_get_lines(buffer, 0, -1, true)) do
          if vim.startswith(text, '    feature/own') and not seen[text] then
            seen[text] = true
            table.insert(_G.branch_lines, text)
          end
        end
      end)
    end,
  })
]]

T['the tree line']['of your branch is written from the reported base alone after a report older than the session’s base'] = function()
  local top = git_repo.create('own-view-line-once', { ['notes.txt'] = { 'one' } })
  local created_from = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'feature/own' })
  local before_session = commit_only(top, 'before.txt', 'before', 'Before the session')
  child.lua('_G.start_copy(...)', { top })
  expect_pane_lines('commits', DEFAULT_VIEW)
  child.lua(RECORD_BRANCH_LINES)

  child.lua('_G.report(...)', {
    { worktree = top, label = 'own', branches = { { name = 'feature/own', base = created_from } } },
  })

  local under = under_branch(git_repo.commit_line(before_session, 'Before the session'))
  git_repo.wait_until('the branch’s commit listed under its line', function()
    return vim.tbl_contains(pane_lines('commits'), under)
  end)
  eq(
    child.lua_get('_G.branch_lines'),
    { ('    feature/own * from %s'):format(short(created_from)) }
  )
end

--- Presses `s` in the commits window, waits until its picker opens, and
--- picks the item at `position`.
---
---@param position integer
local function pick(position)
  local before = child.lua_get('#_G.pickers')
  enter_window_of('commits')
  child.lua("pcall(vim.api.nvim_feedkeys, 's', 'mx', false)")
  git_repo.wait_until('the picker opened', function()
    return child.lua_get('#_G.pickers') > before
  end)
  child.lua('_G.choose(...)', { position })
end

T['s'] = MiniTest.new_set()

T['s']['offers the editor’s own worktree’s lines, each of whose picks shows it alone'] =
  MiniTest.new_set({
    parametrize = {
      { 2, 'Worktree %s (feature/own) · yours' },
      { 3, 'Worktree %s (feature/own) · yours' },
      { 4, 'Uncommitted' },
    },
  })

T['s']['offers the editor’s own worktree’s lines, each of whose picks shows it alone']['item'] = function(
  position,
  chosen
)
  local work = start_on_own_branch('own-view-s-' .. position)

  pick(position)

  expect_pane_lines('commits', own_view(work))
  local heading = 'Files in: ' .. chosen:format(work.folder)
  git_repo.wait_until('the files window lists ' .. heading, function()
    return pane_lines('files')[1] == heading
  end)
end

--- Switches the pane's view as `\g` does with the cursor in its commits
--- window (`toggle_focused_view()`).
local function toggle_in_pane()
  enter_window_of('commits')
  child.lua("require('aineo.changes').toggle_focused_view()")
end

T['\\g'] = MiniTest.new_set()

T['\\g']['switches between the editor’s own worktree shown alone and the default view'] = function()
  local work = start_on_own_branch('own-view-toggle')
  enter_on_line(3)
  expect_pane_lines('commits', own_view(work))

  toggle_in_pane()
  git_repo.wait_until('the default view shown', function()
    return pane_lines('commits')[1] == 'Reported'
  end)
  toggle_in_pane()

  expect_pane_lines('commits', own_view(work))
end

--- The messages the child told through `vim.notify`.
---
---@return string[]
local function messages()
  return child.lua_get([[vim.tbl_map(function(told)
    return told.message
  end, _G.messages)]])
end

T['the view'] = MiniTest.new_set()

T['the view']['is kept on disk and shown again once aineo starts again'] = function()
  local state = fixture.directory('own-view-kept-state')
  local work = start_on_own_branch('own-view-kept', false, state)
  enter_on_line(3)
  expect_pane_lines('commits', own_view(work))

  git_repo.start_editor(child)
  child.lua(HOME)
  child.lua('_G.start_copy(...)', { work.top })
  follow(state)

  expect_pane_lines('commits', own_view(work))
  expect_pane_lines('files', {
    ('Files in: Worktree %s (feature/own) · yours'):format(work.folder),
    '  A branch.txt',
  })
end

T['the view']['chooses its whole change once the commit chosen in it is gone after an amend'] = function()
  local work = start_on_own_branch('own-view-amend')
  enter_on_line(3)
  expect_pane_lines('commits', own_view(work))
  enter_window_of('commits')
  child.type_keys('3G')
  git_repo.wait_until('the commit chosen', function()
    return vim.startswith(pane_lines('files')[1], 'Files in: ' .. short(work.on_branch))
  end)

  git_repo.git(work.top, { 'commit', '--quiet', '--amend', '--message', 'On the branch, amended' })
  child.lua("require('aineo.changes').refresh_shown_pane()")

  local heading = ('Files in: Worktree %s (feature/own) · yours'):format(work.folder)
  git_repo.wait_until('the whole change chosen', function()
    return pane_lines('files')[1] == heading
  end)
end

T['the view']['ends once the editor’s own worktree has another branch checked out, the default view shown and told'] = function()
  local work = start_on_own_branch('own-view-checkout')
  enter_on_line(3)
  expect_pane_lines('commits', own_view(work))

  git_repo.git(work.top, { 'checkout', '--quiet', 'main' })
  child.lua("require('aineo.changes').refresh_shown_pane()")

  git_repo.wait_until('the default view shown', function()
    return pane_lines('commits')[1] == 'Reported'
  end)
  eq(messages(), {
    ('aineo: Worktree %s (feature/own) · yours is gone; the changes pane shows the default view'):format(
      work.folder
    ),
  })
end

return T
