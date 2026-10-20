local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that defines, in the child, `_G.start_copy(directory, settings)`:
--- it begins the changes home's session for `directory`, with `settings` more
--- of the session's settings when given, and shows its two buffers in a
--- tab page of its own, the files buffer in the tab's window, the commits
--- buffer in a window below it. `vim.ui.select` is replaced by a picker that
--- keeps every request in `_G.pickers`, answered by `_G.choose()`, and
--- `vim.notify` by one that keeps every message in `_G.messages`.
local PANE = [[
  _G.pickers, _G.messages = {}, {}
  vim.ui.select = function(items, options, on_choice)
    table.insert(_G.pickers, { items = items, options = options, on_choice = on_choice })
  end
  vim.notify = function(message, level)
    table.insert(_G.messages, { message = message, level = level })
  end
  _G.choose = function(position)
    local request = _G.pickers[#_G.pickers]
    request.on_choice(request.items[position])
  end
  _G.start_copy = function(directory, settings)
    local changes = require('aineo.changes')
    _G.home = changes
    changes.begin_session(vim.tbl_extend('force', {
      directory = directory,
      show_diff = function(diff)
        return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
      end,
    }, settings or {}))
    vim.cmd('tabnew')
    _G.pane = changes.pane_buffers()
    vim.api.nvim_win_set_buf(0, _G.pane.files)
    vim.api.nvim_open_win(_G.pane.commits, false, { split = 'below' })
  end
]]

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
      child.lua(PANE)
      child.fn.chdir(fixture.directory('edit-file-cwd'))
    end,
    post_once = child.stop,
  },
})

--- The lines of the buffer `which` of the pane.
---
---@param which 'files'|'commits'
---@return string[]
local function pane_lines(which)
  return child.lua_get('vim.api.nvim_buf_get_lines(_G.pane[...], 0, -1, true)', { which })
end

--- Waits until the buffer `which` of the pane holds `expected`, at most
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

--- The messages the child told through `vim.notify`.
---
---@return string[]
local function messages()
  return child.lua_get([[vim.tbl_map(function(told)
    return told.message
  end, _G.messages)]])
end

--- Makes the directory `name` beside the repository at `top` a worktree of
--- it on the new branch `branch`, and returns its top level, links resolved.
---
---@param top string
---@param name string
---@param branch string
---@return string worktree
local function add_worktree(top, name, branch)
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), name)
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', branch, worktree })
  return vim.uv.fs_realpath(worktree)
end

--- Writes `lines` as the file `path` under `top` and commits that file alone
--- as `subject`; returns the commit's full id.
---
---@param top string
---@param path string
---@param lines string[]
---@param subject string
---@return string
local function commit_only(top, path, lines, subject)
  git_repo.write(top, path, lines)
  git_repo.git(top, { 'add', '--', path })
  git_repo.git(top, { 'commit', '--quiet', '--message', subject })
  return git_repo.git(top, { 'rev-parse', 'HEAD' })
end

--- Makes the repository `name` with one commit, starts the changes home on
--- it, given `settings` more of the session's settings, with its pane shown,
--- and returns its top level.
---
---@param name string
---@param settings? table
---@return string top
local function start_on_repository(name, settings)
  local top = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  child.lua('_G.start_copy(...)', { top, settings })
  expect_pane_lines('commits', { 'Uncommitted', 'Session work', 'No commits on this session' })
  return top
end

--- Makes the files window the current window.
local function enter_files_window()
  child.lua('vim.api.nvim_set_current_win(vim.fn.win_findbuf(_G.pane.files)[1])')
end

--- Makes the commits window the current window.
local function enter_commits_window()
  child.lua('vim.api.nvim_set_current_win(vim.fn.win_findbuf(_G.pane.commits)[1])')
end

