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

--- The Lua that begins the changes home's session in the child for the
--- directory `...` and shows the pane's two buffers there: the files buffer
--- in the current window, the commits buffer in a window below it. The home
--- is given no layout: a diff it shows is kept in `_G.shown_diffs` and shown
--- in a window of its own at the bottom.
local BEGIN_AND_SHOW = [[
  local directory = ...
  local changes = require('aineo.changes')
  _G.shown_diffs = {}
  changes.begin_session({
    directory = directory,
    show_diff = function(diff)
      table.insert(_G.shown_diffs, diff)
      return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
    end,
  })
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

--- Makes a repository whose base commit holds `notes.txt`, writes `files`
--- (path to lines) into its working tree, begins the session there with the
--- pane shown and waits for the files window to list `expected`. Returns the
--- top level.
---
---@param name string
---@param files table<string, string[]>
---@param expected string[] the files window's lines
---@return string top
local function pane_listing(name, files, expected)
  local top = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  for path, lines in pairs(files) do
    git_repo.write(top, path, lines)
  end
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(FILES, expected)
  return top
end

--- Makes a repository whose base commit holds `notes.txt`, writes the one
--- file `name` into its working tree, begins the session there with the pane
--- shown and waits for the files window to list it on its second line.
--- Returns the top level.
---
---@param case string the case's own name
---@param name string the one file's name
---@return string top
local function pane_listing_one_file(case, name)
  local top = git_repo.create(case, { ['notes.txt'] = { 'one' } })
  git_repo.write(top, name, { 'text' })
  child.lua(BEGIN_AND_SHOW, { top })
  git_repo.wait_until('the file listed', function()
    return (lines_of(FILES)[2] or ''):find('^  %? ') ~= nil
  end)
  return top
end

--- Puts the cursor on line `line` of the files window and presses `gf`
--- there.
---
---@param line integer
local function press_gf_on(line)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })
  child.lua('vim.api.nvim_win_set_cursor(0, { ..., 0 })', { line })
  child.type_keys('gf')
end

--- The name of the buffer in the child's current window.
---
---@return string
local function current_buffer_name()
  return child.lua_get('vim.api.nvim_buf_get_name(0)')
end

--- The Lua expression giving everything the child's messages hold.
local TOLD = "vim.api.nvim_exec2('messages', { output = true }).output"

T['gf'] = MiniTest.new_set()

T['gf']['opens the file whose name holds a space, which Vim’s own gf would cut at it'] = function()
  local top = pane_listing(
    'openfile-space',
    { ['has space.txt'] = { 'text' } },
    { 'Files in: Session work', '  ? has space.txt' }
  )

  press_gf_on(2)

  eq(current_buffer_name(), vim.fs.joinpath(top, 'has space.txt'))
end

--- The names of files whose characters Vim's own `gf`, a command line or a
--- wildcard would take for something else.
local AWKWARD_NAMES = {
  { 'an apostrophe', "it's.txt" },
  { 'a tab', 'a\tb.txt' },
  { 'a double quote', 'say "hi".txt' },
  { 'characters outside ASCII', 'café ✓.txt' },
  { 'a percent sign and a hash', '100% #1.txt' },
  { 'a bar', 'a|b.txt' },
  { 'wildcards', '[a]*?{b}.txt' },
  { 'a backslash', 'a\\b.txt' },
  { 'a line break', 'a\nb.txt' },
  { 'a leading plus', '+-x.txt' },
}

T['gf']['opens a file whose name holds'] = MiniTest.new_set({ parametrize = AWKWARD_NAMES })

T['gf']['opens a file whose name holds']['characters'] = function(_, name)
  local top = pane_listing_one_file('openfile-awkward', name)

  press_gf_on(2)

  eq(current_buffer_name(), vim.fs.joinpath(top, name))
end

T['gf']['on a deleted file opens nothing and says the file is gone'] = function()
  local top = pane_listing(
    'openfile-deleted',
    { ['notes.txt'] = { 'two' } },
    { 'Files in: Session work', '  M notes.txt' }
  )
  vim.fn.delete(vim.fs.joinpath(top, 'notes.txt'))
  expect_lines(FILES, { 'Files in: Session work', '  D notes.txt' })

  press_gf_on(2)

  eq(current_buffer_name(), FILES)
  eq(child.lua_get(TOLD), 'aineo: notes.txt is gone from the working tree')
