--- The files not on disk yet that code is proposed for: each is written,
--- with its missing folders and the files written beside it, when the user
--- first accepts code in it, and never before.

local M = {}

--- The files written beside each buffer's file, by buffer, for the buffers
--- whose file is written once code is first accepted in it.
---@type table<integer, string[]>
local expected = {}

--- Has the file of `buffer`, which is not on disk, written when code is
--- first accepted in it (`write_if_expected()`), with `companions`, the
--- absolute paths of files written beside it, each empty, when missing.
---
---@param buffer integer
---@param companions string[]
function M.expect(buffer, companions)
  expected[buffer] = companions
end

--- Writes `path` empty, with its missing folders, unless it is on disk.
---
---@param path string
local function write_empty(path)
  if vim.uv.fs_stat(path) then
    return
  end
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile({}, path)
end

--- Writes the file of `buffer` when it was expected (`expect()`) and is
--- still not on disk, with its missing folders and its companions, then
--- forgets it; tells the user, once, what was written, or why it could
--- not be. A buffer not expected, or whose file is on disk by then, is
--- left as it is.
---
---@param buffer integer
function M.write_if_expected(buffer)
  local companions = expected[buffer]
  expected[buffer] = nil
  local path = vim.api.nvim_buf_get_name(buffer)
  if not companions or vim.uv.fs_stat(path) then
    return
  end
  local written, problem = pcall(function()
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    vim.api.nvim_buf_call(buffer, function()
      vim.cmd('silent keepalt write')
    end)
    vim.tbl_map(write_empty, companions)
  end)
  if not written then
    vim.notify(
      ('aineo: %s could not be written: %s'):format(path, tostring(problem)),
      vim.log.levels.ERROR
    )
    return
  end
  vim.notify(
    ('aineo: %s written, a new file'):format(vim.fn.fnamemodify(path, ':~:.')),
    vim.log.levels.INFO
  )
end

--- Forgets `buffer`, whose file is then never written by `write_if_expected()`.
---
---@param buffer integer
function M.forget(buffer)
  expected[buffer] = nil
end

return M
