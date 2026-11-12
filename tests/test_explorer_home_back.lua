local MiniTest = require('mini.test')
local fake_explorer = dofile('tests/helpers/fake_explorer.lua')
local footer = dofile('tests/helpers/explorer_footer.lua')

local eq = MiniTest.expect.equality

--- The files of the repository the cases follow in, Claude's folder: a file
--- in a folder below the top, and a top-level one.
local FILES = { 'deep/inner/target.txt', 'top.txt' }

local world
local explorer
local worktree

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      worktree = vim.fn.tempname()
      vim.fn.mkdir(worktree, 'p')
      vim.fn.writefile({ 'one' }, vim.fs.joinpath(worktree, 'feature.txt'))
      world = fake_explorer.new_world({
        files = FILES,
        focused_work = { top = worktree, heading = 'Worktree feature (feature)' },
      })
      explorer = fake_explorer.new(world)
      vim.cmd('only')
      vim.api.nvim_win_set_buf(0, explorer.buffer())
    end,
    post_case = function()
      explorer.let_go()
      vim.fn.delete(worktree, 'rf')
    end,
  },
})

--- The lines of the explorer's buffer.
---
---@return string[]
local function shown_lines()
  return vim.api.nvim_buf_get_lines(explorer.made_buffer(), 0, -1, false)
end

--- The line of the explorer's buffer that ends with `text`, from 1, or nil.
---
---@param text string
---@return integer|nil
local function line_ending_with(text)
  for line, shown in ipairs(shown_lines()) do
    if vim.endswith(shown, text) then
      return line
    end
  end
  return nil
end

--- Whether the footer of the first window showing the explorer names the
--- worktree.
---
---@return boolean
local function shows_the_worktree()
  local window = vim.fn.win_findbuf(explorer.made_buffer())[1]
  return vim.startswith(footer.lines(window)[1], 'Worktree feature (feature)')
end

--- The highlight groups of the lines of the explorer's buffer that carry a
--- whole-line highlight, by the text they end with.
---
---@param text string
---@return boolean
local function line_is_followed(text)
  local line = line_ending_with(text)
  local namespace = vim.api.nvim_get_namespaces()['aineo.explorer']
  local marks = vim.api.nvim_buf_get_extmarks(
    explorer.made_buffer(),
    namespace,
    { line - 1, 0 },
    { line - 1, 0 },
    { details = true }
  )
  return vim.iter(marks):any(function(mark)
    return mark[4].line_hl_group == 'AineoExplorerFollowed'
  end)
end

T['shown_folder()'] = MiniTest.new_set()

T['shown_folder()']['gives the worktree the changes pane shows alone'] = function()
  local folder
  explorer.shown_folder(function(directory)
    folder = directory
  end)

  eq(folder, worktree)
end

T['shown_folder()']['gives the folder Claude works in for the default view'] = function()
  world.focused_work = nil
  local folder
  explorer.shown_folder(function(directory)
    folder = directory
  end)

  eq(folder, '/repo')
end

T['a file of the folder Claude works in'] = MiniTest.new_set()

T['a file of the folder Claude works in']['followed while a worktree shows takes the explorer back to that folder'] = function()
  eq(shows_the_worktree(), true)

  local followed = explorer.follow('/repo/deep/inner/target.txt')

  eq(followed, true)
  eq(shows_the_worktree(), false)
  eq(line_ending_with('target.txt') ~= nil, true)
  eq(line_is_followed('target.txt'), true)
end

T['a file of the folder Claude works in']['followed leaves the cursor of every window where it is'] = function()
  local window = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(window, { 1, 0 })

  explorer.follow('/repo/deep/inner/target.txt')

  eq(vim.api.nvim_win_get_cursor(window)[1], 1)
end

T['a file of the folder Claude works in']['revealed while a worktree shows puts the cursors of the explorer windows on its line'] = function()
  local explorer_window = vim.api.nvim_get_current_win()
  vim.cmd('botright split')
  local other = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(other, explorer.made_buffer())
  vim.cmd('botright new')
  local current = vim.api.nvim_get_current_win()

  explorer.reveal('/repo/deep/inner/target.txt')

  local line = line_ending_with('target.txt')
  eq(line ~= nil, true)
  eq({
    vim.api.nvim_win_get_cursor(explorer_window)[1],
    vim.api.nvim_win_get_cursor(other)[1],
    vim.api.nvim_get_current_win(),
  }, { line, line, current })
end

T['a file of the folder Claude works in']['followed asks the folder shown for Claude’s'] = function()
  explorer.follow('/repo/top.txt')
  local folder
  explorer.shown_folder(function(directory)
    folder = directory
  end)

  eq(folder, '/repo')
end

T['a file of the folder Claude works in']['followed holds the default view across reads of the tree'] = function()
  explorer.follow('/repo/top.txt')

  explorer.refresh()

  eq(shows_the_worktree(), false)
end

T['a change of the focused work'] = MiniTest.new_set()

T['a change of the focused work']['makes the explorer show the focused work again'] = function()
  explorer.follow('/repo/top.txt')
  eq(shows_the_worktree(), false)

  explorer.follow_focused_work()

  eq(shows_the_worktree(), true)
end

T['a file outside both folders'] = MiniTest.new_set()

T['a file outside both folders']['changes nothing, followed or revealed'] = function()
  local window = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(window, { 1, 0 })
  local before = shown_lines()

  local followed = explorer.follow('/elsewhere/file.txt')
  explorer.reveal('/elsewhere/file.txt')

  eq(followed, false)
  eq(shown_lines(), before)
  eq(vim.api.nvim_win_get_cursor(window)[1], 1)
end

T['a file in the folder the explorer shows'] = MiniTest.new_set()

T['a file in the folder the explorer shows']['stays where it is, the worktree shown'] = function()
  explorer.follow(vim.fs.joinpath(worktree, 'feature.txt'))

  eq(shows_the_worktree(), true)
  eq(line_is_followed('feature.txt'), true)
end

return T