--- Picks, with `s`, the item at `position` of what it offers, the cursor in
--- the commits window, and waits until its picker opened.
---
---@param position integer
local function pick(position)
  local before = child.lua_get('#_G.pickers')
  enter_commits_window()
  child.lua("pcall(vim.api.nvim_feedkeys, 's', 'mx', false)")
  git_repo.wait_until('the picker opened', function()
    return child.lua_get('#_G.pickers') > before
  end)
  child.lua('_G.choose(...)', { position })
end

--- The line of the files window that lists a path ending with `suffix`.
---
---@param suffix string
---@return integer line
local function file_line(suffix)
  git_repo.wait_until(suffix .. ' listed', function()
    for _, line in ipairs(pane_lines('files')) do
      if vim.endswith(line, suffix) then
        return true
      end
    end
    return false
  end)
  for index, line in ipairs(pane_lines('files')) do
    if vim.endswith(line, suffix) then
      return index
    end
  end
end

--- Puts the cursor on line `line` of the files window and presses `keys`,
--- written as in a mapping, there. An error the keys raise is left to show in
--- the editor's messages, and in what the case asserts of its state, as a
--- user would see it.
---
---@param line integer
---@param keys string
local function press_on(line, keys)
  enter_files_window()
  child.lua('vim.api.nvim_win_set_cursor(0, { ..., 0 })', { line })
  child.lua("pcall(vim.api.nvim_feedkeys, vim.keycode(...), 'mx', false)", { keys })
end

--- Puts the cursor on line `line` of the files window and presses `<S-CR>`
--- there (`press_on()`).
---
---@param line integer
local function press_shift_enter_on(line)
  press_on(line, '<S-CR>')
end

--- The name of the buffer in the child's current window.
---
---@return string
local function current_buffer_name()
  return child.lua_get('vim.api.nvim_buf_get_name(0)')
end

--- Waits until the child's current buffer is named `name`, at most
--- `git_repo.PATIENCE_MS`, and asserts it.
---
---@param name string
local function expect_current_buffer(name)
  vim.wait(git_repo.PATIENCE_MS, function()
    return current_buffer_name() == name
  end, 10)
  eq(current_buffer_name(), name)
end

--- Makes `worktree` and the file `path` in it the state the cases open: the
--- file committed there as `committed`, then changed in the working tree to
--- `edited`; returns nothing.
---
---@param worktree string
---@param path string
---@param committed string
---@param edited string
local function commit_then_edit(worktree, path, committed, edited)
  commit_only(worktree, path, { committed }, 'Add ' .. path)
  git_repo.write(worktree, path, { edited })
end

T['edit_file_key'] = MiniTest.new_set()

T['edit_file_key']['opens the file as <S-CR> does: editable, in its worktree, the cursor in it in Normal mode'] = function()
  local top = start_on_repository('edit-key', { edit_file_key = '\\<CR>' })
  git_repo.write(top, 'notes.txt', { 'two' })
  expect_pane_lines('files', { 'Files in: Session work', '  M notes.txt' })

  press_on(2, '\\<CR>')

  expect_current_buffer(vim.fs.joinpath(vim.uv.fs_realpath(top), 'notes.txt'))
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), { 'two' })
  eq(child.lua_get('vim.bo.modifiable and vim.bo.buftype == ""'), true)
  eq(child.lua_get('vim.fn.mode()'), 'n')
  eq(messages(), {})
end

T['edit_file_key']['is the key the settings name, in the files buffer alone'] = function()
  start_on_repository('edit-key-custom', { edit_file_key = ',<CR>' })

  eq(child.lua_get('vim.fn.maparg(..., "n", false, true).buffer', { ',<CR>' }), 1)
  eq(child.lua_get('vim.fn.maparg(..., "n")', { '\\<CR>' }), '')
  enter_commits_window()
  eq(child.lua_get('vim.fn.maparg(..., "n")', { ',<CR>' }), '')
end

T['edit_file_key']['maps nothing when the settings name none; <S-CR> stays'] = function()
  start_on_repository('edit-key-none')

  eq(child.lua_get('vim.fn.maparg(..., "n")', { '\\<CR>' }), '')
  eq(child.lua_get('vim.fn.maparg(..., "n", false, true).buffer', { '<S-CR>' }), 1)
