-- Wave 11 planning probe P1: which file names open from the changes pane's
-- files window, on `origin/dev`, through the changes home alone (no layout:
-- the probe's own `show_diff` opens a split). Run from the checkout's root,
-- headless, with an empty scratch repository made under .tests/ by
-- `git init`, and XDG_DATA_HOME, XDG_STATE_HOME, XDG_CACHE_HOME and
-- NVIM_LOG_FILE pointed under .tests/:
--   nvim --clean --headless -l <this file> <empty scratch repository>
-- The probe makes the session's base, one commit with `has space.txt` and
-- `old name.md`, through git's plumbing, begins the changes session there,
-- then makes the session's changes and presses Enter on every file line.
vim.opt.rtp:prepend(vim.fn.getcwd())
local repo = assert(_G.arg[1], 'usage: -l w11-probe-names.lua <repository>')
vim.env.GIT_CONFIG_GLOBAL, vim.env.GIT_CONFIG_NOSYSTEM = '/dev/null', '1'
vim.env.GIT_AUTHOR_NAME, vim.env.GIT_AUTHOR_EMAIL = 'probe', 'probe@example.invalid'
vim.env.GIT_COMMITTER_NAME, vim.env.GIT_COMMITTER_EMAIL = 'probe', 'probe@example.invalid'

local function git(...)
  local result = vim.system({ 'git', '-C', repo, ... }, { text = true }):wait()
  assert(result.code == 0, table.concat({ ... }, ' ') .. ': ' .. result.stderr)
  return result.stdout
end

--- Records the index as a new commit on HEAD, through git's plumbing.
local function record(message)
  local tree = vim.trim(git('write-tree'))
  local parent = vim.system({ 'git', '-C', repo, 'rev-parse', '--verify', '-q', 'HEAD' }):wait()
  local made = parent.code == 0
      and vim.trim(git('commit-tree', tree, '-p', vim.trim(parent.stdout), '-m', message))
    or vim.trim(git('commit-tree', tree, '-m', message))
  git('update-ref', 'HEAD', made)
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

write('has space.txt', 'base')
write('old name.md', 'old')
git('add', '-A')
record('base')

local messages = {}
vim.notify = function(message, level)
  table.insert(messages, ('[%s] %s'):format(level, message))
end

local changes = require('aineo.changes')
local shown = {}
changes.begin_session({
  directory = repo,
  show_diff = function(diff)
    table.insert(shown, vim.api.nvim_buf_get_name(diff))
    return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
  end,
})
settle(2000)

local IDEA = "knowledge-vault/Ideas/The changes pane follows the agents' worktrees.md"
write(IDEA, 'idea')
git('add', '--', IDEA)
record('add the idea')
write('has space.txt', 'changed')
write("untracked it's.md", 'new')
write('tab\there.txt', 'new')
write('say "hi".txt', 'new')
write('café.md', 'new')
write('plain.md', 'new')
write('star*.md', 'new')
write('[x].md', 'new')
git('mv', 'old name.md', 'new name.md')
write('committed [y].md', 'c')
git('add', '--', 'committed [y].md')
record('glob name')
write('committed [y].md', 'c changed')
write('committed y.md', 'decoy')
git('add', '--', 'committed y.md')
record('decoy')
write('committed y.md', 'decoy changed')

local pane = changes.pane_buffers()
vim.api.nvim_win_set_buf(0, pane.files)
changes.refresh_shown_pane()
settle(3000)

local lines = vim.api.nvim_buf_get_lines(pane.files, 0, -1, false)
print('files window:')
for number, line in ipairs(lines) do
  print(('  %2d |%s|'):format(number, line))
end
print('Enter on each file line:')
local files_window = vim.fn.bufwinid(pane.files)
for number, line in ipairs(lines) do
  if line:match('^. %a ') or line:match('^. %? ') then
    messages, shown = {}, {}
    vim.api.nvim_set_current_win(files_window)
    vim.api.nvim_win_set_cursor(0, { number, 0 })
    vim.fn.maparg('<CR>', 'n', false, true).callback()
    vim.wait(3000, function()
      return #shown > 0 or #messages > 0
    end, 20)
    local text = {}
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if shown[1] and vim.api.nvim_buf_get_name(buffer) == shown[1] then
        text = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
      end
    end
    print(('  line %d |%s|'):format(number, line))
    print('    shown:    ' .. vim.inspect(shown))
    print('    messages: ' .. vim.inspect(messages))
    print('    diff:     ' .. vim.inspect(text))
  end
end
vim.cmd('qall!')
