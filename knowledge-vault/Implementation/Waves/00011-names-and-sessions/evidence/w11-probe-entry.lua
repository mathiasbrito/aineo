-- Wave 11 planning probe P2: Enter on a file in the changes pane, through
-- the whole plugin (`:Aineo open`, the fake `claude`, the layout's file
-- column, `\pc`), for names that hold a space, an apostrophe, a tab, a
-- double quote, a non-ASCII letter, a glob character, and a plain control.
-- Run as a test file from the checkout's root, after `make deps`, from a
-- path the runner collects and git ignores (never committed under tests/):
--   mkdir -p .tests/w11-probe
--   cp <this file> .tests/w11-probe/test_w11_probe_entry.lua
--   make test_file FILE=.tests/w11-probe/test_w11_probe_entry.lua
-- Each case prints what the files window lists, what the windows show after
-- Enter, the first lines of the current window, and what aineo told.
local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      entry.restart(child)
    end,
    post_once = child.stop,
  },
})

local FILES = 'aineo://changes-files'

--- The lines of the child's files buffer, found by exact name.
local function files_lines()
  return child.lua_get(
    [[(function(name)
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(b) == name then
          return vim.api.nvim_buf_get_lines(b, 0, -1, true)
        end
      end
      return {}
    end)(...)]],
    { FILES }
  )
end

local NAMES = {
  control = 'plain.md',
  idea = "knowledge-vault/Ideas/The changes pane follows the agents' worktrees.md",
  space = 'has space.txt',
  tab = 'tab\there.txt',
  quote = 'say "hi".txt',
  accent = 'café.md',
  glob = '[x].md',
}

for label, path in pairs(NAMES) do
  T['enter on ' .. label] = function()
    local name = 'changespane-w11-' .. label
    local top = git_repo.create(name, { ['base.txt'] = { 'base' } })
    child.lua('for k, v in pairs(...) do vim.env[k] = v end', { git_repo.ENVIRONMENT })
    child.cmd('cd ' .. vim.fn.fnameescape(top))
    entry.use_fake(child, claude_session.fake(name, 'ready'))
    child.cmd('Aineo open')
    vim.wait(3000, function()
      return false
    end, 50)
    git_repo.write(top, path, { 'committed' })
    git_repo.commit_all(top, 'add ' .. label)
    git_repo.write(top, path, { 'committed', 'edited' })
    entry.press(child, '\\pc')
    git_repo.wait_until('the file listed', function()
      local first = files_lines()[1]
      return first ~= nil and first:match('^. [AM] ') ~= nil
    end)
    child.lua(
      [[for _, w in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)) == ... then
            vim.api.nvim_set_current_win(w)
            vim.api.nvim_win_set_cursor(w, { 1, 0 })
          end
        end]],
      { FILES }
    )
    entry.press(child, '<CR>')
    vim.wait(15000, function()
      return entry.current_window(child) ~= FILES or #entry.messages(child) > 0
    end, 50)
    print(
      ('\n[%s] files=%s\n  windows=%s\n  current=%s\n  current lines=%s\n  messages=%s'):format(
        label,
        vim.inspect(files_lines()),
        vim.inspect(entry.windows(child)),
        vim.inspect(entry.current_window(child)),
        vim.inspect(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, 8, false)')),
        vim.inspect(entry.messages(child))
      )
    )
  end
end

--- The same file, added in another worktree of the repository (D33): its
--- line is listed under that worktree's heading.
for label, path in pairs({ ['worktree idea'] = NAMES.idea, ['worktree control'] = 'plain.md' }) do
  T['enter on ' .. label] = function()
    local name = 'changespane-w11-' .. label:gsub(' ', '-')
    local top = git_repo.create(name, { ['base.txt'] = { 'base' } })
    local other = top .. '-agent'
    git_repo.git(top, { 'worktree', 'add', '-q', '-b', 'agent', other })
    child.lua('for k, v in pairs(...) do vim.env[k] = v end', { git_repo.ENVIRONMENT })
    child.cmd('cd ' .. vim.fn.fnameescape(top))
    entry.use_fake(child, claude_session.fake(name, 'ready'))
    child.cmd('Aineo open')
    vim.wait(3000, function()
      return false
    end, 50)
    git_repo.write(other, path, { 'committed' })
    git_repo.commit_all(other, 'add ' .. label)
    entry.press(child, '\\pc')
    local line
    git_repo.wait_until('the file listed', function()
      for number, text in ipairs(files_lines()) do
        if text:find(path:sub(-10), 1, true) then
          line = number
          return true
        end
      end
      return false
    end)
    child.lua(
      [[local name, line = ...
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)) == name then
            vim.api.nvim_set_current_win(w)
            vim.api.nvim_win_set_cursor(w, { line, 0 })
          end
        end]],
      { FILES, line }
    )
    entry.press(child, '<CR>')
    vim.wait(15000, function()
      return entry.current_window(child) ~= FILES or #entry.messages(child) > 0
    end, 50)
    print(
      ('\n[%s] files=%s\n  windows=%s\n  current lines=%s\n  messages=%s'):format(
        label,
        vim.inspect(files_lines()),
        vim.inspect(entry.windows(child)),
        vim.inspect(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, 8, false)')),
        vim.inspect(entry.messages(child))
      )
    )
  end
end

return T