end

T['<S-CR>'] = MiniTest.new_set()

T['<S-CR>']["opens the file as it is in the editor's own worktree, editable, the cursor in it in Normal mode"] = function()
  local top = start_on_repository('edit-own')
  git_repo.write(top, 'notes.txt', { 'two' })
  expect_pane_lines('files', { 'Files in: Session work', '  M notes.txt' })

  press_shift_enter_on(2)

  expect_current_buffer(vim.fs.joinpath(vim.uv.fs_realpath(top), 'notes.txt'))
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), { 'two' })
  eq(child.lua_get('vim.bo.modifiable and vim.bo.buftype == ""'), true)
  eq(child.lua_get('vim.fn.mode()'), 'n')
  eq(messages(), {})
end

T['<S-CR>']['on a file listed under a commit of the editor’s own opens the working tree’s file, not the commit’s'] = function()
  local top = start_on_repository('edit-own-commit')
  local commit = commit_only(top, 'notes.txt', { 'committed' }, 'Change notes')
  git_repo.write(top, 'notes.txt', { 'now' })
  child.lua('_G.home.refresh_shown_pane()')
  expect_pane_lines('commits', {
    'Uncommitted',
    'Session work',
    git_repo.commit_line(commit, 'Change notes'),
  })
  enter_commits_window()
  child.type_keys('3G')
  expect_pane_lines(
    'files',
    { 'Files in: ' .. git_repo.commit_line(commit, 'Change notes'), '  M notes.txt' }
  )

  press_shift_enter_on(2)

  expect_current_buffer(vim.fs.joinpath(vim.uv.fs_realpath(top), 'notes.txt'))
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), { 'now' })
end

T['<S-CR>']['on a file deleted from the own worktree opens nothing and says it is gone'] = function()
  local top = start_on_repository('edit-own-deleted')
  git_repo.write(top, 'notes.txt', { 'two' })
  expect_pane_lines('files', { 'Files in: Session work', '  M notes.txt' })
  vim.fn.delete(vim.fs.joinpath(top, 'notes.txt'))
  expect_pane_lines('files', { 'Files in: Session work', '  D notes.txt' })

  press_shift_enter_on(2)

  eq(current_buffer_name():find('changes%-files') ~= nil, true)
  eq(messages(), { 'aineo: notes.txt is gone from the working tree' })
end

T['<S-CR>']['opens the file as it is now in the worktree picked, which :w writes into'] = function()
  local top = start_on_repository('edit-worktree')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  commit_then_edit(agent, 'a.txt', 'committed', 'edited')
  child.lua('_G.home.refresh_shown_pane()')
  git_repo.wait_until('the worktree listed', function()
    return #pane_lines('commits') > 3
  end)
  pick(1)
  local line = file_line('a.txt')

  press_shift_enter_on(line)

  expect_current_buffer(vim.fs.joinpath(agent, 'a.txt'))
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), { 'edited' })
  eq(child.lua_get('vim.fn.mode()'), 'n')
  child.lua('vim.api.nvim_buf_set_lines(0, 0, -1, false, { "saved" })')
  child.cmd('write')
  eq(vim.fn.readfile(vim.fs.joinpath(agent, 'a.txt')), { 'saved' })
  eq(vim.uv.fs_stat(vim.fs.joinpath(top, 'a.txt')), nil)
  eq(messages(), {})
end

T['<S-CR>']['on a file deleted from the worktree picked opens nothing and says it is gone'] = function()
  local top = start_on_repository('edit-worktree-deleted')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  commit_only(agent, 'a.txt', { 'committed' }, 'Add a.txt')
  child.lua('_G.home.refresh_shown_pane()')
  git_repo.wait_until('the worktree listed', function()
    return #pane_lines('commits') > 3
  end)
  pick(1)
  local line = file_line('a.txt')
  vim.fn.delete(vim.fs.joinpath(agent, 'a.txt'))

  press_shift_enter_on(line)

  eq(current_buffer_name():find('changes%-files') ~= nil, true)
  eq(messages(), { 'aineo: a.txt is gone from the working tree' })
