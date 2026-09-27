--- Makes the files and directories a test hands to the code under test. They
--- live under `.tests/fixtures/`, outside `tests/`, so the suite's own
--- collection of `tests/**/test_*.lua` never picks them up — a fixture may fail
--- on purpose, or not even parse.

local M = {}

local CHECKOUT = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local FIXTURES = vim.fs.joinpath(CHECKOUT, '.tests', 'fixtures')

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
  vim.fn.mkdir(path, 'p')
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
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  assert(vim.fn.writefile(lines, written) == 0, 'cannot write ' .. written)
  assert(vim.uv.fs_rename(written, path))
  return path
end

return M