end

T['gf']['on another worktree’s file opens nothing, not the editor’s file of that name, and says so'] = function()
  local top = git_repo.create('openfile-other-worktree', { ['notes.txt'] = { 'one' } })
  local agent = vim.fs.joinpath(vim.fs.dirname(top), 'agent')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'agent', agent })
  git_repo.write(top, 'same.txt', { 'mine' })
  git_repo.write(agent, 'same.txt', { 'theirs' })
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(
    FILES,
    { 'Files in: Session work', '  ? same.txt', 'Worktree agent (agent)', '  ? same.txt' }
  )

  press_gf_on(4)

  eq(current_buffer_name(), FILES)
  eq(child.lua_get(TOLD), "aineo: the changes pane opens no other worktree's file")
end

--- The lines of a files window that list no file, by what they are.
local LINES_LISTING_NO_FILE = {
  { 'the line naming the filter', 1 },
  { 'a note', 2 },
  { 'another worktree’s heading', 3 },
  { 'another worktree’s note', 4 },
}

T['gf']['on a line listing no file'] = MiniTest.new_set({ parametrize = LINES_LISTING_NO_FILE })

T['gf']['on a line listing no file']['opens nothing and says nothing'] = function(_, line)
  local top = git_repo.create('openfile-no-file', { ['notes.txt'] = { 'one' } })
  git_repo.git(
    top,
    { 'worktree', 'add', '--quiet', '-b', 'agent', vim.fs.joinpath(vim.fs.dirname(top), 'agent') }
  )
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(FILES, {
    'Files in: Session work',
    'No files changed on this session',
    'Worktree agent (agent)',
    'No files changed in this worktree',
  })

  press_gf_on(line)

  eq(current_buffer_name(), FILES)
  eq(child.lua_get(TOLD), '')
end

T['gf']['in the files buffer made anew opens the file as before'] = function()
  local top = pane_listing(
    'openfile-anew',
    { ['has space.txt'] = { 'text' } },
    { 'Files in: Session work', '  ? has space.txt' }
  )
  child.lua(
    [[
    vim.cmd('new')
    vim.cmd('bwipeout! ' .. vim.fn.bufnr(...))
    local pane = require('aineo.changes').pane_buffers()
    vim.api.nvim_win_set_buf(0, pane.files)
  ]],
    { FILES }
  )
  expect_lines(FILES, { 'Files in: Session work', '  ? has space.txt' })

  press_gf_on(2)

  eq(current_buffer_name(), vim.fs.joinpath(top, 'has space.txt'))
end

T['gf']['in any other buffer stays Vim’s own'] = function()
  local top = pane_listing(
    'openfile-other-buffer',
    { ['has space.txt'] = { 'text' } },
    { 'Files in: Session work', '  ? has space.txt' }
  )
  local notes = vim.fs.joinpath(top, 'notes.txt')
  child.cmd('new')
  child.lua('vim.api.nvim_buf_set_lines(0, 0, -1, true, { ... })', { notes })

  child.type_keys('gf')

  eq(current_buffer_name(), notes)
end

T['gf']['in the commits buffer stays Vim’s own'] = function()
  pane_listing(
    'openfile-commits',
    {},
    { 'Files in: Session work', 'No files changed on this session' }
  )
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { 'aineo://changes-commits' })
  child.lua('vim.api.nvim_win_set_cursor(0, { 2, 0 })')

  MiniTest.expect.error(function()
    child.type_keys('gf')
  end, 'E447')
end

T['gf']['in a diff buffer stays Vim’s own'] = function()
  pane_listing(
    'openfile-diff',
    { ['notes.txt'] = { 'two' } },
    { 'Files in: Session work', '  M notes.txt' }
  )
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })
  child.lua('vim.api.nvim_win_set_cursor(0, { 2, 0 })')
  child.type_keys('<CR>')
  git_repo.wait_until('the diff shown', function()
    return child.lua_get('#_G.shown_diffs') == 1
  end)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(_G.shown_diffs[1]))')
  child.lua('vim.api.nvim_win_set_cursor(0, { 1, 0 })')

  MiniTest.expect.error(function()
    child.type_keys('gf')
  end, 'E447')
end

return T