end

--- Names whose characters a command line, `gf` or a wildcard would take for
--- something else.
local AWKWARD_NAMES = {
  { 'a space', 'has space.txt' },
  { 'a double quote', 'say "hi".txt' },
  { 'wildcards', '[a]*?{b}.txt' },
  { 'a backtick command', '`touch pwned`' },
  { 'a percent sign and a hash', '100% #1.txt' },
}

T['<S-CR> on a file whose name holds'] = MiniTest.new_set({ parametrize = AWKWARD_NAMES })

T['<S-CR> on a file whose name holds']['opens it in the worktree picked, the path taken whole'] = function(
  _,
  name
)
  local top = start_on_repository('edit-awkward')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  commit_only(agent, name, { 'text' }, 'Add the file')
  child.lua('_G.home.refresh_shown_pane()')
  git_repo.wait_until('the worktree listed', function()
    return #pane_lines('commits') > 3
  end)
  pick(1)
  git_repo.wait_until('the file listed', function()
    local listed = pane_lines('files')
    return listed[1] == 'Files in: Worktree agent-1 (feature/a)' and #listed == 2
  end)

  press_shift_enter_on(2)

  expect_current_buffer(vim.fs.joinpath(agent, name))
  eq(vim.uv.fs_stat(vim.fs.joinpath(agent, 'pwned')), nil)
  eq(vim.uv.fs_stat(vim.fs.joinpath(child.fn.getcwd(), 'pwned')), nil)
end

--- Makes the local branch `name` in the repository at `top`, holding one
--- commit that adds `branch.txt`, checked out in no worktree; returns the
--- branch's tip.
---
---@param top string
---@param name string
---@return string tip
local function add_branch(top, name)
  local making = add_worktree(top, 'making-' .. name:gsub('/', '-'), name)
  local tip = commit_only(making, 'branch.txt', { 'committed' }, 'Work ' .. name)
  git_repo.git(top, { 'worktree', 'remove', '--force', making })
  return tip
end

--- Makes the repository `name` with the worktree `agent-1` and the branch
--- `feature/p`, checked out nowhere, waits until the commits window lists
--- the worktree, shows the branch alone with `s`, and waits until the files
--- window lists its file. Returns the top level and the branch's tip.
---
---@param name string
---@return string top
---@return string tip
local function start_with_branch_shown_alone(name)
  local top = start_on_repository(name)
  add_worktree(top, 'agent-1', 'feature/a')
  local tip = add_branch(top, 'feature/p')
  child.lua('_G.home.refresh_shown_pane()')
  git_repo.wait_until('the worktree listed', function()
    return #pane_lines('commits') > 3
  end)
  pick(2)
  expect_pane_lines('commits', { 'Branch feature/p', git_repo.commit_line(tip, 'Work feature/p') })
  git_repo.wait_until('the branch file listed', function()
    return vim.tbl_contains(pane_lines('files'), '  A branch.txt')
  end)
  return top, tip
end

T['<S-CR>']['opens the file as it is now in the worktree where the branch picked is checked out'] = function()
  local top = start_with_branch_shown_alone('edit-branch-checked-out')
  local checkout = vim.fs.joinpath(vim.fs.dirname(top), 'checkout-p')
  git_repo.git(top, { 'worktree', 'add', '--quiet', checkout, 'feature/p' })
  git_repo.write(checkout, 'branch.txt', { 'live' })

  press_shift_enter_on(file_line('branch.txt'))

  expect_current_buffer(vim.fs.joinpath(vim.uv.fs_realpath(checkout), 'branch.txt'))
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), { 'live' })
  child.lua('vim.api.nvim_buf_set_lines(0, 0, -1, false, { "saved" })')
  child.cmd('write')
  eq(vim.fn.readfile(vim.fs.joinpath(checkout, 'branch.txt')), { 'saved' })
  eq(vim.uv.fs_stat(vim.fs.joinpath(top, 'branch.txt')), nil)
  eq(messages(), {})
