--- Makes the files and directories a test hands to the code under test. They
--- live under `.tests/fixtures/`, outside `tests/`, so the suite's own
--- collection of `tests/**/test_*.lua` never picks them up — a fixture may fail
--- on purpose, or not even parse. `make_directory()` also makes the other
--- directories the suites share, wherever they are.

local M = {}

local CHECKOUT = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local FIXTURES = vim.fs.joinpath(CHECKOUT, '.tests', 'fixtures')

--- Makes the directory `path` and the directories leading to it, unless it
--- exists.
---
--- Test files run side by side, each in a Neovim of its own, and `mkdir()`
--- fails with E739 when another Neovim makes one of those directories at the
--- same moment, although the directory is then there. So it tries again, up
--- to once for each of the path's directories: each race lost means one more
--- of them exists.
---
--- Raises `mkdir()`'s error when the directory still cannot be made.
---
---@param path string an absolute path
function M.make_directory(path)
  local tries_left = #vim.split(path, '/', { trimempty = true })
  local made, failure = pcall(vim.fn.mkdir, path, 'p')
  while not made and tries_left > 0 do
    tries_left = tries_left - 1
    made, failure = pcall(vim.fn.mkdir, path, 'p')
  end
  if not made then
    error(failure, 0)
  end
end

--- The empty directory `.tests/fixtures/<name>`, emptied of whatever an
--- earlier run left there.
---
---@param name string
---@return string path the directory's absolute path
function M.directory(name)
  local path = vim.fs.joinpath(FIXTURES, name)
  if vim.uv.fs_stat(path) then
    assert(vim.fn.delete(path, 'rf') == 0, 'cannot remove ' .. path)
  end
  M.make_directory(path)
  return path
end

--- Writes `lines` to `.tests/fixtures/<name>`, replacing any earlier file
--- there and creating the directories `name` leads through.
---
--- The lines go to a file of this Neovim's own beside it first, which then
--- takes the name at once: test files run side by side, and some write the
--- same fixture, so a Neovim reading it while another writes it sees the one
--- file or the other whole, never one cut short.
---
---@param name string the file's path under `.tests/fixtures/`, such as `passing.lua`
---@param lines string[] the file's lines
---@return string path the file's absolute path
function M.write(name, lines)
  local path = vim.fs.joinpath(FIXTURES, name)
  local written = ('%s.%d.writing'):format(path, vim.fn.getpid())
  M.make_directory(vim.fs.dirname(path))
  assert(vim.fn.writefile(lines, written) == 0, 'cannot write ' .. written)
  assert(vim.uv.fs_rename(written, path))
  return path
end

return M
