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

--- The Lua that begins the changes home's session in the child for the
--- directory `...`, with the git options that follow, and shows the pane's
--- two buffers there: the files buffer in the current window, the commits
--- buffer in a window below it. Every buffer the home asks to show as a diff
--- is kept in `_G.shown_diffs` and shown in a window of its own at the
--- bottom, the cursor left where it is.
local BEGIN_AND_SHOW = [[
  local directory, git_options = ...
  local changes = require('aineo.changes')
  _G.shown_diffs = {}
  changes.begin_session({
    directory = directory,
    git = git_options,
    show_diff = function(diff)
      table.insert(_G.shown_diffs, diff)
      local showing = vim.fn.bufwinid(diff)
      if showing ~= -1 then
        return showing
      end
      return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
    end,
  })
  local pane = changes.pane_buffers()
  vim.api.nvim_win_set_buf(0, pane.files)
  vim.api.nvim_open_win(pane.commits, false, { split = 'below' })
]]

--- Begins the session in the child for `directory` and shows the pane
--- (`BEGIN_AND_SHOW`).
---
---@param directory string
---@param git_options? table
local function begin_and_show(directory, git_options)
  child.lua(BEGIN_AND_SHOW, { directory, git_options })
end

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

--- Makes the directory `name` beside the repository at `top` a worktree of
--- it on the new branch `branch`, from `start_point` when given, and
--- returns the worktree's top level.
---
---@param top string
---@param name string
---@param branch string
---@param start_point? string
---@return string worktree
local function add_worktree(top, name, branch, start_point)
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), name)
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', branch, worktree, start_point })
  return worktree
end

T['the files window'] = MiniTest.new_set()

T['the files window']['lists the editor’s files first, as ever, then each other worktree’s under its heading'] = function()
  local top = git_repo.create('changesworktrees-files', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'agent.txt', { 'new' })

  begin_and_show(top)

  expect_lines(FILES, { '  M notes.txt', 'Worktree agent (agent)', '  ? agent.txt' })
end

T['the commits window'] = MiniTest.new_set()

T['the commits window']['lists the editor’s commits first, as ever, then each other worktree’s under its heading'] = function()
  local top = git_repo.create('changesworktrees-commits', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'agent.txt', { 'new' })
  local commit = git_repo.commit_all(agent, 'The agent’s')

  begin_and_show(top)

  expect_lines(COMMITS, {
    'No commits on this session',
    'Worktree agent (agent)',
    commit:sub(1, 7) .. ' The agent’s',
  })
end

return T