end

--- Makes the repository `name` with the worktree `agent-1` and the branch
--- `feature/p`, which `make_branch` fills, checked out nowhere, waits until
--- the commits window lists the worktree, shows the branch alone with `s`
--- and waits until the commits window heads the branch.
---
---@param name string
---@param make_branch fun(top: string, branch: string) makes the branch's commits, in a worktree of its own it leaves
---@return string top
local function start_with_made_branch_shown_alone(name, make_branch)
  local top = start_on_repository(name)
  add_worktree(top, 'agent-1', 'feature/a')
  local making = add_worktree(top, 'making-p', 'feature/p')
  make_branch(making, 'feature/p')
  git_repo.git(top, { 'worktree', 'remove', '--force', making })
  child.lua('_G.home.refresh_shown_pane()')
  git_repo.wait_until('the worktree listed', function()
    return #pane_lines('commits') > 3
  end)
  pick(2)
  git_repo.wait_until('the branch shown', function()
    return pane_lines('commits')[1] == 'Branch feature/p'
  end)
  return top
end

T['<S-CR>']['on a file the branch tip no longer has tells once that it was deleted, not that it is shown'] = function()
  start_with_made_branch_shown_alone('edit-branch-deleted-at-tip', function(making)
    commit_only(making, 'branch.txt', { 'first' }, 'Add branch.txt')
    git_repo.git(making, { 'rm', '--quiet', 'branch.txt' })
    git_repo.git(making, { 'commit', '--quiet', '--message', 'Remove branch.txt' })
  end)
  enter_commits_window()
  child.type_keys('3G')
  git_repo.wait_until('the older commit’s files listed', function()
    local listed = pane_lines('files')
    return listed[1] ~= 'Files in: Branch feature/p' and #listed > 1
  end)

  press_shift_enter_on(file_line('branch.txt'))

  git_repo.wait_until('the failure told', function()
    return vim.iter(messages()):any(function(told)
      return told:find('was deleted', 1, true) ~= nil
    end)
  end)
  eq(messages(), { 'aineo: branch.txt was deleted in the branch feature/p' })
  eq(current_buffer_name(), 'aineo://changes-files')
end

T['<S-CR>']['on a file the branch deletes tells once that it was deleted, not that it is shown'] = function()
  start_with_made_branch_shown_alone('edit-branch-deletes', function(making)
    git_repo.git(making, { 'rm', '--quiet', 'notes.txt' })
    git_repo.git(making, { 'commit', '--quiet', '--message', 'Remove notes.txt' })
  end)

  press_shift_enter_on(file_line('notes.txt'))

  git_repo.wait_until('the failure told', function()
    return vim.iter(messages()):any(function(told)
      return told:find('was deleted', 1, true) ~= nil
    end)
  end)
  eq(messages(), { 'aineo: notes.txt was deleted in the branch feature/p' })
  eq(current_buffer_name(), 'aineo://changes-files')
end

T['<S-CR>']['on a file of a branch checked out nowhere shows the branch tip, read-only, and says so once'] = function()
  local _, tip = start_with_branch_shown_alone('edit-branch-nowhere')

  press_shift_enter_on(file_line('branch.txt'))

  expect_current_buffer('aineo://show/' .. tip .. '/branch.txt')
  eq(child.lua_get('vim.bo.modifiable'), false)
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), { 'committed' })
  eq(messages(), {
    "aineo: the branch feature/p is checked out in no worktree, so branch.txt cannot be edited; it is shown as the branch's tip has it",
  })
end

