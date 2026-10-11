-- Wave 11 planning probe P3: what Vim's own `gf` does on a line of the
-- changes pane's files window, on `origin/dev`, the working directory at the
-- repository's top level as Claude Code's is. Run from the checkout's root,
-- headless, its XDG data, state and cache and its log under .tests/:
--   nvim --clean --headless -l <this file> <empty scratch repository>
vim.opt.rtp:prepend(vim.fn.getcwd())
local repo = assert(_G.arg[1], 'usage: -l w11-probe-gf.lua <repository>')
vim.env.GIT_CONFIG_GLOBAL, vim.env.GIT_CONFIG_NOSYSTEM = '/dev/null', '1'
vim.env.GIT_AUTHOR_NAME, vim.env.GIT_AUTHOR_EMAIL = 'probe', 'probe@example.invalid'
vim.env.GIT_COMMITTER_NAME, vim.env.GIT_COMMITTER_EMAIL = 'probe', 'probe@example.invalid'

local function git(...)
  local result = vim.system({ 'git', '-C', repo, ... }, { text = true }):wait()
  assert(result.code == 0, table.concat({ ... }, ' ') .. ': ' .. result.stderr)
  return result.stdout
end

local function write(path, text)
  vim.fn.mkdir(vim.fs.dirname(repo .. '/' .. path), 'p')
  vim.fn.writefile({ text }, repo .. '/' .. path)
end

local function settle(ms)
  vim.wait(ms, function()
    return false
  end, 20)
end

write('base.txt', 'base')
git('add', '-A')
local tree = vim.trim(git('write-tree'))
git('update-ref', 'HEAD', vim.trim(git('commit-tree', tree, '-m', 'base')))
vim.cmd.cd(vim.fn.fnameescape(repo))

local changes = require('aineo.changes')
changes.begin_session({ directory = repo, show_diff = function() end })
settle(1500)
local NAMES = {
  'plain.md',
  'has space.txt',
  "knowledge-vault/Ideas/The changes pane follows the agents' worktrees.md",
  'café.md',
  'dir/sub.md',
}
for _, name in ipairs(NAMES) do
  write(name, 'new')
end

local pane = changes.pane_buffers()
vim.api.nvim_win_set_buf(0, pane.files)
changes.refresh_shown_pane()
settle(2500)
local files_window = vim.api.nvim_get_current_win()
print("'isfname' = " .. vim.o.isfname)
for number, line in ipairs(vim.api.nvim_buf_get_lines(pane.files, 0, -1, false)) do
  local path_column = 4
  for _, column in ipairs({ path_column, #line - 4 }) do
    vim.api.nvim_set_current_win(files_window)
    vim.api.nvim_win_set_buf(files_window, pane.files)
    vim.api.nvim_win_set_cursor(files_window, { number, column })
    local cfile = vim.fn.expand('<cfile>')
    local ok, failure = pcall(vim.cmd, 'normal! gf')
    print(
      ('|%s| cursor at byte %d: <cfile>=%q gf -> %s'):format(
        line,
        column,
        cfile,
        ok and ('opened ' .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':.'))
          or tostring(failure)
      )
    )
  end
end
vim.cmd('qall!')