T['<S-CR>']['opens the file in the editor’s own worktree when it has checked out the branch picked since'] = function()
  local top = start_with_branch_shown_alone('edit-branch-own')
  git_repo.git(top, { 'switch', '--quiet', 'feature/p' })
  git_repo.write(top, 'branch.txt', { 'live' })

  press_shift_enter_on(file_line('branch.txt'))

  expect_current_buffer(vim.fs.joinpath(vim.uv.fs_realpath(top), 'branch.txt'))
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), { 'live' })
  eq(messages(), {})
end

T['<S-CR>']['on a file of a branch opens nothing and tells why when the worktrees cannot be listed'] = function()
  start_with_branch_shown_alone('edit-branch-unlisted')
  child.lua([[
    require('aineo.git').list_worktrees = function(_, done)
      done({ reason = 'failed', message = 'no worktrees' })
    end
  ]])

  press_shift_enter_on(file_line('branch.txt'))

  git_repo.wait_until('the failure told', function()
    return #messages() > 0
  end)
  eq(messages(), { 'aineo: the worktrees could not be listed: no worktrees' })
  eq(current_buffer_name(), 'aineo://changes-files')
end

T['<S-CR>']['on a file under a commit of a branch checked out nowhere shows the branch tip, not that commit'] = function()
  local top, first = start_with_branch_shown_alone('edit-branch-commit')
  local making = vim.fs.joinpath(vim.fs.dirname(top), 'making-later')
  git_repo.git(top, { 'worktree', 'add', '--quiet', making, 'feature/p' })
  local tip = commit_only(making, 'branch.txt', { 'later' }, 'Later work')
  git_repo.git(top, { 'worktree', 'remove', '--force', making })
  child.lua('_G.home.refresh_shown_pane()')
  expect_pane_lines('commits', {
    'Branch feature/p',
    git_repo.commit_line(tip, 'Later work'),
    git_repo.commit_line(first, 'Work feature/p'),
  })
  enter_commits_window()
  child.type_keys('3G')
  git_repo.wait_until('the first commit’s files listed', function()
    return vim.startswith(pane_lines('files')[1] or '', 'Files in: ' .. first:sub(1, 7))
  end)

  press_shift_enter_on(file_line('branch.txt'))

  expect_current_buffer('aineo://show/' .. tip .. '/branch.txt')
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), { 'later' })
  eq(child.lua_get('vim.bo.modifiable'), false)
end

--- The Lua that makes the git home's listing of the worktrees wait until
--- `_G.release_listing()`, then answer as it would, and sets
--- `_G.listing_answered` once what asked has run.
local HOLD_WORKTREE_LISTING = [[
  local git = require('aineo.git')
  local list_worktrees = git.list_worktrees
  git.list_worktrees = function(found, done, options)
    _G.release_listing = function()
      list_worktrees(found, function(...)
        done(...)
        _G.listing_answered = true
      end, options)
    end
  end
]]

--- Releases the listing `HOLD_WORKTREE_LISTING` holds and waits until what
--- asked for it has run, at most `git_repo.PATIENCE_MS`.
local function release_listing()
  child.lua('_G.release_listing()')
  git_repo.wait_until('the worktrees listed', function()
    return child.lua_get('_G.listing_answered') == true
  end)
end

T['<S-CR>']['on a file of a branch gives way to a key pressed while git lists the worktrees'] = function()
  start_with_branch_shown_alone('edit-branch-keys')
  child.lua(HOLD_WORKTREE_LISTING)
  local line = file_line('branch.txt')
  press_shift_enter_on(line)

  child.type_keys('l')
  release_listing()

  eq(current_buffer_name(), 'aineo://changes-files')
  eq(messages(), {})
end

T['<S-CR>']['on a file of a branch opens nothing when the cursor left the window before git listed the worktrees'] = function()
  start_with_branch_shown_alone('edit-branch-left')
  child.lua(HOLD_WORKTREE_LISTING)
  press_shift_enter_on(file_line('branch.txt'))

  enter_commits_window()
  release_listing()

  eq(child.lua_get('vim.api.nvim_buf_get_name(0)'), 'aineo://changes-commits')
  eq(messages(), {})
end

return T
